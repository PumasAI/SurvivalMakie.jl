_categorical_scale(fg, aes) =
let sd = get(fg.grid[1].categoricalscales, aes, nothing)
    sd === nothing ? nothing : sd[nothing]
end

# Facet scales report a panel's position either as a bare index (`AesRow`/`AesCol`,
# a single line of panels) or as a `(row, col)` tuple (`AesLayout`, wrapped).
_grid_tuple(pos::Integer) = (1, Int(pos))
_grid_tuple(pos::Tuple) = pos

# A scale's data value with any AlgebraOfGraphics value wrapper stripped, so it
# compares equal to the raw value stored in the fit keys. `presorted`/`nonnumeric`
# are stripped by the internal `unwrap`; `sorter` wraps values in `Sorted`, whose
# raw value is its `.value` field. Both `unwrap` and `Sorted` are AlgebraOfGraphics
# internals.
_rawvalue(x::AlgebraOfGraphics.Sorted) = _rawvalue(x.value)
_rawvalue(x) = AlgebraOfGraphics.unwrap(x)

# Facet data values in grid order, i.e. ordered to match the panels sorted by
# grid position. Robust to any constant layout offset between the scale's
# plot positions and the actual grid indices.
function _facet_values(fg, aes)
    scale = _categorical_scale(fg, aes)
    order = sortperm(collect(AlgebraOfGraphics.plotvalues(scale)); by = _grid_tuple)
    return _rawvalue.(collect(AlgebraOfGraphics.datavalues(scale))[order])
end

# Map each distinct grid index of the populated panels (sorted) to its facet
# value (also in grid order). `nothing` column means that dimension is absent.
_grid_value_map(::Nothing, _, _) = Dict{Int, Any}()
_grid_value_map(_col, indices, values) = Dict{Int, Any}(indices[i] => values[i] for i in eachindex(indices))

# (plot axis, facet key, grid row, grid column) for each populated panel. The
# facet key is the panel's `column => value` pairs (empty when unfaceted), used to
# pick the matching fit. `layout` wraps a single column into a grid, while `row`
# and `col` are independent dimensions that combine into a two-dimensional grid.
function _risk_panels(fg, rowcol, colcol, layoutcol)
    axinfo = [(ae.axis.layoutobservables.gridcontent[].span, ae.axis) for ae in vec(fg.grid) if !isempty(ae.entries)]
    sort!(axinfo; by = x -> (x[1].rows.start, x[1].cols.start))
    gridrow(a) = a[1].rows.start
    gridcol(a) = a[1].cols.start

    if rowcol === nothing && colcol === nothing && layoutcol === nothing
        span, ax = axinfo[1]
        return [(ax, (;), span.rows.start, span.cols.start)]
    end
    if layoutcol !== nothing
        values = _facet_values(fg, AlgebraOfGraphics.AesLayout)
        return [(axinfo[i][2], _facetkey(layoutcol => values[i]), gridrow(axinfo[i]), gridcol(axinfo[i])) for i in eachindex(axinfo)]
    end

    rowmap = _grid_value_map(rowcol, sort(unique(gridrow.(axinfo))), rowcol === nothing ? [] : _facet_values(fg, AlgebraOfGraphics.AesRow))
    colmap = _grid_value_map(colcol, sort(unique(gridcol.(axinfo))), colcol === nothing ? [] : _facet_values(fg, AlgebraOfGraphics.AesCol))
    return map(axinfo) do a
        key = _facetkey(
            (rowcol === nothing ? () : (rowcol => rowmap[gridrow(a)],))...,
            (colcol === nothing ? () : (colcol => colmap[gridcol(a)],))...,
        )
        (a[2], key, gridrow(a), gridcol(a))
    end
end

_facetkey(pairs...) = NamedTuple{Tuple(first.(pairs))}(Tuple(last.(pairs)))

# Each statistic is a count drawn from a `KaplanMeier` fit at a time point;
# `nothing` means the (stratum, panel) cell has no data.
natrisk_at(::Nothing, _) = ""
function natrisk_at(km::KaplanMeier, t)
    idx = searchsortedfirst(km.t, t)
    return idx <= length(km.Y) ? km.Y[idx] : 0
end

cumevents_at(::Nothing, _) = ""
cumevents_at(km::KaplanMeier, t) = sum(@view km.∂N[1:searchsortedlast(km.t, t)]; init = 0)

cumcensored_at(::Nothing, _) = ""
cumcensored_at(km::KaplanMeier, t) = sum(@view ncensored(km)[1:searchsortedlast(km.t, t)]; init = 0)

const RISKTABLE_STATS = (
    atrisk = (compute = natrisk_at, title = "At risk"),
    events = (compute = cumevents_at, title = "Events"),
    censored = (compute = cumcensored_at, title = "Censored"),
)

_risktable_stats(on::Bool) = on ? [:atrisk] : Symbol[]
function _risktable_stats(stats)
    out = collect(Symbol, stats)
    for s in out
        haskey(RISKTABLE_STATS, s) ||
            throw(ArgumentError("unknown risk table statistic $(repr(s)); valid options are $(keys(RISKTABLE_STATS))"))
    end
    return out
end

# A stratum name with a colored square matching its curve. The name stays in the
# default text color; only the square carries the group color. The square leads a
# left-aligned block title and trails a right-aligned row label, so it always
# sits toward the data.
_stratum_label(label, ::Nothing; leading = false) = label
function _stratum_label(label, color; leading = false)
    square = rich("◾"; color)
    return leading ? rich(square, " ", label) : rich(label, " ", square)
end
_labeltext(label, ::Nothing) = label
_labeltext(label, _color) = label * " ◾"

# The fit for one (color value, facet key) cell, or `nothing` if absent. The
# facet key holds the panel's `column => value` pairs (empty when unfaceted).
function _stratum_fit(fits, color, colorval, facetkey)
    for (; key, km) in fits
        (color === nothing || key[color] == colorval) || continue
        all(key[fc] == fv for (fc, fv) in pairs(facetkey)) || continue
        return km
    end
    return nothing
end

# The table cross-tabulates strata against statistics. `by` chooses which
# dimension forms the titled blocks: `:group` puts one block per stratum (its
# statistics listed together), `:statistic` puts one block per statistic (its
# strata listed together). The colored square follows the stratum.
function _risk_blocks(by, labels, colors, kms, statentries)
    if by === :group
        return [
            (
                    title = _stratum_label(labels[i], colors[i]; leading = true),
                    titletext = _labeltext(labels[i], colors[i]),
                    rows = [(label = st.title, labeltext = st.title, value = t -> st.compute(kms[i], t)) for st in statentries],
                ) for i in eachindex(labels)
        ]
    else
        return [
            (
                    title = st.title,
                    titletext = st.title,
                    rows = [
                        (label = _stratum_label(labels[i], colors[i]), labeltext = _labeltext(labels[i], colors[i]), value = t -> st.compute(kms[i], t)) for i in eachindex(labels)
                    ],
                ) for st in statentries
        ]
    end
end

const ROW_HEIGHT = 19.0
const BLOCK_GAP = 8.0
const LABEL_GAP = 10.0

# Flatten blocks to a list of visual rows, each tagged with its pixel offset from
# the top of the table. Title rows carry no counts (`value === nothing`); blocks
# are separated by `BLOCK_GAP`. Returns the rows and the total table height.
function _visual_rows(blocks)
    rows = NamedTuple[]
    offset = 0.0
    for (b, block) in enumerate(blocks)
        b == 1 || (offset += BLOCK_GAP)
        offset += ROW_HEIGHT
        push!(rows, (; label = block.title, labeltext = block.titletext, value = nothing, center = offset - ROW_HEIGHT / 2))
        for r in block.rows
            offset += ROW_HEIGHT
            push!(rows, (; label = r.label, labeltext = r.labeltext, value = r.value, center = offset - ROW_HEIGHT / 2))
        end
    end
    return identity.(rows), offset
end

# Estimated text extents (pixel-space text is not measured by the layout). Half
# the width of a count, for placing labels clear of the widest leftmost number,
# and the full width of a label, for the reserved left protrusion.
_num_halfwidth(s, fontsize) = 0.3 * fontsize * length(string(s))
_label_width(s, fontsize) = 0.62 * fontsize * length(string(s))

const TABLE_ROWGAP = Makie.Fixed(4)

# Insert `n` empty rows starting at `at`, shifting lower content down. Falls back
# to appending when `at` is past the last row (e.g. a right-side legend occupies
# a column, not a row, so the plot is the only row).
function _open_rows!(layout, at, n)
    GLB = Makie.GridLayoutBase
    gaps = fill(TABLE_ROWGAP, n)
    at <= GLB.lastrow(layout) ? GLB.insertrows!(layout, at, n; addedrowgaps = gaps) :
        GLB.appendrows!(layout, n; addedrowgaps = gaps)
    return
end

# data x -> figure-scene pixel x for `ax`, reactive on its limits and viewport.
_x_projector(ax) =
    Makie.lift(ax.finallimits, ax.scene.viewport) do _, vp
    x -> vp.origin[1] + Makie.project(ax.scene, Point2f(x, 0))[1]
end

# The risk table is drawn into the figure scene rather than an `Axis`, because an
# axis clips its data area and would cut a wide leftmost number. A spine-less
# `GridLayout` with a `Mixed` left `Protrusion` reserves the label space (so the
# figure grows to fit the labels), and a height-less `Box` in it reports the row
# region. Counts are positioned by projecting the plot axis; labels are right
# aligned just left of the widest leftmost count.
function add_risktable!(fg, fits, color, rowcol, colcol, layoutcol, stats, by)
    fig = fg.figure
    Makie.update_state_before_display!(fig)
    fontsize = Makie.theme(fig.scene)[:fontsize][]

    colorscale = _categorical_scale(fg, AlgebraOfGraphics.AesColor)
    stratumvals = colorscale === nothing ? Any[nothing] : _rawvalue.(AlgebraOfGraphics.datavalues(colorscale))
    stratumlabels = colorscale === nothing ? ["Overall"] : AlgebraOfGraphics.datalabels(colorscale)
    stratumcolors = colorscale === nothing ? Any[nothing] : collect(AlgebraOfGraphics.plotvalues(colorscale))
    statentries = [RISKTABLE_STATS[s] for s in stats]

    blocksfor(facetkey) =
        _risk_blocks(by, stratumlabels, stratumcolors, [_stratum_fit(fits, color, v, facetkey) for v in stratumvals], statentries)

    panels = _risk_panels(fg, rowcol, colcol, layoutcol)
    leftcol = minimum(gridcol for (_, _, _, gridcol) in panels)

    # One table block under each panel row. Process panel rows bottom to top so
    # inserting a row for an upper panel shifts the already-placed lower tables
    # (and any bottom legend) down without invalidating row indices.
    for plotrow in sort(unique(gridrow for (_, _, gridrow, _) in panels); rev = true)
        rowpanels = sort([p for p in panels if p[3] == plotrow]; by = p -> p[4])
        leftax, leftkey = rowpanels[1][1], rowpanels[1][2]
        leftvrows, totalheight = _visual_rows(blocksfor(leftkey))
        lefttvals = Float64.(leftax.xaxis.tickvalues[])

        # Only the right-aligned row labels (not the left-aligned block titles)
        # sit in the left protrusion, so they alone size it.
        maxhw = maximum((_num_halfwidth(r.value(lefttvals[1]), fontsize) for r in leftvrows if r.value !== nothing); init = 0.0)
        maxlw = maximum((_label_width(r.labeltext, fontsize) for r in leftvrows if r.value !== nothing); init = 0.0)
        protrusion = maxhw + LABEL_GAP + maxlw

        _open_rows!(fig.layout, plotrow + 1, 1)
        gl = GridLayout(
            fig[plotrow + 1, leftcol];
            alignmode = Makie.Mixed(left = Makie.GridLayoutBase.Protrusion(protrusion)),
            height = Makie.Fixed(totalheight),
        )
        bb = Box(gl[1, 1]; color = :transparent, strokevisible = false).layoutobservables.computedbbox

        for (ax, facetkey, _, gridcol) in rowpanels
            tickvals = Float64.(ax.xaxis.tickvalues[])
            projx = _x_projector(ax)
            labelright = Makie.lift(p -> p(tickvals[1]) - maxhw - LABEL_GAP, projx)
            dataleft = Makie.lift(vp -> vp.origin[1], ax.scene.viewport)

            for r in _visual_rows(blocksfor(facetkey))[1]
                y = Makie.lift(b -> Makie.top(b) - r.center, bb)
                if gridcol == leftcol
                    if r.value === nothing
                        # block title: left-aligned at the table's inner left border
                        Makie.text!(
                            fig.scene, Makie.lift((x, yy) -> Point2f(x, yy), dataleft, y);
                            text = r.label, align = (:left, :center), fontsize, space = :pixel,
                        )
                    else
                        Makie.text!(
                            fig.scene, Makie.lift((lr, yy) -> Point2f(lr, yy), labelright, y);
                            text = r.label, align = (:right, :center), fontsize, space = :pixel,
                        )
                    end
                end
                r.value === nothing && continue
                for t in tickvals
                    Makie.text!(
                        fig.scene, Makie.lift((p, yy) -> Point2f(p(t), yy), projx, y);
                        text = string(r.value(t)), align = (:center, :center), fontsize, space = :pixel,
                    )
                end
            end
        end
    end

    resize_to_layout!(fig)
    return fg
end

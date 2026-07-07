# A column reference, optionally relabeled: a `Symbol` or `AbstractString` naming
# the column, or `col => label` to relabel, where the label is anything Makie
# accepts (a string, `rich` text, `L"..."`, etc.).
const ColumnArg = Union{Symbol, AbstractString, Pair{Symbol}, Pair{<:AbstractString}}

"""
    survivalplot(table; time, status, kwargs...)

Plot Kaplan-Meier survival curves from a Tables.jl-compatible `table`.

`time` and `status` are the column names holding the event/censoring times and
their status indicators (`true`/`1` = observed event, `false`/`0` =
right-censored).

Column arguments (`time`, `color`, `col`, `row`, `layout`) accept the same forms
as an AlgebraOfGraphics `mapping`: a bare `Symbol`, a `:column => "Label"` pair to
relabel the corresponding axis or legend (e.g. `time = :Time => "Days"` or
`color = :Sex => "Group"`), or a `:column => transformation => "Label"` triple to
also apply a transformation such as `sorter([...])`, `presorted` or `nonnumeric`
(e.g. `color = :group => sorter(["Treatment", "Placebo"]) => "Arm"`). The y-axis
label follows `statistic` and can be overridden with `scales = (; Y = (; label = "..."))`.

# Keyword arguments

- `color`: column to stratify by, drawn as differently colored curves with a legend.
- `col`: column to facet by, drawn as separate panels in a single row. Can be
  combined with `row` for a two-dimensional grid of panels.
- `row`: column to facet by, drawn as separate panels in a single column. Can be
  combined with `col` for a two-dimensional grid of panels.
- `layout`: column to facet by, wrapped into a grid of panels. Cannot be combined
  with `col` or `row`. Each panel gets its own risk table.
- `statistic`: `:survival` (default) plots S(t); `:cumulative_incidence` plots 1 - S(t).
- `ci`: confidence level for the pointwise confidence bands, e.g. `0.95`
  (default) or `0.9`. Set `nothing` to omit the bands.
- `quantile`: draw quantile reference lines at the given probabilities (e.g.
  `0.5` for the median, or `[0.25, 0.5, 0.75]`). Each is an L-shaped line from
  the axis to the curve crossing, distinguished by linestyle.
- `censorticks`: mark censored observations with ticks on the curve (default `true`).
- `risktable`: number-at-risk table below the plot. `true` (default) shows the
  number at risk; `false` omits the table. Pass a vector of `:atrisk`,
  `:events` (cumulative events) and/or `:censored` (cumulative censored) to
  choose which rows to show, in order.
- `risktable_by`: `:group` (default) puts one titled block per stratum with its
  statistics listed together; `:statistic` puts one block per statistic with
  the strata listed together.
- `scales`: forwarded to AlgebraOfGraphics' `scales`, merged one level deep over
  the defaults so you can override individual settings. Change the color scheme
  with `scales = (; Color = (; palette = [...]))` (the risk-table swatches follow
  automatically), or the x ticks with `scales = (; X = (; ticks = 0:200:1000))`.
- `figure`, `axis`, `facet`, `legend`: forwarded to AlgebraOfGraphics. `figure`
  accepts the usual Makie `Figure` options plus `title`/`subtitle`; `facet`
  accepts `linkxaxes`, `linkyaxes`, etc.

Returns an `AlgebraOfGraphics.FigureGrid`, which can be displayed or `save`d.
"""
function survivalplot(
        table;
        time::ColumnArg,
        status::Union{Symbol, AbstractString},
        color::Union{Nothing, ColumnArg} = nothing,
        col::Union{Nothing, ColumnArg} = nothing,
        row::Union{Nothing, ColumnArg} = nothing,
        layout::Union{Nothing, ColumnArg} = nothing,
        statistic::Symbol = :survival,
        ci::Union{Nothing, Real} = 0.95,
        quantile::Union{Nothing, Real, AbstractVector{<:Real}} = nothing,
        censorticks::Bool = true,
        risktable::Union{Bool, AbstractVector{Symbol}} = true,
        risktable_by::Symbol = :group,
        scales = (;),
        figure = (;),
        axis = (;),
        facet = (;),
        legend = (;),
    )
    statistic in (:survival, :cumulative_incidence) ||
        throw(ArgumentError("`statistic` must be :survival or :cumulative_incidence, got $(repr(statistic))"))
    risktable_by in (:group, :statistic) ||
        throw(ArgumentError("`risktable_by` must be :group or :statistic, got $(repr(risktable_by))"))
    layout === nothing ||
        (col === nothing && row === nothing) ||
        throw(ArgumentError("`layout` (wrapped grid) cannot be combined with `col` or `row`; use `col` and `row` together for an explicit grid"))

    colorcol = _colsym(color)
    rowcol = _colsym(row)
    colcol = _colsym(col)
    layoutcol = _colsym(layout)
    stacked_rows = rowcol !== nothing || layoutcol !== nothing
    has_facet = rowcol !== nothing || colcol !== nothing || layoutcol !== nothing

    cols = Tables.columntable(table)
    groupcols = Symbol[]
    for c in (colorcol, rowcol, colcol, layoutcol)
        c === nothing || c in groupcols || push!(groupcols, c)
    end

    fits = group_fits(cols, _colsym(time), _colsym(status), groupcols)
    tabs = layer_tables(fits, statistic, something(ci, 0.95))

    grp = grouping_mapping(color, col, row, layout)

    spec =
        data(tabs.curve) * mapping(:time, :estimate; grp...) * visual(Stairs; step = :post, linewidth = CURVE_LINEWIDTH)
    if ci !== nothing
        spec =
            data(tabs.band) * mapping(:time, :lower, :upper; grp...) * visual(Band; alpha = 0.25, label = ci_label(ci)) +
            spec
    end
    if censorticks
        spec +=
            data(tabs.censor) *
            mapping(:time, :estimate; grp...) *
            visual(Scatter; marker = censor_marker(statistic), markersize = CENSOR_LENGTH, label = "Censored")
    end
    quantiles = quantile === nothing ? Float64[] : quantile isa Real ? [Float64(quantile)] : Float64.(quantile)
    if !isempty(quantiles)
        qtab = quantile_table(fits, statistic, quantiles)
        isempty(qtab) || (
            spec +=
                data(qtab) *
                mapping(:x, :y; grp..., linestyle = :quantile => nonnumeric => "Quantile") *
                visual(Lines; xautolimits = false, yautolimits = false, linewidth = 1.5)
        )
    end

    defaults = (;
        X = (; label = _label(time), ticks = Makie.WilkinsonTicks(5; k_min = 4)),
        Y = (; label = statistic_label(Val(statistic)), ticks = [0.0, 0.25, 0.5, 0.75, 1.0], tickformat = percent_ticks),
    )
    isempty(quantiles) || (defaults = merge(defaults, (; LineStyle = (; palette = [:dash, :dot, :dashdot, :dashdotdot]))))
    scalespec = AlgebraOfGraphics.scales(; merge_scales(defaults, _as_namedtuple(scales))...)

    stats = _risktable_stats(risktable)
    facetdefaults = NamedTuple()
    if has_facet
        # Hint a fixed panel size (3:2 axes) so facets don't get cramped as the grid grows.
        facetdefaults = merge(facetdefaults, (; size = AlgebraOfGraphics.FacetSize(3 / 2, (nr, nc) -> _facet_height(max(nr, nc)))))
    end
    # `row`, `row`+`col` and wrapped `layout` with risk tables stack panels over
    # several rows with a table between them. Keep each panel's x ticks (the shared
    # bottom axis is too far) and per-panel y labels (a single spanning label is
    # positioned from the axes only, so it would collide with the scene-drawn table
    # labels).
    if stacked_rows && !isempty(stats)
        facetdefaults = merge(facetdefaults, (; hidexdecorations = false, singleylabel = false))
    end
    facet = merge(facetdefaults, _as_namedtuple(facet))
    fg = draw(spec, scalespec; axis, figure, facet, legend)

    isempty(stats) || add_risktable!(fg, fits, colorcol, rowcol, colcol, layoutcol, stats, risktable_by)

    return fg
end

const CURVE_LINEWIDTH = 2.0
const CENSOR_LENGTH = 9.0
const CENSOR_WIDTH = 1.4

# A thin rectangle tick, a touch narrower than the curve so dense ticks stay
# separated. The width:length ratio is baked into the path (long axis spans 1,
# scaled by a scalar
# `markersize`) and the path is pre-rotated, so the tilt also shows in the
# legend. It leans away from the curve's direction of travel to stand clear of
# the vertical step risers.
function censor_marker(statistic)
    r = CENSOR_WIDTH / CENSOR_LENGTH
    rect = Makie.BezierPath(
        [
            Makie.MoveTo(-r / 2, -0.5),
            Makie.LineTo(r / 2, -0.5),
            Makie.LineTo(r / 2, 0.5),
            Makie.LineTo(-r / 2, 0.5),
            Makie.ClosePath(),
        ]
    )
    return Makie.rotate(rect, censor_rotation(Val(statistic)))
end

censor_rotation(::Val{:survival}) = -π / 4
censor_rotation(::Val{:cumulative_incidence}) = π / 4

# Normalize a column argument to a `Symbol` column name (dropping any label).
_colsym(x::Symbol) = x
_colsym(x::AbstractString) = Symbol(x)
_colsym(x::Pair) = _colsym(first(x))
_colsym(::Nothing) = nothing

# The label for a column argument: the relabel target if given, else the name.
_label(x::Pair) = last(x)
_label(x::Union{Symbol, AbstractString}) = string(x)

# A mapping reference: a bare `Symbol`, or `Symbol => label` when relabeled.
_mapref(x::Pair) = _colsym(x) => last(x)
_mapref(x) = _colsym(x)

percent_ticks(values) = [string(round(Int, 100v), '%') for v in values]

# Default per-panel axis height by grid extent (max of rows, columns), so facets
# stay legible as the grid grows.
_facet_height(n::Int) = get(Dict(1 => 350, 2 => 225, 3 => 150), n, 100)

function ci_label(level)
    pct = 100 * level
    s = pct == round(pct) ? string(round(Int, pct)) : string(pct)
    return "$s% CI"
end

_as_namedtuple(nt::NamedTuple) = nt
_as_namedtuple(d) = (; pairs(d)...)

# Merge user scale settings over the defaults one level deep, so e.g. passing
# `scales = (; X = (; ticks = ...))` overrides only the ticks and keeps the
# default X label.
function merge_scales(defaults::NamedTuple, user::NamedTuple)
    aess = (union(keys(defaults), keys(user))...,)
    return NamedTuple{aess}(map(a -> merge(get(defaults, a, (;)), get(user, a, (;))), aess))
end

grouping_mapping(color, col, row, layout) = (;
    (color === nothing ? (;) : (; color = _mapref(color)))...,
    (col === nothing ? (;) : (; col = _mapref(col)))...,
    (row === nothing ? (;) : (; row = _mapref(row)))...,
    (layout === nothing ? (;) : (; layout = _mapref(layout)))...,
)

# `:survival` keeps S(t); `:cumulative_incidence` plots 1 - S(t), which also
# flips the confidence bounds since 1 - S is decreasing in S.
apply_statistic(::Val{:survival}, s) = s
apply_statistic(::Val{:cumulative_incidence}, s) = 1 .- s
flip_bounds(::Val{:survival}, lo, hi) = (lo, hi)
flip_bounds(::Val{:cumulative_incidence}, lo, hi) = (1 .- hi, 1 .- lo)

statistic_label(::Val{:survival}) = "Survival probability"
statistic_label(::Val{:cumulative_incidence}) = "Cumulative incidence"

# Duplicate interior points so a `Band` renders as a step function instead of
# interpolating diagonally between confidence bounds.
function step_coords(t, lo, hi)
    n = length(t)
    st = Vector{Float64}(undef, 2n - 1)
    slo = similar(st)
    shi = similar(st)
    for i in 1:(n - 1)
        st[2i - 1], slo[2i - 1], shi[2i - 1] = t[i], lo[i], hi[i]
        st[2i], slo[2i], shi[2i] = t[i + 1], lo[i], hi[i]
    end
    st[2n - 1], slo[2n - 1], shi[2n - 1] = t[n], lo[n], hi[n]
    return st, slo, shi
end

# Split row indices into groups keyed by the combined values of `groupcols`,
# in sorted order for deterministic layout. No grouping columns means a single
# group with an empty key.
function group_indices(cols, groupcols::Vector{Symbol})
    n = length(Tables.getcolumn(cols, first(Tables.columnnames(cols))))
    isempty(groupcols) && return [(NamedTuple(), collect(1:n))]
    keyvecs = [Tables.getcolumn(cols, g) for g in groupcols]
    keys = [ntuple(j -> keyvecs[j][i], length(groupcols)) for i in 1:n]
    NT = NamedTuple{Tuple(groupcols)}
    return [(NT(k), findall(==(k), keys)) for k in sort(unique(keys))]
end

# Fit one `KaplanMeier` per group, returning the group key alongside its fit so
# downstream steps (curves, bands, risk table) share a single fit.
function group_fits(cols, time::Symbol, status::Symbol, groupcols::Vector{Symbol})
    tvec = Tables.getcolumn(cols, time)
    svec = Tables.getcolumn(cols, status)
    return map(group_indices(cols, groupcols)) do (key, idxs)
        (; key, km = KaplanMeier(tvec[idxs], svec[idxs]))
    end
end

# SurvivalModels' `KaplanMeier` stores, per time in `km.t`, the number of deaths
# (`∂N`) and the at-risk count just before that time (`Y`), but not the censored
# counts. The number leaving the risk set at tᵢ is the drop in the at-risk count
# Yᵢ - Yᵢ₊₁ (everyone remaining leaves at the last time, i.e. Yₙ); subtracting
# the deaths there gives the censored count. Summing this telescopes to the
# familiar cumulative identity n - (at risk) - (deaths).
function ncensored(km::KaplanMeier)
    Y = km.Y
    n = length(Y)
    return [(Y[i] - (i < n ? Y[i + 1] : 0)) - km.∂N[i] for i in 1:n]
end

# Survival estimate Ŝ at each time in `km.t`.
survival(km::KaplanMeier) = predict(km, :survival)

# Tidy long-format tables for the three plot layers, each row tagged with its
# group key so AlgebraOfGraphics can map color/col/row directly.
function layer_tables(fits, statistic::Symbol, level::Real)
    stat = Val(statistic)
    curve = NamedTuple[]
    band = NamedTuple[]
    censor = NamedTuple[]

    for (; key, km) in fits
        surv = survival(km)
        t = [zero(eltype(km.t)); km.t]
        est = apply_statistic(stat, [1.0; surv])
        for i in eachindex(t)
            push!(curve, merge((; time = Float64(t[i]), estimate = est[i]), key))
        end

        # SurvivalModels' `confint` takes the significance level α = 1 - level.
        ci = confint(km; level = 1 - level)
        lo = [1.0; ci.lower]
        hi = [1.0; ci.upper]
        lo, hi = flip_bounds(stat, lo, hi)
        st, slo, shi = step_coords(Float64.(t), lo, hi)
        for i in eachindex(st)
            push!(band, merge((; time = st[i], lower = slo[i], upper = shi[i]), key))
        end

        mask = ncensored(km) .> 0
        ct = km.t[mask]
        cest = apply_statistic(stat, surv[mask])
        for i in eachindex(ct)
            push!(censor, merge((; time = Float64(ct[i]), estimate = cest[i]), key))
        end
    end

    return (; curve = identity.(curve), band = identity.(band), censor = identity.(censor))
end

# Quantile reference lines as an L per (group, quantile): a horizontal segment
# at height `q` from off the left edge to the crossing time, then a vertical
# segment down off the bottom edge. The off-axis endpoints (`-CLIP`) are drawn
# with autolimits disabled so they clip to the axis instead of expanding it.
const QUANTILE_CLIP = 1000.0

function quantile_table(fits, statistic::Symbol, quantiles)
    stat = Val(statistic)
    reached = statistic === :survival ? (<=) : (>=)
    rows = NamedTuple[]
    for (; key, km) in fits
        est = apply_statistic(stat, survival(km))
        for q in quantiles
            idx = findfirst(e -> reached(e, q), est)
            idx === nothing && continue
            t = Float64(km.t[idx])
            corners = ((-QUANTILE_CLIP, q), (t, q), (t, -QUANTILE_CLIP))
            for (x, y) in corners
                push!(rows, merge((; x = Float64(x), y = Float64(y), quantile = Float64(q)), key))
            end
        end
    end
    return identity.(rows)
end

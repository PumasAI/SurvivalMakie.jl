# Deterministic synthetic cohort (seeded Xoshiro, stable across Julia 1.x) so the
# reference images are reproducible without depending on an external dataset.
function reference_cohort(; seed = 20240601, n = 240)
    rng = Random.Xoshiro(seed)
    group = rand(rng, ["Treatment", "Placebo"], n)
    scale = [g == "Treatment" ? 380.0 : 230.0 for g in group]
    time = round.(Int, -scale .* log.(rand(rng, n)))
    status = rand(rng, n) .< 0.7
    age = rand(rng, ["< 65", "≥ 65"], n)
    sex = rand(rng, ["F", "M"], n)
    return (; time, status, group, age, sex)
end

const COHORT = reference_cohort()
# A large cohort produces 5-digit at-risk counts (to guard against clipping at
# the table's left edge); censor ticks are off since there would be far too many.
const LARGE_COHORT = reference_cohort(; n = 40000)

@testset "reference images" begin
    @test_pixelmatch "reference_images/basic" survivalplot(COHORT; time = :time, status = :status)

    @test_pixelmatch "reference_images/grouped" survivalplot(COHORT; time = :time, status = :status, color = :group)

    @test_pixelmatch "reference_images/cumulative_incidence" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        statistic = :cumulative_incidence,
    )

    @test_pixelmatch "reference_images/facet_col" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        col = :age,
    )

    @test_pixelmatch "reference_images/facet_row" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        row = :age,
    )

    @test_pixelmatch "reference_images/facet_row_col" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        row = :sex,
        col = :age,
    )

    @test_pixelmatch "reference_images/facet_layout" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        layout = :age,
    )

    @test_pixelmatch "reference_images/quantiles" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        quantile = [0.25, 0.5, 0.75],
        risktable = false,
    )

    @test_pixelmatch "reference_images/multistat_by_group" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        risktable = [:atrisk, :events, :censored],
    )

    @test_pixelmatch "reference_images/multistat_by_statistic" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        risktable = [:atrisk, :events, :censored],
        risktable_by = :statistic,
    )

    @test_pixelmatch "reference_images/bottom_legend" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        legend = (; position = :bottom),
    )

    @test_pixelmatch "reference_images/relabel_and_palette" survivalplot(
        COHORT;
        time = :time => "Time (days)",
        status = :status,
        color = :group => "Arm",
        scales = (; Color = (; palette = [:firebrick, :seagreen])),
        figure = (; title = "Overall survival"),
    )

    @test_pixelmatch "reference_images/large_counts" survivalplot(
        LARGE_COHORT;
        time = :time,
        status = :status,
        color = :group,
        censorticks = false,
        risktable = [:atrisk, :events, :censored],
    )

    @test_pixelmatch "reference_images/plain" survivalplot(
        COHORT;
        time = :time,
        status = :status,
        color = :group,
        ci = nothing,
        censorticks = false,
        risktable = false,
    )
end

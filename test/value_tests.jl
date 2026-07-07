columns(nt) = Tables.columntable(nt)

@testset "Kaplan-Meier curve assembly" begin
    df = (time = [5, 10, 15, 20, 25], status = [true, true, false, true, true])
    fits = group_fits(columns(df), :time, :status, Symbol[])
    @test length(fits) == 1
    @test survival(fits[1].km) ≈ [0.8, 0.6, 0.6, 0.3, 0.0]

    tabs = layer_tables(fits, :survival, 0.95)
    @test [r.time for r in tabs.curve] == [0, 5, 10, 15, 20, 25]
    @test [r.estimate for r in tabs.curve] ≈ [1.0, 0.8, 0.6, 0.6, 0.3, 0.0]

    @test length(tabs.censor) == 1
    @test tabs.censor[1].time == 15.0
    @test tabs.censor[1].estimate ≈ 0.6
end

@testset "cumulative incidence is 1 - survival" begin
    @test apply_statistic(Val(:cumulative_incidence), [1.0, 0.8, 0.3]) ≈ [0.0, 0.2, 0.7]

    df = (time = [5, 10, 15, 20, 25], status = [true, true, false, true, true])
    fits = group_fits(columns(df), :time, :status, Symbol[])
    ci = layer_tables(fits, :cumulative_incidence, 0.95)
    @test [r.estimate for r in ci.curve] ≈ [0.0, 0.2, 0.4, 0.4, 0.7, 1.0]
end

@testset "confidence band steps and brackets the curve" begin
    df = (time = [5, 10, 15, 20, 25], status = [true, true, false, true, true])
    fits = group_fits(columns(df), :time, :status, Symbol[])
    band = layer_tables(fits, :survival, 0.95).band
    @test first(band).time == 0.0 && first(band).lower == 1.0 && first(band).upper == 1.0
    @test length(band) == 2 * 6 - 1  # stepped: interior points duplicated
    @test all(r -> isnan(r.lower) || isnan(r.upper) || r.lower <= r.upper, band)
end

@testset "grouping splits fits, counts, and quantiles" begin
    df = (time = [5, 10, 5, 10, 15], status = [true, true, true, false, true], grp = ["a", "a", "b", "b", "b"])
    fits = group_fits(columns(df), :time, :status, [:grp])
    @test [f.key.grp for f in fits] == ["a", "b"]
    @test survival(fits[1].km) ≈ [0.5, 0.0]
    @test survival(fits[2].km) ≈ [2 / 3, 2 / 3, 0.0]

    @test natrisk_at(fits[1].km, 0) == 2
    @test natrisk_at(fits[2].km, 0) == 3
    @test natrisk_at(fits[2].km, 12) == 1
    @test natrisk_at(fits[2].km, 1000) == 0
    @test natrisk_at(nothing, 0) == ""

    @test cumevents_at(fits[2].km, 12) == 1   # one event by t=12 (at t=5)
    @test cumevents_at(fits[2].km, 1000) == 2
    @test cumcensored_at(fits[2].km, 1000) == 1

    # group a: survival drops to 0.5 at t=5, so the median L corners there
    q = quantile_table(fits, :survival, [0.5])
    a05 = filter(r -> r.grp == "a", q)
    @test [r.x for r in a05] == [-SurvivalMakie.QUANTILE_CLIP, 5.0, 5.0]
    @test [r.y for r in a05] == [0.5, 0.5, -SurvivalMakie.QUANTILE_CLIP]

    # a quantile a curve never reaches yields no line (all-censored stays at 1.0)
    censored = group_fits(columns((time = [5, 10], status = [false, false])), :time, :status, Symbol[])
    @test isempty(quantile_table(censored, :survival, [0.5]))
end

@testset "_stratum_fit keys on color and all facet dimensions" begin
    grp = repeat(["a", "b"], inner = 8)
    r = repeat(["x", "y"], inner = 4, outer = 2)
    c = repeat(["p", "q"], inner = 2, outer = 4)
    time = [3, 9, 4, 10, 2, 8, 5, 11, 6, 13, 7, 14, 1, 12, 5, 15]
    status = repeat([true, false], 8)
    cols = columns((; time, status, grp, r, c))
    fits = group_fits(cols, :time, :status, [:grp, :r, :c])

    cell(g, rv, cv) = (cols.grp .== g) .& (cols.r .== rv) .& (cols.c .== cv)
    celltimes(g, rv, cv) = sort(cols.time[cell(g, rv, cv)])

    @test _stratum_fit(fits, :grp, "b", (; r = "y", c = "q")).t == celltimes("b", "y", "q")
    @test _stratum_fit(fits, :grp, "b", (; r = "y", c = "p")).t == celltimes("b", "y", "p")
    @test celltimes("b", "y", "q") != celltimes("b", "y", "p")
    @test _stratum_fit(fits, :grp, "z", (; r = "y", c = "q")) === nothing
end

@testset "transformed color/facet scales still match risk-table fits" begin
    df = (
        time = repeat(1:10, 8),
        status = repeat([true, false], 40),
        group = repeat(["A", "B"], inner = 40),
        age = repeat(["x", "y"], 40),
    )
    fits = group_fits(columns(df), :time, :status, [:group, :age])
    fg = survivalplot(
        df; time = :time, status = :status,
        color = :group => sorter(["B", "A"]) => "Group",
        col = :age => presorted => "Age",
    )

    @test _rawvalue.(datavalues(_categorical_scale(fg, AesColor))) == ["B", "A"]
    @test _facet_values(fg, AesCol) == ["x", "y"]
    @test _stratum_fit(fits, :group, "B", (; age = "y")) !== nothing
end

@testset "argument validation" begin
    df = (time = [1, 2, 3], status = [true, false, true])
    @test_throws "statistic" survivalplot(df; time = :time, status = :status, statistic = :bogus)
    @test_throws "risktable_by" survivalplot(df; time = :time, status = :status, risktable_by = :bogus)
    @test_throws "cannot be combined" survivalplot(df; time = :time, status = :status, col = :status, layout = :status)
    @test_throws "cannot be combined" survivalplot(df; time = :time, status = :status, row = :status, layout = :status)
end

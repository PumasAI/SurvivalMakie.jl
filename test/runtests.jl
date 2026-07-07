using SurvivalMakie
using SurvivalMakie: group_fits, layer_tables, natrisk_at, cumevents_at, cumcensored_at, apply_statistic, quantile_table, survival
using SurvivalMakie: _stratum_fit, _rawvalue, _facet_values, _categorical_scale
using SurvivalMakie.Tables
using AlgebraOfGraphics: sorter, presorted, datavalues, AesColor, AesCol
using CairoMakie
using PixelMatch
using Random
using Test

CairoMakie.activate!(; type = "png")

# Set JULIA_REFERENCETESTS_UPDATE=true to (re)generate the reference images.
@testset "SurvivalMakie" begin
    include("value_tests.jl")

    # On CI the report name carries the OS so per-OS matrix jobs upload distinct
    # artifacts; locally it stays plain.
    report = if get(ENV, "CI", "false") == "true"
        os = Sys.iswindows() ? "Windows" : Sys.isapple() ? "macOS" : "Linux"
        "pixelmatch-report-$os.html"
    else
        "pixelmatch-report.html"
    end
    report_path = joinpath(@__DIR__, "reference_images", report)
    PixelMatch.@pixelmatch_report out_file = report_path begin
        include("reference_tests.jl")
    end
end

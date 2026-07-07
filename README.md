

# SurvivalMakie

<img src="docs/src/assets/logo.png" align="right" width="180" alt="SurvivalMakie logo" />

[![CI](https://github.com/PumasAI/SurvivalMakie.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/PumasAI/SurvivalMakie.jl/actions/workflows/CI.yml)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://pumasai.github.io/SurvivalMakie.jl/dev/)

SurvivalMakie plots survival analysis results. A single `survivalplot`
function turns a table of event times into a Kaplan-Meier (or
cumulative-incidence) figure with confidence bands, censoring marks, a
number-at-risk table, and optional quantile lines. The estimate comes
from [SurvivalModels.jl](https://github.com/JuliaSurv/SurvivalModels.jl)
and the drawing from [AlgebraOfGraphics](https://aog.makie.org), so
grouping, legends, scales, and faceting are handled by a mature plotting
stack.

## Example

``` julia
using SurvivalMakie, CairoMakie, RDatasets, DataFrames

lung = dataset("survival", "lung")
transform!(lung,
    :Status => ByRow(==(2)) => :Died,
    :Sex => ByRow(s -> s == 1 ? "Male" : "Female") => :Sex,
)

survivalplot(lung; time = :Time, status = :Died, color = :Sex)
```

<img src="README_files/figure-commonmark/cell-3-output-1.png"
width="672" height="480" />

Faceting, cumulative incidence, quantile lines, and styling are shown in
the [documentation](https://pumasai.github.io/SurvivalMakie.jl/dev/).

``` julia
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    statistic = :cumulative_incidence, quantile = 0.5)
```

<img src="README_files/figure-commonmark/cell-4-output-1.png"
width="672" height="480" />

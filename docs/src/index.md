````@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: SurvivalMakie
  text: Kaplan-Meier plots for Makie
  tagline: Survival and cumulative-incidence curves with confidence bands, censoring marks, risk tables, and quantile lines, built on Makie and AlgebraOfGraphics.
  actions:
    - theme: brand
      text: Getting started
      link: /getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/PumasAI/SurvivalMakie.jl

features:
  - title: One function, many options
    details: A single `survivalplot` call draws curves, confidence bands, censoring ticks, and a number-at-risk table. No post-hoc mutation of the figure.
  - title: Comparisons and faceting for free
    details: Stratify by a grouping column for colored curves with a shared legend, or split into panels by column or wrapped layout.
  - title: Publication-ready tables
    details: Number at risk, cumulative events, and cumulative censored, arranged by group or by statistic, colored to match the curves.
---
````

# SurvivalMakie

SurvivalMakie turns a table of event times into a survival figure. It computes the
[Kaplan-Meier](https://en.wikipedia.org/wiki/Kaplan%E2%80%93Meier_estimator) estimate with
[SurvivalModels.jl](https://github.com/JuliaSurv/SurvivalModels.jl) and draws it with
[AlgebraOfGraphics](https://aog.makie.org), so grouping, legends, scales, and faceting come
from a mature plotting stack rather than bespoke code.

The example below uses the NCCTG lung cancer dataset (survival in 228 patients with advanced
lung cancer) to compare survival between men and women, with a number-at-risk table beneath
the curves.

```@example index
using SurvivalMakie, CairoMakie, RDatasets, DataFrames

lung = dataset("survival", "lung")
transform!(lung,
    :Status => ByRow(==(2)) => :Died,
    :Sex => ByRow(s -> s == 1 ? "Male" : "Female") => :Sex,
)

survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    figure = (; title = "Overall survival in advanced lung cancer"))
```

Read on for the individual features, each demonstrated on the same cohort.

# Getting started

## Installation

```julia
using Pkg
Pkg.add("SurvivalMakie")
```

You also need a Makie backend. The documentation uses
[CairoMakie](https://docs.makie.org/stable/explanations/backends/cairomakie) for static
images; [GLMakie](https://docs.makie.org/stable/explanations/backends/glmakie) works too for
interactive windows.

## The data

Every example in this documentation uses the NCCTG lung cancer dataset shipped with
[RDatasets](https://github.com/JuliaStats/RDatasets.jl). It records, for 228 patients with
advanced lung cancer, the survival `Time` in days and a `Status` indicator. `Status` is
coded `1` for censored and `2` for death, so we derive a boolean event column `Died`, and
relabel `Sex` for readable legends.

```@example start
using SurvivalMakie, CairoMakie, RDatasets, DataFrames

lung = dataset("survival", "lung")
transform!(lung,
    :Status => ByRow(==(2)) => :Died,
    :Sex => ByRow(s -> s == 1 ? "Male" : "Female") => :Sex,
)
first(lung, 5)
```

## Your first survival curve

`survivalplot` needs a table plus the `time` and `status` columns. `status` is the event
indicator: `true`/`1` marks an observed event (here, death) and `false`/`0` marks a
right-censored observation (the patient was still alive at last contact).

```@example start
survivalplot(lung; time = :Time, status = :Died)
```

By default you get the Kaplan-Meier survival curve, a shaded 95% confidence band, tick marks
at each censoring time, and a number-at-risk table aligned to the time axis. The y-axis is
formatted as a percentage and starts at 0.

The call returns an `AlgebraOfGraphics.FigureGrid`, which displays in notebooks and can be
saved like any Makie figure:

```julia
fg = survivalplot(lung; time = :Time, status = :Died)
save("survival.png", fg)
```

The [Guide](guide.md) works through the rest of the options, all starting from this `lung`
table.

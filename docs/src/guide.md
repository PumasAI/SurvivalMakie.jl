# Guide

This page walks through what `survivalplot` can draw and the options that control it. Every
example uses the NCCTG lung cancer table prepared in [Getting started](getting-started.md),
reproduced here.

```@setup guide
using SurvivalMakie, CairoMakie, RDatasets, DataFrames
lung = dataset("survival", "lung")
transform!(lung,
    :Status => ByRow(==(2)) => :Died,
    :Sex => ByRow(s -> s == 1 ? "Male" : "Female") => :Sex,
    :Age => ByRow(a -> a < 65 ? "Age < 65" : "Age ≥ 65") => :AgeGroup,
)
```

## Comparing groups

Pass a grouping column as `color` to fit a separate Kaplan-Meier curve per group. Each curve
gets its own color, confidence band, and censoring marks, a shared legend is added, and the
risk table gains one row per group with a matching color swatch.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex)
```

`color` is not limited to two levels. Here the curves are split by ECOG performance status,
keeping the three best-populated levels.

```@example guide
ecog = transform(
    subset(lung, :PhECOG => ByRow(in((0, 1, 2))); skipmissing = true),
    :PhECOG => ByRow(g -> "ECOG $(Int(g))") => :ECOG,
)

survivalplot(ecog; time = :Time, status = :Died, color = :ECOG)
```

## Confidence intervals

`ci` is the confidence level of the pointwise band, `0.95` by default. Pass another level to
widen or narrow it; the legend records the level.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex, ci = 0.9)
```

Pass `ci = nothing` to omit the band, for example when overlapping bands from many groups
would be hard to read.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex, ci = nothing)
```

## Censoring marks

Each censoring time is marked with a short diagonal tick on the curve. The tick leans away
from the curve's direction of travel so it stays distinct from the vertical steps. Set
`censorticks = false` to hide them.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    censorticks = false, risktable = false)
```

## Cumulative incidence

`statistic = :cumulative_incidence` plots ``1 - S(t)`` instead of ``S(t)``: the curve starts
at 0 and rises. Grouping, bands, censoring marks, and risk tables all follow the transformed
curve.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    statistic = :cumulative_incidence)
```

## Quantile lines

`quantile` draws reference lines from the y-axis across to the curve and down to the time
axis, so the crossing time can be read off the x-axis. `quantile = 0.5` marks the median.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    quantile = 0.5, risktable = false)
```

Pass several probabilities to draw several lines. Each level gets a distinct line style and
legend entry, while color still encodes the group. A line is omitted for any curve that
never reaches the requested level.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    quantile = [0.25, 0.5, 0.75], risktable = false)
```

## Risk tables

The number-at-risk table is drawn by default and aligns to the plot's time ticks. Set
`risktable = false` to drop it.

Pass a vector to choose which rows appear, in order: the number at risk (`:atrisk`), the
cumulative number of events (`:events`), and the cumulative number censored (`:censored`).

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    risktable = [:atrisk, :events, :censored])
```

`risktable_by` controls the arrangement. By default (`:group`) each stratum is one titled
block with its statistics listed together. `:statistic` flips it: one block per statistic
with the strata listed together.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    risktable = [:atrisk, :events, :censored], risktable_by = :statistic)
```

## Faceting

`col` splits the plot into a single row of panels, one per level of the faceting column.
Each panel gets its own risk table.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex, col = :AgeGroup)
```

`layout` wraps the panels into a grid instead, which suits a faceting column with many
levels. It is mutually exclusive with `col`.

```@example guide
sites = transform(
    subset(lung, :Inst => ByRow(in((1, 3, 5, 6, 11, 12))); skipmissing = true),
    :Inst => ByRow(i -> "Institution $(Int(i))") => :Site,
)

survivalplot(sites; time = :Time, status = :Died, color = :Sex, layout = :Site)
```

## Customizing appearance

`survivalplot` owns the figure layout but forwards the usual AlgebraOfGraphics and Makie
options, so you can relabel, recolor, retitle, and reposition without touching the internals.

### Labels

Column arguments accept either a `Symbol` or a `:column => "Label"` pair, where the label can
be a string or any Makie rich text. The y-axis label follows `statistic` and can be set
through `scales`.

```@example guide
survivalplot(lung;
    time = :Time => "Time since enrollment (days)",
    status = :Died,
    color = :Sex => "Sex at birth")
```

### Color scheme

Change the palette through the `Color` scale; the curves, bands, legend, and risk-table
swatches all follow.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    scales = (; Color = (; palette = [:firebrick, :steelblue])))
```

### Titles and legend placement

`figure` takes the usual Makie figure options plus `title` and `subtitle`. `legend` is
forwarded to AlgebraOfGraphics; moving it below the plot tucks the risk table underneath it.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    figure = (; title = "Overall survival", subtitle = "NCCTG lung cancer cohort"),
    legend = (; position = :bottom))
```

### Ticks

Ticks are set through `scales`, consistent with labels. The x ticks default to
`WilkinsonTicks(; k_min = 4)` and the y ticks to percentages; override either independently.

```@example guide
survivalplot(lung; time = :Time, status = :Died, color = :Sex,
    scales = (; X = (; ticks = 0:200:1000)))
```

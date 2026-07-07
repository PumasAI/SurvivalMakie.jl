# SurvivalMakie.jl

A plotting package for survival analysis, built on AlgebraOfGraphics and SurvivalModels.jl.
The single entry point is `survivalplot(table; time, status, ...)`, which prepares the
data itself (one `KaplanMeier(...)` fit per group) and hands tidy long-format tables to
AlgebraOfGraphics, then mutates the resulting layout to attach the risk table.

## Formatting

This project is formatted with [Runic](https://github.com/fredrikekre/Runic.jl), like
Makie and AlgebraOfGraphics. Do not use JuliaFormatter. Format before committing:

```
runic --inplace src test
```

## Tests

The suite has plain value tests plus PixelMatch reference-image tests:

```
julia --project=test test/runtests.jl
```

Reference images live in `test/reference_images/` as `*_ref.png`. To (re)generate them
after an intentional visual change, run with `JULIA_REFERENCETESTS_UPDATE=true` and commit
the updated `*_ref.png` files. The `*_rec.png`, `*_diff.png`, and the HTML report are
gitignored. Reference rendering is deterministic across operating systems (Makie bundles
its own fonts and FreeType), so a reference failure on CI points at a code or dependency
change, not the platform.

On CI, reference failures upload a self-contained PixelMatch HTML report (side-by-side
reference/recorded/diff) as an artifact, linked from a commit status.

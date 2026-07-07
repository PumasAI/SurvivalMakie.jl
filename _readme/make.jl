cd(@__DIR__)
using Pkg
Pkg.activate(".")
Pkg.instantiate()  # resolves SurvivalMakie via the [sources] entry in Project.toml

using quarto_jll

# Render with the quarto binary from quarto_jll instead of a system install, and point
# its julia engine at this environment (which carries QuartoNotebookRunner) so CI needs
# nothing beyond `julia --project=_readme _readme/make.jl`.
withenv(
    "QUARTO_JULIA" => first(Base.julia_cmd().exec),
    "QUARTO_JULIA_PROJECT" => @__DIR__,
) do
    run(`$(quarto_jll.quarto()) render README.qmd`)
end

mv("README.md", "../README.md", force = true)
mv("README_files/", "../README_files/", force = true)

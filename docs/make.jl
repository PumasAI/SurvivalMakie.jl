using SurvivalMakie
using Documenter
using Documenter: Remotes
using DocumenterVitepress
using CairoMakie

DocMeta.setdocmeta!(SurvivalMakie, :DocTestSetup, :(using SurvivalMakie); recursive = true)

makedocs(;
    sitename = "SurvivalMakie",
    authors = "Julius Krumbiegel and contributors",
    modules = [SurvivalMakie],
    repo = Remotes.GitHub("PumasAI", "SurvivalMakie.jl"),
    warnonly = get(ENV, "CI", "false") != "true",
    format = DocumenterVitepress.MarkdownVitepress(;
        repo = "https://github.com/PumasAI/SurvivalMakie.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Getting started" => "getting-started.md",
        "Guide" => "guide.md",
        "API" => "api.md",
    ],
    pagesonly = true,
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/PumasAI/SurvivalMakie.jl",
    target = joinpath(@__DIR__, "build"),
    branch = "gh-pages",
    devbranch = "main",
    push_preview = true,
)

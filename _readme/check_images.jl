cd(@__DIR__)
using Pkg
Pkg.activate(".")

using PixelMatch
using PNGFiles

# Compare the freshly rendered README images (working tree) against the committed ones
# (HEAD) with PixelMatch. PNG bytes are not reproducible across renders, so a raw `git
# diff` on the images is meaningless; what must stay stable is the rendered pixels. Run
# _readme/make.jl first so the working tree holds the regenerated images.
repo = normpath(joinpath(@__DIR__, ".."))
cd(repo)

committed = String[
    p for p in split(read(`git ls-tree -r --name-only HEAD README_files`, String), '\n'; keepempty = false)
        if endswith(p, ".png")
]

rendered = String[]
for (root, _, files) in walkdir("README_files")
    for f in files
        endswith(f, ".png") && push!(rendered, replace(relpath(joinpath(root, f), repo), '\\' => '/'))
    end
end

if Set(committed) != Set(rendered)
    only_committed = sort(collect(setdiff(Set(committed), Set(rendered))))
    only_rendered = sort(collect(setdiff(Set(rendered), Set(committed))))
    error(
        """
        README image set is out of date.
          committed but no longer rendered: $(isempty(only_committed) ? "none" : join(only_committed, ", "))
          rendered but not committed:       $(isempty(only_rendered) ? "none" : join(only_rendered, ", "))
        Run `julia --project=_readme _readme/make.jl` and commit the result.""",
    )
end

failures = String[]
for path in sort(committed)
    tmp = tempname() * ".png"
    open(tmp, "w") do io
        run(pipeline(`git show HEAD:$path`; stdout = io))
    end
    img_committed = PNGFiles.load(tmp)
    img_rendered = PNGFiles.load(path)

    if size(img_committed) != size(img_rendered)
        push!(failures, "$path: size $(size(img_committed)) (committed) vs $(size(img_rendered)) (rendered)")
        continue
    end

    n, _ = pixelmatch(img_committed, img_rendered)
    n > 0 && push!(failures, "$path: $n pixels differ")
end

if !isempty(failures)
    error(
        """
        README images do not match the committed versions:
        $(join("  " .* failures, '\n'))
        Run `julia --project=_readme _readme/make.jl` and commit the regenerated images.""",
    )
end

println("README images match the committed versions ($(length(committed)) image(s) checked).")

using Cairo
using Colors
using StableRNGs

const MAKIE_BLUE = colorant"#3182bb"
const MAKIE_RED = colorant"#dd3366"
const MAKIE_YELLOW = colorant"#e8cb26"

premultiply_white(c, w) = RGB((1 - w) * red(c) + w, (1 - w) * green(c) + w, (1 - w) * blue(c) + w)

function bary_weights(px, py, corners)
    (ax, ay), (bx, by), (cx, cy) = corners
    denom = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    wa = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / denom
    wb = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / denom
    return (wa, wb, 1 - wa - wb)
end

function makie_gradient(px, py, corners, colors; exponent = 2.1)
    w = clamp.(bary_weights(px, py, corners), 0, 1) .^ exponent
    s = sum(w)
    r = (w[1] * red(colors[1]) + w[2] * red(colors[2]) + w[3] * red(colors[3])) / s
    g = (w[1] * green(colors[1]) + w[2] * green(colors[2]) + w[3] * green(colors[3])) / s
    b = (w[1] * blue(colors[1]) + w[2] * blue(colors[2]) + w[3] * blue(colors[3])) / s
    return RGB(r, g, b)
end

function gradient_surface(N, corners, colors; whitemix = 0.0)
    pixels = Matrix{ARGB32}(undef, N, N)
    for iy in 1:N, ix in 1:N
        c = makie_gradient(ix - 0.5, iy - 0.5, corners, colors)
        pixels[ix, iy] = ARGB32(premultiply_white(c, whitemix))
    end
    return Cairo.CairoImageSurface(pixels)
end

function km_curve(rng; rate, tmax, n, z, base)
    events = sort(filter(<=(tmax), -log.(rand(rng, n)) ./ rate))
    ts = Float64[0.0]
    ss = Float64[1.0]
    ses = Float64[0.0]
    s = 1.0
    varterm = 0.0
    for i in 1:length(events)
        ni = n - (i - 1)
        s *= 1 - 1 / ni
        varterm += 1 / (ni * (ni - 1))
        push!(ts, events[i])
        push!(ss, s)
        push!(ses, s * sqrt(varterm))
    end
    push!(ts, 1.6tmax)
    push!(ss, ss[end])
    push!(ses, ses[end])

    halfwidth = base .+ z .* ses
    lower = ss .- halfwidth
    upper = ss .+ halfwidth
    return (; ts, ss, lower, upper)
end

function step_points(t, y)
    xs = Float64[t[1]]
    ys = Float64[y[1]]
    for i in 2:length(t)
        push!(xs, t[i]); push!(ys, y[i - 1])
        push!(xs, t[i]); push!(ys, y[i])
    end
    return xs, ys
end

# Outline of a width-`2h` stroke around a post-step staircase (horizontal run `i` at
# `ys[i]` over `xs[i]..xs[i+1]`, then a riser at `xs[i+1]`), as one simple polygon usable
# as an even-odd hole. The stroke is the union of the run and riser rectangles; since the
# staircase is monotone the union is x-simple (one vertical span per x), so its boundary is
# the top envelope traced left to right plus the bottom envelope traced back. Computed by
# sweeping the rectangle x-edges, which stays correct when runs or risers are thinner than
# the stroke (a per-corner offset would self-overlap and leave blocky artifacts there).
function staircase_outline(xs, ys, h)
    rects = NTuple{4, Float64}[]
    for i in 1:(length(xs) - 1)
        push!(rects, (xs[i], xs[i + 1], ys[i] - h, ys[i] + h))
        ys[i + 1] != ys[i] && push!(rects, (xs[i + 1] - h, xs[i + 1] + h, ys[i], ys[i + 1]))
    end

    edges = sort!(unique!(vcat(first.(rects), getindex.(rects, 2))))
    top = Tuple{Float64, Float64}[]
    bottom = Tuple{Float64, Float64}[]
    for k in 1:(length(edges) - 1)
        a, b = edges[k], edges[k + 1]
        mid = (a + b) / 2
        covering = filter(r -> r[1] <= mid <= r[2], rects)
        isempty(covering) && continue
        hi = minimum(r[3] for r in covering)
        lo = maximum(r[4] for r in covering)
        push!(top, (a, hi)); push!(top, (b, hi))
        push!(bottom, (a, lo)); push!(bottom, (b, lo))
    end

    outline = vcat(top, reverse(bottom))
    return first.(outline), last.(outline)
end

function draw_logo!(cr; N, seed = 1)
    rng = StableRNG(seed)
    tmax = 10.0

    curves = [
        (offset = 0.07, curve = km_curve(rng; rate = 0.032, tmax, n = 70, z = 1.89, base = 0.045)),
        (offset = 0.09, curve = km_curve(rng; rate = 0.09, tmax, n = 70, z = 1.68, base = 0.04)),
        (offset = 0.19, curve = km_curve(rng; rate = 0.36, tmax, n = 70, z = 2.1, base = 0.05)),
    ]

    corners = (
        (0.5N, 1.0N),        # blue, bottom
        (0.933N, 0.25N),     # red, upper right
        (0.067N, 0.25N),     # yellow, upper left
    )
    colors = (MAKIE_BLUE, MAKIE_RED, MAKIE_YELLOW)
    band_source = gradient_surface(N, corners, colors)

    xpad = 0.04N
    ypad = 0.04N
    tox(t) = xpad + (t / tmax) * (N - 2xpad)
    toy(s) = (N - ypad) - s * (N - 2ypad)

    linewidth = 0.012N

    Cairo.arc(cr, N / 2, N / 2, 0.46N, 0, 2pi)
    Cairo.clip(cr)

    Cairo.set_source_surface(cr, band_source, 0, 0)
    Cairo.set_fill_type(cr, Cairo.CAIRO_FILL_RULE_EVEN_ODD)
    for (; offset, curve) in curves
        bx, bu = step_points(curve.ts, curve.upper)
        _, bl = step_points(curve.ts, curve.lower)
        Cairo.move_to(cr, tox(bx[1]), toy(bu[1] - offset))
        for i in 2:length(bx)
            Cairo.line_to(cr, tox(bx[i]), toy(bu[i] - offset))
        end
        for i in length(bx):-1:1
            Cairo.line_to(cr, tox(bx[i]), toy(bl[i] - offset))
        end
        Cairo.close_path(cr)

        hx, hy = staircase_outline([tox(t) for t in curve.ts], [toy(s - offset) for s in curve.ss], linewidth / 2)
        Cairo.move_to(cr, hx[1], hy[1])
        for i in 2:length(hx)
            Cairo.line_to(cr, hx[i], hy[i])
        end
        Cairo.close_path(cr)

        Cairo.fill(cr)
    end

    return cr
end

function render_png(path; N = 800)
    surface = Cairo.CairoARGBSurface(N, N)
    draw_logo!(Cairo.CairoContext(surface); N)
    Cairo.write_to_png(surface, path)
    return path
end

function render_svg(path; N = 800)
    surface = Cairo.CairoSVGSurface(path, N, N)
    draw_logo!(Cairo.CairoContext(surface); N)
    Cairo.finish(surface)
    return path
end

const ASSETS = normpath(joinpath(@__DIR__, "..", "docs", "src", "assets"))
mkpath(ASSETS)
render_png(joinpath(ASSETS, "logo.png"))
render_svg(joinpath(ASSETS, "logo.svg"))

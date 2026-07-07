module SurvivalMakie

using SurvivalModels: KaplanMeier, confint, predict
using Tables: Tables
using AlgebraOfGraphics
using AlgebraOfGraphics: AxisEntries, FigureGrid, figure_settings
using AlgebraOfGraphics.Makie

export survivalplot

include("prepare.jl")
include("survivalplot.jl")
include("risktable.jl")

end # module

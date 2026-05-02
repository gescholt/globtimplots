# Notebook setup for GlobtimPlots examples
# This file loads the local Globtim package from ../globtim

using Pkg

println("🚀 Setting up GlobtimPlots notebook environment")
println("="^60)

# Activate the GlobtimPlots project environment
globtimplots_path = abspath(joinpath(@__DIR__, ".."))
isfile(joinpath(globtimplots_path, "Project.toml")) ||
    error("Cannot find GlobtimPlots Project.toml at $globtimplots_path")
println("Activating GlobtimPlots environment at: ", globtimplots_path)
Pkg.activate(globtimplots_path)

println("\nLoading required packages...")

using Globtim
println("  Globtim loaded")

using GlobtimPlots
println("  GlobtimPlots loaded")

using CairoMakie
println("  CairoMakie loaded")

using DataFrames
println("  DataFrames loaded")

println("\nNotebook setup complete!")
println("Available from Globtim:")
println("  - camel function")
println("  - TestInput constructor")
println("  - Constructor for polynomial approximation")
println("  - RationalPrecision")
println("  - solve_polynomial_system")
println("  - process_crit_pts")
println("  - analyze_critical_points")

println("Available from GlobtimPlots:")
println("  - cairo_plot_polyapprox_levelset")
println("  - AbstractPolynomialData, AbstractProblemInput")
println("  - adapt_polynomial_data, adapt_problem_input")

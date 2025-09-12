# Notebook setup for GlobtimPlots examples
# This file loads the local Globtim package from ../globtim

using Pkg

println("🚀 Setting up GlobtimPlots notebook environment")
println("=" ^ 60)

# Activate the local Globtim package development environment
globtim_path = abspath(joinpath(@__DIR__, "..", "..", "globtim"))
if isdir(globtim_path)
    println("📦 Activating Globtim environment at: ", globtim_path)
    Pkg.activate(globtim_path)
    
    # Add the current GlobtimPlots package in development mode
    globtimplots_path = abspath(joinpath(@__DIR__, ".."))
    if isdir(globtimplots_path)
        println("📦 Adding GlobtimPlots in dev mode from: ", globtimplots_path)
        try
            Pkg.develop(path=globtimplots_path)
        catch e
            println("⚠️  GlobtimPlots already in dev mode or error: ", e)
        end
    end
    
    println("\n📋 Loading required packages...")
    
    # Load required packages
    try
        using Globtim
        println("  ✅ Globtim")
    catch e
        println("  ❌ Globtim: ", e)
    end
    
    try
        using GlobtimPlots
        println("  ✅ GlobtimPlots")
    catch e
        println("  ❌ GlobtimPlots: ", e)
    end
    
    try
        using CairoMakie
        println("  ✅ CairoMakie")
    catch e
        println("  ❌ CairoMakie: ", e)
    end
    
    try
        using DataFrames
        println("  ✅ DataFrames")
    catch e
        println("  ❌ DataFrames: ", e)
    end
    
    println("\n✅ Notebook setup complete!")
    println("📋 Available from Globtim:")
    println("  - camel function")
    println("  - test_input constructor") 
    println("  - Constructor for polynomial approximation")
    println("  - RationalPrecision")
    println("  - solve_polynomial_system")
    println("  - process_crit_pts")
    println("  - analyze_critical_points")
    
    println("📋 Available from GlobtimPlots:")
    println("  - cairo_plot_polyapprox_levelset")
    println("  - AbstractPolynomialData, AbstractProblemInput")
    println("  - adapt_polynomial_data, adapt_problem_input")
    
else
    error("❌ Globtim directory not found at: $globtim_path")
end
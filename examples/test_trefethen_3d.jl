#!/usr/bin/env julia

"""
Test script for Trefethen 3D function
This script tests the updated solve_polynomial_system pattern with basis/precision/normalized parameters
"""

# Set up the examples environment with local packages
using Pkg
Pkg.activate(@__DIR__)

# Add local development packages if not already added
examples_dir = @__DIR__
globoptim_dir = dirname(examples_dir)  # Go up from examples/ to globtimplots/
root_dir = dirname(globoptim_dir)  # Go up from globtimplots/ to GlobalOptim/

globtimcore_path = joinpath(root_dir, "globtimcore")
globtimpostproc_path = joinpath(root_dir, "globtimpostprocessing")
globtimplots_path = globoptim_dir

# Develop local packages if they're not already in the environment
if !haskey(Pkg.project().dependencies, "Globtim")
    println("Adding Globtim from: $globtimcore_path")
    Pkg.develop(path=globtimcore_path)
end

if !haskey(Pkg.project().dependencies, "GlobtimPostProcessing")
    println("Adding GlobtimPostProcessing from: $globtimpostproc_path")
    Pkg.develop(path=globtimpostproc_path)
end

if !haskey(Pkg.project().dependencies, "GlobtimPlots")
    println("Adding GlobtimPlots from: $globtimplots_path")
    Pkg.develop(path=globtimplots_path)
end

# Install all dependencies
Pkg.instantiate()

using Globtim
using DynamicPolynomials: @polyvar
using DataFrames
using StaticArrays

# Use Trefethen 3D function from LibFunctions
f = Globtim.tref_3d  # Use the library version which properly couples all 3 dimensions

# Constants and Parameters
const n, a, b = 3, 12, 100
const scale_factor = a / b   # Scaling factor

# Setup
center = [0.0, 0.0, 0.0]
d = 14  # initial degree
SMPL = 30  # Number of samples

println("Setting up test input...")
TR = test_input(f,
                dim = n,
                center = center,
                GN = SMPL,
                sample_range = scale_factor
                )

println("Constructing polynomial approximation...")
pol_cheb = Constructor(TR, d, basis=:chebyshev, precision=RationalPrecision)

println("Defining polynomial ring...")
@polyvar(x[1:n])

println("Solving polynomial system...")
# New pattern: store intermediate result and pass basis/precision/normalized
real_pts_cheb = solve_polynomial_system(
    x, n, d, pol_cheb.coeffs;
    basis=pol_cheb.basis,
    precision=pol_cheb.precision,
    normalized=pol_cheb.normalized,
)

println("Processing critical points...")
df_cheb = process_crit_pts(real_pts_cheb, f, TR)
sort!(df_cheb, :z, rev=false)

println("\nResults:")
println("Number of critical points found: ", nrow(df_cheb))
println("\nFirst few critical points:")
println(first(df_cheb, 5))

# Generate grid for visualization
println("\nGenerating visualization grid...")
grid = scale_factor * generate_grid(3, 100)  # 3D grid with 100 points per dimension

# Load visualization backend and package
println("Loading GLMakie backend...")
using GLMakie

# FORCE native window backend (not inline PNG rendering)
GLMakie.activate!(; inline = false)

println("Loading GlobtimPlots for visualization...")
using GlobtimPlots

# Create interactive level set visualization
println("\nCreating interactive level set visualization...")
println("Use the slider to change the level value and explore the level sets.")
println("Critical points from the DataFrame are shown as orange diamonds.")

# Create visualization with tighter tolerance for cleaner level sets
viz_params = GlobtimPlots.VisualizationParameters(
    point_tolerance = 0.05,  # Tighter tolerance (was 0.1)
    point_window = 0.1,
    fig_size = (1200, 900)
)

fig = create_level_set_visualization(f, grid, df_cheb, (-3.0, 6.0), viz_params)

println("\n✓ Visualization created! Interact with the slider to explore different level sets.")
println("  Blue points: Level set surface")
println("  Orange diamonds: Critical points at the current level")

# Display in native GLMakie window (not inline rendering)
screen = display(GLMakie.Screen(), fig)

println("\n→ Interactive GLMakie window displayed!")
println("   Press Enter in this terminal to close the window...")
readline()

println("Closing visualization...")
close(screen)

#!/usr/bin/env julia

"""
Test script for Trefethen 3D function
This script tests the updated solve_polynomial_system pattern with basis/precision/normalized parameters
"""

# Adaptive path procedure to load dependencies
using Pkg

# Try to find and activate the GlobtimPlots project
# First check if we're already in the right environment
let
    if !haskey(Pkg.project().dependencies, "GlobtimPlots") && !haskey(Pkg.project().dependencies, "Globtim")
        # Walk up the directory tree to find Project.toml with GlobtimPlots
        current_dir = @__DIR__
        project_found = false

        for _ in 1:5  # Limit search depth to avoid infinite loops
            project_file = joinpath(current_dir, "Project.toml")
            if isfile(project_file)
                # Check if this is the GlobtimPlots project
                project_content = read(project_file, String)
                if occursin("GlobtimPlots", project_content)
                    Pkg.activate(current_dir)
                    project_found = true
                    break
                end
            end
            # Move up one directory
            parent_dir = dirname(current_dir)
            if parent_dir == current_dir  # Reached root
                break
            end
            current_dir = parent_dir
        end

        if !project_found
            @warn "Could not find GlobtimPlots project. Using default environment."
        end
    end
end

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

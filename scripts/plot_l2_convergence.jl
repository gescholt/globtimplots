#!/usr/bin/env julia
"""
Plot L2 convergence by degree with trial paths.

Usage:
    julia --project=<globtimplots_path> plot_l2_convergence.jl <results_dir> [output.pdf]

Example:
    julia --project=path/to/globtimplots plot_l2_convergence.jl \\
        path/to/globtim_results/lotka_volterra_4d/<comparison_dir>
"""

using Pkg

# Activate globtimplots — script is inside globtimplots/scripts/
globtimplots_path = abspath(joinpath(@__DIR__, ".."))
isfile(joinpath(globtimplots_path, "Project.toml")) || error("Cannot find globtimplots Project.toml at $globtimplots_path. Run this script from within the globtimplots/scripts/ directory or use --project=<globtimplots_path>.")
Pkg.activate(globtimplots_path)

using GlobtimPlots
using CSV
using DataFrames

if length(ARGS) < 1
    println("Usage: julia plot_l2_convergence.jl <results_dir> [output.pdf]")
    exit(1)
end

results_dir = ARGS[1]
output_file = length(ARGS) >= 2 ? ARGS[2] : "l2_convergence.pdf"

csv_path = joinpath(results_dir, "comparison_results.csv")
if !isfile(csv_path)
    error("comparison_results.csv not found at: $csv_path")
end

df = CSV.read(csv_path, DataFrame)

# Verify required columns
required_cols = [:degree, :l2_error, :seed, :method]
missing_cols = setdiff(required_cols, Symbol.(names(df)))
if !isempty(missing_cols)
    error("Missing required columns: $missing_cols")
end

println("Loaded $(nrow(df)) rows from $csv_path")
println("Methods: $(unique(df.method))")
println("Degrees: $(sort(unique(df.degree)))")
println("Seeds: $(length(unique(df.seed)))")

# Plot all domains combined
fig = plot_l2_convergence_trials(df, title="L2 Convergence: Log vs Standard")
save(output_file, fig)
println("Saved: $output_file")

# Per-domain plots if multiple domains
if :domain in Symbol.(names(df))
    domains = unique(df.domain)
    if length(domains) > 1
        println("\nGenerating per-domain plots...")
        for dom in sort(domains)
            output_dom = replace(output_file, ".pdf" => "_dom$(dom).pdf")
            fig_dom = plot_l2_convergence_trials(df,
                domain_filter=dom,
                title="L2 Convergence (domain=$dom)"
            )
            save(output_dom, fig_dom)
            println("Saved: $output_dom")
        end
    end
end

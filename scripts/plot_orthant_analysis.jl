#!/usr/bin/env julia
"""
V4: Per-Orthant Analysis Visualization

Visualizes why subdivision fails by showing:
1. Critical points per orthant
2. Best polynomial minimum per orthant
3. L2 approximation error per orthant

Key insight: Algorithm selects wrong orthant because the global polynomial minimum
is in a different orthant than p_true.

Usage:
    julia --project=path/to/globtimplots plot_orthant_analysis.jl \\
        --experiment-dir path/to/globtim_results/lotka_volterra_4d/<experiment_dir>
"""

const SCRIPT_DIR = @__DIR__

using Pkg
# Activate globtimplots — script is inside globtimplots/scripts/
const GLOBTIMPLOTS_ROOT = abspath(joinpath(SCRIPT_DIR, ".."))
isfile(joinpath(GLOBTIMPLOTS_ROOT, "Project.toml")) || error("Cannot find globtimplots Project.toml at $GLOBTIMPLOTS_ROOT. Run this script from within globtimplots/scripts/ or use --project=<globtimplots_path>.")
Pkg.activate(GLOBTIMPLOTS_ROOT)

using CairoMakie
using JSON
using ArgParse
using Printf

"""
    point_to_orthant(point, center) -> Int

Compute which orthant (1-indexed) contains a point relative to center.

Orthants are numbered using binary encoding:
- Orthant 1: all dimensions negative (0000)
- Orthant 2: dim1 positive, rest negative (0001)
- ...
- Orthant 16: all dimensions positive (1111)
"""
function point_to_orthant(point, center)
    signs = sign.(point .- center)
    # Convert signs (-1,1) to bits (0,1), then to orthant index
    bits = [(s > 0 ? 1 : 0) for s in signs]
    return sum(bits[i] * 2^(i-1) for i in eachindex(bits)) + 1
end

"""
    orthant_to_signs(orthant_idx, ndims) -> Vector{String}

Convert orthant index to sign pattern for display.
"""
function orthant_to_signs(orthant_idx, ndims)
    bits = digits(orthant_idx - 1, base=2, pad=ndims)
    return [b == 1 ? "+" : "-" for b in bits]
end

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--experiment-dir"
            help = "Path to subdivision experiment results"
            arg_type = String
            required = true
        "--output"
            help = "Output file path (default: orthant_analysis.pdf in experiment dir)"
            arg_type = String
            default = nothing
        "--show"
            help = "Display plot interactively"
            action = :store_true
    end
    return parse_args(s)
end

function load_orthant_data(experiment_dir)
    results_path = joinpath(experiment_dir, "results_summary.json")
    config_path = joinpath(experiment_dir, "experiment_config.json")

    if !isfile(results_path)
        error("results_summary.json not found in $experiment_dir")
    end
    if !isfile(config_path)
        error("experiment_config.json not found in $experiment_dir")
    end

    results = JSON.parsefile(results_path)
    config = JSON.parsefile(config_path)

    # Handle both array and single-object formats
    result_data = results isa Vector ? results[1] : results

    return (
        orthant_stats = result_data["orthant_stats"],
        p_true = Float64.(config["p_true"]),
        p_center = Float64.(config["p_center"]),
        domain_range = config["domain_range"],
        recovery_error = result_data["recovery_error"],
        total_critical_points = result_data["total_critical_points"]
    )
end

function create_orthant_analysis_plot(data)
    orthant_stats = data.orthant_stats
    n_orthants = length(orthant_stats)
    ndims = length(data.p_true)

    # Find key orthants
    true_orthant = point_to_orthant(data.p_true, data.p_center)
    best_values = [s["best_value"] for s in orthant_stats]
    best_orthant = orthant_stats[argmin(best_values)]["orthant"]

    # Extract data
    orthants = [s["orthant"] for s in orthant_stats]
    cpts = [s["critical_points"] for s in orthant_stats]
    l2_norms = [s["L2_norm"] for s in orthant_stats]

    # Color scheme: green = contains p_true, red = selected, blue = other
    colors = [o == true_orthant ? :green :
              (o == best_orthant ? :red : :steelblue)
              for o in orthants]

    # Create figure
    fig = Figure(size=(1400, 500), fontsize=12)

    # Panel 1: Critical points per orthant
    ax1 = Axis(fig[1, 1],
        xlabel="Orthant",
        ylabel="Critical Points",
        title="Critical Points per Orthant",
        xticks=1:n_orthants
    )
    barplot!(ax1, orthants, cpts, color=colors)

    # Panel 2: Best f(p) per orthant (log scale)
    ax2 = Axis(fig[1, 2],
        xlabel="Orthant",
        ylabel="Best f(p)",
        title="Best Polynomial Minimum per Orthant",
        yscale=log10,
        xticks=1:n_orthants
    )
    barplot!(ax2, orthants, best_values, color=colors)

    # Add horizontal line at best value
    hlines!(ax2, [minimum(best_values)], color=:black, linestyle=:dash, linewidth=1)

    # Panel 3: L2 approximation error per orthant
    ax3 = Axis(fig[1, 3],
        xlabel="Orthant",
        ylabel="L2 Norm",
        title="Polynomial Approximation Error",
        xticks=1:n_orthants
    )
    barplot!(ax3, orthants, l2_norms, color=colors)

    # Legend
    true_signs = join(orthant_to_signs(true_orthant, ndims), ",")
    best_signs = join(orthant_to_signs(best_orthant, ndims), ",")

    Legend(fig[2, :],
        [PolyElement(color=:green),
         PolyElement(color=:red),
         PolyElement(color=:steelblue)],
        ["Contains p_true: Orthant $true_orthant ($true_signs)",
         "Selected (global min): Orthant $best_orthant ($best_signs)",
         "Other orthants"],
        orientation=:horizontal,
        framevisible=false
    )

    return fig, (true_orthant=true_orthant, best_orthant=best_orthant,
                 true_signs=true_signs, best_signs=best_signs)
end

function print_summary(data, analysis)
    orthant_stats = data.orthant_stats

    # Get stats for key orthants
    true_stats = orthant_stats[analysis.true_orthant]
    best_stats = orthant_stats[analysis.best_orthant]

    println()
    println("="^70)
    println("ORTHANT ANALYSIS SUMMARY")
    println("="^70)
    println()

    println("p_true is in Orthant $(analysis.true_orthant) (signs: $(analysis.true_signs))")
    println("  - Critical points: $(true_stats["critical_points"])")
    println("  - Best value: $(@sprintf("%.1f", true_stats["best_value"]))")
    println("  - L2 norm: $(@sprintf("%.1f", true_stats["L2_norm"]))")
    println()

    println("Algorithm selected Orthant $(analysis.best_orthant) (signs: $(analysis.best_signs))")
    println("  - Critical points: $(best_stats["critical_points"])")
    println("  - Best value: $(@sprintf("%.2f", best_stats["best_value"])) <- GLOBAL MINIMUM")
    println("  - L2 norm: $(@sprintf("%.1f", best_stats["L2_norm"]))")
    println()

    if analysis.true_orthant != analysis.best_orthant
        println("MISMATCH: Algorithm chose orthant $(analysis.best_orthant), but p_true is in orthant $(analysis.true_orthant)")
        println("This explains the $(@sprintf("%.1f%%", data.recovery_error * 100)) recovery error.")
    else
        println("MATCH: Algorithm correctly identified the orthant containing p_true.")
    end

    println()
    println("-"^70)
    println("Per-orthant breakdown:")
    println("-"^70)
    println(@sprintf("%-8s %-12s %-15s %-12s", "Orthant", "Crit Pts", "Best f(p)", "L2 Norm"))
    println("-"^70)

    for s in orthant_stats
        marker = ""
        if s["orthant"] == analysis.true_orthant
            marker = " [p_true]"
        elseif s["orthant"] == analysis.best_orthant
            marker = " [selected]"
        end
        println(@sprintf("%-8d %-12d %-15.2f %-12.1f%s",
            s["orthant"], s["critical_points"], s["best_value"], s["L2_norm"], marker))
    end

    println("-"^70)
    println("Total critical points: $(data.total_critical_points)")
    println()
end

function main()
    args = parse_commandline()

    experiment_dir = args["experiment-dir"]
    if !isabspath(experiment_dir)
        experiment_dir = abspath(experiment_dir)
    end

    # Load data
    data = load_orthant_data(experiment_dir)

    # Create visualization
    fig, analysis = create_orthant_analysis_plot(data)

    # Print summary
    print_summary(data, analysis)

    # Save figure
    output_path = args["output"]
    if output_path === nothing
        output_path = joinpath(experiment_dir, "orthant_analysis.pdf")
    end

    save(output_path, fig)
    println("Saved: $output_path")

    # Also save PNG for quick viewing
    png_path = replace(output_path, ".pdf" => ".png")
    save(png_path, fig, px_per_unit=2)
    println("Saved: $png_path")

    if args["show"]
        display(fig)
        println("\nPress Enter to close...")
        readline()
    end

    return fig
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

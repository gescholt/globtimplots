"""
Experiment Results Plotting Module for @globtimplots

Functions for plotting cluster experiment results including:
- L2 norm convergence
- Euclidean distance to true parameters
- Condition number analysis
- Parameter recovery metrics

Uses GLMakie for interactive windows and CairoMakie for static file output.
"""

using DataFrames, Statistics
using Printf

# Import backends explicitly
# NOTE: GLMakie removed - causes macOS precompilation segfault
# For interactive plots, users should: using GLMakie; Makie.activate!()
import CairoMakie
using Makie  # Backend-agnostic Makie API

"""
    plot_experiment_results_interactive(
        experiment_name::String,
        metrics::NamedTuple
    )

Create interactive GLMakie window showing experiment results.
Window supports zoom, pan, and interactive exploration.

Parameters:
- `experiment_name`: Name of experiment for title
- `metrics`: NamedTuple with fields: degrees, l2_norms, min_distances, mean_distances, condition_numbers
"""
function plot_experiment_results_interactive(
    experiment_name::String,
    metrics::NamedTuple
)
    # Use GLMakie for interactive display
    fig = Makie.Figure(size = (1400, 900))

    # Plot 1: L2 Norm vs Degree
    ax1 = Makie.Axis(fig[1, 1],
        title = "L2 Norm of Polynomial Approximation",
        xlabel = "Polynomial Degree",
        ylabel = "L2 Norm (log scale)",
        yscale = log10
    )
    Makie.scatterlines!(ax1, metrics.degrees, metrics.l2_norms,
        color = :blue, markersize = 15, linewidth = 3,
        label = "L2 Approximation Error")
    Makie.axislegend(ax1, position = :rt)

    # Plot 2: Euclidean Distance to True Parameters
    has_distances = any(!isnan, metrics.min_distances)
    if has_distances
        ax2 = Makie.Axis(fig[1, 2],
            title = "Euclidean Distance to True Parameters",
            xlabel = "Polynomial Degree",
            ylabel = "Distance (log scale)",
            yscale = log10
        )

        # Min distance (best critical point)
        Makie.scatterlines!(ax2, metrics.degrees, metrics.min_distances,
            color = :green, markersize = 15, linewidth = 3,
            label = "Min Distance")

        # Mean distance (average over all critical points)
        if any(!isnan, metrics.mean_distances)
            Makie.scatterlines!(ax2, metrics.degrees, metrics.mean_distances,
                color = :orange, markersize = 12, linewidth = 2,
                label = "Mean Distance", linestyle = :dash)
        end

        Makie.axislegend(ax2, position = :rt)
    else
        ax2 = Makie.Axis(fig[1, 2],
            title = "Distance to True Parameters (N/A)",
            xlabel = "Polynomial Degree",
            ylabel = "Distance"
        )
        Makie.text!(ax2, "No true parameters available\nfor this experiment",
            position = (mean(metrics.degrees), 0.5),
            align = (:center, :center),
            fontsize = 16)
    end

    # Plot 3: Condition Number vs Degree
    has_conditions = any(!isnan, metrics.condition_numbers)
    if has_conditions
        ax3 = Makie.Axis(fig[2, 1],
            title = "Condition Number (Numerical Stability)",
            xlabel = "Polynomial Degree",
            ylabel = "Condition Number"
        )
        Makie.scatterlines!(ax3, metrics.degrees, metrics.condition_numbers,
            color = :red, markersize = 15, linewidth = 3,
            label = "Condition Number")
        Makie.axislegend(ax3, position = :rt)
    end

    # Plot 4: Convergence Rate Analysis
    if has_distances && length(metrics.min_distances) >= 2
        valid_idx = findall(!isnan, metrics.min_distances)
        if length(valid_idx) >= 2
            ax4 = Makie.Axis(fig[2, 2],
                title = "Parameter Convergence Rate",
                xlabel = "Polynomial Degree",
                ylabel = "Convergence Rate (log scale)",
                yscale = log10
            )

            # Compute rate: ratio of consecutive distances
            conv_rates = Float64[]
            conv_degrees = Float64[]
            for i in 2:length(valid_idx)
                idx_prev = valid_idx[i-1]
                idx_curr = valid_idx[i]
                rate = metrics.min_distances[idx_prev] / metrics.min_distances[idx_curr]
                push!(conv_rates, rate)
                push!(conv_degrees, metrics.degrees[idx_curr])
            end

            if !isempty(conv_rates)
                Makie.scatterlines!(ax4, conv_degrees, conv_rates,
                    color = :purple, markersize = 15, linewidth = 3,
                    label = "Convergence Factor")
                Makie.axislegend(ax4, position = :rt)
            end
        end
    end

    # Add overall title
    if !isempty(experiment_name)
        Makie.Label(fig[0, :], "Experiment: $experiment_name", fontsize = 20, tellwidth = false)
    end

    # Display interactive window
    display(fig)

    return fig
end

"""
    plot_experiment_results_static(
        experiment_name::String,
        metrics::NamedTuple;
        output_file::String = "experiment_results.png"
    )

Create static PNG/PDF/SVG plot using CairoMakie and save to file.

Parameters:
- `experiment_name`: Name of experiment for title
- `metrics`: NamedTuple with fields: degrees, l2_norms, min_distances, mean_distances, condition_numbers
- `output_file`: Path to save file (extension determines format: .png, .pdf, .svg)

Returns:
- Path to saved file
"""
function plot_experiment_results_static(
    experiment_name::String,
    metrics::NamedTuple;
    output_file::String = "experiment_results.png"
)
    # Use CairoMakie for static output
    fig = CairoMakie.Figure(size = (1400, 900))

    # Plot 1: L2 Norm vs Degree
    ax1 = CairoMakie.Axis(fig[1, 1],
        title = "L2 Norm of Polynomial Approximation",
        xlabel = "Polynomial Degree",
        ylabel = "L2 Norm (log scale)",
        yscale = log10
    )
    CairoMakie.scatterlines!(ax1, metrics.degrees, metrics.l2_norms,
        color = :blue, markersize = 15, linewidth = 3,
        label = "L2 Approximation Error")
    CairoMakie.axislegend(ax1, position = :rt)

    # Plot 2: Euclidean Distance to True Parameters
    has_distances = any(!isnan, metrics.min_distances)
    if has_distances
        ax2 = CairoMakie.Axis(fig[1, 2],
            title = "Euclidean Distance to True Parameters",
            xlabel = "Polynomial Degree",
            ylabel = "Distance (log scale)",
            yscale = log10
        )

        # Min distance (best critical point)
        CairoMakie.scatterlines!(ax2, metrics.degrees, metrics.min_distances,
            color = :green, markersize = 15, linewidth = 3,
            label = "Min Distance")

        # Mean distance (average over all critical points)
        if any(!isnan, metrics.mean_distances)
            CairoMakie.scatterlines!(ax2, metrics.degrees, metrics.mean_distances,
                color = :orange, markersize = 12, linewidth = 2,
                label = "Mean Distance", linestyle = :dash)
        end

        CairoMakie.axislegend(ax2, position = :rt)
    else
        ax2 = CairoMakie.Axis(fig[1, 2],
            title = "Distance to True Parameters (N/A)",
            xlabel = "Polynomial Degree",
            ylabel = "Distance"
        )
        CairoMakie.text!(ax2, "No true parameters available\nfor this experiment",
            position = (mean(metrics.degrees), 0.5),
            align = (:center, :center),
            fontsize = 16)
    end

    # Plot 3: Condition Number vs Degree
    has_conditions = any(!isnan, metrics.condition_numbers)
    if has_conditions
        ax3 = CairoMakie.Axis(fig[2, 1],
            title = "Condition Number (Numerical Stability)",
            xlabel = "Polynomial Degree",
            ylabel = "Condition Number"
        )
        CairoMakie.scatterlines!(ax3, metrics.degrees, metrics.condition_numbers,
            color = :red, markersize = 15, linewidth = 3,
            label = "Condition Number")
        CairoMakie.axislegend(ax3, position = :rt)
    end

    # Plot 4: Convergence Rate Analysis
    if has_distances && length(metrics.min_distances) >= 2
        valid_idx = findall(!isnan, metrics.min_distances)
        if length(valid_idx) >= 2
            ax4 = CairoMakie.Axis(fig[2, 2],
                title = "Parameter Convergence Rate",
                xlabel = "Polynomial Degree",
                ylabel = "Convergence Rate (log scale)",
                yscale = log10
            )

            # Compute rate: ratio of consecutive distances
            conv_rates = Float64[]
            conv_degrees = Float64[]
            for i in 2:length(valid_idx)
                idx_prev = valid_idx[i-1]
                idx_curr = valid_idx[i]
                rate = metrics.min_distances[idx_prev] / metrics.min_distances[idx_curr]
                push!(conv_rates, rate)
                push!(conv_degrees, metrics.degrees[idx_curr])
            end

            if !isempty(conv_rates)
                CairoMakie.scatterlines!(ax4, conv_degrees, conv_rates,
                    color = :purple, markersize = 15, linewidth = 3,
                    label = "Convergence Factor")
                CairoMakie.axislegend(ax4, position = :rt)
            end
        end
    end

    # Add overall title
    if !isempty(experiment_name)
        CairoMakie.Label(fig[0, :], "Experiment: $experiment_name", fontsize = 20, tellwidth = false)
    end

    # Save to file
    CairoMakie.save(output_file, fig, px_per_unit = 2)

    return output_file
end

export plot_experiment_results_static, plot_experiment_results_interactive
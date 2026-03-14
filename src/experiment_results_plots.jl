"""
Experiment Results Plotting Module for @globtimplots

Functions for plotting cluster experiment results including:
- L2 norm convergence
- Euclidean distance to true parameters
- Condition number analysis
- Parameter recovery metrics

Uses the abstract Makie API (backend-agnostic).
"""

using DataFrames, Statistics
using Printf

"""
    _build_experiment_results_figure(experiment_name, metrics; fig_size) → Figure

Internal: build the 4-panel experiment results figure using backend-agnostic
Makie calls.  Both the interactive and static entry points delegate here.
"""
function _build_experiment_results_figure(
    experiment_name::String,
    metrics::NamedTuple;
    fig_size::Tuple{Int,Int} = (1400, 900)
)
    fig = Figure(size = fig_size)

    # Plot 1: L2 Norm vs Degree
    ax1 = Axis(fig[1, 1],
        title = "L2 Norm of Polynomial Approximation",
        xlabel = "Polynomial Degree",
        ylabel = "L2 Norm (log scale)",
        yscale = log10
    )
    scatterlines!(ax1, metrics.degrees, metrics.l2_norms,
        color = :blue, markersize = 15, linewidth = 3,
        label = "L2 Approximation Error")
    axislegend(ax1, position = :rt)

    # Plot 2: Euclidean Distance to True Parameters
    has_distances = any(!isnan, metrics.min_distances)
    if has_distances
        ax2 = Axis(fig[1, 2],
            title = "Euclidean Distance to True Parameters",
            xlabel = "Polynomial Degree",
            ylabel = "Distance (log scale)",
            yscale = log10
        )

        # Min distance (best critical point)
        scatterlines!(ax2, metrics.degrees, metrics.min_distances,
            color = :green, markersize = 15, linewidth = 3,
            label = "Min Distance")

        # Mean distance (average over all critical points)
        if any(!isnan, metrics.mean_distances)
            scatterlines!(ax2, metrics.degrees, metrics.mean_distances,
                color = :orange, markersize = 12, linewidth = 2,
                label = "Mean Distance", linestyle = :dash)
        end

        axislegend(ax2, position = :rt)
    else
        ax2 = Axis(fig[1, 2],
            title = "Distance to True Parameters (N/A)",
            xlabel = "Polynomial Degree",
            ylabel = "Distance"
        )
        text!(ax2, "No true parameters available\nfor this experiment",
            position = (mean(metrics.degrees), 0.5),
            align = (:center, :center),
            fontsize = 16)
    end

    # Plot 3: Condition Number vs Degree
    has_conditions = any(!isnan, metrics.condition_numbers)
    if has_conditions
        ax3 = Axis(fig[2, 1],
            title = "Condition Number (Numerical Stability)",
            xlabel = "Polynomial Degree",
            ylabel = "Condition Number"
        )
        scatterlines!(ax3, metrics.degrees, metrics.condition_numbers,
            color = :red, markersize = 15, linewidth = 3,
            label = "Condition Number")
        axislegend(ax3, position = :rt)
    end

    # Plot 4: Convergence Rate Analysis
    if has_distances && length(metrics.min_distances) >= 2
        valid_idx = findall(!isnan, metrics.min_distances)
        if length(valid_idx) >= 2
            ax4 = Axis(fig[2, 2],
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
                scatterlines!(ax4, conv_degrees, conv_rates,
                    color = :purple, markersize = 15, linewidth = 3,
                    label = "Convergence Factor")
                axislegend(ax4, position = :rt)
            end
        end
    end

    # Add overall title
    if !isempty(experiment_name)
        Label(fig[0, :], "Experiment: $experiment_name", fontsize = 20, tellwidth = false)
    end

    return fig
end

"""
    plot_experiment_results_interactive(experiment_name, metrics; fig_size)

Create interactive window showing experiment results.
Delegates to the shared figure builder, then calls `display`.

Parameters:
- `experiment_name`: Name of experiment for title
- `metrics`: NamedTuple with fields: degrees, l2_norms, min_distances, mean_distances, condition_numbers
"""
function plot_experiment_results_interactive(
    experiment_name::String,
    metrics::NamedTuple;
    fig_size::Tuple{Int,Int} = (1400, 900)
)
    fig = _build_experiment_results_figure(experiment_name, metrics; fig_size)
    display(fig)
    return fig
end

"""
    plot_experiment_results_static(experiment_name, metrics; output_file, fig_size)

Create static PNG/PDF/SVG plot and save to file.

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
    output_file::String = "experiment_results.png",
    fig_size::Tuple{Int,Int} = (1400, 900)
)
    fig = _build_experiment_results_figure(experiment_name, metrics; fig_size)
    save(output_file, fig, px_per_unit = 2)
    return output_file
end

export plot_experiment_results_static, plot_experiment_results_interactive

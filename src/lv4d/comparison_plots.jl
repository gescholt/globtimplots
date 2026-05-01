"""
Comparison plots for LV4D experiments.

Degree comparison, GN comparison, heatmap visualizations, and parameter comparison.
"""

# ============================================================================
# Parameter Comparison Bar Chart
# ============================================================================

"""
    plot_parameter_comparison(p_true, p_estimated; labels, title)

Side-by-side bar plot comparing true vs estimated parameters.

# Arguments
- `p_true::Vector`: True parameter values
- `p_estimated::Vector`: Estimated parameter values
- `labels::Vector{String}`: Parameter labels (default: ["α", "β", "γ", "δ"])
- `title::String`: Plot title

# Returns
Figure with grouped bar chart comparing true vs estimated parameters.

# Example
```julia
fig = plot_parameter_comparison([0.2, 0.3, 0.5, 0.6], [0.201, 0.299, 0.502, 0.598])
save("comparison.png", fig)
```
"""
function plot_parameter_comparison(
    p_true::Vector,
    p_estimated::Vector;
    labels::Vector{String} = ["α", "β", "γ", "δ"],
    title::String = "LV4D Parameter Recovery",
    fig_size::Tuple{Int,Int} = (700, 400),
)
    n = length(p_true)
    length(p_estimated) == n || error("p_true and p_estimated must have same length")
    length(labels) == n || error("labels must have same length as parameters")

    fig = Figure(size = fig_size)
    ax = Axis(
        fig[1, 1],
        title = title,
        xlabel = "Parameter",
        ylabel = "Value",
        xticks = (1:n, labels),
    )

    barplot!(ax, (1:n) .- 0.15, p_true, width = 0.25, color = :steelblue, label = "True")
    barplot!(
        ax,
        (1:n) .+ 0.15,
        p_estimated,
        width = 0.25,
        color = :coral,
        label = "Estimated",
    )
    axislegend(ax, position = :lt)

    return fig
end

# ============================================================================
# Degree Comparison Plot
# ============================================================================

"""
    plot_lv4d_degree_comparison(df::DataFrame; domain_filter=nothing, gn_filter=nothing,
                                metrics=[:mean_recovery, :mean_L2, :success_rate])

Multi-panel plot comparing metrics across degrees for fixed domain.

# Arguments
- `df::DataFrame`: Aggregated data with domain, degree, GN columns
- `domain_filter`: Domain value to filter by (uses minimum if not specified)
- `gn_filter`: Optional GN value to filter by
- `metrics`: Vector of metrics to plot (from aggregated columns)

# Returns
Figure with one panel per metric.

# Available Metrics
- mean_recovery: Mean ||p_best - p_true|| / ||p_true||
- mean_L2: Mean ||f - w_d||_L2
- success_rate: Fraction with recovery_error < 5%
- mean_grad_valid: Mean gradient validation rate
"""
function plot_lv4d_degree_comparison(
    df::DataFrame;
    domain_filter = nothing,
    gn_filter = nothing,
    metrics::Vector{Symbol} = [:mean_recovery, :mean_L2, :success_rate],
    fig_size::Union{Tuple{Int,Int},Nothing} = nothing,
)
    df_plot = copy(df)

    # Apply GN filter
    if gn_filter !== nothing
        df_plot = df_plot[df_plot.GN.==gn_filter, :]
    end

    # Apply domain filter (use minimum domain if not specified)
    if domain_filter !== nothing
        df_plot = df_plot[df_plot.domain.==domain_filter, :]
    else
        min_domain = minimum(df_plot.domain)
        df_plot = df_plot[df_plot.domain.==min_domain, :]
        domain_filter = min_domain
    end

    if nrow(df_plot) == 0
        error("No data after filtering")
    end

    # Create multi-panel figure
    n_metrics = length(metrics)
    fig = Figure(size = something(fig_size, (800, 300 * n_metrics)))

    title_str =
        "Degree Comparison (domain=$(domain_filter))" *
        (gn_filter !== nothing ? ", GN=$gn_filter" : "")

    for (i, metric) in enumerate(metrics)
        String(metric) in names(df_plot) || continue

        ax = Axis(
            fig[i, 1],
            xlabel = i == n_metrics ? "Polynomial degree" : "",
            ylabel = _get_comparison_metric_label(metric),
            title = i == 1 ? title_str : "",
            xticks = sort(unique(df_plot.degree)),
        )

        # Sort by degree
        df_sorted = sort(df_plot, :degree)

        # Plot bars
        barplot!(
            ax,
            df_sorted.degree,
            df_sorted[!, metric],
            color = :steelblue,
            strokewidth = 1,
            strokecolor = :black,
        )

        # Add value labels on bars
        for row in eachrow(df_sorted)
            val = row[metric]
            label = _format_metric_value(metric, val)
            text!(
                ax,
                row.degree,
                val,
                text = label,
                fontsize = 12,
                align = (:center, :bottom),
                offset = (0, 5),
            )
        end
    end

    # Add legend explaining metrics
    metric_explanations =
        join([_get_comparison_metric_definition(m) for m in metrics], "\n")
    Label(
        fig[n_metrics+1, 1],
        metric_explanations,
        fontsize = 14,
        color = :gray60,
        halign = :left,
    )

    return fig
end

# ============================================================================
# GN Comparison Plot
# ============================================================================

"""
    plot_lv4d_gn_comparison(df::DataFrame; domain_filter=nothing, degree_filter=nothing,
                           metrics=[:mean_recovery, :success_rate])

Compare metrics across different GN values.

# Arguments
- `df::DataFrame`: Aggregated data with GN column
- `domain_filter`: Domain value to filter by
- `degree_filter`: Degree value to filter by
- `metrics`: Vector of metrics to plot

# Returns
Figure comparing GN values.
"""
function plot_lv4d_gn_comparison(
    df::DataFrame;
    domain_filter = nothing,
    degree_filter = nothing,
    metrics::Vector{Symbol} = [:mean_recovery, :success_rate],
    fig_size::Union{Tuple{Int,Int},Nothing} = nothing,
)
    df_plot = copy(df)

    # Apply filters
    if domain_filter !== nothing
        df_plot = df_plot[df_plot.domain.==domain_filter, :]
    end
    if degree_filter !== nothing
        df_plot = df_plot[df_plot.degree.==degree_filter, :]
    end

    if nrow(df_plot) == 0
        error("No data after filtering")
    end

    # Create grouped bar plot
    gn_values = sort(unique(df_plot.GN))
    n_gn = length(gn_values)

    fig = Figure(size = something(fig_size, (600 + 100 * n_gn, 400)))

    title_str =
        "GN Comparison" *
        (domain_filter !== nothing ? " (domain=$domain_filter)" : "") *
        (degree_filter !== nothing ? ", degree=$degree_filter" : "")

    ax = Axis(
        fig[1, 1],
        xlabel = "Grid nodes (GN)",
        ylabel = "Metric value",
        title = title_str,
        xticks = (1:n_gn, string.(gn_values)),
    )

    # Plot each metric as grouped bars
    n_metrics = length(metrics)
    bar_width = 0.8 / n_metrics
    colors = [:steelblue, :coral, :seagreen, :purple]

    plotted_metrics = Symbol[]
    for (j, metric) in enumerate(metrics)
        metric in Symbol.(names(df_plot)) || continue

        offset = (j - (n_metrics + 1) / 2) * bar_width
        positions = (1:n_gn) .+ offset

        values = [df_plot[df_plot.GN.==gn, metric][1] for gn in gn_values]

        barplot!(
            ax,
            positions,
            values,
            color = colors[mod1(j, length(colors))],
            width = bar_width,
            label = _get_comparison_metric_label(metric),
        )
        push!(plotted_metrics, metric)
    end

    if isempty(plotted_metrics)
        available = names(df_plot)
        error(
            "No metrics found in DataFrame. Requested: $metrics. Available columns: $available",
        )
    end

    Legend(fig[1, 2], ax)

    return fig
end

# ============================================================================
# Metrics Heatmap
# ============================================================================

"""
    plot_lv4d_metrics_heatmap(df::DataFrame; metric=:success_rate, gn_filter=nothing,
                              aggregation=:mean, show_n=true)

Heatmap showing metric values across degree × domain grid.

# Arguments
- `df::DataFrame`: Data with degree, domain columns (can be pre-aggregated with n_experiments)
- `metric::Symbol`: Metric to display (e.g., :success_rate, :mean_recovery, :mean_L2)
- `gn_filter`: Optional GN value to filter by
- `aggregation::Symbol`: How to aggregate if multiple values (:mean, :max, :min)
- `show_n::Bool=true`: Show experiment count (n=X) in each cell

# Returns
Figure with heatmap visualization.
"""
function plot_lv4d_metrics_heatmap(
    df::DataFrame;
    metric::Symbol = :success_rate,
    gn_filter = nothing,
    aggregation::Symbol = :mean,
    show_n::Bool = true,
    fig_size::Tuple{Int,Int} = (800, 600),
)
    df_plot = gn_filter !== nothing ? df[df.GN.==gn_filter, :] : copy(df)

    if nrow(df_plot) == 0
        error("No data after filtering")
    end

    # Get unique domains and degrees
    domains = sort(unique(df_plot.domain))
    degrees = sort(unique(df_plot.degree))

    # Resolve metric column
    actual_metric = _resolve_heatmap_metric(df_plot, metric)
    String(actual_metric) in names(df_plot) ||
        error("Metric $metric not found in DataFrame")

    # Aggregate data - include experiment count
    agg_func =
        aggregation == :mean ? mean :
        aggregation == :max ? maximum : aggregation == :min ? minimum : mean

    # Check if n_experiments column exists (pre-aggregated data)
    has_n_experiments = "n_experiments" in names(df_plot)

    if has_n_experiments
        # Sum existing n_experiments when further aggregating
        agg = combine(
            groupby(df_plot, [:domain, :degree]),
            actual_metric => agg_func => :value,
            :n_experiments => sum => :n,
        )
    else
        # Count rows when aggregating raw data
        agg = combine(
            groupby(df_plot, [:domain, :degree]),
            actual_metric => agg_func => :value,
            nrow => :n,
        )
    end

    # Create matrices for values and counts
    matrix = fill(NaN, length(domains), length(degrees))
    n_matrix = fill(0, length(domains), length(degrees))
    for row in eachrow(agg)
        i = findfirst(==(row.domain), domains)
        j = findfirst(==(row.degree), degrees)
        if i !== nothing && j !== nothing
            matrix[i, j] = row.value
            n_matrix[i, j] = row.n
        end
    end

    # Create figure
    fig = Figure(size = fig_size)

    title_str =
        "$(titlecase(string(metric))) Heatmap" *
        (gn_filter !== nothing ? " (GN=$gn_filter)" : "")

    ax = Axis(
        fig[1, 1],
        xlabel = "Polynomial degree",
        ylabel = "Domain half-width",
        title = title_str,
        xticks = (1:length(degrees), string.(degrees)),
        yticks = (1:length(domains), [@sprintf("%.4f", d) for d in domains]),
    )

    # Determine colormap and limits based on metric
    colormap, limits = _get_heatmap_colormap(metric, matrix)

    # Plot heatmap
    hm = heatmap!(
        ax,
        1:length(degrees),
        1:length(domains),
        matrix',
        colormap = colormap,
        colorrange = limits,
    )

    Colorbar(fig[1, 2], hm, label = _get_comparison_metric_label(metric))

    # Add value annotations (with optional n count)
    for i in 1:length(domains)
        for j in 1:length(degrees)
            val = matrix[i, j]
            if !isnan(val)
                val_str = _format_metric_value(metric, val)
                label = show_n ? "$val_str\n(n=$(n_matrix[i,j]))" : val_str
                # Choose text color based on background
                text_color = val > mean(limits) ? :white : :black
                text!(
                    ax,
                    j,
                    i,
                    text = label,
                    fontsize = show_n ? 11 : 12,
                    align = (:center, :center),
                    color = text_color,
                )
            end
        end
    end

    # Add metric definition
    Label(
        fig[2, 1:2],
        _get_comparison_metric_definition(metric),
        fontsize = 14,
        color = :gray60,
        halign = :left,
    )

    return fig
end

# ============================================================================
# Helper Functions
# ============================================================================

function _get_comparison_metric_label(metric::Symbol)
    labels = Dict(
        :mean_recovery => "Recovery Error",
        :std_recovery => "Recovery Error Std",
        :mean_L2 => "L2 Error",
        :std_L2 => "L2 Error Std",
        :success_rate => "Success Rate",
        :mean_grad_valid => "Gradient Valid %",
        :mean_crit_pts => "Critical Points",
        :n_experiments => "Experiments",
        :n_seeds => "Experiments",  # backward compatibility
    )
    return get(labels, metric, string(metric))
end

function _get_comparison_metric_definition(metric::Symbol)
    defs = Dict(
        :mean_recovery => "mean_recovery = ||p_best - p_true|| / ||p_true|| (parameter error)",
        :std_recovery => "std_recovery = standard deviation of recovery error",
        :mean_L2 => "mean_L2 = ||f - w_d||_L2 (polynomial approximation error)",
        :success_rate => "success_rate = fraction of experiments with recovery_error < 5%",
        :mean_grad_valid => "mean_grad_valid = fraction of CPs where ||∇f|| < 1e-6",
        :mean_crit_pts => "mean_crit_pts = mean number of critical points found",
    )
    return get(defs, metric, "")
end

function _format_metric_value(metric::Symbol, val::Real)
    if metric in [:success_rate, :mean_grad_valid]
        return @sprintf("%.0f%%", val * 100)
    elseif metric in [:mean_recovery, :std_recovery]
        return @sprintf("%.1f%%", val * 100)
    elseif metric in [:mean_L2, :std_L2]
        return val < 0.01 ? @sprintf("%.2e", val) : @sprintf("%.3f", val)
    elseif metric in [:mean_crit_pts, :n_seeds]
        return @sprintf("%.0f", val)
    else
        return @sprintf("%.3f", val)
    end
end

function _resolve_heatmap_metric(df::DataFrame, metric::Symbol)
    # Handle aliases
    if metric == :recovery_error && :mean_recovery in names(df)
        return :mean_recovery
    elseif metric == :L2_norm && :mean_L2 in names(df)
        return :mean_L2
    end
    return metric
end

function _get_heatmap_colormap(metric::Symbol, matrix::AbstractMatrix)
    valid_vals = filter(!isnan, vec(matrix))
    isempty(valid_vals) && return (:viridis, (0.0, 1.0))

    if metric == :success_rate
        return (:RdYlGn, (0.0, 1.0))
    elseif metric in [:mean_recovery, :std_recovery, :mean_L2, :std_L2]
        # Lower is better - use reversed colormap
        return (Reverse(:RdYlGn), (minimum(valid_vals), maximum(valid_vals)))
    elseif metric == :mean_grad_valid
        return (:RdYlGn, (0.0, 1.0))
    else
        return (:viridis, (minimum(valid_vals), maximum(valid_vals)))
    end
end

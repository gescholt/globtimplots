"""
Convergence plots for LV4D experiments.

Log-log plots showing convergence of approximation and recovery errors.
"""

# ============================================================================
# Color scheme for consistent plotting
# ============================================================================

const LV4D_COLORS = Dict(
    4 => :blue,
    6 => :green,
    8 => :orange,
    10 => :red,
    12 => :purple,
    14 => :brown,
    16 => :pink,
    18 => :cyan
)

function get_degree_color(degree::Int)
    return get(LV4D_COLORS, degree, :black)
end

# ============================================================================
# L2 Convergence Plot
# ============================================================================

"""
    plot_lv4d_l2_convergence(df::DataFrame; gn_filter=nothing, degree_filter=nothing,
                             show_fit=false, band_type=:quantile, title=nothing)

Plot L2 approximation error vs domain size on log-log scale.

# Arguments
- `df::DataFrame`: Data with columns: domain, degree, GN, L2_norm (or mean_L2)
- `gn_filter`: Optional GN value to filter by
- `degree_filter`: Optional degree or range to filter by
- `show_fit::Bool=false`: Show fitted convergence rate line
- `band_type::Symbol=:quantile`: Band type - `:quantile` (IQR 25-75%), `:std`, or `:none`
- `title`: Optional custom title

# Returns
Figure with log-log convergence plot.

# Metric Definition
L2_norm = ||f - w_d||_L2 = polynomial approximation error
"""
function plot_lv4d_l2_convergence(df::DataFrame;
                                  gn_filter=nothing,
                                  degree_filter=nothing,
                                  show_fit::Bool=false,
                                  band_type::Symbol=:quantile,
                                  title=nothing,
                                  fig_size::Tuple{Int,Int}=(800, 600))
    # Apply filters
    df_plot = _apply_filters(df, gn_filter, degree_filter)

    if nrow(df_plot) == 0
        error("No data after filtering (GN=$gn_filter, degree=$degree_filter)")
    end

    # Determine which L2 column to use
    l2_col = "L2_norm" in names(df_plot) ? :L2_norm : :mean_L2

    # Create figure
    fig = Figure(size=fig_size)

    # Title
    title_str = title !== nothing ? title :
        "L2 Approximation Error Convergence" *
        (gn_filter !== nothing ? " (GN=$gn_filter)" : "")

    ax = Axis(fig[1, 1],
        xlabel = "Domain half-width",
        ylabel = "||f - w_d||_L2",
        title = title_str,
        xscale = log10,
        yscale = log10,
        xminorticksvisible = true,
        yminorticksvisible = true
    )

    # Plot each degree separately
    degrees = sort(unique(df_plot.degree))
    plotted_count = 0
    for deg in degrees
        df_deg = df_plot[df_plot.degree .== deg, :]
        if _plot_convergence_line!(ax, df_deg, l2_col, deg, show_fit; band_type=band_type)
            plotted_count += 1
        end
    end

    # Add legend only if we have plots
    if plotted_count > 0
        Legend(fig[1, 2], ax, "Degree")
    end

    # Add metric explanation
    Label(fig[2, 1:2],
        "L2_norm = ||f - w_d||_L2 (polynomial approximation error)",
        fontsize=14, color=:gray60, halign=:left
    )

    return fig
end

# ============================================================================
# Recovery Error Convergence Plot
# ============================================================================

"""
    plot_lv4d_recovery_convergence(df::DataFrame; gn_filter=nothing, degree_filter=nothing,
                                   show_fit=false, band_type=:quantile, title=nothing)

Plot parameter recovery error vs domain size on log-log scale.

# Arguments
- `df::DataFrame`: Data with columns: domain, degree, GN, recovery_error (or mean_recovery)
- `gn_filter`: Optional GN value to filter by
- `degree_filter`: Optional degree or range to filter by
- `show_fit::Bool=false`: Show fitted convergence rate line
- `band_type::Symbol=:quantile`: Band type - `:quantile` (IQR 25-75%), `:std`, or `:none`
- `title`: Optional custom title

# Returns
Figure with log-log convergence plot.

# Metric Definition
recovery_error = ||p_best - p_true|| / ||p_true|| (relative parameter error)
"""
function plot_lv4d_recovery_convergence(df::DataFrame;
                                        gn_filter=nothing,
                                        degree_filter=nothing,
                                        show_fit::Bool=false,
                                        band_type::Symbol=:quantile,
                                        title=nothing,
                                        fig_size::Tuple{Int,Int}=(800, 600))
    # Apply filters
    df_plot = _apply_filters(df, gn_filter, degree_filter)

    if nrow(df_plot) == 0
        error("No data after filtering (GN=$gn_filter, degree=$degree_filter)")
    end

    # Determine which recovery column to use
    rec_col = "recovery_error" in names(df_plot) ? :recovery_error : :mean_recovery

    # Create figure
    fig = Figure(size=fig_size)

    title_str = title !== nothing ? title :
        "Parameter Recovery Error Convergence" *
        (gn_filter !== nothing ? " (GN=$gn_filter)" : "")

    ax = Axis(fig[1, 1],
        xlabel = "Domain half-width",
        ylabel = "||p_best - p_true|| / ||p_true||",
        title = title_str,
        xscale = log10,
        yscale = log10,
        xminorticksvisible = true,
        yminorticksvisible = true
    )

    # Add 5% threshold line
    domain_range = extrema(df_plot.domain)
    hlines!(ax, [0.05], color=:gray, linestyle=:dash, linewidth=1,
            label="5% threshold")

    # Plot each degree separately
    degrees = sort(unique(df_plot.degree))
    for deg in degrees
        df_deg = df_plot[df_plot.degree .== deg, :]
        _plot_convergence_line!(ax, df_deg, rec_col, deg, show_fit; band_type=band_type)
    end

    # Add legend (5% threshold always provides at least one label)
    Legend(fig[1, 2], ax, "Degree")

    # Add metric explanation
    Label(fig[2, 1:2],
        "recovery_error = ||p_best - p_true|| / ||p_true|| (relative parameter error)",
        fontsize=14, color=:gray60, halign=:left
    )

    return fig
end

# ============================================================================
# Convergence Rate Plot (α values)
# ============================================================================

"""
    plot_lv4d_convergence_rate(df::DataFrame; metric=:recovery_error, gn_filter=nothing)

Plot fitted convergence rate α (where error ∝ domain^α) vs degree.

# Arguments
- `df::DataFrame`: Aggregated data with domain, degree columns
- `metric::Symbol`: Which metric to compute rate for (:recovery_error or :L2_norm)
- `gn_filter`: Optional GN value to filter by

# Returns
Figure showing convergence rate α per degree.
"""
function plot_lv4d_convergence_rate(df::DataFrame;
                                    metric::Symbol=:recovery_error,
                                    gn_filter=nothing,
                                    fig_size::Tuple{Int,Int}=(600, 400))
    df_plot = gn_filter !== nothing ? df[df.GN .== gn_filter, :] : df

    # Compute convergence rate for each degree
    degrees = sort(unique(df_plot.degree))
    slopes = Float64[]
    slope_errors = Float64[]

    for deg in degrees
        df_deg = df_plot[df_plot.degree .== deg, :]
        if nrow(df_deg) >= 2
            slope, slope_err = _fit_convergence_rate(df_deg, metric)
            push!(slopes, slope)
            push!(slope_errors, slope_err)
        else
            push!(slopes, NaN)
            push!(slope_errors, NaN)
        end
    end

    # Create figure
    fig = Figure(size=fig_size)

    metric_name = metric == :recovery_error ? "recovery error" : "L2 error"
    title_str = "Convergence Rate: $metric_name ∝ domain^α" *
                (gn_filter !== nothing ? " (GN=$gn_filter)" : "")

    ax = Axis(fig[1, 1],
        xlabel = "Polynomial degree",
        ylabel = "Convergence rate α",
        title = title_str,
        xticks = degrees
    )

    # Plot rates with error bars
    valid_idx = .!isnan.(slopes)
    scatter!(ax, degrees[valid_idx], slopes[valid_idx],
             color=:steelblue, markersize=12)
    errorbars!(ax, degrees[valid_idx], slopes[valid_idx], slope_errors[valid_idx],
               color=:steelblue, whiskerwidth=8)

    # Add reference line at α=1 and α=2
    hlines!(ax, [1.0], color=:gray, linestyle=:dash, linewidth=1, label="α=1")
    hlines!(ax, [2.0], color=:gray, linestyle=:dot, linewidth=1, label="α=2")

    # Annotate values
    for (i, (deg, slope)) in enumerate(zip(degrees[valid_idx], slopes[valid_idx]))
        text!(ax, deg + 0.2, slope, text=@sprintf("%.2f", slope),
              fontsize=13, align=(:left, :center))
    end

    Legend(fig[1, 2], ax)

    return fig
end

# ============================================================================
# Multi-Degree Convergence Plot
# ============================================================================

"""
    plot_lv4d_convergence_multi_degree(df::DataFrame; gn_filter=nothing,
                                       metric=:recovery_error, show_fit=true)

Plot convergence for multiple degrees on a single log-log plot with rate annotations.

# Arguments
- `df::DataFrame`: Data with domain, degree, and metric columns
- `gn_filter`: Optional GN value to filter by
- `metric::Symbol`: Which metric to plot (:recovery_error, :L2_norm, :mean_recovery, :mean_L2)
- `show_fit::Bool=true`: Show fitted lines with slope annotations

# Returns
Figure with multi-degree convergence plot.
"""
function plot_lv4d_convergence_multi_degree(df::DataFrame;
                                            gn_filter=nothing,
                                            metric::Symbol=:recovery_error,
                                            show_fit::Bool=true,
                                            fig_size::Tuple{Int,Int}=(900, 700))
    df_plot = gn_filter !== nothing ? df[df.GN .== gn_filter, :] : df

    # Map to available column
    actual_metric = _resolve_metric_column(df_plot, metric)

    fig = Figure(size=fig_size)

    metric_label = _get_metric_label(metric)
    title_str = "Convergence Analysis: $metric_label" *
                (gn_filter !== nothing ? " (GN=$gn_filter)" : "")

    ax = Axis(fig[1, 1],
        xlabel = "Domain half-width",
        ylabel = metric_label,
        title = title_str,
        xscale = log10,
        yscale = log10,
        xminorticksvisible = true,
        yminorticksvisible = true
    )

    # Plot each degree
    degrees = sort(unique(df_plot.degree))
    annotations = String[]
    plotted_count = 0

    for deg in degrees
        df_deg = df_plot[df_plot.degree .== deg, :]

        # Aggregate by domain
        agg = combine(groupby(df_deg, :domain),
                      actual_metric => mean => :mean_val,
                      actual_metric => std => :std_val,
                      nrow => :n)
        sort!(agg, :domain)

        # Skip if not enough data
        nrow(agg) < 2 && continue

        color = get_degree_color(deg)

        # Plot data points
        scatter!(ax, agg.domain, agg.mean_val, color=color, markersize=8,
                 label="deg $deg")
        plotted_count += 1

        # Fit and plot line
        if show_fit
            slope, _ = _fit_convergence_rate_from_agg(agg)
            if !isnan(slope)
                # Plot fitted line
                x_fit = [minimum(agg.domain), maximum(agg.domain)]
                y_fit = _predict_power_law(x_fit, agg.domain, agg.mean_val, slope)
                lines!(ax, x_fit, y_fit, color=color, linestyle=:dash, linewidth=1.5)

                # Store annotation
                push!(annotations, "deg $deg: α = $(round(slope, digits=2))")
            end
        end
    end

    # Only add legend if we have plots
    if plotted_count > 0
        Legend(fig[1, 2], ax, "Degree")
    end

    # Add rate annotations
    if !isempty(annotations)
        annotation_text = join(annotations, "\n")
        Label(fig[2, 1], annotation_text, fontsize=14, halign=:left)
    end

    # Add metric definition
    Label(fig[3, 1:2],
        _get_metric_definition(metric),
        fontsize=14, color=:gray60, halign=:left
    )

    # Set row sizes: main plot gets most space, annotations and definition get minimal
    rowsize!(fig.layout, 1, Relative(0.85))
    rowsize!(fig.layout, 2, Auto())
    rowsize!(fig.layout, 3, Auto())

    # Set column sizes: plot area larger than legend
    colsize!(fig.layout, 1, Relative(0.75))
    colsize!(fig.layout, 2, Auto())

    return fig
end

# ============================================================================
# L2 Error vs Degree Plot (for single-domain analysis)
# ============================================================================

"""
    plot_lv4d_l2_by_degree(df::DataFrame; gn_filter=nothing, domain_filter=nothing,
                           show_fit=true, title=nothing)

Plot L2 approximation error vs polynomial degree on log-linear scale.

Use this plot when analyzing a single domain value to see how polynomial approximation
improves with increasing degree.

# Arguments
- `df::DataFrame`: Data with columns: domain, degree, GN, L2_norm (or mean_L2)
- `gn_filter`: Optional GN value to filter by
- `domain_filter`: Optional domain value to filter by (uses minimum if not specified)
- `show_fit::Bool=true`: Show fitted exponential decay line
- `title`: Optional custom title

# Returns
Figure with degree on x-axis (linear), L2 error on y-axis (log).

# Metric Definition
L2_norm = ||f - w_d||_L2 = polynomial approximation error
"""
function plot_lv4d_l2_by_degree(df::DataFrame;
                                 gn_filter=nothing,
                                 domain_filter=nothing,
                                 show_fit::Bool=true,
                                 title=nothing,
                                 fig_size::Tuple{Int,Int}=(800, 600))
    # Apply GN filter
    df_plot = gn_filter !== nothing ? df[df.GN .== gn_filter, :] : copy(df)

    # Apply domain filter (use minimum if multiple)
    domains = unique(df_plot.domain)
    if domain_filter !== nothing
        df_plot = df_plot[df_plot.domain .== domain_filter, :]
        actual_domain = domain_filter
    elseif length(domains) == 1
        actual_domain = domains[1]
    else
        actual_domain = minimum(domains)
        df_plot = df_plot[df_plot.domain .== actual_domain, :]
    end

    if nrow(df_plot) == 0
        error("No data after filtering")
    end

    # Determine L2 column
    l2_col = "L2_norm" in names(df_plot) ? :L2_norm : :mean_L2

    # Aggregate by degree
    agg = combine(groupby(df_plot, :degree),
                  l2_col => mean => :mean_L2,
                  l2_col => std => :std_L2,
                  nrow => :n)
    sort!(agg, :degree)

    # Create figure
    fig = Figure(size=fig_size)

    domain_str = actual_domain >= 0.01 ? @sprintf("%.4f", actual_domain) : @sprintf("%.2e", actual_domain)
    title_str = title !== nothing ? title :
        "L2 Error vs Polynomial Degree (domain=$domain_str)" *
        (gn_filter !== nothing ? ", GN=$gn_filter" : "")

    ax = Axis(fig[1, 1],
        xlabel = "Polynomial degree",
        ylabel = "||f - w_d||_L2",
        title = title_str,
        yscale = log10,
        xticks = agg.degree,
        yminorticksvisible = true
    )

    # Plot points
    scatter!(ax, agg.degree, agg.mean_L2, color=:steelblue, markersize=12,
             label="L2 error")

    # Connect with lines
    lines!(ax, agg.degree, agg.mean_L2, color=:steelblue, linewidth=2)

    # Plot std bands
    if any(.!isnan.(agg.std_L2) .& (agg.std_L2 .> 0))
        valid = .!isnan.(agg.std_L2) .& (agg.std_L2 .> 0)
        band!(ax, agg.degree[valid],
              max.(agg.mean_L2[valid] .- agg.std_L2[valid], 1e-16),
              agg.mean_L2[valid] .+ agg.std_L2[valid],
              color=(:steelblue, 0.2))
    end

    # Fit exponential decay: L2 ∝ exp(-α * degree)
    if show_fit && nrow(agg) >= 2
        valid = agg.mean_L2 .> 0
        if sum(valid) >= 2
            log_y = log.(agg.mean_L2[valid])
            x = agg.degree[valid]
            # Linear regression: log(y) = a + b*x => y = exp(a) * exp(b*x)
            n = length(x)
            sum_x = sum(x)
            sum_y = sum(log_y)
            sum_xy = sum(x .* log_y)
            sum_x2 = sum(x.^2)
            denom = n * sum_x2 - sum_x^2
            if abs(denom) > 1e-10
                slope = (n * sum_xy - sum_x * sum_y) / denom
                intercept = (sum_y - slope * sum_x) / n

                x_fit = range(minimum(x), maximum(x), length=50)
                y_fit = exp.(intercept .+ slope .* x_fit)
                lines!(ax, collect(x_fit), y_fit, color=:red, linestyle=:dash, linewidth=1.5,
                       label=@sprintf("fit: ∝ e^(%.2f·deg)", slope))
            end
        end
    end

    Legend(fig[1, 2], ax)

    # Add explanation
    Label(fig[2, 1:2],
        "L2_norm = ||f - w_d||_L2 (polynomial approximation error). Expect exponential decay with degree.",
        fontsize=14, color=:gray60, halign=:left
    )

    return fig
end

# ============================================================================
# Recovery Error vs Degree Plot (for single-domain analysis)
# ============================================================================

"""
    plot_lv4d_recovery_by_degree(df::DataFrame; gn_filter=nothing, domain_filter=nothing,
                                  show_fit=true, title=nothing)

Plot parameter recovery error vs polynomial degree on log-linear scale.

Use this plot when analyzing a single domain value to see how recovery error
improves with increasing polynomial degree.

# Arguments
- `df::DataFrame`: Data with columns: domain, degree, GN, recovery_error (or mean_recovery)
- `gn_filter`: Optional GN value to filter by
- `domain_filter`: Optional domain value to filter by (uses minimum if not specified)
- `show_fit::Bool=true`: Show fitted exponential decay line
- `title`: Optional custom title

# Returns
Figure with degree on x-axis (linear), recovery error on y-axis (log).

# Metric Definition
recovery_error = ||p_best - p_true|| / ||p_true|| (relative parameter error)
"""
function plot_lv4d_recovery_by_degree(df::DataFrame;
                                       gn_filter=nothing,
                                       domain_filter=nothing,
                                       show_fit::Bool=true,
                                       title=nothing,
                                       fig_size::Tuple{Int,Int}=(800, 600))
    # Apply GN filter
    df_plot = gn_filter !== nothing ? df[df.GN .== gn_filter, :] : copy(df)

    # Apply domain filter (use minimum if multiple)
    domains = unique(df_plot.domain)
    if domain_filter !== nothing
        df_plot = df_plot[df_plot.domain .== domain_filter, :]
        actual_domain = domain_filter
    elseif length(domains) == 1
        actual_domain = domains[1]
    else
        actual_domain = minimum(domains)
        df_plot = df_plot[df_plot.domain .== actual_domain, :]
    end

    if nrow(df_plot) == 0
        error("No data after filtering")
    end

    # Determine recovery column
    rec_col = "recovery_error" in names(df_plot) ? :recovery_error : :mean_recovery

    # Aggregate by degree
    agg = combine(groupby(df_plot, :degree),
                  rec_col => mean => :mean_recovery,
                  rec_col => std => :std_recovery,
                  nrow => :n)
    sort!(agg, :degree)

    # Create figure
    fig = Figure(size=fig_size)

    domain_str = actual_domain >= 0.01 ? @sprintf("%.4f", actual_domain) : @sprintf("%.2e", actual_domain)
    title_str = title !== nothing ? title :
        "Recovery Error vs Polynomial Degree (domain=$domain_str)" *
        (gn_filter !== nothing ? ", GN=$gn_filter" : "")

    ax = Axis(fig[1, 1],
        xlabel = "Polynomial degree",
        ylabel = "||p_best - p_true|| / ||p_true||",
        title = title_str,
        yscale = log10,
        xticks = agg.degree,
        yminorticksvisible = true
    )

    # Add 5% threshold line
    hlines!(ax, [0.05], color=:gray, linestyle=:dash, linewidth=1,
            label="5% threshold")

    # Plot points
    scatter!(ax, agg.degree, agg.mean_recovery, color=:steelblue, markersize=12,
             label="Recovery error")

    # Connect with lines
    lines!(ax, agg.degree, agg.mean_recovery, color=:steelblue, linewidth=2)

    # Plot std bands
    if any(.!isnan.(agg.std_recovery) .& (agg.std_recovery .> 0))
        valid = .!isnan.(agg.std_recovery) .& (agg.std_recovery .> 0)
        band!(ax, agg.degree[valid],
              max.(agg.mean_recovery[valid] .- agg.std_recovery[valid], 1e-16),
              agg.mean_recovery[valid] .+ agg.std_recovery[valid],
              color=(:steelblue, 0.2))
    end

    # Fit exponential decay: recovery ∝ exp(-α * degree)
    if show_fit && nrow(agg) >= 2
        valid = agg.mean_recovery .> 0
        if sum(valid) >= 2
            log_y = log.(agg.mean_recovery[valid])
            x = agg.degree[valid]
            # Linear regression: log(y) = a + b*x => y = exp(a) * exp(b*x)
            n = length(x)
            sum_x = sum(x)
            sum_y = sum(log_y)
            sum_xy = sum(x .* log_y)
            sum_x2 = sum(x.^2)
            denom = n * sum_x2 - sum_x^2
            if abs(denom) > 1e-10
                slope = (n * sum_xy - sum_x * sum_y) / denom
                intercept = (sum_y - slope * sum_x) / n

                x_fit = range(minimum(x), maximum(x), length=50)
                y_fit = exp.(intercept .+ slope .* x_fit)
                lines!(ax, collect(x_fit), y_fit, color=:red, linestyle=:dash, linewidth=1.5,
                       label=@sprintf("fit: ∝ e^(%.2f·deg)", slope))
            end
        end
    end

    Legend(fig[1, 2], ax)

    # Add explanation
    Label(fig[2, 1:2],
        "recovery_error = ||p_best - p_true|| / ||p_true|| (relative parameter error). Expect improvement with degree.",
        fontsize=14, color=:gray60, halign=:left
    )

    return fig
end

# ============================================================================
# Helper Functions
# ============================================================================

function _apply_filters(df::DataFrame, gn_filter, degree_filter)
    df_out = copy(df)

    if gn_filter !== nothing
        df_out = df_out[df_out.GN .== gn_filter, :]
    end

    if degree_filter !== nothing
        if degree_filter isa Integer
            df_out = df_out[df_out.degree .== degree_filter, :]
        elseif degree_filter isa AbstractRange || degree_filter isa Tuple
            deg_min, deg_max = extrema(degree_filter)
            df_out = df_out[(df_out.degree .>= deg_min) .& (df_out.degree .<= deg_max), :]
        end
    end

    return df_out
end

"""
Plot a convergence line for a single degree. Returns true if plot was added, false otherwise.

# Arguments
- `band_type::Symbol=:quantile`: Type of uncertainty band:
  - `:quantile` - IQR (25th-75th percentile) band
  - `:std` - Mean ± standard deviation band
  - `:none` - No band
"""
function _plot_convergence_line!(ax, df_deg::DataFrame, metric_col::Symbol,
                                 degree::Int, show_fit::Bool;
                                 band_type::Symbol=:quantile)::Bool
    # Aggregate by domain with both std and quantiles
    agg = combine(groupby(df_deg, :domain),
                  metric_col => mean => :mean_val,
                  metric_col => std => :std_val,
                  metric_col => (x -> quantile(x, 0.25)) => :q25,
                  metric_col => (x -> quantile(x, 0.75)) => :q75,
                  nrow => :n)
    sort!(agg, :domain)

    nrow(agg) < 1 && return false

    color = get_degree_color(degree)

    # Draw smooth line through mean values (always)
    lines!(ax, agg.domain, agg.mean_val, color=color, linewidth=2, label="deg $degree")

    # Plot scatter points on top
    scatter!(ax, agg.domain, agg.mean_val, color=color, markersize=8)

    if band_type == :quantile
        # IQR band (25th-75th percentile)
        valid = .!isnan.(agg.q25) .& .!isnan.(agg.q75)
        if any(valid)
            band!(ax, agg.domain[valid],
                  agg.q25[valid],
                  agg.q75[valid],
                  color=(color, 0.2))
        end
    elseif band_type == :std
        # Mean ± std band
        valid_std = .!isnan.(agg.std_val) .& (agg.std_val .> 0)
        if any(valid_std)
            band!(ax, agg.domain[valid_std],
                  agg.mean_val[valid_std] .- agg.std_val[valid_std],
                  agg.mean_val[valid_std] .+ agg.std_val[valid_std],
                  color=(color, 0.2))
        end
    end
    # :none - no band plotted

    # Fit and plot line (optional power-law regression)
    if show_fit && nrow(agg) >= 2
        slope, _ = _fit_convergence_rate_from_agg(agg)
        if !isnan(slope)
            x_fit = [minimum(agg.domain), maximum(agg.domain)]
            y_fit = _predict_power_law(x_fit, agg.domain, agg.mean_val, slope)
            lines!(ax, x_fit, y_fit, color=color, linestyle=:dash, linewidth=1.5)
        end
    end

    return true
end

function _fit_convergence_rate(df::DataFrame, metric::Symbol)
    # Aggregate by domain first
    actual_metric = _resolve_metric_column(df, metric)
    agg = combine(groupby(df, :domain),
                  actual_metric => mean => :mean_val)
    sort!(agg, :domain)

    return _fit_convergence_rate_from_agg(agg)
end

function _fit_convergence_rate_from_agg(agg::DataFrame)
    # Log-log linear regression
    valid = (agg.mean_val .> 0) .& .!isnan.(agg.mean_val)
    n_valid = sum(valid)
    n_valid < 2 && return (NaN, NaN)

    log_x = log10.(agg.domain[valid])
    log_y = log10.(agg.mean_val[valid])

    n = length(log_x)
    sum_x = sum(log_x)
    sum_y = sum(log_y)
    sum_xy = sum(log_x .* log_y)
    sum_x2 = sum(log_x.^2)

    denom = n * sum_x2 - sum_x^2
    abs(denom) < 1e-10 && return (NaN, NaN)

    slope = (n * sum_xy - sum_x * sum_y) / denom
    intercept = (sum_y - slope * sum_x) / n

    # Compute standard error of slope
    y_pred = intercept .+ slope .* log_x
    residuals = log_y .- y_pred
    mse = sum(residuals.^2) / (n - 2)
    se_slope = n > 2 ? sqrt(mse * n / denom) : NaN

    return (slope, se_slope)
end

function _predict_power_law(x_new, x_data, y_data, slope)
    # y = A * x^slope  =>  log(y) = log(A) + slope*log(x)
    valid = (y_data .> 0) .& .!isnan.(y_data)
    any(valid) || return fill(NaN, length(x_new))

    log_A = mean(log10.(y_data[valid]) .- slope .* log10.(x_data[valid]))
    return 10.0.^(log_A .+ slope .* log10.(x_new))
end

function _resolve_metric_column(df::DataFrame, metric::Symbol)
    # Handle different column naming conventions
    if metric == :recovery_error
        return "recovery_error" in names(df) ? :recovery_error : :mean_recovery
    elseif metric == :L2_norm
        return "L2_norm" in names(df) ? :L2_norm : :mean_L2
    elseif metric == :mean_recovery
        return "mean_recovery" in names(df) ? :mean_recovery : :recovery_error
    elseif metric == :mean_L2
        return "mean_L2" in names(df) ? :mean_L2 : :L2_norm
    else
        return metric
    end
end

function _get_metric_label(metric::Symbol)
    labels = Dict(
        :recovery_error => "||p_best - p_true|| / ||p_true||",
        :mean_recovery => "||p_best - p_true|| / ||p_true||",
        :L2_norm => "||f - w_d||_L2",
        :mean_L2 => "||f - w_d||_L2",
        :gradient_valid_rate => "Gradient validation rate"
    )
    return get(labels, metric, string(metric))
end

function _get_metric_definition(metric::Symbol)
    defs = Dict(
        :recovery_error => "recovery_error = ||p_best - p_true|| / ||p_true|| (relative parameter error)",
        :mean_recovery => "recovery_error = ||p_best - p_true|| / ||p_true|| (relative parameter error)",
        :L2_norm => "L2_norm = ||f - w_d||_L2 (polynomial approximation error)",
        :mean_L2 => "L2_norm = ||f - w_d||_L2 (polynomial approximation error)"
    )
    return get(defs, metric, "")
end

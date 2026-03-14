# Hessian and eigenvalue visualization functions
#
# These functions use the abstract Makie API (Figure, Axis, scatter!, etc.)
# and work with any backend (CairoMakie, GLMakie, WGLMakie) — whichever the
# user has activated.  Previously they were duplicated verbatim across the
# GLMakie and CairoMakie package extensions.
#
# Dependencies available in module scope via GlobtimPlots.jl:
#   CairoMakie (@reexport — brings all Makie symbols into scope)
#   DataFrames, Statistics, ColorSchemes, LinearAlgebra
#   Globtim (Project.toml dep)

using Globtim  # for extract_all_eigenvalues_for_visualization, match_raw_to_refined_points

# ──────────────────────────────────────────────────────────────────────────────
# plot_hessian_norms
# ──────────────────────────────────────────────────────────────────────────────

"""
    plot_hessian_norms(df; fig_size=(800,600))

Scatter plot of Hessian Frobenius norms, colored by critical-point type.
"""
function plot_hessian_norms(df::DataFrames.DataFrame; fig_size::Tuple{Int,Int}=(800, 600))
    fig = Figure(size = fig_size)
    ax = Axis(
        fig[1, 1],
        xlabel = "Critical Point Index",
        ylabel = "Hessian L2 Norm",
        title = "L2 Norm of Hessian Matrices"
    )

    if "critical_point_type" in names(df)
        for classification in unique(df.critical_point_type)
            mask = df.critical_point_type .== classification
            scatter!(
                ax,
                findall(mask),
                df.hessian_norm[mask],
                label = string(classification),
                markersize = 8
            )
        end
        axislegend(ax)
    else
        scatter!(ax, 1:nrow(df), df.hessian_norm, markersize = 8)
    end

    return fig
end

# ──────────────────────────────────────────────────────────────────────────────
# plot_condition_numbers
# ──────────────────────────────────────────────────────────────────────────────

"""
    plot_condition_numbers(df; fig_size=(800,600))

Log-scale scatter plot of Hessian condition numbers κ(H) = |λ_max|/|λ_min|.
"""
function plot_condition_numbers(df::DataFrames.DataFrame; fig_size::Tuple{Int,Int}=(800, 600))
    fig = Figure(size = fig_size)
    ax = Axis(
        fig[1, 1],
        xlabel = "Critical Point Index",
        ylabel = "Condition Number (log scale)",
        title = "Condition Numbers of Hessian Matrices",
        yscale = log10
    )

    valid_indices = findall(x -> isfinite(x) && x > 0, df.hessian_condition_number)

    if "critical_point_type" in names(df)
        for classification in unique(df.critical_point_type)
            mask =
                (df.critical_point_type .== classification) .&
                [i in valid_indices for i in 1:nrow(df)]
            indices = findall(mask)
            if !isempty(indices)
                scatter!(
                    ax,
                    indices,
                    df.hessian_condition_number[indices],
                    label = string(classification),
                    markersize = 8
                )
            end
        end
        axislegend(ax)
    else
        scatter!(
            ax,
            valid_indices,
            df.hessian_condition_number[valid_indices],
            markersize = 8
        )
    end

    return fig
end

# ──────────────────────────────────────────────────────────────────────────────
# plot_critical_eigenvalues
# ──────────────────────────────────────────────────────────────────────────────

"""
    plot_critical_eigenvalues(df; fig_size=(1200,500))

Two-panel plot: smallest positive eigenvalues (minima) and largest negative
eigenvalues (maxima).
"""
function plot_critical_eigenvalues(df::DataFrames.DataFrame; fig_size::Tuple{Int,Int}=(1200, 500))
    fig = Figure(size = fig_size)

    # Plot 1: Smallest positive eigenvalues for minima
    ax1 = Axis(
        fig[1, 1],
        xlabel = "Minimum Index",
        ylabel = "Smallest Positive Eigenvalue",
        title = "Smallest Positive Eigenvalues (Minima)"
    )

    minima_mask = df.critical_point_type .== :minimum
    valid_minima =
        findall(x -> isfinite(x) && x > 0, df.smallest_positive_eigenval[minima_mask])

    if !isempty(valid_minima)
        scatter!(
            ax1,
            valid_minima,
            df.smallest_positive_eigenval[minima_mask][valid_minima],
            color = :blue,
            markersize = 10
        )
        hlines!(
            ax1,
            [1e-12],
            color = :red,
            linestyle = :dash,
            label = "Numerical Zero"
        )
        axislegend(ax1)
    end

    # Plot 2: Largest negative eigenvalues for maxima
    ax2 = Axis(
        fig[1, 2],
        xlabel = "Maximum Index",
        ylabel = "Largest Negative Eigenvalue",
        title = "Largest Negative Eigenvalues (Maxima)"
    )

    maxima_mask = df.critical_point_type .== :maximum
    valid_maxima =
        findall(x -> isfinite(x) && x < 0, df.largest_negative_eigenval[maxima_mask])

    if !isempty(valid_maxima)
        scatter!(
            ax2,
            valid_maxima,
            df.largest_negative_eigenval[maxima_mask][valid_maxima],
            color = :red,
            markersize = 10
        )
        hlines!(
            ax2,
            [-1e-12],
            color = :red,
            linestyle = :dash,
            label = "Numerical Zero"
        )
        axislegend(ax2)
    end

    return fig
end

# ──────────────────────────────────────────────────────────────────────────────
# plot_all_eigenvalues
# ──────────────────────────────────────────────────────────────────────────────

"""
    plot_all_eigenvalues(f, df; sort_by=:magnitude, fig_size=nothing)

Complete eigenvalue spectrum visualization separated by critical-point type,
with multiple sort options (`:magnitude`, `:abs_magnitude`, `:smallest`,
`:largest`, `:spread`, `:index`).
"""
function plot_all_eigenvalues(
    f::Function,
    df::DataFrames.DataFrame;
    sort_by = :magnitude,
    fig_size::Union{Tuple{Int,Int},Nothing} = nothing
)
    all_eigenvalues = Globtim.extract_all_eigenvalues_for_visualization(f, df)

    n_points = length(all_eigenvalues)
    if n_points == 0
        @warn "No eigenvalue data available"
        return Figure()
    end

    valid_indices = [i for i in 1:n_points if !any(isnan, all_eigenvalues[i])]
    if isempty(valid_indices)
        @warn "No valid eigenvalue data found"
        return Figure()
    end

    n_dims = length(all_eigenvalues[valid_indices[1]])

    # Separate indices by critical point type
    point_types = [:minimum, :saddle, :maximum]
    # CP type colors from shared CP_TYPE_TABLE (interfaces.jl)

    type_indices = Dict()
    for ptype in point_types
        type_mask = [i for i in valid_indices if df.critical_point_type[i] == ptype]
        if !isempty(type_mask)
            if sort_by == :magnitude
                type_indices[ptype] =
                    sort(type_mask, by = i -> maximum(abs.(all_eigenvalues[i])), rev = true)
            elseif sort_by == :abs_magnitude
                type_indices[ptype] =
                    sort(type_mask, by = i -> maximum(abs.(all_eigenvalues[i])), rev = true)
            elseif sort_by == :smallest
                type_indices[ptype] = sort(type_mask, by = i -> minimum(all_eigenvalues[i]))
            elseif sort_by == :largest
                type_indices[ptype] =
                    sort(type_mask, by = i -> maximum(all_eigenvalues[i]), rev = true)
            elseif sort_by == :spread
                type_indices[ptype] = sort(
                    type_mask,
                    by = i -> maximum(all_eigenvalues[i]) - minimum(all_eigenvalues[i]),
                    rev = true
                )
            else  # :index
                type_indices[ptype] = type_mask
            end
        end
    end

    available_types = [
        ptype for ptype in point_types if
        haskey(type_indices, ptype) && !isempty(type_indices[ptype])
    ]
    n_types = length(available_types)

    if n_types == 0
        @warn "No valid critical point types found"
        return Figure()
    end

    fig = Figure(size = something(fig_size, (1400, 400 * n_types)))

    y_label =
        sort_by == :abs_magnitude ? "Eigenvalue Magnitude (Absolute Value)" :
        "Eigenvalue Magnitude"

    eigenval_colors = [:red, :blue, :green, :orange, :purple]
    eigenval_labels = ["λ₁ (smallest)", "λ₂ (middle)", "λ₃ (largest)", "λ₄", "λ₅"]

    for (subplot_idx, ptype) in enumerate(available_types)
        sorted_indices = type_indices[ptype]
        type_color = CP_TYPE_TABLE[normalize_cp_key(ptype)].color

        plot_title =
            sort_by == :abs_magnitude ?
            "$(uppercase(string(ptype))) Points - Eigenvalue Spectrum (Absolute Values)" :
            "$(uppercase(string(ptype))) Points - Complete Eigenvalue Spectrum"

        ax = Axis(
            fig[subplot_idx, 1],
            xlabel = "$(uppercase(string(ptype))) Point Index (sorted by $(sort_by))",
            ylabel = y_label,
            title = plot_title,
            xgridvisible = false
        )

        for (plot_idx, orig_idx) in enumerate(sorted_indices)
            eigenvals = sort(all_eigenvalues[orig_idx])
            x_pos = plot_idx
            plot_vals = sort_by == :abs_magnitude ? abs.(eigenvals) : eigenvals

            lines!(
                ax,
                fill(x_pos, length(plot_vals)),
                plot_vals,
                color = type_color,
                linestyle = :dot,
                linewidth = 1,
                alpha = 0.7
            )

            for (eig_idx, (eigenval, plot_val)) in enumerate(zip(eigenvals, plot_vals))
                scatter!(
                    ax,
                    [x_pos],
                    [plot_val],
                    color = eigenval_colors[min(eig_idx, length(eigenval_colors))],
                    marker = :circle,
                    markersize = 8,
                    strokecolor = type_color,
                    strokewidth = 1.5
                )
            end
        end

        if sort_by != :abs_magnitude
            hlines!(ax, [0], color = :black, linestyle = :dash, alpha = 0.5)
        end
    end

    # Eigenvalue legend
    eigenval_legend_elements = [
        MarkerElement(
            color = eigenval_colors[i],
            marker = :circle,
            markersize = 10
        ) for i in 1:min(n_dims, length(eigenval_colors))
    ]
    eigenval_legend_labels = eigenval_labels[1:min(n_dims, length(eigenval_labels))]

    # Type color legend
    type_legend_elements = [
        MarkerElement(
            color = :black,
            marker = :circle,
            markersize = 10,
            strokecolor = CP_TYPE_TABLE[normalize_cp_key(ptype)].color,
            strokewidth = 2
        ) for ptype in available_types
    ]
    type_legend_labels = ["$(uppercase(string(ptype))) Points" for ptype in available_types]

    Legend(
        fig[1:n_types, 2],
        eigenval_legend_elements,
        eigenval_legend_labels,
        "Eigenvalue Order",
        tellheight = false,
        framevisible = true
    )
    Legend(
        fig[1:n_types, 3],
        type_legend_elements,
        type_legend_labels,
        "Critical Point Type",
        tellheight = false,
        framevisible = true
    )

    return fig
end

# ──────────────────────────────────────────────────────────────────────────────
# plot_raw_vs_refined_eigenvalues
# ──────────────────────────────────────────────────────────────────────────────

"""
    plot_raw_vs_refined_eigenvalues(f, df_raw, df_refined; sort_by=:euclidean_distance, fig_size=nothing)

Before/after BFGS comparison of eigenvalues at matched critical points.
Sort options: `:euclidean_distance`, `:function_value_diff`, `:eigenvalue_change`.
"""
function plot_raw_vs_refined_eigenvalues(
    f::Function,
    df_raw::DataFrames.DataFrame,
    df_refined::DataFrames.DataFrame;
    sort_by = :euclidean_distance,
    fig_size::Union{Tuple{Int,Int},Nothing} = nothing
)
    matches = Globtim.match_raw_to_refined_points(df_raw, df_refined)

    if isempty(matches)
        @warn "No matching points found between raw and refined datasets"
        return Figure()
    end

    raw_eigenvalues = Globtim.extract_all_eigenvalues_for_visualization(f, df_raw)
    refined_eigenvalues = Globtim.extract_all_eigenvalues_for_visualization(f, df_refined)

    if "critical_point_type" in names(df_refined)
        type_groups = Dict()
        for (raw_idx, refined_idx, distance) in matches
            ptype = df_refined.critical_point_type[refined_idx]
            if !haskey(type_groups, ptype)
                type_groups[ptype] = []
            end
            push!(type_groups[ptype], (raw_idx, refined_idx, distance))
        end

        available_types = collect(keys(type_groups))
        n_types = length(available_types)
    else
        type_groups = Dict(:all => matches)
        available_types = [:all]
        n_types = 1
    end

    if n_types == 0
        @warn "No valid critical point types found in matches"
        return Figure()
    end

    fig = Figure(size = something(fig_size, (1400, 600 * n_types)))

    # CP type colors from shared CP_TYPE_TABLE (interfaces.jl)
    # :all is a special aggregate key, not a real CP type — use :darkblue
    _all_color = :darkblue

    eigenval_colors = [:red, :blue, :green, :orange, :purple]

    for (subplot_idx, ptype) in enumerate(available_types)
        type_matches = type_groups[ptype]
        nk = normalize_cp_key(ptype)
        type_color = haskey(CP_TYPE_TABLE, nk) ? CP_TYPE_TABLE[nk].color : _all_color

        if sort_by == :euclidean_distance
            sort!(type_matches, by = x -> x[3])
        elseif sort_by == :function_value_diff
            sort!(type_matches, by = x -> abs(df_raw.z[x[1]] - df_refined.z[x[2]]))
        else
            sort!(type_matches, by = x -> x[3])
        end

        plot_title = "Raw vs Refined Eigenvalues: $(uppercase(string(ptype))) Points"
        ax = Axis(
            fig[subplot_idx, 1],
            xlabel = "Matched Pair Index (sorted by $(sort_by))",
            ylabel = "Eigenvalue Magnitude",
            title = plot_title,
            xgridvisible = false
        )

        for (pair_idx, (raw_idx, refined_idx, distance)) in enumerate(type_matches)
            x_pos = pair_idx

            raw_eigenvals = raw_eigenvalues[raw_idx]
            refined_eigenvals = refined_eigenvalues[refined_idx]

            if any(isnan, raw_eigenvals) || any(isnan, refined_eigenvals)
                continue
            end

            raw_sorted = sort(raw_eigenvals)
            refined_sorted = sort(refined_eigenvals)

            n_eigenvals = min(length(raw_sorted), length(refined_sorted))

            raw_y_offset = 0.3
            refined_y_offset = -0.3

            # Raw eigenvalues (lighter, top)
            for (eig_idx, eigenval) in enumerate(raw_sorted[1:n_eigenvals])
                y_pos = eigenval + raw_y_offset
                scatter!(
                    ax,
                    [x_pos],
                    [y_pos],
                    color = eigenval_colors[min(eig_idx, length(eigenval_colors))],
                    marker = :circle,
                    markersize = 8,
                    strokecolor = type_color,
                    strokewidth = 1.5,
                    alpha = 0.6
                )
            end

            # Refined eigenvalues (darker, bottom)
            for (eig_idx, eigenval) in enumerate(refined_sorted[1:n_eigenvals])
                y_pos = eigenval + refined_y_offset
                scatter!(
                    ax,
                    [x_pos],
                    [y_pos],
                    color = eigenval_colors[min(eig_idx, length(eigenval_colors))],
                    marker = :circle,
                    markersize = 8,
                    strokecolor = type_color,
                    strokewidth = 1.5,
                    alpha = 1.0
                )
            end

            # Connect corresponding eigenvalues
            for eig_idx in 1:n_eigenvals
                raw_y = raw_sorted[eig_idx] + raw_y_offset
                refined_y = refined_sorted[eig_idx] + refined_y_offset

                lines!(
                    ax,
                    [x_pos, x_pos],
                    [raw_y, refined_y],
                    color = eigenval_colors[min(eig_idx, length(eigenval_colors))],
                    linestyle = :solid,
                    linewidth = 1.5,
                    alpha = 0.7
                )
            end

            # Distance annotation
            if distance > 0
                text!(
                    ax,
                    x_pos,
                    minimum(refined_sorted) + refined_y_offset - 0.1,
                    text = "d=$(round(distance, digits=3))",
                    fontsize = 8,
                    color = :gray,
                    align = (:center, :top)
                )
            end
        end

        hlines!(ax, [0], color = :black, linestyle = :dash, alpha = 0.5)

        hlines!(
            ax,
            [0],
            color = type_color,
            linestyle = :solid,
            alpha = 0.3,
            linewidth = 2
        )
    end

    # Legends
    n_dims = length(raw_eigenvalues) > 0 ? length(filter(!isnan, raw_eigenvalues[1])) : 3
    eigenval_legend_elements = [
        MarkerElement(
            color = eigenval_colors[i],
            marker = :circle,
            markersize = 10
        ) for i in 1:min(n_dims, length(eigenval_colors))
    ]
    eigenval_legend_labels = ["λ$i" for i in 1:min(n_dims, length(eigenval_colors))]

    raw_refined_elements = [
        MarkerElement(
            color = :blue,
            marker = :circle,
            markersize = 10,
            alpha = 0.6
        ),
        MarkerElement(
            color = :blue,
            marker = :circle,
            markersize = 10,
            alpha = 1.0
        )
    ]
    raw_refined_labels = ["Raw (polynomial)", "Refined (BFGS)"]

    Legend(
        fig[1:n_types, 2],
        eigenval_legend_elements,
        eigenval_legend_labels,
        "Eigenvalue Order",
        tellheight = false,
        framevisible = true
    )
    Legend(
        fig[1:n_types, 3],
        raw_refined_elements,
        raw_refined_labels,
        "Point Type",
        tellheight = false,
        framevisible = true
    )

    return fig
end

module GlobtimGLMakieExt

using GlobtimPlots
using GLMakie
using DataFrames
using StaticArrays
using Parameters
using DynamicPolynomials
using LinearAlgebra

# Placeholder types - these would normally come from the main optimization package
struct LevelSetData{T}
    # Placeholder structure
end

struct VisualizationParameters{T}
    # Placeholder structure
end

struct ApproxPoly{T,S}
    # Placeholder structure
end

struct TestInput
    # Placeholder structure
end

# GLMakie-specific plotting functions

function plot_error_function_1D_with_critical_points(
    pol::ApproxPoly,
    TR::TestInput,
    df::DataFrame,
    x,
    wd_in_std_basis,
    p_true,
    plot_range,
    distance;
    xlabel = "Parameter 1",
    model_func = "Unknown Model",
    figure_size = (1200, 1000),
    num_levels = 30,
)
    @assert size(pol.grid, 2) == 1 "Grid must be 1D for this function"

    # Grid on [a] ± [b]
    fine_grid = Iterators.product(plot_range...) |> collect
    fine_grid = map(i -> TR.center + collect(i), fine_grid)

    # Grid on [-1, 1] ± eps
    pullback(x) = (1 / pol.scale_factor) * (x .- TR.center)
    pushforward(x) = pol.scale_factor * x .+ TR.center
    fine_grid_pullback = map(pullback, fine_grid)

    # @info "" fine_grid fine_grid_pullback

    # f(x) on [a] ± [b]
    fine_values_f = map(TR.objective, fine_grid)

    # w_d(x) on [-1, 1] ± eps
    poly_func =
        p -> DynamicPolynomials.coefficients(
            DynamicPolynomials.subs(wd_in_std_basis, x => p),
        )[1]
    fine_values_wd = map(poly_func, fine_grid_pullback)

    # @info "" fine_values_f fine_values_wd

    # ||f - w_d||_s
    fine_values_f_minus_wd = log2.(abs.(fine_values_wd .- fine_values_f) .+ eps(Float64))

    z_limits_f = (minimum(fine_values_f), maximum(fine_values_f))
    z_limits_wd = (minimum(fine_values_wd), maximum(fine_values_wd))
    z_limits_f_minus_wd = (minimum(fine_values_f_minus_wd), maximum(fine_values_f_minus_wd))

    @info "" z_limits_f z_limits_wd z_limits_f_minus_wd

    # Combine z_limits
    # Option 1
    z_limits = (min(z_limits_f[1], z_limits_wd[1]), max(z_limits_f[2], z_limits_wd[2]))
    # Option 2
    z_limits = z_limits_f
    z_limits = (
        z_limits[1] - 0.1 * abs(z_limits[2] - z_limits[1]),
        z_limits[2] + 0.1 * abs(z_limits[2] - z_limits[1]),
    )
    @info "" z_limits

    levels = range(z_limits[1], z_limits[2], length = num_levels)
    levels_f_wd = range(z_limits_f_minus_wd[1], z_limits_f_minus_wd[2], length = num_levels)

    fig = Figure(size = figure_size)

    ax = Axis(
        fig[1, 1],
        title = "$model_func, f(x) = $distance",
        xlabel = xlabel,
        ylabel = "f(x)",
    )

    # @info "" map(first, fine_grid) map(last, fine_grid) fine_values_f

    cf = plot!(ax, map(first, fine_grid), fine_values_f; alpha = 0.3)
    pt = scatter!(
        ax,
        map(first, p_true),
        TR.objective.(map(p -> p[1:1], p_true)),
        markersize = 20,
        color = :green,
        marker = :diamond,
    )
    # for p_true_i in p_true
    #     pt = scatter!(
    #         ax,
    #         p_true_i[1],
    #         TR.objective(p_true_i),
    #         markersize = 20,
    #         color = :green,
    #         marker = :diamond,
    #     )
    # end
    # pt = arc!(
    #     ax,
    #     p_true,
    #     (maximum(plot_range[1]) - minimum(plot_range[1])) / 20,
    #     0,
    #     2π,
    #     color = :green,
    #     label = "p_true",
    # )
    cp = scatter!(ax, df.x1, df.z, markersize = 10, color = :blue, marker = :diamond)

    ax = Axis(
        fig[1, 2],
        title = "w_d(x), d = $(pol.degree)",
        xlabel = xlabel,
        ylabel = "w_d(x)",
    )

    cf = plot!(ax, map(first, fine_grid), fine_values_wd; alpha = 0.3)
    cp = scatter!(
        ax,
        df.x1,
        poly_func.((x -> Vector(pullback([x]))).(df.x1)),
        markersize = 10,
        color = :blue,
        marker = :diamond,
    )
    # rct = lines!(
    #     ax,
    #     [
    #         TR.center[1] - TR.sample_range,
    #         TR.center[1] - TR.sample_range,
    #         TR.center[1] + TR.sample_range,
    #         TR.center[1] + TR.sample_range,
    #         TR.center[1] - TR.sample_range,
    #     ],
    #     [
    #         TR.center[2] - TR.sample_range,
    #         TR.center[2] + TR.sample_range,
    #         TR.center[2] + TR.sample_range,
    #         TR.center[2] - TR.sample_range,
    #         TR.center[2] - TR.sample_range,
    #     ],
    #     color = :black,
    #     linewidth = 3,
    #     linestyle = :dash,
    # )

    # Colorbar(fig[1, 3], cf, label = "")

    Legend(
        fig[2, 1],
        [cf, cp, pt],
        ["function", "Critical Points of w_d", "True Parameter"],
        orientation = :horizontal,  # Make legend horizontal for better space usage
        tellwidth = false,         # Don't have legend width affect layout
        tellheight = true,
        patchsize = (30, 20),
    )

    fig
end

function plot_error_function_2D_with_critical_points(
    fig,
    pol::ApproxPoly,
    TR::TestInput,
    df::DataFrame,
    x,
    wd_in_std_basis,
    p_true,
    plot_range,
    distance;
    arrow_norm_factor = 0.1,
    xlabel = "Parameter 1",
    ylabel = "Parameter 2",
    model_func = "Unknown Model",
    colorbar = true,
    figure_size = (1200, 1000),
    chosen_colormap = :inferno,
    colorbar_label = "Loss Value",
    num_levels = 30,
    critical_point_threshold_for_hessian = 1e-2,
)
    @assert size(pol.grid, 2) == 2 "Grid must be 2D for this function"

    # Grid on [a, b] ± [c, d]
    fine_grid = Iterators.product(plot_range...) |> collect
    fine_grid = map(i -> TR.center + collect(i), fine_grid)

    # Grid on [-1, 1] x [-1, 1] ± eps
    pullback(x) = (1 / pol.scale_factor) * (x .- TR.center)
    pushforward(x) = pol.scale_factor * x .+ TR.center
    fine_grid_pullback = map(pullback, fine_grid)

    # @info "" fine_grid fine_grid_pullback

    # f(x) on [a, b] ± [c, d]
    fine_values_f = Float64.(map(TR.objective, fine_grid))

    # w_d(x) on [-1, 1] x [-1, 1] ± eps
    poly_func(poly) =
        p -> (
            cfs = DynamicPolynomials.coefficients(DynamicPolynomials.subs(poly, x => p));
            isempty(cfs) ? 0.0 : cfs[1]
        )
    fine_values_wd = map(poly_func(wd_in_std_basis), fine_grid_pullback)

    # @info "" fine_values_f fine_values_wd

    # ||f - w_d||_s
    fine_values_f_minus_wd = log2.(abs.(fine_values_wd .- fine_values_f) .+ eps(Float64))

    z_limits_f = (minimum(fine_values_f), maximum(fine_values_f))
    z_limits_wd = (minimum(fine_values_wd), maximum(fine_values_wd))
    z_limits_f_minus_wd = (minimum(fine_values_f_minus_wd), maximum(fine_values_f_minus_wd))

    @info "" z_limits_f z_limits_wd z_limits_f_minus_wd

    # Combine z_limits
    # Option 1
    z_limits = (min(z_limits_f[1], z_limits_wd[1]), max(z_limits_f[2], z_limits_wd[2]))
    # Option 2
    z_limits = z_limits_f
    z_limits = (
        z_limits[1] - 0.1 * abs(z_limits[2] - z_limits[1]),
        z_limits[2] + 0.1 * abs(z_limits[2] - z_limits[1]),
    )
    @info "" z_limits

    levels = range(z_limits[1], z_limits[2], length = num_levels)
    levels_f_wd = range(z_limits_f_minus_wd[1], z_limits_f_minus_wd[2], length = num_levels)

    # fig = Figure(size = figure_size)

    ax = Axis(
        fig[1, 1],
        title = "$model_func, f(x) = $distance",
        xlabel = xlabel,
        ylabel = ylabel,
    )

    # @info "" map(first, fine_grid) map(last, fine_grid) fine_values_f

    cf = contourf!(
        ax,
        map(first, fine_grid),
        map(last, fine_grid),
        fine_values_f;
        colormap = chosen_colormap,
        levels = levels,
    )

    pts_along_valley = df[df.z .< critical_point_threshold_for_hessian, :]

    grad = DynamicPolynomials.differentiate(wd_in_std_basis, x)
    grad_func(x) = map(f -> f(pullback(x)), poly_func.(grad))
    grad_at_cp = map(pt -> grad_func([pt.x1, pt.x2]), eachrow(pts_along_valley))

    hess = DynamicPolynomials.differentiate(grad, x)
    hess_func(x) = map(f -> f(pullback(x)), poly_func.(hess))
    hess_at_cp = map(pt -> hess_func([pt.x1, pt.x2]), eachrow(pts_along_valley))

    percent(x, v) = 1 - count(<(x), v) / length(v)

    pt = scatter!(
        ax,
        map(first, p_true),
        map(last, p_true),
        color = :green,
        marker = :diamond,
    )
    # for p_true_i in p_true
    #     pt = scatter!(
    #         ax,
    #         p_true_i[1],
    #         p_true_i[2],
    #         markersize = 10,
    #         color = :green,
    #         marker = :diamond,
    #     )
    # end
    # pt = arc!(
    #     ax,
    #     p_true,
    #     (maximum(plot_range[1]) - minimum(plot_range[1])) / 20,
    #     0,
    #     2π,
    #     color = :green,
    #     label = "p_true",
    # )
    cp = scatter!(
        ax,
        df.x1,
        df.x2,
        markersize = round.(
            Int,
            10*percent.(norm.(grad_at_cp), Ref(norm.(grad_at_cp))),
            RoundUp,
        ),
        # markersize = max.(1, round.(Int, 15*norm.(grad_at_cp) ./ maximum(norm.(grad_at_cp)))),
        color = :blue,
        marker = :diamond,
    )

    ax = Axis(
        fig[1, 2],
        title = "w_d(x), d = $(pol.degree)",
        xlabel = xlabel,
        ylabel = ylabel,
    )

    cf = contourf!(
        ax,
        map(first, fine_grid),
        map(last, fine_grid),
        fine_values_wd,
        colormap = chosen_colormap,
        levels = levels,
    )

    cp = scatter!(
        ax,
        df.x1,
        df.x2,
        markersize = 10,# round.(Int, 10*percent.(norm.(grad_at_cp), Ref(norm.(grad_at_cp))), RoundUp), 
        color = :blue,
        marker = :diamond,
    )
    rct = lines!(
        ax,
        [
            TR.center[1] - TR.sample_range,
            TR.center[1] - TR.sample_range,
            TR.center[1] + TR.sample_range,
            TR.center[1] + TR.sample_range,
            TR.center[1] - TR.sample_range,
        ],
        [
            TR.center[2] - TR.sample_range,
            TR.center[2] + TR.sample_range,
            TR.center[2] + TR.sample_range,
            TR.center[2] - TR.sample_range,
            TR.center[2] - TR.sample_range,
        ],
        color = :black,
        linewidth = 3,
        linestyle = :dash,
    )

    norm_factor = arrow_norm_factor * TR.sample_range
    ar = arrows!(
        ax,
        repeat([pts_along_valley.x1[i] for i in 1:length(eachrow(pts_along_valley))], 2),
        repeat([pts_along_valley.x2[i] for i in 1:length(eachrow(pts_along_valley))], 2),
        vcat(
            [
                eigvecs(hess_at_cp[i])[1, 1] * norm_factor for
                i in 1:length(eachrow(pts_along_valley))
            ],
            [
                eigvecs(hess_at_cp[i])[2, 1] * norm_factor for
                i in 1:length(eachrow(pts_along_valley))
            ],
        ),
        vcat(
            [
                eigvecs(hess_at_cp[i])[1, 2] * norm_factor for
                i in 1:length(eachrow(pts_along_valley))
            ],
            [
                eigvecs(hess_at_cp[i])[2, 2] * norm_factor for
                i in 1:length(eachrow(pts_along_valley))
            ],
        ),
        color = :red,
        alpha = 0.6,
        linewidth = 2.0,
        # label="My Arrow"
    )

    Colorbar(fig[1, 3], cf, label = "")

    Legend(
        fig[2, 1],
        [cp, pt, rct, ar],
        [
            "Critical Points of w_d (size is norm of Hessisan of w_d)",
            "True Parameter",
            "Sample Range",
            "Eigenvectors of Hessian",
        ],
        orientation = :horizontal,  # Make legend horizontal for better space usage
        tellwidth = false,         # Don't have legend width affect layout
        tellheight = true,
        # patchsize = (30, 20),
    )

    fig
end

# Convenience method that creates its own figure
function plot_error_function_2D_with_critical_points(
    pol::ApproxPoly,
    TR::TestInput,
    df::DataFrame,
    x,
    wd_in_std_basis,
    p_true,
    plot_range,
    distance;
    figure_size = (1200, 1000),
    kwargs...,
)
    fig = Figure(size = figure_size)
    plot_error_function_2D_with_critical_points(
        fig,
        pol,
        TR,
        df,
        x,
        wd_in_std_basis,
        p_true,
        plot_range,
        distance;
        figure_size = figure_size,
        kwargs...,
    )
    return fig
end

# Method that accepts a GridPosition or GridLayout position
function plot_error_function_2D_with_critical_points(
    grid_position::Union{Makie.GridPosition,Makie.GridLayout},
    pol::ApproxPoly,
    TR::TestInput,
    df::DataFrame,
    x,
    wd_in_std_basis,
    p_true,
    plot_range,
    distance;
    arrow_norm_factor = 0.1,
    xlabel = "Parameter 1",
    ylabel = "Parameter 2",
    model_func = "Unknown Model",
    colorbar = true,
    figure_size = (1200, 1000),
    chosen_colormap = :inferno,
    colorbar_label = "Loss Value",
    num_levels = 30,
    critical_point_threshold_for_hessian = 1e-2,
    # Layout control parameters for GridPosition usage
    plot1_pos = (1, 1),
    plot2_pos = (1, 2),
    colorbar_pos = (1, 3),
    legend_pos = (2, 1),
    legend_span = nothing,
)
    @assert size(pol.grid, 2) == 2 "Grid must be 2D for this function"

    # Grid on [a, b] ± [c, d]
    fine_grid = Iterators.product(plot_range...) |> collect
    fine_grid = map(i -> TR.center + collect(i), fine_grid)

    # Grid on [-1, 1] x [-1, 1] ± eps
    pullback(x) = (1 / pol.scale_factor) * (x .- TR.center)
    pushforward(x) = pol.scale_factor * x .+ TR.center
    fine_grid_pullback = map(pullback, fine_grid)

    # f(x) on [a, b] ± [c, d]
    fine_values_f = Float64.(map(TR.objective, fine_grid))

    # w_d(x) on [-1, 1] x [-1, 1] ± eps
    poly_func(poly) =
        p -> (
            cfs = DynamicPolynomials.coefficients(DynamicPolynomials.subs(poly, x => p));
            isempty(cfs) ? 0.0 : cfs[1]
        )
    fine_values_wd = map(poly_func(wd_in_std_basis), fine_grid_pullback)

    # ||f - w_d||_s
    fine_values_f_minus_wd = log2.(abs.(fine_values_wd .- fine_values_f) .+ eps(Float64))

    z_limits_f = (minimum(fine_values_f), maximum(fine_values_f))
    z_limits_wd = (minimum(fine_values_wd), maximum(fine_values_wd))
    z_limits_f_minus_wd = (minimum(fine_values_f_minus_wd), maximum(fine_values_f_minus_wd))

    @info "" z_limits_f z_limits_wd z_limits_f_minus_wd

    # Combine z_limits
    z_limits = z_limits_f
    z_limits = (
        z_limits[1] - 0.1 * abs(z_limits[2] - z_limits[1]),
        z_limits[2] + 0.1 * abs(z_limits[2] - z_limits[1]),
    )
    @info "" z_limits

    levels = range(z_limits[1], z_limits[2], length = num_levels)
    levels_f_wd = range(z_limits_f_minus_wd[1], z_limits_f_minus_wd[2], length = num_levels)

    # First plot
    ax = Axis(
        grid_position[plot1_pos...],
        title = "$model_func, f(x) = $distance",
        xlabel = xlabel,
        ylabel = ylabel,
    )

    # Extract x and y coordinates
    x_coords = Float64.(plot_range[1] .+ TR.center[1])
    y_coords = Float64.(plot_range[2] .+ TR.center[2])

    cf = contourf!(
        ax,
        x_coords,
        y_coords,
        reshape(fine_values_f, length(plot_range[2]), length(plot_range[1]))' |>
        Matrix{Float64};
        colormap = chosen_colormap,
        levels = levels,
    )

    pt = scatter!(
        ax,
        map(first, p_true),
        map(last, p_true),
        markersize = 10,
        color = :green,
        marker = :diamond,
    )
    cp = scatter!(ax, df.x1, df.x2, markersize = 10, color = :blue, marker = :diamond)

    # Second plot
    ax = Axis(
        grid_position[plot2_pos...],
        title = "w_d(x), d = $(pol.degree)",
        xlabel = xlabel,
        ylabel = ylabel,
    )

    cf = contourf!(
        ax,
        x_coords,
        y_coords,
        reshape(fine_values_wd, length(plot_range[2]), length(plot_range[1]))' |>
        Matrix{Float64},
        colormap = chosen_colormap,
        levels = levels,
    )
    cp = scatter!(ax, df.x1, df.x2, markersize = 10, color = :blue, marker = :diamond)
    rct = lines!(
        ax,
        [
            TR.center[1] - TR.sample_range,
            TR.center[1] - TR.sample_range,
            TR.center[1] + TR.sample_range,
            TR.center[1] + TR.sample_range,
            TR.center[1] - TR.sample_range,
        ],
        [
            TR.center[2] - TR.sample_range,
            TR.center[2] + TR.sample_range,
            TR.center[2] + TR.sample_range,
            TR.center[2] - TR.sample_range,
            TR.center[2] - TR.sample_range,
        ],
        color = :black,
        linewidth = 3,
        linestyle = :dash,
    )

    pts_along_valley = df[df.z .< critical_point_threshold_for_hessian, :]

    grad = DynamicPolynomials.differentiate(wd_in_std_basis, x)
    grad_func(x) = map(f -> f(pullback(x)), poly_func.(grad))
    grad_at_cp = map(pt -> grad_func([pt.x1, pt.x2]), eachrow(pts_along_valley))

    hess = DynamicPolynomials.differentiate(grad, x)
    hess_func(x) = map(f -> f(pullback(x)), poly_func.(hess))
    hess_at_cp = map(pt -> hess_func([pt.x1, pt.x2]), eachrow(pts_along_valley))

    norm_factor = arrow_norm_factor * TR.sample_range
    ar = arrows2d!(
        ax,
        repeat([pts_along_valley.x1[i] for i in 1:length(eachrow(pts_along_valley))], 2),
        repeat([pts_along_valley.x2[i] for i in 1:length(eachrow(pts_along_valley))], 2),
        vcat(
            [
                eigvecs(hess_at_cp[i])[1, 1] * norm_factor for
                i in 1:length(eachrow(pts_along_valley))
            ],
            [
                eigvecs(hess_at_cp[i])[2, 1] * norm_factor for
                i in 1:length(eachrow(pts_along_valley))
            ],
        ),
        vcat(
            [
                eigvecs(hess_at_cp[i])[1, 2] * norm_factor for
                i in 1:length(eachrow(pts_along_valley))
            ],
            [
                eigvecs(hess_at_cp[i])[2, 2] * norm_factor for
                i in 1:length(eachrow(pts_along_valley))
            ],
        ),
        color = :red,
        alpha = 0.6,
        # linewidth=2.0,
    )

    if colorbar
        Colorbar(grid_position[colorbar_pos...], cf, label = colorbar_label)
    end

    legend_position =
        isnothing(legend_span) ? grid_position[legend_pos...] :
        grid_position[legend_pos[1], legend_span]
    Legend(
        legend_position,
        [cp, pt, rct, ar],
        [
            "Critical Points of w_d",
            "True Parameter",
            "Sample Range",
            "Eigenvectors of Hessian",
        ],
        orientation = :horizontal,
        tellwidth = false,
        tellheight = true,
    )

    return grid_position
end

# Note: plot_hessian_norms, plot_condition_numbers, plot_critical_eigenvalues,
# plot_all_eigenvalues, and plot_raw_vs_refined_eigenvalues have been moved to
# globtimplots/src/hessian_eigenvalue_plots.jl (backend-agnostic, abstract Makie API).

"""
    plot_polyapprox_3d(pol, TR, df, df_min; kwargs...)

Creates a 3D visualization of a polynomial approximation with critical points.
Requires GLMakie to be loaded.

# Returns
- `fig`: The GLMakie figure object
"""
function GlobtimPlots.plot_polyapprox_3d(
    pol::AbstractPolynomialData,
    TR::AbstractProblemInput,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int,Int} = (1000, 800),
    z_limits::Union{Nothing,Tuple{Float64,Float64}} = nothing,
    show_captured::Bool = true,
    alpha_surface::Float64 = 0.7,
    rotate::Bool = false,
    filename::String = "function_3d_rotation.mp4",
    fade::Bool = false,
    z_cut = 0.25,
)
    # Delegate to the backend-agnostic implementation in GlobtimPlots
    fig = GlobtimPlots._plot_polyapprox_3d_impl(
        pol,
        TR,
        df,
        df_min;
        figure_size = figure_size,
        z_limits = z_limits,
        show_captured = show_captured,
        alpha_surface = alpha_surface,
        fade = fade,
        z_cut = z_cut,
    )

    if isnothing(fig)
        return nothing
    end

    # GLMakie-specific: optional rotation animation (requires GLMakie.record)
    if rotate
        ax = content(fig[1, 1])
        @info "Recording animation to $(filename)..."
        GLMakie.record(fig, filename, 1:240; framerate = 30) do frame
            ax.azimuth[] = 3π / 4 + 2π * frame / 240
            ax.elevation[] = π / 6 + π / 12 * sin(2π * frame / 240)
        end
        @info "Animation saved to $(filename)!"
    end

    display(fig)
    return fig
end

end

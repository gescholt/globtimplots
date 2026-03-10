# 3D polynomial approximation surface visualization
#
# Uses the abstract Makie API — works with any backend (CairoMakie, GLMakie, WGLMakie).
# The GLMakie extension adds optional rotation animation via GLMakie.record().

"""
    _plot_polyapprox_3d_impl(pol, TR, df, df_min; kwargs...) -> Figure

Core implementation of 3D polynomial approximation visualization.
Returns a Figure with a 3D surface plot + critical point markers.

Backend-agnostic: uses abstract Makie API (Figure, Axis3, surface!, scatter!).
The GLMakie extension wraps this to add `rotate` animation support.

# Arguments
- `pol::AbstractPolynomialData`: Polynomial approximation data
- `TR::AbstractProblemInput`: Problem domain specification
- `df::DataFrame`: All critical points (must have columns `x1`, `x2`, `z`, optionally `close`)
- `df_min::DataFrame`: Minima points (must have columns `x1`, `x2`, `value`, `captured`)

# Keyword Arguments
- `figure_size::Tuple{Int,Int}=(1000,800)`: Figure dimensions
- `z_limits::Union{Nothing,Tuple{Float64,Float64}}=nothing`: Z-axis limits (auto-computed if nothing)
- `show_captured::Bool=true`: Whether to show captured minima markers
- `alpha_surface::Float64=0.7`: Surface transparency
- `fade::Bool=false`: Enable fade effect for top portion of z-range
- `z_cut::Float64=0.25`: Fraction of z-range to fade (when `fade=true`)
"""
function _plot_polyapprox_3d_impl(
    pol::AbstractPolynomialData,
    TR::AbstractProblemInput,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int, Int} = (1000, 800),
    z_limits::Union{Nothing, Tuple{Float64, Float64}} = nothing,
    show_captured::Bool = true,
    alpha_surface::Float64 = 0.7,
    fade::Bool = false,
    z_cut = 0.25
)
    coords = transform_coordinates(pol.scale_factor, pol.grid, TR.center)
    z_coords = pol.z

    if size(coords)[2] != 2
        @warn "plot_polyapprox_3d only works with 2D grid data"
        return nothing
    end

    fig = Figure(size = figure_size)
    ax = Axis3(
        fig[1, 1],
        xlabel = "x₁",
        ylabel = "x₂",
        zlabel = ""
    )

    # Calculate z_limits if not provided (filter non-finite values from ODE solver failures)
    if isnothing(z_limits)
        z_values = Float64[]
        append!(z_values, df.z)
        append!(z_values, df_min.value)
        append!(z_values, z_coords)
        finite_z = filter(isfinite, z_values)
        if isempty(finite_z)
            error("No finite z-values among critical points — cannot determine contour z_limits")
        end
        z_limits = (minimum(finite_z), maximum(finite_z))
    end

    # Prepare surface data
    x_unique = sort(unique(coords[:, 1]))
    y_unique = sort(unique(coords[:, 2]))
    Z = fill(NaN, (length(y_unique), length(x_unique)))

    z_threshold = z_limits[2] - z_cut * (z_limits[2] - z_limits[1])

    for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
        i = findlast(≈(y), y_unique)
        j = findlast(≈(x), x_unique)
        if !isnothing(i) && !isnothing(j)
            if !isfinite(z) || (!isnothing(z_limits) && (z < z_limits[1] || z > z_limits[2]))
                Z[j, i] = NaN
            else
                Z[j, i] = z
            end
        end
    end

    if fade
        Z_lower = copy(Z)
        Z_upper = copy(Z)

        for i in 1:size(Z, 1)
            for j in 1:size(Z, 2)
                if !isnan(Z[i, j])
                    if Z[i, j] >= z_threshold
                        Z_lower[i, j] = NaN
                    else
                        Z_upper[i, j] = NaN
                    end
                end
            end
        end

        surface!(
            ax,
            x_unique,
            y_unique,
            Z_lower,
            colormap = :viridis,
            transparency = true,
            alpha = alpha_surface,
            colorrange = z_limits
        )

        for fade_level in 1:10
            fade_alpha = alpha_surface * (1.0 - (fade_level - 1) / 10 * 0.9)
            z_min = z_threshold + (fade_level - 1) / 10 * (z_limits[2] - z_threshold)
            z_max = z_threshold + fade_level / 10 * (z_limits[2] - z_threshold)

            Z_level = copy(Z)
            for i in 1:size(Z, 1)
                for j in 1:size(Z, 2)
                    if isnan(Z[i, j]) || Z[i, j] < z_min || Z[i, j] >= z_max
                        Z_level[i, j] = NaN
                    end
                end
            end

            surface!(
                ax,
                x_unique,
                y_unique,
                Z_level,
                colormap = :viridis,
                transparency = true,
                alpha = fade_alpha,
                colorrange = z_limits
            )
        end
    else
        surface!(
            ax,
            x_unique,
            y_unique,
            Z,
            colormap = :viridis,
            transparency = true,
            alpha = alpha_surface,
            colorrange = z_limits
        )
    end

    # Set initial camera position
    ax.azimuth[] = 3π / 4
    ax.elevation[] = π / 6

    # Plot points from df with appropriate colors
    if :close in propertynames(df)
        close_idx = df.close
        if any(close_idx)
            scatter!(
                ax,
                df.x1[close_idx],
                df.x2[close_idx],
                df.z[close_idx],
                markersize = 10,
                color = :green,
                strokecolor = :black,
                strokewidth = 1,
                label = "Near"
            )
        end

        not_close_idx = .!df.close
        if any(not_close_idx)
            scatter!(
                ax,
                df.x1[not_close_idx],
                df.x2[not_close_idx],
                df.z[not_close_idx],
                markersize = 8,
                color = :white,
                strokecolor = :black,
                strokewidth = 1,
                label = "Far"
            )
        end
    else
        scatter!(
            ax,
            df.x1,
            df.x2,
            df.z,
            markersize = 20,
            color = :orange,
            label = "All Points"
        )
    end

    # Plot minima points from df_min
    if !isempty(df_min)
        uncaptured_idx = .!df_min.captured
        if any(uncaptured_idx)
            scatter!(
                ax,
                df_min.x1[uncaptured_idx],
                df_min.x2[uncaptured_idx],
                df_min.value[uncaptured_idx],
                markersize = 40,
                marker = :diamond,
                color = :red,
                label = "Uncaptured"
            )
        end

        if show_captured
            captured_idx = df_min.captured
            if any(captured_idx)
                scatter!(
                    ax,
                    df_min.x1[captured_idx],
                    df_min.x2[captured_idx],
                    df_min.value[captured_idx],
                    markersize = 40,
                    marker = :diamond,
                    color = :blue,
                    label = "Captured"
                )
            end
        end
    end

    return fig
end

module GlobtimCairoMakieExt

using GlobtimPlots
using CairoMakie
using DataFrames

# CairoMakie-specific extensions - source functions are in main package

"""
Updated visualization function to handle per-coordinate scaling factors.
"""
function GlobtimPlots.cairo_plot_polyapprox_levelset(
    pol::GlobtimPlots.AbstractPolynomialData,
    TR::GlobtimPlots.AbstractProblemInput,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int, Int} = (1000, 600),
    z_limits::Union{Nothing, Tuple{Float64, Float64}} = nothing,
    chebyshev_levels::Bool = false,
    num_levels::Int = 30,
    show_captured::Bool = true  # New parameter
)
    # Type-stable coordinate transformation using multiple dispatch
    coords = GlobtimPlots.transform_coordinates(pol.scale_factor, pol.grid, TR.center)

    z_coords = pol.z

    if size(coords)[2] == 2
        fig = CairoMakie.Figure(size = figure_size)
        ax = CairoMakie.Axis(fig[1, 1], title = "")

        # Calculate z_limits if not provided (filter non-finite values from ODE solver failures)
        if isnothing(z_limits)
            z_values = Float64[]
            append!(z_values, df.z)
            append!(z_values, df_min.value)
            finite_z = filter(isfinite, z_values)
            if isempty(finite_z)
                error("No finite z-values among critical points — cannot determine contour z_limits")
            end
            z_limits = (minimum(finite_z), maximum(finite_z))
        end

        # Calculate levels (must be finite and sorted for Makie contourf)
        levels = if chebyshev_levels
            k = collect(0:(num_levels - 1))
            cheb_nodes = -cos.((2k .+ 1) .* π ./ (2 * num_levels))
            z_min, z_max = z_limits
            lvls = (z_max - z_min) ./ 2 .* cheb_nodes .+ (z_max + z_min) ./ 2
            sort!(filter!(isfinite, lvls))
        else
            num_levels
        end

        # Prepare contour data
        x_unique = sort(unique(coords[:, 1]))
        y_unique = sort(unique(coords[:, 2]))
        Z = fill(NaN, (length(y_unique), length(x_unique)))

        for (idx, (x, y, z)) in enumerate(zip(coords[:, 1], coords[:, 2], z_coords))
            i = findlast(≈(y), y_unique)
            j = findlast(≈(x), x_unique)
            if !isnothing(i) && !isnothing(j)
                Z[j, i] = isfinite(z) ? z : NaN  # non-finite → NaN (empty cell in contourf)
            end
        end

        # Create contour plot
        chosen_colormap = :inferno
        CairoMakie.contourf!(ax, x_unique, y_unique, Z, colormap = chosen_colormap, levels = levels)

        # Initialize empty array for legend entries
        legend_entries = []

        # Plot and add legend entries for all point types
        if :close in propertynames(df)
            # Far points
            not_close_idx = .!df.close
            if any(not_close_idx)
                CairoMakie.scatter!(
                    ax,
                    df.x1[not_close_idx],
                    df.x2[not_close_idx],
                    markersize = 10,
                    color = :white,
                    strokecolor = :black,
                    strokewidth = 1,
                    label = "Far"
                )
                push!(legend_entries, "Far")
            end

            # Near points
            close_idx = df.close
            if any(close_idx)
                CairoMakie.scatter!(
                    ax,
                    df.x1[close_idx],
                    df.x2[close_idx],
                    markersize = 10,
                    color = :green,
                    strokecolor = :black,
                    strokewidth = 1,
                    label = "Near"
                )
                push!(legend_entries, "Near")
            end
        else
            # All points if no close/far distinction
            CairoMakie.scatter!(
                ax,
                df.x1,
                df.x2,
                markersize = 2,
                color = :orange,
                label = "All points"
            )
            push!(legend_entries, "All points")
        end

        # Uncaptured points
        if !isempty(df_min)
            uncaptured_idx = .!df_min.captured
            captured_idx = df_min.captured

            if any(uncaptured_idx)
                CairoMakie.scatter!(
                    ax,
                    df_min.x1[uncaptured_idx],
                    df_min.x2[uncaptured_idx],
                    markersize = 15,
                    marker = :diamond,
                    color = :red,
                    label = "Uncaptured"
                )
                push!(legend_entries, "Uncaptured")
            end

            # Only show captured points if show_captured is true
            if show_captured && any(captured_idx)
                CairoMakie.scatter!(
                    ax,
                    df_min.x1[captured_idx],
                    df_min.x2[captured_idx],
                    markersize = 15,
                    marker = :diamond,
                    color = :blue,
                    label = "Captured"
                )
                push!(legend_entries, "Captured")
            end
        end
        return fig
    end
end

# Note: plot_hessian_norms, plot_condition_numbers, plot_critical_eigenvalues,
# plot_all_eigenvalues, and plot_raw_vs_refined_eigenvalues have been moved to
# globtimplots/src/hessian_eigenvalue_plots.jl (backend-agnostic, abstract Makie API).

end

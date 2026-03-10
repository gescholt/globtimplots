# partition_viz.jl
# 2D domain partition visualization for adaptive mesh refinement
# Uses CairoMakie for publication-quality static plots
# Note: Rect is imported at module level in GlobtimPlots.jl

"""
    PartitionStyle

Styling configuration for 2D partition visualization.
"""
Base.@kwdef struct PartitionStyle
    # Colormap for error/degree coloring
    colormap::Symbol = :viridis

    # Stroke (border) styling
    strokewidth::Float64 = 1.5
    strokecolor::Symbol = :black

    # Label styling
    show_labels::Bool = true
    label_fontsize::Int = 10
    label_color::Symbol = :white

    # Figure sizing
    fig_size::Tuple{Int, Int} = (600, 600)

    # Domain limits (default to [-1,1]²)
    domain_limits::Tuple{Float64, Float64, Float64, Float64} = (-1.0, 1.0, -1.0, 1.0)

    # Colorbar
    show_colorbar::Bool = true
end

"""
    plot_2d_partition(subdomains; kwargs...)

Plot 2D subdomain partition on domain [-1,1]².

# Arguments
- `subdomains`: Iterable of objects with fields `center`, `half_widths`, `l2_error`, `degree`, `id`

# Keyword Arguments
- `color_by::Symbol = :l2_error`: Color by `:l2_error` (log scale) or `:degree`
- `title::String = "Domain Partition"`: Plot title
- `style::PartitionStyle = PartitionStyle()`: Styling configuration
- `fig = nothing`: Existing Figure to plot into (creates new if nothing)
- `ax = nothing`: Existing Axis to plot into (creates new if nothing)

# Returns
- `Figure`: The Makie figure

# Example
```julia
# Collect subdomains from episode
final_subs = collect_final_subdomains(env)

# Plot colored by L2 error
fig = plot_2d_partition(final_subs, color_by=:l2_error, title="AdaptiveL2 Policy")
save("partition.pdf", fig)

# Plot colored by degree
fig = plot_2d_partition(final_subs, color_by=:degree, title="Polynomial Degrees")
```
"""
function plot_2d_partition(
    subdomains;
    color_by::Symbol = :l2_error,
    title::String = "Domain Partition",
    style::PartitionStyle = PartitionStyle(),
    fig = nothing,
    ax = nothing
)
    # Validate color_by
    color_by in (:l2_error, :degree) || error("color_by must be :l2_error or :degree")

    # Collect subdomain data
    subs = collect(subdomains)
    isempty(subs) && error("No subdomains to plot")

    # Extract values for coloring
    if color_by == :l2_error
        raw_values = [getfield_or_index(s, :l2_error) for s in subs]
        # Use log scale for errors, handle zeros/negatives
        values = [v > 0 ? log10(v) : -16.0 for v in raw_values]
        colorbar_label = "log₁₀(L2 Error)"
    else
        values = Float64[getfield_or_index(s, :degree) for s in subs]
        colorbar_label = "Polynomial Degree"
    end

    # Normalize values to [0, 1] for colormap
    vmin, vmax = extrema(values)
    if vmin ≈ vmax
        normalized = fill(0.5, length(values))
    else
        normalized = (values .- vmin) ./ (vmax - vmin)
    end

    # Get colormap
    cmap = ColorSchemes.colorschemes[style.colormap]
    colors = [get(cmap, n, :clamp) for n in normalized]

    # Create figure if not provided
    if isnothing(fig)
        fig = Figure(size=style.fig_size)
    end

    # Create axis if not provided
    if isnothing(ax)
        xmin, xmax, ymin, ymax = style.domain_limits
        ax = Axis(fig[1, 1],
            title=title,
            xlabel="x₁", ylabel="x₂",
            aspect=DataAspect(),
            limits=(xmin, xmax, ymin, ymax)
        )
    end

    # Draw rectangles
    for (i, sub) in enumerate(subs)
        center = getfield_or_index(sub, :center)
        hw = getfield_or_index(sub, :half_widths)

        # Create rectangle from bottom-left corner
        rect = Rect(
            center[1] - hw[1],  # x_min
            center[2] - hw[2],  # y_min
            2 * hw[1],          # width
            2 * hw[2]           # height
        )

        poly!(ax, rect,
            color=colors[i],
            strokewidth=style.strokewidth,
            strokecolor=style.strokecolor
        )

        # Add label at center
        if style.show_labels
            id = getfield_or_index(sub, :id)
            text!(ax, center[1], center[2],
                text=string(id),
                align=(:center, :center),
                fontsize=style.label_fontsize,
                color=style.label_color
            )
        end
    end

    # Add colorbar
    if style.show_colorbar
        Colorbar(fig[1, 2],
            colormap=style.colormap,
            limits=(vmin, vmax),
            label=colorbar_label
        )
    end

    return fig
end

"""
    plot_l2_trajectories(trajectories; kwargs...)

Plot L2 error trajectories for multiple policies.

# Arguments
- `trajectories::Dict{String, Vector{Float64}}`: Policy name → L2 error vector

# Keyword Arguments
- `title::String = "L2 Error Evolution"`: Plot title
- `yscale = log10`: Y-axis scale (log10 or identity)
- `xlabel::String = "Step"`: X-axis label
- `ylabel::String = "L2 Error"`: Y-axis label
- `fig_size::Tuple{Int,Int} = (800, 500)`: Figure size

# Returns
- `Figure`: The Makie figure

# Example
```julia
trajectories = Dict(
    "AdaptiveL2" => run_episode(env, AdaptiveL2Policy()).l2_trajectory,
    "GreedyDegree" => run_episode(env, GreedyDegreePolicy()).l2_trajectory
)
fig = plot_l2_trajectories(trajectories)
```
"""
function plot_l2_trajectories(
    trajectories::Dict{String, Vector{Float64}};
    title::String = "L2 Error Evolution",
    yscale = log10,
    xlabel::String = "Step",
    ylabel::String = "L2 Error",
    fig_size::Tuple{Int, Int} = (800, 500)
)
    isempty(trajectories) && error("No trajectories to plot")

    fig = Figure(size=fig_size)
    ax = Axis(fig[1, 1],
        title=title,
        xlabel=xlabel,
        ylabel=ylabel,
        yscale=yscale
    )

    # Use Dark2 colors for distinguishable lines
    colors = ColorSchemes.Dark2_8

    for (i, (name, traj)) in enumerate(sort(collect(trajectories)))
        color = colors[mod1(i, length(colors))]
        lines!(ax, 1:length(traj), traj,
            label=name,
            linewidth=2,
            color=color
        )
    end

    # Add legend
    if length(trajectories) > 1
        Legend(fig[1, 2], ax)
    end

    return fig
end

"""
Helper to get field from struct or NamedTuple by symbol.
Works with both field access and getindex for Dict-like objects.
"""
function getfield_or_index(obj, field::Symbol)
    if hasfield(typeof(obj), field)
        return getfield(obj, field)
    elseif hasproperty(obj, field)
        return getproperty(obj, field)
    else
        return obj[field]
    end
end

"""
Level Set Visualization Functions for GlobtimPlots

This module provides 3D level set visualization capabilities that were
previously in globtimcore/src/LevelSetViz.jl. These functions use GLMakie
for interactive visualizations.

The functions work with generic data structures to avoid tight coupling
with Globtim internals.
"""

# NOTE: GLMakie removed from direct import - causes macOS precompilation segfault
# Users who need 3D interactive plots should: using GLMakie; GLMakie.activate!()
using Makie
using StaticArrays
using DataFrames

"""
    LevelSetData{T}

Container for level set point data.

# Fields
- `points::Vector{SVector{3,T}}`: 3D points on the level set
- `values::Vector{T}`: Function values at each point
- `level::T`: The level value
"""
struct LevelSetData{T <: AbstractFloat}
    points::Vector{SVector{3, T}}
    values::Vector{T}
    level::T

    function LevelSetData{T}(
        points::Vector{SVector{3, T}},
        values::Vector{T},
        level::T
    ) where {T <: AbstractFloat}
        length(points) == length(values) ||
            throw(ArgumentError("Points and values must have same length"))
        new{T}(points, values, level)
    end
end

LevelSetData(
    points::Vector{SVector{3, T}},
    values::Vector{T},
    level::T
) where {T <: AbstractFloat} = LevelSetData{T}(points, values, level)

"""
    VisualizationParameters{T}

Parameters for controlling level set visualization.

# Fields
- `point_tolerance::T`: Tolerance for level set detection (default: 0.1)
- `point_window::T`: Window size for filtering (default: 0.2)
- `fig_size::Tuple{Int,Int}`: Figure dimensions in pixels (default: (1000, 800))
"""
struct VisualizationParameters{T <: AbstractFloat}
    point_tolerance::T
    point_window::T
    fig_size::Tuple{Int, Int}

    function VisualizationParameters{T}(;
        point_tolerance::T = T(0.1),
        point_window::T = T(0.2),
        fig_size::Tuple{Int, Int} = (1000, 800)
    ) where {T <: AbstractFloat}
        new{T}(point_tolerance, point_window, fig_size)
    end
end

VisualizationParameters(;
    point_tolerance::T = 0.1,
    point_window::T = 0.2,
    fig_size::Tuple{Int, Int} = (1000, 800)
) where {T <: AbstractFloat} = VisualizationParameters{T}(;
    point_tolerance = point_tolerance,
    point_window = point_window,
    fig_size = fig_size
)

"""
    prepare_level_set_data(
        grid::Array{SVector{3,T},3},
        values::Array{T},
        level::T;
        tolerance::T = T(0.01)
    ) where {T<:AbstractFloat}

Identify points in the grid that are close to the specified level.

# Arguments
- `grid`: 3D array of grid points
- `values`: Function values at each grid point
- `level`: Target level value
- `tolerance`: Maximum distance from level to include point

# Returns
- `LevelSetData{T}`: Container with filtered points and values
"""
function prepare_level_set_data(
    grid::Array{SVector{3, T}, 3},
    values::Array{T},
    level::T;
    tolerance::T = T(0.01)
) where {T <: AbstractFloat}
    size(grid) == size(values) ||
        throw(DimensionMismatch("Grid and values must have same dimensions"))
    tolerance > zero(T) || throw(ArgumentError("Tolerance must be positive"))

    flat_grid = vec(grid)
    flat_values = vec(values)

    level_set_mask = @. abs(flat_values - level) < tolerance

    return LevelSetData(flat_grid[level_set_mask], flat_values[level_set_mask], level)
end

"""
    to_makie_format(level_set::LevelSetData{T}) where {T<:AbstractFloat}

Convert LevelSetData to format suitable for Makie plotting.

# Returns
Named tuple with:
- `points`: 3×N matrix of coordinates
- `values`: vector of function values
- `xyz`: tuple of (x, y, z) coordinate vectors
"""
function to_makie_format(level_set::LevelSetData{T}) where {T <: AbstractFloat}
    isempty(level_set.points) &&
        return (points = Matrix{T}(undef, 3, 0), values = T[], xyz = (T[], T[], T[]))

    points = reduce(hcat, level_set.points)
    return (
        points = points,
        values = level_set.values,
        xyz = (view(points, 1, :), view(points, 2, :), view(points, 3, :))
    )
end

"""
    plot_level_set(
        formatted_data;
        fig_size = (800, 600),
        marker_size = 4,
        title = "Level Set Visualization"
    )

Create a basic 3D scatter plot of level set points.

# Arguments
- `formatted_data`: Output from `to_makie_format`
- `fig_size`: Figure dimensions
- `marker_size`: Size of scatter markers
- `title`: Plot title

# Returns
- GLMakie Figure object
"""
function plot_level_set(
    formatted_data;
    fig_size = (800, 600),
    marker_size = 4,
    title = "Level Set Visualization"
)
    fig = Figure(size = fig_size)
    ax = Axis3(fig[1, 1], title = title, xlabel = "x₁", ylabel = "x₂", zlabel = "x₃")

    scatter!(ax, formatted_data.xyz..., markersize = marker_size)

    display(fig)
    return fig
end

"""
    create_level_set_visualization(
        f,
        grid::Array{SVector{3,T},3},
        df::Union{DataFrame,Nothing},
        z_range::Tuple{T,T},
        params::VisualizationParameters{T} = VisualizationParameters{T}()
    ) where {T<:AbstractFloat}

Create an interactive 3D level set visualization with a slider.

# Arguments
- `f`: Objective function to visualize
- `grid`: 3D array of sample points
- `df`: Optional DataFrame with critical points (columns: x1, x2, x3, z)
- `z_range`: Tuple (min, max) for level values
- `params`: Visualization parameters

# Returns
- GLMakie Figure with interactive slider

# Example
```julia
using GLMakie, StaticArrays, GlobtimPlots

# Create a simple test function
f(x) = x[1]^2 + x[2]^2 + x[3]^2

# Create grid
grid = [SVector{3,Float64}(x, y, z)
        for x in range(-1, 1, 50),
            y in range(-1, 1, 50),
            z in range(-1, 1, 50)]

# Visualize
fig = create_level_set_visualization(f, grid, nothing, (0.0, 3.0))
```
"""
function create_level_set_visualization(
    f,
    grid::Array{SVector{3, T}, 3},
    df::Union{DataFrame, Nothing},
    z_range::Tuple{T, T},
    params::VisualizationParameters{T} = VisualizationParameters{T}()
) where {T <: AbstractFloat}
    grid_points = vec(grid)
    valid_points = filter(p -> !any(isnan, p), grid_points)
    isempty(valid_points) && throw(ArgumentError("Grid contains no valid points"))

    z_min, z_max = z_range
    (isnan(z_min) || isnan(z_max)) && throw(ArgumentError("Invalid z_range"))

    fig = Figure(size = params.fig_size)
    ax = Axis3(fig[1, 1], xlabel = "x₁", ylabel = "x₂", zlabel = "x₃")

    x_range = extrema(p[1] for p in valid_points)
    y_range = extrema(p[2] for p in valid_points)
    z_range_grid = extrema(p[3] for p in valid_points)

    limits!(ax, x_range..., y_range..., z_range_grid...)

    level_slider =
        Slider(fig[2, 1], range = range(z_min, z_max, length = 1000), startvalue = z_min)

    Label(
        fig[3, 1],
        @lift(string("Level: ", round($(level_slider.value), digits = 3))),
        tellwidth = false
    )

    level_points = Observable(Point3f[])
    data_points = Observable(Point3f[])

    # Pre-compute function values for the entire grid
    values = zeros(T, size(grid)...)
    @inbounds for i in eachindex(grid_points)
        point = grid_points[i]
        values[i] = any(isnan, point) ? NaN : f(point)
    end

    scatter!(
        ax,
        level_points,
        color = :blue,
        markersize = 6,
        alpha = 0.7,
        label = "Level Set"
    )

    if !isnothing(df)
        scatter!(
            ax,
            data_points,
            color = :darkorange,
            marker = :diamond,
            markersize = 30,
            label = "Data Points"
        )
    end

    function update_visualization(level::T) where {T <: AbstractFloat}
        try
            # Update level set points
            level_data = prepare_level_set_data(
                grid,
                values,
                level,
                tolerance = params.point_tolerance
            )

            formatted_data = to_makie_format(level_data)

            # Update points atomically
            new_points = Point3f[]
            if !isempty(formatted_data.xyz[1])
                for (x, y, z) in zip(formatted_data.xyz...)
                    if !any(isnan, (x, y, z))
                        push!(new_points, Point3f(x, y, z))
                    end
                end
            end
            level_points[] = new_points

            if !isnothing(df)
                visible_points = Point3f[]
                for row in eachrow(df)
                    if !any(isnan, [row.x1, row.x2, row.x3, row.z]) &&
                       abs(row.z - level) ≤ params.point_tolerance
                        push!(visible_points, Point3f(row.x1, row.x2, row.x3))
                    end
                end
                data_points[] = visible_points
            end
        catch e
            @error "Error in visualization update" exception = e
            rethrow(e)
        end
    end

    on(level_slider.value) do level
        update_visualization(level)
    end

    update_visualization(z_min)
    axislegend(ax, position = :rt)

    return fig
end

"""
    create_level_set_animation(
        f,
        grid::Array{SVector{3,T},3},
        df::Union{DataFrame,Nothing},
        z_range::Tuple{T,T},
        params::VisualizationParameters{T} = VisualizationParameters{T}();
        fps::Int = 30,
        duration::Int = 20,
        output_file::String = "level_set_animation.mp4"
    ) where {T<:AbstractFloat}

Create an animated level set visualization that sweeps through levels
while rotating the camera.

# Arguments
- `f`: Objective function
- `grid`: 3D array of sample points
- `df`: Optional DataFrame with critical points
- `z_range`: Range of level values to animate
- `params`: Visualization parameters
- `fps`: Frames per second for animation
- `duration`: Animation duration in seconds
- `output_file`: Path to save the animation

# Returns
- GLMakie Figure object

# Example
```julia
fig = create_level_set_animation(
    f, grid, df, (-3.0, 6.0);
    fps = 30,
    duration = 10,
    output_file = "my_animation.mp4"
)
```
"""
function create_level_set_animation(
    f,
    grid::Array{SVector{3, T}, 3},
    df::Union{DataFrame, Nothing},
    z_range::Tuple{T, T},
    params::VisualizationParameters{T} = VisualizationParameters{T}();
    fps::Int = 30,
    duration::Int = 20,
    output_file::String = "level_set_animation.mp4"
) where {T <: AbstractFloat}
    grid_points = vec(grid)
    valid_points = filter(p -> !any(isnan, p), grid_points)

    z_min, z_max = z_range

    fig = Figure(size = params.fig_size)
    ax = Axis3(
        fig[1, 1],
        title = "Level Set Visualization",
        xlabel = "x₁",
        ylabel = "x₂",
        zlabel = "x₃"
    )

    # Set up initial ranges and limits
    x_range = extrema(p[1] for p in valid_points)
    y_range = extrema(p[2] for p in valid_points)
    z_range_grid = extrema(p[3] for p in valid_points)
    limits!(ax, x_range..., y_range..., z_range_grid...)

    # Pre-compute function values
    values = zeros(T, size(grid)...)
    @inbounds for i in eachindex(grid_points)
        point = grid_points[i]
        values[i] = any(isnan, point) ? NaN : f(point)
    end

    level_points = Observable(Point3f[])
    data_points = Observable(Point3f[])

    scatter!(ax, level_points, color = :blue, markersize = 2, label = "Level Set")

    if !isnothing(df)
        scatter!(
            ax,
            data_points,
            color = :darkorange,
            marker = :diamond,
            markersize = 20,
            label = "Data Points"
        )
    end

    function update_visualization(level::T) where {T <: AbstractFloat}
        level_data =
            prepare_level_set_data(grid, values, level, tolerance = params.point_tolerance)

        formatted_data = to_makie_format(level_data)

        new_points = Point3f[]
        if !isempty(formatted_data.xyz[1])
            for (x, y, z) in zip(formatted_data.xyz...)
                if !any(isnan, (x, y, z))
                    push!(new_points, Point3f(x, y, z))
                end
            end
        end
        level_points[] = new_points

        if !isnothing(df)
            visible_points = Point3f[]
            for row in eachrow(df)
                if !any(isnan, [row.x1, row.x2, row.x3, row.z]) &&
                   abs(row.z - level) ≤ params.point_tolerance
                    push!(visible_points, Point3f(row.x1, row.x2, row.x3))
                end
            end
            data_points[] = visible_points
        end
    end

    axislegend(ax, position = :rt)

    # Animation parameters
    total_frames = fps * duration
    θ = range(0, π, length = total_frames)
    levels = range(z_min, z_max, length = total_frames)

    record(fig, output_file, 1:total_frames; framerate = fps) do frame
        # Update camera position
        ax.azimuth[] = θ[frame]

        # Update level set
        update_visualization(levels[frame])
    end

    @info "Animation saved to: $output_file"
    return fig
end

# Export functions
export LevelSetData, VisualizationParameters
export prepare_level_set_data, to_makie_format, plot_level_set
export create_level_set_visualization, create_level_set_animation

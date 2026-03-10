"""
    Refinement Trajectory Visualization

Overlay local-refinement paths (Newton, trust-region, NelderMead) on an existing
Makie `Axis`.  Each trajectory is drawn from the raw polynomial critical point
(circle marker) to the refined result (triangle marker), with optional
intermediate iterates when the solver recorded a full trace.

The bang method `plot_refinement_trajectories!` mutates an existing axis so you
can compose it with any landscape / contour plot.

Requires: GlobtimPostProcessing (CriticalPointRefinementResult)
"""

using GlobtimPostProcessing: CriticalPointRefinementResult
using LinearAlgebra: norm

# ── Style configuration ──────────────────────────────────────────────────────

"""
    RefinementTrajectoryStyle

Visual style for refinement trajectory overlays.

# Fields
- `linewidth::Float64`: Path line width (default 1.5)
- `markersize_start::Float64`: Start marker (circle) size (default 6.0)
- `markersize_end::Float64`: End marker (triangle) size (default 8.0)
- `marker_start::Symbol`: Marker for raw CP (default `:circle`)
- `marker_end::Symbol`: Marker for refined CP (default `:dtriangle`)
- `stroke_color`: Marker stroke color (default `:black`)
- `stroke_width::Float64`: Marker stroke width (default 0.5)
- `line_alpha::Float64`: Line opacity (default 0.8)
- `colors::Vector{Symbol}`: Palette for trajectory coloring (cycled)
"""
Base.@kwdef struct RefinementTrajectoryStyle
    linewidth::Float64 = 1.5
    markersize_start::Float64 = 6.0
    markersize_end::Float64 = 8.0
    marker_start::Symbol = :circle
    marker_end::Symbol = :dtriangle
    stroke_color::Any = :black
    stroke_width::Float64 = 0.5
    line_alpha::Float64 = 0.8
    colors::Vector{Symbol} = [
        :orangered, :darkorange, :gold, :yellowgreen, :cyan,
        :deepskyblue, :dodgerblue, :mediumpurple, :orchid, :hotpink,
    ]
end

# ── Main plotting function ───────────────────────────────────────────────────

"""
    plot_refinement_trajectories!(ax, refine_results, raw_points; kwargs...) -> Int

Overlay refinement trajectories on an existing `Axis`.

Each trajectory visualizes how a local solver (Newton / trust-region / NelderMead)
moved a raw polynomial critical point toward the refined result.  Paths are drawn
as colored lines from circle (start) to triangle (end), with intermediate iterates
when the solver recorded a full trace.

# Arguments
- `ax::Axis`: Makie axis to draw on (mutated in place)
- `refine_results::Vector{CriticalPointRefinementResult}`: Per-CP refinement results
  (must have `.trace` field — a `Vector{Vector{Float64}}` of iterates)
- `raw_points::Vector{Vector{Float64}}`: Starting points (same length & ordering as
  `refine_results`)

# Keyword Arguments

## Selection — which trajectories to show
- `p_target::Union{Nothing, Vector{Float64}} = nothing`: Sort raw CPs by distance
  to this point and show the `n_show` closest.  Mutually exclusive with `indices`.
- `n_show::Int = 10`: Number of trajectories to show when using `p_target` sorting.
- `indices::Union{Nothing, Vector{Int}} = nothing`: Explicit 1-based indices into
  `refine_results` / `raw_points` to plot.  Overrides `p_target` / `n_show`.

## Projection — for N-D problems
- `dim_x::Int = 1`: Parameter dimension to map to the x-axis.
- `dim_y::Int = 2`: Parameter dimension to map to the y-axis.

## Clipping
- `clip_bounds::Union{Nothing, Vector{Vector{Float64}}} = nothing`: If provided,
  only draw trajectories that have at least one iterate inside this bounding box
  (format `[[lo1, hi1], [lo2, hi2], ...]`  — checked on `dim_x` and `dim_y` only).

## Visual style
- `style::RefinementTrajectoryStyle = RefinementTrajectoryStyle()`: Full style config.
- `label::Union{String, Nothing} = "refinement paths"`: Legend label for the first
  trajectory group.  Pass `nothing` to suppress legend entries.

# Returns
- `Int`: Number of trajectories actually drawn.

# Example
```julia
using CairoMakie, GlobtimPlots

fig = Figure()
ax = Axis(fig[1,1])
contourf!(ax, x_range, y_range, Z; colormap=:inferno)

n_drawn = plot_refinement_trajectories!(ax, results, raw_cps;
    p_target = p_true, n_show = 15,
    style = RefinementTrajectoryStyle(linewidth=2.0))
```
"""
function plot_refinement_trajectories!(
    ax,
    refine_results::Vector{CriticalPointRefinementResult},
    raw_points::Vector{Vector{Float64}};
    # Selection
    p_target::Union{Nothing, Vector{Float64}} = nothing,
    n_show::Int = 10,
    indices::Union{Nothing, Vector{Int}} = nothing,
    # Projection
    dim_x::Int = 1,
    dim_y::Int = 2,
    # Clipping
    clip_bounds::Union{Nothing, Vector{Vector{Float64}}} = nothing,
    # Style
    style::RefinementTrajectoryStyle = RefinementTrajectoryStyle(),
    label::Union{String, Nothing} = "refinement paths",
)::Int
    length(refine_results) == length(raw_points) ||
        error("refine_results ($(length(refine_results))) and raw_points ($(length(raw_points))) must have the same length")

    # ── Determine which trajectories to plot ─────────────────────────────────
    plot_indices = if indices !== nothing
        # Explicit selection
        for idx in indices
            1 <= idx <= length(refine_results) ||
                error("index $idx out of range [1, $(length(refine_results))]")
        end
        indices
    elseif p_target !== nothing
        # Sort by distance to target, take top n_show
        dists = [norm(rp .- p_target) for rp in raw_points]
        order = sortperm(dists)
        order[1:min(n_show, length(order))]
    else
        # No selection criteria — show first n_show
        collect(1:min(n_show, length(refine_results)))
    end

    # ── Draw trajectories ────────────────────────────────────────────────────
    n_drawn = 0
    legend_added = false
    colors = style.colors

    for (rank, idx) in enumerate(plot_indices)
        rr = refine_results[idx]
        tpts = rr.trace
        length(tpts) < 2 && continue

        tx = [Float64(p[dim_x]) for p in tpts]
        ty = [Float64(p[dim_y]) for p in tpts]

        # Clip check: skip if no iterate falls inside the clip window
        if clip_bounds !== nothing
            xb = clip_bounds[1]  # [lo, hi] for dim_x
            yb = clip_bounds[2]  # [lo, hi] for dim_y
            any_inside = any(
                xb[1] <= tx[k] <= xb[2] && yb[1] <= ty[k] <= yb[2]
                for k in eachindex(tx)
            )
            any_inside || continue
        end

        col = colors[mod1(rank, length(colors))]

        # Legend entry only on first drawn trajectory
        lbl = (!legend_added && label !== nothing) ? label : nothing

        lines!(ax, tx, ty;
            color=(col, style.line_alpha),
            linewidth=style.linewidth,
            label=lbl,
        )

        # Start marker (raw CP)
        scatter!(ax, [tx[1]], [ty[1]];
            marker=style.marker_start,
            markersize=style.markersize_start,
            color=col,
            strokecolor=style.stroke_color,
            strokewidth=style.stroke_width,
        )

        # End marker (refined CP)
        scatter!(ax, [tx[end]], [ty[end]];
            marker=style.marker_end,
            markersize=style.markersize_end,
            color=col,
            strokecolor=style.stroke_color,
            strokewidth=style.stroke_width,
        )

        legend_added = true
        n_drawn += 1
    end

    return n_drawn
end

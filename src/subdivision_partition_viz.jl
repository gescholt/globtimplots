# subdivision_partition_viz.jl
# 2D domain partition visualization for subdivision experiments
# Backend-agnostic: works with CairoMakie (static) or GLMakie (interactive)
# Note: Rect is imported at module level in GlobtimPlots.jl

using Globtim: SubdivisionTree, Subdomain, get_bounds

# ── Style configuration ──────────────────────────────────────────────────────

"""
    SubdivisionPartitionStyle

Styling configuration for subdivision domain partition visualization.
Controls colormap, degree labels, CP markers, convergence borders, colorbar, and legend.
"""
Base.@kwdef struct SubdivisionPartitionStyle
    # Colormap
    colormap::Symbol = :viridis

    # Figure
    fig_size::Tuple{Int,Int} = (700, 560)
    fontsize::Int = 13

    # Degree labels
    show_degree_labels::Bool = true
    degree_fontsize::Int = 9
    min_box_fraction::Float64 = 0.05  # skip labels on boxes smaller than this fraction

    # Critical point markers
    show_critical_points::Bool = true
    cp_markersize::Int = 8
    show_p_true::Bool = true
    p_true_markersize::Int = 18

    # Convergence borders
    show_convergence_borders::Bool = true
    converged_strokecolor::Symbol = :green3
    converged_strokewidth::Float64 = 2.0
    unconverged_strokecolor::Symbol = :gray40
    unconverged_strokewidth::Float64 = 0.5
    convergence_border_alpha::Float64 = 0.5

    # Colorbar
    show_colorbar::Bool = true
    colorbar_label::String = "log₁₀(L2 error)"
    colorbar_width::Int = 14
    colorbar_ticklabelsize::Int = 9

    # Raw (pre-refinement) critical point markers
    show_raw_cps::Bool = true
    raw_cp_markersize::Int = 6
    raw_cp_color::Symbol = :white
    raw_cp_strokewidth::Float64 = 0.8

    # Levelset contour options
    log_scale::Bool = false
    quantile_levels::Bool = false

    # Legend
    show_legend::Bool = true
    legend_labelsize::Int = 10
    legend_patchsize::Tuple{Int,Int} = (14, 14)
end

# ── Contour level preparation ────────────────────────────────────────────────

"""
    _prepare_contourf_args(Z::Matrix, n_levels::Int, style) → (Z_display, levels_kw)

Apply optional log₁₀ transform and/or quantile-based level breaks to a raw
objective grid `Z`.  Returns `(Z_display, levels_kw)` where `levels_kw` is
either `n_levels` (Int) or a `Vector{Float64}` of explicit breakpoints.
"""
function _prepare_contourf_args(Z::Matrix, n_levels::Int, style::SubdivisionPartitionStyle)
    if style.log_scale
        min_pos = minimum(z for z in Z if isfinite(z) && z > 0; init = NaN)
        if isnan(min_pos)
            @warn "_prepare_contourf_args: no positive finite values in Z — skipping log transform"
            Z_display = Z
            return Z_display, n_levels
        end
        Z_display = map(z -> (isfinite(z) && z > 0) ? log10(z) : log10(min_pos), Z)
    else
        Z_display = Z
    end

    if style.quantile_levels
        vals = filter(isfinite, vec(Z_display))
        isempty(vals) &&
            error("_prepare_contourf_args: no finite values for quantile levels")
        qs = range(0, 1; length = n_levels + 1)
        levels_kw = unique(quantile(vals, qs))
        # Need at least 2 levels for contourf
        if length(levels_kw) < 2
            levels_kw = n_levels
        end
    else
        levels_kw = n_levels
    end

    return Z_display, levels_kw
end

# ── Degree-visualization utilities ───────────────────────────────────────────

"""
    format_degree_label(d) → String

Format a degree value for display: scalar `4` → `"4"`, vector `[4,8]` → `"(4,8)"`.
"""
format_degree_label(d::Integer) = string(Int(d))
format_degree_label(d::AbstractVector) = "(" * join(Int.(d), ",") * ")"

"""
    effective_degree(d) → Int

Effective (maximum) degree: scalar as-is, vector → `maximum(d)`.
"""
effective_degree(d::Integer) = Int(d)
effective_degree(d::AbstractVector) = maximum(Int.(d))

"""
    min_degree(d) → Int

Minimum degree: scalar as-is, vector → `minimum(d)`.
"""
min_degree(d::Integer) = Int(d)
min_degree(d::AbstractVector) = minimum(Int.(d))

# CP_TYPE_TABLE, cp_type_appearance, and normalize_cp_key are defined in
# interfaces.jl (single source of truth for CP type appearance).

"""
    _in_domain(p, lo, hi) → Bool

Check whether point `p` lies within the axis-aligned box `[lo, hi]`.
"""
_in_domain(p, lo, hi) = all(lo[d] <= p[d] <= hi[d] for d in eachindex(p))

# ── Internal helpers ─────────────────────────────────────────────────────────

"""
    _log_l2_colorrange(error_vecs...) → (cmin, cmax)

Compute a shared `(cmin, cmax)` color range from one or more vectors of L2 errors.
Applies `log10` and filters `Inf`/`NaN`.
"""
function _log_l2_colorrange(error_vecs::Vector{Float64}...)
    all_valid = Float64[]
    for errs in error_vecs
        for e in errs
            v = (e == Inf || isnan(e)) ? NaN : log10(max(e, 1e-20))
            isnan(v) || push!(all_valid, v)
        end
    end
    if isempty(all_valid)
        return (-10.0, 0.0)
    end
    cmin, cmax = extrema(all_valid)
    if cmin == cmax
        cmin -= 1.0
    end
    return (cmin, cmax)
end

"""
    _domain_bbox(leaf_bounds) → (lo::Vector{Float64}, hi::Vector{Float64})

Compute the axis-aligned bounding box of the domain from leaf bounds.
`leaf_bounds` is `Vector{Vector{Vector{Float64}}}` — `[leaf][dim] → [lo, hi]`.
"""
function _domain_bbox(leaf_bounds)
    ndim = length(first(leaf_bounds))
    lo = fill(Inf, ndim)
    hi = fill(-Inf, ndim)
    for lb in leaf_bounds
        for d in 1:ndim
            lo[d] = min(lo[d], lb[d][1])
            hi[d] = max(hi[d], lb[d][2])
        end
    end
    return lo, hi
end

"""
    _draw_partition_rects!(ax, leaf_bounds, l2_errors, cmin, cmax; style, l2_tolerance)

Draw colored rectangles for leaf subdomains, colored by `log₁₀(L2 error)`.
"""
function _draw_partition_rects!(
    ax,
    leaf_bounds,
    l2_errors,
    cmin,
    cmax;
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
    l2_tolerance::Union{Nothing,Float64} = nothing,
)
    cmap = Makie.resample_cmap(style.colormap, 256)
    for (lb, err) in zip(leaf_bounds, l2_errors)
        x_lo, x_hi = lb[1]
        y_lo, y_hi = lb[2]
        w = x_hi - x_lo
        h = y_hi - y_lo

        l2v = (err == Inf || isnan(err)) ? NaN : log10(max(err, 1e-20))
        t = isnan(l2v) ? 1.0 : clamp((l2v - cmin) / (cmax - cmin), 0, 1)
        c = cmap[round(Int, t * 255)+1]

        if style.show_convergence_borders && l2_tolerance !== nothing
            converged = !isnan(err) && err != Inf && err <= l2_tolerance
            sc = converged ? style.converged_strokecolor : style.unconverged_strokecolor
            sw = converged ? style.converged_strokewidth : style.unconverged_strokewidth
        else
            sc = style.unconverged_strokecolor
            sw = style.unconverged_strokewidth
        end

        poly!(ax, Rect(x_lo, y_lo, w, h); color = c, strokecolor = sc, strokewidth = sw)
    end
end

"""
    _draw_degree_labels!(ax, leaf_bounds, leaf_degrees, l2_errors, cmin, cmax; style)

Annotate degree inside each box with luminance-aware text color.
"""
function _draw_degree_labels!(
    ax,
    leaf_bounds,
    leaf_degrees,
    l2_errors,
    cmin,
    cmax;
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
)
    d_lo, d_hi = _domain_bbox(leaf_bounds)
    x_extent = d_hi[1] - d_lo[1]
    y_extent = d_hi[2] - d_lo[2]

    cmap_arr = Makie.resample_cmap(style.colormap, 256)
    for (lb, deg, err) in zip(leaf_bounds, leaf_degrees, l2_errors)
        x_lo, x_hi = lb[1]
        y_lo, y_hi = lb[2]
        w = x_hi - x_lo
        h = y_hi - y_lo

        # Skip labels on tiny boxes
        w > style.min_box_fraction * x_extent && h > style.min_box_fraction * y_extent ||
            continue

        lbl = format_degree_label(deg)
        l2v = (err == Inf || isnan(err)) ? NaN : log10(max(err, 1e-20))
        t = isnan(l2v) ? 1.0 : clamp((l2v - cmin) / (cmax - cmin), 0, 1)
        bg = cmap_arr[round(Int, t * 255)+1]
        lum = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        tc = lum > 0.5 ? :black : :white

        text!(
            ax,
            x_lo + w / 2,
            y_lo + h / 2;
            text = lbl,
            fontsize = style.degree_fontsize,
            color = tc,
            align = (:center, :center),
        )
    end
end

"""
    _scatter_cps_by_type!(ax, cp_points, cp_types; domain_lo, domain_hi, style)

Overlay verified critical points colored by type (min/saddle/max).
Points outside the domain are excluded when `domain_lo` and `domain_hi` are provided.
"""
function _scatter_cps_by_type!(
    ax,
    cp_points::Vector,
    cp_types::Vector;
    domain_lo::Union{Nothing,Vector{Float64}} = nothing,
    domain_hi::Union{Nothing,Vector{Float64}} = nothing,
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
)
    isempty(cp_points) && return

    # Filter to points inside domain if bounds provided
    if domain_lo !== nothing && domain_hi !== nothing
        mask = [_in_domain(p, domain_lo, domain_hi) for p in cp_points]
    else
        mask = trues(length(cp_points))
    end

    for key in keys(CP_TYPE_TABLE)
        entry = CP_TYPE_TABLE[key]
        type_str = string(key)
        idxs =
            findall(i -> mask[i] && string(cp_types[i]) == type_str, eachindex(cp_points))
        isempty(idxs) && continue
        xs = [cp_points[i][1] for i in idxs]
        ys = [cp_points[i][2] for i in idxs]
        scatter!(
            ax,
            xs,
            ys;
            marker = entry.marker,
            markersize = style.cp_markersize,
            color = entry.color,
            strokecolor = :white,
            strokewidth = 1.5,
        )
    end
end

"""
    _scatter_raw_cps!(ax, raw_cp_points; domain_lo, domain_hi, style)

Overlay raw (pre-refinement) critical points as thin white crosses.
Drawn before refined CPs so refined markers render on top.
"""
function _scatter_raw_cps!(
    ax,
    raw_cp_points::Vector;
    domain_lo::Union{Nothing,Vector{Float64}} = nothing,
    domain_hi::Union{Nothing,Vector{Float64}} = nothing,
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
)
    isempty(raw_cp_points) && return

    # Filter to points inside domain if bounds provided
    if domain_lo !== nothing && domain_hi !== nothing
        mask = [_in_domain(p, domain_lo, domain_hi) for p in raw_cp_points]
    else
        mask = trues(length(raw_cp_points))
    end

    idxs = findall(mask)
    isempty(idxs) && return

    xs = [raw_cp_points[i][1] for i in idxs]
    ys = [raw_cp_points[i][2] for i in idxs]
    scatter!(
        ax,
        xs,
        ys;
        marker = :cross,
        markersize = style.raw_cp_markersize,
        color = style.raw_cp_color,
        strokecolor = style.raw_cp_color,
        strokewidth = style.raw_cp_strokewidth,
    )
end

"""
    _scatter_p_true!(ax, p_true; style)

Plot the true parameter as a gold star.
"""
function _scatter_p_true!(
    ax,
    p_true;
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
)
    if !isempty(p_true)
        scatter!(
            ax,
            [p_true[1]],
            [p_true[2]];
            marker = :star5,
            markersize = style.p_true_markersize,
            color = :gold,
            strokecolor = :black,
            strokewidth = 1.5,
        )
        vlines!(ax, [p_true[1]]; color = (:gold, 0.3), linewidth = 1, linestyle = :dash)
        hlines!(ax, [p_true[2]]; color = (:gold, 0.3), linewidth = 1, linestyle = :dash)
    end
end

"""
    _build_legend_entries(style) → (entries, labels)

Build standard legend entries for CP types, convergence borders, and p*.
"""
function _build_legend_entries(style::SubdivisionPartitionStyle; show_raw_cps::Bool = false)
    entries = Makie.LegendElement[]
    labels = String[]

    # CP type entries from canonical table
    for key in keys(CP_TYPE_TABLE)
        entry = CP_TYPE_TABLE[key]
        push!(
            entries,
            MarkerElement(
                marker = entry.marker,
                color = entry.color,
                strokecolor = :white,
                strokewidth = 1.5,
                markersize = style.cp_markersize,
            ),
        )
        push!(labels, entry.label)
    end

    # Fixed entries: p_true, convergence borders
    push!(
        entries,
        MarkerElement(
            marker = :star5,
            color = :gold,
            strokecolor = :black,
            strokewidth = 1.5,
            markersize = 12,
        ),
    )
    push!(labels, "p* (true)")
    push!(
        entries,
        LineElement(
            color = (style.converged_strokecolor, style.convergence_border_alpha),
            linewidth = style.converged_strokewidth,
        ),
    )
    push!(labels, "Converged")
    push!(
        entries,
        LineElement(
            color = (style.unconverged_strokecolor, style.convergence_border_alpha),
            linewidth = style.unconverged_strokewidth,
        ),
    )
    push!(labels, "Unconverged")

    if show_raw_cps
        push!(
            entries,
            MarkerElement(
                marker = :cross,
                color = style.raw_cp_color,
                strokecolor = style.raw_cp_color,
                strokewidth = style.raw_cp_strokewidth,
                markersize = style.raw_cp_markersize,
            ),
        )
        push!(labels, "Raw CP")
    end

    return entries, labels
end

# ── Main function ────────────────────────────────────────────────────────────

"""
    plot_subdivision_partition(leaf_bounds, leaf_l2_errors, leaf_degrees; kwargs...) → Figure

Create a domain partition visualization for a subdivision experiment result.

# Arguments
- `leaf_bounds::Vector`: Per-leaf bounds, `[leaf][dim] → [lo, hi]`
- `leaf_l2_errors::Vector{Float64}`: L2 error per leaf
- `leaf_degrees::Vector`: Degree per leaf (Int or Vector{Int} for anisotropic)

# Keyword Arguments
- `cp_points::Vector = []`: Refined critical points (`Vector{Float64}[]`)
- `cp_types::Vector = []`: CP type strings ("min"/"saddle"/"max")
- `raw_cp_points::Vector = []`: Raw (pre-refinement) critical points (`Vector{Float64}[]`)
- `p_true = nothing`: True parameter vector
- `l2_tolerance = nothing`: L2 tolerance for convergence border coloring
- `colorrange = nothing`: Explicit `(cmin, cmax)` for color scale; auto-computed if nothing
- `title::String = "Domain Partition"`: Plot title
- `subtitle::String = ""`: Plot subtitle
- `style::SubdivisionPartitionStyle = SubdivisionPartitionStyle()`: Styling config
- `fig = nothing`: Plot into existing Figure
- `ax = nothing`: Plot into existing Axis

# Returns
- `Figure`: The Makie figure (backend-agnostic — display with GLMakie for interactive, save with CairoMakie)

# Example
```julia
using GlobtimPlots
fig = plot_subdivision_partition(
    leaf_bounds, leaf_l2_errors, leaf_degrees;
    cp_points=cps, cp_types=types, p_true=[1.0, 1.5],
    l2_tolerance=1e-4, title="LV2D subdivision"
)
save("partition.png", fig; px_per_unit=2)
```
"""
function plot_subdivision_partition(
    leaf_bounds::Vector,
    leaf_l2_errors::Vector{Float64},
    leaf_degrees::Vector;
    cp_points::Vector = Vector{Float64}[],
    cp_types::Vector = String[],
    raw_cp_points::Vector = Vector{Float64}[],
    p_true = nothing,
    l2_tolerance::Union{Nothing,Float64} = nothing,
    colorrange::Union{Nothing,Tuple{Float64,Float64}} = nothing,
    title::String = "Domain Partition",
    subtitle::String = "",
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
    fig = nothing,
    ax = nothing,
)
    isempty(leaf_bounds) && error("No leaf bounds provided")

    # Compute color range
    cmin, cmax = if colorrange !== nothing
        colorrange
    else
        _log_l2_colorrange(leaf_l2_errors)
    end

    # Create figure if not provided
    own_fig = isnothing(fig)
    if own_fig
        fig = Figure(size = style.fig_size, fontsize = style.fontsize)
    end

    # Create axis if not provided
    if isnothing(ax)
        ax = Axis(
            fig[1, 1];
            xlabel = "p₁",
            ylabel = "p₂",
            title = title,
            subtitle = subtitle,
            aspect = DataAspect(),
        )
    end

    # Draw colored partition rectangles
    _draw_partition_rects!(
        ax,
        leaf_bounds,
        leaf_l2_errors,
        cmin,
        cmax;
        style = style,
        l2_tolerance = l2_tolerance,
    )

    # Degree labels
    if style.show_degree_labels && !isempty(leaf_degrees)
        _draw_degree_labels!(
            ax,
            leaf_bounds,
            leaf_degrees,
            leaf_l2_errors,
            cmin,
            cmax;
            style = style,
        )
    end

    # Raw (pre-refinement) critical points — drawn first so refined CPs render on top
    d_lo, d_hi = _domain_bbox(leaf_bounds)
    if style.show_raw_cps && !isempty(raw_cp_points)
        _scatter_raw_cps!(
            ax,
            raw_cp_points;
            domain_lo = d_lo,
            domain_hi = d_hi,
            style = style,
        )
    end

    # Refined critical points
    if style.show_critical_points && !isempty(cp_points)
        _scatter_cps_by_type!(
            ax,
            cp_points,
            cp_types;
            domain_lo = d_lo,
            domain_hi = d_hi,
            style = style,
        )
    end

    # True parameter
    if style.show_p_true && p_true !== nothing
        _scatter_p_true!(ax, p_true; style = style)
    end

    # Colorbar (only add if we own the figure layout)
    if style.show_colorbar && own_fig
        Colorbar(
            fig[1, 2];
            colorrange = (cmin, cmax),
            colormap = style.colormap,
            label = style.colorbar_label,
            width = style.colorbar_width,
            ticklabelsize = style.colorbar_ticklabelsize,
        )
    end

    # Legend (only add if we own the figure layout)
    if style.show_legend && own_fig
        entries, labels = _build_legend_entries(
            style;
            show_raw_cps = style.show_raw_cps && !isempty(raw_cp_points),
        )
        Legend(
            fig[2, 1:2],
            entries,
            labels;
            orientation = :horizontal,
            framevisible = false,
            labelsize = style.legend_labelsize,
            patchsize = style.legend_patchsize,
            colgap = 12,
        )
    end

    return fig
end

# ── Convergence-colored boundary drawing ────────────────────────────────────

"""
    _draw_convergence_boundaries!(ax, leaf_bounds, leaf_l2_errors; l2_tolerance, style)

Draw per-leaf boundary line segments colored by convergence status.
Green for converged leaves (`l2_error ≤ l2_tolerance`), gray for unconverged.

Uses two batched `linesegments!` calls (one per status) for efficiency.
"""
function _draw_convergence_boundaries!(
    ax,
    leaf_bounds,
    leaf_l2_errors;
    l2_tolerance::Union{Nothing,Float64} = nothing,
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
)
    conv_xs = Float64[]
    conv_ys = Float64[]
    unconv_xs = Float64[]
    unconv_ys = Float64[]

    for (lb, err) in zip(leaf_bounds, leaf_l2_errors)
        x_lo, x_hi = lb[1]
        y_lo, y_hi = lb[2]

        converged =
            l2_tolerance !== nothing && !isnan(err) && err != Inf && err <= l2_tolerance
        xs = converged ? conv_xs : unconv_xs
        ys = converged ? conv_ys : unconv_ys

        # Bottom
        push!(xs, x_lo, x_hi)
        push!(ys, y_lo, y_lo)
        # Right
        push!(xs, x_hi, x_hi)
        push!(ys, y_lo, y_hi)
        # Top
        push!(xs, x_hi, x_lo)
        push!(ys, y_hi, y_hi)
        # Left
        push!(xs, x_lo, x_lo)
        push!(ys, y_hi, y_lo)
    end

    if !isempty(conv_xs)
        linesegments!(
            ax,
            conv_xs,
            conv_ys;
            color = (style.converged_strokecolor, style.convergence_border_alpha),
            linewidth = style.converged_strokewidth,
        )
    end
    if !isempty(unconv_xs)
        linesegments!(
            ax,
            unconv_xs,
            unconv_ys;
            color = (style.unconverged_strokecolor, style.convergence_border_alpha),
            linewidth = style.unconverged_strokewidth,
        )
    end
end

"""
    _draw_convergence_boundaries!(ax, tree::SubdivisionTree; l2_tolerance, style)

Tree-based dispatch: extracts leaf bounds and L2 errors from the tree, then
delegates to the data-based method.
"""
function _draw_convergence_boundaries!(
    ax,
    tree::SubdivisionTree;
    l2_tolerance::Union{Nothing,Float64} = nothing,
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
)
    all_leaf_ids = vcat(tree.active_leaves, tree.converged_leaves)
    leaf_bounds = [get_bounds(tree.subdomains[id]) for id in all_leaf_ids]
    leaf_l2_errors = [tree.subdomains[id].l2_error for id in all_leaf_ids]
    _draw_convergence_boundaries!(
        ax,
        leaf_bounds,
        leaf_l2_errors;
        l2_tolerance = l2_tolerance,
        style = style,
    )
end

# ── Level set base rendering (shared by static and interactive) ───────────────

"""
    _build_levelset_base!(ax, tree, f; resolution, n_levels, colormap,
                          l2_tolerance, cp_points, cp_types, p_true, style) → contourf_plot

Draw the shared levelset base onto `ax`: filled contour of `f`, subdivision
convergence boundaries, refined CPs, and `p*`. Returns the `contourf!` plot
object for colorbar binding.

Does NOT draw raw CPs — callers handle raw CPs differently (static: `_scatter_raw_cps!`;
interactive: named scatter for `pick()`).
"""
function _build_levelset_base!(
    ax,
    tree::SubdivisionTree,
    f;
    resolution::Int = 200,
    n_levels::Int = 30,
    colormap::Symbol = :viridis,
    l2_tolerance::Union{Nothing,Float64} = nothing,
    cp_points::Vector = Vector{Float64}[],
    cp_types::Vector = String[],
    p_true = nothing,
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
)
    root_bounds = get_bounds(tree.subdomains[tree.root_id])
    x_lo, x_hi = root_bounds[1]
    y_lo, y_hi = root_bounds[2]

    xs = range(x_lo, x_hi; length = resolution)
    ys = range(y_lo, y_hi; length = resolution)
    f_values = [f([x, y]) for x in xs, y in ys]

    # Apply optional log/quantile transform
    Z_display, levels_kw = _prepare_contourf_args(f_values, n_levels, style)
    cb_label = style.log_scale ? "log₁₀ f(p)" : "f(p)"

    # Level-set contour fill
    cf = contourf!(
        ax,
        collect(xs),
        collect(ys),
        Z_display;
        levels = levels_kw,
        colormap = colormap,
    )

    # Subdivision boundaries with convergence coloring
    _draw_convergence_boundaries!(ax, tree; l2_tolerance = l2_tolerance, style = style)

    # Domain bounds for CP filtering
    d_lo = Float64[x_lo, y_lo]
    d_hi = Float64[x_hi, y_hi]

    # Refined CPs
    if style.show_critical_points && !isempty(cp_points)
        _scatter_cps_by_type!(
            ax,
            cp_points,
            cp_types;
            domain_lo = d_lo,
            domain_hi = d_hi,
            style = style,
        )
    end

    # True parameter
    if style.show_p_true && p_true !== nothing
        _scatter_p_true!(ax, p_true; style = style)
    end

    return cf, cb_label
end

# ── Level set + subdivision overlay ─────────────────────────────────────────

"""
    plot_subdivision_on_levelset(tree::SubdivisionTree, f; kwargs...) → Figure

Plot the objective function `f` as a filled contour (level set) with subdivision
boundaries overlaid, colored by convergence status. Critical points and `p*`
are scattered on top.

Requires the `SubdivisionTree` and objective function to be in memory (runtime only).

# Arguments
- `tree`: The subdivision tree (provides domain bounds and per-leaf L2 errors)
- `f`: The objective function `f(x::Vector{Float64}) → Float64`

# Keyword Arguments
- `resolution::Int = 200`: Grid points per axis for contour evaluation
- `n_levels::Int = 30`: Number of contour levels
- `colormap::Symbol = :viridis`: Colormap for the filled contour
- `l2_tolerance`: L2 tolerance for convergence border coloring
- `cp_points, cp_types`: Refined critical points and their types
- `raw_cp_points`: Raw (pre-refinement) critical points
- `p_true`: True parameter vector
- `title`: Plot title
- `style`: `SubdivisionPartitionStyle` for marker/border styling
- `fig, ax`: Plot into existing Figure/Axis
"""
function plot_subdivision_on_levelset(
    tree::SubdivisionTree,
    f;
    resolution::Int = 200,
    n_levels::Int = 30,
    colormap::Symbol = :viridis,
    l2_tolerance::Union{Nothing,Float64} = nothing,
    cp_points::Vector = Vector{Float64}[],
    cp_types::Vector = String[],
    raw_cp_points::Vector = Vector{Float64}[],
    p_true = nothing,
    title::String = "Objective with Subdivision Overlay",
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
    fig = nothing,
    ax = nothing,
)
    # Create figure if not provided
    own_fig = isnothing(fig)
    if own_fig
        fig = Figure(size = style.fig_size, fontsize = style.fontsize)
    end

    if isnothing(ax)
        ax = Axis(
            fig[1, 1];
            xlabel = "p₁",
            ylabel = "p₂",
            title = title,
            aspect = DataAspect(),
        )
    end

    # Draw shared levelset base (contour, boundaries, refined CPs, p_true)
    cf, cb_label = _build_levelset_base!(
        ax,
        tree,
        f;
        resolution = resolution,
        n_levels = n_levels,
        colormap = colormap,
        l2_tolerance = l2_tolerance,
        cp_points = cp_points,
        cp_types = cp_types,
        p_true = p_true,
        style = style,
    )

    # Raw CPs (drawn on top of base, before legend/colorbar)
    root_bounds = get_bounds(tree.subdomains[tree.root_id])
    d_lo = Float64[root_bounds[1][1], root_bounds[2][1]]
    d_hi = Float64[root_bounds[1][2], root_bounds[2][2]]
    if style.show_raw_cps && !isempty(raw_cp_points)
        _scatter_raw_cps!(
            ax,
            raw_cp_points;
            domain_lo = d_lo,
            domain_hi = d_hi,
            style = style,
        )
    end

    # Colorbar for contour fill
    if style.show_colorbar && own_fig
        Colorbar(
            fig[1, 2],
            cf;
            label = cb_label,
            width = style.colorbar_width,
            ticklabelsize = style.colorbar_ticklabelsize,
        )
    end

    # Legend
    if style.show_legend && own_fig
        entries, labels = _build_legend_entries(
            style;
            show_raw_cps = style.show_raw_cps && !isempty(raw_cp_points),
        )
        Legend(
            fig[2, 1:2],
            entries,
            labels;
            orientation = :horizontal,
            framevisible = false,
            labelsize = style.legend_labelsize,
            patchsize = style.legend_patchsize,
            colgap = 12,
        )
    end

    return fig
end

"""
    plot_subdivision_on_levelset(f, bounds; leaf_bounds, leaf_l2_errors, kwargs...) → Figure

Data-based version for when the tree is not available but leaf geometry and
L2 errors have been extracted (e.g. from JSON results).

# Arguments
- `f`: The objective function `f(x::Vector{Float64}) → Float64`
- `bounds`: Domain bounds `[[x_lo, x_hi], [y_lo, y_hi]]` or `[(x_lo, x_hi), (y_lo, y_hi)]`
- `leaf_bounds`: Per-leaf bounds `[leaf][dim] → [lo, hi]` or tuples
- `leaf_l2_errors::Vector{Float64}`: L2 error per leaf

All other keyword arguments are the same as the tree-based version.
"""
function plot_subdivision_on_levelset(
    f,
    bounds::Vector;
    leaf_bounds::Vector,
    leaf_l2_errors::Vector{Float64},
    resolution::Int = 200,
    n_levels::Int = 30,
    colormap::Symbol = :viridis,
    l2_tolerance::Union{Nothing,Float64} = nothing,
    cp_points::Vector = Vector{Float64}[],
    cp_types::Vector = String[],
    raw_cp_points::Vector = Vector{Float64}[],
    p_true = nothing,
    title::String = "Objective with Subdivision Overlay",
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
    fig = nothing,
    ax = nothing,
)
    x_lo, x_hi = bounds[1]
    y_lo, y_hi = bounds[2]

    # Evaluate f on a uniform grid
    xs = range(x_lo, x_hi; length = resolution)
    ys = range(y_lo, y_hi; length = resolution)
    f_values = [f([x, y]) for x in xs, y in ys]

    # Create figure if not provided
    own_fig = isnothing(fig)
    if own_fig
        fig = Figure(size = style.fig_size, fontsize = style.fontsize)
    end

    if isnothing(ax)
        ax = Axis(
            fig[1, 1];
            xlabel = "p₁",
            ylabel = "p₂",
            title = title,
            aspect = DataAspect(),
        )
    end

    # Apply optional log/quantile transform
    Z_display, levels_kw = _prepare_contourf_args(f_values, n_levels, style)
    cb_label = style.log_scale ? "log₁₀ f(p)" : "f(p)"

    # Level-set contour fill
    cf = contourf!(
        ax,
        collect(xs),
        collect(ys),
        Z_display;
        levels = levels_kw,
        colormap = colormap,
    )

    # Subdivision boundaries with convergence coloring
    _draw_convergence_boundaries!(
        ax,
        leaf_bounds,
        leaf_l2_errors;
        l2_tolerance = l2_tolerance,
        style = style,
    )

    # Domain bounds for CP filtering
    d_lo = Float64[x_lo, y_lo]
    d_hi = Float64[x_hi, y_hi]

    # Raw CPs (drawn first so refined CPs render on top)
    if style.show_raw_cps && !isempty(raw_cp_points)
        _scatter_raw_cps!(
            ax,
            raw_cp_points;
            domain_lo = d_lo,
            domain_hi = d_hi,
            style = style,
        )
    end

    # Refined CPs
    if style.show_critical_points && !isempty(cp_points)
        _scatter_cps_by_type!(
            ax,
            cp_points,
            cp_types;
            domain_lo = d_lo,
            domain_hi = d_hi,
            style = style,
        )
    end

    # True parameter
    if style.show_p_true && p_true !== nothing
        _scatter_p_true!(ax, p_true; style = style)
    end

    # Colorbar for contour fill
    if style.show_colorbar && own_fig
        Colorbar(
            fig[1, 2],
            cf;
            label = cb_label,
            width = style.colorbar_width,
            ticklabelsize = style.colorbar_ticklabelsize,
        )
    end

    # Legend
    if style.show_legend && own_fig
        entries, labels = _build_legend_entries(
            style;
            show_raw_cps = style.show_raw_cps && !isempty(raw_cp_points),
        )
        Legend(
            fig[2, 1:2],
            entries,
            labels;
            orientation = :horizontal,
            framevisible = false,
            labelsize = style.legend_labelsize,
            patchsize = style.legend_patchsize,
            colgap = 12,
        )
    end

    return fig
end

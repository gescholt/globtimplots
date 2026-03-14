# subdivision_error_heatmap.jl
# 2D filled heatmap of |f(p) - poly(p)| across the subdivision domain.
# Requires the SubdivisionTree to still be in memory (polynomials are not serialized to JSON).

using Globtim: SubdivisionTree, Subdomain, get_bounds, evaluate, ApproxPoly

"""
    find_containing_leaf(tree::SubdivisionTree, point::AbstractVector{Float64}) → Subdomain

Find the leaf subdomain containing `point`. Errors if no leaf contains the point.
"""
function find_containing_leaf(tree::SubdivisionTree, point::AbstractVector{Float64})
    all_leaf_ids = vcat(tree.active_leaves, tree.converged_leaves)
    for id in all_leaf_ids
        sd = tree.subdomains[id]
        bounds = get_bounds(sd)
        if all(bounds[d][1] <= point[d] <= bounds[d][2] for d in eachindex(point))
            return sd
        end
    end
    error("Point $point not found in any leaf subdomain")
end

"""
    compute_error_grid(tree::SubdivisionTree, f;
                       resolution::Int = 200, log_scale::Bool = true)
        → (xs, ys, error_matrix)

Evaluate `|f(p) - poly(p)|` on a uniform grid over the tree's domain.
Returns x-coordinates, y-coordinates, and the error matrix.

If `log_scale`, applies `log10` to the error values (clamped to a minimum of 1e-20).
"""
function compute_error_grid(tree::SubdivisionTree, f;
                            resolution::Int = 200, log_scale::Bool = true)
    # Get full domain bounds from root
    root_bounds = get_bounds(tree.subdomains[tree.root_id])
    x_lo, x_hi = root_bounds[1]
    y_lo, y_hi = root_bounds[2]

    xs = range(x_lo, x_hi; length=resolution)
    ys = range(y_lo, y_hi; length=resolution)

    # Pre-collect leaf info for fast lookup
    all_leaf_ids = vcat(tree.active_leaves, tree.converged_leaves)
    leaf_bounds = [get_bounds(tree.subdomains[id]) for id in all_leaf_ids]
    leaf_polys = [tree.subdomains[id].polynomial for id in all_leaf_ids]

    error_matrix = Matrix{Float64}(undef, resolution, resolution)

    for (j, y) in enumerate(ys)
        for (i, x) in enumerate(xs)
            point = [x, y]
            # Find containing leaf by bounds check
            leaf_idx = findfirst(eachindex(all_leaf_ids)) do k
                lb = leaf_bounds[k]
                all(lb[d][1] <= point[d] <= lb[d][2] for d in eachindex(point))
            end

            if leaf_idx === nothing || leaf_polys[leaf_idx] === nothing
                error_matrix[i, j] = NaN
            else
                poly = leaf_polys[leaf_idx]
                err = abs(f(point) - evaluate(poly, point))
                error_matrix[i, j] = log_scale ? log10(max(err, 1e-20)) : err
            end
        end
    end

    return collect(xs), collect(ys), error_matrix
end

"""
    plot_subdivision_error_heatmap(
        tree::SubdivisionTree, f;
        resolution::Int = 200,
        log_scale::Bool = true,
        colormap::Symbol = :viridis,
        show_boundaries::Bool = true,
        boundary_color = :white,
        boundary_width::Float64 = 1.0,
        title::String = "Polynomial Approximation Error",
        cp_points::Vector = Vector{Float64}[],
        cp_types::Vector = String[],
        raw_cp_points::Vector = Vector{Float64}[],
        p_true = nothing,
        style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
        fig = nothing,
        ax = nothing,
    ) → Figure

Create a 2D filled heatmap of `|f(p) - poly(p)|` across the subdivision domain,
with subdomain boundaries overlaid.

Requires the `SubdivisionTree` with populated polynomials (runtime only — polynomials
are not serialized to JSON).

# Arguments
- `tree`: The subdivision tree with polynomial approximations per leaf
- `f`: The objective function `f(x::Vector{Float64}) → Float64`

# Keyword Arguments
- `resolution`: Grid points per axis (default 200)
- `log_scale`: If true, plot log₁₀(error) (default true)
- `colormap`: Makie colormap (default `:viridis`)
- `show_boundaries`: Overlay subdomain boundaries (default true)
- `boundary_color`: Color for boundary lines (default `:white`)
- `boundary_width`: Line width for boundaries (default 1.0)
- `title`: Plot title
- `cp_points, cp_types`: Refined critical points and their types
- `raw_cp_points`: Raw (pre-refinement) critical points
- `p_true`: True parameter vector
- `style`: SubdivisionPartitionStyle for CP marker styling
- `fig, ax`: Plot into existing Figure/Axis
"""
function plot_subdivision_error_heatmap(
    tree::SubdivisionTree, f;
    resolution::Int = 200,
    log_scale::Bool = true,
    colormap::Symbol = :viridis,
    show_boundaries::Bool = true,
    boundary_color = :white,
    boundary_width::Float64 = 1.0,
    title::String = "Polynomial Approximation Error",
    cp_points::Vector = Vector{Float64}[],
    cp_types::Vector = String[],
    raw_cp_points::Vector = Vector{Float64}[],
    p_true = nothing,
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
    fig = nothing,
    ax = nothing,
)
    # Compute error grid
    xs, ys, error_matrix = compute_error_grid(tree, f; resolution, log_scale)

    # Create figure if not provided
    own_fig = isnothing(fig)
    if own_fig
        fig = Figure(size=style.fig_size, fontsize=style.fontsize)
    end

    # Create axis if not provided
    if isnothing(ax)
        ax = Axis(fig[1, 1];
            xlabel="p₁", ylabel="p₂",
            title=title,
            aspect=DataAspect(),
        )
    end

    # Heatmap
    hm = heatmap!(ax, xs, ys, error_matrix; colormap)

    # Subdomain boundaries
    if show_boundaries
        _draw_boundary_segments!(ax, tree; color=boundary_color, linewidth=boundary_width)
    end

    # Raw CPs (white crosses, drawn before refined)
    if style.show_raw_cps && !isempty(raw_cp_points)
        _scatter_raw_cps!(ax, raw_cp_points; style=style)
    end

    # Refined CPs
    if style.show_critical_points && !isempty(cp_points)
        _scatter_cps_by_type!(ax, cp_points, cp_types; style=style)
    end

    # True parameter
    if style.show_p_true && p_true !== nothing
        _scatter_p_true!(ax, p_true; style=style)
    end

    # Colorbar
    if style.show_colorbar && own_fig
        cb_label = log_scale ? "log₁₀(|f - poly|)" : "|f - poly|"
        Colorbar(fig[1, 2], hm; label=cb_label,
                 width=style.colorbar_width, ticklabelsize=style.colorbar_ticklabelsize)
    end

    return fig
end

"""
    _draw_boundary_segments!(ax, tree; color, linewidth)

Draw subdomain boundary line segments for all leaves in the tree.
"""
function _draw_boundary_segments!(ax, tree::SubdivisionTree;
                                  color = :white, linewidth::Float64 = 1.0)
    all_leaf_ids = vcat(tree.active_leaves, tree.converged_leaves)
    # Collect all edge segments as pairs of points for a single linesegments! call
    seg_xs = Float64[]
    seg_ys = Float64[]
    for id in all_leaf_ids
        bounds = get_bounds(tree.subdomains[id])
        x_lo, x_hi = bounds[1]
        y_lo, y_hi = bounds[2]
        # 4 edges per rectangle, each as a pair of points
        # Bottom: (x_lo,y_lo)→(x_hi,y_lo)
        push!(seg_xs, x_lo, x_hi); push!(seg_ys, y_lo, y_lo)
        # Right:  (x_hi,y_lo)→(x_hi,y_hi)
        push!(seg_xs, x_hi, x_hi); push!(seg_ys, y_lo, y_hi)
        # Top:    (x_hi,y_hi)→(x_lo,y_hi)
        push!(seg_xs, x_hi, x_lo); push!(seg_ys, y_hi, y_hi)
        # Left:   (x_lo,y_hi)→(x_lo,y_lo)
        push!(seg_xs, x_lo, x_lo); push!(seg_ys, y_hi, y_lo)
    end
    if !isempty(seg_xs)
        linesegments!(ax, seg_xs, seg_ys; color=color, linewidth=linewidth)
    end
end

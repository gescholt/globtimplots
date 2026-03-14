# interactive_error_explorer.jl
# Interactive GLMakie explorer for subdivision polynomial approximation error.
# Zoom into a region, press "Refine View" to re-render at higher resolution.
# Adapted from Opt_Traj/examples/getting_started/landscape_explorer.jl refine!() pattern.
#
# Requires GLMakie (not loaded by default in GlobtimPlots — load it separately).

using Globtim: SubdivisionTree, Subdomain, get_bounds, evaluate, ApproxPoly
using Printf

# ── Core computation ─────────────────────────────────────────────────────────

"""
    _compute_error_grid_in_window(tree, f, xs, ys) → Matrix{Float64}

Evaluate `|f(p) - poly(p)|` on the grid defined by `xs × ys`.
Returns raw (unscaled) error values; `NaN` for points outside any leaf or
leaves without a polynomial.
"""
function _compute_error_grid_in_window(tree::SubdivisionTree, f,
                                       xs::AbstractVector, ys::AbstractVector)
    nx, ny = length(xs), length(ys)

    # Pre-collect leaf info for fast lookup
    all_leaf_ids = vcat(tree.active_leaves, tree.converged_leaves)
    leaf_bounds = [get_bounds(tree.subdomains[id]) for id in all_leaf_ids]
    leaf_polys  = [tree.subdomains[id].polynomial for id in all_leaf_ids]

    E = Matrix{Float64}(undef, nx, ny)

    Threads.@threads for i in 1:nx
        for j in 1:ny
            point = [xs[i], ys[j]]
            # Find containing leaf
            leaf_idx = findfirst(eachindex(all_leaf_ids)) do k
                lb = leaf_bounds[k]
                all(lb[d][1] <= point[d] <= lb[d][2] for d in eachindex(point))
            end

            if leaf_idx === nothing || leaf_polys[leaf_idx] === nothing
                E[i, j] = NaN
            else
                E[i, j] = abs(f(point) - evaluate(leaf_polys[leaf_idx], point))
            end
        end
    end

    return E
end

# ── Display transform ────────────────────────────────────────────────────────

function _apply_error_display_transform!(obs_state)
    cache = obs_state.raw_error_ref[]
    cache === nothing && return

    E, xs, ys = cache.E, cache.xs, cache.ys
    use_log = obs_state.log_scale_obs[]

    E_display = map(E) do e
        isfinite(e) || return NaN
        use_log ? log10(max(e, 1e-20)) : e
    end

    obs_state.xs_obs[]         = xs
    obs_state.ys_obs[]         = ys
    obs_state.error_grid_obs[] = E_display
end

# ── Regenerate (full domain) ─────────────────────────────────────────────────

function _regenerate_error!(obs_state;
                            resolution::Int = obs_state.resolution)
    tree = obs_state.tree
    f    = obs_state.f

    root_bounds = get_bounds(tree.subdomains[tree.root_id])
    x_lo, x_hi = root_bounds[1]
    y_lo, y_hi = root_bounds[2]

    xs = collect(range(x_lo, x_hi; length=resolution))
    ys = collect(range(y_lo, y_hi; length=resolution))
    E  = _compute_error_grid_in_window(tree, f, xs, ys)

    obs_state.raw_error_ref[] = (; E, xs, ys)
    _apply_error_display_transform!(obs_state)

    @printf("  Reset: %d×%d grid  domain=[%.3g,%.3g]×[%.3g,%.3g]\n",
            resolution, resolution, x_lo, x_hi, y_lo, y_hi)
end

# ── Refine (zoom window) ─────────────────────────────────────────────────────

"""
    _refine_error!(obs_state, ax; resolution)

Re-sample the error grid at full `resolution` within the current zoom window of `ax`.
"""
function _refine_error!(obs_state, ax;
                        resolution::Int = obs_state.resolution)
    tree = obs_state.tree
    f    = obs_state.f

    # Read zoom window from axis limits
    rect = ax.finallimits[]
    x_min = Float64(rect.origin[1])
    y_min = Float64(rect.origin[2])
    x_max = Float64(x_min + rect.widths[1])
    y_max = Float64(y_min + rect.widths[2])

    # Clamp to domain bounds
    root_bounds = get_bounds(tree.subdomains[tree.root_id])
    x_min = clamp(x_min, root_bounds[1]...)
    x_max = clamp(x_max, root_bounds[1]...)
    y_min = clamp(y_min, root_bounds[2]...)
    y_max = clamp(y_max, root_bounds[2]...)

    if x_max - x_min < 1e-10 || y_max - y_min < 1e-10
        @warn "refine!: visible window is too small to refine (zoom out first)"
        return nothing
    end

    xs = collect(range(x_min, x_max; length=resolution))
    ys = collect(range(y_min, y_max; length=resolution))
    E  = _compute_error_grid_in_window(tree, f, xs, ys)

    obs_state.raw_error_ref[] = (; E, xs, ys)
    _apply_error_display_transform!(obs_state)

    # Print zoom stats
    dx_full = root_bounds[1][2] - root_bounds[1][1]
    dy_full = root_bounds[2][2] - root_bounds[2][1]
    zoom_x = round(dx_full / (x_max - x_min); digits=1)
    zoom_y = round(dy_full / (y_max - y_min); digits=1)

    @printf("  Refined: %d×%d grid  x=[%.3g,%.3g]  y=[%.3g,%.3g]  zoom≈%.1f×%.1f\n",
            resolution, resolution, x_min, x_max, y_min, y_max, zoom_x, zoom_y)
end

# ── Boundary line segments ───────────────────────────────────────────────────

function _collect_boundary_segments(tree::SubdivisionTree)
    all_leaf_ids = vcat(tree.active_leaves, tree.converged_leaves)
    pts = Point2f[]
    for id in all_leaf_ids
        bounds = get_bounds(tree.subdomains[id])
        x_lo, x_hi = Float32.(bounds[1])
        y_lo, y_hi = Float32.(bounds[2])
        # 4 edges per rect: bottom, right, top, left
        push!(pts, Point2f(x_lo, y_lo), Point2f(x_hi, y_lo))
        push!(pts, Point2f(x_hi, y_lo), Point2f(x_hi, y_hi))
        push!(pts, Point2f(x_hi, y_hi), Point2f(x_lo, y_hi))
        push!(pts, Point2f(x_lo, y_hi), Point2f(x_lo, y_lo))
    end
    return pts
end

# ── Public API ───────────────────────────────────────────────────────────────

"""
    interactive_error_explorer(
        tree::SubdivisionTree, f;
        resolution::Int = 200,
        log_scale::Bool = true,
        colormap::Symbol = :viridis,
    ) → Figure

Launch an interactive GLMakie window showing `|f(p) - poly(p)|` across the
subdivision domain. Requires GLMakie to be loaded and active.

## Interaction
- **Zoom** into a region with the mouse scroll / drag
- **"Refine View"** re-renders at full `resolution` within the current zoom window
- **"Reset"** restores the full domain view
- **"Toggle log/linear"** switches between log₁₀ and raw error display (instant, no recompute)

## Arguments
- `tree`: SubdivisionTree with populated polynomials (runtime only)
- `f`: Objective function `f(x::Vector{Float64}) → Float64`

## Keyword Arguments
- `resolution`: Grid points per axis (default 200)
- `log_scale`: Start with log₁₀ scale (default true)
- `colormap`: Makie colormap (default `:viridis`)
"""
function interactive_error_explorer(
    tree::SubdivisionTree, f;
    resolution::Int = 200,
    log_scale::Bool = true,
    colormap::Symbol = :viridis,
)
    # Verify we have a 2D tree
    root_bounds = get_bounds(tree.subdomains[tree.root_id])
    length(root_bounds) == 2 || error("interactive_error_explorer requires a 2D subdivision tree")

    # ── Observables ──────────────────────────────────────────────────────────
    xs_obs         = Observable(collect(range(0.0, 1.0; length=2)))
    ys_obs         = Observable(collect(range(0.0, 1.0; length=2)))
    error_grid_obs = Observable(zeros(2, 2))
    log_scale_obs  = Observable(log_scale)
    raw_error_ref  = Ref{Union{Nothing, NamedTuple}}(nothing)

    obs_state = (;
        xs_obs, ys_obs, error_grid_obs, log_scale_obs, raw_error_ref,
        tree, f, resolution,
    )

    # ── Figure layout ────────────────────────────────────────────────────────
    fig = Figure(size=(900, 750), fontsize=13)

    ax = Axis(fig[1, 1];
        title="Polynomial Approximation Error",
        xlabel="p₁", ylabel="p₂",
        aspect=AxisAspect(1),
    )

    # Heatmap (reactive to Observables)
    hm = heatmap!(ax, xs_obs, ys_obs, error_grid_obs; colormap, interpolate=true)
    hm.inspectable[] = false

    # Subdomain boundaries (static overlay)
    boundary_pts = _collect_boundary_segments(tree)
    if !isempty(boundary_pts)
        linesegments!(ax, boundary_pts; color=(:white, 0.6), linewidth=0.8)
    end

    # Colorbar
    cb_label_obs = Observable(log_scale ? "log₁₀(|f - poly|)" : "|f - poly|")
    cb = Colorbar(fig[1, 2], hm; label=cb_label_obs, width=14, ticklabelsize=9)

    # ── Controls ─────────────────────────────────────────────────────────────
    controls = fig[2, 1:2] = GridLayout()

    refine_btn  = Button(controls[1, 1]; label="Refine View", fontsize=12)
    reset_btn   = Button(controls[1, 2]; label="Reset", fontsize=12)
    toggle_btn  = Button(controls[1, 3]; label="Toggle log/linear", fontsize=12)

    # ── Callbacks ────────────────────────────────────────────────────────────
    _READY = Ref(false)

    on(refine_btn.clicks) do _
        _READY[] || return
        _refine_error!(obs_state, ax)
    end

    on(reset_btn.clicks) do _
        _READY[] || return
        _regenerate_error!(obs_state)
    end

    on(toggle_btn.clicks) do _
        _READY[] || return
        obs_state.log_scale_obs[] = !obs_state.log_scale_obs[]
        _apply_error_display_transform!(obs_state)
        cb_label_obs[] = obs_state.log_scale_obs[] ? "log₁₀(|f - poly|)" : "|f - poly|"
    end

    # ── Initial render ───────────────────────────────────────────────────────
    _regenerate_error!(obs_state)
    _READY[] = true

    display(fig)
    return fig
end

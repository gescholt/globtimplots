# interactive_levelset_explorer.jl
# Interactive GLMakie explorer for subdivision levelset with selection-based refinement.
# Right-click raw CPs (white crosses) to select/deselect, then "Refine Selected" to
# batch-refine using Newton (∇f=0) or Optim (NelderMead f-min) mode.
# Zoom in and click "Refine View" to re-evaluate the contour at higher effective resolution.
#
# Requires GLMakie (not loaded by default in GlobtimPlots — load it separately).

using Printf

# ── Log panel helper ─────────────────────────────────────────────────────────

const _LOG_PANEL_MAX_LINES = 15
const _EXPLORER_LOG_PANEL_WIDTH = 280
const _EXPLORER_CONTROLS_HEIGHT = 70

# ── Slider builder helpers ──────────────────────────────────────────────────

"""
    _make_log_slider!(layout, row, label_text, exponent_range, default_exp)

Create a labeled log₁₀-scale slider in `layout[row, :]`.
Returns the Observable holding the actual value (10^exponent).
"""
function _make_log_slider!(layout, row::Int, label_text::String,
                            exponent_range::AbstractRange, default_exp::Number)
    Label(layout[row, 1], label_text; fontsize=10, halign=:right)
    sl = Slider(layout[row, 2]; range=exponent_range, startvalue=default_exp)
    val_obs = @lift(10.0 ^ $(sl.value))
    Label(layout[row, 3], @lift(@sprintf("%.1e", $val_obs)); fontsize=10, halign=:left)
    return val_obs
end

"""
    _make_linear_slider!(layout, row, label_text, range, default_val)

Create a labeled linear slider in `layout[row, :]`.
Returns the Observable holding the slider value.
"""
function _make_linear_slider!(layout, row::Int, label_text::String,
                               range::AbstractRange, default_val::Number)
    Label(layout[row, 1], label_text; fontsize=10, halign=:right)
    sl = Slider(layout[row, 2]; range=range, startvalue=default_val)
    Label(layout[row, 3], @lift(string(round(Int, $(sl.value)))); fontsize=10, halign=:left)
    return sl.value
end

function _log!(log_lines::Observable, msg::String)
    lines = copy(log_lines[])
    push!(lines, msg)
    length(lines) > _LOG_PANEL_MAX_LINES && deleteat!(lines, 1:length(lines)-_LOG_PANEL_MAX_LINES)
    log_lines[] = lines
end

function _format_eigenvalues(eigs)
    isempty(eigs) && return ""
    parts = [(@sprintf "%+.2e" e) for e in eigs]
    return "  eigs=[$(join(parts, ","))]"
end

# ── Helpers for zoom-based contour refinement ────────────────────────────────

function _compute_levelset_grid(f, xs, ys)
    return [f([x, y]) for x in xs, y in ys]
end

"""
    _apply_levelset_display_transform!(raw_Z_ref, Z_display_obs, log_scale_obs, n_levels)

Apply log₁₀ transform (if enabled) to the raw Z grid and push result to the
display observable.
"""
function _apply_levelset_display_transform!(raw_Z_ref, Z_display_obs, log_scale_obs, n_levels)
    Z = raw_Z_ref[]
    if log_scale_obs[]
        Z_disp, _ = _prepare_contourf_args(Z, n_levels, SubdivisionPartitionStyle(log_scale=true))
    else
        Z_disp = Z
    end
    Z_display_obs[] = Z_disp
end

function _refine_levelset!(xs_obs, ys_obs, raw_Z_ref, Z_display_obs, log_scale_obs,
                            f, ax, root_bounds; resolution::Int, n_levels::Int)
    rect = ax.finallimits[]
    x_min = Float64(rect.origin[1])
    y_min = Float64(rect.origin[2])
    x_max = x_min + Float64(rect.widths[1])
    y_max = y_min + Float64(rect.widths[2])

    # Clamp to domain
    x_min = clamp(x_min, root_bounds[1]...)
    x_max = clamp(x_max, root_bounds[1]...)
    y_min = clamp(y_min, root_bounds[2]...)
    y_max = clamp(y_max, root_bounds[2]...)

    if x_max - x_min < 1e-10 || y_max - y_min < 1e-10
        @warn "_refine_levelset!: visible window too small to refine (zoom out first)"
        return nothing
    end

    xs = collect(range(x_min, x_max; length=resolution))
    ys = collect(range(y_min, y_max; length=resolution))
    Z  = _compute_levelset_grid(f, xs, ys)

    xs_obs[] = xs
    ys_obs[] = ys
    raw_Z_ref[] = Z
    _apply_levelset_display_transform!(raw_Z_ref, Z_display_obs, log_scale_obs, n_levels)

    # Force axis limits to match the (square-padded) data range
    xlims!(ax, x_min, x_max)
    ylims!(ax, y_min, y_max)

    # Print zoom stats
    dx_full = root_bounds[1][2] - root_bounds[1][1]
    dy_full = root_bounds[2][2] - root_bounds[2][1]
    zoom_x = round(dx_full / (x_max - x_min); digits=1)
    zoom_y = round(dy_full / (y_max - y_min); digits=1)
    @printf("  Refined levelset: %d×%d grid  x=[%.3g,%.3g]  y=[%.3g,%.3g]  zoom≈%.1f×%.1f\n",
            resolution, resolution, x_min, x_max, y_min, y_max, zoom_x, zoom_y)
end

function _reset_levelset!(xs_obs, ys_obs, raw_Z_ref, Z_display_obs, log_scale_obs,
                           f, root_bounds; resolution::Int, n_levels::Int)
    xs = collect(range(root_bounds[1]...; length=resolution))
    ys = collect(range(root_bounds[2]...; length=resolution))
    Z  = _compute_levelset_grid(f, xs, ys)

    xs_obs[] = xs
    ys_obs[] = ys
    raw_Z_ref[] = Z
    _apply_levelset_display_transform!(raw_Z_ref, Z_display_obs, log_scale_obs, n_levels)

    @printf("  Reset levelset: %d×%d grid  domain=[%.3g,%.3g]×[%.3g,%.3g]\n",
            resolution, resolution, root_bounds[1]..., root_bounds[2]...)
end

# ── Main interactive explorer ────────────────────────────────────────────────

"""
    interactive_levelset_explorer(
        tree::SubdivisionTree, f;
        refine_newton::Function,
        refine_optim::Function,
        kwargs...
    ) → Vector{Figure}

Tree-based overload — extracts bounds, leaf_bounds, and leaf_l2_errors from the
tree, then delegates to the data-based method.

Returns `[plot_fig, controls_fig]` (two separate windows).
"""
function interactive_levelset_explorer(
    tree::SubdivisionTree, f;
    refine_newton::Function,
    refine_optim::Function,
    raw_cp_points::Vector = Vector{Float64}[],
    cp_points::Vector = Vector{Float64}[],
    cp_types::Vector = String[],
    p_true = nothing,
    l2_tolerance::Union{Nothing, Float64} = nothing,
    resolution::Int = 200,
    n_levels::Int = 30,
    colormap::Symbol = :viridis,
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
    title::String = "Interactive Levelset Explorer",
    fig_size::Tuple{Int, Int} = (1400, 750),
    controls_size::Tuple{Int, Int} = (560, 600),
)
    root_bounds = get_bounds(tree.subdomains[tree.root_id])
    length(root_bounds) == 2 || error("interactive_levelset_explorer requires a 2D subdivision tree")

    # Extract leaf data from tree
    all_leaf_ids = vcat(tree.active_leaves, tree.converged_leaves)
    leaf_bounds = [get_bounds(tree.subdomains[id]) for id in all_leaf_ids]
    leaf_l2_errors = [tree.subdomains[id].l2_error for id in all_leaf_ids]

    return interactive_levelset_explorer(
        f, collect.(root_bounds);
        refine_newton=refine_newton, refine_optim=refine_optim,
        leaf_bounds=leaf_bounds, leaf_l2_errors=leaf_l2_errors,
        raw_cp_points=raw_cp_points, cp_points=cp_points, cp_types=cp_types,
        p_true=p_true, l2_tolerance=l2_tolerance, resolution=resolution,
        n_levels=n_levels, colormap=colormap, style=style, title=title,
        fig_size=fig_size, controls_size=controls_size,
    )
end

"""
    interactive_levelset_explorer(
        f, bounds::Vector;
        refine_newton::Function,
        refine_optim::Function,
        leaf_bounds::Vector,
        leaf_l2_errors::Vector{Float64},
        raw_cp_points::Vector = Vector{Float64}[],
        cp_points::Vector = Vector{Float64}[],
        cp_types::Vector = String[],
        p_true = nothing,
        l2_tolerance::Union{Nothing, Float64} = nothing,
        resolution::Int = 200,
        n_levels::Int = 30,
        colormap::Symbol = :viridis,
        style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
        title::String = "Interactive Levelset Explorer",
    ) → Vector{Figure}

Launch an interactive GLMakie explorer as **two windows**: a plot window (axis +
colorbar) and a controls window (buttons + log panel). This avoids layout
conflicts between `DataAspect()` and fixed-height controls that cause vertical
size constraints on macOS.

Shows the objective function as a filled
contour with subdivision boundaries overlaid. Right-click raw critical points
(white crosses) to select/deselect them, then click "Refine Selected" to
batch-refine all selected CPs.

## Interaction
- **Right-click** a raw CP → toggle selection (highlighted in yellow)
- **Refine Selected (N)** batch-refines all selected CPs, draws trajectories + markers
- **Refine:** dropdown menu selects refinement mode (Newton ∇f=0 or Optim f-min)
- **Log₁₀** toggle switch enables/disables log₁₀ scale on the contour
- **Levels** slider adjusts contour density (5–100 levels)
- **Clear** removes all refined markers, trajectories, and selection
- **Refine View** re-evaluates the contour at full resolution within the current zoom window
- **Reset** returns to the full domain view

## Keyboard shortcuts (plot window)
| Key | Action |
|-----|--------|
| `r` | Refine Selected |
| `c` | Clear Refined |
| `v` | Refine View |
| `z` | Reset View |
| `l` | Toggle Log₁₀ |

## Callback contract
Both `refine_newton` and `refine_optim` must accept `(point::Vector{Float64}; kwargs...)`
and return a NamedTuple with fields:
```julia
(; point::Vector{Float64}, objective_value::Float64, gradient_norm::Float64,
   cp_type::Symbol, converged::Bool, iterations::Int, trace::Vector{Vector{Float64}})
```

Keyword arguments forwarded from sliders:
- **Newton**: `tol`, `accept_tol`, `max_iterations`, `hessian_tol`, `trust_radius_fraction`
- **Optim**: `f_abstol`, `x_abstol`, `max_iterations`, `hessian_tol`, `method` (`:neldermead` or `:lbfgs`), `step_size` (LBFGS only)

## Arguments
- `f`: Objective function `f(x::Vector{Float64}) → Float64`
- `bounds`: Domain bounds as `[collect(dim1_bounds), collect(dim2_bounds)]`
- `refine_newton`: Callback for trust-region Newton on ∇f=0 (all CP types)
- `refine_optim`: Callback for NelderMead f-minimization
- `leaf_bounds`: Per-leaf domain bounds from subdivision
- `leaf_l2_errors`: Per-leaf L2 approximation errors

## Keyword Arguments
- `raw_cp_points`: Raw (pre-refinement) critical points — pickable targets
- `cp_points, cp_types`: Already-refined CPs and their types
- `p_true`: True parameter vector (gold star)
- `l2_tolerance`: For convergence border coloring
- `resolution`: Grid points per axis for contour evaluation
- `n_levels`: Number of contour levels
- `colormap`: Colormap for filled contour
- `style`: `SubdivisionPartitionStyle` for marker/border styling
- `title`: Plot title
"""
function interactive_levelset_explorer(
    f, bounds::Vector;
    refine_newton::Function,
    refine_optim::Function,
    leaf_bounds::Vector,
    leaf_l2_errors::Vector{Float64},
    raw_cp_points::Vector = Vector{Float64}[],
    cp_points::Vector = Vector{Float64}[],
    cp_types::Vector = String[],
    p_true = nothing,
    l2_tolerance::Union{Nothing, Float64} = nothing,
    resolution::Int = 200,
    n_levels::Int = 30,
    colormap::Symbol = :viridis,
    style::SubdivisionPartitionStyle = SubdivisionPartitionStyle(),
    title::String = "Interactive Levelset Explorer",
    fig_size::Tuple{Int, Int} = (1400, 750),
    controls_size::Tuple{Int, Int} = (560, 600),
)
    # Verify 2D
    length(bounds) == 2 || error("interactive_levelset_explorer requires 2D bounds")
    root_bounds = [(Float64(b[1]), Float64(b[2])) for b in bounds]

    d_lo = Float64[root_bounds[1][1], root_bounds[2][1]]
    d_hi = Float64[root_bounds[1][2], root_bounds[2][2]]

    # Filter raw CPs to domain
    filtered_raw_cps = filter(p -> _in_domain(p, d_lo, d_hi), raw_cp_points)

    # ── Plot figure (clean: axis + colorbar only) ────────────────────────────
    fig = Figure(size=fig_size, fontsize=style.fontsize)
    ax = Axis(fig[1, 1];
        xlabel="p₁", ylabel="p₂",
        title=title,
        aspect=AxisAspect(1),
    )

    # ── Observable contourf grid ─────────────────────────────────────────────
    xs_obs = Observable(collect(range(d_lo[1], d_hi[1]; length=resolution)))
    ys_obs = Observable(collect(range(d_lo[2], d_hi[2]; length=resolution)))
    Z_initial = _compute_levelset_grid(f, xs_obs[], ys_obs[])
    raw_Z_ref = Ref{Matrix{Float64}}(Z_initial)
    log_scale_obs = Observable(false)
    Z_display_obs = Observable(copy(Z_initial))

    n_levels_obs = Observable(n_levels)
    cf = contourf!(ax, xs_obs, ys_obs, Z_display_obs;
                   levels=n_levels_obs, colormap=colormap)
    cf.inspectable[] = false   # prevent contourf from intercepting pick()

    # ── Static overlays (same as _build_levelset_base! minus contourf) ───────
    _draw_convergence_boundaries!(ax, leaf_bounds, leaf_l2_errors;
                                   l2_tolerance=l2_tolerance, style=style)

    if style.show_critical_points && !isempty(cp_points)
        _scatter_cps_by_type!(ax, cp_points, cp_types;
                               domain_lo=d_lo, domain_hi=d_hi, style=style)
    end

    if style.show_p_true && p_true !== nothing
        _scatter_p_true!(ax, p_true; style=style)
    end

    # Make all existing plots non-pickable so only raw_scatter is pickable
    for p in ax.scene.plots
        p.inspectable[] = false
    end

    # Pickable raw CP scatter — these are the click targets (not via _scatter_raw_cps!)
    raw_scatter = if !isempty(filtered_raw_cps)
        raw_xs = [p[1] for p in filtered_raw_cps]
        raw_ys = [p[2] for p in filtered_raw_cps]
        scatter!(ax, raw_xs, raw_ys;
                 marker=:cross, markersize=style.raw_cp_markersize,
                 color=style.raw_cp_color,
                 strokecolor=style.raw_cp_color,
                 strokewidth=style.raw_cp_strokewidth)
    else
        nothing
    end

    # ── Selection highlight scatter ──────────────────────────────────────────
    selected_indices = Observable(Set{Int}())
    last_refined_starts = Observable(Vector{Float64}[])  # for re-refine with new params
    sel_points_obs = @lift begin
        idxs = $selected_indices
        isempty(idxs) ? Point2f[] : [Point2f(filtered_raw_cps[i]...) for i in idxs]
    end
    sel_scatter = scatter!(ax, sel_points_obs;
        marker=:cross, markersize=style.raw_cp_markersize + 6,
        color=:yellow, strokecolor=:yellow,
        strokewidth=style.raw_cp_strokewidth + 1)
    sel_scatter.inspectable[] = false

    # Colorbar with observable label
    cb_label_obs = Observable("f(p)")
    Colorbar(fig[1, 2], cf; label=cb_label_obs,
             width=style.colorbar_width,
             ticklabelsize=style.colorbar_ticklabelsize)

    # ── Controls figure (separate window: buttons + log panel) ───────────────
    ctrl_fig = Figure(size=controls_size, fontsize=style.fontsize)

    # Activity log panel (top of controls window)
    log_lines = Observable(String["Ready — right-click raw CPs to select"])
    log_text = @lift join($log_lines, "\n")

    log_panel = ctrl_fig[1, 1] = GridLayout()
    Box(log_panel[1, 1]; color=(:black, 0.05), strokecolor=:gray80, strokewidth=1)
    Label(log_panel[1, 1], log_text;
          fontsize=10, halign=:left, valign=:top,
          padding=(8, 8, 8, 8), font=:regular)

    # Controls (bottom of controls window)
    controls = ctrl_fig[2, 1] = GridLayout()

    mode_obs = Observable(:newton)
    info_obs   = Observable("Right-click raw CPs to select, then 'Refine Selected'")
    # Smart label: shows "Re-Refine (N)" when no selection but last_refined_starts exist
    n_sel_label = @lift begin
        n_sel = length($selected_indices)
        n_last = length($last_refined_starts)
        if n_sel > 0
            "Refine Selected ($n_sel)"
        elseif n_last > 0
            "Re-Refine ($n_last)"
        else
            "Refine Selected (0)"
        end
    end

    # Row 1: [Refine: label] [Mode menu] [Refine Sel (N)] [Clear Refined]
    Label(controls[1, 1], "Refine:"; fontsize=11, halign=:right)
    mode_menu = Menu(controls[1, 2]; options=["Newton ∇f=0", "LBFGS f-min", "NelderMead f-min"],
                     default="Newton ∇f=0", fontsize=11)
    refine_sel_btn = Button(controls[1, 3]; label=n_sel_label, fontsize=11)
    clear_btn      = Button(controls[1, 4]; label="Clear Refined", fontsize=11)

    # Row 2: [Refine View] [Reset View] [Log₁₀ label] [Toggle switch]
    refine_btn = Button(controls[2, 1]; label="Refine View", fontsize=11)
    reset_btn  = Button(controls[2, 2]; label="Reset View", fontsize=11)
    Label(controls[2, 3], "Log₁₀"; fontsize=11, halign=:right)
    log_toggle = Toggle(controls[2, 4]; active=false)

    # Row 3: Contour levels slider
    Label(controls[3, 1], "Levels"; fontsize=11, halign=:right)
    levels_sl = Slider(controls[3, 2:3]; range=5:5:100, startvalue=n_levels)
    Label(controls[3, 4], @lift(string(round(Int, $(levels_sl.value)))); fontsize=10)
    on(levels_sl.value) do nv
        n_levels_obs[] = round(Int, nv)
        if log_scale_obs[]
            _apply_levelset_display_transform!(raw_Z_ref, Z_display_obs, log_scale_obs, round(Int, nv))
        end
    end

    # ── Newton parameter sliders ─────────────────────────────────────────────
    newton_panel = controls[4, 1:4] = GridLayout()
    Label(newton_panel[1, 1:3], "── Newton Parameters ──"; fontsize=10, halign=:left, color=:gray50)
    newton_tol_obs        = _make_log_slider!(newton_panel, 2, "tol", -12.0:0.5:-2.0, -8.0)
    newton_accept_tol_obs = _make_log_slider!(newton_panel, 3, "accept_tol", -6.0:0.5:0.0, -2.0)
    newton_maxiter_obs    = _make_linear_slider!(newton_panel, 4, "max_iter", 10:10:1000, 200)
    hessian_tol_obs       = _make_log_slider!(newton_panel, 5, "hessian_tol", -10.0:0.5:-2.0, -6.0)
    newton_step_obs       = _make_log_slider!(newton_panel, 6, "step size", -2.0:0.25:0.0, -1.0)

    # ── Optim parameter sliders ──────────────────────────────────────────────
    optim_panel = controls[5, 1:4] = GridLayout()
    Label(optim_panel[1, 1:3], "── Optim Parameters ──"; fontsize=10, halign=:left, color=:gray50)
    optim_f_abstol_obs = _make_log_slider!(optim_panel, 2, "f_abstol", -12.0:0.5:-1.0, -6.0)
    optim_x_abstol_obs = _make_log_slider!(optim_panel, 3, "x_abstol", -12.0:0.5:-1.0, -6.0)
    optim_maxiter_obs  = _make_linear_slider!(optim_panel, 4, "max_iter", 10:10:2000, 300)
    lbfgs_step_obs     = _make_log_slider!(optim_panel, 5, "LBFGS step", -3.0:0.25:1.0, 0.0)

    # Row after sliders: info label (full width)
    Label(controls[6, 1:4], info_obs; fontsize=10, halign=:left)

    # ── State for added plot objects ─────────────────────────────────────────
    added_plots = Makie.AbstractPlot[]

    # ── Mode menu ─────────────────────────────────────────────────────────────
    on(mode_menu.selection) do sel
        mode_obs[] = if sel == "Newton ∇f=0"
            :newton
        elseif sel == "LBFGS f-min"
            :lbfgs
        else
            :neldermead
        end
        _log!(log_lines, "Switched to $sel mode")
    end

    # ── Clear button ─────────────────────────────────────────────────────────
    on(clear_btn.clicks) do _
        for p in added_plots
            delete!(ax.scene, p)
        end
        empty!(added_plots)
        selected_indices[] = Set{Int}()
        last_refined_starts[] = Vector{Float64}[]
        info_obs[] = "Cleared — right-click raw CPs to select"
        log_lines[] = String["Cleared — right-click raw CPs to select"]
    end

    # ── Refine View button ───────────────────────────────────────────────────
    on(refine_btn.clicks) do _
        _refine_levelset!(xs_obs, ys_obs, raw_Z_ref, Z_display_obs, log_scale_obs,
                           f, ax, root_bounds; resolution=resolution, n_levels=round(Int, n_levels_obs[]))
        info_obs[] = "Refined view — zoom and click 'Refine View' again for more detail"
        _log!(log_lines, "Refined view to current zoom window")
    end

    # ── Reset button ─────────────────────────────────────────────────────────
    on(reset_btn.clicks) do _
        _reset_levelset!(xs_obs, ys_obs, raw_Z_ref, Z_display_obs, log_scale_obs,
                          f, root_bounds; resolution=resolution, n_levels=round(Int, n_levels_obs[]))
        autolimits!(ax)
        info_obs[] = "Reset to full domain"
        _log!(log_lines, "Reset to full domain")
    end

    # ── Log/linear toggle ────────────────────────────────────────────────────
    on(log_toggle.active) do is_log
        log_scale_obs[] = is_log
        _apply_levelset_display_transform!(raw_Z_ref, Z_display_obs, log_scale_obs, round(Int, n_levels_obs[]))
        cb_label_obs[] = is_log ? "log₁₀ f(p)" : "f(p)"
        mode_str = is_log ? "log₁₀" : "linear"
        info_obs[] = "Switched to $mode_str scale"
        _log!(log_lines, "Switched to $mode_str scale")
    end

    # ── Right-click / Ctrl+click handler (toggle selection) ─────────────────
    on(events(ax.scene).mousebutton) do event
        event.action == Makie.Mouse.press || return Consume(false)
        is_right = event.button == Makie.Mouse.right
        is_ctrl_left = event.button == Makie.Mouse.left &&
            Makie.Keyboard.left_control in events(ax.scene).keyboardstate
        (is_right || is_ctrl_left) || return Consume(false)
        Makie.is_mouseinside(ax.scene) || return Consume(false)
        raw_scatter === nothing && return Consume(false)

        # Pick the plot object under cursor (radius=10 for trackpad tolerance)
        mp = events(ax.scene).mouseposition[]
        picked_plot, picked_idx = pick(ax.scene, mp, 10)
        picked_plot === raw_scatter || return Consume(false)
        (picked_idx < 1 || picked_idx > length(filtered_raw_cps)) && return Consume(false)

        # Toggle selection
        cur = copy(selected_indices[])
        if picked_idx in cur
            delete!(cur, picked_idx)
        else
            push!(cur, picked_idx)
        end
        selected_indices[] = cur
        pt = filtered_raw_cps[picked_idx]
        if picked_idx in cur
            _log!(log_lines, "Selected CP #$picked_idx at [$(round.(pt; digits=3))]")
        else
            _log!(log_lines, "Deselected CP #$picked_idx")
        end
        info_obs[] = "Selected $(length(cur)) CP(s) — click 'Refine Selected' to refine"

        return Consume(true)
    end

    # ── Refine Selected / Re-Refine button ───────────────────────────────────
    on(refine_sel_btn.clicks) do _
        sel = selected_indices[]

        # Determine starting points: new selection, or re-refine last set
        start_points = if !isempty(sel)
            pts = [collect(Float64, filtered_raw_cps[idx]) for idx in sort(collect(sel))]
            last_refined_starts[] = copy(pts)
            pts
        elseif !isempty(last_refined_starts[])
            # Re-refine: clear old plot objects first
            for p in added_plots
                delete!(ax.scene, p)
            end
            empty!(added_plots)
            copy(last_refined_starts[])
        else
            info_obs[] = "No CPs selected — right-click to select"
            _log!(log_lines, "No CPs selected — right-click to select")
            return
        end

        is_rerefine = isempty(sel) && !isempty(last_refined_starts[])

        mode = mode_obs[]
        mode_str = if mode == :newton
            "Newton"
        elseif mode == :lbfgs
            "LBFGS"
        else
            "NelderMead"
        end

        refine_fn = if mode == :newton
            pt -> refine_newton(pt;
                tol=newton_tol_obs[], accept_tol=newton_accept_tol_obs[],
                max_iterations=round(Int, newton_maxiter_obs[]),
                hessian_tol=hessian_tol_obs[],
                trust_radius_fraction=newton_step_obs[])
        elseif mode == :lbfgs
            pt -> refine_optim(pt;
                f_abstol=optim_f_abstol_obs[], x_abstol=optim_x_abstol_obs[],
                max_iterations=round(Int, optim_maxiter_obs[]),
                hessian_tol=hessian_tol_obs[],
                method=:lbfgs, step_size=lbfgs_step_obs[])
        else
            pt -> refine_optim(pt;
                f_abstol=optim_f_abstol_obs[], x_abstol=optim_x_abstol_obs[],
                max_iterations=round(Int, optim_maxiter_obs[]),
                hessian_tol=hessian_tol_obs[],
                method=:neldermead)
        end

        n_ok = 0
        action = is_rerefine ? "Re-refining" : "Refining"
        _log!(log_lines, "$action $(length(start_points)) CPs [$mode_str]…")

        for (i, pt) in enumerate(start_points)
            try
                result = refine_fn(pt)

                # Draw trajectory with arrowhead
                if !isempty(result.trace) && length(result.trace) >= 2
                    traj = lines!(ax, [p[1] for p in result.trace],
                                      [p[2] for p in result.trace];
                                  color=:orange, linewidth=2, linestyle=:dash)
                    push!(added_plots, traj)

                    # Directional arrowhead at end of trace
                    p_prev = result.trace[end-1]
                    p_end  = result.trace[end]
                    dx, dy = p_end[1] - p_prev[1], p_end[2] - p_prev[2]
                    if dx^2 + dy^2 > 0
                        angle = atan(dy, dx) - π/2
                        arr = scatter!(ax, [p_end[1]], [p_end[2]];
                                       marker=:utriangle, markersize=10,
                                       color=:orange, rotation=angle)
                        push!(added_plots, arr)
                    end
                end

                # Draw refined CP marker colored by type; red outline if not converged
                cp_color, cp_marker = cp_type_appearance(result.cp_type)
                stroke_clr = result.converged ? :black : :red
                stroke_w   = result.converged ? 1.5 : 2.5
                rs = scatter!(ax, [result.point[1]], [result.point[2]];
                              marker=cp_marker, markersize=12, color=cp_color,
                              strokecolor=stroke_clr, strokewidth=stroke_w)
                push!(added_plots, rs)
                n_ok += 1

                # Rich log line with optional eigenvalues
                eig_str = hasproperty(result, :eigenvalues) ? _format_eigenvalues(result.eigenvalues) : ""
                _log!(log_lines, @sprintf("  #%d → %s  f=%.3e  ‖∇f‖=%.1e  iters=%d%s",
                    i, result.cp_type, result.objective_value, result.gradient_norm, result.iterations, eig_str))
            catch e
                @warn "Refinement failed for point $i" exception=(e, catch_backtrace())
                _log!(log_lines, "  #$i — FAILED: $(sprint(showerror, e))")
            end
        end

        info_obs[] = "$action $n_ok/$(length(start_points)) CPs [$mode_str]"
        _log!(log_lines, "$action $n_ok/$(length(start_points)) CPs [$mode_str]")
        if !isempty(sel)
            selected_indices[] = Set{Int}()   # clear selection after refining (not on re-refine)
        end
    end

    # ── Keyboard shortcuts (plot window) ────────────────────────────────────
    on(events(fig.scene).keyboardbutton) do event
        event.action == Makie.Keyboard.press || return Consume(false)
        key = event.key
        if key == Makie.Keyboard.r
            notify(refine_sel_btn.clicks)
        elseif key == Makie.Keyboard.c
            notify(clear_btn.clicks)
        elseif key == Makie.Keyboard.v
            notify(refine_btn.clicks)
        elseif key == Makie.Keyboard.z
            notify(reset_btn.clicks)
        elseif key == Makie.Keyboard.l
            log_toggle.active[] = !log_toggle.active[]
        else
            return Consume(false)
        end
        return Consume(true)
    end

    return [fig, ctrl_fig]
end

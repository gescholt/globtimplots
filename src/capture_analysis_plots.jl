"""
    Capture Analysis Visualization

Multi-panel composite figures showing how polynomial critical points converge
toward known critical points as polynomial complexity (support size) increases, with
sparsification speed vs accuracy analysis.

Functions:
- `plot_capture_convergence`: Distance distributions + capture rate bars (+ optional L2)
- `plot_capture_sparsification_combined`: Side-by-side: CP accuracy (distance boxplots)
  + HC solve time (grouped bars with time-saved annotations, L2 range in legend)

Requires: GlobtimPostProcessing (CaptureResult, KnownCriticalPoints)
"""

using GlobtimPostProcessing: CaptureResult, KnownCriticalPoints
using Printf
using Random: MersenneTwister

# --- Shared constants & helpers -----------------------------------------------

# CP type colors/labels come from CP_TYPE_TABLE in interfaces.jl (single source of truth).
# Plural labels for capture analysis context:
const _CP_PLURAL_LABELS = Dict(:min => "Minima", :max => "Maxima", :saddle => "Saddles")

"""
Compute horizontal offsets for dodged groups centered at 0.

Returns a vector of offsets for each dodge group (1..n_groups),
evenly distributed across [-total_width/2, +total_width/2].
"""
function _compute_dodge_offsets(n_groups::Int, total_width::Float64)
    if n_groups == 1
        return [0.0]
    end
    step = total_width / (n_groups - 1)
    return [(-total_width / 2) + (i - 1) * step for i in 1:n_groups]
end

"""
Compute adaptive spacing parameters from a set of x-axis positions.

All widths, offsets, and jitter scales derive from the actual data spacing,
so plots automatically adapt to any x-axis values -- whether evenly spaced
polynomial degrees (4, 6, 8, 10) or non-uniform support sizes (70, 210, 495, 1001).

Returns a NamedTuple with:
- `min_gap`: minimum distance between adjacent positions
- `fill_width`: recommended total width for elements at a single position (~80% of min_gap)
- `jitter_scale`: recommended scatter jitter magnitude (~10% of fill_width)
- `label_offset`: recommended horizontal offset for text labels beyond the last position
"""
function _adaptive_spacing(positions::AbstractVector{<:Real})
    sorted = sort(unique(Float64.(positions)))
    n = length(sorted)
    if n <= 1
        # Single position: derive scale from the position value itself
        scale = n == 1 ? max(abs(sorted[1]) * 0.1, 1.0) : 1.0
        return (
            min_gap = scale,
            fill_width = scale * 0.8,
            jitter_scale = scale * 0.08,
            label_offset = scale * 0.5,
        )
    end
    min_gap = minimum(diff(sorted))
    fill = min_gap * 0.8
    return (
        min_gap = min_gap,
        fill_width = fill,
        jitter_scale = fill * 0.1,
        label_offset = min_gap * 0.4,
    )
end

"""
Map non-uniform values to evenly-spaced rank positions (1, 2, 3, ...).

When x-axis values have widely varying gaps (e.g., support sizes from `binomial(n+d,d)`),
placing bars at literal values makes them vanishingly thin at the sparse end of the axis.
Rank-based positioning gives uniform spacing while preserving the original values as tick labels.

Returns `(positions, ticks, value_to_rank)` where:
- `positions`: rank-mapped vector (same length as input `values`)
- `ticks`: `(tick_positions, tick_labels)` tuple for `ax.xticks`
- `value_to_rank`: `Dict{Int, Int}` mapping original values to rank positions
"""
function _rank_positions(values::AbstractVector{<:Integer})
    sorted_unique = sort(unique(values))
    value_to_rank = Dict(v => i for (i, v) in enumerate(sorted_unique))
    ranked = [value_to_rank[v] for v in values]
    ticks = (collect(1:length(sorted_unique)), string.(sorted_unique))
    return ranked, ticks, value_to_rank
end

"""
Build variant color palette: gray for Full (index 1), warm colors for sparsified variants.

All colors are returned as `RGBAf` with the given `alpha` baked in, ensuring
consistent color types for CairoMakie rendering (no `(color, alpha)` tuple ambiguity).

Uses a slice of the :YlOrRd colormap starting at 40% to avoid near-white colors.
"""
function _variant_color_palette(n_variants::Int; alpha::Float64 = 0.7)
    # Convert any Colorant to RGBAf with the given alpha.
    # Uses Makie's RGBAf(c) conversion, then overrides alpha.
    function _to_rgbaf(c, a)
        rgba = RGBAf(c)
        return RGBAf(rgba.r, rgba.g, rgba.b, Float32(a))
    end

    full_color = RGBAf(0.25f0, 0.25f0, 0.25f0, Float32(alpha))
    if n_variants == 1
        return RGBAf[full_color]
    end
    # Sample from 40%-95% of YlOrRd to get visible warm tones (skip the pale end)
    n_sparse = n_variants - 1
    sparse_colors = [
        colorant"#feb24c",
        colorant"#fd8d3c",
        colorant"#f03b20",
        colorant"#bd0026",
        colorant"#800026",
    ]
    palette = if n_sparse <= length(sparse_colors)
        [_to_rgbaf(c, alpha) for c in sparse_colors[1:n_sparse]]
    else
        # Fall back to sampling a gradient for many variants
        cmap = cgrad(:YlOrRd)
        [_to_rgbaf(cmap[0.4+0.55*(i-1)/max(n_sparse - 1, 1)], alpha) for i in 1:n_sparse]
    end
    return RGBAf[full_color; palette...]
end

"""
Standard legend styling kwargs.
"""
function _legend_kwargs(; labelsize = 10, titlesize = 11)
    return (;
        framevisible = true,
        backgroundcolor = (:white, 0.9),
        padding = (8, 8, 6, 6),
        labelsize = labelsize,
        titlesize = titlesize,
    )
end

# --- Function 1: plot_capture_convergence -------------------------------------

"""
    plot_capture_convergence(
        degree_capture_results::Vector{Tuple{Int, CaptureResult}},
        known::KnownCriticalPoints;
        fig_size = (900, 900),
        l2_errors = nothing,
        show_l2 = false,
        support_sizes = nothing,
        save_path = nothing,
    ) -> Figure

Create a multi-panel figure showing capture analysis convergence.

When `support_sizes` is provided, the x-axis shows the number of nonzero polynomial
coefficients (support size) instead of polynomial degree. All spacing and bar widths
adapt automatically to the data via `_adaptive_spacing`.

# Panels (top to bottom)
1. **Distance distribution**: One sub-panel per CP type (min/max/saddle), each with its
   own y-range and log y-scale. Boxplots + jittered scatter of distances from each known
   CP to its nearest computed CP. Horizontal dashed lines at tolerance levels.
2. **Capture rate**: Grouped bars showing fraction of known CPs captured
   at each tolerance level.
3. **L2 approximation error** (optional): Only shown when both `l2_errors` data is
   provided AND `show_l2=true`. Not displayed by default.

# Arguments
- `degree_capture_results`: Vector of `(degree, CaptureResult)` tuples, one per degree.
  All CaptureResults must use the same `tolerance_fractions`.
- `known`: `KnownCriticalPoints` with the ground truth.

# Keyword Arguments
- `fig_size`: Figure dimensions in pixels.
- `l2_errors`: Optional `Vector{Tuple{Int, Float64}}` of `(degree, l2_error)` pairs.
- `show_l2`: Whether to display the L2 error panel. Default `false`. Requires `l2_errors`
  to be provided as well.
- `support_sizes`: Optional `Dict{Int, Int}` mapping degree -> support size (nonzero
  coefficients). When provided, x-axis shows support size instead of degree.
- `save_path`: Optional file path to save the figure (e.g., `"capture_convergence.png"`).

# Returns
- `Figure`: CairoMakie figure object.

# Example
```julia
using GlobtimPlots, GlobtimPostProcessing

# With support size on x-axis
support_sizes = Dict(dr.degree => dr.support_size
    for dr in degree_results if dr.status == "success")
fig = plot_capture_convergence(
    degree_capture_results, known_cps;
    support_sizes = support_sizes,
    l2_errors = [(dr.degree, dr.l2_approx_error) for dr in degree_results if dr.status == "success"],
)
display(fig)
```
"""
function plot_capture_convergence(
    degree_capture_results::Vector{Tuple{Int,CaptureResult}},
    known::KnownCriticalPoints;
    fig_size::Tuple{Int,Int} = (900, 900),
    l2_errors::Union{Nothing,Vector{Tuple{Int,Float64}}} = nothing,
    show_l2::Bool = false,
    support_sizes::Union{Nothing,Dict{Int,Int}} = nothing,
    save_path::Union{String,Nothing} = nothing,
)
    isempty(degree_capture_results) && error("degree_capture_results must be non-empty")

    degrees = [d for (d, _) in degree_capture_results]

    # Validate tolerance consistency across all CaptureResults
    ref_cr = degree_capture_results[1][2]
    n_tols = length(ref_cr.tolerance_fractions)
    for (deg, cr) in degree_capture_results
        if cr.tolerance_fractions != ref_cr.tolerance_fractions
            error(
                "All CaptureResults must use the same tolerance_fractions. " *
                "Degree $deg has $(cr.tolerance_fractions), expected $(ref_cr.tolerance_fractions)",
            )
        end
    end

    # X-axis: support size (if provided) or degree (fallback)
    # When support sizes are provided, use rank-based (categorical) positioning so that
    # bars are uniformly spaced regardless of how non-uniform the actual support sizes are
    # (e.g., binomial(n+d,d) grows rapidly). Tick labels show actual support sizes.
    if support_sizes !== nothing
        raw_support = [support_sizes[d] for d in degrees]
        x_positions, x_ticks, support_to_rank = _rank_positions(raw_support)
        x_label = "Support Size (nonzero coefficients)"
        x_title_suffix = "Support Size"
    else
        x_positions = degrees
        x_ticks = (x_positions, string.(x_positions))
        x_label = "Polynomial Degree"
        x_title_suffix = "Polynomial Degree"
    end
    deg_to_xpos = Dict(zip(degrees, x_positions))
    spacing = _adaptive_spacing(x_positions)

    has_l2 = show_l2 && l2_errors !== nothing && !isempty(l2_errors)

    # Collect unique types (sorted for consistent ordering)
    all_types = sort(unique(known.types))
    n_types = length(all_types)

    # Scale figure height: Panel 1 gets ~200px per type, L2 panel ~250px if shown
    n_other_panels = has_l2 ? 1 : 0
    auto_height = n_types * 200 + n_other_panels * 250
    actual_size = (fig_size[1], max(fig_size[2], auto_height))
    fig = Figure(size = actual_size, fontsize = 13)

    # Deterministic jitter RNG (reproducible scatter positions)
    jitter_rng = MersenneTwister(42)

    # --- Panel 1: Distance Distribution (per-type subpanels) ------------------
    panel1_gl = fig[1, 1] = GridLayout()

    # Build per-type distance data: type -> (positions, values)
    type_data = Dict{Symbol,Tuple{Vector{Float64},Vector{Float64}}}()
    for cp_type in all_types
        type_data[cp_type] = (Float64[], Float64[])
    end
    for (deg, cr) in degree_capture_results
        xpos = deg_to_xpos[deg]
        for (k, dist) in enumerate(cr.distances)
            cp_type = known.types[k]
            isfinite(dist) || continue
            clamped_dist = max(dist, 1e-16)
            push!(type_data[cp_type][1], Float64(xpos))
            push!(type_data[cp_type][2], clamped_dist)
        end
    end

    tol_line_colors = [:gray70, :gray60, :gray50, :gray40]
    panel1_axes = Axis[]

    for (ti, cp_type) in enumerate(all_types)
        is_first = ti == 1
        is_last = ti == n_types
        type_count = count(x -> x == cp_type, known.types)
        type_label = _CP_PLURAL_LABELS[cp_type]
        type_color = CP_TYPE_TABLE[cp_type].color

        ax = Axis(
            panel1_gl[ti, 1];
            ylabel = "Distance to nearest CP",
            yscale = log10,
            xgridvisible = true,
            ygridvisible = true,
            xgridstyle = :dash,
            ygridstyle = :dash,
            title = is_first ? "Distance from Known CPs to Nearest Computed CP" : "",
            xticklabelsvisible = is_last,
            xticksvisible = is_last,
            xlabelvisible = is_last,
        )
        push!(panel1_axes, ax)

        # Annotate type in top-left corner of each sub-axis
        text!(
            ax,
            Point2f(0.02, 0.95),
            text = "$type_label ($type_count)";
            fontsize = 10,
            color = type_color,
            align = (:left, :top),
            space = :relative,
        )

        positions, values = type_data[cp_type]
        if !isempty(positions)
            boxplot!(
                ax,
                positions,
                values;
                color = type_color,
                width = spacing.fill_width,
                whiskerwidth = 0.5,
                show_outliers = false,
                medianlinewidth = 2,
            )

            # Jittered scatter overlay
            jittered_x = [p + spacing.jitter_scale * randn(jitter_rng) for p in positions]
            scatter!(
                ax,
                jittered_x,
                values;
                color = (type_color, 0.3),
                markersize = 2,
                strokewidth = 0,
            )
        end

        # Tolerance hlines (on every sub-axis for reference)
        for (i, tf) in enumerate(ref_cr.tolerance_fractions)
            tol_abs = tf * known.domain_diameter
            lc = i <= length(tol_line_colors) ? tol_line_colors[i] : :gray50
            hlines!(ax, [tol_abs]; linestyle = :dash, color = lc, linewidth = 0.8)
            # Label only on last (bottom) sub-axis to avoid clutter
            if is_last
                text!(
                    ax,
                    @sprintf("%.1f%%", 100 * tf);
                    position = (Float64(x_positions[end]) + spacing.label_offset, tol_abs),
                    fontsize = 9,
                    color = lc,
                    align = (:left, :center),
                )
            end
        end

        ax.xticks = x_ticks
    end

    # Link x-axes across sub-panels
    if length(panel1_axes) > 1
        for ax in panel1_axes[2:end]
            linkxaxes!(panel1_axes[1], ax)
        end
    end

    # Legend for Panel 1
    legend_elements = [
        MarkerElement(;
            color = CP_TYPE_TABLE[t].color,
            marker = CP_TYPE_TABLE[t].marker,
            markersize = 12,
        ) for t in all_types
    ]
    legend_labels =
        [_CP_PLURAL_LABELS[t] * " ($(count(x -> x == t, known.types)))" for t in all_types]
    Legend(fig[1, 2], legend_elements, legend_labels; _legend_kwargs(; labelsize = 11)...)

    # --- Panel 2 (mothballed): Capture Rate Bars --------------------------------
    # Capture rate bars are redundant with the distance distribution boxplots
    # (Panel 1) which already show whether CPs fall below tolerance lines.
    # This block can be restored if needed — search for "mothballed".
    #=
    capture_bar_width = spacing.fill_width / n_tols
    ax2 = Axis(fig[2, 1];
        xlabel = has_l2 ? "" : x_label,
        ylabel = "Capture rate (%)",
        xgridvisible = false, ygridvisible = true, ygridstyle = :dash,
        title = "Capture Rate vs $x_title_suffix",
    )
    tol_palette = cgrad(:blues, n_tols + 1; categorical = true)
    bar_positions = Float64[]
    bar_values = Float64[]
    bar_dodge = Int[]
    bar_colors = typeof(tol_palette[1])[]
    for (deg, cr) in degree_capture_results
        xpos = deg_to_xpos[deg]
        for (ti, rate) in enumerate(cr.capture_rates)
            push!(bar_positions, Float64(xpos))
            push!(bar_values, 100.0 * rate)
            push!(bar_dodge, ti)
            push!(bar_colors, tol_palette[ti])
        end
    end
    barplot!(ax2, bar_positions, bar_values;
        dodge = bar_dodge, color = bar_colors, width = capture_bar_width)
    loosest_tol_offset = _compute_dodge_offsets(n_tols, capture_bar_width * n_tols)[end]
    for (i, (deg, cr)) in enumerate(degree_capture_results)
        rate = cr.capture_rates[end]
        n_captured = count(cr.captured_at[end])
        text!(ax2, @sprintf("%d/%d", n_captured, cr.n_known);
            position = (Float64(x_positions[i]) + loosest_tol_offset, 100.0 * rate + 1.5),
            fontsize = 10, align = (:center, :bottom), color = :gray40)
    end
    hlines!(ax2, [100.0]; linestyle = :dash, color = :gray60, linewidth = 0.8)
    ax2.xticks = x_ticks
    ylims!(ax2, 0, 110)
    tol_elements = [PolyElement(; color = tol_palette[ti]) for ti in 1:n_tols]
    tol_labels = [@sprintf("%.1f%% (%.3f)", 100 * ref_cr.tolerance_fractions[ti],
                           ref_cr.tolerance_values[ti]) for ti in 1:n_tols]
    Legend(fig[2, 2], tol_elements, tol_labels; title = "Tolerance", _legend_kwargs()...)
    =#

    # --- Panel 2: L2 Error (optional) -----------------------------------------
    if has_l2
        # Remap l2_errors degrees to x positions (rank-based when using support sizes)
        if support_sizes !== nothing
            l2_x = [Float64(support_to_rank[support_sizes[d]]) for (d, _) in l2_errors]
        else
            l2_x = [Float64(d) for (d, _) in l2_errors]
        end
        l2_vals = [v for (_, v) in l2_errors]

        ax3 = Axis(
            fig[2, 1];
            xlabel = x_label,
            ylabel = "L2 Error",
            yscale = log10,
            xgridvisible = true,
            ygridvisible = true,
            xgridstyle = :dash,
            ygridstyle = :dash,
            title = "Polynomial Approximation Error",
        )

        scatterlines!(
            ax3,
            l2_x,
            l2_vals;
            color = :darkorange,
            markersize = 8,
            linewidth = 2.5,
        )

        ax3.xticks = x_ticks
    end

    # Legend column auto-sizes to fit content via tellwidth (Makie default).
    # Plot column (Auto) fills remaining space.

    if save_path !== nothing
        save(save_path, fig; px_per_unit = 2)
    end

    return fig
end

# --- Function 2: plot_capture_sparsification_combined -------------------------

"""
    plot_capture_sparsification_combined(
        entries,
        known::KnownCriticalPoints;
        fig_size = (1400, 700),
        save_path = nothing,
    ) -> Figure

Two-panel side-by-side figure showing the sparsification speed vs accuracy tradeoff.

The x-axis uses support size (number of nonzero coefficients) from the Full variant
at each degree, so the axis reflects actual polynomial complexity. All spacing and
bar widths adapt automatically via `_adaptive_spacing`.

# Panel A (left) -- CP Accuracy: Distance to Known CPs
Stacked per-type subpanels with dodged boxplots for each support size x variant.
Log-y scale, tolerance reference lines. Shows how much CP accuracy degrades with
sparsification.

# Panel B (right) -- HC Solve Time
Grouped bar chart: x-axis = support size, bars dodged by variant. Y-axis = solve time (seconds).
Each sparsified bar is annotated with absolute time saved.
Shows how much faster the HC solve is with sparsification.

# Arguments
- `entries`: Vector of NamedTuples, each with fields:
  - `degree::Int` -- polynomial degree
  - `variant_label::String` -- "Full", "1e-5 (mild)", etc.
  - `threshold::Float64` -- sparsification threshold (0.0 for full polynomial)
  - `capture_result::CaptureResult` -- full capture analysis
  - `n_nonzero_coeffs::Int` -- number of non-zero coefficients
  - `l2_ratio::Float64` -- ratio of sparsified L2 norm to original (1.0 for full)
  - `solve_time::Float64` -- HC solve wall-clock time in seconds
- `known::KnownCriticalPoints`: Ground truth critical points.

# Keyword Arguments
- `fig_size`: Figure dimensions in pixels.
- `save_path`: Optional file path to save the figure.

# Returns
- `Figure`: CairoMakie figure object.
"""
function plot_capture_sparsification_combined(
    entries::Vector{<:NamedTuple},
    known::KnownCriticalPoints;
    fig_size::Tuple{Int,Int} = (1400, 700),
    save_path::Union{String,Nothing} = nothing,
)
    isempty(entries) && error("entries must be non-empty")

    degrees = sort(unique(e.degree for e in entries))
    n_degrees = length(degrees)

    # Extract variant labels in order of appearance (from first degree)
    first_deg = degrees[1]
    variant_labels = [e.variant_label for e in entries if e.degree == first_deg]
    n_variants = length(variant_labels)

    # Validate: every degree must have the same set of variants in the same order
    for deg in degrees
        deg_labels = [e.variant_label for e in entries if e.degree == deg]
        if deg_labels != variant_labels
            error("Degree $deg has variants $(deg_labels), expected $(variant_labels)")
        end
    end

    # Validate: all CaptureResults must use the same tolerance_fractions
    ref_cr = entries[1].capture_result
    ref_tol_fracs = ref_cr.tolerance_fractions
    for e in entries
        if e.capture_result.tolerance_fractions != ref_tol_fracs
            error(
                "All CaptureResults must use the same tolerance_fractions. " *
                "Entry (degree=$(e.degree), variant=$(e.variant_label)) has " *
                "$(e.capture_result.tolerance_fractions), expected $(ref_tol_fracs)",
            )
        end
    end

    # Build lookup: (degree, variant_label) -> entry
    entry_map = Dict((e.degree, e.variant_label) => e for e in entries)

    # X-axis: each entry has its own support size (n_nonzero_coeffs).
    # Sparsified variants have fewer nonzero coefficients than Full variants,
    # so each bar sits at its actual support size — showing the complexity reduction.
    # Use rank-based positioning so bars are uniformly spaced.
    all_support_sizes = sort(unique(e.n_nonzero_coeffs for e in entries))
    _, x_ticks, support_to_rank = _rank_positions(all_support_sizes)
    x_label = "Support Size (nonzero coefficients)"

    # Map each entry to its rank position
    entry_to_xpos = Dict(
        (e.degree, e.variant_label) => support_to_rank[e.n_nonzero_coeffs] for e in entries
    )

    # Spacing from rank positions (uniform: 1, 2, 3, ...)
    rank_positions = collect(1:length(all_support_sizes))
    spacing = _adaptive_spacing(rank_positions)

    # Collect unique CP types (sorted for consistent ordering)
    all_types = sort(unique(known.types))
    n_types = length(all_types)

    variant_colors = _variant_color_palette(n_variants)

    jitter_rng = MersenneTwister(42)

    # --- Figure layout: [Panel A (left) | Panel B (right)] --------------------
    # Panel A uses a sub-GridLayout with n_types rows for per-type distance subpanels.
    # Panel B is a single Axis for solve time bars.
    # A shared legend sits at the far right.

    fig = Figure(size = fig_size, fontsize = 13)

    # Main grid: [panelA_gl | panelB_ax | legend]
    panel_a_gl = fig[1, 1] = GridLayout()

    # --- Panel A: Distance to Known CPs (per-type subpanels) -------------------
    # Each variant sits at its own support size — no dodge grouping needed.

    box_width = spacing.fill_width * 0.9

    panel_a_axes = Axis[]

    for (ti, cp_type) in enumerate(all_types)
        is_first = ti == 1
        is_last = ti == n_types
        type_count = count(x -> x == cp_type, known.types)
        type_label = _CP_PLURAL_LABELS[cp_type]
        type_color = CP_TYPE_TABLE[cp_type].color

        ax = Axis(
            panel_a_gl[ti, 1];
            ylabel = "Distance to nearest CP",
            yscale = log10,
            xgridvisible = true,
            ygridvisible = true,
            xgridstyle = :dash,
            ygridstyle = :dash,
            title = is_first ? "CP Accuracy: Distance to Known Critical Points" : "",
            xlabel = is_last ? x_label : "",
            xticklabelsvisible = is_last,
            xticksvisible = is_last,
            xlabelvisible = is_last,
        )
        push!(panel_a_axes, ax)

        # Type annotation in top-right corner (avoids overlap with boxplots)
        text!(
            ax,
            Point2f(0.98, 0.95),
            text = "$type_label ($type_count)";
            fontsize = 11,
            color = type_color,
            align = (:right, :top),
            space = :relative,
            font = :bold,
        )

        # Indices of known CPs of this type
        type_idxs = findall(t -> t == cp_type, known.types)

        # Draw boxplots for each variant at its own support-size position
        for (vi, vlabel) in enumerate(variant_labels)
            vcolor = variant_colors[vi]

            for deg in degrees
                e = entry_map[(deg, vlabel)]
                xpos = Float64(entry_to_xpos[(deg, vlabel)])
                cr = e.capture_result

                positions = Float64[]
                values = Float64[]
                for ki in type_idxs
                    dist = cr.distances[ki]
                    isfinite(dist) || continue
                    clamped = max(dist, 1e-16)
                    push!(positions, xpos)
                    push!(values, clamped)
                end

                if !isempty(positions)
                    boxplot!(
                        ax,
                        positions,
                        values;
                        color = vcolor,
                        width = box_width,
                        whiskerwidth = 0.5,
                        show_outliers = false,
                        medianlinewidth = 2,
                    )

                    scatter_color = RGBAf(vcolor.r, vcolor.g, vcolor.b, 0.25f0)
                    jittered_x =
                        [p + spacing.jitter_scale * randn(jitter_rng) for p in positions]
                    scatter!(
                        ax,
                        jittered_x,
                        values;
                        color = scatter_color,
                        markersize = 2,
                        strokewidth = 0,
                    )
                end
            end
        end

        # Tolerance hlines
        tol_line_colors = [:gray70, :gray60, :gray50, :gray40]
        for (i, tf) in enumerate(ref_tol_fracs)
            tol_abs = tf * known.domain_diameter
            lc = i <= length(tol_line_colors) ? tol_line_colors[i] : :gray50
            hlines!(ax, [tol_abs]; linestyle = :dash, color = lc, linewidth = 0.8)
            if is_last
                text!(
                    ax,
                    @sprintf("%.1f%%", 100 * tf);
                    position = (
                        Float64(rank_positions[end]) + spacing.label_offset,
                        tol_abs,
                    ),
                    fontsize = 9,
                    color = lc,
                    align = (:left, :center),
                )
            end
        end

        ax.xticks = x_ticks
    end

    # Link x-axes across Panel A sub-panels
    if length(panel_a_axes) > 1
        for ax in panel_a_axes[2:end]
            linkxaxes!(panel_a_axes[1], ax)
        end
    end

    # --- Panel B: HC Solve Time ------------------------------------------------
    # Each bar at its own support size — no dodge. Wider bars, no overlap.

    bar_w = spacing.fill_width * 0.9

    ax_time = Axis(
        fig[1, 2];
        xlabel = x_label,
        ylabel = "HC Solve Time (s)",
        xgridvisible = false,
        ygridvisible = true,
        ygridstyle = :dash,
        title = "HC Solve Time: Full vs Sparsified",
    )

    # One bar per entry, at its own support-size position
    bar_positions = Float64[]
    bar_values = Float64[]
    bar_colors = []

    for e in entries
        variant_idx = findfirst(==(e.variant_label), variant_labels)
        push!(bar_positions, Float64(entry_to_xpos[(e.degree, e.variant_label)]))
        push!(bar_values, e.solve_time)
        push!(bar_colors, variant_colors[variant_idx])
    end

    barplot!(ax_time, bar_positions, bar_values; color = bar_colors, width = bar_w)

    ax_time.xticks = x_ticks

    # Helper: format time saved as a compact string
    _fmt_saved(dt) = dt >= 1.0 ? @sprintf("-%.1fs", dt) : @sprintf("-%.0fms", dt * 1000)

    # Annotations on sparsified bars: time saved vs Full at same degree
    for deg in degrees
        full_entry = entry_map[(deg, variant_labels[1])]
        full_time = full_entry.solve_time

        for (vi, vlabel) in enumerate(variant_labels)
            e = entry_map[(deg, vlabel)]
            if e.threshold > 0.0 && full_time > 0.0
                bar_x = Float64(entry_to_xpos[(deg, vlabel)])
                bar_top = e.solve_time
                time_saved = full_time - e.solve_time
                text!(
                    ax_time,
                    _fmt_saved(time_saved);
                    position = (bar_x, bar_top),
                    fontsize = 9,
                    align = (:center, :bottom),
                    color = :gray20,
                    font = :bold,
                )
            end
        end
    end

    # --- Shared Legend (with L2 range per variant) -----------------------------

    # Compute L2 ratio range per variant across all degrees
    legend_labels = String[]
    for (vi, vlabel) in enumerate(variant_labels)
        variant_entries = [entry_map[(deg, vlabel)] for deg in degrees]
        l2_ratios = [e.l2_ratio for e in variant_entries]
        if vi == 1  # Full variant (l2_ratio == 1.0)
            push!(legend_labels, vlabel)
        else
            l2_min = minimum(l2_ratios)
            l2_max = maximum(l2_ratios)
            push!(legend_labels, @sprintf("%s [L2: %.3f-%.3f]", vlabel, l2_min, l2_max))
        end
    end

    legend_elements = [
        PolyElement(;
            color = RGBAf(
                variant_colors[i].r,
                variant_colors[i].g,
                variant_colors[i].b,
                1.0f0,
            ),
        ) for i in 1:n_variants
    ]
    Legend(
        fig[1, 3],
        legend_elements,
        legend_labels;
        title = "Variant",
        _legend_kwargs()...,
    )

    # --- Layout sizing --------------------------------------------------------

    # Plot columns share space proportionally; legend column auto-sizes to content
    colsize!(fig.layout, 1, Auto(1.6))   # Panel A (distance boxplots) gets more space
    colsize!(fig.layout, 2, Auto(1.0))   # Panel B (solve time bars)
    # Column 3 (legend) uses Auto() default -- sizes to fit legend content via tellwidth

    if save_path !== nothing
        save(save_path, fig; px_per_unit = 2)
    end

    return fig
end

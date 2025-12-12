# subdivision_tree_viz.jl
# Publication-quality visualization for adaptive subdivision trees
# Uses GraphMakie + CairoMakie for hierarchical tree layout

using Graphs
using GraphMakie
using NetworkLayout
using GeometryBasics: Point, Point2f
using Makie: RGBf, RGBAf, poly!

#==============================================================================#
#                           DATA STRUCTURES                                     #
#==============================================================================#

"""
    SubdomainNodeInfo

Extracted information about a single subdomain node for visualization.
Uses duck typing to work with Globtim's SubdivisionTree without hard dependency.
"""
struct SubdomainNodeInfo
    id::Int
    is_leaf::Bool
    is_converged::Bool
    split_dim::Union{Int,Nothing}
    split_pos::Union{Float64,Nothing}
    l2_error::Float64
    depth::Int
    children::Union{Tuple{Int,Int},Nothing}
    parent_id::Union{Int,Nothing}
end

"""
    TreeVizStyle

Styling configuration for subdivision tree visualization.
"""
Base.@kwdef struct TreeVizStyle
    # Dimension colors - Dark2 palette (muted, professional)
    dim_colors::Vector = collect(ColorSchemes.Dark2_6)

    # Leaf node colors
    converged_color::RGBf = RGBf(0.18, 0.55, 0.34)  # Seagreen
    active_color::RGBf = RGBf(1.0, 0.55, 0.0)      # Darkorange (fallback when gradient off)

    # Error-based coloring for active leaves
    use_error_gradient::Bool = true

    # Depth bands (alternating stripes)
    show_depth_bands::Bool = true
    depth_band_color::RGBAf = RGBAf(0.9, 0.9, 0.9, 0.3)

    # Node stroke (outline)
    node_strokewidth::Float64 = 1.5
    node_strokecolor::Symbol = :black

    # Node sizes (base values, scaled by auto_scale)
    split_node_size::Float64 = 20.0
    leaf_node_size::Float64 = 25.0

    # Edge styling
    edge_width::Float64 = 2.0

    # Figure size (used when auto_fig_size=false)
    fig_size::Tuple{Int,Int} = (1200, 800)

    # Label options
    show_split_info::Bool = true
    show_error_values::Bool = true
    show_error_reduction::Bool = true

    # Font sizes (base values, scaled by auto_scale)
    label_fontsize::Int = 10
    title_fontsize::Int = 16

    # Layout scaling (for BalancedTreeLayout)
    horizontal_scale::Float64 = 10.0   # Multiply x coords by this to spread tree horizontally
    vertical_spacing::Float64 = 1.5    # Vertical space between tree levels

    # === Auto-scaling options (for large trees) ===
    auto_scale::Bool = true            # Enable automatic scaling for large trees
    min_node_size::Float64 = 8.0       # Minimum node size after scaling
    max_node_size::Float64 = 30.0      # Maximum node size
    min_fontsize::Int = 6              # Minimum font size after scaling

    # Label control
    label_max_chars::Int = 15          # Truncate labels longer than this

    # Auto figure sizing
    auto_fig_size::Bool = true         # Automatically size figure based on tree
end

#==============================================================================#
#                           TREE EXTRACTION                                     #
#==============================================================================#

"""
    extract_tree_data(tree) -> (Vector{SubdomainNodeInfo}, Set{Int}, Set{Int}, Int)

Extract node information from a SubdivisionTree using duck typing.
Returns node info vector, converged leaf IDs, active leaf IDs, and root_id.
"""
function extract_tree_data(tree)
    converged_set = Set(tree.converged_leaves)
    active_set = Set(tree.active_leaves)

    nodes = SubdomainNodeInfo[]
    for (id, sd) in enumerate(tree.subdomains)
        is_leaf = sd.children === nothing
        is_converged = id in converged_set

        push!(nodes, SubdomainNodeInfo(
            id,
            is_leaf,
            is_converged,
            sd.split_dim,
            sd.split_pos,
            sd.l2_error,
            sd.depth,
            sd.children,
            sd.parent_id
        ))
    end

    return nodes, converged_set, active_set, tree.root_id
end

#==============================================================================#
#                           GRAPH CONVERSION                                    #
#==============================================================================#

"""
    tree_to_graph(nodes::Vector{SubdomainNodeInfo}) -> SimpleDiGraph

Convert extracted node info to Graphs.jl SimpleDiGraph.
"""
function tree_to_graph(nodes::Vector{SubdomainNodeInfo})
    n = length(nodes)
    graph = SimpleDiGraph(n)

    for node in nodes
        if node.children !== nothing
            left_id, right_id = node.children
            add_edge!(graph, node.id, left_id)
            add_edge!(graph, node.id, right_id)
        end
    end

    return graph
end

#==============================================================================#
#                           CUSTOM LAYOUT                                       #
#==============================================================================#

"""
    balanced_tree_layout(nodes::Vector{SubdomainNodeInfo}, root_id::Int; h_scale=10.0, v_spacing=1.5)

Custom tree layout where horizontal child positions reflect split positions.

Split position p ∈ [-1,1] maps to:
- Left child: positioned at relative offset -(1-p)/2  (closer to parent if split right)
- Right child: positioned at relative offset +(1+p)/2 (closer to parent if split left)

This visually shows WHERE in the domain each split occurred.

# Arguments
- `h_scale`: Horizontal scaling factor (default 10.0) - spreads tree horizontally
- `v_spacing`: Vertical spacing between levels (default 1.5)
"""
function balanced_tree_layout(nodes::Vector{SubdomainNodeInfo}, root_id::Int;
                              h_scale::Float64=10.0, v_spacing::Float64=1.5)
    n = length(nodes)
    positions = Vector{Point{2,Float64}}(undef, n)

    # DFS to compute positions
    # Each node gets an x-range [x_min, x_max] that it can use
    function layout_subtree!(node_id::Int, x_min::Float64, x_max::Float64, y::Float64)
        node = nodes[node_id]
        x_center = (x_min + x_max) / 2
        # Apply scaling: h_scale spreads horizontally, v_spacing controls level separation
        positions[node_id] = Point(x_center * h_scale, -y * v_spacing)

        if node.children !== nothing
            left_id, right_id = node.children

            # Get split position (default to 0 if not available)
            split_pos = node.split_pos === nothing ? 0.0 : node.split_pos

            # Convert split position [-1,1] to fraction [0,1]
            # split_pos = -1: split at left edge → left gets 0%, right gets 100%
            # split_pos = 0: split at center → 50/50
            # split_pos = +1: split at right edge → left gets 100%, right gets 0%
            split_frac = (split_pos + 1) / 2  # Now in [0,1]

            # Width allocation: left gets split_frac, right gets 1-split_frac
            width = x_max - x_min
            x_split = x_min + width * split_frac

            # Recurse to children
            layout_subtree!(left_id, x_min, x_split, y + 1)
            layout_subtree!(right_id, x_split, x_max, y + 1)
        end
    end

    # Start layout from root
    layout_subtree!(root_id, 0.0, 1.0, 0.0)

    return positions
end

"""
    BalancedTreeLayout

Custom layout type for GraphMakie that uses split positions to determine child placement.
Supports configurable horizontal scaling and vertical spacing.
"""
struct BalancedTreeLayout
    nodes::Vector{SubdomainNodeInfo}
    root_id::Int
    h_scale::Float64
    v_spacing::Float64
end

# Constructor with default scaling from TreeVizStyle defaults
BalancedTreeLayout(nodes::Vector{SubdomainNodeInfo}, root_id::Int) =
    BalancedTreeLayout(nodes, root_id, 10.0, 1.5)

# Make it callable for GraphMakie
function (layout::BalancedTreeLayout)(graph)
    return balanced_tree_layout(layout.nodes, layout.root_id;
                                h_scale=layout.h_scale, v_spacing=layout.v_spacing)
end

#==============================================================================#
#                           AUTO-SCALING                                        #
#==============================================================================#

"""
    compute_auto_scale(nodes::Vector{SubdomainNodeInfo}, style::TreeVizStyle) -> NamedTuple

Compute scaling factors for nodes, fonts, and layout based on tree size.
Returns named tuple with scaled values ready to use.
"""
function compute_auto_scale(nodes::Vector{SubdomainNodeInfo}, style::TreeVizStyle)
    n_nodes = length(nodes)
    n_leaves = count(n -> n.is_leaf, nodes)
    max_depth = maximum(n.depth for n in nodes)

    if !style.auto_scale || n_nodes <= 10
        # No scaling needed for small trees
        return (
            node_scale = 1.0,
            font_scale = 1.0,
            h_scale = style.horizontal_scale,
            split_node_size = style.split_node_size,
            leaf_node_size = style.leaf_node_size,
            label_fontsize = style.label_fontsize,
            edge_width = style.edge_width
        )
    end

    # Scale down for larger trees: factor decreases with log of node count
    # n=10 → 1.0, n=50 → 0.53, n=100 → 0.45, n=200 → 0.39
    node_scale = clamp(3.0 / log2(n_nodes + 2), 0.3, 1.0)
    font_scale = clamp(4.0 / log2(n_nodes + 2), 0.5, 1.0)

    # Increase horizontal spread for trees with many leaves
    h_scale = if n_leaves > 10
        style.horizontal_scale * (1.0 + 0.5 * log2(n_leaves / 10))
    else
        style.horizontal_scale
    end

    # Compute actual sizes with clamping
    split_size = clamp(style.split_node_size * node_scale,
                       style.min_node_size, style.max_node_size)
    leaf_size = clamp(style.leaf_node_size * node_scale,
                      style.min_node_size, style.max_node_size)
    fontsize = max(style.min_fontsize, round(Int, style.label_fontsize * font_scale))
    edge_w = max(1.0, style.edge_width * node_scale)

    return (
        node_scale = node_scale,
        font_scale = font_scale,
        h_scale = h_scale,
        split_node_size = split_size,
        leaf_node_size = leaf_size,
        label_fontsize = fontsize,
        edge_width = edge_w
    )
end

"""
    compute_figure_size(nodes::Vector{SubdomainNodeInfo}, style::TreeVizStyle) -> Tuple{Int,Int}

Calculate optimal figure size based on tree structure.
"""
function compute_figure_size(nodes::Vector{SubdomainNodeInfo}, style::TreeVizStyle)
    if !style.auto_fig_size
        return style.fig_size
    end

    n_leaves = count(n -> n.is_leaf, nodes)
    max_depth = maximum(n.depth for n in nodes)

    # Width based on number of leaves (60px per leaf, clamped)
    width = clamp(n_leaves * 60 + 200, 600, 2400)

    # Height based on depth (100px per level + margins)
    height = clamp((max_depth + 1) * 100 + 250, 400, 1400)

    return (round(Int, width), round(Int, height))
end

#==============================================================================#
#                           STYLING FUNCTIONS                                   #
#==============================================================================#

"""
    compute_error_range(nodes::Vector{SubdomainNodeInfo}) -> Tuple{Float64,Float64}

Compute min/max error range for active leaves (used for error gradient coloring).
"""
function compute_error_range(nodes::Vector{SubdomainNodeInfo})
    errors = [n.l2_error for n in nodes if n.is_leaf && !n.is_converged && isfinite(n.l2_error)]
    if isempty(errors)
        return (1e-10, 1.0)  # fallback
    end
    return (minimum(errors), maximum(errors))
end

"""
    get_dim_color(dim::Int, style::TreeVizStyle)

Get color for a dimension, cycling through available colors.
"""
function get_dim_color(dim::Int, style::TreeVizStyle)
    return style.dim_colors[mod1(dim, length(style.dim_colors))]
end

"""
    get_node_color(node::SubdomainNodeInfo, style::TreeVizStyle, error_range::Tuple{Float64,Float64})

Determine node color based on node type, with error gradient for active leaves.
"""
function get_node_color(node::SubdomainNodeInfo, style::TreeVizStyle,
                        error_range::Tuple{Float64,Float64}=(1e-10, 1.0))
    if node.is_leaf
        if node.is_converged
            return style.converged_color
        elseif style.use_error_gradient && isfinite(node.l2_error)
            # Map error to color: low error = green, high error = red
            min_err, max_err = error_range
            if max_err > min_err
                # Use log scale for better visual spread
                t = (log10(node.l2_error) - log10(min_err)) / (log10(max_err) - log10(min_err))
                return get(ColorSchemes.RdYlGn, 1 - clamp(t, 0, 1))  # Reversed: 1=green, 0=red
            end
            return get(ColorSchemes.RdYlGn, 0.5)  # Middle color
        else
            return style.active_color
        end
    else
        # Internal node: color by split dimension
        return get_dim_color(node.split_dim, style)
    end
end

"""
    get_node_marker(node::SubdomainNodeInfo) -> Symbol

Determine node marker shape based on node type.
"""
function get_node_marker(node::SubdomainNodeInfo)
    if node.is_leaf
        return node.is_converged ? :star5 : :circle
    else
        return :rect
    end
end

"""
    get_node_size(node::SubdomainNodeInfo, style::TreeVizStyle) -> Float64

Get node size based on type.
"""
function get_node_size(node::SubdomainNodeInfo, style::TreeVizStyle)
    return node.is_leaf ? style.leaf_node_size : style.split_node_size
end

"""
    split_position_label(split_pos::Float64, width::Int=10) -> String

Create ASCII split position visualization: [----|---------]
"""
function split_position_label(split_pos::Float64, width::Int=10)
    pos = round(Int, (split_pos + 1) / 2 * (width - 1))
    pos = clamp(pos, 0, width - 1)
    return "[" * "-"^pos * "|" * "-"^(width - 1 - pos) * "]"
end

"""
    compute_error_reduction(nodes, node::SubdomainNodeInfo) -> Union{Float64,Nothing}

Compute percentage error reduction from this node to its children.
Returns Nothing for leaf nodes or if children have Inf error.
"""
function compute_error_reduction(nodes::Vector{SubdomainNodeInfo}, node::SubdomainNodeInfo)
    node.children === nothing && return nothing

    left_id, right_id = node.children
    left_err = nodes[left_id].l2_error
    right_err = nodes[right_id].l2_error

    # Skip if any error is Inf or parent error is zero
    (!isfinite(left_err) || !isfinite(right_err)) && return nothing
    (node.l2_error <= 0 || !isfinite(node.l2_error)) && return nothing

    children_total = left_err + right_err
    return (node.l2_error - children_total) / node.l2_error * 100
end

"""
    format_node_label(node::SubdomainNodeInfo, nodes::Vector{SubdomainNodeInfo}, style::TreeVizStyle; balanced_layout::Bool=true) -> String

Format node label for display.
When balanced_layout is true, split position is encoded in edge lengths so we skip the ASCII viz.
Labels are truncated to style.label_max_chars.
"""
function format_node_label(node::SubdomainNodeInfo, nodes::Vector{SubdomainNodeInfo}, style::TreeVizStyle; balanced_layout::Bool=true)
    label = if node.is_leaf
        if style.show_error_values && isfinite(node.l2_error)
            string(round(node.l2_error, sigdigits=2))
        else
            ""
        end
    else
        # Internal node: show dimension
        parts = ["x$(node.split_dim)"]

        # Only show ASCII split position if NOT using balanced layout (since layout encodes it)
        if !balanced_layout && style.show_split_info && node.split_pos !== nothing
            push!(parts, split_position_label(node.split_pos))
        end

        if style.show_error_reduction
            reduction = compute_error_reduction(nodes, node)
            if reduction !== nothing
                if reduction >= 0
                    push!(parts, "$(round(Int, reduction))%↓")
                else
                    push!(parts, "$(round(Int, -reduction))%↑")
                end
            end
        end

        join(parts, " ")
    end

    # Truncate long labels
    if length(label) > style.label_max_chars
        return label[1:style.label_max_chars-1] * "…"
    end
    return label
end

#==============================================================================#
#                           DEPTH BANDS                                         #
#==============================================================================#

"""
    draw_depth_bands!(ax, nodes, positions, style)

Draw alternating horizontal bands at each tree depth for visual hierarchy.
"""
function draw_depth_bands!(ax, nodes::Vector{SubdomainNodeInfo},
                           positions::Vector{Point{2,Float64}}, style::TreeVizStyle)
    !style.show_depth_bands && return

    max_depth = maximum(n.depth for n in nodes)

    # Get x-range from positions
    xs = [p[1] for p in positions]
    x_min, x_max = minimum(xs) - 2, maximum(xs) + 2

    # Get y-values per depth
    y_by_depth = Dict{Int, Float64}()
    for (i, n) in enumerate(nodes)
        y_by_depth[n.depth] = positions[i][2]
    end

    # Draw alternating bands at even depths
    for d in 0:max_depth
        d % 2 == 1 && continue  # Only even depths
        haskey(y_by_depth, d) || continue

        y = y_by_depth[d]
        band_height = style.vertical_spacing * 0.45

        poly!(ax,
            Point2f[(x_min, y - band_height), (x_max, y - band_height),
                    (x_max, y + band_height), (x_min, y + band_height)],
            color = style.depth_band_color
        )
    end
end

#==============================================================================#
#                           MAIN PLOTTING FUNCTION                              #
#==============================================================================#

"""
    plot_subdivision_tree(tree; kwargs...) -> Figure

Create publication-quality visualization of a subdivision tree.

# Arguments
- `tree`: SubdivisionTree from Globtim (uses duck typing)

# Keyword Arguments
- `style::TreeVizStyle = TreeVizStyle()`: Visual styling configuration
- `title::String = ""`: Optional figure title
- `show_legend::Bool = true`: Whether to show dimension color legend
- `balanced_layout::Bool = true`: Use split-position-aware layout (recommended)

# Returns
- `Figure`: CairoMakie Figure object suitable for saving as PDF/SVG

# Notes
- Auto-scaling is enabled by default: node sizes, fonts, and figure dimensions
  adapt to tree size for optimal readability.
- Set `style=TreeVizStyle(auto_scale=false, auto_fig_size=false)` for fixed sizing.

# Example
```julia
using Globtim, GlobtimPlots

tree = adaptive_refine(f, bounds, 4, l2_tolerance=1e-3)
fig = plot_subdivision_tree(tree)
save("tree.pdf", fig)
```
"""
function plot_subdivision_tree(
    tree;
    style::TreeVizStyle = TreeVizStyle(),
    title::String = "",
    show_legend::Bool = true,
    balanced_layout::Bool = true
)
    # Extract tree data
    nodes, _, _, root_id = extract_tree_data(tree)

    # Compute auto-scaling based on tree size
    scale = compute_auto_scale(nodes, style)

    # Compute figure size
    fig_size = compute_figure_size(nodes, style)

    # Convert to graph
    graph = tree_to_graph(nodes)

    # Compute error range for gradient coloring
    error_range = compute_error_range(nodes)

    # Prepare node attributes with scaled sizes (now with error gradient)
    node_colors = [get_node_color(n, style, error_range) for n in nodes]
    node_sizes = [n.is_leaf ? scale.leaf_node_size : scale.split_node_size for n in nodes]
    node_markers = [get_node_marker(n) for n in nodes]
    node_labels = [format_node_label(n, nodes, style; balanced_layout=balanced_layout) for n in nodes]

    # Prepare edge colors (colored by parent's split dimension)
    edge_colors = []
    for e in edges(graph)
        parent_node = nodes[src(e)]
        if parent_node.split_dim !== nothing
            push!(edge_colors, get_dim_color(parent_node.split_dim, style))
        else
            push!(edge_colors, :gray)
        end
    end

    # Create figure with computed size
    fig = Figure(size=fig_size)

    # Main axis for tree
    ax = Axis(fig[1, 1],
        title = isempty(title) ? "Subdivision Tree" : title,
        titlesize = style.title_fontsize,
        aspect = DataAspect()
    )
    hidedecorations!(ax)
    hidespines!(ax)

    # Choose layout: balanced (split-aware) or standard Buchheim
    layout_obj = balanced_layout ?
        BalancedTreeLayout(nodes, root_id, scale.h_scale, style.vertical_spacing) :
        Buchheim()

    # Precompute positions for depth bands
    positions = layout_obj(graph)

    # Draw depth bands BEFORE the graph (so they render behind)
    draw_depth_bands!(ax, nodes, positions, style)

    # Plot the graph with scaled attributes and node strokes
    graphplot!(ax, graph,
        layout = _ -> positions,  # Use precomputed positions
        node_color = node_colors,
        node_size = node_sizes,
        node_marker = node_markers,
        node_strokewidth = style.node_strokewidth,
        node_strokecolor = style.node_strokecolor,
        edge_color = edge_colors,
        edge_width = scale.edge_width,
        nlabels = node_labels,
        nlabels_distance = max(8, round(Int, 12 * scale.font_scale)),
        nlabels_fontsize = scale.label_fontsize,
        arrow_show = false
    )

    # Add legend if requested
    if show_legend
        _create_tree_legend!(fig, nodes, style, error_range)
    end

    return fig
end

"""
    _create_tree_legend!(fig, nodes, style, error_range)

Add legend to the figure showing dimension colors, leaf status, and error colorbar.
"""
function _create_tree_legend!(fig, nodes::Vector{SubdomainNodeInfo}, style::TreeVizStyle,
                              error_range::Tuple{Float64,Float64})
    # Determine dimensions used
    dims_used = Set{Int}()
    for n in nodes
        if n.split_dim !== nothing
            push!(dims_used, n.split_dim)
        end
    end

    if isempty(dims_used)
        return
    end

    # Create legend entries
    legend_entries = []
    legend_labels = String[]

    # Dimension entries
    for d in sort(collect(dims_used))
        color = get_dim_color(d, style)
        push!(legend_entries, MarkerElement(color=color, marker=:rect, markersize=15))
        push!(legend_labels, "x$d split")
    end

    # Leaf status entries
    push!(legend_entries, MarkerElement(color=style.converged_color, marker=:star5, markersize=15))
    push!(legend_labels, "Converged")

    # For active leaves: show gradient info or single color
    if style.use_error_gradient
        # Show low/high error markers
        push!(legend_entries, MarkerElement(color=get(ColorSchemes.RdYlGn, 1.0), marker=:circle, markersize=15))
        push!(legend_labels, "Low error")
        push!(legend_entries, MarkerElement(color=get(ColorSchemes.RdYlGn, 0.0), marker=:circle, markersize=15))
        push!(legend_labels, "High error")
    else
        push!(legend_entries, MarkerElement(color=style.active_color, marker=:circle, markersize=15))
        push!(legend_labels, "Active")
    end

    # Add legend to figure
    Legend(fig[1, 2], legend_entries, legend_labels,
        framevisible = true,
        backgroundcolor = (:white, 0.9),
        padding = (10, 10, 10, 10)
    )

    # Adjust column sizes
    colsize!(fig.layout, 1, Relative(0.85))
    colsize!(fig.layout, 2, Relative(0.15))
end

#==============================================================================#
#                           SUMMARY STATISTICS                                  #
#==============================================================================#

"""
    print_tree_summary(tree; io=stdout)

Print summary statistics for a subdivision tree.
"""
function print_tree_summary(tree; io=stdout)
    nodes, converged_set, active_set, _ = extract_tree_data(tree)

    n_total = length(converged_set) + length(active_set)
    n_conv = length(converged_set)
    n_act = length(active_set)
    max_depth = maximum(n.depth for n in nodes)

    # Count splits per dimension
    split_counts = Dict{Int,Int}()
    for n in nodes
        if n.split_dim !== nothing
            split_counts[n.split_dim] = get(split_counts, n.split_dim, 0) + 1
        end
    end

    # Compute total error
    total_err = 0.0
    for n in nodes
        if n.is_leaf && isfinite(n.l2_error)
            total_err += n.l2_error
        end
    end

    println(io, "Subdivision Tree Summary")
    println(io, "=" ^ 40)
    println(io, "Leaves: $n_total ($n_conv converged, $n_act active)")
    println(io, "Max depth: $max_depth")

    if !isempty(split_counts)
        dims_str = join(["x$d=$(split_counts[d])" for d in sort(collect(keys(split_counts)))], " ")
        println(io, "Splits: $dims_str")
    end

    println(io, "Total L2 error: $(round(total_err, sigdigits=4))")
end

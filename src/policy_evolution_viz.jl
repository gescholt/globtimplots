"""
Policy Evolution Visualization for GlobTimRL

Visualizations to understand how the RL policy evolves during training:
- When does it choose SUBDIVIDE vs INCREASE_DEGREE?
- How does this decision-making change across episodes?
- What state features drive these decisions?
"""

using CairoMakie
using Statistics

"""
    plot_action_ratio_evolution(run; resolution=(1000, 600))

Plot the ratio of SUBDIVIDE to INCREASE_DEGREE actions across episodes.
Shows whether agent learns to prefer subdivision or degree increases.
"""
function plot_action_ratio_evolution(run; resolution=(1000, 600))
    episodes = run.episodes
    n_episodes = length(episodes)

    # Extract subdivision and degree increase counts per episode
    ep_nums = [ep.episode for ep in episodes]
    subdivide_counts = [get(ep.actions, "SUBDIVIDE", 0) for ep in episodes]
    degree_counts = [get(ep.actions, "INCREASE_DEGREE", 0) for ep in episodes]

    # Compute ratio (with smoothing to avoid division by zero)
    ratios = [(s + 1) / (d + 1) for (s, d) in zip(subdivide_counts, degree_counts)]

    # Compute moving average for trend
    window = min(5, div(n_episodes, 2))
    if window > 0 && n_episodes > window
        smoothed = [mean(ratios[max(1, i-window):min(n_episodes, i+window)]) for i in 1:n_episodes]
    else
        smoothed = ratios
    end

    fig = Figure(resolution=resolution)

    strategy_name = episodes[1].strategy_name
    func_name = episodes[1].function_name
    Label(fig[0, :], text="Action Ratio Evolution: $strategy_name on $func_name",
          fontsize=20, font=:bold)

    # Main plot: ratio over time
    ax = Axis(fig[1, 1],
              xlabel="Episode",
              ylabel="SUBDIVIDE / INCREASE_DEGREE Ratio",
              title="Policy Decision Making")

    # Reference line at ratio = 1 (equal preference)
    hlines!(ax, [1.0], color=:gray, linestyle=:dash, linewidth=1)

    # Plot ratios
    scatter!(ax, ep_nums, ratios, color=:steelblue, markersize=8,
             alpha=0.5, label="Raw ratio")

    if n_episodes > window
        lines!(ax, ep_nums, smoothed, color=:red, linewidth=3,
               label="Smoothed (window=$window)")
    end

    axislegend(ax, position=:rt)

    # Annotation for interpretation
    Label(fig[2, 1],
          text="Ratio > 1: Prefers subdivision | Ratio < 1: Prefers degree increase",
          fontsize=12, halign=:center)

    return fig
end

"""
    plot_action_stacked_area(run; resolution=(1000, 600))

Stacked area plot showing the proportion of different actions across episodes.
"""
function plot_action_stacked_area(run; resolution=(1000, 600))
    episodes = run.episodes
    n_episodes = length(episodes)

    # Get all unique actions
    all_actions = Set{String}()
    for ep in episodes
        union!(all_actions, keys(ep.actions))
    end
    action_names = sort(collect(all_actions))
    n_actions = length(action_names)

    # Build action count matrix
    action_matrix = zeros(Int, n_episodes, n_actions)
    for (i, ep) in enumerate(episodes)
        for (j, action) in enumerate(action_names)
            action_matrix[i, j] = get(ep.actions, action, 0)
        end
    end

    # Normalize to proportions per episode
    row_sums = sum(action_matrix, dims=2)
    proportions = action_matrix ./ max.(row_sums, 1)  # Avoid division by zero

    ep_nums = 1:n_episodes

    fig = Figure(resolution=resolution)

    strategy_name = episodes[1].strategy_name
    func_name = episodes[1].function_name
    Label(fig[0, :], text="Action Distribution Evolution: $strategy_name on $func_name",
          fontsize=20, font=:bold)

    ax = Axis(fig[1, 1],
              xlabel="Episode",
              ylabel="Action Proportion",
              title="How does action distribution change?")

    # Create stacked area chart
    colors = Makie.wong_colors()
    cumulative = zeros(n_episodes)

    for (i, action) in enumerate(action_names)
        color = colors[(i-1) % length(colors) + 1]

        upper = cumulative .+ proportions[:, i]

        band!(ax, ep_nums, cumulative, upper,
              color=(color, 0.6), label=action)

        cumulative = upper
    end

    axislegend(ax, position=:rt)

    return fig
end

"""
    plot_state_action_heatmap(state_action_pairs; resolution=(1200, 800))

Heatmap showing which actions are taken in which states.
Requires state-action pair tracking during training.

# Arguments
- `state_action_pairs`: Vector of (state, action) tuples collected during episodes
  where state = [width, center, l2_error, degree, cond]
"""
function plot_state_action_heatmap(state_action_pairs; resolution=(1200, 800))
    if isempty(state_action_pairs)
        error("No state-action pairs provided")
    end

    # Extract states and actions
    states = [sa[1] for sa in state_action_pairs]
    actions = [sa[2] for sa in state_action_pairs]

    # State features: [width, center, l2_error, degree, cond]
    l2_errors = [s[3] for s in states]
    degrees = [Int(s[4]) for s in states]

    # Define bins for L2 error (log scale) and degree
    l2_bins = 10 .^ range(log10(minimum(l2_errors) + 1e-10),
                          log10(maximum(l2_errors) + 1e-10),
                          length=10)
    degree_bins = minimum(degrees):maximum(degrees)

    # Count actions in each (l2, degree) bin
    subdivide_counts = zeros(Int, length(l2_bins)-1, length(degree_bins))
    degree_counts = zeros(Int, length(l2_bins)-1, length(degree_bins))

    for (state, action) in state_action_pairs
        l2 = state[3]
        deg = Int(state[4])

        # Find bins
        l2_idx = searchsortedlast(l2_bins, l2)
        l2_idx = clamp(l2_idx, 1, length(l2_bins)-1)

        deg_idx = findfirst(==(deg), degree_bins)
        if isnothing(deg_idx)
            continue
        end

        if action == "SUBDIVIDE"
            subdivide_counts[l2_idx, deg_idx] += 1
        elseif action == "INCREASE_DEGREE"
            degree_counts[l2_idx, deg_idx] += 1
        end
    end

    # Compute action preference: positive = subdivide, negative = degree increase
    total_counts = subdivide_counts .+ degree_counts
    preference = (subdivide_counts .- degree_counts) ./ max.(total_counts, 1)

    fig = Figure(resolution=resolution)

    Label(fig[0, :], text="Policy State-Action Map: SUBDIVIDE vs INCREASE_DEGREE",
          fontsize=20, font=:bold)

    # Heatmap
    ax = Axis(fig[1, 1],
              xlabel="Polynomial Degree",
              ylabel="L2 Error",
              yscale=log10,
              title="Decision Boundaries")

    hm = heatmap!(ax,
                  collect(degree_bins),
                  l2_bins[1:end-1],
                  preference,
                  colormap=:RdBu,
                  colorrange=(-1, 1))

    Colorbar(fig[1, 2], hm,
             label="Preference",
             ticks=([-1, 0, 1], ["Degree ↑", "Neutral", "Subdivide"]))

    # Add text annotations for interpretation
    Label(fig[2, :],
          text="Red = Agent prefers SUBDIVIDE | Blue = Agent prefers INCREASE_DEGREE",
          fontsize=12, halign=:center)

    return fig
end

"""
    plot_policy_evolution_comparison(runs::Vector; resolution=(1400, 1000))

Compare how different strategies evolve their action preferences across training.
"""
function plot_policy_evolution_comparison(runs::Vector; resolution=(1400, 1000))
    if isempty(runs)
        error("No runs to compare")
    end

    n_strategies = length(runs)
    strategy_names = [run.episodes[1].strategy_name for run in runs]
    colors = Makie.wong_colors()

    fig = Figure(resolution=resolution)

    func_name = runs[1].episodes[1].function_name
    Label(fig[0, :], text="Policy Evolution Comparison on $func_name",
          fontsize=22, font=:bold)

    # Row 1: Subdivision ratio evolution
    ax_ratio = Axis(fig[1, 1],
                    xlabel="Episode",
                    ylabel="SUBDIVIDE / INCREASE_DEGREE",
                    title="Action Preference Evolution")

    hlines!(ax_ratio, [1.0], color=:gray, linestyle=:dash, linewidth=1)

    for (i, run) in enumerate(runs)
        episodes = run.episodes
        ep_nums = [ep.episode for ep in episodes]

        subdivide_counts = [get(ep.actions, "SUBDIVIDE", 0) for ep in episodes]
        degree_counts = [get(ep.actions, "INCREASE_DEGREE", 0) for ep in episodes]
        ratios = [(s + 1) / (d + 1) for (s, d) in zip(subdivide_counts, degree_counts)]

        color = colors[(i-1) % length(colors) + 1]
        lines!(ax_ratio, ep_nums, ratios, color=color, linewidth=2,
               label=strategy_names[i])
    end

    axislegend(ax_ratio, position=:rt)

    # Row 2: Action counts over time
    ax_actions = Axis(fig[2, 1],
                      xlabel="Episode",
                      ylabel="Action Count",
                      title="Raw Action Frequencies")

    for (i, run) in enumerate(runs)
        episodes = run.episodes
        ep_nums = [ep.episode for ep in episodes]

        subdivide_counts = [get(ep.actions, "SUBDIVIDE", 0) for ep in episodes]
        degree_counts = [get(ep.actions, "INCREASE_DEGREE", 0) for ep in episodes]

        color = colors[(i-1) % length(colors) + 1]

        # Plot both action types with different line styles
        lines!(ax_actions, ep_nums, subdivide_counts,
               color=color, linewidth=2, linestyle=:solid,
               label="$(strategy_names[i]) - SUBDIVIDE")
        lines!(ax_actions, ep_nums, degree_counts,
               color=color, linewidth=2, linestyle=:dash,
               label="$(strategy_names[i]) - DEGREE")
    end

    axislegend(ax_actions, position=:rt)

    # Row 3: Summary statistics
    if all(run -> !isnothing(run.aggregate), runs)
        ax_summary = Axis(fig[3, 1],
                          xlabel="Strategy",
                          ylabel="Mean Action Count",
                          title="Average Action Distribution per Episode")

        x_pos = 1:n_strategies
        width = 0.35

        mean_subdivide = [mean([get(ep.actions, "SUBDIVIDE", 0) for ep in run.episodes])
                          for run in runs]
        mean_degree = [mean([get(ep.actions, "INCREASE_DEGREE", 0) for ep in run.episodes])
                       for run in runs]

        barplot!(ax_summary, x_pos .- width/2, mean_subdivide,
                width=width, color=colors[1], label="SUBDIVIDE")
        barplot!(ax_summary, x_pos .+ width/2, mean_degree,
                width=width, color=colors[2], label="INCREASE_DEGREE")

        ax_summary.xticks = (x_pos, strategy_names)
        axislegend(ax_summary, position=:rt)
    end

    return fig
end

"""
    plot_episode_decision_timeline(episode_metrics, state_action_history; resolution=(1200, 600))

Plot the sequence of decisions made during a single episode.
Shows when SUBDIVIDE vs INCREASE_DEGREE was chosen and in what state.

# Arguments
- `episode_metrics`: Metrics for the episode (any object with episode info)
- `state_action_history`: Vector of (step, state, action) tuples from the episode
"""
function plot_episode_decision_timeline(episode_metrics,
                                       state_action_history;
                                       resolution=(1200, 600))
    if isempty(state_action_history)
        error("No state-action history provided")
    end

    steps = [sa[1] for sa in state_action_history]
    states = [sa[2] for sa in state_action_history]
    actions = [sa[3] for sa in state_action_history]

    # Extract state features
    l2_errors = [s[3] for s in states]
    degrees = [Int(s[4]) for s in states]

    fig = Figure(resolution=resolution)

    strategy = episode_metrics.strategy_name
    func = episode_metrics.function_name
    ep_num = episode_metrics.episode

    Label(fig[0, :],
          text="Episode $ep_num Decision Timeline: $strategy on $func",
          fontsize=20, font=:bold)

    # Top panel: L2 error evolution
    ax_l2 = Axis(fig[1, 1],
                 ylabel="L2 Error",
                 yscale=log10,
                 title="Approximation Quality")

    lines!(ax_l2, steps, l2_errors, color=:blue, linewidth=2)
    scatter!(ax_l2, steps, l2_errors, color=:blue, markersize=8)

    # Middle panel: Degree evolution
    ax_degree = Axis(fig[2, 1],
                     ylabel="Polynomial Degree",
                     title="Approximation Complexity")

    lines!(ax_degree, steps, degrees, color=:green, linewidth=2)
    scatter!(ax_degree, steps, degrees, color=:green, markersize=8)

    # Bottom panel: Actions taken
    ax_actions = Axis(fig[3, 1],
                      xlabel="Step",
                      ylabel="Action",
                      title="Decisions Made",
                      yticks=(1:4, ["SUBDIVIDE", "INCREASE_DEGREE", "COMPUTE_MINIMA", "DONE"]))

    # Map actions to integers for plotting
    action_map = Dict(
        "SUBDIVIDE" => 1,
        "INCREASE_DEGREE" => 2,
        "COMPUTE_MINIMA" => 3,
        "DONE" => 4
    )
    action_ints = [get(action_map, a, 0) for a in actions]

    # Color code by action type
    colors_actions = [
        a == "SUBDIVIDE" ? :red :
        a == "INCREASE_DEGREE" ? :blue :
        a == "COMPUTE_MINIMA" ? :green :
        :gray
        for a in actions
    ]

    scatter!(ax_actions, steps, action_ints,
             color=colors_actions, markersize=12)

    # Connect with vertical lines to show sequence
    for i in 1:length(steps)-1
        lines!(ax_actions, [steps[i], steps[i+1]],
               [action_ints[i], action_ints[i+1]],
               color=:lightgray, alpha=0.3)
    end

    return fig
end

export plot_action_ratio_evolution
export plot_action_stacked_area
export plot_state_action_heatmap
export plot_policy_evolution_comparison
export plot_episode_decision_timeline

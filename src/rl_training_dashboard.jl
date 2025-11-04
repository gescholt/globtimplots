"""
RL Training Dashboard Visualization

Visualization functions for training metrics and strategy comparisons.
Accepts training metrics as NamedTuples (no package dependencies).

Usage:
    # Single strategy training progress
    fig = plot_training_progress(training_run)

    # Compare multiple strategies
    fig = plot_strategy_comparison([run1, run2, run3])

    # Full dashboard with all plots
    fig = create_training_dashboard(training_run)

Note: Uses duck typing - accepts any object with expected fields (no imports required).
"""

using CairoMakie
using GLMakie
using Statistics
using Printf

# Note: We expect training data structs with standard fields (duck typing)
# Functions accept any object with episode_rewards, episode_minimizers, etc.

"""
    plot_training_progress(run; resolution=(1200, 800))

Create multi-panel plot showing training progress:
- Rewards per episode
- Minimizers found per episode
- Steps per episode
- Function evaluations per episode
"""
function plot_training_progress(run; resolution=(1200, 800))
    episodes = run.episodes
    n_episodes = length(episodes)

    if n_episodes == 0
        error("No episodes to plot")
    end

    # Extract data
    ep_nums = [ep.episode for ep in episodes]
    rewards = [ep.total_reward for ep in episodes]
    minimizers = [ep.minimizers_found for ep in episodes]
    steps = [ep.steps_taken for ep in episodes]
    evals = [ep.function_evals for ep in episodes]

    # Create figure
    fig = Figure(resolution=resolution)

    # Title
    strategy_name = episodes[1].strategy_name
    func_name = episodes[1].function_name
    Label(fig[0, :], text="Training Progress: $strategy_name on $func_name",
          fontsize=20, font=:bold)

    # Row 1: Rewards and Minimizers
    ax_reward = Axis(fig[1, 1], xlabel="Episode", ylabel="Total Reward",
                     title="Cumulative Reward")
    lines!(ax_reward, ep_nums, rewards, color=:blue, linewidth=2)
    scatter!(ax_reward, ep_nums, rewards, color=:blue, markersize=8)

    # Add trend line
    if n_episodes > 1
        z = fit_linear_trend(ep_nums, rewards)
        lines!(ax_reward, ep_nums, z, color=:red, linestyle=:dash, linewidth=1.5,
               label="Trend")
        axislegend(ax_reward, position=:lt)
    end

    ax_minimizers = Axis(fig[1, 2], xlabel="Episode", ylabel="Minimizers Found",
                          title="Discovery Progress")
    lines!(ax_minimizers, ep_nums, minimizers, color=:green, linewidth=2)
    scatter!(ax_minimizers, ep_nums, minimizers, color=:green, markersize=8)

    # Row 2: Steps and Function Evaluations
    ax_steps = Axis(fig[2, 1], xlabel="Episode", ylabel="Steps",
                    title="Steps per Episode")
    lines!(ax_steps, ep_nums, steps, color=:orange, linewidth=2)
    scatter!(ax_steps, ep_nums, steps, color=:orange, markersize=8)

    ax_evals = Axis(fig[2, 2], xlabel="Episode", ylabel="Function Evals",
                    title="Computational Cost")
    lines!(ax_evals, ep_nums, evals, color=:purple, linewidth=2)
    scatter!(ax_evals, ep_nums, evals, color=:purple, markersize=8)

    return fig
end

"""
    plot_action_distribution(run; resolution=(1000, 600))

Plot action distribution across episodes as stacked bar chart or heatmap
"""
function plot_action_distribution(run; resolution=(1000, 600))
    episodes = run.episodes
    n_episodes = length(episodes)

    if n_episodes == 0
        error("No episodes to plot")
    end

    # Get all unique actions
    all_actions = Set{String}()
    for ep in episodes
        union!(all_actions, keys(ep.actions))
    end
    action_names = sort(collect(all_actions))
    n_actions = length(action_names)

    # Build action count matrix: rows = episodes, cols = actions
    action_matrix = zeros(Int, n_episodes, n_actions)
    for (i, ep) in enumerate(episodes)
        for (j, action) in enumerate(action_names)
            action_matrix[i, j] = get(ep.actions, action, 0)
        end
    end

    # Create figure
    fig = Figure(resolution=resolution)

    strategy_name = episodes[1].strategy_name
    Label(fig[0, :], text="Action Distribution: $strategy_name",
          fontsize=20, font=:bold)

    # Heatmap
    ax = Axis(fig[1, 1], xlabel="Action", ylabel="Episode",
              title="Action Counts per Episode")

    hm = heatmap!(ax, 1:n_actions, 1:n_episodes, action_matrix',
                  colormap=:viridis)
    ax.xticks = (1:n_actions, action_names)
    ax.xticklabelrotation = π/4

    Colorbar(fig[1, 2], hm, label="Count")

    # Bar chart: total action counts
    ax_bar = Axis(fig[2, 1], xlabel="Action", ylabel="Total Count",
                  title="Total Actions Taken")
    total_actions = sum(action_matrix, dims=1)[:]
    barplot!(ax_bar, 1:n_actions, total_actions, color=:steelblue)
    ax_bar.xticks = (1:n_actions, action_names)
    ax_bar.xticklabelrotation = π/4

    return fig
end

"""
    plot_l2_error_evolution(run; resolution=(800, 500))

Plot mean and final L2 errors across episodes
"""
function plot_l2_error_evolution(run; resolution=(800, 500))
    episodes = run.episodes

    ep_nums = [ep.episode for ep in episodes]
    mean_l2 = [ep.mean_l2_error for ep in episodes]
    final_l2 = [ep.final_l2_error for ep in episodes]

    fig = Figure(resolution=resolution)

    strategy_name = episodes[1].strategy_name
    Label(fig[0, :], text="L2 Error Evolution: $strategy_name",
          fontsize=20, font=:bold)

    ax = Axis(fig[1, 1], xlabel="Episode", ylabel="L2 Error",
              yscale=log10, title="Approximation Quality")

    lines!(ax, ep_nums, mean_l2, color=:blue, linewidth=2, label="Mean L2")
    scatter!(ax, ep_nums, mean_l2, color=:blue, markersize=8)

    lines!(ax, ep_nums, final_l2, color=:red, linewidth=2, label="Final L2")
    scatter!(ax, ep_nums, final_l2, color=:red, markersize=8)

    axislegend(ax, position=:rt)

    return fig
end

"""
    plot_strategy_comparison(runs::Vector; resolution=(1400, 1000))

Compare multiple training runs (different strategies) on the same function
"""
function plot_strategy_comparison(runs::Vector; resolution=(1400, 1000))
    if isempty(runs)
        error("No runs to compare")
    end

    n_strategies = length(runs)
    strategy_names = [run.episodes[1].strategy_name for run in runs]
    colors = Makie.wong_colors()

    fig = Figure(resolution=resolution)

    func_name = runs[1].episodes[1].function_name
    Label(fig[0, :], text="Strategy Comparison on $func_name",
          fontsize=22, font=:bold)

    # Row 1: Rewards and Minimizers Found
    ax_reward = Axis(fig[1, 1], xlabel="Episode", ylabel="Total Reward",
                     title="Learning Curves")

    ax_minimizers = Axis(fig[1, 2], xlabel="Episode", ylabel="Minimizers Found",
                          title="Discovery Efficiency")

    for (i, run) in enumerate(runs)
        episodes = run.episodes
        ep_nums = [ep.episode for ep in episodes]
        rewards = [ep.total_reward for ep in episodes]
        minimizers = [ep.minimizers_found for ep in episodes]

        color = colors[(i-1) % length(colors) + 1]

        lines!(ax_reward, ep_nums, rewards, color=color, linewidth=2,
               label=strategy_names[i])
        scatter!(ax_reward, ep_nums, rewards, color=color, markersize=6)

        lines!(ax_minimizers, ep_nums, minimizers, color=color, linewidth=2,
               label=strategy_names[i])
        scatter!(ax_minimizers, ep_nums, minimizers, color=color, markersize=6)
    end

    axislegend(ax_reward, position=:lt)
    axislegend(ax_minimizers, position=:lt)

    # Row 2: Computational Cost
    ax_steps = Axis(fig[2, 1], xlabel="Episode", ylabel="Steps",
                    title="Steps per Episode")
    ax_evals = Axis(fig[2, 2], xlabel="Episode", ylabel="Function Evals",
                    title="Computational Cost")

    for (i, run) in enumerate(runs)
        episodes = run.episodes
        ep_nums = [ep.episode for ep in episodes]
        steps = [ep.steps_taken for ep in episodes]
        evals = [ep.function_evals for ep in episodes]

        color = colors[(i-1) % length(colors) + 1]

        lines!(ax_steps, ep_nums, steps, color=color, linewidth=2,
               label=strategy_names[i])
        scatter!(ax_steps, ep_nums, steps, color=color, markersize=6)

        lines!(ax_evals, ep_nums, evals, color=color, linewidth=2,
               label=strategy_names[i])
        scatter!(ax_evals, ep_nums, evals, color=color, markersize=6)
    end

    axislegend(ax_steps, position=:lt)
    axislegend(ax_evals, position=:lt)

    # Row 3: Aggregate comparison bars (if aggregates available)
    if all(run -> !isnothing(run.aggregate), runs)
        ax_agg = Axis(fig[3, :], xlabel="Strategy", ylabel="Value",
                      title="Aggregate Metrics Comparison")

        # Metrics to compare
        mean_rewards = [run.aggregate.mean_reward for run in runs]
        mean_mins = [run.aggregate.mean_minimizers for run in runs]
        success_rates = [run.aggregate.success_rate * 100 for run in runs]  # as percentage
        efficiencies = [run.aggregate.efficiency * 100 for run in runs]  # scale up for visibility

        x = 1:n_strategies
        width = 0.2

        barplot!(ax_agg, x .- 1.5*width, mean_rewards, width=width,
                color=colors[1], label="Mean Reward")
        barplot!(ax_agg, x .- 0.5*width, mean_mins, width=width,
                color=colors[2], label="Mean Minimizers")
        barplot!(ax_agg, x .+ 0.5*width, success_rates, width=width,
                color=colors[3], label="Success Rate (%)")
        barplot!(ax_agg, x .+ 1.5*width, efficiencies, width=width,
                color=colors[4], label="Efficiency (×100)")

        ax_agg.xticks = (x, strategy_names)
        ax_agg.xticksize = 12
        axislegend(ax_agg, position=:lt)
    end

    return fig
end

"""
    create_training_dashboard(run; resolution=(1600, 1200))

Create comprehensive dashboard with all training plots
"""
function create_training_dashboard(run; resolution=(1600, 1200))
    episodes = run.episodes
    n_episodes = length(episodes)

    if n_episodes == 0
        error("No episodes to plot")
    end

    # Extract data
    ep_nums = [ep.episode for ep in episodes]
    rewards = [ep.total_reward for ep in episodes]
    minimizers = [ep.minimizers_found for ep in episodes]
    steps = [ep.steps_taken for ep in episodes]
    evals = [ep.function_evals for ep in episodes]
    mean_l2 = [ep.mean_l2_error for ep in episodes]
    final_l2 = [ep.final_l2_error for ep in episodes]

    # Get actions
    all_actions = Set{String}()
    for ep in episodes
        union!(all_actions, keys(ep.actions))
    end
    action_names = sort(collect(all_actions))
    n_actions = length(action_names)

    # Build action matrix
    action_matrix = zeros(Int, n_episodes, n_actions)
    for (i, ep) in enumerate(episodes)
        for (j, action) in enumerate(action_names)
            action_matrix[i, j] = get(ep.actions, action, 0)
        end
    end

    # Create figure
    fig = Figure(resolution=resolution)

    strategy_name = episodes[1].strategy_name
    func_name = episodes[1].function_name
    Label(fig[0, :], text="Training Dashboard: $strategy_name on $func_name",
          fontsize=24, font=:bold)

    # Row 1: Rewards and Minimizers
    ax_reward = Axis(fig[1, 1], xlabel="Episode", ylabel="Total Reward",
                     title="Learning Curve")
    lines!(ax_reward, ep_nums, rewards, color=:blue, linewidth=2)
    scatter!(ax_reward, ep_nums, rewards, color=:blue, markersize=8)

    if n_episodes > 1
        z = fit_linear_trend(ep_nums, rewards)
        lines!(ax_reward, ep_nums, z, color=:red, linestyle=:dash, linewidth=1.5,
               label="Trend")
        axislegend(ax_reward, position=:lb)
    end

    ax_minimizers = Axis(fig[1, 2], xlabel="Episode", ylabel="Minimizers Found",
                          title="Discovery Progress")
    lines!(ax_minimizers, ep_nums, minimizers, color=:green, linewidth=2)
    scatter!(ax_minimizers, ep_nums, minimizers, color=:green, markersize=8)

    # Row 2: Steps and Evals
    ax_steps = Axis(fig[2, 1], xlabel="Episode", ylabel="Steps",
                    title="Steps per Episode")
    lines!(ax_steps, ep_nums, steps, color=:orange, linewidth=2)
    scatter!(ax_steps, ep_nums, steps, color=:orange, markersize=8)

    ax_evals = Axis(fig[2, 2], xlabel="Episode", ylabel="Function Evals",
                    title="Computational Cost")
    lines!(ax_evals, ep_nums, evals, color=:purple, linewidth=2)
    scatter!(ax_evals, ep_nums, evals, color=:purple, markersize=8)

    # Row 3: L2 Error and Actions
    ax_l2 = Axis(fig[3, 1], xlabel="Episode", ylabel="L2 Error",
                 yscale=log10, title="Approximation Quality")
    lines!(ax_l2, ep_nums, mean_l2, color=:blue, linewidth=2, label="Mean L2")
    scatter!(ax_l2, ep_nums, mean_l2, color=:blue, markersize=6)
    lines!(ax_l2, ep_nums, final_l2, color=:red, linewidth=2, label="Final L2")
    scatter!(ax_l2, ep_nums, final_l2, color=:red, markersize=6)
    axislegend(ax_l2, position=:rt)

    # Action distribution bar chart
    ax_actions = Axis(fig[3, 2], xlabel="Action", ylabel="Total Count",
                      title="Action Distribution")
    total_actions = sum(action_matrix, dims=1)[:]
    barplot!(ax_actions, 1:n_actions, total_actions, color=:steelblue)
    ax_actions.xticks = (1:n_actions, action_names)
    ax_actions.xticksize = 10
    ax_actions.xtickrotation = π/4

    # Row 4: Summary statistics (if aggregate available)
    if !isnothing(run.aggregate)
        agg = run.aggregate

        summary_text = """
        Mean Reward: $(round(agg.mean_reward, digits=2)) ± $(round(agg.std_reward, digits=2))
        Mean Minimizers: $(round(agg.mean_minimizers, digits=2))
        Total Minimizers: $(agg.total_minimizers)
        Success Rate: $(round(agg.success_rate * 100, digits=1))%
        Efficiency: $(round(agg.efficiency, digits=4)) min/eval
        Mean Steps: $(round(agg.mean_steps, digits=1))
        Mean Evals: $(round(agg.mean_function_evals, digits=1))
        """

        Label(fig[4, :], text=summary_text, fontsize=14,
              font=:regular, halign=:left, tellwidth=false)
    end

    return fig
end

"""
Helper function to fit linear trend
"""
function fit_linear_trend(x::Vector, y::Vector)
    n = length(x)
    x_mean = mean(x)
    y_mean = mean(y)

    numerator = sum((x .- x_mean) .* (y .- y_mean))
    denominator = sum((x .- x_mean).^2)

    slope = numerator / denominator
    intercept = y_mean - slope * x_mean

    return slope .* x .+ intercept
end

export plot_training_progress
export plot_action_distribution
export plot_l2_error_evolution
export plot_strategy_comparison
export create_training_dashboard

# ============================================================================
# Simplified API for train_dqn_phase2.jl output format
# ============================================================================

"""
    plot_training_curves_simple(results;
                                 title="Training Progress",
                                 expected_minima=nothing,
                                 window_size=25)

Plot training curves from simple NamedTuple format (train_dqn_phase2.jl output).

# Arguments
- `results`: NamedTuple with fields:
  - `episode_rewards::Vector{Float64}`: Cumulative reward per episode
  - `episode_minimizers::Vector{Float64}`: Minimizers found per episode
  - `episode_losses::Vector{Float64}`: TD loss per episode (NaN if no training)
  - `func_config::Dict`: Function metadata (for expected_minima)

# Returns
- `fig::Figure`: GLMakie figure (interactive window)

# Example
```julia
using GLMakie
results = include("examples/train_dqn_phase2.jl")
plot_training_curves_simple(results)
```
"""
function plot_training_curves_simple(results;
                                     title="Training Progress",
                                     expected_minima=nothing,
                                     window_size=25)
    # GLMakie is activated automatically when loaded
    # No need for explicit activate!() call

    # Extract data
    rewards = results.episode_rewards
    minimizers = results.episode_minimizers
    losses = results.episode_losses
    n_episodes = length(rewards)
    episodes = 1:n_episodes

    # Use expected_minima from func_config if not provided
    if expected_minima === nothing && haskey(results, :func_config)
        expected_minima = get(results.func_config, "expected_minima", nothing)
    end

    # Create figure (extra height for objective function panel)
    fig = Figure(size=(1400, 1200))

    Label(fig[0, :], text=title, fontsize=24, font=:bold)

    # Panel 1: Minimizers found
    ax1 = Axis(fig[1, 1],
              xlabel="Episode",
              ylabel="Minimizers Found",
              title="Discovery Rate")

    lines!(ax1, episodes, minimizers, color=(:steelblue, 0.4), linewidth=1, label="Raw")
    lines!(ax1, episodes, rolling_mean(minimizers, window_size),
           color=:steelblue, linewidth=3, label="Rolling Avg ($window_size)")

    if expected_minima !== nothing
        hlines!(ax1, expected_minima, color=:red, linestyle=:dash,
                linewidth=2, label="Expected")
    end

    axislegend(ax1, position=:lt)

    # Panel 2: Cumulative reward
    ax2 = Axis(fig[1, 2],
              xlabel="Episode",
              ylabel="Cumulative Reward",
              title="Reward Signal")

    lines!(ax2, episodes, rewards, color=(:orange, 0.4), linewidth=1)
    lines!(ax2, episodes, rolling_mean(rewards, window_size),
           color=:orange, linewidth=3, label="Rolling Avg")

    axislegend(ax2, position=:lt)

    # Panel 3: TD Loss (if available)
    valid_losses = filter(!isnan, losses)
    if !isempty(valid_losses)
        ax3 = Axis(fig[2, 1],
                  xlabel="Episode",
                  ylabel="TD Loss",
                  title="Learning Progress")

        valid_indices = findall(!isnan, losses)
        lines!(ax3, valid_indices, valid_losses, color=:purple, linewidth=2)

        # Add smoothed trend
        if length(valid_losses) > window_size
            smoothed = rolling_mean(valid_losses, window_size)
            lines!(ax3, valid_indices[1:length(smoothed)], smoothed,
                   color=:black, linewidth=3, linestyle=:dash, label="Trend")
            axislegend(ax3, position=:rt)
        end
    end

    # Panel 4: Final performance summary
    ax4 = Axis(fig[2, 2],
              xlabel="Metric",
              ylabel="Value",
              title="Final Performance (last 25 episodes)")

    window_end = min(n_episodes, 25)
    final_window = max(1, n_episodes - window_end + 1):n_episodes

    avg_minimizers = mean(minimizers[final_window])
    avg_reward = mean(rewards[final_window])
    success_rate = if expected_minima !== nothing
        count(x -> x >= expected_minima, minimizers[final_window]) / length(final_window) * 100
    else
        NaN
    end

    metrics = ["Avg\nMinimizers", "Avg\nReward"]
    values = [avg_minimizers, avg_reward / 10]  # Scale reward for visibility
    colors_bar = [:steelblue, :orange]

    barplot!(ax4, 1:2, values, color=colors_bar)
    ax4.xticks = (1:2, metrics)
    ax4.xticklabelrotation = 0

    # Add text labels
    text!(ax4, 1, avg_minimizers + 0.2, text=@sprintf("%.1f", avg_minimizers),
          align=(:center, :bottom), fontsize=14)
    text!(ax4, 2, avg_reward/10 + 0.2, text=@sprintf("%.1f", avg_reward),
          align=(:center, :bottom), fontsize=14)

    if !isnan(success_rate)
        text!(ax4, 1.5, maximum(values) * 0.8,
              text=@sprintf("Success: %.0f%%", success_rate),
              align=(:center, :center), fontsize=16, font=:bold)
    end

    # Panel 5: Objective function (if available)
    if haskey(results, :func_config)
        func_config = results.func_config
        if haskey(func_config, "f") && haskey(func_config, "domain")
            f = func_config["f"]
            domain = func_config["domain"]

            ax5 = Axis(fig[3, :],
                      xlabel="x",
                      ylabel="f(x)",
                      title="Objective Function: $(get(func_config, "description", get(func_config, "name", "")))")

            # Plot function over domain
            x_vals = range(domain[1], domain[2], length=500)
            y_vals = [f([x]) for x in x_vals]

            lines!(ax5, x_vals, y_vals, color=:black, linewidth=2, label="f(x)")

            # Mark expected minima line (if known)
            if expected_minima !== nothing
                text!(ax5, domain[1] + 0.02 * (domain[2] - domain[1]),
                      minimum(y_vals) + 0.1 * (maximum(y_vals) - minimum(y_vals)),
                      text="Target: $expected_minima minima",
                      fontsize=12, color=:red)
            end

            axislegend(ax5, position=:rt)
        end
    end

    display(fig)

    # Keep window open until user presses Enter (macOS display doesn't block by default)
    println("\n[Press Enter to close window and continue]")
    readline()

    return fig
end

"""
    plot_multi_strategy_comparison_simple(results_dict;
                                          expected_minima=5,
                                          window_size=25)

Compare multiple training strategies on same plot (simplified API).

# Arguments
- `results_dict::Dict{String, NamedTuple}`: Dict of strategy name => results
- `expected_minima::Int`: Horizontal reference line
- `window_size::Int`: Rolling average window

# Example
```julia
results_dict = Dict(
    "DQN" => run_dqn_training(),
    "Greedy" => run_greedy_baseline(),
    "Random" => run_random_baseline()
)
plot_multi_strategy_comparison_simple(results_dict)
```
"""
function plot_multi_strategy_comparison_simple(results_dict::Dict;
                                               expected_minima=5,
                                               window_size=25)
    # GLMakie is activated automatically when loaded

    fig = Figure(size=(1600, 1100))

    Label(fig[0, :], text="Training Strategy Comparison",
          fontsize=24, font=:bold)

    # Main plot: Minimizers found (smoothed)
    ax_main = Axis(fig[1, 1:2],
                  xlabel="Episode",
                  ylabel="Minimizers Found (rolling avg)",
                  title="Discovery Rate Comparison")

    colors = Makie.wong_colors()

    for (i, (name, results)) in enumerate(sort(collect(results_dict)))
        color = colors[mod1(i, length(colors))]

        minimizers = results.episode_minimizers
        episodes = 1:length(minimizers)

        # Raw data (faint)
        lines!(ax_main, episodes, minimizers,
               color=(color, 0.2), linewidth=1)

        # Smoothed curve
        smoothed = rolling_mean(minimizers, window_size)
        lines!(ax_main, episodes, smoothed,
               label=name, color=color, linewidth=3)
    end

    # Expected minima reference
    hlines!(ax_main, expected_minima,
            color=:red, linestyle=:dash, linewidth=2, label="Expected")

    axislegend(ax_main, position=:lt, framevisible=true, labelsize=14)

    # Right panel: Final performance comparison
    ax_bar = Axis(fig[1, 3],
                 xlabel="Strategy",
                 ylabel="Avg Minimizers (last 25)",
                 title="Final Performance")

    strategies = sort(collect(keys(results_dict)))
    final_perfs = Float64[]

    for strat in strategies
        minimizers = results_dict[strat].episode_minimizers
        window = max(1, length(minimizers) - 24):length(minimizers)
        push!(final_perfs, mean(minimizers[window]))
    end

    barplot!(ax_bar, 1:length(strategies), final_perfs,
             color=colors[1:length(strategies)])
    ax_bar.xticks = (1:length(strategies), strategies)
    ax_bar.xticklabelrotation = π/4

    # Add value labels on bars
    for (i, val) in enumerate(final_perfs)
        text!(ax_bar, i, val + 0.1,
              text=@sprintf("%.1f", val),
              align=(:center, :bottom), fontsize=12)
    end

    # Bottom panel: Rewards comparison
    ax_reward = Axis(fig[2, :],
                    xlabel="Episode",
                    ylabel="Cumulative Reward (rolling avg)",
                    title="Reward Signal Comparison")

    for (i, (name, results)) in enumerate(sort(collect(results_dict)))
        color = colors[mod1(i, length(colors))]

        rewards = results.episode_rewards
        episodes = 1:length(rewards)

        smoothed = rolling_mean(rewards, window_size)
        lines!(ax_reward, episodes, smoothed,
               label=name, color=color, linewidth=3)
    end

    axislegend(ax_reward, position=:lt, framevisible=true, labelsize=14)

    # Row 3: Objective function (if available)
    # Get func_config from first result (same function for all strategies)
    first_result = first(values(results_dict))
    if haskey(first_result, :func_config)
        func_config = first_result.func_config
        if haskey(func_config, "f") && haskey(func_config, "domain")
            f = func_config["f"]
            domain = func_config["domain"]

            ax_obj = Axis(fig[3, :],
                         xlabel="x",
                         ylabel="f(x)",
                         title="Objective Function: $(get(func_config, "description", get(func_config, "name", "")))")

            # Plot function over domain
            x_vals = range(domain[1], domain[2], length=500)
            y_vals = [f([x]) for x in x_vals]

            lines!(ax_obj, x_vals, y_vals, color=:black, linewidth=2, label="f(x)")

            # Mark expected minima
            text!(ax_obj, domain[1] + 0.02 * (domain[2] - domain[1]),
                  minimum(y_vals) + 0.1 * (maximum(y_vals) - minimum(y_vals)),
                  text="Target: $expected_minima minima",
                  fontsize=12, color=:red)

            axislegend(ax_obj, position=:rt)
        end
    end

    display(fig)

    # Keep window open until user presses Enter (macOS display doesn't block by default)
    println("\n[Press Enter to close window and continue]")
    readline()

    return fig
end

"""
Helper: Compute rolling mean with given window size
"""
function rolling_mean(xs::Vector, window::Int)
    [mean(xs[max(1, i-window+1):i]) for i in 1:length(xs)]
end

export plot_training_curves_simple
export plot_multi_strategy_comparison_simple

#!/usr/bin/env julia
#
# Generate LV4D convergence and analysis plots
#
# Usage: julia --project=globtimplots scripts/plot_lv4d.jl
#
# The script launches interactive menus with two modes:
#
#   Standard mode: Select GN and domain (all seeds included)
#   Advanced mode: Also select specific seed values
#
# Use arrow keys to navigate menus, Enter to select.
# Degree is always the x-axis (independent variable) and is never filtered.
#
# Plot controls:
#   Enter - advance to next plot
#   s     - save current plot as PDF
#   q     - quit
#

using GlobtimPostProcessing
using GlobtimPostProcessing.LV4DAnalysis
using GlobtimPlots
using GlobtimPlots.LV4DPlots
using GLMakie  # Interactive display
GLMakie.activate!()
using DataFrames
using Statistics
using REPL.TerminalMenus

# =============================================================================
# Interactive Parameter Selection
# =============================================================================

"""
Create a menu for selecting a parameter value.
Returns the selected value (FixedValue), a range (SweepRange), or nothing for 'all'.
"""
function select_parameter(
    param_name::String,
    available::Vector{T};
    context::String = "",
    allow_range::Bool = true,
) where {T}
    # Build menu options
    options = string.(available)
    if allow_range && length(available) > 1
        push!(options, "[range]")
    end
    push!(options, "[all]")

    # Show context
    ctx_str = isempty(context) ? "" : " ($context)"
    println("\nSelect $param_name$ctx_str:")

    # Create and run menu
    menu = RadioMenu(options; pagesize = min(10, length(options)))
    choice = request(menu)

    if choice == -1  # Cancelled
        error("Selection cancelled")
    end

    selected = options[choice]

    if selected == "[all]"
        return nothing
    elseif selected == "[range]"
        return select_range(param_name, available)
    else
        return fixed(parse(T, selected))
    end
end

"""
Prompt user to select a range from available values.
"""
function select_range(param_name::String, available::Vector{T}) where {T}
    println("\nSelect $param_name range:")
    println("  Available: $(minimum(available)) to $(maximum(available))")

    # Select min
    println("Select minimum:")
    menu_min = RadioMenu(string.(available); pagesize = min(10, length(available)))
    min_idx = request(menu_min)
    min_idx == -1 && error("Selection cancelled")
    min_val = available[min_idx]

    # Select max (only values >= min)
    valid_max = filter(x -> x >= min_val, available)
    println("Select maximum:")
    menu_max = RadioMenu(string.(valid_max); pagesize = min(10, length(valid_max)))
    max_idx = request(menu_max)
    max_idx == -1 && error("Selection cancelled")
    max_val = valid_max[max_idx]

    return sweep(min_val, max_val)
end

"""
Get available values for a parameter given current filter constraints.
"""
function get_filtered_values(results_root::String, filter::ExperimentFilter, param::Symbol)
    df = query_to_dataframe(results_root, filter)
    if nrow(df) == 0
        # Return empty vector of appropriate type
        param_types = Dict(:GN => Int, :domain => Float64, :seed => Int, :degree => Int)
        T = get(param_types, param, Any)
        return T[]
    end
    return sort(unique(df[!, param]))
end

"""
Build context string from current filter.
"""
function build_context(filter::ExperimentFilter)
    parts = String[]
    filter.gn !== nothing && push!(parts, "GN=$(format_spec(filter.gn))")
    filter.domain !== nothing && push!(parts, "domain=$(format_spec(filter.domain))")
    filter.seed !== nothing && push!(parts, "seed=$(format_spec(filter.seed))")
    return join(parts, ", ")
end

"""
Select between standard, advanced, coverage, and browse mode.
Returns :standard, :advanced, :coverage, or :browse.
"""
function select_mode()
    println("\nSelect mode:")
    options = [
        "Standard (GN + domain → plots)",
        "Advanced (GN + domain + seed → plots)",
        "Coverage (check missing experiments)",
        "Browse (use experiment index → plots)",
    ]
    menu = RadioMenu(options; pagesize = 4)
    choice = request(menu)
    choice == -1 && error("Selection cancelled")
    return [:standard, :advanced, :coverage, :browse][choice]
end

"""
Interactive parameter selection flow with arrow-key menus.

Standard mode: Select GN and domain only (all seeds included)
Advanced mode: Also select seed
Coverage mode: Returns :coverage (handled separately)
Browse mode: Returns :browse (handled separately)
"""
function interactive_filter_selection(results_root::String)
    # Initial scan
    df_all = query_to_dataframe(results_root, ExperimentFilter())
    if nrow(df_all) == 0
        error("No experiments found in: $results_root")
    end
    println("Found $(length(unique(df_all.experiment_dir))) experiment directories")

    # Select mode
    mode = select_mode()

    # Coverage and Browse modes handled separately
    if mode == :coverage
        return :coverage
    elseif mode == :browse
        return :browse
    end

    # Step 1: Select GN
    gn_values = sort(unique(df_all.GN))
    gn_spec = select_parameter("GN", gn_values; allow_range = false)

    # Step 2: Select domain (filtered by GN)
    filter_gn = ExperimentFilter(gn = gn_spec)
    domain_values = get_filtered_values(results_root, filter_gn, :domain)
    domain_spec = select_parameter(
        "domain",
        domain_values;
        context = build_context(filter_gn),
        allow_range = true,
    )

    # Step 3: Select seed (advanced mode only)
    seed_spec = nothing
    if mode == :advanced
        filter_gn_dom = ExperimentFilter(gn = gn_spec, domain = domain_spec)
        seed_values = get_filtered_values(results_root, filter_gn_dom, :seed)
        seed_spec = select_parameter(
            "seed",
            seed_values;
            context = build_context(filter_gn_dom),
            allow_range = true,
        )
    end

    return ExperimentFilter(gn = gn_spec, domain = domain_spec, seed = seed_spec)
end

# =============================================================================
# Coverage Analysis Mode
# =============================================================================

"""
Multi-select values from a list using space to toggle.
"""
function multi_select_values(prompt::String, values::Vector{T}) where {T}
    if isempty(values)
        println("No values available")
        return T[]
    end
    if length(values) == 1
        println("Using $(values[1]) (only available)")
        return values
    end

    options = string.(values)
    menu = MultiSelectMenu(options; pagesize = min(10, length(options)))
    selected = request(prompt, menu)

    if isempty(selected)
        return T[]
    end
    return [values[i] for i in sort(collect(selected))]
end

"""
Format a vector for user-friendly display (no Julia array syntax).
"""
function format_values(values::Vector)
    return join(values, ", ")
end

"""
Format seed range compactly (e.g., "1-5" for consecutive, "1,3,5" otherwise).
"""
function format_seed_range(seeds::Vector{Int})
    if length(seeds) == 1
        return string(seeds[1])
    elseif seeds == collect(minimum(seeds):maximum(seeds))
        return "$(minimum(seeds))-$(maximum(seeds))"
    else
        return join(seeds, ",")
    end
end

"""
Run interactive coverage analysis.
"""
function run_coverage_analysis(results_root::String)
    println("\n" * "="^60)
    println("LV4D Coverage Analysis")
    println("="^60)

    # Get available values
    df_all = query_to_dataframe(results_root, ExperimentFilter())
    gn_values = sort(unique(df_all.GN))
    domain_values = sort(unique(df_all.domain))
    degree_values = sort(unique(df_all.degree))

    # Step 1: Multi-select GN values
    selected_gn = multi_select_values("\nSelect expected GN values:", gn_values)
    isempty(selected_gn) && error("No GN values selected")

    # Step 2: Multi-select domain values
    selected_domains =
        multi_select_values("\nSelect expected domain values:", domain_values)
    isempty(selected_domains) && error("No domain values selected")

    # Step 3: Select degree range
    println("\nSelect degree range:")
    deg_min, deg_max = extrema(degree_values)
    options = ["$deg_min-$deg_max (all)", "4-12", "4-18", "Custom"]
    menu = RadioMenu(options; pagesize = 4)
    choice = request(menu)
    choice == -1 && error("Selection cancelled")

    degree_range = if choice == 1
        deg_min:2:deg_max
    elseif choice == 2
        4:2:12
    elseif choice == 3
        4:2:18
    else
        print("Enter degree range (e.g., 4:2:12): ")
        input = strip(readline())
        parts = split(input, ":")
        if length(parts) == 3
            parse(Int, parts[1]):parse(Int, parts[2]):parse(Int, parts[3])
        elseif length(parts) == 2
            parse(Int, parts[1]):2:parse(Int, parts[2])
        else
            error("Invalid format")
        end
    end

    # Step 4: Select seed range
    println("\nSelect seed range:")
    seed_options = ["1:5 (5 seeds)", "1:3 (3 seeds)", "1 only", "Custom"]
    menu = RadioMenu(seed_options; pagesize = 4)
    choice = request(menu)
    choice == -1 && error("Selection cancelled")

    seed_range = if choice == 1
        collect(1:5)
    elseif choice == 2
        collect(1:3)
    elseif choice == 3
        [1]
    else
        print("Enter seed range (e.g., 1:10): ")
        input = strip(readline())
        parts = split(input, ":")
        if length(parts) == 2
            collect(parse(Int, parts[1]):parse(Int, parts[2]))
        else
            [parse(Int, input)]
        end
    end

    # Run analysis (no redundant summary - report will show params)
    report = analyze_coverage(
        results_root;
        expected_gn = selected_gn,
        expected_domains = selected_domains,
        expected_degrees = degree_range,
        expected_seeds = seed_range,
    )

    # Print report
    print_coverage_report(report)

    # Offer gap-filling if missing experiments
    if !isempty(report.missing_keys)
        println("\nGenerate gap-filling configs?")
        options = ["Yes", "No"]
        menu = RadioMenu(options; pagesize = 2)
        choice = request(menu)

        if choice == 1
            println("\nSelect output directory:")
            dir_options = ["experiments/fill_gaps/", "experiments/generated/", "Custom"]
            menu = RadioMenu(dir_options; pagesize = 3)
            dir_choice = request(menu)

            output_dir = if dir_choice == 1
                "experiments/fill_gaps/"
            elseif dir_choice == 2
                "experiments/generated/"
            else
                print("Enter directory: ")
                strip(readline())
            end

            configs = generate_gap_filling_configs(report; output_dir = output_dir)
            n_missing = length(report.missing_keys)
            println(
                "\nGenerated $(length(configs)) config files for $n_missing missing experiments.",
            )
        end
    end

    return report
end

# =============================================================================
# Main Execution
# =============================================================================

const RESULTS_ROOT = let
    key = "GLOBTIM_RESULTS"
    haskey(ENV, key) || error(
        "Environment variable $key is not set. Set it to the globtim_results directory, e.g. export GLOBTIM_RESULTS=/path/to/globtim_results",
    )
    joinpath(ENV[key], "lotka_volterra_4d")
end

# Interactive filter selection
filter_result = interactive_filter_selection(RESULTS_ROOT)

# Coverage mode - run analysis and exit
if filter_result === :coverage
    report = run_coverage_analysis(RESULTS_ROOT)
    n_missing = length(report.missing_keys)
    if n_missing == 0
        println("\nCoverage analysis complete. All expected experiments present.")
    else
        println("\nCoverage analysis complete. $n_missing missing experiments identified.")
    end
    exit(0)
end

# Browse mode - use experiment index TUI
if filter_result === :browse
    using GlobtimPostProcessing: select_experiments
    filter, results_path = select_experiments()
    # results_path from select_experiments may differ from RESULTS_ROOT
    # Use it for consistency with the index shown
    actual_results_root = results_path
else
    filter = filter_result
    actual_results_root = RESULTS_ROOT
end

# Plotting mode
println("\nFilter: $(format_filter(filter))")
df = query_to_dataframe(actual_results_root, filter)

if nrow(df) == 0
    error("No experiments match filter: $(format_filter(filter))")
end

# Show data summary
n_seeds = length(unique(df.seed))
n_configs = length(unique(zip(df.GN, df.domain, df.degree)))
println("Loaded $n_configs configurations × $n_seeds seeds = $(nrow(df)) data points")
println("  GN: $(format_values(sort(unique(df.GN))))")
println("  Degrees: $(minimum(df.degree))-$(maximum(df.degree))")
println("  Domains: $(format_values(sort(unique(df.domain))))")

# Aggregate data for comparison plots
df_agg = combine(
    groupby(df, [:GN, :domain, :degree]),
    :L2_norm => mean => :mean_L2,
    :L2_norm => std => :std_L2,
    :recovery_error => mean => :mean_recovery,
    :recovery_error => std => :std_recovery,
    :recovery_error => (x -> mean(x .< 0.05)) => :success_rate,
    nrow => :n_seeds,
)

# Detect single-domain case
n_domains = length(unique(df.domain))
is_single_domain = n_domains == 1

# Generate appropriate plots based on number of domains
figures = if is_single_domain
    # Single domain: show L2/recovery vs degree instead of domain-based convergence
    fig1 = plot_lv4d_l2_by_degree(df)
    fig2 = plot_lv4d_recovery_by_degree(df)
    fig3 = plot_lv4d_degree_comparison(df_agg)
    fig4 = plot_lv4d_gn_comparison(df_agg)

    [
        ("L2 vs Degree", fig1),
        ("Recovery vs Degree", fig2),
        ("Degree Comparison", fig3),
        ("GN Comparison", fig4),
    ]
else
    # Multiple domains: use domain-based convergence plots
    fig1 = plot_lv4d_l2_convergence(df)
    fig2 = plot_lv4d_recovery_convergence(df)
    fig3 = plot_lv4d_convergence_multi_degree(df)
    fig4 = plot_lv4d_convergence_rate(df)
    fig5 = plot_lv4d_degree_comparison(df_agg)
    fig6 = plot_lv4d_metrics_heatmap(df_agg)
    fig7 = plot_lv4d_gn_comparison(df_agg)

    [
        ("L2 Convergence", fig1),
        ("Recovery Convergence", fig2),
        ("Multi-Degree Convergence", fig3),
        ("Convergence Rate", fig4),
        ("Degree Comparison", fig5),
        ("Metrics Heatmap", fig6),
        ("GN Comparison", fig7),
    ]
end

println("\n$(length(figures)) plots ready. Press Enter to cycle, 'q' to quit, 's' to save.")
for (name, fig) in figures
    println("\nShowing: $name")
    display(fig)
    print("Action [Enter/q/s]: ")
    input = readline()
    if input == "q"
        break
    elseif input == "s"
        filename = lowercase(replace(name, " " => "_")) * ".pdf"
        save(filename, fig)
        println("Saved: $filename")
    end
end

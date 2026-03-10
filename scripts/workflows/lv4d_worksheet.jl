# LV4D Analysis Worksheet - run line-by-line in REPL from GlobalOptim directory

# === SETUP ===
using Revise; Revise.revise()
using Pkg
let proj = joinpath(@__DIR__, "..", "..")
    isfile(joinpath(proj, "Project.toml")) || error("No Project.toml found at $proj. Activate the correct project environment before running this worksheet.")
    Pkg.activate(proj)
end
using GlobtimPostProcessing, GlobtimPostProcessing.LV4DAnalysis, GlobtimPlots, GLMakie, DataFrames
GLMakie.activate!()

const RESULTS_ROOT = let
    key = "GLOBTIM_RESULTS"
    haskey(ENV, key) || error("Environment variable $key is not set. Set it to the globtim_results directory, e.g. export GLOBTIM_RESULTS=/path/to/globtim_results")
    joinpath(ENV[key], "lotka_volterra_4d")
end

# === PARAMETERS ===
GN = 8
DEG_MIN, DEG_MAX = 8, 12
DOMAIN_MIN, DOMAIN_MAX = 0.08, 0.15

# === SWEEP ANALYSIS ===
filter = ExperimentFilter(gn=fixed(GN), degree=sweep(DEG_MIN, DEG_MAX), domain=sweep(DOMAIN_MIN, DOMAIN_MAX))
df = analyze_sweep(RESULTS_ROOT, filter; export_csv=false, show_header=false)

# === CONVERGENCE RATE ANALYSIS ===
convergence = analyze_convergence(RESULTS_ROOT; gn=GN, degree_min=DEG_MIN, degree_max=DEG_MAX)

# === HEATMAP PLOTS ===
plot_lv4d_metrics_heatmap(df; metric=:success_rate)
plot_lv4d_metrics_heatmap(df; metric=:mean_recovery)
plot_lv4d_metrics_heatmap(df; metric=:mean_L2)

# === CONVERGENCE PLOTS ===
plot_lv4d_l2_convergence(df)
plot_lv4d_recovery_convergence(df)
plot_lv4d_convergence_rate(df; metric=:mean_recovery)
plot_lv4d_convergence_multi_degree(df)

# === COMPARISON PLOTS ===
plot_lv4d_l2_by_degree(df)
plot_lv4d_recovery_by_degree(df)
plot_lv4d_degree_comparison(df)
plot_lv4d_gn_comparison(df)

# === COVERAGE ANALYSIS ===
coverage = analyze_coverage(RESULTS_ROOT;
    expected_gn=[8], expected_domains=[0.08, 0.1, 0.12, 0.15], expected_degrees=8:2:12, expected_seeds=1:5)
print_coverage_report(coverage)
missing = get_missing_combinations(coverage)

# === QUERY INTERFACE ===
experiments = query_experiments(RESULTS_ROOT, filter)

# === SINGLE EXPERIMENT ===
exp_path = select_experiment(RESULTS_ROOT)
analyze_quality(exp_path)
summary = get_quality_summary(load_lv4d_experiment(exp_path))

# === FIND/FILTER EXPERIMENTS ===
find_experiments(RESULTS_ROOT)
filter!(contains("GN8"), find_experiments(RESULTS_ROOT))

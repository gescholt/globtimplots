module GlobtimPlots

# Core plotting dependencies
using CairoMakie
using GLMakie
using DataFrames
using Statistics
using Dates
using ProgressMeter

# Re-export Makie backends so users get them automatically
# This allows: using GlobtimPlots; CairoMakie.activate!()
using Reexport
@reexport using CairoMakie
@reexport using GLMakie

# Note: We use duck typing for data structures from other packages (GlobtimPostProcessing, GlobTimRL)
# This avoids circular dependencies while maintaining API flexibility

# Include abstract interfaces
include("interfaces.jl")

# Include core plotting functionality
include("graphs_cairo.jl")
include("graphs_makie.jl")
include("level_set_viz.jl")  # 3D level set visualization
include("experiment_results_plots.jl")  # Cluster experiment results visualization

# Include campaign plotting files that only depend on Makie
# (These use duck typing for ExperimentResult/CampaignResults types from GlobtimPostProcessing)
include("CampaignPlotting.jl")

# Include RL training dashboard (accepts GlobTimRL metrics structs)
include("rl_training_dashboard.jl")
include("policy_evolution_viz.jl")

# Export abstract types
export AbstractPolynomialData, AbstractProblemInput, AbstractCriticalPointData
export GenericPolynomialData, GenericProblemInput
export adapt_polynomial_data, adapt_problem_input

# Export plotting functions
export plot_polyapprox_3d, plot_polyapprox_levelset, plot_polyapprox_rotate
export plot_polyapprox_animate, plot_polyapprox_flyover, plot_polyapprox_animate2
export plot_level_set, plot_polyapprox_levelset_2D
export cairo_plot_polyapprox_levelset, plot_convergence_analysis, plot_discrete_l2
export plot_filtered_y_distances, plot_distance_statistics, plot_convergence_captured
export plot_theoretical_minimizer_distances
export plot_hessian_norms, plot_condition_numbers, plot_critical_eigenvalues
export plot_all_eigenvalues, plot_raw_vs_refined_eigenvalues
export plot_degree_comparison, plot_domain_comparison, plot_experiment_overview
export create_comparison_plots
export plot_results, plot_multiple_results
export makie_available
export plot_experiment_results_static, plot_experiment_results_interactive

# Export campaign plotting functions from CampaignPlotting.jl (Makie-based)
export PlotBackend, Interactive, Static
export create_experiment_plots, create_campaign_comparison_plot, create_single_plot, save_plot
export generate_experiment_labels

# Note: VegaLite and Tidier-based plotting functions are temporarily disabled
# due to VegaLite dependency conflicts with modern Julia packages
# These will be re-enabled once VegaLite compatibility is resolved:
# - campaign_to_tidy_dataframe, compute_campaign_summary_stats (from TidierTransforms.jl)
# - create_convergence_dashboard, create_parameter_sensitivity_plot (from VegaPlotting.jl)
# - create_multi_metric_comparison, create_efficiency_analysis (from VegaPlotting.jl)
# - plot_l2_convergence (from VegaPlottingMinimal.jl)
# Level set visualization functions
export LevelSetData, VisualizationParameters
export prepare_level_set_data, to_makie_format
export create_level_set_visualization, create_level_set_animation

# Export utility functions
export transform_coordinates, points_in_hypercube
export analyze_convergence_distances, analyze_captured_distances
export capture_histogram, create_legend_figure, histogram_enhanced, histogram_minimizers_only

# Export RL training dashboard functions
export plot_training_progress, plot_action_distribution, plot_l2_error_evolution
export plot_strategy_comparison, create_training_dashboard
# Simplified API for train_dqn_phase2.jl output format
export plot_training_curves_simple, plot_multi_strategy_comparison_simple

# Export policy evolution visualization functions
export plot_action_ratio_evolution, plot_action_stacked_area
export plot_state_action_heatmap, plot_policy_evolution_comparison
export plot_episode_decision_timeline

# Package version
const VERSION = v"0.1.0"

# Initialize the module
function __init__()
    @info "GlobtimPlots.jl loaded. Extensions will be available when backend packages are loaded."
end

end # module GlobtimPlots
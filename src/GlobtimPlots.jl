module GlobtimPlots

# Core plotting dependencies
using CairoMakie
# NOTE: GLMakie removed - causes precompilation segfault on macOS (GLFW monitor detection bug)
# Users can load GLMakie separately if needed: using GLMakie; GLMakie.activate!()
using DataFrames
using Statistics
using ColorSchemes

# Re-export CairoMakie backend so users get it automatically
# This allows: using GlobtimPlots; CairoMakie.activate!()
using Reexport
@reexport using CairoMakie

# Note: We use duck typing for data structures from other packages
# This avoids circular dependencies while maintaining API flexibility
# RL visualization functions accept any NamedTuple with expected fields (no package dependency)

# Include abstract interfaces
include("interfaces.jl")

# Pure numeric helpers for Morse-aware slider distributions and adaptive shell stacks
include("morse_slider.jl")

# Include core plotting functionality
include("analysis_plots.jl")
include("level_set_viz.jl")  # 3D level set visualization
include("experiment_results_plots.jl")  # Cluster experiment results visualization

# Include campaign plotting files that only depend on Makie
# (These use duck typing for ExperimentResult/CampaignResults types from GlobtimPostProcessing)
include("CampaignPlotting.jl")

# Include RL training dashboard (accepts metrics as NamedTuples - no package dependencies)
include("rl_training_dashboard.jl")
include("policy_evolution_viz.jl")

# Include subdivision tree visualization (for adaptive refinement from globtim)
include("subdivision_tree_viz.jl")

# Include 1D polynomial approximation visualization
include("plot_1d_approx.jl")

# Include 2D partition visualization (for AMR environments)
# Import Rect for partition_viz.jl and subdivision_partition_viz.jl
# (GeometryBasics is a transitive dep via CairoMakie)
using GeometryBasics: Rect
include("partition_viz.jl")

# Include subdivision partition visualization (for adaptive subdivision experiments)
include("subdivision_partition_viz.jl")

# Include subdivision error heatmap (runtime plot: requires tree with polynomials in memory)
include("subdivision_error_heatmap.jl")

# Include interactive error explorer (zoom-refine pattern; needs GLMakie for interactivity)
include("interactive_error_explorer.jl")

# Include interactive levelset explorer (click-to-optimize; needs GLMakie for interactivity)
include("interactive_levelset_explorer.jl")

# Include capture analysis visualization (depends on GlobtimPostProcessing types)
include("capture_analysis_plots.jl")

# Include refinement trajectory visualization (depends on GlobtimPostProcessing types)
include("refinement_trajectory_viz.jl")

# Include LV4D plotting module
include("lv4d/LV4DPlots.jl")
using .LV4DPlots

# Backend-agnostic Hessian/eigenvalue plots (previously duplicated across GLMakie & CairoMakie extensions)
include("hessian_eigenvalue_plots.jl")

# Backend-agnostic 3D polynomial approximation surface (core logic; GLMakie extension adds record())
include("polyapprox_3d.jl")

# Export abstract types
export AbstractPolynomialData, AbstractProblemInput, AbstractCriticalPointData
export GenericPolynomialData, GenericProblemInput
export adapt_polynomial_data, adapt_problem_input
export _plot_polyapprox_3d_impl

# Export plotting functions (defined in src/)
export plot_polyapprox_3d
export plot_level_set
export cairo_plot_polyapprox_levelset, plot_convergence_analysis, plot_discrete_l2
export plot_filtered_y_distances, plot_distance_statistics, plot_convergence_captured
export plot_theoretical_minimizer_distances
export plot_l2_convergence_trials
export plot_experiment_results_static, plot_experiment_results_interactive

# Forward declaration for plot_polyapprox_3d — the public API.
# The core plotting logic lives in src/polyapprox_3d.jl (_plot_polyapprox_3d_impl).
# The GLMakie extension defines the full plot_polyapprox_3d with rotation animation support.
# When no 3D backend extension is loaded, this stub provides a clear error.
function plot_polyapprox_3d end

# Note: plot_hessian_norms, plot_condition_numbers, plot_critical_eigenvalues,
# plot_all_eigenvalues, and plot_raw_vs_refined_eigenvalues are now concrete
# implementations in src/hessian_eigenvalue_plots.jl (backend-agnostic, abstract Makie API).

# Export extension functions
export plot_hessian_norms, plot_condition_numbers, plot_critical_eigenvalues
export plot_all_eigenvalues, plot_raw_vs_refined_eigenvalues

# Export campaign plotting functions from CampaignPlotting.jl (Makie-based)
export PlotBackend, Interactive, Static
export create_experiment_plots,
    create_campaign_comparison_plot, create_single_plot, save_plot
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

# Export RL training dashboard functions
export plot_training_progress, plot_action_distribution, plot_l2_error_evolution
export plot_strategy_comparison, create_training_dashboard
# Simplified API for train_dqn_phase2.jl output format
export plot_training_curves_simple, plot_multi_strategy_comparison_simple
# Multi-function learning curves
export plot_multifunction_learning_curves

# Export policy evolution visualization functions
export plot_action_ratio_evolution, plot_action_stacked_area
export plot_state_action_heatmap, plot_policy_evolution_comparison
export plot_episode_decision_timeline

# Export subdivision tree visualization functions
export plot_subdivision_tree, TreeVizStyle, print_tree_summary

# Export 1D polynomial approximation visualization functions
export plot_1d_polynomial_approximation, plot_1d_comparison

# Export 2D partition visualization functions (AMR environments)
export plot_2d_partition, plot_l2_trajectories, PartitionStyle

# Export subdivision partition visualization functions
export plot_subdivision_partition,
    plot_subdivision_on_levelset,
    plot_subdivision_on_levelset_from_bounds,
    SubdivisionPartitionStyle
export format_degree_label, effective_degree, min_degree
export CP_TYPE_TABLE, cp_type_appearance, normalize_cp_key

# Export Morse-aware slider helpers (pure numeric, backend-agnostic)
export morse_slider_levels, adaptive_shell_levels

# Export subdivision error heatmap functions
export plot_subdivision_error_heatmap, find_containing_leaf, compute_error_grid

# Export interactive error explorer
export interactive_error_explorer

# Export interactive levelset explorer
export interactive_levelset_explorer

# Export capture analysis visualization
export plot_capture_convergence, plot_capture_sparsification_combined

# Export refinement trajectory visualization
export plot_refinement_trajectories!, RefinementTrajectoryStyle

# Export LV4D plotting functions
export plot_lv4d_l2_convergence, plot_lv4d_recovery_convergence
export plot_lv4d_convergence_rate, plot_lv4d_convergence_multi_degree
export plot_lv4d_degree_comparison, plot_lv4d_metrics_heatmap
export plot_lv4d_gn_comparison
export plot_lv4d_l2_by_degree, plot_lv4d_recovery_by_degree
export plot_parameter_comparison

# Package version
const VERSION = v"0.1.0"

# Initialize the module
function __init__()
    @debug "GlobtimPlots.jl loaded. Extensions will be available when backend packages are loaded."
end

end # module GlobtimPlots

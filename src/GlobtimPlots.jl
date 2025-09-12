module GlobtimPlots

# Include abstract interfaces
include("interfaces.jl")

# Include core plotting functionality
include("graphs_cairo.jl")
include("graphs_makie.jl")
# include("InteractiveVizCore.jl")  # Deactivated - documentation functionality
# include("InteractiveViz.jl")      # Deactivated - documentation functionality

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
export plot_hessian_norms, plot_condition_numbers, plot_critical_eigenvalues
export plot_all_eigenvalues, plot_raw_vs_refined_eigenvalues
export plot_error_function_1D_with_critical_points, plot_error_function_2D_with_critical_points

# Export utility functions
export transform_coordinates, points_in_hypercube
export analyze_convergence_distances, analyze_captured_distances
export capture_histogram, create_legend_figure, histogram_enhanced, histogram_minimizers_only

# Package version
const VERSION = v"0.1.0"

# Core plotting functionality will be loaded through extensions
# when the appropriate backend packages are loaded

function __init__()
    @info "GlobtimPlots.jl loaded. Extensions will be available when backend packages are loaded."
end

end # module GlobtimPlots
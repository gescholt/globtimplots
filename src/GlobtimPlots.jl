module GlobtimPlots

using GLMakie

export plot_polyapprox_3d, plot_polyapprox_levelset, plot_polyapprox_rotate
export plot_polyapprox_animate, plot_polyapprox_flyover, plot_polyapprox_animate2
export plot_level_set, plot_polyapprox_levelset_2D
export cairo_plot_polyapprox_levelset, plot_convergence_analysis, plot_discrete_l2
export plot_filtered_y_distances, plot_distance_statistics, plot_convergence_captured
export plot_hessian_norms, plot_condition_numbers, plot_critical_eigenvalues
export plot_all_eigenvalues, plot_raw_vs_refined_eigenvalues
export plot_error_function_1D_with_critical_points, plot_error_function_2D_with_critical_points

# Package version
const VERSION = v"0.1.0"

# Core plotting functionality will be loaded through extensions
# when the appropriate backend packages are loaded

function __init__()
    @info "GlobtimPlots.jl loaded. Extensions will be available when backend packages are loaded."
end

end # module GlobtimPlots
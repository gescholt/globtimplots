# API Reference

```@meta
CurrentModule = GlobtimPlots
```

## Core Functions

```@autodocs
Modules = [GlobtimPlots]
```

## CairoMakie Extension

Static plotting functions for publication-quality output.

### Level Set Plots
- `cairo_plot_polyapprox_levelset` - Main level set visualization
- `plot_polyapprox_levelset_2D` - 2D level set variant

### Statistical Analysis
- `plot_convergence_analysis` - Convergence analysis plots  
- `plot_discrete_l2` - L2 norm visualization
- `plot_filtered_y_distances` - Distance analysis
- `plot_distance_statistics` - Statistical distance plots
- `plot_convergence_captured` - Captured point analysis

### Eigenvalue Analysis
- `plot_hessian_norms` - Hessian visualization
- `plot_condition_numbers` - Condition number plots
- `plot_critical_eigenvalues` - Eigenvalue analysis
- `plot_all_eigenvalues` - Complete eigenvalue spectrum
- `plot_raw_vs_refined_eigenvalues` - Refinement comparison

## GLMakie Extension

Interactive and 3D plotting functions.

### 3D Visualization
- `plot_polyapprox_3d` - 3D surface visualization
- `plot_polyapprox_levelset` - Interactive level sets
- `plot_level_set` - Core level set plotting

### Animation
- `plot_polyapprox_rotate` - Rotation animations
- `plot_polyapprox_animate` - Animation sequences  
- `plot_polyapprox_flyover` - Flyover animations
- `plot_polyapprox_animate2` - Advanced animations

### Error Visualization
- `plot_error_function_1D_with_critical_points` - 1D error visualization
- `plot_error_function_2D_with_critical_points` - 2D error visualization
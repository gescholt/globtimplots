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

## Subdivision Visualization

Functions for visualizing adaptive subdivision experiments.

### Domain Partition
- `plot_subdivision_partition` - 2D domain partition with convergence coloring, CPs, and degree labels
- `SubdivisionPartitionStyle` - Style configuration for partition plots

### Level Set Overlay
- `plot_subdivision_on_levelset` - Objective function contours with subdivision boundaries and CPs overlaid (tree-based; runtime only)
- `plot_subdivision_on_levelset_from_bounds` - Same plot built from serialized leaf bounds + L2 errors (works from JSON results, no tree needed)

### Error Heatmap
- `plot_subdivision_error_heatmap` - Per-cell polynomial approximation error on a fine grid
- `compute_error_grid` - Build error grid from tree and objective function
- `find_containing_leaf` - Look up which leaf contains a query point

### Interactive Error Explorer
- `interactive_error_explorer` - GLMakie zoom-refine explorer with reset and log/linear toggle

### Utilities
- `format_degree_label` - Format polynomial degree for display
- `effective_degree` - Compute effective degree from leaf data
- `min_degree` - Minimum degree across leaves

## Subdivision Tree

- `plot_subdivision_tree` - Tree structure visualization
- `TreeVizStyle` - Style configuration
- `print_tree_summary` - Terminal summary

## 1D Polynomial Approximation

- `plot_1d_polynomial_approximation` - Plot 1D polynomial fit vs true function
- `plot_1d_comparison` - Compare multiple 1D fits

## 2D Partition (AMR)

- `plot_2d_partition` - 2D AMR-style partition visualization
- `plot_l2_trajectories` - L2 error trajectory plots
- `PartitionStyle` - Style configuration

## Capture Analysis

- `plot_capture_convergence` - Convergence of captured critical points
- `plot_capture_sparsification_combined` - Combined capture/sparsification plot

## Refinement Trajectories

- `plot_refinement_trajectories!` - Overlay refinement paths on existing axes
- `RefinementTrajectoryStyle` - Style configuration

## LV4D Plots

Lotka-Volterra 4D convergence and comparison plots.

```@autodocs
Modules = [GlobtimPlots.LV4DPlots]
```
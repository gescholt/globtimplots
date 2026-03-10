"""
LV4D Plotting Module

Visualization tools for Lotka-Volterra 4D parameter estimation experiments.

This module provides publication-quality plots for:
- Convergence rate analysis (log-log plots)
- Degree comparison plots
- Domain × degree heatmaps

All functions accept DataFrames from globtimpostprocessing analysis.
"""
module LV4DPlots

using CairoMakie
using DataFrames
using Statistics: mean, std, quantile
using Printf

# Include plotting modules
include("convergence_plots.jl")
include("comparison_plots.jl")

# Re-export functions
export plot_lv4d_l2_convergence, plot_lv4d_recovery_convergence
export plot_lv4d_convergence_rate, plot_lv4d_convergence_multi_degree
export plot_lv4d_degree_comparison, plot_lv4d_metrics_heatmap
export plot_lv4d_gn_comparison
export plot_lv4d_l2_by_degree, plot_lv4d_recovery_by_degree
export plot_parameter_comparison

end # module LV4DPlots

# GlobtimPlots

Visualization and plotting library for the Globtim global optimization ecosystem.

## Overview

GlobtimPlots provides specialized visualization tools for analyzing polynomial approximation experiments and optimization campaigns:

- **Experiment Results**: L2 convergence, parameter recovery, condition number analysis
- **Campaign Comparisons**: Multi-experiment visualizations with automatic label generation
- **Level Set Visualization**: 3D surface plots, contour plots, animated trajectories
- **Critical Point Analysis**: Parameter space visualization, eigenvalue analysis, Hessian diagnostics

Supports both **interactive** (GLMakie) and **static** (CairoMakie) plotting backends.

## Getting Started

### Installation

GlobtimPlots is **not registered in Julia General**. To use it, set up the entire GlobalOptim ecosystem using the centralized setup repository:

```bash
# Clone the setup repository
git clone git@git.mpi-cbg.de:globaloptim/setup.git GlobalOptim
cd GlobalOptim

# Run automated setup (develops all packages)
julia setup_globaloptim.jl
```

This automatically develops all GlobalOptim packages including GlobtimPlots.

**For detailed instructions**, see the [setup repository](https://git.mpi-cbg.de/globaloptim/setup).

### Manual Development (Alternative)

If you prefer manual setup:

```julia
using Pkg
Pkg.develop(path="/path/to/GlobalOptim/globtimplots")
```

## Quick Start

### Plot Experiment Results

```julia
using GlobtimPlots
using GlobtimPostProcessing

# Load experiment results
campaign = load_campaign_results("experiment_campaign")

# Create interactive plots (GLMakie window)
create_experiment_plots(campaign, Interactive)

# Or save static plots to files
create_experiment_plots(campaign, Static, output_dir="plots/")
```

### Compare Multiple Campaigns

```julia
# Compare different parameter configurations
campaigns = [
    load_campaign_results("campaign_deg6"),
    load_campaign_results("campaign_deg8"),
    load_campaign_results("campaign_deg10")
]
labels = ["Degree 6", "Degree 8", "Degree 10"]

fig = create_campaign_comparison_plot(campaigns, labels)
save_plot("comparison.png", fig, Static)
```

### Visualize Level Sets

```julia
# 3D surface plot of polynomial approximation
fig = plot_polyapprox_3d(polynomial_data, resolution=50)

# 2D level set contours
fig = plot_polyapprox_levelset(polynomial_data, num_levels=20)
```

## Key Functions

### Experiment Visualization
- `plot_experiment_results_interactive()` - Interactive GLMakie window
- `plot_experiment_results_static()` - Static file output
- `create_experiment_plots()` - Unified interface with backend selection

### Campaign Analysis
- `create_campaign_comparison_plot()` - Compare multiple campaigns
- `generate_experiment_labels()` - Auto-generate informative labels
- `create_single_plot()` - Individual metric visualization

### Level Set & Surfaces
- `plot_polyapprox_3d()` - 3D surface visualization
- `plot_polyapprox_levelset()` - 2D contour plots
- `plot_level_set()` - Custom level set visualization
- `create_level_set_animation()` - Animated trajectories

### Critical Point Analysis
- `plot_convergence_analysis()` - L2 error vs degree
- `plot_condition_numbers()` - Numerical conditioning
- `plot_critical_eigenvalues()` - Hessian eigenvalue analysis
- `plot_hessian_norms()` - Matrix norm diagnostics

## Dependencies

**Core Plotting:**
- CairoMakie (static plots)
- GLMakie (interactive plots)

**Data Handling:**
- DataFrames, CSV
- JSON3
- Statistics, LinearAlgebra

**Globtim Ecosystem:**
- GlobtimPostProcessing (for `ExperimentResult` and `CampaignResults` types)

**Note:** GlobtimPlots is designed to be **independent of globtimcore** to avoid circular dependencies.

## Architecture

GlobtimPlots sits at the visualization layer of the Globtim ecosystem:

```
globtimcore → GlobtimPostProcessing → GlobtimPlots
   (compute)      (data structures)     (visualization)
```

This separation allows:
- Clean dependency hierarchy (no circular deps)
- Independent testing and development
- Flexible plotting without core algorithm changes

## Testing

```bash
cd globtimplots
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Related Packages

- [globtimcore](https://git.mpi-cbg.de/globaloptim/globtimcore) - Core optimization algorithms
- [GlobtimPostProcessing](https://git.mpi-cbg.de/globaloptim/globtimpostprocessing) - Experiment data structures and analysis
- [GlobtimHPC](https://git.mpi-cbg.de/globaloptim/globtimhpc) - HPC deployment infrastructure
- [globtim-integration-tests](https://git.mpi-cbg.de/globaloptim/globtim-integration-tests) - Cross-package integration testing

## Contact & Issues

- **Issues:** https://git.mpi-cbg.de/globaloptim/globtimplots/-/issues
- **Maintainer:** Georgy Scholten

## License

GPL-3.0 - See [LICENSE](../globtimcore/LICENSE) for details.

---

**Note:** VegaLite and Tidier-based plotting functions are temporarily disabled due to dependency conflicts. These will be re-enabled once compatibility is resolved.

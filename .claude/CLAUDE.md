# GlobtimPlots Package Memory

## CRITICAL: GitLab Authentication Setup

**⚠️ MUST READ FIRST - Required for all GitLab operations**

This repository has its **own dedicated bot account**, separate from globtimcore:

- **GitLab Project ID**: 2854
- **Bot Account**: `project_2854_bot_c0773f578a34233c0cd413c32b641f19`
- **Authentication Method**: `.glab-env` file (must be sourced before using `glab`)

**Before running ANY glab commands:**
```bash
cd /Users/ghscholt/GlobalOptim/globtimplots
source .glab-env  # Sets GITLAB_TOKEN environment variable
glab issue list   # Now works with project 2854
```

**Files:**
- `.glab-env` - Tracked in git, sources the private token file
- `.env.gitlab.local` - Gitignored, contains actual `GITLAB_PRIVATE_TOKEN`
- `.env.gitlab.local.template` - Template for setting up the token

**Setup for new clones:**
1. Clone repository
2. Copy `.env.gitlab.local.template` to `.env.gitlab.local`
3. Add the bot's API token to `.env.gitlab.local`
4. Run `source .glab-env` before using glab

**Critical Notes:**
- The globtimcore bot (`project_2859_bot`) does NOT have access to this project
- Token is stored in `.env.gitlab.local` (gitignored for security)
- Must source `.glab-env` in each new shell session
- Without authentication, all glab commands will fail with 404 errors

## Project Information

**Repository**: `git@git.mpi-cbg.de:globaloptim/globtimplots.git`
**GitLab URL**: https://git.mpi-cbg.de/globaloptim/globtimplots
**Local Path**: `/Users/ghscholt/GlobalOptim/globtimplots`
**Package Name**: `GlobtimPlots`

## Package Purpose

**GlobtimPlots is the VISUALIZATION LAYER** - all plotting, graphing, and visual output for the Global Optimization Toolkit. This package creates publication-quality static figures and interactive visualizations from globtimcore experiment results.

## Critical Design Principle: VISUALIZATION ONLY

🚨 **This package is ONLY for plotting** 🚨

**What this means:**
- ✅ Create plots, figures, visualizations
- ✅ Support multiple backends (CairoMakie, GLMakie)
- ✅ Style and theme management
- ❌ NO core optimization algorithms
- ❌ NO statistical analysis (that's globtimpostprocessing)
- ❌ NO experiment execution (that's globtimcore)

## What BELONGS in globtimplots

✅ **Plotting Functions:**
- Level set visualizations
- Convergence plots
- Critical point scatter plots
- Heatmaps and contour plots
- Histogram and distribution plots
- Parameter space visualizations
- Multi-experiment comparison plots

✅ **Visualization Backends:**
- CairoMakie (static, publication-quality)
- GLMakie (interactive, GPU-accelerated)
- Backend switching and management

✅ **Styling and Themes:**
- Color schemes
- Publication-quality formatting
- Font management
- Layout composition
- Legend handling

✅ **Interactive Visualizations:**
- Interactive sliders
- Zoom and pan functionality
- Real-time parameter exploration
- Animation generation

✅ **Plot Export:**
- PDF, PNG, SVG output
- High-DPI rendering
- Batch plot generation
- Custom size/resolution handling

✅ **Allowed Dependencies:**
- CairoMakie, GLMakie, WGLMakie - Plotting backends
- Makie - Core plotting framework
- Colors, ColorSchemes, ColorBrewer - Color management
- FileIO, ImageIO - Image export
- DataFrames - Data input (from globtimcore/globtimpostprocessing)

## What DOES NOT belong in globtimplots

❌ **Core Optimization Algorithms:**
- Polynomial approximation → Use `globtimcore`
- Critical point solving → Use `globtimcore`
- Grid construction → Use `globtimcore`
- Optimization routines → Use `globtimcore`

❌ **Statistical Analysis:**
- Computing statistics → Use `globtimpostprocessing`
- Campaign aggregation → Use `globtimpostprocessing`
- Parameter recovery analysis → Use `globtimpostprocessing`
- Quality diagnostics → Use `globtimpostprocessing`

❌ **Data Loading:**
- Loading experiment results → Use `globtimpostprocessing`
- Parsing JSON/CSV → Use `globtimpostprocessing`
- Result validation → Use `globtimpostprocessing`

❌ **Experiment Execution:**
- Running experiments → Use `globtimcore`
- Evaluating objectives → Use `globtimcore`

## Architecture: Separation of Concerns

```
┌─────────────────────────────────────────┐
│         globtimcore                     │
│  (Runs experiments, exports data)       │
│  - Executes optimization                │
│  - Exports DataFrames/CSV/JSON          │
└─────────────────────────────────────────┘
           │
           │ produces data
           ▼
┌─────────────────────────────────────────┐
│    globtimpostprocessing                │
│  (Analyzes data, computes statistics)   │
│  - Loads results                        │
│  - Computes statistics                  │
│  - Returns DataFrames with analysis     │
└─────────────────────────────────────────┘
           │
           │ analysis results
           ▼
┌─────────────────────────────────────────┐
│         globtimplots (THIS PACKAGE)     │
│  (Visualizes data and analysis)         │
│  - Takes DataFrames as input            │
│  - Creates plots                        │
│  - Exports figures                      │
└─────────────────────────────────────────┘
```

## Dependency on globtimcore

**Very Limited Dependency:**

This package depends on globtimcore ONLY for:
- Data structure types (e.g., `test_input`, if needed)
- Reading exported CSV/JSON files

**Key principle**: NO circular dependency. GlobtimPlots can import globtimcore data structures, but globtimcore never imports GlobtimPlots.

## Recent Changes (October 2025)

### Circular Dependency Removal
- Removed `Globtim` from Project.toml dependencies (it was only in deps, never actually imported)
- Added `CairoMakie` dependency

**Rationale**: Eliminated circular dependency that prevented package precompilation. Plotting package should never be imported by the core computation package.

## Repository Structure

```
globtimplots/
├── src/
│   ├── GlobtimPlots.jl           # Main module
│   ├── graphs_cairo.jl           # CairoMakie static plots
│   ├── graphs_makie.jl           # GLMakie interactive plots
│   ├── comparison_plots.jl       # Multi-experiment comparisons
│   ├── InteractiveViz.jl         # Interactive visualization tools
│   └── plot_utils.jl             # Shared utilities
├── examples/
│   ├── basic_plots.jl            # Basic plotting examples
│   ├── interactive_demo.jl       # Interactive visualization demos
│   └── publication_quality.jl    # Publication-ready figures
├── test/
│   └── runtests.jl               # Test suite
├── Project.toml                  # Dependencies (includes CairoMakie)
└── README.md
```

## Typical Workflow

```julia
using GlobtimPlots
using GlobtimPostProcessing
using DataFrames

# 1. Load and analyze data (using globtimpostprocessing)
results = load_experiment_results("path/to/experiment")
stats = compute_statistics(results)

# 2. Create plots (using globtimplots)
CairoMakie.activate!()  # For static plots

# Plot critical points
fig_points = plot_critical_points(results.critical_points)
save("critical_points.pdf", fig_points)

# Plot convergence
fig_conv = plot_convergence(stats)
save("convergence.pdf", fig_conv)

# For interactive exploration
GLMakie.activate!()
interactive_viz = create_interactive_viewer(results)
```

## Key Design Principles

1. **Standardized Inputs**: Functions accept DataFrames and standard data structures
2. **Multiple Backends**: Support both CairoMakie (static) and GLMakie (interactive)
3. **Reproducible Outputs**: Same data → same plots
4. **Publication Quality**: High-DPI, customizable styling
5. **No Side Effects**: Plotting functions are pure (no data modification)

## Decision Framework

**Before adding ANY new feature, ask:**

1. **Is this feature about creating visual output?**
   - Yes → Add to globtimplots ✅
   - No → **STOP!** Wrong package

2. **Does it require Makie or other plotting libraries?**
   - Yes → Perfect for globtimplots ✅
   - No → Probably wrong package

3. **Is it a core algorithm or statistical computation?**
   - Yes → **STOP!** Use globtimcore or globtimpostprocessing
   - No → Could be in globtimplots

4. **Does it produce numerical results?**
   - Yes → **STOP!** Use globtimpostprocessing for analysis
   - No, only visual output → Perfect for globtimplots ✅

## Examples

| Feature | Correct Package | Why |
|---------|----------------|-----|
| Convergence line plot | globtimplots | Visualization ✅ |
| Compute convergence rate | globtimpostprocessing | Statistics |
| Interactive parameter slider | globtimplots | Interactive viz ✅ |
| Load experiment CSV | globtimpostprocessing | Data loading |
| Level set contour plot | globtimplots | Visualization ✅ |
| Polynomial approximation | globtimcore | Core algorithm |
| Heatmap of objective values | globtimplots | Visualization ✅ |
| Detect stagnation | globtimpostprocessing | Analysis |
| 3D scatter plot | globtimplots | Visualization ✅ |
| BFGS optimization | globtimcore | Core algorithm |

## Common Plot Types

```julia
# Level set visualization
plot_levelset(polynomial, test_input, critical_points)

# Convergence analysis
plot_convergence(degrees, l2_errors)

# Critical point scatter
plot_critical_points(df_points, color_by=:type)

# Multi-degree comparison
plot_degree_comparison(results_dict)

# Parameter space exploration
plot_parameter_space(objective_func, ranges)

# Distance statistics
plot_distance_statistics(stats)

# Interactive exploration
create_interactive_viewer(results)
```

## Testing

```bash
# Run tests
cd /Users/ghscholt/GlobalOptim/globtimplots
julia --project=. -e 'using Pkg; Pkg.test()'

# Check precompilation
julia --project=. -e 'using GlobtimPlots'

# Verify CairoMakie is available
julia --project=. -e 'using CairoMakie; CairoMakie.activate!()'

# Test plot generation
julia --project=. examples/basic_plots.jl
```

## Notes for Claude Code

**When asked to add visualization features:**
1. ✅ Add to this package - it's designed for plotting
2. ✅ Can use Makie, CairoMakie, GLMakie
3. ✅ Functions should accept DataFrames or standard data structures
4. ❌ Do NOT add core algorithms (use globtimcore)
5. ❌ Do NOT add statistical analysis (use globtimpostprocessing)
6. ❌ Do NOT create circular dependency with globtimcore

**When creating new plots:**
```julia
# CORRECT: Pure plotting function
function plot_convergence(degrees::Vector, errors::Vector)
    fig = Figure()
    ax = Axis(fig[1,1], xlabel="Degree", ylabel="L2 Error")
    lines!(ax, degrees, errors)
    return fig
end

# WRONG: Don't compute statistics in plotting code
function plot_convergence(results::Dict)
    # ❌ Statistical computation doesn't belong here
    errors = [compute_error(r) for r in values(results)]
    # This should be done in globtimpostprocessing first
end
```

**Proper workflow:**
```julia
# Step 1: Analysis (globtimpostprocessing)
stats = compute_convergence_stats(results)  # Returns DataFrame

# Step 2: Plotting (globtimplots)
fig = plot_convergence(stats.degrees, stats.errors)  # Just plots data
```

## Related Documentation

- See `/Users/ghscholt/GlobalOptim/.claude/CLAUDE.md` for overall package structure
- See `globtimcore/.claude/CLAUDE.md` for core algorithm guidelines
- See `globtimpostprocessing/.claude/CLAUDE.md` for analysis guidelines

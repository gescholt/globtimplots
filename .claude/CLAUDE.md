# GlobtimPlots Project Memory

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

## Purpose

GlobtimPlots is the dedicated visualization package for the Global Optimization Toolkit (globtimcore). It maintains architectural separation between computation (globtimcore) and visualization (globtimplots).

## Key Design Principles

1. **No plotting in globtimcore**: Keeps core package lightweight and HPC-compatible
2. **Standardized inputs**: Reads JSON/CSV outputs from globtimcore experiments
3. **Multiple backends**: CairoMakie (static) and GLMakie (interactive)
4. **Reproducible outputs**: Same data → same plots
5. **Publication quality**: High-DPI, customizable styling

## Repository Structure

- `src/` - Core plotting modules
  - `graphs_cairo.jl` - CairoMakie static plots
  - `graphs_makie.jl` - GLMakie interactive plots
  - `comparison_plots.jl` - Multi-experiment comparisons
  - `InteractiveViz.jl` - Interactive visualization tools
- `examples/` - Example scripts for common plotting tasks
- `docs/` - Documentation and workflow guides
- `test/` - Test suite
- `tools/` - Utility scripts

## Upstream Repository

This repository is part of the GlobalOptim organization on the MPI-CBG GitLab instance.

## Related Repositories

- **globtimcore**: Core computation package (produces data)
- **globtimpostprocessing**: Post-processing analysis tools

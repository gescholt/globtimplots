# Changelog

All notable changes to GlobtimPlots.jl are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-04-30

Initial public release.

### Added

- Visualization layer for [Globtim.jl](https://github.com/gescholt/Globtim.jl) and [GlobtimPostProcessing.jl](https://github.com/gescholt/GlobtimPostProcessing.jl), built on the Makie ecosystem.
- **Critical-point and refinement plots** — scatter, level-set overlays, gradient-norm validation visualizations.
- **Convergence diagnostics** — L2 error vs. polynomial degree, residual decomposition, sample-reuse provenance.
- **Campaign comparisons** — multi-run side-by-side rendering for parameter-sweep studies.
- **Domain visualizations** — subdivision tree rendering, anisotropic-grid overlays, refinement boxes.
- **Backend extensions** (weakdeps):
  - `GlobtimDataExt` (`CSV`) — DataFrame loaders for campaign result imports.
  - `GlobtimGLMakieExt` (`GLMakie` + `DynamicPolynomials` + `Parameters`) — interactive 3D plots and polynomial visualization.
  - `GlobtimWGLMakieExt` (`WGLMakie`) — browser-rendered interactive plots for share-able UIs.

### Notes

- `CairoMakie` is the default backend (publication-quality static figures).
- `GLMakie` and `WGLMakie` are weak dependencies. Load them to activate interactive backends.
- Julia 1.12+ required.

# GlobtimPlots.jl

A Julia package for advanced plotting and visualization of global optimization algorithms and polynomial approximations.

## Overview

GlobtimPlots.jl provides a comprehensive suite of plotting functions for:

- **Level Set Visualization**: Interactive and static level set plots
- **3D Surface Plots**: Advanced 3D surface visualization with rotation and animation
- **Convergence Analysis**: Statistical analysis and visualization of algorithm convergence
- **Eigenvalue Analysis**: Specialized plots for Hessian eigenvalues and condition numbers
- **Error Function Visualization**: 1D and 2D error function plots with critical points

## Features

### Static Plotting (CairoMakie Backend)
- High-quality publication-ready plots
- Level set visualization
- Convergence analysis plots
- Statistical distribution plots
- Eigenvalue spectrum analysis

### Interactive Plotting (GLMakie Backend)  
- Real-time 3D surface visualization
- Interactive level sets
- Animation sequences
- Camera flyover animations
- Real-time algorithm tracking

## Installation

```julia
using Pkg
Pkg.add(url="https://git.mpi-cbg.de/globaloptim/globtimplots.git")
```

## Quick Start

```julia
using GlobtimPlots

# Load backend for plotting
using GLMakie  # For interactive plots
using CairoMakie  # For static plots

# Your plotting code here
```

## Migration from Globtim

This package extracts plotting functionality from the main Globtim package to provide:
- Cleaner separation of concerns  
- Reduced dependencies in core optimization code
- Extensible plotting system
- Better maintainability

See the [Migration Guide](migration.md) for detailed migration instructions.
# Migration Guide

This guide helps you migrate from using plotting functions in the main Globtim package to using GlobtimPlots.jl.

## Quick Migration

### Before (Globtim)
```julia
using Globtim
using CairoMakie

# Plotting functions were part of Globtim
plot_polyapprox_levelset(poly, input)
```

### After (GlobtimPlots)
```julia
using GlobtimPlots
using CairoMakie  # Load the backend

# Same function names, now in dedicated package
plot_polyapprox_levelset(poly, input) 
```

## Key Changes

1. **Separate Package**: Plotting functions are now in a dedicated package
2. **Extension System**: Backend packages (CairoMakie, GLMakie) are loaded as extensions
3. **Same API**: Function names and signatures remain unchanged
4. **Cleaner Dependencies**: Main optimization code no longer depends on plotting packages

## Migration Phases

Based on the complexity assessment, migrate in this order:

### Phase 1: Low Complexity Functions
- Statistical plotting functions
- Basic 2D level set plots  
- Convergence analysis plots

### Phase 2: Medium Complexity Functions
- 3D surface visualization
- Interactive level sets
- Eigenvalue analysis plots

### Phase 3: High Complexity Functions
- Animation systems
- Interactive algorithm tracking
- Real-time convergence monitoring
- Tightly coupled mathematical visualizations

## Common Migration Issues

### Extension Loading
Make sure to load the appropriate backend:

```julia
using GlobtimPlots
using CairoMakie  # For static plots
# or
using GLMakie     # For interactive plots
```

### Data Structure Compatibility
The package expects the same data structures:
- `ApproxPoly{T,S}` - Polynomial approximation data
- `test_input` - Problem domain configuration
- `DataFrame` - Critical points and analysis results  
- `LevelSetData{T}` - Level set visualization data

### Coordinate Transformations
Coordinate transformation utilities should be handled by your data preparation code before calling plotting functions.

## Testing Your Migration

1. Install GlobtimPlots: `using Pkg; Pkg.add(url="https://git.mpi-cbg.de/globaloptim/globtimplots.git")`
2. Load appropriate backend: `using CairoMakie` or `using GLMakie`
3. Test basic plotting: `using GlobtimPlots; # your plotting code`
4. Run your existing test suite to ensure compatibility

## Getting Help

If you encounter issues during migration:
1. Check that the appropriate backend is loaded
2. Verify your data structures match the expected formats
3. Consult the API documentation for function signatures
4. Open an issue on the GitLab repository
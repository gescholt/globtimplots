# Abstract interfaces for GlobtimPlots.jl
# These interfaces allow the package to work independently of Globtim types

using DataFrames
using LinearAlgebra

# ── Canonical CP type appearance ──────────────────────────────────────────────
# Single source of truth for CP type → (color, marker, label) across all viz.

"""
    CP_TYPE_TABLE

Canonical named tuple mapping CP type keys (`:min`, `:saddle`, `:max`) to
their visual appearance `(color, marker, label)`.  All visualization code
should use this table (or the `cp_type_appearance` helper) instead of
defining local color/marker constants.
"""
const CP_TYPE_TABLE = (
    min    = (color = :green3,     marker = :circle,    label = "Min"),
    saddle = (color = :dodgerblue, marker = :dtriangle, label = "Saddle"),
    max    = (color = :red,        marker = :rect,      label = "Max"),
)

"""
    normalize_cp_key(k::Symbol) → Symbol

Normalize verbose CP type keys to the canonical short form used by
`CP_TYPE_TABLE`:  `:minimum` → `:min`,  `:maximum` → `:max`.
All other keys pass through unchanged.
"""
function normalize_cp_key(k::Symbol)
    k === :minimum && return :min
    k === :maximum && return :max
    return k
end
normalize_cp_key(k::AbstractString) = normalize_cp_key(Symbol(k))

"""
    cp_type_appearance(cp_type) → (color::Symbol, marker::Symbol)

Look up color and marker for a CP type (Symbol or String).
Accepts both short (`:min`) and long (`:minimum`) key forms.
Returns `(:magenta, :diamond)` for unknown types.
"""
function cp_type_appearance(cp_type::Symbol)
    key = normalize_cp_key(cp_type)
    haskey(CP_TYPE_TABLE, key) || return (:magenta, :diamond)
    entry = CP_TYPE_TABLE[key]
    return (entry.color, entry.marker)
end
cp_type_appearance(cp_type::AbstractString) = cp_type_appearance(Symbol(cp_type))

# Core abstract types

"""
    AbstractPolynomialData

Abstract type for polynomial approximation data used in visualization.

Subtypes should provide access to polynomial coefficients, basis information,
and grid data needed for plotting level sets and surfaces.

See also: [`GenericPolynomialData`](@ref), [`adapt_polynomial_data`](@ref)
"""
abstract type AbstractPolynomialData end

"""
    AbstractProblemInput

Abstract type for problem input data used in visualization.

Subtypes should provide dimension, center, and domain range information
needed for coordinate transformations in plots.

See also: [`GenericProblemInput`](@ref), [`adapt_problem_input`](@ref)
"""
abstract type AbstractProblemInput end

"""
    AbstractCriticalPointData

Abstract type for critical point data used in visualization.

Subtypes should provide critical point locations and classifications
for scatter plots and overlays.
"""
abstract type AbstractCriticalPointData end

# Default implementations for common data structures

"""
    GenericPolynomialData <: AbstractPolynomialData

Concrete implementation of polynomial data for plotting.

# Fields
- `coeffs::Any`: Polynomial coefficients
- `basis::Symbol`: Basis type (`:chebyshev`, `:monomial`, etc.), default `:chebyshev`
- `scale_factor::Union{Float64, Vector{Float64}}`: Domain scaling factor(s), default `1.0`
- `grid::Matrix{Float64}`: Evaluation grid points
- `z::Vector{Float64}`: Function values at grid points
- `precision::Any`: Numerical precision information
- `normalized::Bool`: Whether the approximation is normalized, default `false`

See also: [`AbstractPolynomialData`](@ref), [`adapt_polynomial_data`](@ref)
"""
Base.@kwdef struct GenericPolynomialData <: AbstractPolynomialData
    coeffs::Any
    basis::Symbol = :chebyshev
    scale_factor::Union{Float64, Vector{Float64}} = 1.0
    grid::Matrix{Float64} = Matrix{Float64}(undef, 0, 0)
    z::Vector{Float64} = Float64[]
    precision::Any = nothing
    normalized::Bool = false
end

"""
    GenericProblemInput <: AbstractProblemInput

Concrete implementation of problem input data for plotting.

# Fields
- `dim::Int`: Problem dimension (number of variables), default `2`
- `center::Vector{Float64}`: Domain center point, default `[0.0, 0.0]`
- `sample_range::Union{Float64, Vector{Float64}}`: Domain sampling range(s), default `1.0`

See also: [`AbstractProblemInput`](@ref), [`adapt_problem_input`](@ref)
"""
Base.@kwdef struct GenericProblemInput <: AbstractProblemInput
    dim::Int = 2
    center::Vector{Float64} = [0.0, 0.0]
    sample_range::Union{Float64, Vector{Float64}} = 1.0
end

# Helper function to extract coordinates from coordinate data
function transform_coordinates(scale_factor::Union{Float64, Vector{Float64}}, grid::Matrix, center::Vector)
    # Default implementation - scale and translate grid points
    coords = similar(grid)
    for i in axes(grid, 1)
        coords[i, :] = scale_factor .* grid[i, :] .+ center
    end
    return coords
end

# Helper function to check if points are in domain
function points_in_hypercube(points::Matrix, bounds::Tuple)
    # Simple bounds checking
    all(p -> all(bounds[1] .<= p .<= bounds[2]), eachrow(points))
end

"""
    adapt_polynomial_data(globtim_poly) → GenericPolynomialData

Adapt a polynomial approximation object to the GlobtimPlots plotting interface.

This function extracts common fields from polynomial types (like `ApproxPoly` from globtim)
and wraps them in `GenericPolynomialData` which implements the `AbstractPolynomialData` interface.

# Why Use This?

This adapter maintains clean package separation:
- `globtim` defines concrete types (`ApproxPoly`) without depending on plotting packages
- `globtimplots` defines abstract interfaces (`AbstractPolynomialData`)
- Users explicitly convert when crossing package boundaries

# Arguments
- `globtim_poly`: Any object with polynomial approximation data (typically `ApproxPoly`)

# Extracted Fields
- `coeffs`: Polynomial coefficients
- `basis`: Basis type (`:chebyshev`, `:monomial`, etc.)
- `scale_factor`: Domain scaling factor
- `grid`: Evaluation grid points (Matrix)
- `z`: Function values at grid points
- `precision`: Numerical precision information
- `normalized`: Whether the approximation is normalized

# Returns
- `GenericPolynomialData <: AbstractPolynomialData`: Wrapped data for plotting

# Example
```julia
using Globtim
using GlobtimPlots: adapt_polynomial_data

# Create polynomial approximation in globtim
pol = ApproxPoly(...)

# Adapt for plotting
pol_adapted = adapt_polynomial_data(pol)

# Now can use with plotting functions
fig = cairo_plot_polyapprox_levelset(pol_adapted, ...)
```

See also: [`adapt_problem_input`](@ref), [`GenericPolynomialData`](@ref), [`AbstractPolynomialData`](@ref)
"""
function adapt_polynomial_data(globtim_poly)
    # Extract common fields that plotting functions need
    GenericPolynomialData(
        coeffs = hasfield(typeof(globtim_poly), :coeffs) ? globtim_poly.coeffs : nothing,
        basis = hasfield(typeof(globtim_poly), :basis) ? globtim_poly.basis : :chebyshev,
        scale_factor = hasfield(typeof(globtim_poly), :scale_factor) ? globtim_poly.scale_factor : 1.0,
        grid = hasfield(typeof(globtim_poly), :grid) ? globtim_poly.grid : Matrix{Float64}(undef, 0, 0),
        z = hasfield(typeof(globtim_poly), :z) ? globtim_poly.z : Float64[],
        precision = hasfield(typeof(globtim_poly), :precision) ? globtim_poly.precision : nothing,
        normalized = hasfield(typeof(globtim_poly), :normalized) ? globtim_poly.normalized : false
    )
end

"""
    adapt_problem_input(globtim_input) → GenericProblemInput

Adapt a problem input object to the GlobtimPlots plotting interface.

This function extracts common fields from problem input types (like `TestInput` from globtim)
and wraps them in `GenericProblemInput` which implements the `AbstractProblemInput` interface.

# Why Use This?

This adapter maintains clean package separation:
- `globtim` defines concrete types (`TestInput`) without depending on plotting packages
- `globtimplots` defines abstract interfaces (`AbstractProblemInput`)
- Users explicitly convert when crossing package boundaries

# Arguments
- `globtim_input`: Any object with problem input data (typically `TestInput`)

# Extracted Fields
- `dim`: Problem dimension (number of variables)
- `center`: Domain center point (Vector)
- `sample_range`: Domain sampling range

# Returns
- `GenericProblemInput <: AbstractProblemInput`: Wrapped data for plotting

# Example
```julia
using Globtim
using GlobtimPlots: adapt_problem_input

# Create problem input in globtim
TR = TestInput(
    f = x -> sum(x.^2),
    dim = 2,
    center = [0.0, 0.0],
    sample_range = 2.0,
    degree = 6
)

# Adapt for plotting
tr_adapted = adapt_problem_input(TR)

# Now can use with plotting functions
fig = cairo_plot_polyapprox_levelset(..., tr_adapted, ...)
```

See also: [`adapt_polynomial_data`](@ref), [`GenericProblemInput`](@ref), [`AbstractProblemInput`](@ref)
"""
function adapt_problem_input(globtim_input)
    # Extract common fields that plotting functions need
    GenericProblemInput(
        dim = hasfield(typeof(globtim_input), :dim) ? globtim_input.dim : 2,
        center = hasfield(typeof(globtim_input), :center) ? globtim_input.center : [0.0, 0.0],
        sample_range = hasfield(typeof(globtim_input), :sample_range) ? globtim_input.sample_range : 1.0
    )
end
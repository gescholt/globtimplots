# Abstract interfaces for GlobtimPlots.jl
# These interfaces allow the package to work independently of Globtim types

using DataFrames
using LinearAlgebra

# Core abstract types
abstract type AbstractPolynomialData end
abstract type AbstractProblemInput end
abstract type AbstractCriticalPointData end

# Default implementations for common data structures
Base.@kwdef struct GenericPolynomialData <: AbstractPolynomialData
    coeffs::Any
    basis::Symbol = :chebyshev
    scale_factor::Float64 = 1.0
    grid::Matrix{Float64} = Matrix{Float64}(undef, 0, 0)
    z::Vector{Float64} = Float64[]
    precision::Any = nothing
    normalized::Bool = false
end

Base.@kwdef struct GenericProblemInput <: AbstractProblemInput
    dim::Int = 2
    center::Vector{Float64} = [0.0, 0.0]
    sample_range::Float64 = 1.0
end

# Helper function to extract coordinates from coordinate data
function transform_coordinates(scale_factor::Float64, grid::Matrix, center::Vector)
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

# Adapter functions to work with existing Globtim types
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

function adapt_problem_input(globtim_input)
    # Extract common fields that plotting functions need
    GenericProblemInput(
        dim = hasfield(typeof(globtim_input), :dim) ? globtim_input.dim : 2,
        center = hasfield(typeof(globtim_input), :center) ? globtim_input.center : [0.0, 0.0],
        sample_range = hasfield(typeof(globtim_input), :sample_range) ? globtim_input.sample_range : 1.0
    )
end
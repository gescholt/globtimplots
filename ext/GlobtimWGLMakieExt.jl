module GlobtimWGLMakieExt

using GlobtimPlots
using WGLMakie
using DataFrames

# WGLMakie extension for GlobtimPlots
#
# All plotting functions (hessian/eigenvalue plots, polyapprox_3d core logic)
# live in globtimplots/src/ using the abstract Makie API.  They work with any
# backend — whichever the user has activated via `WGLMakie.activate!()`.
#
# This extension provides the WGLMakie-specific plot_polyapprox_3d method.
# Unlike the GLMakie extension, no rotation animation is supported (WGLMakie
# does not support record()).  The plot is returned as a Figure that WGLMakie
# renders to an interactive WebGL widget.

import GlobtimPlots: AbstractPolynomialData, AbstractProblemInput

"""
    plot_polyapprox_3d(pol, TR, df, df_min; kwargs...) -> Figure

3D polynomial approximation surface with critical points.
WGLMakie backend — produces an interactive WebGL widget in notebooks and
Documenter.jl @example blocks.

Note: The `rotate` and `filename` keyword arguments are accepted for API
compatibility but ignored (WGLMakie does not support `record()`).
"""
function GlobtimPlots.plot_polyapprox_3d(
    pol::AbstractPolynomialData,
    TR::AbstractProblemInput,
    df::DataFrame,
    df_min::DataFrame;
    figure_size::Tuple{Int,Int} = (1000, 800),
    z_limits::Union{Nothing,Tuple{Float64,Float64}} = nothing,
    show_captured::Bool = true,
    alpha_surface::Float64 = 0.7,
    rotate::Bool = false,
    filename::String = "function_3d_rotation.mp4",
    fade::Bool = false,
    z_cut = 0.25,
)
    if rotate
        @warn "WGLMakie does not support record() — ignoring rotate=true. Use GLMakie for animation."
    end

    fig = GlobtimPlots._plot_polyapprox_3d_impl(
        pol,
        TR,
        df,
        df_min;
        figure_size = figure_size,
        z_limits = z_limits,
        show_captured = show_captured,
        alpha_surface = alpha_surface,
        fade = fade,
        z_cut = z_cut,
    )

    return fig
end

function __init__()
    @info "GlobtimPlots: WGLMakie backend loaded — interactive web visualizations available"
end

end

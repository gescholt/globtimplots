# src/plot_1d_approx.jl
#
# 1D polynomial approximation visualization functions.
# Plots original functions alongside their polynomial approximations with critical points.

using DataFrames
using LaTeXStrings

"""
    plot_1d_polynomial_approximation(
        f::Function,
        poly,
        critical_points::DataFrame;
        poly_eval::Function = nothing,
        n_plot_points::Int = 500,
        title::String = "1D Polynomial Approximation",
        show_l2_error::Bool = true,
        save_path::Union{String, Nothing} = nothing,
        figsize::Tuple{Int, Int} = (800, 600)
    ) -> Figure

Plot a 1D function with its polynomial approximation and critical points.

# Arguments
- `f`: Original function (scalar input, scalar output)
- `poly`: ApproxPoly object from globtimcore (used for metadata: center, scale_factor, nrm, degree)
- `critical_points`: DataFrame with `x1` and `z` columns from `process_crit_pts`

# Keyword Arguments
- `poly_eval`: Function to evaluate polynomial at a point `x -> evaluate(poly, [x])`. Required.
- `n_plot_points`: Number of points for smooth curve plotting (default: 500)
- `title`: Plot title
- `show_l2_error`: Whether to annotate L2 approximation error (default: true)
- `func_latex`: LaTeX string for function label in legend (default: "Original f(x)")
- `n_samples`: Number of sample points used in construction (shown as annotation)
- `save_path`: If provided, save figure to this path
- `figsize`: Figure size in pixels (default: (800, 600))

# Returns
- `Figure`: CairoMakie Figure object

# Example
```julia
using Globtim, GlobtimPlots, DynamicPolynomials, DataFrames

f = x -> 0.5 * (x^4 - 16*x^2 + 5*x)
TR = test_input(f, dim=1, center=[0.0], sample_range=5.0, GN=16)
poly = Constructor(TR, 12)

@polyvar x
solutions = solve_polynomial_system(x, poly)
df = process_crit_pts(solutions, f, TR)

fig = plot_1d_polynomial_approximation(
    f, poly, df,
    poly_eval = xi -> evaluate(poly, [xi]),
    title = "Styblinski-Tang 1D"
)
```
"""
function plot_1d_polynomial_approximation(
    f::Function,
    poly,
    critical_points::DataFrame;
    poly_eval::Union{Function, Nothing} = nothing,
    n_plot_points::Int = 500,
    title::String = "1D Polynomial Approximation",
    show_l2_error::Bool = true,
    func_latex::Union{LaTeXString, Nothing} = nothing,
    n_samples::Union{Int, Nothing} = nothing,
    save_path::Union{String, Nothing} = nothing,
    figsize::Tuple{Int, Int} = (800, 600)
)
    # Validate poly_eval is provided
    if isnothing(poly_eval)
        error("poly_eval function is required. Pass: poly_eval = xi -> evaluate(poly, [xi])")
    end

    # Extract domain from poly metadata
    center = poly.center[1]
    scale = isa(poly.scale_factor, Number) ? poly.scale_factor : poly.scale_factor[1]
    x_min = center - scale
    x_max = center + scale

    # Create plotting grid
    x_plot = collect(range(x_min, x_max, length=n_plot_points))

    # Evaluate original function and polynomial
    y_original = [f(xi) for xi in x_plot]
    y_poly = [poly_eval(xi) for xi in x_plot]

    # Extract degree for legend
    degree_str = _extract_degree_string(poly)

    # Create figure
    fig = Figure(size=figsize, fontsize=14)

    # Main plot axis
    ax = Axis(
        fig[1, 1],
        xlabel = "x",
        ylabel = "f(x)",
        title = title,
        xgridvisible = true,
        ygridvisible = true,
        xgridstyle = :dash,
        ygridstyle = :dash,
        xgridcolor = (:gray, 0.3),
        ygridcolor = (:gray, 0.3)
    )

    # Plot original function
    original_label = isnothing(func_latex) ? "Original f(x)" : func_latex
    lines!(ax, x_plot, y_original,
        color = :blue, linewidth = 2.5, label = original_label)

    # Plot polynomial approximation
    lines!(ax, x_plot, y_poly,
        color = :red, linewidth = 2.0, linestyle = :dash,
        label = "Polynomial (degree $degree_str)")

    # Plot critical points
    if nrow(critical_points) > 0
        scatter!(ax, critical_points.x1, critical_points.z,
            color = :green, markersize = 14, marker = :star5,
            strokecolor = :black, strokewidth = 1.5,
            label = "Critical Points ($(nrow(critical_points)))")
    end

    # Add legend
    axislegend(ax, position = :rt, framevisible = true,
        backgroundcolor = (:white, 0.9), labelsize = 16)

    # Add L2 error and sample count annotations
    y_range = maximum(y_original) - minimum(y_original)
    annotation_y = minimum(y_original) + 0.08*y_range

    if show_l2_error && hasproperty(poly, :nrm)
        l2_text = "L² error: $(round(poly.nrm, sigdigits=3))"
        text!(ax, x_min + 0.03*(x_max-x_min), annotation_y,
            text = l2_text, fontsize = 11, color = :gray60)
        annotation_y -= 0.05*y_range  # Move down for next annotation
    end

    if !isnothing(n_samples)
        samples_text = "Sample set size: $n_samples"
        text!(ax, x_min + 0.03*(x_max-x_min), annotation_y,
            text = samples_text, fontsize = 11, color = :gray60)

        # Show sample points as small ticks at y=0 (Chebyshev nodes)
        # Chebyshev nodes: cos((2i+1)π/(2n+2)) for i=0:n, scaled to domain
        cheb_normalized = [cos(π * (2i + 1) / (2*n_samples + 2)) for i in 0:n_samples]
        x_samples = center .+ scale .* cheb_normalized
        scatter!(ax, x_samples, fill(0.0, length(x_samples)),
            marker = :vline, markersize = 10, color = :gray50)
    end

    # Save if path provided
    if !isnothing(save_path)
        save(save_path, fig)
        @debug "Saved figure to $save_path"
    end

    return fig
end


"""
    plot_1d_comparison(
        f::Function,
        results::Dict{Int, NamedTuple};
        poly_eval_factory::Function,
        n_plot_points::Int = 500,
        figsize::Tuple{Int, Int} = (1200, 400),
        save_path::Union{String, Nothing} = nothing
    ) -> Figure

Create a multi-panel comparison figure showing polynomial approximations at different degrees.

# Arguments
- `f`: Original function (scalar input, scalar output)
- `results`: Dict mapping degree => (poly=..., df=..., TR=...) NamedTuple
- `poly_eval_factory`: Function that takes a poly and returns evaluation function: `poly -> (xi -> evaluate(poly, [xi]))`
- `func_latex`: LaTeX string for function label in legend (default: "Original f(x)")
- `n_samples`: Number of sample points used in construction (shown in legend)

# Returns
- `Figure`: CairoMakie Figure with one panel per degree
"""
function plot_1d_comparison(
    f::Function,
    results::Dict{Int, <:NamedTuple};
    poly_eval_factory::Function,
    n_plot_points::Int = 500,
    func_latex::Union{LaTeXString, Nothing} = nothing,
    n_samples::Union{Int, Nothing} = nothing,
    figsize::Tuple{Int, Int} = (1200, 400),
    save_path::Union{String, Nothing} = nothing
)
    degrees = sort(collect(keys(results)))

    # Extract domain from first result
    first_poly = results[degrees[1]].poly
    center = first_poly.center[1]
    scale = isa(first_poly.scale_factor, Number) ? first_poly.scale_factor : first_poly.scale_factor[1]
    x_min = center - scale
    x_max = center + scale

    x_plot = collect(range(x_min, x_max, length=n_plot_points))
    y_original = [f(xi) for xi in x_plot]

    # Create figure
    fig = Figure(size=figsize, fontsize=12)

    for (i, degree) in enumerate(degrees)
        poly = results[degree].poly
        df = results[degree].df
        poly_eval = poly_eval_factory(poly)

        y_poly = [poly_eval(xi) for xi in x_plot]
        l2_str = round(poly.nrm, sigdigits=2)

        ax = Axis(
            fig[1, i],
            xlabel = "x",
            ylabel = i == 1 ? "f(x)" : "",
            title = "Degree $degree (L²=$l2_str)"
        )

        # Original function
        lines!(ax, x_plot, y_original, color=:blue, linewidth=2)

        # Polynomial approximation
        lines!(ax, x_plot, y_poly, color=:red, linewidth=2, linestyle=:dash)

        # Critical points
        if nrow(df) > 0
            scatter!(ax, df.x1, df.z, color=:green, markersize=10, marker=:star5,
                strokecolor=:black, strokewidth=1)
        end

        # Show sample points as small ticks at y=0 (Chebyshev nodes)
        if !isnothing(n_samples)
            cheb_normalized = [cos(π * (2i + 1) / (2*n_samples + 2)) for i in 0:n_samples]
            x_samples = center .+ scale .* cheb_normalized
            scatter!(ax, x_samples, fill(0.0, length(x_samples)),
                marker = :vline, markersize = 8, color = :gray50)
        end
    end

    # Add legend below all panels
    original_label = isnothing(func_latex) ? "Original f(x)" : func_latex
    samples_label = isnothing(n_samples) ? "" : " ($n_samples samples)"
    Legend(fig[2, :],
        [LineElement(color=:blue, linewidth=2),
         LineElement(color=:red, linewidth=2, linestyle=:dash),
         MarkerElement(color=:green, marker=:star5, markersize=12, strokecolor=:black, strokewidth=1)],
        [original_label, "Polynomial Approx.$samples_label", "Critical Points"],
        orientation = :horizontal,
        framevisible = false,
        labelsize = 14
    )

    # Save if path provided
    if !isnothing(save_path)
        save(save_path, fig)
        @debug "Saved comparison figure to $save_path"
    end

    return fig
end


# Helper function to extract degree string from poly object
function _extract_degree_string(poly)
    if !hasproperty(poly, :degree)
        return "?"
    end

    d = poly.degree
    if d isa Tuple && length(d) >= 2
        if d[1] == :one_d_for_all
            return string(d[2])
        elseif d[1] == :one_d_per_dim
            return string(maximum(d[2]))
        end
    elseif d isa Int
        return string(d)
    end

    return "?"
end

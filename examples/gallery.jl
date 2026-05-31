# gallery.jl
# Regenerate the sample-output gallery used in pkg/globtimplots README and docs.
#
# Run with:
#   julia --project=profiles/viz pkg/globtimplots/examples/gallery.jl
#
# Outputs go to pkg/globtimplots/docs/src/assets/gallery_*.png

using Globtim
using GlobtimPlots
using CairoMakie
using DynamicPolynomials: @polyvar
using HomotopyContinuation
using Optim
using LinearAlgebra: eigvals

const ASSET_DIR = abspath(joinpath(@__DIR__, "..", "docs", "src", "assets"))
isdir(ASSET_DIR) || mkpath(ASSET_DIR)

println("Writing gallery PNGs to: $ASSET_DIR")

# ─────────────────────────────────────────────────────────────────────────────
# 1. Polynomial approximation level-set (Camel 2D, Chebyshev degree 6)
# ─────────────────────────────────────────────────────────────────────────────

println("\n[1/4] Camel 2D level-set + eigenvalue spectrum …")
let
    n, scale_factor = 2, 5.0
    f = camel
    d = 6
    TR = TestInput(f; dim=n, center=[0.0, 0.0], GN=200, sample_range=scale_factor)
    pol = Constructor(TR, d, basis=:chebyshev, precision=RationalPrecision)

    @polyvar x[1:n]
    real_pts = solve_polynomial_system(
        x, n, d, pol.coeffs;
        basis=pol.basis, precision=pol.precision, normalized=pol.normalized,
    )
    df_cp = process_crit_pts(real_pts, f, TR)
    df_cp, df_min = analyze_critical_points(f, df_cp, TR; tol_dist=0.00125)

    apol = adapt_polynomial_data(pol)
    ainp = adapt_problem_input(TR)

    fig = cairo_plot_polyapprox_levelset(apol, ainp, df_cp, df_min; chebyshev_levels=true)
    CairoMakie.save(joinpath(ASSET_DIR, "gallery_polyapprox_levelset.png"), fig; px_per_unit=2)
    println("   → gallery_polyapprox_levelset.png")

    # Full Hessian spectrum per CP: vertical segment from λ_min to λ_max,
    # colored by Morse classification. Stays above y=0 → minimum, below → maximum,
    # crosses → saddle. Camel has f(-x,-y) = f(x,y) symmetry, so CP pairs share
    # (z, λ) coordinates and overlap visually.
    fig_eig = Figure(size=(900, 520), fontsize=14)
    ax = Axis(fig_eig[1, 1];
        xlabel = "Objective value  f(x*)  at critical point",
        ylabel = "Hessian eigenvalues at x*",
        title  = "Camel 2D — full Morse spectrum (λ₁ … λ₂ per critical point)",
    )

    color_for(t) = t == :minimum ? :steelblue :
                   t == :maximum ? :crimson   :
                   t == :saddle  ? :purple    : :gray
    drew = Dict{Symbol,Bool}(:minimum=>false, :maximum=>false, :saddle=>false)

    points = Matrix{Float64}(hcat(df_cp.x1, df_cp.x2))
    hessians = compute_hessians(f, points)

    for i in 1:size(df_cp, 1)
        eigs = sort(eigvals(hessians[i]))
        z = df_cp.z[i]
        t = df_cp.critical_point_type[i]
        col = color_for(t)
        lines!(ax, [z, z], [eigs[1], eigs[end]]; color=col, linewidth=2.5)
        scatter!(ax, [z, z], [eigs[1], eigs[end]];
            color=col, markersize=11,
            label = drew[t] ? nothing : "$(uppercasefirst(string(t)))")
        drew[t] = true
    end

    hlines!(ax, [0.0]; color=:black, linestyle=:dash, linewidth=1, label="Morse threshold  λ = 0")
    axislegend(ax; position=:rc, framevisible=true, backgroundcolor=(:white, 0.9))

    CairoMakie.save(joinpath(ASSET_DIR, "gallery_critical_eigenvalues.png"), fig_eig; px_per_unit=2)
    println("   → gallery_critical_eigenvalues.png")
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. Subdivision partition (Rosenbrock 2D, adaptive isotropic)
# ─────────────────────────────────────────────────────────────────────────────

println("\n[2/4] Anisotropic 2D subdivision partition …")
let
    # Anisotropic test function: high frequency in x_1, low frequency in x_2.
    # Forces subdivision predominantly along x_1, gives a visually distinctive partition.
    f(x) = sin(5 * x[1]) + 0.3 * sin(x[2])
    bounds = [(-2.0, 2.0), (-2.0, 2.0)]

    tree = adaptive_refine(
        f, bounds, 4;
        l2_tolerance=0.005, tolerance_mode=:absolute,
        max_depth=6, parallel=false, verbose=false,
    )

    leaf_ids = vcat(tree.converged_leaves, tree.active_leaves)
    leaf_bounds = [[collect(get_bounds(tree.subdomains[i])[d]) for d in 1:2] for i in leaf_ids]
    leaf_l2 = [tree.subdomains[i].l2_error for i in leaf_ids]
    leaf_deg = [tree.subdomains[i].degree for i in leaf_ids]

    fig = plot_subdivision_partition(
        leaf_bounds, leaf_l2, leaf_deg;
        title="Anisotropic sin(5x_1) + 0.3 sin(x_2) — adaptive subdivision",
        subtitle="Color encodes log L2 error per leaf",
        l2_tolerance=0.005,
    )
    CairoMakie.save(joinpath(ASSET_DIR, "gallery_subdivision_partition.png"), fig; px_per_unit=2)
    println("   → gallery_subdivision_partition.png  ($(length(leaf_ids)) leaves)")
end

# ─────────────────────────────────────────────────────────────────────────────
# 3. Convergence analysis — Camel CP spread vs degree
# ─────────────────────────────────────────────────────────────────────────────

println("\n[3/4] Camel degree-sweep — CPs recovered and L2 error vs degree …")
let
    n, scale_factor = 2, 5.0
    f = camel
    TR = TestInput(f; dim=n, center=[0.0, 0.0], GN=200, sample_range=scale_factor)

    degrees = collect(4:2:14)
    n_cps   = Int[]
    l2_err  = Float64[]
    for d in degrees
        pol = Constructor(TR, d, basis=:chebyshev, precision=RationalPrecision)
        @polyvar x[1:n]
        real_pts = solve_polynomial_system(
            x, n, d, pol.coeffs;
            basis=pol.basis, precision=pol.precision, normalized=pol.normalized,
        )
        df_cp = process_crit_pts(real_pts, f, TR)
        df_cp, _ = analyze_critical_points(f, df_cp, TR; tol_dist=0.00125)
        push!(n_cps, size(df_cp, 1))
        push!(l2_err, pol.nrm)
        println("   degree $d → $(size(df_cp, 1)) CPs, L2 fit error = $(round(pol.nrm, sigdigits=3))")
    end

    fig = Figure(size=(900, 500), fontsize=14)
    ax_l = Axis(fig[1, 1];
        xlabel="Polynomial degree",
        ylabel="L2 approximation error  ||f − p||",
        yscale=log10,
        title="Camel 2D — convergence of the polynomial approximant",
        xticks = degrees,
    )
    ax_r = Axis(fig[1, 1];
        ylabel="# critical points recovered",
        yaxisposition=:right,
    )
    hidespines!(ax_r)
    hidexdecorations!(ax_r)
    linkxaxes!(ax_l, ax_r)

    lines!(ax_l, degrees, l2_err; color=:steelblue, linewidth=2.5)
    l2_pts = scatter!(ax_l, degrees, l2_err; color=:steelblue, markersize=12)

    lines!(ax_r, degrees, n_cps; color=:crimson, linewidth=2.5, linestyle=:dash)
    cp_pts = scatter!(ax_r, degrees, n_cps; color=:crimson, markersize=12, marker=:rect)

    axislegend(ax_l,
        [l2_pts, cp_pts],
        ["L2 error (left axis, log)", "# critical points (right axis)"];
        position=:rc, framevisible=true, backgroundcolor=(:white, 0.85))

    CairoMakie.save(joinpath(ASSET_DIR, "gallery_convergence_analysis.png"), fig; px_per_unit=2)
    println("   → gallery_convergence_analysis.png")
end

println("\nGallery complete. PNGs in $ASSET_DIR")

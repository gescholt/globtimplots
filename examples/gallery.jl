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

const ASSET_DIR = abspath(joinpath(@__DIR__, "..", "docs", "src", "assets"))
isdir(ASSET_DIR) || mkpath(ASSET_DIR)

println("Writing gallery PNGs to: $ASSET_DIR")

# ─────────────────────────────────────────────────────────────────────────────
# 1. Polynomial approximation level-set (Camel 2D, Chebyshev degree 6)
# ─────────────────────────────────────────────────────────────────────────────

println("\n[1/3] Camel 2D level-set …")
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
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. Subdivision partition (Rosenbrock 2D, adaptive isotropic)
# ─────────────────────────────────────────────────────────────────────────────

println("\n[2/3] Anisotropic 2D subdivision partition …")
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

println("\n[3/3] Camel CP-spread degree sweep …")
let
    n, scale_factor = 2, 5.0
    f = camel
    TR = TestInput(f; dim=n, center=[0.0, 0.0], GN=200, sample_range=scale_factor)

    results = Dict{Int,NamedTuple}()
    for d in 4:2:10
        pol = Constructor(TR, d, basis=:chebyshev, precision=RationalPrecision)
        @polyvar x[1:n]
        real_pts = solve_polynomial_system(
            x, n, d, pol.coeffs;
            basis=pol.basis, precision=pol.precision, normalized=pol.normalized,
        )
        df_cp = process_crit_pts(real_pts, f, TR)
        df_cp, _ = analyze_critical_points(f, df_cp, TR; tol_dist=0.00125)
        results[d] = (df = df_cp,)
        println("   degree $d → $(size(df_cp, 1)) critical points")
    end

    fig = plot_convergence_analysis(results, 4, 10, 2)
    CairoMakie.save(joinpath(ASSET_DIR, "gallery_convergence_analysis.png"), fig; px_per_unit=2)
    println("   → gallery_convergence_analysis.png")
end

println("\nGallery complete. PNGs in $ASSET_DIR")

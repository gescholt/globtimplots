# Visual test for capture analysis plots — NOT run by Pkg.test().
#
# Run manually:  julia --project=globtimplots globtimplots/test/test_plot_visual.jl
#
# Generates synthetic data matching Deuflhard 4D shape (3 degrees × 4 variants × 2 CP types)
# and saves PNGs to globtimplots/test/visual_output/ for inspection.
#
# Dev loop:
#   1. Edit capture_analysis_plots.jl
#   2. Run this script (~10s)
#   3. Inspect PNGs
#   4. Repeat

using GlobtimPlots
using GlobtimPostProcessing: CaptureResult, KnownCriticalPoints
using CairoMakie
using Random: MersenneTwister

const OUTPUT_DIR = joinpath(@__DIR__, "visual_output")
mkpath(OUTPUT_DIR)

# --- Helpers ---------------------------------------------------------------

function make_capture_result(distances, types, tol_fracs, dd; n_computed=10)
    n_known = length(distances)
    tol_vals = tol_fracs .* dd
    nearest = fill(1, n_known)
    captured = [BitVector([d <= tv for d in distances]) for tv in tol_vals]
    rates = [count(c) / length(c) for c in captured]
    type_rates = Dict{Symbol, Vector{Float64}}()
    type_counts = Dict{Symbol, Int}()
    for sym in unique(types)
        idxs = findall(t -> t == sym, types)
        type_counts[sym] = length(idxs)
        type_rates[sym] = [count(captured[ti][idxs]) / length(idxs)
                           for ti in eachindex(tol_fracs)]
    end
    CaptureResult(distances, nearest, tol_fracs, tol_vals,
        captured, rates, type_rates, n_known, n_computed, dd, type_counts)
end

# --- Synthetic test data: Deuflhard 4D shape --------------------------------
# 25 known CPs: 9 minima + 16 saddles, 4D domain [0,1.2]×[-1.2,0]×[0,1.2]×[-1.2,0]

rng = MersenneTwister(123)

types_25 = vcat(fill(:min, 9), fill(:saddle, 16))
points_25 = [rand(rng, 4) for _ in 1:25]
values_25 = rand(rng, 25)
known = KnownCriticalPoints(points_25, values_25, types_25,
    [(0.0, 1.2), (-1.2, 0.0), (0.0, 1.2), (-1.2, 0.0)])
dd = known.domain_diameter
tol_fracs = [0.01, 0.025, 0.05, 0.1]

# Distances decrease with degree (convergence behavior)
dists_d3 = [0.3 + 0.2 * rand(rng) for _ in 1:25]
dists_d4 = [0.1 + 0.1 * rand(rng) for _ in 1:25]
dists_d5 = [0.02 + 0.03 * rand(rng) for _ in 1:25]

cr3 = make_capture_result(dists_d3, types_25, tol_fracs, dd; n_computed=40)
cr4 = make_capture_result(dists_d4, types_25, tol_fracs, dd; n_computed=120)
cr5 = make_capture_result(dists_d5, types_25, tol_fracs, dd; n_computed=300)

degree_capture_results = [(3, cr3), (4, cr4), (5, cr5)]

# Support sizes: binomial(4+d, d) for 4D
support_sizes = Dict(3 => 35, 4 => 70, 5 => 126)

# ═══════════════════════════════════════════════════════════════════════════════
# Plot 1: Capture convergence (distance boxplots + optional L2)
# ═══════════════════════════════════════════════════════════════════════════════

path1 = joinpath(OUTPUT_DIR, "capture_convergence.png")
println("Generating $path1 ...")
fig1 = plot_capture_convergence(degree_capture_results, known;
    support_sizes=support_sizes,
    l2_errors=[(3, 1.5), (4, 0.3), (5, 0.02)],
    show_l2=true,
    save_path=path1)
println("  Done.")

# ═══════════════════════════════════════════════════════════════════════════════
# Plot 2: Sparsification combined (CP accuracy + HC solve time)
# ═══════════════════════════════════════════════════════════════════════════════

# 3 degrees × 4 variants. Support sizes decrease with sparsification.
variant_specs = [
    ("Full",              0.0,   1.0),   # no sparsification
    ("1e-5 (mild)",       1e-5,  0.85),  # 85% coeffs retained
    ("1e-4 (moderate)",   1e-4,  0.60),  # 60% retained
    ("1e-3 (aggressive)", 1e-3,  0.30),  # 30% retained
]

entries = NamedTuple[]
for (deg, cr_base, full_support) in [(3, cr3, 35), (4, cr4, 70), (5, cr5, 126)]
    for (vlabel, threshold, retain_frac) in variant_specs
        n_nnz = max(1, round(Int, full_support * retain_frac))
        # Distances degrade with more sparsification
        degradation = 1.0 + (1.0 - retain_frac) * 0.5
        dists = [min(d * degradation, dd) for d in cr_base.distances]
        cr = make_capture_result(dists, types_25, tol_fracs, dd;
            n_computed=max(5, round(Int, cr_base.n_computed * retain_frac)))
        solve_time = deg^2 * 0.5 * retain_frac^1.5  # faster with more sparsification
        push!(entries, (
            degree=deg, variant_label=vlabel, threshold=threshold,
            capture_result=cr, n_nonzero_coeffs=n_nnz,
            l2_ratio=retain_frac > 0.99 ? 1.0 : 0.95 + 0.05 * retain_frac,
            solve_time=solve_time,
        ))
    end
end

path2 = joinpath(OUTPUT_DIR, "sparsification_combined.png")
println("Generating $path2 ...")
fig2 = plot_capture_sparsification_combined(entries, known;
    save_path=path2)
println("  Done.")

println("\nFiles written to $(OUTPUT_DIR)/:")
for f in readdir(OUTPUT_DIR)
    endswith(f, ".png") && println("  $f ($(filesize(joinpath(OUTPUT_DIR, f))) bytes)")
end

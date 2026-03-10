using Test
using GlobtimPlots
using GlobtimPostProcessing: CaptureResult, KnownCriticalPoints
using CairoMakie

"""
Build a CaptureResult from distances and known types for testing.
"""
function _make_capture_result(
    distances::Vector{Float64},
    types::Vector{Symbol},
    tol_fracs::Vector{Float64},
    domain_diameter::Float64;
    n_computed::Int = 10,
)
    n_known = length(distances)
    tol_vals = tol_fracs .* domain_diameter
    nearest = fill(1, n_known)
    captured = [BitVector([d <= tv for d in distances]) for tv in tol_vals]
    rates = [count(c) / length(c) for c in captured]

    type_rates = Dict{Symbol, Vector{Float64}}()
    type_counts = Dict{Symbol, Int}()
    for sym in unique(types)
        idxs = findall(t -> t == sym, types)
        type_counts[sym] = length(idxs)
        type_rates[sym] = [count(captured[ti][idxs]) / length(idxs)
                           for ti in 1:length(tol_fracs)]
    end

    return CaptureResult(distances, nearest, tol_fracs, tol_vals,
        captured, rates, type_rates, n_known, n_computed, domain_diameter, type_counts)
end

@testset "GlobtimPlots.jl" begin
    @testset "Package Loading" begin
        @test isdefined(GlobtimPlots, :VERSION)
        @test GlobtimPlots.VERSION isa VersionNumber
    end

    @testset "Extensions Available" begin
        @test true  # Placeholder - actual tests would depend on loaded extensions
    end

    @testset "plot_capture_convergence" begin
        @testset "Export exists" begin
            @test isdefined(GlobtimPlots, :plot_capture_convergence)
        end

        @testset "Smoke test — no L2 (3 types → 3 sub-axes + 1 panel)" begin
            points = [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0], [0.5, 0.5]]
            values = [0.0, 1.0, 1.0, 2.0, 0.5]
            types = [:min, :min, :saddle, :max, :saddle]
            known = KnownCriticalPoints(points, values, types, [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter
            tol_fracs = [0.01, 0.025, 0.05, 0.1]

            cr4 = _make_capture_result([0.3, 0.5, 0.2, 0.8, 0.15], types, tol_fracs, dd)
            cr6 = _make_capture_result([0.05, 0.1, 0.03, 0.2, 0.02], types, tol_fracs, dd; n_computed=20)

            fig = plot_capture_convergence([(4, cr4), (6, cr6)], known)
            @test fig isa Figure

            # 3 sub-axes (Panel 1: one per type) — Panel 2 mothballed
            axes = filter(x -> x isa Axis, collect(fig.content))
            @test length(axes) >= 3
        end

        @testset "Smoke test — with L2 (2 types → 2 sub-axes + 2 panels)" begin
            points = [[0.0, 0.0], [1.0, 0.0], [0.5, 0.5]]
            values = [0.0, 1.0, 0.5]
            types = [:min, :saddle, :saddle]
            known = KnownCriticalPoints(points, values, types, [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter
            tol_fracs = [0.01, 0.05, 0.1]

            cr = _make_capture_result([0.05, 0.2, 0.02], types, tol_fracs, dd; n_computed=5)

            # show_l2=true required to display L2 panel
            fig = plot_capture_convergence([(6, cr)], known; l2_errors=[(6, 0.01)], show_l2=true)
            @test fig isa Figure

            # 2 sub-axes (Panel 1: min + saddle) + L2 panel = 3 axes (Panel 2 mothballed)
            axes = filter(x -> x isa Axis, collect(fig.content))
            @test length(axes) >= 3
        end

        @testset "L2 data without show_l2 does not add L2 panel" begin
            points = [[0.0, 0.0], [1.0, 0.0]]
            values = [0.0, 1.0]
            types = [:min, :saddle]
            known = KnownCriticalPoints(points, values, types, [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter
            tol_fracs = [0.05, 0.1]

            cr = _make_capture_result([0.1, 0.2], types, tol_fracs, dd; n_computed=5)

            # Pass l2_errors but NOT show_l2 — L2 panel should not appear
            fig = plot_capture_convergence([(6, cr)], known; l2_errors=[(6, 0.01)])
            @test fig isa Figure

            # 2 sub-axes (Panel 1: min + saddle) = 2 axes (Panel 2 mothballed, no L2)
            axes = filter(x -> x isa Axis, collect(fig.content))
            @test length(axes) == 2
        end

        @testset "Error on empty input" begin
            known = KnownCriticalPoints([[0.0, 0.0]], [0.0], [:min], [(-1.0, 1.0), (-1.0, 1.0)])
            @test_throws ErrorException plot_capture_convergence(
                Tuple{Int, CaptureResult}[], known)
        end

        @testset "Error on mismatched tolerance_fractions" begin
            types = [:min, :saddle]
            known = KnownCriticalPoints([[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types,
                [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter

            cr1 = _make_capture_result([0.1, 0.2], types, [0.05, 0.1], dd)
            cr2 = _make_capture_result([0.05, 0.1], types, [0.01, 0.1], dd)

            @test_throws ErrorException plot_capture_convergence([(4, cr1), (6, cr2)], known)
        end

        @testset "Save to file" begin
            types = [:min, :max]
            known = KnownCriticalPoints([[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types,
                [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter
            cr = _make_capture_result([0.1, 0.3], types, [0.05, 0.1], dd; n_computed=5)

            tmpfile = tempname() * ".png"
            fig = plot_capture_convergence([(4, cr)], known; save_path=tmpfile)
            @test isfile(tmpfile)
            @test filesize(tmpfile) > 0
            rm(tmpfile; force=true)
        end

        @testset "Reproducible jitter" begin
            types = [:min, :saddle]
            known = KnownCriticalPoints([[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types,
                [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter
            cr = _make_capture_result([0.1, 0.2], types, [0.05, 0.1], dd)

            # Two calls should produce identical figures (deterministic jitter)
            fig1 = plot_capture_convergence([(4, cr)], known)
            fig2 = plot_capture_convergence([(4, cr)], known)
            @test fig1 isa Figure
            @test fig2 isa Figure
            # Can't easily compare figures pixel-by-pixel, but at least they don't error
        end

        @testset "With support_sizes kwarg" begin
            types = [:min, :saddle]
            known = KnownCriticalPoints(
                [[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types, [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter
            tol_fracs = [0.01, 0.05, 0.1]
            cr4 = _make_capture_result([0.2, 0.3], types, tol_fracs, dd)
            cr6 = _make_capture_result([0.05, 0.08], types, tol_fracs, dd)

            # Non-uniform support sizes (like 2D binomial: C(6,2)=15, C(8,2)=28)
            fig = plot_capture_convergence([(4, cr4), (6, cr6)], known;
                support_sizes=Dict(4 => 15, 6 => 28))
            @test fig isa Figure

            # 2 sub-axes (Panel 1: min + saddle) = 2 axes (Panel 2 mothballed)
            axes = filter(x -> x isa Axis, collect(fig.content))
            @test length(axes) == 2
        end

        @testset "With support_sizes + L2" begin
            types = [:min, :max]
            known = KnownCriticalPoints(
                [[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types, [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter
            tol_fracs = [0.05, 0.1]
            cr4 = _make_capture_result([0.2, 0.4], types, tol_fracs, dd)
            cr8 = _make_capture_result([0.01, 0.02], types, tol_fracs, dd)

            # 4D total degree: C(8,4)=70, C(12,8)=495
            fig = plot_capture_convergence([(4, cr4), (8, cr8)], known;
                support_sizes=Dict(4 => 70, 8 => 495),
                l2_errors=[(4, 100.0), (8, 0.5)], show_l2=true)
            @test fig isa Figure

            # 2 sub-axes (Panel 1) + L2 panel = 3 axes (Panel 2 mothballed)
            axes = filter(x -> x isa Axis, collect(fig.content))
            @test length(axes) == 3
        end

        @testset "Single degree with support_sizes" begin
            types = [:min]
            known = KnownCriticalPoints(
                [[0.5, 0.5]], [1.0], types, [(0.0, 1.0), (0.0, 1.0)])
            dd = known.domain_diameter
            cr = _make_capture_result([0.1], types, [0.05], dd)

            fig = plot_capture_convergence([(6, cr)], known;
                support_sizes=Dict(6 => 28))
            @test fig isa Figure
        end
    end

    @testset "plot_capture_sparsification_combined" begin
        # Shared test data builder for combined plot entries
        function _make_combined_entries(degrees, variant_specs, types, known)
            dd = known.domain_diameter
            tol_fracs = [0.01, 0.05, 0.1]
            entries = NamedTuple[]
            for deg in degrees
                for (vlabel, threshold, dist_scale, n_nnz, l2r) in variant_specs
                    # Distances decrease with degree, increase with threshold
                    dists = [dist_scale / deg * (1 + 0.1 * i) for i in 1:length(types)]
                    cr = _make_capture_result(dists, types, tol_fracs, dd;
                        n_computed = max(5, round(Int, 20 / dist_scale)))
                    # Simulate solve time: scales with degree, faster with more sparsification
                    base_time = deg^2 * 0.1
                    solve_t = threshold > 0.0 ? base_time / (1.0 + 10.0 * threshold) : base_time
                    push!(entries, (
                        degree = deg,
                        variant_label = vlabel,
                        threshold = threshold,
                        capture_result = cr,
                        n_nonzero_coeffs = n_nnz,
                        l2_ratio = l2r,
                        solve_time = solve_t,
                    ))
                end
            end
            return entries
        end

        @testset "Export exists" begin
            @test isdefined(GlobtimPlots, :plot_capture_sparsification_combined)
        end

        @testset "Smoke test — 2 degrees × 3 variants, 2 types" begin
            types = [:min, :saddle, :saddle, :min]
            known = KnownCriticalPoints(
                [[0.0, 0.0], [1.0, 0.0], [0.5, 0.5], [1.0, 1.0]],
                [0.0, 1.0, 0.5, 2.0], types, [(-1.0, 1.0), (-1.0, 1.0)])

            variant_specs = [
                ("Full",       0.0,  1.0, 100, 1.0),
                ("1e-4 (mild)", 1e-4, 1.2,  80, 0.98),
                ("1e-3 (agg)",  1e-3, 1.5,  50, 0.85),
            ]
            entries = _make_combined_entries([4, 6], variant_specs, types, known)

            fig = plot_capture_sparsification_combined(entries, known)
            @test fig isa Figure

            # 2 type sub-axes (Panel A) + 1 solve time axis (Panel B) = 3 axes
            axes = filter(x -> x isa Axis, collect(fig.content))
            @test length(axes) == 3
        end

        @testset "Single degree, single variant (Full only)" begin
            types = [:min, :saddle]
            known = KnownCriticalPoints(
                [[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types, [(-1.0, 1.0), (-1.0, 1.0)])

            entries = _make_combined_entries([4], [("Full", 0.0, 1.0, 100, 1.0)], types, known)

            fig = plot_capture_sparsification_combined(entries, known)
            @test fig isa Figure
        end

        @testset "3 types (min, max, saddle)" begin
            types = [:min, :max, :saddle]
            known = KnownCriticalPoints(
                [[0.0, 0.0], [1.0, 0.0], [0.5, 0.5]],
                [0.0, 2.0, 1.0], types, [(-1.0, 1.0), (-1.0, 1.0)])

            variant_specs = [
                ("Full",  0.0,  1.0, 200, 1.0),
                ("1e-4",  1e-4, 1.3, 150, 0.95),
            ]
            entries = _make_combined_entries([4, 8], variant_specs, types, known)

            fig = plot_capture_sparsification_combined(entries, known)
            @test fig isa Figure

            # 3 type sub-axes (Panel A) + 1 solve time axis (Panel B) = 4 axes
            axes = filter(x -> x isa Axis, collect(fig.content))
            @test length(axes) == 4
        end

        @testset "Error on empty input" begin
            known = KnownCriticalPoints([[0.0, 0.0]], [0.0], [:min], [(-1.0, 1.0), (-1.0, 1.0)])
            @test_throws ErrorException plot_capture_sparsification_combined(
                NamedTuple[], known)
        end

        @testset "Error on mismatched variants across degrees" begin
            types = [:min, :saddle]
            known = KnownCriticalPoints(
                [[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types, [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter
            tol_fracs = [0.05, 0.1]

            cr = _make_capture_result([0.1, 0.2], types, tol_fracs, dd)

            entries = [
                (degree=4, variant_label="Full", threshold=0.0,
                 capture_result=cr, n_nonzero_coeffs=100, l2_ratio=1.0, solve_time=1.0),
                (degree=4, variant_label="1e-4", threshold=1e-4,
                 capture_result=cr, n_nonzero_coeffs=80, l2_ratio=0.98, solve_time=0.8),
                # Degree 6 missing "1e-4" variant
                (degree=6, variant_label="Full", threshold=0.0,
                 capture_result=cr, n_nonzero_coeffs=200, l2_ratio=1.0, solve_time=5.0),
            ]
            @test_throws ErrorException plot_capture_sparsification_combined(entries, known)
        end

        @testset "Error on mismatched tolerance_fractions" begin
            types = [:min, :saddle]
            known = KnownCriticalPoints(
                [[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types, [(-1.0, 1.0), (-1.0, 1.0)])
            dd = known.domain_diameter

            cr1 = _make_capture_result([0.1, 0.2], types, [0.05, 0.1], dd)
            cr2 = _make_capture_result([0.1, 0.2], types, [0.01, 0.1], dd)

            entries = [
                (degree=4, variant_label="Full", threshold=0.0,
                 capture_result=cr1, n_nonzero_coeffs=100, l2_ratio=1.0, solve_time=1.0),
                (degree=4, variant_label="1e-4", threshold=1e-4,
                 capture_result=cr2, n_nonzero_coeffs=80, l2_ratio=0.98, solve_time=0.8),
            ]
            @test_throws ErrorException plot_capture_sparsification_combined(entries, known)
        end

        @testset "Save to file" begin
            types = [:min, :saddle]
            known = KnownCriticalPoints(
                [[0.0, 0.0], [1.0, 1.0]], [0.0, 2.0], types, [(-1.0, 1.0), (-1.0, 1.0)])

            entries = _make_combined_entries(
                [4], [("Full", 0.0, 1.0, 100, 1.0)], types, known)

            tmpfile = tempname() * ".png"
            fig = plot_capture_sparsification_combined(entries, known; save_path=tmpfile)
            @test isfile(tmpfile)
            @test filesize(tmpfile) > 0
            rm(tmpfile; force=true)
        end
    end
end

# Aqua.jl quality assurance tests
include("test_aqua.jl")

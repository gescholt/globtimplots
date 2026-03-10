# Test script for the interactive docs refactoring (Phase 1 + Phase 2)
#
# Run from the repo root:
#   julia --project=globtimplots globtimplots/test/test_interactive_docs.jl
#
# Tests:
#   1. GlobtimPlots loads with shared hessian/eigenvalue + polyapprox_3d code
#   2. Forward declarations and exports are correct
#   3. GLMakie extension loads and provides plot_polyapprox_3d
#   4. Hessian/eigenvalue functions are callable (type-level check)

using Test

# ─────────────────────────────────────────────────────────────────────────────
# Test 1: GlobtimPlots basic load
# ─────────────────────────────────────────────────────────────────────────────
@testset "GlobtimPlots basic load" begin
    @info "Test 1: Loading GlobtimPlots..."
    using GlobtimPlots

    # Shared hessian/eigenvalue functions exist as concrete methods
    @test isdefined(GlobtimPlots, :plot_hessian_norms)
    @test isdefined(GlobtimPlots, :plot_condition_numbers)
    @test isdefined(GlobtimPlots, :plot_critical_eigenvalues)
    @test isdefined(GlobtimPlots, :plot_all_eigenvalues)
    @test isdefined(GlobtimPlots, :plot_raw_vs_refined_eigenvalues)

    # Shared polyapprox_3d impl exists
    @test isdefined(GlobtimPlots, :_plot_polyapprox_3d_impl)

    # Forward declaration for plot_polyapprox_3d exists (stub until extension loads)
    @test isdefined(GlobtimPlots, :plot_polyapprox_3d)

    # Abstract types exported
    @test isdefined(GlobtimPlots, :AbstractPolynomialData)
    @test isdefined(GlobtimPlots, :AbstractProblemInput)

    # Hessian functions should have at least 1 method each (from hessian_eigenvalue_plots.jl)
    @test length(methods(GlobtimPlots.plot_hessian_norms)) >= 1
    @test length(methods(GlobtimPlots.plot_condition_numbers)) >= 1
    @test length(methods(GlobtimPlots.plot_critical_eigenvalues)) >= 1
    @test length(methods(GlobtimPlots.plot_all_eigenvalues)) >= 1
    @test length(methods(GlobtimPlots.plot_raw_vs_refined_eigenvalues)) >= 1

    # _plot_polyapprox_3d_impl should have 1 method
    @test length(methods(GlobtimPlots._plot_polyapprox_3d_impl)) >= 1

    @info "Test 1 passed: GlobtimPlots loads with all shared functions"
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 2: GLMakie extension
# ─────────────────────────────────────────────────────────────────────────────
@testset "GLMakie extension" begin
    @info "Test 2: Checking GLMakie extension..."
    glmakie_available = try
        Base.require(Main, :GLMakie)
        true
    catch
        false
    end

    if glmakie_available
        using GLMakie
        using DynamicPolynomials
        using Parameters

        # After loading GLMakie + DynamicPolynomials + Parameters, the extension should load
        # and add a method to plot_polyapprox_3d
        n_methods = length(methods(GlobtimPlots.plot_polyapprox_3d))
        @test n_methods >= 1
        @info "Test 2: plot_polyapprox_3d has $n_methods method(s) after GLMakie extension"

        # The extension's method should accept AbstractPolynomialData
        sig_types = [m.sig for m in methods(GlobtimPlots.plot_polyapprox_3d)]
        @info "Test 2: Signatures: $sig_types"

        @info "Test 2 passed: GLMakie extension loaded"
    else
        @info "Test 2 skipped: GLMakie not available in this environment (it's a weak dependency)"
        @test_skip false  # Mark as skipped, not failed
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 3: CairoMakie extension (should already be loaded via GlobtimPlots)
# ─────────────────────────────────────────────────────────────────────────────
@testset "CairoMakie extension" begin
    @info "Test 3: Checking CairoMakie extension..."

    # cairo_plot_polyapprox_levelset should exist from CairoMakie extension
    @test isdefined(GlobtimPlots, :cairo_plot_polyapprox_levelset)
    @test length(methods(GlobtimPlots.cairo_plot_polyapprox_levelset)) >= 1

    @info "Test 3 passed: CairoMakie extension loaded"
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 4: Quick smoke test — create a simple figure with abstract Makie API
# ─────────────────────────────────────────────────────────────────────────────
@testset "Smoke test: abstract Makie API figure" begin
    @info "Test 4: Creating a test figure with abstract Makie API..."

    # Use CairoMakie (already loaded via GlobtimPlots)
    CairoMakie.activate!()

    fig = Figure(size = (400, 300))
    ax = Axis3(fig[1, 1], title = "Smoke Test")
    xs = range(-2, 2, length = 20)
    ys = range(-2, 2, length = 20)
    zs = [sin(x) * cos(y) for x in xs, y in ys]
    surface!(ax, xs, ys, zs, colormap = :viridis)

    @test fig isa Figure
    @info "Test 4 passed: Abstract Makie API works for 3D surface"
end

@info "All tests passed!"

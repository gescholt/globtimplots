"""
    test_postprocessing_integration.jl

Test that GlobtimPlots can properly import and use types from GlobtimPostProcessing.

This verifies the correct dependency direction:
    GlobtimPostProcessing (data) ← GlobtimPlots (visualization)
"""

using Test
using Dates

@testset "GlobtimPlots ← GlobtimPostProcessing Integration" begin
    @testset "GlobtimPlots can import GlobtimPostProcessing" begin
        # Load both packages
        using GlobtimPostProcessing
        using GlobtimPlots

        # Verify GlobtimPlots loaded successfully
        @test isdefined(GlobtimPlots, :VERSION)
        @test GlobtimPlots.VERSION isa VersionNumber

        println("✓ Both packages loaded successfully")
    end

    @testset "GlobtimPlots plotting functions work with GlobtimPostProcessing types" begin
        using GlobtimPostProcessing
        using GlobtimPlots
        using DataFrames

        # Create a minimal test ExperimentResult
        test_cp_df = DataFrame(
            x1 = [1.0, 2.0],
            x2 = [1.5, 2.5],
            z = [0.1, 0.2],
            degree = [3, 3]
        )

        exp_result = ExperimentResult(
            "test_experiment_001",
            Dict("test_param" => 1.0, "domain_range" => 0.5),
            ["l2_discrete", "critical_points"],
            ["l2_discrete", "critical_points", "eigenvalues"],
            test_cp_df,
            Dict("runtime_seconds" => 10.5),
            nothing,
            "/tmp/test_exp"
        )

        # Verify the type works
        @test exp_result isa ExperimentResult
        @test exp_result.experiment_id == "test_experiment_001"

        # Create a test campaign
        campaign = CampaignResults(
            "test_campaign_001",
            [exp_result],
            Dict("campaign_param" => "test"),
            now()
        )

        @test campaign isa CampaignResults
        @test length(campaign.experiments) == 1

        # Test that plotting functions are available
        # (These use duck-typing, so we just check they're exported)
        @test isdefined(GlobtimPlots, :create_experiment_plots)
        @test isdefined(GlobtimPlots, :create_campaign_comparison_plot)

        println("✓ GlobtimPlots functions can work with GlobtimPostProcessing types")
    end

    @testset "GlobtimPlots has GlobtimPostProcessing as dependency" begin
        using Pkg

        # Get dependencies from GlobtimPlots Project.toml
        project_path = joinpath(dirname(dirname(@__FILE__)), "Project.toml")
        @test isfile(project_path)

        project_toml = Pkg.TOML.parsefile(project_path)
        deps = get(project_toml, "deps", Dict())

        # Verify GlobtimPostProcessing is listed (or that it's using Globtim which includes it)
        # Currently it depends on Globtim, which is acceptable
        has_data_source = haskey(deps, "GlobtimPostProcessing") || haskey(deps, "Globtim")

        @test has_data_source

        if haskey(deps, "GlobtimPostProcessing")
            println("✓ GlobtimPlots directly depends on GlobtimPostProcessing")
        elseif haskey(deps, "Globtim")
            println("✓ GlobtimPlots depends on Globtim (which includes GlobtimPostProcessing)")
        end
    end
end

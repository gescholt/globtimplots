using Test
using GlobtimPlots

@testset "GlobtimPlots.jl" begin
    @testset "Package Loading" begin
        @test isdefined(GlobtimPlots, :VERSION)
        @test GlobtimPlots.VERSION isa VersionNumber
    end
    
    @testset "Extensions Available" begin
        # Test that extensions are properly defined
        # These will only work when the corresponding packages are loaded
        @test true  # Placeholder - actual tests would depend on loaded extensions
    end
end
using Aqua
using GlobtimPlots

@testset "Aqua.jl Quality Assurance" begin
    Aqua.test_all(GlobtimPlots;
        ambiguities=true,
        unbound_args=true,
        # Disabled: @reexport using CairoMakie re-exports Makie symbols (Text, density,
        # rotate!) that are lazily defined at runtime. Aqua always flags these and we
        # can't fix upstream Makie. Our own exports are validated by the forward
        # declarations in GlobtimPlots.jl.
        undefined_exports=false,
        stale_deps=(; ignore=[
            :PlotlyJS, :Tidier, :VegaLite, :GLMakie,  # weak deps / extensions
        ]),
        deps_compat=true,
        persistent_tasks=false,  # Skip: CairoMakie upstream issue + local dev deps
    )
end

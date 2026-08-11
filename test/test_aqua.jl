using Aqua
using GlobtimPlots

@testset "Aqua.jl Quality Assurance" begin
    # One real exclusion. Two former ones were dropped as stale (verified on
    # Julia 1.12.6 / Aqua 0.8.14):
    #
    #   - `stale_deps = (; ignore = [:PlotlyJS, :Tidier, :VegaLite, :GLMakie])`.
    #     PlotlyJS, Tidier and VegaLite are not in [deps] at all (the VegaLite/
    #     Tidier plotting functions are commented out in src/GlobtimPlots.jl), so
    #     three quarters of that list ignored nothing. GLMakie is a [weakdeps]
    #     entry, which stale_deps does not flag. The check passes clean with no
    #     ignore list.
    #
    #   - `persistent_tasks = false` ("CairoMakie upstream issue + local dev
    #     deps"). It passes on 1.12. It is expensive — ~135s, since the check
    #     spawns a subprocess that loads the whole Makie stack from scratch — so
    #     it is the first thing to reconsider if this package's CI wall becomes a
    #     problem.
    #
    # undefined_exports stays off: `@reexport using CairoMakie` re-exports Makie
    # symbols that are only defined lazily at runtime — currently Sphere, Text,
    # density, rotate! and volume. Not fixable from here, and our own exports are
    # covered by the forward declarations in GlobtimPlots.jl.
    #
    # undocumented_names is off by Aqua's own default and stays off for now.
    Aqua.test_all(GlobtimPlots; undefined_exports = false)
end

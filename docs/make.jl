using Documenter
using GlobtimPlots

makedocs(
    sitename = "GlobtimPlots.jl",
    format = Documenter.HTML(
        prettyurls = false,
        canonical = "https://gescholt.github.io/globtimplots",
        analytics = "G-22HWCKE0JK",
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => "api.md",
        "Migration Guide" => "migration.md",
    ],
    modules = [GlobtimPlots, GlobtimPlots.LV4DPlots],
)

deploydocs(
    repo = "github.com/gescholt/GlobtimPlots.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "main",
)

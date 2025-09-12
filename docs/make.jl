using Documenter
using GlobtimPlots

makedocs(
    sitename="GlobtimPlots.jl",
    format=Documenter.HTML(
        prettyurls=false,
        canonical="https://globaloptim.github.io/GlobtimPlots.jl"
    ),
    pages=[
        "Home" => "index.md",
        "API Reference" => "api.md",
        "Migration Guide" => "migration.md"
    ],
    modules=[GlobtimPlots]
)

deploydocs(
    repo="git.mpi-cbg.de/globaloptim/globtimplots.git",
    target="build",
    branch="gh-pages",
    devbranch="main"
)
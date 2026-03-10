# Workflows

Interactive cross-package workflows for REPL-based analysis and visualization.

## What belongs here

Scripts that combine multiple packages (e.g., analysis from `GlobtimPostProcessing` + visualization from `GlobtimPlots`) in an interactive worksheet format.

## Usage

Run line-by-line in Julia REPL:

```bash
cd /path/to/your/project
julia --project=globtimplots
```

Then in REPL:
```julia
include("scripts/workflows/lv4d_worksheet.jl")
```

Or execute individual lines from the worksheet.

## Scripts

| Script | Purpose |
|--------|---------|
| `lv4d_worksheet.jl` | LV4D parameter sweep analysis with interactive heatmaps and convergence plots |

## Related

- `scripts/analysis/` - Batch analysis scripts (no interactive visualization)
- `scripts/plotting/` - Standalone plotting scripts
- `globtimpostprocessing/scripts/lv4d_repl_workflow.jl` - Text-based LV4D analysis (no plotting)

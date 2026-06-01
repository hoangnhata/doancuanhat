# Chỉ xóa artifact classify — KHÔNG đụng ocr_* / forecast_*
$models = Join-Path $PSScriptRoot "..\models" | Resolve-Path
$patterns = @(
    "classify_model.pt",
    "classify_vocab.json",
    "classify_preprocess.json",
    "classify_meta.json",
    "classify_metrics.json",
    "classify_best.pt",
    "classify_checkpoint.pt",
    "IMPROVEMENT_REPORT.md",
    "MODEL_IMPROVEMENT_REPORT.md",
    "grid_search_results.json"
)
foreach ($name in $patterns) {
    $p = Join-Path $models $name
    if (Test-Path $p) {
        Remove-Item $p -Force
        Write-Host "Removed $name"
    }
}
$grid = Join-Path $models "grid_runs"
if (Test-Path $grid) {
    Remove-Item $grid -Recurse -Force
    Write-Host "Removed grid_runs/"
}
Write-Host "Done. OCR and forecast files untouched."

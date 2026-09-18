<#
  show_losses.ps1  --  "loss visualizer" agent (one command).
  Regenerates the annotated loss charts from the latest combo deals CSV and opens the gallery.

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\show_losses.ps1                # 24 worst, M15
    powershell -ExecutionPolicy Bypass -File tools\show_losses.ps1 -Tf 5 -Top 40  # M5 candles, 40 worst

  NOTE: this draws from the CURRENT ck_gold_combo_deals.csv (Common\Files).
  To refresh the data first, run a combo backtest:
    powershell -ExecutionPolicy Bypass -File tools\run_candidate.ps1 -Preset experiments\combo_base2\preset.json
#>
param([int]$Tf = 15, [int]$Top = 24)
$py = "C:\Python314\python.exe"
$script = Join-Path $PSScriptRoot "loss_visualizer.py"
Write-Host "[show_losses] drawing $Top worst losses on M$Tf candles..." -ForegroundColor Cyan
& $py $script --tf $Tf --top $Top
$gal = Join-Path $env:USERPROFILE "Desktop\gold_chop_charts\losses\gallery.html"
if (Test-Path $gal) {
    Write-Host "[show_losses] opening gallery: $gal" -ForegroundColor Green
    Start-Process $gal
} else {
    Write-Host "[show_losses] gallery not found (did the visualizer run?)" -ForegroundColor Yellow
}

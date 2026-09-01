<#
  run_sweep.ps1 — run every sweep preset through run_candidate, SEQUENTIALLY (MT5 is
  single-instance; never run two chains at once). Resumable: skips a preset whose
  holdout trades.csv already exists.
  Usage: powershell -ExecutionPolicy Bypass -File tools\run_sweep.ps1
#>
$ErrorActionPreference = "Continue"
$presets = Get-ChildItem "experiments\sweep_*\preset.json" | Sort-Object FullName
Write-Host "[sweep] $($presets.Count) presets total"
foreach ($p in $presets) {
    $done = Join-Path $p.Directory.FullName "windows\holdout\trades.csv"
    if (Test-Path $done) { Write-Host "SKIP (done) $($p.Directory.Name)"; continue }
    Write-Host "=== RUN $($p.Directory.Name) ==="
    powershell -ExecutionPolicy Bypass -File tools\run_candidate.ps1 -Preset $p.FullName -TimeoutSec 1500
}
Write-Host "SWEEP_ALL_DONE"

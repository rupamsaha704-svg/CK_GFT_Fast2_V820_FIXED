<#
  run_batch.ps1 - queue and run MANY candidate presets in one go, writing all output to files
  (avoids the interactive shell buffer lag). After the batch, regenerates the master summary table.

  Usage:
    powershell -File tools\run_batch.ps1 -Presets exp\a\preset.json,exp\b\preset.json [-TimeoutSec 900]
    powershell -File tools\run_batch.ps1 -Glob "experiments\screen_*\preset.json"

  Discipline unchanged: each preset pins every input (Guard #20 inside make_ini); MT5 is the only
  simulator; verdicts come from the deterministic pipeline. Screening vs final = the preset's own
  "model" field (1 = 1-min OHLC fast screen; 4 = every-tick real-tick final truth).
#>
param(
    [string[]]$Presets,
    [string]$Glob,
    [int]$TimeoutSec = 900
)
$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot
$repo = Split-Path -Parent $scriptDir
$envCfg = Get-Content (Join-Path $scriptDir "env.json") -Raw | ConvertFrom-Json
$py = $envCfg.python

if ($Glob) { $Presets = @(Get-ChildItem $Glob -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) }
# robustness: when called via `powershell -File ... -Presets a,b` the arg can arrive as ONE
# comma-joined string instead of an array. Split it so each path is honoured.
if ($Presets -and $Presets.Count -eq 1 -and $Presets[0] -match ',') { $Presets = $Presets[0] -split ',' }
if (-not $Presets -or $Presets.Count -eq 0) { Write-Host "no presets given"; exit 1 }

$log = Join-Path $repo "experiments\_BATCH_LOG.txt"
"=== BATCH START $((Get-Date).ToString('u')) : $($Presets.Count) presets ===" | Set-Content $log
$i = 0
foreach ($p in $Presets) {
    $i++
    if (-not (Test-Path $p)) { "[$i] MISSING preset: $p" | Add-Content $log; continue }
    $mdl = (Get-Content $p -Raw | ConvertFrom-Json).model
    "[$i/$($Presets.Count)] $(Split-Path (Split-Path $p -Parent) -Leaf)  (model=$mdl)  start $((Get-Date).ToString('HH:mm:ss'))" | Add-Content $log
    & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "run_candidate.ps1") -Preset $p -TimeoutSec $TimeoutSec *>> $log
    "[$i] done $((Get-Date).ToString('HH:mm:ss')) exit=$LASTEXITCODE" | Add-Content $log
}
"=== BATCH END $((Get-Date).ToString('u')) ===" | Add-Content $log

# regenerate the master compact summary (MT5-style: trades, net$, PF, win%, maxDD%)
$sum = Join-Path $repo "experiments\_ALL_SUMMARY.txt"
& $py (Join-Path $scriptDir "summarize_all.py") 50000 | Out-File -Encoding ascii $sum
Write-Host "batch complete -> $log ; summary -> $sum"

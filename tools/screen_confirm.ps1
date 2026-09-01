<#
  screen_confirm.ps1 - fast-screen (Model 1) -> real-tick (Model 4) confirm, one command.

  Flow (SPEED with discipline intact):
    1) Build a Model-1 (1-min OHLC) screen variant of the given final preset (all inputs pinned,
       identical windows) in experiments/<id>__screen/.
    2) Run it fast via run_candidate.ps1.
    3) Apply the LOOSE screen_gate (rejects only clearly-dead ideas). Model 1 is an approximation.
    4) If it survives the screen -> run the ORIGINAL Model-4 (real-tick) preset = the only truth,
       and the full deterministic pipeline issues PASS/FAIL/REJECT there.
    5) If clearly dead -> skip the slow real-tick run and say so (time saved).

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\screen_confirm.ps1 -Preset experiments\foo\preset.json
               [-ScreenMinPF 0.90] [-ScreenTimeoutSec 600] [-ConfirmTimeoutSec 1200]
#>
param(
    [Parameter(Mandatory=$true)][string]$Preset,
    [double]$ScreenMinPF = 0.90,
    [int]$ScreenTimeoutSec = 600,
    [int]$ConfirmTimeoutSec = 1200
)
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$repo = Split-Path -Parent $scriptDir
$envCfg = Get-Content (Join-Path $scriptDir "env.json") -Raw | ConvertFrom-Json
$py = $envCfg.python

if (-not (Test-Path $Preset)) { throw "Preset not found: $Preset" }
$p = Get-Content $Preset -Raw | ConvertFrom-Json
$expId = Split-Path -Leaf (Split-Path -Parent (Resolve-Path $Preset))

# --- 1) Build Model-1 screen variant (identical except model=1) ---
$screenId  = "${expId}__screen"
$screenDir = Join-Path $repo "experiments\$screenId"
if (-not (Test-Path $screenDir)) { New-Item -ItemType Directory -Force $screenDir | Out-Null }
$p.model = 1
$screenPreset = Join-Path $screenDir "preset.json"
$p | ConvertTo-Json -Depth 30 | Set-Content -Encoding ascii $screenPreset

# resolve the OOS + both-half window ids from the preset (order-independent)
$oosWin = ($p.windows | Where-Object { $_.id -match 'oos' } | Select-Object -First 1)
if (-not $oosWin) { $oosWin = $p.windows[1] }   # fallback: 2nd declared window
$h1Win = ($p.windows | Where-Object { $_.id -match 'h1|half1' } | Select-Object -First 1)
$h2Win = ($p.windows | Where-Object { $_.id -match 'h2|half2' } | Select-Object -First 1)

Write-Host "=== SCREEN (Model 1, fast) : $screenId ==="
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "run_candidate.ps1") -Preset $screenPreset -TimeoutSec $ScreenTimeoutSec

# --- 2) Apply loose screen gate on the screen outputs ---
$oosCsv = Join-Path $screenDir "windows\$($oosWin.id)\trades.csv"
$gateArgs = @((Join-Path $scriptDir "screen_gate.py"), "--oos", $oosCsv, "--min-pf", $ScreenMinPF, "--deposit", $p.deposit)
if ($h1Win) { $gateArgs += @("--half1", (Join-Path $screenDir "windows\$($h1Win.id)\trades.csv")) }
if ($h2Win) { $gateArgs += @("--half2", (Join-Path $screenDir "windows\$($h2Win.id)\trades.csv")) }
& $py @gateArgs
$gate = $LASTEXITCODE

# --- 3) Confirm on real ticks only if it survived the screen ---
if ($gate -eq 0) {
    Write-Host ""
    Write-Host "=== CONFIRM (Model 4, real ticks = TRUTH) : $expId ==="
    & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "run_candidate.ps1") -Preset $Preset -TimeoutSec $ConfirmTimeoutSec
    Write-Host "screen->confirm done: real-tick verdict is in experiments\$expId\report.md"
} elseif ($gate -eq 2) {
    Write-Host "screen->confirm: SCREENED OUT at Model 1 (clearly dead). Skipped real-tick to save time."
    Write-Host "  (If you disagree, run real-tick directly: run_candidate.ps1 -Preset $Preset)"
} else {
    Write-Host "screen->confirm: screen gate ERROR (exit $gate). Not proceeding to real-tick."
}

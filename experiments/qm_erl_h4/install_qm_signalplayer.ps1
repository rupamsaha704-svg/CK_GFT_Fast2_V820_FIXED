# install_qm_signalplayer.ps1
# Local install of the ship-ready Plan Q kit into MT5.
# 1) Copies CK_QM_SignalPlayer.mq5 -> MT5 data-dir MQL5\Experts\
# 2) Copies _signals_erl_h4.txt    -> MT5 Common\Files\signals_erl_h4.csv
#     (the EA reads with FILE_COMMON when InpUseCommonFiles=true)
# 3) Compiles the EA with MetaEditor (headless).
# 4) Verifies .ex5 was produced.
# Attach + Load + Enable is a manual step in MT5 (no CLI for chart attach).
# Steering: §5 (MT5 = truth), §5a (signal-player pattern), §7 (QM safe risk = $75 on FN $6k),
#           §10 (-NoProfile mandatory).
# Deployment protocol: see QM_FORWARD_DEMO.md in this folder.

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$eaSrc      = Join-Path $repoRoot 'CK_QM_SignalPlayer.mq5'
$sigSrc     = Join-Path $repoRoot '_signals_erl_h4.txt'
if (-not (Test-Path $sigSrc)) {
    # fallback to the CSV if the .txt isn't there
    $sigSrc = Join-Path $repoRoot '_signals_erl_h4.csv'
}

if (-not (Test-Path $eaSrc))  { Write-Host "ERROR: EA not found at $eaSrc";  exit 2 }
if (-not (Test-Path $sigSrc)) { Write-Host "ERROR: signals not found at repo root"; exit 2 }

# --- locate MetaEditor64.exe ---
$meCandidates = @(
    'C:\Program Files\MetaTrader 5\MetaEditor64.exe',
    'C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe',
    'C:\Program Files\FundedNext MT5\MetaEditor64.exe'
)
$me = $meCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $me) {
    $me = (Get-ChildItem 'C:\Program Files' -Recurse -Filter 'MetaEditor64.exe' `
        -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
}
if (-not $me) { Write-Host 'ERROR: MetaEditor64.exe not found under C:\Program Files.'; exit 3 }
Write-Host "MetaEditor : $me"

# --- locate MT5 data-dir (the terminal instance with MQL5\Experts) ---
$termRoot = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
$dataDir  = (Get-ChildItem $termRoot -Directory -ErrorAction SilentlyContinue |
             Where-Object { Test-Path (Join-Path $_.FullName 'MQL5\Experts') } |
             Select-Object -First 1).FullName
if (-not $dataDir) { Write-Host "ERROR: no MT5 data-dir under $termRoot"; exit 4 }
Write-Host "MT5 data-dir: $dataDir"

$expertsDir = Join-Path $dataDir 'MQL5\Experts'
$commonDir  = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
if (-not (Test-Path $commonDir)) { New-Item -ItemType Directory -Force $commonDir | Out-Null }

# --- copy files ---
$eaDst  = Join-Path $expertsDir 'CK_QM_SignalPlayer.mq5'
$sigDst = Join-Path $commonDir  'signals_erl_h4.csv'
Copy-Item -Path $eaSrc  -Destination $eaDst  -Force
Copy-Item -Path $sigSrc -Destination $sigDst -Force
Write-Host "Copied EA      -> $eaDst"
Write-Host "Copied signals -> $sigDst"

$sigLineCount = (Get-Content $sigDst | Measure-Object -Line).Lines
Write-Host "Signal file    -> $sigLineCount lines (header + signals)"

# --- compile ---
$ex5 = [System.IO.Path]::ChangeExtension($eaDst, '.ex5')
if (Test-Path $ex5) { Remove-Item $ex5 -Force }
$log = Join-Path $expertsDir 'CK_QM_SignalPlayer.log'
if (Test-Path $log) { Remove-Item $log -Force }

Write-Host 'Compiling ...'
$compArgs = @(('/compile:"{0}"' -f $eaDst), ('/log:"{0}"' -f $log))
Start-Process -FilePath $me -ArgumentList $compArgs -Wait -WindowStyle Hidden

if (-not (Test-Path $ex5)) {
    Write-Host 'COMPILE FAILED. MetaEditor log:'
    if (Test-Path $log) { Get-Content $log -Encoding Unicode | Select-Object -Last 40 }
    exit 5
}
$ex5Info = Get-Item $ex5
Write-Host ('COMPILE OK -> {0}  ({1} bytes, {2})' -f $ex5, $ex5Info.Length, $ex5Info.LastWriteTime)

Write-Host ''
Write-Host '===== NEXT STEPS (manual, in MT5) ====='
Write-Host '1. In MT5, open a XAUUSD chart, timeframe M15.'
Write-Host '2. Drag CK_QM_SignalPlayer from Navigator > Expert Advisors onto the chart.'
Write-Host '3. In the Inputs tab, set these values (SHIP config for FN $6k funded):'
Write-Host '     InpSignalFile      = signals_erl_h4.csv'
Write-Host '     InpUseCommonFiles  = true'
Write-Host '     InpRiskUSD         = 75         (NOT the 85 that breaches - see QM_FORWARD_DEMO.md)'
Write-Host '     InpMaxLot          = 0.20'
Write-Host '     InpMinLot          = 0.01'
Write-Host '     InpMaxConcurrent   = 2'
Write-Host '     InpToleranceMin    = 20'
Write-Host '     InpMaxSpreadPrice  = 0.60'
Write-Host '     InpUseTrail        = false      (H2 rejected in ledger seq272 - leave OFF)'
Write-Host '4. Tick "Allow Algo Trading" in the input dialog and press OK.'
Write-Host '5. Turn ON the global AutoTrading button in the top toolbar.'
Write-Host '6. Confirm the Experts tab shows: CK_QM_SignalPlayer: loaded N signals from ...'
Write-Host '7. Leave the terminal running on a stable VPS (see QM_VPS_SETUP.md).'
Write-Host ''
Write-Host 'CRITICAL - signal-file freshness:'
Write-Host '  The CSV committed with this kit ends 2026-07-27. Any signal older than 20 min'
Write-Host '  from now is auto-skipped. You MUST regenerate the CSV with fresh data before'
Write-Host '  going live. See QM_VPS_SETUP.md section "Signal regeneration workflow".'
Write-Host ''
Write-Host 'See QM_FORWARD_DEMO.md for the PASS/FAIL bar and QM_DEPLOY_CHECKLIST.md for daily checks.'

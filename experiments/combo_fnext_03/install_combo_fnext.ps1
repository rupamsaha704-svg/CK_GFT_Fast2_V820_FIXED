# install_combo_fnext.ps1
# Local install of the ship-ready combo_fnext_03 config into MT5.
# 1) Copies CK_GOLD_COMBO.mq5      -> MT5 data-dir MQL5\Experts\
# 2) Copies CK_GOLD_COMBO_FundedNext.set -> MT5 data-dir MQL5\Presets\
# 3) Compiles the EA with MetaEditor (headless).
# 4) Verifies .ex5 was produced.
# Attach + Load + Enable is a manual step in MT5 (there is no CLI for chart attach).
# Steering: §5 (MT5 is truth), §7 (this .set is the SHIPPING config), §10 (-NoProfile).
# Deployment protocol: see FORWARD_DEMO.md in this folder.

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$eaSrc      = Join-Path $repoRoot 'CK_GOLD_COMBO.mq5'
$setSrc     = Join-Path $PSScriptRoot 'CK_GOLD_COMBO_FundedNext.set'

if (-not (Test-Path $eaSrc))  { Write-Host "ERROR: EA not found at $eaSrc";  exit 2 }
if (-not (Test-Path $setSrc)) { Write-Host "ERROR: .set not found at $setSrc"; exit 2 }

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

# --- locate MT5 data-dir (the terminal instance that has an MQL5\Experts folder) ---
$termRoot = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
$dataDir  = (Get-ChildItem $termRoot -Directory -ErrorAction SilentlyContinue |
             Where-Object { Test-Path (Join-Path $_.FullName 'MQL5\Experts') } |
             Select-Object -First 1).FullName
if (-not $dataDir) { Write-Host "ERROR: no MT5 data-dir under $termRoot"; exit 4 }
Write-Host "MT5 data-dir: $dataDir"

$expertsDir = Join-Path $dataDir 'MQL5\Experts'
$presetsDir = Join-Path $dataDir 'MQL5\Presets'
if (-not (Test-Path $presetsDir)) { New-Item -ItemType Directory -Force $presetsDir | Out-Null }

# --- copy files ---
$eaDst  = Join-Path $expertsDir 'CK_GOLD_COMBO.mq5'
$setDst = Join-Path $presetsDir 'CK_GOLD_COMBO_FundedNext.set'
Copy-Item -Path $eaSrc  -Destination $eaDst  -Force
Copy-Item -Path $setSrc -Destination $setDst -Force
Write-Host "Copied EA   -> $eaDst"
Write-Host "Copied .set -> $setDst"

# --- compile ---
$ex5 = [System.IO.Path]::ChangeExtension($eaDst, '.ex5')
if (Test-Path $ex5) { Remove-Item $ex5 -Force }
$log = Join-Path $expertsDir 'CK_GOLD_COMBO.log'
if (Test-Path $log) { Remove-Item $log -Force }

Write-Host 'Compiling ...'
$compArgs = @(('/compile:"{0}"' -f $eaDst), ('/log:"{0}"' -f $log))
Start-Process -FilePath $me -ArgumentList $compArgs -Wait -WindowStyle Hidden

# --- verify ---
if (-not (Test-Path $ex5)) {
    Write-Host 'COMPILE FAILED. MetaEditor log:'
    if (Test-Path $log) { Get-Content $log | Select-Object -Last 40 }
    exit 5
}
$ex5Info = Get-Item $ex5
Write-Host ('COMPILE OK -> {0}  ({1} bytes, {2})' -f $ex5, $ex5Info.Length, $ex5Info.LastWriteTime)

Write-Host ''
Write-Host '===== NEXT STEPS (manual, in MT5) ====='
Write-Host '1. In MT5, open a XAUUSD chart, timeframe M15.'
Write-Host '2. Drag CK_GOLD_COMBO from Navigator > Expert Advisors onto the chart.'
Write-Host '3. In the Inputs tab click "Load" and pick CK_GOLD_COMBO_FundedNext.'
Write-Host '4. Verify these inputs from the preset:'
Write-Host '     Combo_Stage           = 0        (0=Eval, 1=Funded)'
Write-Host '     Combo_DailyRefInitial = true     (daily vs initial for FundedNext)'
Write-Host '     Combo_BlockEntryHours = 0,1      (settlement-window block)'
Write-Host '     FIX_FixedLot          = 0.02     (ship value; 0.03 breaches on $6k)'
Write-Host '     FIX_MaxLot            = 0.02'
Write-Host '     Combo_UseNewsGate     = true'
Write-Host '5. Tick "Allow Algo Trading" in the input dialog and press OK.'
Write-Host '6. Turn ON the global AutoTrading button in the top toolbar.'
Write-Host '7. Confirm the Experts tab shows: [COMBO] init bal=... MODE=EVAL'
Write-Host '8. Leave the terminal running on a stable VPS (see VPS_SETUP.md).'
Write-Host ''
Write-Host 'Do NOT change inputs, optimize, or intervene in trades during the forward-demo.'
Write-Host 'See FORWARD_DEMO.md for the PASS/FAIL bar and DEPLOY_CHECKLIST.md for daily checks.'

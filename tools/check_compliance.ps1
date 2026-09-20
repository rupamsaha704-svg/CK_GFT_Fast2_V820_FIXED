<#
  check_compliance.ps1 - one command, all GFT stages, for ONE MT5 window.

  Runs the deterministic rule engine (tools/gft_compliance.py) for step1, step2 and funded
  against an MT5 output directory and prints a single combined summary.

  POWER NOTE: this launches NO backtest. It only reads MT5 output that already exists
  (trades.csv + report.htm). Three tiny stdlib-Python passes - effectively zero CPU load.
  Run a backtest only when you actually need fresh trades, and only one at a time.

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\check_compliance.ps1 -Window experiments\combo_m4_funded2\windows\last1y
    powershell -ExecutionPolicy Bypass -File tools\check_compliance.ps1 -Window <dir> -Stages funded
    powershell -ExecutionPolicy Bypass -File tools\check_compliance.ps1 -Window <dir> -Initial 5000 -DayResetHour 0

  Exit code = worst outcome across the stages checked:
    0 CLEARED | 1 NOT CLEARED | 2 BREACH | 3 input error
#>
param(
    [Parameter(Mandatory=$true)][string]$Window,
    [string[]]$Stages = @("step1","step2","funded"),
    [double]$Initial = 5000,
    [int]$DayResetHour = 0,
    [string]$EquitySeries = "",
    [switch]$Quiet
)
$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$repoRoot  = Split-Path -Parent $scriptDir
$engine    = Join-Path $scriptDir "gft_compliance.py"
if (-not (Test-Path $engine)) { throw "rule engine missing: $engine" }

$envJson = Join-Path $scriptDir "env.json"
$python  = "C:\Python314\python.exe"
if (Test-Path $envJson) {
    try { $python = (Get-Content $envJson -Raw | ConvertFrom-Json).python } catch { }
}
if (-not (Test-Path $python)) { throw "python not found: $python" }

$wdir = if ([System.IO.Path]::IsPathRooted($Window)) { $Window } else { Join-Path $repoRoot $Window }
if (-not (Test-Path (Join-Path $wdir "trades.csv"))) {
    Write-Host "[check_compliance] INPUT ERROR: no trades.csv in $wdir" -ForegroundColor Red
    Write-Host "  Nothing to audit. Produce MT5 output first, then re-run this check."
    exit 3
}

$LABEL = @{ 0 = "CLEARED"; 1 = "NOT CLEARED"; 2 = "BREACH"; 3 = "INPUT ERROR" }
$COLOR = @{ 0 = "Green";   1 = "Yellow";      2 = "Red";     3 = "Red" }

Write-Host ""
Write-Host "================ GFT COMPLIANCE - ALL STAGES ================"
Write-Host "  window : $wdir"
Write-Host "  stages : $($Stages -join ', ')"
Write-Host "  (reads existing MT5 output only - no backtest launched)"
Write-Host ""

$worst = 0
$results = @()

foreach ($st in $Stages) {
    $outFile = Join-Path $wdir ("compliance_{0}.txt" -f $st)
    $args = @($engine, "--stage", $st, "--window", $wdir,
              "--initial", $Initial, "--day-reset-hour", $DayResetHour, "--out", $outFile)
    if ($EquitySeries) { $args += @("--equity-series", $EquitySeries) }

    & $python @args | Out-Null
    $code = $LASTEXITCODE
    if ($code -gt $worst) { $worst = $code }

    $verdict = $LABEL[$code]
    Write-Host ("  {0,-8} -> {1}" -f $st.ToUpper(), $verdict) -ForegroundColor $COLOR[$code]

    # Pull the breached rule / unverified rules straight out of the report we just wrote.
    if (Test-Path $outFile) {
        $txt = Get-Content $outFile
        if ($code -eq 2) {
            $line = ($txt | Select-String -Pattern '^\s+RULE BREACHED\s+:' | Select-Object -First 1)
            $at   = ($txt | Select-String -Pattern '^\s+AT\s+:'            | Select-Object -First 1)
            if ($line) { Write-Host ("             {0}" -f $line.Line.Trim()) -ForegroundColor Red }
            if ($at)   { Write-Host ("             {0}" -f $at.Line.Trim())   -ForegroundColor Red }
        } elseif ($code -eq 1) {
            foreach ($u in ($txt | Select-String -Pattern '^\s+\[UNVERIFIED\]')) {
                Write-Host ("             unverified: {0}" -f ($u.Line -replace '.*\[UNVERIFIED\]\s*','').Trim()) -ForegroundColor DarkYellow
            }
        }
        if (-not $Quiet) { Write-Host ("             report: {0}" -f $outFile) -ForegroundColor DarkGray }
    }
    Write-Host ""
}

Write-Host "============================================================="
Write-Host ("OVERALL: {0}" -f $LABEL[$worst]) -ForegroundColor $COLOR[$worst]
switch ($worst) {
    2 { Write-Host "  A hard rule was breached. STOP. Do not take this configuration to a real"
        Write-Host "  account - one breach permanently closes it. Fix the cause, then re-audit." -ForegroundColor Red }
    1 { Write-Host "  No breach found, but some rules could not be verified from this evidence."
        Write-Host "  'Not checkable' is not 'safe'. Close the gaps before risking money." -ForegroundColor Yellow }
    0 { Write-Host "  All applicable rules verified compliant on THIS window. Not a promise about"
        Write-Host "  future trading - forward-demo proof and human approval still required." -ForegroundColor Green }
}
Write-Host "============================================================="
exit $worst

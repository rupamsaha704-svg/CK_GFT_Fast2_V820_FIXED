<#
  run_candidate.ps1 - ONE command per candidate.
  Reads env.json + preset -> compiles the EA -> runs the MT5 Strategy Tester headless
  (real ticks / Model 4, ShutdownTerminal=1) for EACH declared window -> collects the
  MT5 native report AND the OnTester trade CSV per window -> runs metrics.py + pipeline.py
  -> writes experiments/<id>/report.md. All trade simulation happens in MT5; Python only reads.

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\run_candidate.ps1 -Preset experiments\fix09_proof\preset.json [-TimeoutSec 1200]
#>
param(
    [Parameter(Mandatory=$true)][string]$Preset,
    [int]$TimeoutSec = 1200
)
$ErrorActionPreference = "Stop"
$ProgressPreference     = "SilentlyContinue"

$scriptDir = $PSScriptRoot
$envCfg = Get-Content (Join-Path $scriptDir "env.json") -Raw | ConvertFrom-Json
$repoRoot    = $envCfg.repo_root
$terminal    = $envCfg.terminal64
$commonFiles = $envCfg.common_files
$testerLogs  = $envCfg.tester_logs
$python      = $envCfg.python

if (-not (Test-Path $Preset)) { throw "Preset not found: $Preset" }
$p = Get-Content $Preset -Raw | ConvertFrom-Json
$expDir = Split-Path -Parent (Resolve-Path $Preset)
$expId  = Split-Path -Leaf $expDir
$ea     = $p.ea
$tradesCsvName = $p.trades_csv
if (-not $tradesCsvName) { throw "preset.trades_csv (the OnTester CSV filename) is required." }

$winRoot = Join-Path $expDir "windows"
if (-not (Test-Path $winRoot)) { New-Item -ItemType Directory -Force $winRoot | Out-Null }

Write-Host "=== run_candidate: $expId (EA=$ea) ==="

# --- 1) Compile ---
Write-Host "[1] Compiling $ea ..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "compile_ea.ps1") -EaName $ea
if ($LASTEXITCODE -ne 0) { throw "Compile failed for $ea - aborting (never run on a failed compile)." }

# --- 2) Per-window tester runs ---
$commonCsv = Join-Path $commonFiles $tradesCsvName
$windowResults = @()

foreach ($win in $p.windows) {
    $wid = $win.id
    $wdir = Join-Path $winRoot $wid
    if (-not (Test-Path $wdir)) { New-Item -ItemType Directory -Force $wdir | Out-Null }
    $iniPath    = Join-Path $wdir "$wid.ini"
    # MT5 writes the tester report relative to its own dir(s), not to an arbitrary absolute
    # path, so we pass a bare, unique report NAME and locate the produced file afterwards.
    $reportName = "$expId`_$wid"
    $destCsv    = Join-Path $wdir "trades.csv"

    Write-Host "[2] Window '$wid' ($($win.from) to $($win.to))"

    # 2a) Build pinned .ini (GUARD #20 enforced inside make_ini)
    & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "make_ini.ps1") -Preset $Preset -WindowId $wid -IniPath $iniPath -ReportPath $reportName
    if ($LASTEXITCODE -ne 0) { throw "make_ini failed for window $wid." }

    # 2b) Clear stale OnTester CSV so we never read a previous run's output
    if (Test-Path $commonCsv) { Remove-Item $commonCsv -Force -ErrorAction SilentlyContinue }

    # 2c) Launch headless tester
    Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    $runStart = Get-Date       # used to select only THIS run's logs (never grab a stale one)
    Write-Host "    launching MT5 tester (real ticks; first run may download ticks)..."
    $proc = Start-Process $terminal -ArgumentList ('/config:"{0}"' -f $iniPath) -PassThru
    $proc | Wait-Process -Timeout $TimeoutSec -ErrorAction SilentlyContinue
    if (-not $proc.HasExited) { $proc | Stop-Process -Force -ErrorAction SilentlyContinue }
    Start-Sleep 3

    # 2d) Collect OnTester CSV
    $haveCsv = $false
    if (Test-Path $commonCsv) { Copy-Item $commonCsv $destCsv -Force; $haveCsv = $true }
    else { Write-Host "    WARNING: OnTester CSV not produced for '$wid'" }

    # 2e) Collect MT5 native report (MT5 writes <name>.htm[l] into its data dir or install dir)
    $reportHtml = $null
    $installDir = Split-Path $terminal -Parent
    $searchDirs = @($envCfg.data_dir, $installDir)
    foreach ($sd in $searchDirs) {
        foreach ($ext in @("html","htm")) {
            $cand = Join-Path $sd ("{0}.{1}" -f $reportName, $ext)
            if (Test-Path $cand) {
                $dest = Join-Path $wdir "report.$ext"
                Move-Item $cand $dest -Force -ErrorAction SilentlyContinue
                # MT5 also emits a sibling folder of images (<name>.htm files reference it) - move if present
                foreach ($imgDir in @((Join-Path $sd $reportName), (Join-Path $sd ("{0}.files" -f $reportName)))) {
                    if (Test-Path $imgDir) { Move-Item $imgDir (Join-Path $wdir (Split-Path $imgDir -Leaf)) -Force -ErrorAction SilentlyContinue }
                }
                $reportHtml = $dest; break
            }
        }
        if ($reportHtml) { break }
    }

    # 2f) Snapshot THIS run's logs only (LastWriteTime at/after launch) from both trees:
    #     terminal tester logs (summary) and agent logs (trade detail + OnTester Prints).
    $logSources = @()
    if ($testerLogs) { $logSources += $testerLogs }
    if ($envCfg.tester_agent_base -and (Test-Path $envCfg.tester_agent_base)) {
        $logSources += (Get-ChildItem $envCfg.tester_agent_base -Directory -Recurse -Filter "logs" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    }
    $fresh = @()
    foreach ($ls in ($logSources | Select-Object -Unique)) {
        if (-not (Test-Path $ls)) { continue }
        $fresh += Get-ChildItem $ls -Filter "*.log" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $runStart.AddSeconds(-2) }
    }
    $agentLog = $fresh | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($agentLog) { Copy-Item $agentLog.FullName (Join-Path $wdir "tester.log") -Force -ErrorAction SilentlyContinue }
    else { Write-Host "    note: no fresh tester log found for this run (stale logs skipped)" }

    $trades = 0
    if ($haveCsv) { $trades = (Get-Content $destCsv | Where-Object { $_ -and ($_ -notmatch '^time,') }).Count }
    Write-Host "    window '$wid': csv=$haveCsv trades=$trades report=$([bool]$reportHtml)"

    $windowResults += [pscustomobject]@{ id=$wid; from=$win.from; to=$win.to; csv=$destCsv; haveCsv=$haveCsv; trades=$trades; report=$reportHtml }
}

# --- 3) Metrics + deterministic verdict (Python reads MT5 outputs only) ---
$reportMd = Join-Path $expDir "report.md"
$lab = Join-Path $repoRoot "v1_lab"
$genUtc = (Get-Date).ToUniversalTime().ToString('u')

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Candidate report - $expId")
$lines.Add("")
$lines.Add("- EA: $ea")
$lines.Add("- Preset: $Preset")
$lines.Add("- Generated (UTC): $genUtc")
$lines.Add("- Trade simulator: MT5 Strategy Tester (real ticks, Model $($p.model)). Python analyzes MT5 outputs only.")
$lines.Add("")

foreach ($w in $windowResults) {
    $lines.Add("## Window: $($w.id)  ($($w.from) to $($w.to))")
    if ($w.haveCsv -and $w.trades -gt 0) {
        $lines.Add('```')
        $summary = & $python (Join-Path $lab "metrics.py") $w.csv $p.deposit 2>&1
        foreach ($s in $summary) { $lines.Add("$s") }
        $lines.Add('```')
    } else {
        $lines.Add("_No trades / CSV missing for this window._")
    }
    if ($w.report) { $lines.Add("- MT5 native report: $($w.report)") }
    $lines.Add("")
}

# Deterministic pipeline verdict: first window with trades = IS, second = OOS
$withTrades = @($windowResults | Where-Object { $_.haveCsv -and $_.trades -gt 0 })
if ($withTrades.Count -ge 1) {
    $lines.Add("## Deterministic verdict (pipeline.py)")
    $lines.Add('```')
    Push-Location $lab
    try {
        if ($withTrades.Count -ge 2) {
            $verdict = & $python "pipeline.py" --is $withTrades[0].csv --oos $withTrades[1].csv --deposit $p.deposit 2>&1
        } else {
            $verdict = & $python "pipeline.py" --is $withTrades[0].csv --deposit $p.deposit 2>&1
        }
    } finally { Pop-Location }
    foreach ($v in $verdict) { $lines.Add("$v") }
    $lines.Add('```')
    $verdict | Write-Host
}

Set-Content -Encoding UTF8 -Path $reportMd -Value $lines
Write-Host ""
Write-Host "[done] report -> $reportMd"

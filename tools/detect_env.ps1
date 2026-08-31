<#
  detect_env.ps1 — Environment doctor for the MT5-native research lab.
  Auto-detects MT5 + Python paths and SAVES them to tools/env.json.
  Every other script READS env.json — zero hard-coded paths.

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\detect_env.ps1
#>
$ErrorActionPreference = "Stop"
$ProgressPreference     = "SilentlyContinue"

function Find-First-File {
    param([string[]]$Candidates, [string]$Filename, [string[]]$SearchRoots)
    foreach ($c in $Candidates) { if (Test-Path $c) { return (Resolve-Path $c).Path } }
    foreach ($root in $SearchRoots) {
        if (-not (Test-Path $root)) { continue }
        # shallow scan: root + its immediate subdirectories only (fast, avoids deep-recurse hangs)
        $hit = Join-Path $root $Filename
        if (Test-Path $hit) { return (Resolve-Path $hit).Path }
        foreach ($d in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
            $hit = Join-Path $d.FullName $Filename
            if (Test-Path $hit) { return (Resolve-Path $hit).Path }
        }
    }
    return $null
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

Write-Host "=== MT5-native lab: environment detection ===" -ForegroundColor Cyan

# --- MT5 terminal + MetaEditor ---
$pfRoots = @("C:\Program Files","C:\Program Files (x86)")
$termCandidates = @(
    "C:\Program Files\MetaTrader 5\terminal64.exe",
    "C:\Program Files (x86)\MetaTrader 5\terminal64.exe"
)
$meCandidates = @(
    "C:\Program Files\MetaTrader 5\metaeditor64.exe",
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
)
$terminal   = Find-First-File -Candidates $termCandidates -Filename "terminal64.exe"   -SearchRoots $pfRoots
$metaeditor = Find-First-File -Candidates $meCandidates   -Filename "metaeditor64.exe" -SearchRoots $pfRoots

if (-not $terminal)   { throw "terminal64.exe not found. Edit tools\detect_env.ps1 candidates or install MT5." }
if (-not $metaeditor) { throw "metaeditor64.exe not found. Edit tools\detect_env.ps1 candidates." }

# --- MT5 data dir (the one containing MQL5\Experts) ---
$termBase = Join-Path $env:APPDATA "MetaQuotes\Terminal"
$dataDir = $null
if (Test-Path $termBase) {
    $dataDir = (Get-ChildItem $termBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "MQL5\Experts") } |
        Select-Object -First 1).FullName
}
if (-not $dataDir) { throw "MT5 data dir with MQL5\Experts not found under $termBase" }

$experts    = Join-Path $dataDir "MQL5\Experts"
$commonFiles = Join-Path $termBase "Common\Files"
$testerLogs = Join-Path $dataDir "Tester\logs"
$testerDir  = Join-Path $dataDir "Tester"
$termLogs   = Join-Path $dataDir "Logs"
# Agent logs (per-run trade detail + OnTester Print output) live under a SEPARATE tree:
#   %APPDATA%\MetaQuotes\Tester\<id>\Agent-127.0.0.1-<port>\logs
$testerAgentBase = Join-Path (Split-Path $termBase -Parent) "Tester"

# --- Python ---
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) { $python = (Get-Command py -ErrorAction SilentlyContinue).Source }
$pyVersion = if ($python) { & $python --version 2>&1 } else { "NOT FOUND" }

$env = [ordered]@{
    detected_utc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repo_root     = $repoRoot
    terminal64    = $terminal
    metaeditor64  = $metaeditor
    data_dir      = $dataDir
    experts_dir   = $experts
    common_files  = $commonFiles
    tester_dir    = $testerDir
    tester_logs   = $testerLogs
    tester_agent_base = $testerAgentBase
    terminal_logs = $termLogs
    python        = $python
    python_version = "$pyVersion".Trim()
}

$outDir = Join-Path $repoRoot "tools"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }
$outFile = Join-Path $outDir "env.json"
$env | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $outFile

Write-Host ""
Write-Host "Detected paths (confirm these once):" -ForegroundColor Green
foreach ($k in $env.Keys) { "{0,-15} {1}" -f $k, $env[$k] | Write-Host }
Write-Host ""

# --- Sanity checks ---
$warn = @()
foreach ($p in @($terminal,$metaeditor,$experts,$commonFiles,$testerDir)) {
    if (-not (Test-Path $p)) { $warn += "MISSING: $p" }
}
if ("$pyVersion" -notmatch "Python 3") { $warn += "Python 3 not confirmed ($pyVersion)" }
if ($warn.Count -gt 0) {
    Write-Host "WARNINGS:" -ForegroundColor Yellow
    $warn | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
} else {
    Write-Host "All key paths exist. env.json written to: $outFile" -ForegroundColor Green
}

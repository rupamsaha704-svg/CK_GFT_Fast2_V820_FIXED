<#
  compile_ea.ps1 — Deploy an EA into MQL5\Experts and compile it with MetaEditor,
  capturing and parsing the compile log. STOPS loudly on compile errors.

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\compile_ea.ps1 -EaName CK_GOLD_PRO_FIX09 [-LogDir <dir>]

  -EaName    : EA base name (without extension). Source resolved from repo root <EaName>.mq5,
               or pass -SourcePath to override.
  Returns exit code 0 on success, non-zero on failure.
#>
param(
    [Parameter(Mandatory=$true)][string]$EaName,
    [string]$SourcePath,
    [string]$LogDir
)
$ErrorActionPreference = "Stop"
$ProgressPreference     = "SilentlyContinue"

$scriptDir = $PSScriptRoot
$envFile   = Join-Path $scriptDir "env.json"
if (-not (Test-Path $envFile)) { throw "env.json not found. Run tools\detect_env.ps1 first." }
$envCfg = Get-Content $envFile -Raw | ConvertFrom-Json

$repoRoot   = $envCfg.repo_root
$metaeditor = $envCfg.metaeditor64
$experts    = $envCfg.experts_dir

if (-not $SourcePath) { $SourcePath = Join-Path $repoRoot ("{0}.mq5" -f $EaName) }
if (-not (Test-Path $SourcePath)) { throw "EA source not found: $SourcePath" }

if (-not $LogDir) { $LogDir = Join-Path $scriptDir "_compile" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force $LogDir | Out-Null }

# 1) Deploy source into Experts
$destMq5 = Join-Path $experts ("{0}.mq5" -f $EaName)
Copy-Item $SourcePath $destMq5 -Force
$destEx5 = [System.IO.Path]::ChangeExtension($destMq5, ".ex5")
if (Test-Path $destEx5) { Remove-Item $destEx5 -Force }

Write-Host "[compile] source : $SourcePath"
Write-Host "[compile] deploy : $destMq5"

# 2) Compile with log
$logFile = Join-Path $LogDir ("{0}.compile.log" -f $EaName)
if (Test-Path $logFile) { Remove-Item $logFile -Force }
$args = '/compile:"{0}" /log:"{1}"' -f $destMq5, $logFile
$p = Start-Process -FilePath $metaeditor -ArgumentList $args -PassThru
$p | Wait-Process -Timeout 120 -ErrorAction SilentlyContinue
if (-not $p.HasExited) { $p | Stop-Process -Force -ErrorAction SilentlyContinue }

# wait for ex5 / log to settle
for ($i=0; $i -lt 30; $i++) { if (Test-Path $destEx5) { break }; Start-Sleep -Milliseconds 500 }

# 3) Parse compile log (MetaEditor writes UTF-16)
$logText = ""
if (Test-Path $logFile) {
    try   { $logText = Get-Content $logFile -Raw -Encoding Unicode }
    catch { $logText = Get-Content $logFile -Raw }
}
Write-Host "----- compile log -----"
if ($logText) { Write-Host $logText.Trim() } else { Write-Host "(no log captured)" }
Write-Host "-----------------------"

$errCount  = 0
$warnCount = 0
if ($logText -match "(\d+)\s+error") { $errCount  = [int]$Matches[1] }
if ($logText -match "(\d+)\s+warning") { $warnCount = [int]$Matches[1] }

$compiled = Test-Path $destEx5
if (-not $compiled -or $errCount -gt 0) {
    Write-Host "[compile] FAILED (errors=$errCount, ex5 present=$compiled)" -ForegroundColor Red
    exit 1
}
Write-Host "[compile] OK (warnings=$warnCount) -> $destEx5" -ForegroundColor Green
exit 0

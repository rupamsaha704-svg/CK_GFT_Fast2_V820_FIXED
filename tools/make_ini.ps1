<#
  make_ini.ps1 — Emit a pinned MT5 Strategy-Tester .ini for ONE window from a preset.
  ENFORCES GUARD #20: parses every `input` declared in the EA source and FAILS LOUDLY
  if the preset does not pin all of them (so the tester can never fall back to cached GUI inputs).

  Usage (normally called by run_candidate.ps1):
    powershell -File tools\make_ini.ps1 -Preset experiments\id\preset.json -WindowId baseline `
        -IniPath out.ini -ReportPath out_report

  Returns exit 0 and prints the .ini path on success; throws on missing/extra inputs.
#>
param(
    [Parameter(Mandatory=$true)][string]$Preset,
    [Parameter(Mandatory=$true)][string]$WindowId,
    [Parameter(Mandatory=$true)][string]$IniPath,
    [Parameter(Mandatory=$true)][string]$ReportPath
)
$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$envCfg = Get-Content (Join-Path $scriptDir "env.json") -Raw | ConvertFrom-Json
$repoRoot = $envCfg.repo_root

if (-not (Test-Path $Preset)) { throw "Preset not found: $Preset" }
$p = Get-Content $Preset -Raw | ConvertFrom-Json

$ea = $p.ea
$eaSource = Join-Path $repoRoot ("{0}.mq5" -f $ea)
if (-not (Test-Path $eaSource)) { throw "EA source not found for input parse: $eaSource" }

# --- Parse every declared EA input name ---
$declared = @()
foreach ($line in (Get-Content $eaSource)) {
    if ($line -match '^\s*input\s+\w+(\s*<[^>]+>)?\s+(\w+)\s*=') { $declared += $Matches[2] }
    elseif ($line -match '^\s*input\s+[\w:]+\s+(\w+)\s*=') { $declared += $Matches[1] }
}
$declared = $declared | Select-Object -Unique

# --- Preset input coverage check (GUARD #20) ---
$presetInputs = @{}
foreach ($prop in $p.inputs.PSObject.Properties) { $presetInputs[$prop.Name] = $prop.Value }

$missing = @()
foreach ($d in $declared) { if (-not $presetInputs.ContainsKey($d)) { $missing += $d } }
$extra = @()
foreach ($k in $presetInputs.Keys) { if ($declared -notcontains $k) { $extra += $k } }

if ($missing.Count -gt 0) {
    throw "GUARD #20 VIOLATION: preset does not pin these EA inputs: $($missing -join ', '). Refusing to run (would fall back to cached GUI inputs)."
}
if ($extra.Count -gt 0) {
    Write-Host "[make_ini] WARNING: preset pins inputs not declared in EA (ignored by MT5): $($extra -join ', ')" -ForegroundColor Yellow
}

# --- Locate window ---
$win = $p.windows | Where-Object { $_.id -eq $WindowId } | Select-Object -First 1
if (-not $win) { throw "Window '$WindowId' not found in preset." }

# --- Format a value for the .ini (bools lowercase; numbers as-is) ---
function Format-IniValue($v) {
    if ($v -is [bool]) { if ($v) { return "true" } else { return "false" } }
    return "$v"
}

# --- Build the .ini ---
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("[Tester]")
[void]$sb.AppendLine("Expert=$ea.ex5")
[void]$sb.AppendLine("Symbol=$($p.symbol)")
[void]$sb.AppendLine("Period=$($p.period)")
[void]$sb.AppendLine("Model=$($p.model)")
[void]$sb.AppendLine("ExecutionMode=$($p.execution_mode)")
[void]$sb.AppendLine("FromDate=$($win.from)")
[void]$sb.AppendLine("ToDate=$($win.to)")
[void]$sb.AppendLine("ForwardMode=0")
[void]$sb.AppendLine("Deposit=$($p.deposit)")
[void]$sb.AppendLine("Currency=$($p.currency)")
[void]$sb.AppendLine("Leverage=$($p.leverage)")
[void]$sb.AppendLine("Optimization=0")
[void]$sb.AppendLine("Report=$ReportPath")
[void]$sb.AppendLine("ReplaceReport=1")
[void]$sb.AppendLine("ShutdownTerminal=1")
[void]$sb.AppendLine("Visual=0")
[void]$sb.AppendLine("[TesterInputs]")
foreach ($d in $declared) {
    $val = Format-IniValue $presetInputs[$d]
    [void]$sb.AppendLine("$d=$val")
}

# MT5 .ini files are read as ANSI/UTF-16; ASCII is safest here.
Set-Content -Encoding ascii -Path $IniPath -Value $sb.ToString()
Write-Host "[make_ini] window '$WindowId' -> $IniPath (pinned $($declared.Count) inputs)" -ForegroundColor Green
exit 0

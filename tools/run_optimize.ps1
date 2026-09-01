<#
  run_optimize.ps1 - MT5 native Strategy-Tester OPTIMIZATION, used for PLATEAU/robustness ONLY.

  DISCIPLINE (anti-overfit, non-negotiable):
    * We run MT5's own optimizer (complete grid or genetic, multi-core) to MAP the result surface.
    * We NEVER auto-select the peak pass. parse_opt.py reports whether a BROAD profitable plateau
      exists and gives a ROBUST (median/centre) parameter choice - a lone spike is flagged overfit.
    * GUARD #20 still holds: every EA input is accounted for (pinned OR swept); nothing falls back
      to cached GUI values.
    * MT5 is the only simulator; Python only reads MT5's exported XML.

  Opt-preset JSON (experiments\<id>\opt.json):
    { ea, trades_csv, symbol, period, model(1 fast/4 truth), execution_mode, deposit, currency,
      leverage, optimization(1 complete|2 genetic), opt_criterion(0..6), forward_mode(0..4),
      forward_date("YYYY.MM.DD" if forward_mode=4),
      opt_window:{from,to},
      sweep:{ InpX:{start,step,stop}, ... },
      inputs:{ ...ALL declared EA inputs pinned (swept ones give the base value)... } }

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\run_optimize.ps1 -OptPreset experiments\v23_opt\opt.json [-TimeoutSec 1800]
#>
param(
    [Parameter(Mandatory=$true)][string]$OptPreset,
    [int]$TimeoutSec = 1800
)
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$envCfg = Get-Content (Join-Path $scriptDir "env.json") -Raw | ConvertFrom-Json
$repoRoot = $envCfg.repo_root
$terminal = $envCfg.terminal64
$py       = $envCfg.python

if (-not (Test-Path $OptPreset)) { throw "Opt-preset not found: $OptPreset" }
$p = Get-Content $OptPreset -Raw | ConvertFrom-Json
$expDir = Split-Path -Parent (Resolve-Path $OptPreset)
$expId  = Split-Path -Leaf $expDir
$ea = $p.ea

# --- Compile EA (never optimize a stale/failed build) ---
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "compile_ea.ps1") -EaName $ea
if ($LASTEXITCODE -ne 0) { throw "Compile failed for $ea - aborting." }

# --- GUARD #20: every declared EA input must be pinned or swept ---
$eaSource = Join-Path $repoRoot ("{0}.mq5" -f $ea)
if (-not (Test-Path $eaSource)) { throw "EA source not found: $eaSource" }
$declared = @()
foreach ($line in (Get-Content $eaSource)) {
    if ($line -match '^\s*input\s+\w+(\s*<[^>]+>)?\s+(\w+)\s*=') { $declared += $Matches[2] }
    elseif ($line -match '^\s*input\s+[\w:]+\s+(\w+)\s*=') { $declared += $Matches[1] }
}
$declared = $declared | Select-Object -Unique
$pin = @{}; foreach ($prop in $p.inputs.PSObject.Properties) { $pin[$prop.Name] = $prop.Value }
$sweep = @{}; if ($p.sweep) { foreach ($prop in $p.sweep.PSObject.Properties) { $sweep[$prop.Name] = $prop.Value } }
$missing = @(); foreach ($d in $declared) { if (-not $pin.ContainsKey($d)) { $missing += $d } }
if ($missing.Count -gt 0) { throw "GUARD #20 VIOLATION: opt-preset does not pin/declare EA inputs: $($missing -join ', ')." }
foreach ($s in $sweep.Keys) { if ($declared -notcontains $s) { throw "sweep names input '$s' not declared in EA." } }

function Fmt($v) { if ($v -is [bool]) { if ($v) {"true"} else {"false"} } else { "$v" } }

# --- Build optimization .ini ---
$reportName = "opt_$expId"
$ini = Join-Path $expDir "$reportName.ini"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("[Tester]")
[void]$sb.AppendLine("Expert=$ea.ex5")
[void]$sb.AppendLine("Symbol=$($p.symbol)")
[void]$sb.AppendLine("Period=$($p.period)")
[void]$sb.AppendLine("Model=$($p.model)")
[void]$sb.AppendLine("ExecutionMode=$($p.execution_mode)")
[void]$sb.AppendLine("FromDate=$($p.opt_window.from)")
[void]$sb.AppendLine("ToDate=$($p.opt_window.to)")
[void]$sb.AppendLine("ForwardMode=$($p.forward_mode)")
if ($p.forward_mode -eq 4 -and $p.forward_date) { [void]$sb.AppendLine("ForwardDate=$($p.forward_date)") }
[void]$sb.AppendLine("Deposit=$($p.deposit)")
[void]$sb.AppendLine("Currency=$($p.currency)")
[void]$sb.AppendLine("Leverage=$($p.leverage)")
[void]$sb.AppendLine("Optimization=$($p.optimization)")           # 1 complete grid | 2 genetic
[void]$sb.AppendLine("OptimizationCriterion=$($p.opt_criterion)") # only steers search; we parse ALL passes
[void]$sb.AppendLine("Report=$reportName")                        # optimization => <name>.xml (all passes)
[void]$sb.AppendLine("ReplaceReport=1")
[void]$sb.AppendLine("ShutdownTerminal=1")
[void]$sb.AppendLine("Visual=0")
[void]$sb.AppendLine("[TesterInputs]")
foreach ($d in $declared) {
    $base = Fmt $pin[$d]
    if ($sweep.ContainsKey($d)) {
        $s = $sweep[$d]
        [void]$sb.AppendLine("$d=$base||$(Fmt $s.start)||$(Fmt $s.step)||$(Fmt $s.stop)||Y")
    } else {
        [void]$sb.AppendLine("$d=$base||$base||0||$base||N")
    }
}
Set-Content -Encoding ascii -Path $ini -Value $sb.ToString()
Write-Host "[opt] ini -> $ini  (sweep: $($sweep.Keys -join ', '); pinned $($declared.Count - $sweep.Count))"

# --- Launch optimization (multi-core handled by MT5) ---
Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
$runStart = Get-Date
Write-Host "[opt] launching MT5 optimizer (Optimization=$($p.optimization), forward=$($p.forward_mode))..."
$proc = Start-Process $terminal -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
$proc | Wait-Process -Timeout $TimeoutSec -ErrorAction SilentlyContinue
if (-not $proc.HasExited) { $proc | Stop-Process -Force -ErrorAction SilentlyContinue }
Start-Sleep 3

# --- Collect the exported XML(s): <name>.xml and (if forward) <name>.forward.xml ---
$installDir = Split-Path $terminal -Parent
$searchDirs = @($envCfg.data_dir, $installDir)
$found = @{}
foreach ($sd in $searchDirs) {
    foreach ($suffix in @("", ".forward")) {
        $cand = Join-Path $sd ("{0}{1}.xml" -f $reportName, $suffix)
        if ((Test-Path $cand) -and (Get-Item $cand).LastWriteTime -ge $runStart.AddSeconds(-2)) {
            $tag = if ($suffix) { "forward" } else { "is" }
            if (-not $found.ContainsKey($tag)) {
                $dest = Join-Path $expDir ("opt_results{0}.xml" -f ($(if($suffix){"_forward"}else{""})))
                Move-Item $cand $dest -Force
                $found[$tag] = $dest
                Write-Host "[opt] collected $tag results -> $dest"
            }
        }
    }
}
if (-not $found.ContainsKey("is")) { Write-Host "[opt] WARNING: optimization XML not found (did the run finish? check tester logs)"; exit 3 }

# --- Plateau / robustness diagnosis (never cherry-picks the peak) ---
$sweepNames = ($sweep.Keys -join ",")
$parseArgs = @((Join-Path $scriptDir "parse_opt.py"), "--xml", $found["is"], "--sweep", $sweepNames, "--out", (Join-Path $expDir "plateau_report.txt"))
if ($found.ContainsKey("forward")) { $parseArgs += @("--forward", $found["forward"]) }
& $py @parseArgs
Write-Host "[opt] plateau report -> $(Join-Path $expDir 'plateau_report.txt')"

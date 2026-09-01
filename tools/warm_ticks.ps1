<#
  warm_ticks.ps1 - warm the MT5 real-tick cache ONCE so later Model-4 runs are fast.

  It checks which monthly tick files (bases\<server>\ticks\<symbol>\<yyyyMM>.tkc) already exist
  and only launches a headless tester (Model 4, real ticks) for the range if months are MISSING.
  If everything is already cached it is a no-op. Cache is period-independent (ticks are ticks),
  so we warm once on M15 and every timeframe benefits.

  Usage:
    powershell -ExecutionPolicy Bypass -File tools\warm_ticks.ps1
    powershell -File tools\warm_ticks.ps1 -Symbols XAUUSD,XAGUSD -From 2025.05.01 -To 2026.08.28 [-Force]
#>
param(
    [string[]]$Symbols = @("XAUUSD","XAGUSD"),
    [string]$From = "2025.06.01",   # earliest window start (IS_2025H2); avoids chasing unused months
    [string]$To   = "2026.08.28",
    [string]$WarmEa = "CK_GFT_Fast_v23_ROBUST",
    [int]$TimeoutSec = 1800,
    [switch]$Force
)
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$envCfg = Get-Content (Join-Path $scriptDir "env.json") -Raw | ConvertFrom-Json
$terminal = $envCfg.terminal64
$dataDir  = $envCfg.data_dir
$basesDir = Join-Path $dataDir "bases"

# months required by the range (yyyyMM)
$d0 = [datetime]::ParseExact($From, "yyyy.MM.dd", $null)
$d1 = [datetime]::ParseExact($To,   "yyyy.MM.dd", $null)
$need = @()
$cur = Get-Date -Year $d0.Year -Month $d0.Month -Day 1
while ($cur -le $d1) { $need += $cur.ToString("yyyyMM"); $cur = $cur.AddMonths(1) }

function Get-CachedMonths($sym) {
    $months = @()
    Get-ChildItem $basesDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $td = Join-Path $_.FullName "ticks\$sym"
        if (Test-Path $td) {
            Get-ChildItem $td -Filter "*.tkc" -ErrorAction SilentlyContinue | ForEach-Object {
                $months += [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            }
        }
    }
    return ($months | Select-Object -Unique)
}

foreach ($sym in $Symbols) {
    $have = Get-CachedMonths $sym
    $missing = @($need | Where-Object { $_ -notin $have })
    if ($missing.Count -eq 0 -and -not $Force) {
        Write-Host "[warm] $sym : already warm ($($need.Count) months cached: $($need[0])..$($need[-1])) - skip"
        continue
    }
    Write-Host "[warm] $sym : $($missing.Count) month(s) missing $(if($missing){'-> '+($missing -join ',')})$(if($Force){' (Force)'})  downloading via headless tester..."

    $ini = Join-Path $env:TEMP "warm_$sym.ini"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("[Tester]")
    [void]$sb.AppendLine("Expert=$WarmEa.ex5")
    [void]$sb.AppendLine("Symbol=$sym")
    [void]$sb.AppendLine("Period=M15")
    [void]$sb.AppendLine("Model=4")            # every tick based on real ticks = forces real-tick cache
    [void]$sb.AppendLine("ExecutionMode=0")
    [void]$sb.AppendLine("FromDate=$From")
    [void]$sb.AppendLine("ToDate=$To")
    [void]$sb.AppendLine("ForwardMode=0")
    [void]$sb.AppendLine("Deposit=50000")
    [void]$sb.AppendLine("Currency=USD")
    [void]$sb.AppendLine("Leverage=10")
    [void]$sb.AppendLine("Optimization=0")
    [void]$sb.AppendLine("ShutdownTerminal=1")
    [void]$sb.AppendLine("Visual=0")
    Set-Content -Encoding ascii -Path $ini -Value $sb.ToString()

    Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    $proc = Start-Process $terminal -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
    $proc | Wait-Process -Timeout $TimeoutSec -ErrorAction SilentlyContinue
    if (-not $proc.HasExited) { $proc | Stop-Process -Force -ErrorAction SilentlyContinue }
    Start-Sleep 3

    $have2 = Get-CachedMonths $sym
    $still = @($need | Where-Object { $_ -notin $have2 })
    if ($still.Count -eq 0) { Write-Host "[warm] $sym : now fully cached ($($need.Count) months)." }
    else { Write-Host "[warm] $sym : still missing $($still -join ',') (broker may not have this history)." }
}
Write-Host "[warm] done."

$ErrorActionPreference="Continue"
$research="C:\Users\prita\CK_GFT_V22_RESEARCH"
if(-not (Test-Path $research)){ New-Item -ItemType Directory -Force $research | Out-Null }
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if(-not $term){ Write-Host "MT5 not found"; exit }

function LastBalance {
  $logs=Get-ChildItem "$env:APPDATA\MetaQuotes" -Recurse -Include *.log -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match "logs" } | Sort-Object LastWriteTime -Descending | Select-Object -First 3
  $best=$null; $bestT=[datetime]::MinValue
  foreach($l in $logs){
    $b=[IO.File]::ReadAllBytes($l.FullName)
    if(($b[0..([Math]::Min(2000,$b.Length-1))] -contains 0)){ $t=[Text.Encoding]::Unicode.GetString($b) } else { $t=[Text.Encoding]::UTF8.GetString($b) }
    $m=[regex]::Matches($t,'final balance ([\d\. ]+) USD')
    if($m.Count -gt 0 -and $l.LastWriteTime -gt $bestT){ $bestT=$l.LastWriteTime; $best=$m[$m.Count-1].Groups[1].Value.Trim() }
  }
  return $best
}
function Run($risk,$maxlot){
  $ini=Join-Path $research "risk.ini"
  $cfg="[Tester]`nExpert=CK_GFT_Fast_v23_ROBUST.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=0`nFromDate=2025.08.01`nToDate=2026.08.01`nDeposit=5000`nCurrency=USD`nLeverage=100`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpRiskPercent=$risk`nInpMaxLot=$maxlot`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  $p | Wait-Process -Timeout 150 -ErrorAction SilentlyContinue
  if(-not $p.HasExited){ $p | Stop-Process -Force -ErrorAction SilentlyContinue }
  Start-Sleep 3
  return (LastBalance)
}
Write-Host "==== v23 RISK SCAN (XAUUSD M15, FULL 12 months) : how much risk to reach +30000 ? ===="
Write-Host "   (higher profit here = higher leverage = proportionally higher blow-up risk)"
foreach($risk in 0.5,1.0,1.5,2.0){
  $bal=Run $risk 5.0
  $net=0.0; if($bal){ $net=[double]($bal -replace '[^\d\.-]','') - 5000 }
  $flag=""; if($net -ge 30000){ $flag="  <-- reaches +30k target (BUT high risk)" }
  Write-Host ("  Risk%=" + $risk + "  MaxLot=5.0  -> final=" + ("{0}" -f $bal).PadRight(12) + " net=" + ("{0:+0.0;-0.0;0}" -f $net) + $flag)
}
Write-Host "==== done ===="
Write-Host "HONEST NOTE: profit scales with risk, and so does drawdown / risk-of-ruin."
Write-Host "A +30k backtest at high risk is NOT a safe edge - it is leverage. Deploy only tiny risk live."

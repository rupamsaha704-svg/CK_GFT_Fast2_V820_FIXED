$ErrorActionPreference="Continue"
$research="C:\Users\prita\CK_GFT_V22_RESEARCH"
if(-not (Test-Path $research)){ New-Item -ItemType Directory -Force $research | Out-Null }
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if(-not $term){ Write-Host "MT5 not found"; exit }
$RR=3.0; $SL=2.5   # best IS config

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
function Run($from,$to){
  $ini=Join-Path $research "vbest.ini"
  $cfg="[Tester]`nExpert=CK_GFT_Fast_v23_ROBUST.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=0`nFromDate=$from`nToDate=$to`nDeposit=5000`nCurrency=USD`nLeverage=100`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=$RR`nInpMaxSL_ATR=$SL`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  $p | Wait-Process -Timeout 150 -ErrorAction SilentlyContinue
  if(-not $p.HasExited){ $p | Stop-Process -Force -ErrorAction SilentlyContinue }
  Start-Sleep 3
  return (LastBalance)
}
function Show($label,$from,$to){
  $bal=Run $from $to
  $net=0.0; if($bal){ $net=[double]($bal -replace '[^\d\.-]','') - 5000 }
  Write-Host ("  " + $label.PadRight(34) + " final=" + ("{0}" -f $bal).PadRight(12) + " net=" + ("{0:+0.0;-0.0;0}" -f $net))
}
Write-Host "==== v23 BEST config (RR=3, SL_ATR=2.5) consistency across the 1-year window ===="
Show "Q1 IS  2025.08 -> 2025.11" "2025.08.01" "2025.11.01"
Show "Q2 IS  2025.11 -> 2026.02" "2025.11.01" "2026.02.01"
Show "Q3 OOS 2026.02 -> 2026.05" "2026.02.01" "2026.05.01"
Show "Q4 OOS 2026.05 -> 2026.08" "2026.05.01" "2026.08.01"
Show "FULL   2025.08 -> 2026.08" "2025.08.01" "2026.08.01"
Write-Host "==== done ===="
Write-Host "Read: profitable in ALL quarters incl. OOS = robust; profit only in 1 quarter = one lucky trend."

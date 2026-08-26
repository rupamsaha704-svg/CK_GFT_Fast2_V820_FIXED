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
function RunCfg($rr,$slatr,$from,$to){
  $ini=Join-Path $research "opt.ini"
  $cfg="[Tester]`nExpert=CK_GFT_Fast_v23_ROBUST.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=0`nFromDate=$from`nToDate=$to`nDeposit=5000`nCurrency=USD`nLeverage=100`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=$rr`nInpMaxSL_ATR=$slatr`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  $p | Wait-Process -Timeout 150 -ErrorAction SilentlyContinue
  if(-not $p.HasExited){ $p | Stop-Process -Force -ErrorAction SilentlyContinue }
  Start-Sleep 3
  return (LastBalance)
}
Write-Host "==== v23 IN-SAMPLE optimization (XAUUSD M15, Aug 2025 - Apr 2026) : final balance from 5000 ===="
$rows=@()
foreach($rr in 1.0,1.5,2.0,3.0){
  foreach($sl in 2.5,4.0){
    $bal=RunCfg $rr $sl "2025.08.01" "2026.04.01"
    $net = 0.0; if($bal){ $net = [double]($bal -replace '[^\d\.-]','') - 5000 }
    Write-Host ("RR=" + $rr + "  SL_ATR=" + $sl + "  -> final=" + $bal + "  (net " + ("{0:+0.0;-0.0;0}" -f $net) + ")")
    $rows += [pscustomobject]@{RR=$rr;SL=$sl;Net=$net}
  }
}
Write-Host ""
$best=$rows | Sort-Object Net -Descending | Select-Object -First 1
Write-Host ("BEST IS config -> RR=" + $best.RR + "  SL_ATR=" + $best.SL + "  net=" + ("{0:+0.0;-0.0;0}" -f $best.Net))
Write-Host "(next step: OOS-validate this best config)"
Write-Host "==== done ===="

$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Parameter-neighbourhood grid: vary ONE param at a time around the FROZEN center (EMA20/Age12/BE0.50),
# to test STABILITY (plateau vs lonely spike) - NOT to pick a 'best'. Emits grid_results.csv for
# paramstability.py. 7 backtests (1-year each) -> a few minutes each.
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_gold_pro_fix09_trades.csv"
$out=Join-Path $research "grid_results.csv"

Write-Host "downloading + compiling CK_GOLD_PRO_FIX09..."
Invoke-WebRequest "$base/CK_GOLD_PRO_FIX09.mq5" -OutFile (Join-Path $exp "CK_GOLD_PRO_FIX09.mq5")
$mq=Join-Path $exp "CK_GOLD_PRO_FIX09.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "compile FAILED";exit}
Set-Content -Encoding ascii $out "label,is_center,pf,net"

function RunCombo($label,$isC,$ema,$age,$be){
   $ini=Join-Path $research "grid.ini"
   $cfg="[Tester]`nExpert=CK_GOLD_PRO_FIX09.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpFixedLot=0.09`nInpMaxLot=0.09`nInpRiskPercent=2.0`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpMaxSpreadPrice=0.60`nInpEntryEMA=$ema`nInpBreakoutMaxAge=$age`nInpBEProgress=$be`n"
   Set-Content -Encoding ascii $ini $cfg
   if(Test-Path $csv){Remove-Item $csv -Force}
   Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
   $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
   $p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
   if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 2
   $rows=@(Get-Content $csv -ErrorAction SilentlyContinue | Where-Object { $_ -and ($_ -notmatch '^time,') })
   $gw=0.0;$gl=0.0;$net=0.0; foreach($r in $rows){ $q=[double]($r.Split(",")[1]); $net+=$q; if($q -gt 0){$gw+=$q}elseif($q -lt 0){$gl+=[Math]::Abs($q)} }
   $pf=if($gl -gt 0){$gw/$gl}else{0}
   Add-Content $out ("{0},{1},{2},{3}" -f $label,$isC,[math]::Round($pf,2),[math]::Round($net))
   Write-Host ("  {0}: PF {1:N2} net {2:N0}" -f $label,$pf,$net)
}
Write-Host "running neighbourhood (7 runs, center=EMA20/Age12/BE0.50)..."
RunCombo "EMA20_Age12_BE0.50" 1 20 12 0.50
RunCombo "EMA19_Age12_BE0.50" 0 19 12 0.50
RunCombo "EMA21_Age12_BE0.50" 0 21 12 0.50
RunCombo "EMA20_Age10_BE0.50" 0 20 10 0.50
RunCombo "EMA20_Age14_BE0.50" 0 20 14 0.50
RunCombo "EMA20_Age12_BE0.45" 0 20 12 0.45
RunCombo "EMA20_Age12_BE0.55" 0 20 12 0.55
Write-Host ""
Write-Host "=====PARAMGRID_START====="
Get-Content $out
Write-Host "=====PARAMGRID_END====="
Write-Host "^ Copy this block back to me (feeds paramstability.py: plateau vs lonely-spike verdict)."

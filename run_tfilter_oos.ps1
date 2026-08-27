$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# DECISIVE overfit check: run the SAME time filter (4,6,13,15h + Tue,Thu) on an OUT-OF-SAMPLE window
# 2022.08.01 -> 2025.08.01 (3 yrs BEFORE the 2025-26 data the filter was derived from). Model 4 real
# ticks. If ON meaningfully beats OFF here too => the time-of-day effect is structural (keepable).
# If ON does NOT help (or hurts) => the filter is overfit to 2025-26 and must be rejected.
# NOTE: 2 x 3-year real-tick runs => this can take a while.
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_v23tf_trades.csv"

Write-Host "[1] downloading + compiling CK_GFT_v23_tfilter..."
Invoke-WebRequest "$base/CK_GFT_v23_tfilter.mq5" -OutFile (Join-Path $exp "CK_GFT_v23_tfilter.mq5")
$mq=Join-Path $exp "CK_GFT_v23_tfilter.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

function RunBT($useFilter,$saveAs){
   $ini=Join-Path $research "tfoos.ini"
   $cfg="[Tester]`nExpert=CK_GFT_v23_tfilter.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2022.08.01`nToDate=2025.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRiskPercent=1.7`nInpMaxLot=0.09`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpMaxSpreadPrice=0.60`nInpUseTimeFilter=$useFilter`nInpBlockHours=4,6,13,15`nInpBlockDOW=2,4`n"
   Set-Content -Encoding ascii $ini $cfg
   if(Test-Path $csv){Remove-Item $csv -Force}
   Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
   $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
   $p|Wait-Process -Timeout 1500 -ErrorAction SilentlyContinue
   if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3
   if(Test-Path $csv){ Copy-Item $csv $saveAs -Force }
}
Write-Host "[2] OOS filter OFF (2022-2025)..."; RunBT "false" (Join-Path $research "oos_off.csv")
Write-Host "[3] OOS filter ON  (2022-2025, same 4,6,13,15h+Tue,Thu)..."; RunBT "true" (Join-Path $research "oos_on.csv")
function Metrics($f){ if(-not(Test-Path $f)){return $null}
   $rows=@(Get-Content $f | Where-Object { $_ -and ($_ -notmatch '^time,') })
   $n=$rows.Count; $net=0.0; $gw=0.0; $gl=0.0; $wins=0; $eq=5000.0; $peak=5000.0; $mdd=0.0
   foreach($r in $rows){ $p=[double]($r.Split(",")[1]); $net+=$p; if($p -gt 0){$gw+=$p;$wins++}elseif($p -lt 0){$gl+=[Math]::Abs($p)}
      $eq+=$p; if($eq -gt $peak){$peak=$eq}; $dd=($peak-$eq)/$peak; if($dd -gt $mdd){$mdd=$dd} }
   $pf=if($gl -gt 0){$gw/$gl}else{0}; $wr=if($n){100.0*$wins/$n}else{0}
   return [pscustomobject]@{n=$n;net=$net;pf=$pf;wr=$wr;mdd=100.0*$mdd} }
$off=Metrics (Join-Path $research "oos_off.csv"); $on=Metrics (Join-Path $research "oos_on.csv")
Write-Host "=====TFILTER_OOS_START====="
Write-Host "window: 2022.08.01 -> 2025.08.01 (OUT-OF-SAMPLE; filter NOT derived from this)"
if($off){ Write-Host ("OFF: trades {0,4}  net {1,9:N0}  PF {2:N2}  WR {3:N1}%%  closedDD {4:N1}%%" -f $off.n,$off.net,$off.pf,$off.wr,$off.mdd) }
if($on){  Write-Host ("ON : trades {0,4}  net {1,9:N0}  PF {2:N2}  WR {3:N1}%%  closedDD {4:N1}%%" -f $on.n,$on.net,$on.pf,$on.wr,$on.mdd) }
Write-Host "-----"
Write-Host "STRUCTURAL (keep filter) if ON clearly beats OFF here too. OVERFIT (reject) if ON does not help / hurts."
Write-Host "=====TFILTER_OOS_END====="
Write-Host "^ Copy this block back to me."

$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Robustness check: run v23_live on M5, M15, M30 (same year, risk 1.7%, real ticks). Compare metrics.
# NOTE: EMA/ATR/breakout are in BARS, so each timeframe is effectively a different strategy - this
# tests behaviour/robustness, it is NOT a claim any single TF is "the" edge.
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_v23live_trades.csv"

Write-Host "[1] downloading + compiling CK_GFT_v23_live..."
Invoke-WebRequest "$base/CK_GFT_v23_live.mq5" -OutFile (Join-Path $exp "CK_GFT_v23_live.mq5")
$mq=Join-Path $exp "CK_GFT_v23_live.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

function RunTF($period){
   $ini=Join-Path $research "tf.ini"
   $cfg="[Tester]`nExpert=CK_GFT_v23_live.ex5`nSymbol=XAUUSD`nPeriod=$period`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRiskPercent=1.7`nInpMaxLot=0.09`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpMaxSpreadPrice=0.60`n"
   Set-Content -Encoding ascii $ini $cfg
   if(Test-Path $csv){Remove-Item $csv -Force}
   Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
   $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
   $p|Wait-Process -Timeout 1200 -ErrorAction SilentlyContinue
   if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3
   if(Test-Path $csv){ Copy-Item $csv (Join-Path $research ("tf_"+$period+".csv")) -Force }
}
function Metrics($f){
   if(-not(Test-Path $f)){return $null}
   $rows=@(Get-Content $f | Where-Object { $_ -and ($_ -notmatch '^time,') })
   $n=$rows.Count; $net=0.0; $gw=0.0; $gl=0.0; $wins=0; $eq=5000.0; $peak=5000.0; $mdd=0.0
   foreach($r in $rows){ $p=[double]($r.Split(",")[1]); $net+=$p; if($p -gt 0){$gw+=$p;$wins++}elseif($p -lt 0){$gl+=[Math]::Abs($p)}
      $eq+=$p; if($eq -gt $peak){$peak=$eq}; $dd=($peak-$eq)/$peak; if($dd -gt $mdd){$mdd=$dd} }
   $pf=if($gl -gt 0){$gw/$gl}else{0}; $wr=if($n){100.0*$wins/$n}else{0}
   return [pscustomobject]@{n=$n;net=$net;ret=100.0*$net/5000;pf=$pf;wr=$wr;mdd=100.0*$mdd}
}
Write-Host "[2] backtest M5 (may be slow - more bars)..."; RunTF "M5"
Write-Host "[3] backtest M15..."; RunTF "M15"
Write-Host "[4] backtest M30..."; RunTF "M30"
Write-Host "[5] comparison:"
Write-Host "=====TF_START====="
foreach($tf in @("M5","M15","M30")){ $m=Metrics (Join-Path $research ("tf_"+$tf+".csv"))
   if($m){ Write-Host ("{0,-4}: trades {1,4}  net {2,8:N0}  ret {3,7:N1}%%  PF {4:N2}  WR {5:N1}%%  closedDD {6:N1}%%" -f $tf,$m.n,$m.net,$m.ret,$m.pf,$m.wr,$m.mdd) }
   else { Write-Host ("{0,-4}: no CSV / failed" -f $tf) } }
Write-Host "=====TF_END====="
Write-Host "^ Copy this block back to me."

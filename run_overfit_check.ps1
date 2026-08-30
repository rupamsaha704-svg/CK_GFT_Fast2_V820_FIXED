$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# OVERFIT CHECK: tuned (EntryEMA21/MaxAge9/BE0.44) vs original (20/12/0.50), each on IN-SAMPLE (2025-26)
# and OUT-OF-SAMPLE (2022-25). Overfit if tuned beats original in-sample but NOT out-of-sample.
# 4 backtests (2 are 3-year) -> takes a while. Uses CK_GOLD_PRO_FIX09 (params passed via inputs).
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_gold_pro_fix09_trades.csv"

Write-Host "[1] downloading + compiling CK_GOLD_PRO_FIX09..."
Invoke-WebRequest "$base/CK_GOLD_PRO_FIX09.mq5" -OutFile (Join-Path $exp "CK_GOLD_PRO_FIX09.mq5")
$mq=Join-Path $exp "CK_GOLD_PRO_FIX09.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

function RunBT($from,$to,$ema,$age,$be,$saveAs){
   $ini=Join-Path $research "ofc.ini"
   $cfg="[Tester]`nExpert=CK_GOLD_PRO_FIX09.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=$from`nToDate=$to`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpFixedLot=0.09`nInpMaxLot=0.09`nInpRiskPercent=2.0`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpMaxSpreadPrice=0.60`nInpEntryEMA=$ema`nInpBreakoutMaxAge=$age`nInpBEProgress=$be`n"
   Set-Content -Encoding ascii $ini $cfg
   if(Test-Path $csv){Remove-Item $csv -Force}
   Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
   $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
   $p|Wait-Process -Timeout 1500 -ErrorAction SilentlyContinue
   if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3
   if(Test-Path $csv){ Copy-Item $csv $saveAs -Force }
}
function Metrics($f){ if(-not(Test-Path $f)){return $null}
   $rows=@(Get-Content $f | Where-Object { $_ -and ($_ -notmatch '^time,') })
   $n=$rows.Count; $net=0.0; $gw=0.0; $gl=0.0; $eq=5000.0; $peak=5000.0; $mdd=0.0
   foreach($r in $rows){ $p=[double]($r.Split(",")[1]); $net+=$p; if($p -gt 0){$gw+=$p}elseif($p -lt 0){$gl+=[Math]::Abs($p)}
      $eq+=$p; if($eq -gt $peak){$peak=$eq}; $dd=($peak-$eq)/$peak; if($dd -gt $mdd){$mdd=$dd} }
   $pf=if($gl -gt 0){$gw/$gl}else{0}
   return [pscustomobject]@{n=$n;net=$net;pf=$pf;mdd=100.0*$mdd} }

Write-Host "[2/5] ORIGINAL in-sample 2025-26 (20/12/0.50)..."; RunBT "2025.08.01" "2026.08.01" 20 12 0.50 (Join-Path $research "of_orig_is.csv")
Write-Host "[3/5] TUNED    in-sample 2025-26 (21/9/0.44)...";   RunBT "2025.08.01" "2026.08.01" 21 9  0.44 (Join-Path $research "of_tune_is.csv")
Write-Host "[4/5] ORIGINAL OOS 2022-25 (20/12/0.50)...";        RunBT "2022.08.01" "2025.08.01" 20 12 0.50 (Join-Path $research "of_orig_oos.csv")
Write-Host "[5/5] TUNED    OOS 2022-25 (21/9/0.44)...";          RunBT "2022.08.01" "2025.08.01" 21 9  0.44 (Join-Path $research "of_tune_oos.csv")

$ois=Metrics (Join-Path $research "of_orig_is.csv"); $tis=Metrics (Join-Path $research "of_tune_is.csv")
$oos=Metrics (Join-Path $research "of_orig_oos.csv"); $tos=Metrics (Join-Path $research "of_tune_oos.csv")
Write-Host "=====OVERFIT_START====="
Write-Host "                        trades      net      PF     maxDD"
if($ois){Write-Host ("ORIGINAL  in-sample : {0,5}  {1,8:N0}   {2:N2}   {3:N1}%%" -f $ois.n,$ois.net,$ois.pf,$ois.mdd)}
if($tis){Write-Host ("TUNED     in-sample : {0,5}  {1,8:N0}   {2:N2}   {3:N1}%%" -f $tis.n,$tis.net,$tis.pf,$tis.mdd)}
if($oos){Write-Host ("ORIGINAL  OOS 22-25 : {0,5}  {1,8:N0}   {2:N2}   {3:N1}%%" -f $oos.n,$oos.net,$oos.pf,$oos.mdd)}
if($tos){Write-Host ("TUNED     OOS 22-25 : {0,5}  {1,8:N0}   {2:N2}   {3:N1}%%" -f $tos.n,$tos.net,$tos.pf,$tos.mdd)}
Write-Host "-----"
Write-Host "OVERFIT if TUNED beats ORIGINAL in-sample but does NOT beat it OOS."
Write-Host "ROBUST  if TUNED also beats (or matches) ORIGINAL OOS."
Write-Host "=====OVERFIT_END====="
Write-Host "^ Copy this block back to me."

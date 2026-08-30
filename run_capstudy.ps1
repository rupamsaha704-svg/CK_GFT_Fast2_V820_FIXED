$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Phase-2 cap-saturation study. Runs ONE risk (default 1.7). Re-run with a different $RISK for the ladder.
$RISK="1.7"   # <-- change to 0.5 / 1.0 / 1.5 / 2.0 and re-run for the full ladder
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_v23_capstudy.csv"

Write-Host "[1/4] downloading + compiling CK_GFT_v23_capstudy..."
Invoke-WebRequest "$base/CK_GFT_v23_capstudy.mq5" -OutFile (Join-Path $exp "CK_GFT_v23_capstudy.mq5")
$mq=Join-Path $exp "CK_GFT_v23_capstudy.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

Write-Host "[2/4] clearing old CSV..."
if(Test-Path $csv){Remove-Item $csv -Force -ErrorAction SilentlyContinue}

Write-Host "[3/4] backtest at risk $RISK% (real ticks, MaxLot 0.09)..."
$ini=Join-Path $research "capstudy.ini"
$cfg="[Tester]`nExpert=CK_GFT_v23_capstudy.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRiskPercent=$RISK`nInpMaxLot=0.09`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpMaxSpreadPrice=0.60`n"
Set-Content -Encoding ascii $ini $cfg
Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
$p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
$p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3

Write-Host "[4/4] cap-saturation summary (from CSV):"
$rows=@(Get-Content $csv | Where-Object { $_ -and ($_ -notmatch '^entry_time,') })
$n=$rows.Count; $capN=0; $pC=0.0; $pU=0.0; $ardC=0.0; $ardU=0.0; $rmSum=0.0; $ardSum=0.0
foreach($r in $rows){ $c=$r.Split(","); $cap=[int]$c[4]; $rm=[double]$c[5]; $ard=[double]$c[6]; $pf=[double]$c[7]
  $rmSum+=$rm; $ardSum+=$ard
  if($cap -eq 1){ $capN++; $pC+=$pf; $ardC+=$ard } else { $pU+=$pf; $ardU+=$ard } }
Write-Host "=====CAPSTUDY_START====="
Write-Host ("risk               : {0}%%" -f $RISK)
Write-Host ("trades             : {0}" -f $n)
Write-Host ("capped @0.09       : {0}  ({1:N1}%% of trades)" -f $capN,($(if($n){100.0*$capN/$n}else{0})))
Write-Host ("net profit capped  : {0:N2}" -f $pC)
Write-Host ("net profit uncapped: {0:N2}" -f $pU)
Write-Host ("sum intended risk $ : {0:N2}" -f $rmSum)
Write-Host ("sum ACTUAL risk $   : {0:N2}   (gap = risk lost to the 0.09 cap)" -f $ardSum)
Write-Host ("risk realised ratio : {0:N1}%%   (actual/intended)" -f ($(if($rmSum){100.0*$ardSum/$rmSum}else{0})))
Write-Host "=====CAPSTUDY_END====="
Write-Host "^ Copy this block back to me. (full per-trade file: ck_v23_capstudy.csv)"

$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Pullback-offset entry, IS 2025-26. Primary offset = 4.0 (declared). Change $OFF to 5/6 = EXPLORATORY only.
$OFF="4.0"
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_offset_trades.csv"
$py=$null; foreach($c in @("C:\Python314\python.exe")){ if(Test-Path $c){$py=$c;break} }
if(-not $py){ $g=Get-Command py -ErrorAction SilentlyContinue; if($g){$py=$g.Source} }
if(-not $py){ $g=Get-Command python -ErrorAction SilentlyContinue; if($g){$py=$g.Source} }

Write-Host "[1/4] compiling CK_GOLD_PRO_OFFSET..."
Invoke-WebRequest "$base/CK_GOLD_PRO_OFFSET.mq5" -OutFile (Join-Path $exp "CK_GOLD_PRO_OFFSET.mq5")
$mq=Join-Path $exp "CK_GOLD_PRO_OFFSET.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "compile FAILED";exit}
if($py -and -not (Test-Path (Join-Path $research "metrics.py"))){ Invoke-WebRequest "$base/v1_lab/metrics.py" -OutFile (Join-Path $research "metrics.py") }

Write-Host "[2/4] backtest offset=$OFF, IS 2025-26 (fixed 0.09, all params pinned)..."
$ini=Join-Path $research "offset.ini"
$cfg="[Tester]`nExpert=CK_GOLD_PRO_OFFSET.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpMagic=20260716`nInpFixedLot=0.09`nInpMaxLot=0.09`nInpRiskPercent=2.0`nInpRR=3.0`nInpMaxTradesPerDay=3`nInpDailyLossStopR=2.0`nInpDailyProfitStopR=4.0`nInpMaxSpreadPrice=0.60`nInpTrendEMA=200`nInpBreakoutLookback=20`nInpBreakoutMaxAge=12`nInpEntryEMA=20`nInpSwingLookback=10`nInpMaxSL_ATR=2.5`nInpSLBufferATR=0.2`nInpBEProgress=0.5`nInpEntryOffset=$OFF`nInpPendingBars=3`n"
Set-Content -Encoding ascii $ini $cfg
if(Test-Path $csv){Remove-Item $csv -Force}
Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
$p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
$p|Wait-Process -Timeout 1200 -ErrorAction SilentlyContinue
if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 2

Write-Host "[3/4] summary..."
Write-Host "=====OFFSET_IS_START====="
Write-Host "offset=$OFF  (FIX09 baseline IS = 280 trades / +200% / PF1.47 / DD16.3%)"
if($py){ Push-Location $research; & $py "metrics.py" "$csv" 5000; Pop-Location }
else{ $rows=@(Get-Content $csv|Where-Object{$_ -and ($_ -notmatch '^time,')}); $n=$rows.Count; $net=0.0; foreach($r in $rows){$net+=[double]($r.Split(",")[1])}; Write-Host ("trades {0}  net {1:N2}  return {2:N1}%%" -f $n,$net,(100*$net/5000)) }
Write-Host "=====OFFSET_IS_END====="
Write-Host "^ Copy block. (offset=4 is the declared primary; 5/6 are exploratory-only. IS is NOT evidence - OOS+consistency next.)"

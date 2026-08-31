$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# OFFSET=2.0 mandatory OOS test (ledger seq20/21). Backtest IS(2025-26)+OOS(2022-25), run deterministic
# pipeline LOCALLY (your Python). Prints only verdict block. ALL params pinned (guard #20).
$OFF="2.0"
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$SPEC_HASH="5ea604749e7cd82d6fa71003eccf62d0ff7095bf7ad72472a86b3e9a25b47df4"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_offset_trades.csv"

$py=$null
foreach($c in @("$env:LOCALAPPDATA\Programs\Python\Python314\python.exe","C:\Python314\python.exe","C:\Python313\python.exe","C:\Python312\python.exe")){ if(Test-Path $c){$py=$c;break} }
if(-not $py){ $g=Get-Command py -ErrorAction SilentlyContinue; if($g){$py=$g.Source} }
if(-not $py){ $g=Get-Command python -ErrorAction SilentlyContinue; if($g){$py=$g.Source} }
if(-not $py){ Write-Host "Python not found"; exit }
Write-Host "python: $py"

Write-Host "[1/5] compiling CK_GOLD_PRO_OFFSET..."
Invoke-WebRequest "$base/CK_GOLD_PRO_OFFSET.mq5" -OutFile (Join-Path $exp "CK_GOLD_PRO_OFFSET.mq5")
$mq=Join-Path $exp "CK_GOLD_PRO_OFFSET.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "compile FAILED";exit}

function RunBT($from,$to,$saveAs){
   $ini=Join-Path $research "offoos.ini"
   $cfg="[Tester]`nExpert=CK_GOLD_PRO_OFFSET.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=$from`nToDate=$to`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpMagic=20260716`nInpFixedLot=0.09`nInpMaxLot=0.09`nInpRiskPercent=2.0`nInpRR=3.0`nInpMaxTradesPerDay=3`nInpDailyLossStopR=2.0`nInpDailyProfitStopR=4.0`nInpMaxSpreadPrice=0.60`nInpTrendEMA=200`nInpBreakoutLookback=20`nInpBreakoutMaxAge=12`nInpEntryEMA=20`nInpSwingLookback=10`nInpMaxSL_ATR=2.5`nInpSLBufferATR=0.2`nInpBEProgress=0.5`nInpEntryOffset=$OFF`nInpPendingBars=3`n"
   Set-Content -Encoding ascii $ini $cfg
   if(Test-Path $csv){Remove-Item $csv -Force}
   Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
   $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
   $p|Wait-Process -Timeout 1500 -ErrorAction SilentlyContinue
   if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 2
   if(Test-Path $csv){ Copy-Item $csv $saveAs -Force }
}
Write-Host "[2/5] backtest IS 2025-26 (offset=$OFF)..."; RunBT "2025.08.01" "2026.08.01" (Join-Path $research "off_is.csv")
Write-Host "[3/5] backtest OOS 2022-25 (offset=$OFF, 3yr real-tick, slower)..."; RunBT "2022.08.01" "2025.08.01" (Join-Path $research "off_oos.csv")

Write-Host "[4/5] downloading pipeline modules..."
foreach($m in @("metrics.py","cost_stress.py","benchmark.py","pipeline.py")){ Invoke-WebRequest "$base/v1_lab/$m" -OutFile (Join-Path $research $m) }

Write-Host "[5/5] running deterministic pipeline locally..."
Write-Host ""
Write-Host "=====OFFSET2_OOS_VERDICT_START====="
Write-Host "offset=$OFF  (FIX09 dev-verdict was FAIL: OOS PF1.13/exp3.26)"
Push-Location $research
& $py "pipeline.py" --is "off_is.csv" --oos "off_oos.csv" --spec-hash $SPEC_HASH --cost-per-trade 2.5
Pop-Location
Write-Host "=====OFFSET2_OOS_VERDICT_END====="
Write-Host "^ Copy this whole verdict block back to me. This is the REAL test - IS was only exploratory."

$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Consistency check: same pre-registered regime gate on 2025-26 (IS), OFF vs ON, fixed 0.09, all params pinned.
# Resolves the contradiction (gate helped OOS 2022-25 but reportedly hurt 2025-26). Consistent => FIX10 candidate.
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_fix10_regime_trades.csv"
$py=$null; foreach($c in @("C:\Python314\python.exe")){ if(Test-Path $c){$py=$c;break} }
if(-not $py){ $g=Get-Command py -ErrorAction SilentlyContinue; if($g){$py=$g.Source} }
if(-not $py){ $g=Get-Command python -ErrorAction SilentlyContinue; if($g){$py=$g.Source} }
if(-not $py){ Write-Host "Python not found"; exit }

Write-Host "[1/4] compiling..."
Invoke-WebRequest "$base/CK_GOLD_PRO_FIX10_regime.mq5" -OutFile (Join-Path $exp "CK_GOLD_PRO_FIX10_regime.mq5")
$mq=Join-Path $exp "CK_GOLD_PRO_FIX10_regime.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "compile FAILED";exit}
if(-not (Test-Path (Join-Path $research "metrics.py"))){ Invoke-WebRequest "$base/v1_lab/metrics.py" -OutFile (Join-Path $research "metrics.py") }

function RunBT($useReg,$saveAs){
   $ini=Join-Path $research "f10is.ini"
   $cfg="[Tester]`nExpert=CK_GOLD_PRO_FIX10_regime.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpMagic=20260716`nInpFixedLot=0.09`nInpMaxLot=0.09`nInpRiskPercent=2.0`nInpRR=3.0`nInpMaxTradesPerDay=3`nInpDailyLossStopR=2.0`nInpDailyProfitStopR=4.0`nInpMaxSpreadPrice=0.60`nInpTrendEMA=200`nInpBreakoutLookback=20`nInpBreakoutMaxAge=12`nInpEntryEMA=20`nInpSwingLookback=10`nInpMaxSL_ATR=2.5`nInpSLBufferATR=0.2`nInpBEProgress=0.5`nInpUseRegime=$useReg`nInpRegimeLookback=20`nInpRegimeMinSlopeATR=0.5`n"
   Set-Content -Encoding ascii $ini $cfg
   if(Test-Path $csv){Remove-Item $csv -Force}
   Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
   $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
   $p|Wait-Process -Timeout 1200 -ErrorAction SilentlyContinue
   if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 2
   if(Test-Path $csv){ Copy-Item $csv $saveAs -Force }
}
Write-Host "[2/4] IS 2025-26 regime OFF..."; RunBT "false" (Join-Path $research "is_reg_off.csv")
Write-Host "[3/4] IS 2025-26 regime ON..."; RunBT "true" (Join-Path $research "is_reg_on.csv")
Write-Host "[4/4] metrics..."
Push-Location $research
Write-Host ""
Write-Host "=====FIX10_REGIME_IS_START====="
Write-Host "--- IS 2025-26 regime OFF (=FIX09) ---"; & $py "metrics.py" "is_reg_off.csv" 5000
Write-Host "--- IS 2025-26 regime ON ---"; & $py "metrics.py" "is_reg_on.csv" 5000
Pop-Location
Write-Host "=====FIX10_REGIME_IS_END====="
Write-Host "^ Copy this block. Consistent (ON not much worse / better on BOTH periods) => FIX10 candidate; big flip => period-dependent, not robust."

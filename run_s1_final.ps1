$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$research="C:\Users\prita\CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$val=Join-Path $research "validation"; if(-not(Test-Path $val)){New-Item -ItemType Directory -Force $val|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"

Write-Host "===== FINALIZING STRATEGY #1 (v23 trend, RR3, NO partial book) ====="
Write-Host "  goal: bring REALIZED MaxDD <= 9% via risk sizing, keep profit + robustness"
Write-Host ""
Write-Host "[1/5] downloading v23 EA + analyzer..."
Invoke-WebRequest "$base/CK_GFT_Fast_v23_ROBUST.mq5" -OutFile (Join-Path $exp "CK_GFT_Fast_v23_ROBUST.mq5")
foreach($f in "cpcv.py","pbo.py","analyze_trades.py"){ Invoke-WebRequest "$base/validation/$f" -OutFile (Join-Path $val $f) }

Write-Host "[2/5] compiling..."
$mq=Join-Path $exp "CK_GFT_Fast_v23_ROBUST.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

Write-Host "[3/5] clearing old CSV..."
$csv=Join-Path $common "ck_v23_trades.csv"; if(Test-Path $csv){Remove-Item $csv -Force -ErrorAction SilentlyContinue}

Write-Host "[4/5] FULL 12-month backtest - REAL TICKS, MaxLot 0.09, RISK 0.30% (several min)..."
$ini=Join-Path $research "s1_final.ini"
$cfg="[Tester]`nExpert=CK_GFT_Fast_v23_ROBUST.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpRiskPercent=0.30`nInpMaxLot=0.09`n"
Set-Content -Encoding ascii $ini $cfg
Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
$p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
$p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3

Write-Host "[5/5] robustness analysis (DD / Monte Carlo / CPCV)..."
$py="python"; & $py -c "import numpy" 2>$null; if($LASTEXITCODE -ne 0){ & $py -m pip install --user numpy|Out-Null }
$env:CK_RESEARCH=$research; $env:CK_MC="10000"; $env:CK_DD_LIMIT="9"
Write-Host "############ STRATEGY #1 FINAL (risk 0.30%) ############"
Write-Host "  (at risk 0.50% it was: Net +6712  PF 1.46  Win 25.8%  MaxDD 13.1%)"
Write-Host "  PASS if REALIZED MaxDD <= 9% AND still net positive AND OOS Sharpe > 0"
& $py (Join-Path $val "analyze_trades.py")
Write-Host ""
Write-Host "If MaxDD <= 9% here -> STRATEGY #1 IS DONE. Then (and only then) we start #2."
Write-Host "If MaxDD still > 9% -> we lower risk one more notch (0.25%) and re-run. No curve-fit."

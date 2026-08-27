$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$research="C:\Users\prita\CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_v23live_trades.csv"

Write-Host "[1/5] downloading + compiling CK_GFT_v23_live..."
Invoke-WebRequest "$base/CK_GFT_v23_live.mq5" -OutFile (Join-Path $exp "CK_GFT_v23_live.mq5")
$mq=Join-Path $exp "CK_GFT_v23_live.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

Write-Host "[2/5] clearing old CSV..."
if(Test-Path $csv){Remove-Item $csv -Force -ErrorAction SilentlyContinue}

Write-Host "[3/5] A/B regression backtest - SAME settings as v23_ts baseline (REAL TICKS, M15, risk 0.5%, MaxLot 0.09)..."
$ini=Join-Path $research "v23live.ini"
$cfg="[Tester]`nExpert=CK_GFT_v23_live.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpRiskPercent=0.5`nInpMaxLot=0.09`nInpMaxSpreadPrice=0.60`n"
Set-Content -Encoding ascii $ini $cfg
Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
$p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
$p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3

Write-Host "[4/5] safety-trigger counters (from tester log - traces any A/B divergence to the exact fix):"
$logDir=Join-Path $dataDir "Tester\logs"; $line=$null
if(Test-Path $logDir){ $lg=Get-ChildItem $logDir -Filter *.log -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 3
  foreach($f in $lg){ $m=Select-String -Path $f.FullName -Pattern "v23live" -ErrorAction SilentlyContinue; if($m){$line=$m; break} } }
Write-Host "=====V23LIVE_SAFETY_START====="
if($line){ $line|ForEach-Object{ Write-Host $_.Line.Trim() } } else { Write-Host "(no [v23live] log line found - check MT5 Journal for: safety triggers)" }
Write-Host "=====V23LIVE_SAFETY_END====="

Write-Host ""
Write-Host "[5/5] v23_live trades (time,profit) - COPY EVERYTHING BETWEEN THE MARKERS:"
Write-Host "=====V23LIVE_CSV_START====="
if(Test-Path $csv){ Get-Content $csv } else { Write-Host "NO CSV - failed." }
Write-Host "=====V23LIVE_CSV_END====="
Write-Host ""
Write-Host "^ Copy BOTH blocks (SAFETY + CSV) back to me for the A/B regression vs v23_ts."

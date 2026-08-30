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

Write-Host "[setup] downloading EAs + analyzer..."
foreach($f in "CK_GFT_Fast_v23_ROBUST.mq5","CK_GFT_Fast_v24_ROBUST.mq5"){ Invoke-WebRequest "$base/$f" -OutFile (Join-Path $exp $f) }
foreach($f in "cpcv.py","pbo.py","analyze_trades.py"){ Invoke-WebRequest "$base/validation/$f" -OutFile (Join-Path $val $f) }

function Compile($mq){ $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}; Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){return $true}}; return $false }
function RunBT($ea,$csvName){
  $c=Join-Path $common $csvName; if(Test-Path $c){Remove-Item $c -Force -ErrorAction SilentlyContinue}
  $ini=Join-Path $research "cmp.ini"
  $cfg="[Tester]`nExpert=$ea`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpRiskPercent=0.5`nInpMaxLot=0.09`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  $p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
  if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}
  Start-Sleep 3
}
$py="python"; & $py -c "import numpy" 2>$null; if($LASTEXITCODE -ne 0){ & $py -m pip install --user numpy|Out-Null }
$env:CK_RESEARCH=$research; $env:CK_MC="10000"; $env:CK_DD_LIMIT="9"

Write-Host "[1] compiling v23 + v24..."; if(-not (Compile (Join-Path $exp "CK_GFT_Fast_v23_ROBUST.mq5"))){Write-Host "v23 compile fail";exit}; if(-not (Compile (Join-Path $exp "CK_GFT_Fast_v24_ROBUST.mq5"))){Write-Host "v24 compile fail";exit}
Write-Host "[2] backtesting v23 (real ticks, 12mo)... (several min)"; RunBT "CK_GFT_Fast_v23_ROBUST.ex5" "ck_v23_trades.csv"
Write-Host "[3] backtesting v24 (real ticks, 12mo)... (several min)"; RunBT "CK_GFT_Fast_v24_ROBUST.ex5" "ck_v24_trades.csv"
Write-Host ""; Write-Host "################## v23 (no partial book) ##################"
& $py (Join-Path $val "analyze_trades.py") (Join-Path $common "ck_v23_trades.csv")
Write-Host ""; Write-Host "################## v24 (WITH partial book) ##################"
& $py (Join-Path $val "analyze_trades.py") (Join-Path $common "ck_v24_trades.csv")
Write-Host ""; Write-Host "Compare the two: higher net + lower DD + positive OOS Sharpe wins."

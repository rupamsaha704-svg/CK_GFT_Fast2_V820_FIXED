$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# FROZEN demo/forward-test install of CK_GOLD_PRO_FIX09 v1.03. Compile only; attach manually on a DEMO account.
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $me){Write-Host "MetaEditor not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"
Write-Host "[1/2] downloading FROZEN CK_GOLD_PRO_FIX09.mq5 (v1.03)..."
Invoke-WebRequest "$base/CK_GOLD_PRO_FIX09.mq5" -OutFile (Join-Path $exp "CK_GOLD_PRO_FIX09.mq5")
$mq=Join-Path $exp "CK_GOLD_PRO_FIX09.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Write-Host "[2/2] compiling..."
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}
Write-Host "  compiled OK -> 'CK_GOLD_PRO_FIX09' in Navigator > Expert Advisors"
Write-Host ""
Write-Host "=====FROZEN DEMO SETUP====="
Write-Host "1. Log into a DEMO account (File > Open an Account > demo)."
Write-Host "2. Open XAUUSD chart, timeframe M15."
Write-Host "3. Drag 'CK_GOLD_PRO_FIX09' onto the chart."
Write-Host "4. Inputs (FROZEN - set once, NEVER change during the test):"
Write-Host "     InpFixedLot=0.09  InpMaxLot=0.09  InpRiskPercent=2.0"
Write-Host "     InpRR=3.0  InpMaxSL_ATR=2.5  InpMaxSpreadPrice=0.60"
Write-Host "     InpEntryEMA=20  InpBreakoutMaxAge=12  InpBEProgress=0.50   (ORIGINAL, non-overfit)"
Write-Host "5. Allow Algo Trading -> OK. Turn ON global AutoTrading."
Write-Host "6. Leave it. Weekly: Account History > Report; send me the statement + Journal."
Write-Host ""
Write-Host "RULES: do NOT change any input/logic while it runs (that turns forward-test into optimization"
Write-Host "data). If analysis later proves a real improvement, it becomes a NEW version FIX10 with its OWN"
Write-Host "fresh independent forward test. Demo = locked evidence."
Write-Host "=====END====="

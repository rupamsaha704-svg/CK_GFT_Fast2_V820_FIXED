$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# DEMO forward-test install: download + compile the FROZEN v23_live into MT5 Navigator. No backtest, no tuning.
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $me){Write-Host "MetaEditor not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"

Write-Host "[1/2] downloading FROZEN CK_GFT_v23_live.mq5 (audited build)..."
Invoke-WebRequest "$base/CK_GFT_v23_live.mq5" -OutFile (Join-Path $exp "CK_GFT_v23_live.mq5")
$mq=Join-Path $exp "CK_GFT_v23_live.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Write-Host "[2/2] compiling..."
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}
Write-Host "  compiled OK -> CK_GFT_v23_live.ex5 is now in Navigator > Expert Advisors"
Write-Host ""
Write-Host "=====NEXT STEPS (do manually on a DEMO account)====="
Write-Host "1. In MT5, log into a DEMO account (File > Open an Account > demo)."
Write-Host "2. Open an XAUUSD chart, set timeframe M15."
Write-Host "3. Drag 'CK_GFT_v23_live' from Navigator onto the XAUUSD M15 chart."
Write-Host "4. In the inputs dialog set (FROZEN - do not change afterwards):"
Write-Host "     InpRiskPercent = 0.5   (conservative)  OR  1.7  (target)"
Write-Host "     InpMaxLot      = 0.09"
Write-Host "     InpRR          = 3.0"
Write-Host "     InpMaxSL_ATR   = 2.5"
Write-Host "     InpMaxSpreadPrice = 0.60"
Write-Host "5. Enable 'Allow Algo Trading' on the dialog, click OK."
Write-Host "6. Turn ON the global AutoTrading button (top toolbar)."
Write-Host "7. Leave it running. Weekly: Account History > right-click > Report; send me the"
Write-Host "   statement + the Journal lines containing [v23live]."
Write-Host "DO NOT optimise, change inputs, or intervene in trades - that contaminates the OOS test."
Write-Host "=====END====="

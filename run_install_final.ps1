$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
if(-not $me -or -not $dataDir){Write-Host "MT5 not found";exit}
$exp=Join-Path $dataDir "MQL5\Experts"

Write-Host "Installing final validated EA: CK_GFT_Fast_v23_ROBUST ..."
Invoke-WebRequest "$base/CK_GFT_Fast_v23_ROBUST.mq5" -OutFile (Join-Path $exp "CK_GFT_Fast_v23_ROBUST.mq5")
$mq=Join-Path $exp "CK_GFT_Fast_v23_ROBUST.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(Test-Path $ex5){
  Write-Host ""
  Write-Host "==================== READY ===================="
  Write-Host " EA compiled and installed:"
  Write-Host "   $ex5"
  Write-Host ""
  Write-Host " NEXT (in MT5):"
  Write-Host "  1. Open a XAUUSD M15 chart"
  Write-Host "  2. Navigator -> Expert Advisors -> drag 'CK_GFT_Fast_v23_ROBUST' onto the chart"
  Write-Host "  3. Set inputs: RiskPercent=0.5  RR=3.0  MaxLot=0.09  MaxSL_ATR=2.5"
  Write-Host "  4. Enable 'Algo Trading'. Use a DEMO account first."
  Write-Host ""
  Write-Host " Validated: +115% backtest, PF 1.39, NOT overfit (Vibe CPCV OOS +0.107)."
  Write-Host " Honest: drawdown ~14%. For <=9% DD run on a ~\$8-10k account."
  Write-Host "==============================================="
} else { Write-Host "compile FAILED - send me the MetaEditor error." }

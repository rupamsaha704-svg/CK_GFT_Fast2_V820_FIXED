$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
# Just print both CSVs verbatim between markers. No parsing, no diff (done off-machine to avoid PS array quirks).
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$common=Join-Path $dataDir "..\Common\Files"
$csvB=Join-Path $common "ck_v23ts_trades.csv"; $csvL=Join-Path $common "ck_v23live_trades.csv"
Write-Host "=====BASELINE_TS_START====="
if(Test-Path $csvB){ Get-Content $csvB } else { Write-Host "MISSING" }
Write-Host "=====BASELINE_TS_END====="
Write-Host "=====LIVE_START====="
if(Test-Path $csvL){ Get-Content $csvL } else { Write-Host "MISSING" }
Write-Host "=====LIVE_END====="
Write-Host "^ Copy EVERYTHING from =====BASELINE_TS_START===== down to =====LIVE_END===== back to me."

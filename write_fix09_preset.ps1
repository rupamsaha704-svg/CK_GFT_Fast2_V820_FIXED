$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
# Writes a frozen .set preset for CK_GOLD_PRO_FIX09 into MQL5\Presets so you can click "Load" in the
# EA inputs dialog instead of typing. (Attaching to a live chart is still a GUI drag - MT5 has no CLI for it.)
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$presets=Join-Path $dataDir "MQL5\Presets"; if(-not(Test-Path $presets)){New-Item -ItemType Directory -Force $presets|Out-Null}
$set=@"
InpMagic=20260716
InpFixedLot=0.09
InpMaxLot=0.09
InpRiskPercent=2.0
InpRR=3.0
InpMaxTradesPerDay=3
InpDailyLossStopR=2.0
InpDailyProfitStopR=4.0
InpMaxSpreadPrice=0.6
InpTrendEMA=200
InpBreakoutLookback=20
InpBreakoutMaxAge=12
InpEntryEMA=20
InpSwingLookback=10
InpMaxSL_ATR=2.5
InpSLBufferATR=0.2
InpBEProgress=0.5
"@
$path=Join-Path $presets "CK_GOLD_PRO_FIX09.set"
Set-Content -Encoding ascii $path $set
Write-Host "preset written -> $path"
Write-Host ""
Write-Host "NOW in MT5:"
Write-Host "1. Drag CK_GOLD_PRO_FIX09 onto an XAUUSD M15 chart (demo account)."
Write-Host "2. In the Inputs tab click 'Load' -> pick CK_GOLD_PRO_FIX09.set  (values fill in)."
Write-Host "3. Tick 'Allow Algo Trading' -> OK. Turn ON the global AutoTrading button."
Write-Host "NOTE: InpHTF stays H1 and InpUseBreakEven stays true by default (already correct)."

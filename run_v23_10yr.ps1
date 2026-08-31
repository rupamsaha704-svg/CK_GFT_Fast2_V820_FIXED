$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$research="C:\Users\prita\CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_v23ts_trades.csv"

Write-Host "[1/4] downloading + compiling v23 (timestamp dump)..."
Invoke-WebRequest "$base/CK_GFT_v23_ts.mq5" -OutFile (Join-Path $exp "CK_GFT_v23_ts.mq5")
$mq=Join-Path $exp "CK_GFT_v23_ts.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

Write-Host "[2/4] clearing old CSV..."
if(Test-Path $csv){Remove-Item $csv -Force -ErrorAction SilentlyContinue}

Write-Host "[3/4] MULTI-YEAR backtest - REAL TICKS (Model 4), risk 1.7%, MaxLot 0.09 LOCKED..."
Write-Host "      (real ticks = accurate; broker may only have ~1-3 years of gold tick history -"
Write-Host "       MT5 will test whatever real-tick history exists. Can take a long time.)"
$ini=Join-Path $research "v23_10yr.ini"
$cfg="[Tester]`nExpert=CK_GFT_v23_ts.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2015.01.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpRiskPercent=1.7`nInpMaxLot=0.09`n"
Set-Content -Encoding ascii $ini $cfg
Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
$p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
$p|Wait-Process -Timeout 3000 -ErrorAction SilentlyContinue
if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3

Write-Host "[4/4] per-YEAR results (robustness across regimes):"
if(-not (Test-Path $csv)){ Write-Host "NO CSV - tester failed or no history."; exit }
$bal=5000.0;$peak=5000.0;$mdd=0.0;$netAll=0.0
$yr=@{}; $yc=@{}
Get-Content $csv | Select-Object -Skip 1 | ForEach-Object {
  $a=$_ -split ","; if($a.Count -ge 2){
    $t=$a[0]; $pr=[double]$a[1]; $y=$t.Substring(0,4)
    $bal+=$pr; $netAll+=$pr; if($bal -gt $peak){$peak=$bal}; $dd=($peak-$bal)/$peak*100; if($dd -gt $mdd){$mdd=$dd}
    if(-not $yr.ContainsKey($y)){$yr[$y]=0.0;$yc[$y]=0}
    $yr[$y]+=$pr; $yc[$y]++
  }
}
Write-Host "=====V23_10YR_START====="
Write-Host ("{0,-6}{1,8}{2,12}" -f "year","trades","net$")
foreach($y in ($yr.Keys | Sort-Object)){ Write-Host ("{0,-6}{1,8}{2,12:N0}" -f $y,$yc[$y],$yr[$y]) }
Write-Host ("-"*26)
Write-Host ("TOTAL net = {0:N0}   return = {1:N0}%   overall maxDD = {2:N1}%" -f $netAll,($netAll/5000*100),$mdd)
Write-Host "=====V23_10YR_END====="
Write-Host ""
Write-Host "COPY the block above. Profitable in MOST years = robust across regimes = strong."

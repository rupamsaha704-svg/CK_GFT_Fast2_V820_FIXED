$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$research="C:\Users\prita\CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_v23_trades.csv"

Write-Host "downloading + compiling v23..."
Invoke-WebRequest "$base/CK_GFT_Fast_v23_ROBUST.mq5" -OutFile (Join-Path $exp "CK_GFT_Fast_v23_ROBUST.mq5")
$mq=Join-Path $exp "CK_GFT_Fast_v23_ROBUST.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "compile FAILED";exit}; Write-Host "compiled OK"
Write-Host ""
Write-Host "RISK LADDER (v23, XAUUSD M15, real ticks, MaxLot 0.09 HARD CAP, deposit 5000)"
Write-Host "=========================================================================="
Write-Host ("{0,-8}{1,12}{2,12}{3,10}" -f "risk%","net$","return%","maxDD%")

foreach($risk in @("0.5","1.0","2.0")){
  if(Test-Path $csv){Remove-Item $csv -Force -ErrorAction SilentlyContinue}
  $ini=Join-Path $research "ladder.ini"
  $cfg="[Tester]`nExpert=CK_GFT_Fast_v23_ROBUST.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpRiskPercent=$risk`nInpMaxLot=0.09`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  $p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
  if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 2
  if(Test-Path $csv){
    $bal=5000.0; $peak=5000.0; $mdd=0.0; $net=0.0
    Get-Content $csv | Select-Object -Skip 1 | ForEach-Object {
      $parts=$_ -split ","; if($parts.Count -ge 2){ $pr=[double]$parts[1]; $bal+=$pr; $net+=$pr; if($bal -gt $peak){$peak=$bal}; $dd=($peak-$bal)/$peak*100; if($dd -gt $mdd){$mdd=$dd} }
    }
    $ret=$net/5000.0*100
    Write-Host ("{0,-8}{1,12:N0}{2,11:N0}%{3,9:N1}%" -f $risk,$net,$ret,$mdd)
  } else { Write-Host ("{0,-8}  no trades / failed" -f $risk) }
}
Write-Host "=========================================================================="
Write-Host "COPY this whole table and paste it back to me. Higher return ALWAYS comes with higher drawdown."

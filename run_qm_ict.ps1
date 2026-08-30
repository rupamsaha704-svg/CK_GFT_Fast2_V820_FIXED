$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Compile + backtest CK_QM_ICT_EA (XAUUSD M15, real ticks, fixed 0.09 lot, EMA-bias ON).
# This is a SANITY / faithfulness backtest: compare its trade count/behaviour vs the Python engine.
# All strategy inputs pinned (guard #20: MT5 tester caches last-GUI inputs otherwise).
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_qm_ict_trades.csv"
$py=$null; foreach($c in @("C:\Python314\python.exe")){ if(Test-Path $c){$py=$c;break} }
if(-not $py){ $g=Get-Command py -ErrorAction SilentlyContinue; if($g){$py=$g.Source} }
if(-not $py){ $g=Get-Command python -ErrorAction SilentlyContinue; if($g){$py=$g.Source} }

Write-Host "[1/4] downloading + compiling CK_QM_ICT_EA..."
Invoke-WebRequest "$base/CK_QM_ICT_EA.mq5" -OutFile (Join-Path $exp "CK_QM_ICT_EA.mq5")
$mq=Join-Path $exp "CK_QM_ICT_EA.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED - open CK_QM_ICT_EA.mq5 in MetaEditor (F7) to see errors";exit}; Write-Host "  compiled OK"
if($py -and -not (Test-Path (Join-Path $research "metrics.py"))){ Invoke-WebRequest "$base/v1_lab/metrics.py" -OutFile (Join-Path $research "metrics.py") }

function RunBT($from,$to,$saveAs){
  $ini=Join-Path $research "qmict.ini"
  $cfg="[Tester]`nExpert=CK_QM_ICT_EA.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=$from`nToDate=$to`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpMagic=20260730`nInpFixedLot=0.09`nInpMaxLot=0.09`nInpPivot=2`nInpDispATR=0.6`nInpAtrPeriod=14`nInpUseEmaBias=true`nInpEmaPeriod=200`nInpSLBufferATR=0.5`nInpMinRR=1.0`nInpErlLookback=5`nInpMaxTradesPerDay=2`nInpLookbackBars=500`nInpSetupExpiryBars=40`nInpUseSession=false`nInpSessStartHour=13`nInpSessEndHour=22`nInpMaxSpreadPrice=0.60`n"
  Set-Content -Encoding ascii $ini $cfg
  if(Test-Path $csv){Remove-Item $csv -Force}
  Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  $p|Wait-Process -Timeout 1500 -ErrorAction SilentlyContinue
  if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 2
  if(Test-Path $csv){ Copy-Item $csv $saveAs -Force }
}
function Report($saveAs){
  if(Test-Path $saveAs){
    if($py){ Push-Location $research; & $py "metrics.py" "$saveAs" 5000; Pop-Location }
    else { $rows=@(Get-Content $saveAs|Where-Object{$_ -and ($_ -notmatch '^time,')}); $n=$rows.Count; $net=0.0; foreach($r in $rows){$net+=[double]($r.Split(",")[1])}; Write-Host ("trades {0}  net {1:N2}" -f $n,$net) }
  } else { Write-Host "NO CSV - 0 trades in this window." }
}

# PRIMARY = current regime (last ~11 months, since the market shifted ~Oct 2025). 4yr = context only.
Write-Host "[2/4] backtest CURRENT REGIME 2025.10.01..2026.08.29 (PRIMARY value judge)..."
RunBT "2025.10.01" "2026.08.29" (Join-Path $research "qm_regime.csv")
Write-Host "[3/4] backtest 4-YEAR 2022.06.01..2026.08.29 (CONTEXT only, not the value judge)..."
RunBT "2022.06.01" "2026.08.29" (Join-Path $research "qm_4yr.csv")

Write-Host ""
Write-Host "=====QM_ICT_CURRENT_REGIME_START=====  (last ~11 months = PRIMARY; this is what decides VALUE)"
Report (Join-Path $research "qm_regime.csv")
Write-Host "=====QM_ICT_CURRENT_REGIME_END====="
Write-Host ""
Write-Host "=====QM_ICT_4YR_CONTEXT_START=====  (4 years = context ONLY; older regime, not the judge)"
Report (Join-Path $research "qm_4yr.csv")
Write-Host "=====QM_ICT_4YR_CONTEXT_END====="
Write-Host ""
Write-Host "[4/4] RULE (your regime principle, now in code): VALUE is judged by the CURRENT-REGIME (11-month) block."
Write-Host "The market algorithm of the last ~11 months differs from older years and holds to ~2030; 4yr is context."
Write-Host "^ Copy BOTH blocks back to me."

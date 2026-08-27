$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# ALL-IN-ONE: compile CK_GOLD_PRO_FIX09 + backtest (fixed 0.09) + summary + auto Journal check. One paste.
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_gold_pro_fix09_trades.csv"

Write-Host "[1/5] downloading + compiling CK_GOLD_PRO_FIX09..."
Invoke-WebRequest "$base/CK_GOLD_PRO_FIX09.mq5" -OutFile (Join-Path $exp "CK_GOLD_PRO_FIX09.mq5")
$mq=Join-Path $exp "CK_GOLD_PRO_FIX09.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

Write-Host "[2/5] clearing old CSV..."; if(Test-Path $csv){Remove-Item $csv -Force}
Write-Host "[3/5] backtest FIXED 0.09, real ticks, 2025.08-2026.08 (a few minutes)..."
$ini=Join-Path $research "fix09.ini"
$cfg="[Tester]`nExpert=CK_GOLD_PRO_FIX09.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpFixedLot=0.09`nInpMaxLot=0.09`nInpRiskPercent=2.0`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpMaxSpreadPrice=0.60`n"
Set-Content -Encoding ascii $ini $cfg
Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
$p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
$p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3

Write-Host "[4/5] computing summary..."
$dep=5000.0; $rows=@(Get-Content $csv -ErrorAction SilentlyContinue | Where-Object { $_ -and ($_ -notmatch '^time,') })
$n=$rows.Count; $net=0.0; $gw=0.0; $gl=0.0; $wins=0; $eq=$dep; $peak=$dep; $mdd=0.0
foreach($r in $rows){ $p2=[double]($r.Split(",")[1]); $net+=$p2; if($p2 -gt 0){$gw+=$p2;$wins++}elseif($p2 -lt 0){$gl+=[Math]::Abs($p2)}
  $eq+=$p2; if($eq -gt $peak){$peak=$eq}; $dd=($peak-$eq)/$peak; if($dd -gt $mdd){$mdd=$dd} }
$pf=if($gl -gt 0){$gw/$gl}else{0}; $ret=($net/$dep)*100; $wr=if($n){($wins/$n)*100}else{0}

Write-Host "[5/5] reading Journal (EA prints + any error/reject)..."
$dirs=@((Join-Path $dataDir "Tester\logs"), (Join-Path $dataDir "MQL5\Logs"), (Join-Path $dataDir "logs"))
$logs=@(); foreach($d in $dirs){ if(Test-Path $d){ $logs += Get-ChildItem $d -Filter *.log -ErrorAction SilentlyContinue } }
$logs=$logs | Sort-Object LastWriteTime -Descending | Select-Object -First 4
$pat="CK_GOLD_PRO|ORDER_FAIL|fail|error|reject|invalid|no money|not enough|market closed|requote"
$hits=@(); foreach($f in $logs){ $m=Select-String -Path $f.FullName -Pattern $pat -ErrorAction SilentlyContinue; foreach($ln in $m){ $hits += $ln.Line.Trim() } }

Write-Host ""
Write-Host "=====FIX09_ALL_START====="
Write-Host ("Config       : CK_GOLD_PRO_FIX09  FIXED lot 0.09  real ticks")
Write-Host ("Trades       : {0}" -f $n)
Write-Host ("Net profit   : {0:N2}  on {1:N0}" -f $net,$dep)
Write-Host ("Return       : {0:N1}%%   (expected ~ +200%%)" -f $ret)
Write-Host ("Profit factor: {0:N2}" -f $pf)
Write-Host ("Win rate     : {0:N1}%%" -f $wr)
Write-Host ("Closed-trade max DD: {0:N1}%%" -f ($mdd*100))
Write-Host "----- JOURNAL (errors/rejects/EA prints) -----"
if($hits.Count -eq 0){ Write-Host "CLEAN: no errors/rejects found in recent tester logs." }
else{ $hits | Select-Object -Last 25 | ForEach-Object { Write-Host $_ } }
Write-Host "=====FIX09_ALL_END====="
Write-Host "^ Copy this ONE block back to me - it has everything."

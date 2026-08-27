$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# NOTE: this script stops ALL running MT5 terminals to free the tester, and assumes a SINGLE MT5 install.
#       If you run multiple brokers' MT5, close others first / verify the right terminal is used.
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"; $csv=Join-Path $common "ck_v23live_trades.csv"

Write-Host "[1/5] downloading + compiling CK_GFT_v23_live + baseline..."
Invoke-WebRequest "$base/CK_GFT_v23_live.mq5" -OutFile (Join-Path $exp "CK_GFT_v23_live.mq5")
$baseCsv=Join-Path $research "baseline_v23ts_trades.csv"
Invoke-WebRequest "$base/baseline_v23ts_trades.csv" -OutFile $baseCsv
$mq=Join-Path $exp "CK_GFT_v23_live.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

Write-Host "[2/5] clearing old CSV..."
if(Test-Path $csv){Remove-Item $csv -Force -ErrorAction SilentlyContinue}

Write-Host "[3/5] A/B regression backtest - SAME settings as v23_ts baseline (REAL TICKS, M15, risk 0.5%, MaxLot 0.09)..."
$ini=Join-Path $research "v23live.ini"
$cfg="[Tester]`nExpert=CK_GFT_v23_live.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpRiskPercent=0.5`nInpMaxLot=0.09`nInpMaxSpreadPrice=0.60`n"
Set-Content -Encoding ascii $ini $cfg
Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
$p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
$p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3

Write-Host "[4/5] reading [v23live] log lines (spread diagnostic + safety triggers)..."
$diag="(none)"; $safety="(none)"
$logDir=Join-Path $dataDir "Tester\logs"
if(Test-Path $logDir){ $lg=Get-ChildItem $logDir -Filter *.log -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 4
  foreach($f in $lg){ $m=Select-String -Path $f.FullName -Pattern "\[v23live\]" -ErrorAction SilentlyContinue
    if($m){ foreach($ln in $m){ $t=$ln.Line.Trim(); if($t -match "digits="){$diag=$t.Substring($t.IndexOf("[v23live]"))}; if($t -match "safety triggers"){$safety=$t.Substring($t.IndexOf("[v23live]"))} }; if($safety -ne "(none)"){break} } } }

Write-Host "[5/5] A/B row-by-row diff (v23_live vs baseline v23_ts)..."
function LoadRows($p){ if(-not(Test-Path $p)){return @()} $r=@(); foreach($l in (Get-Content $p)){ if($l -match "^time,"){continue}; if($l.Trim() -eq ""){continue}; $r+=$l.Trim() }; return $r }
$L=LoadRows $csv; $B=LoadRows $baseCsv
$netL=0.0; foreach($r in $L){ $netL+=[double]($r -split ",")[1] }
$netB=0.0; foreach($r in $B){ $netB+=[double]($r -split ",")[1] }
$mism=0; $firstMism=@(); $max=[Math]::Max($L.Count,$B.Count)
for($i=0;$i -lt $max;$i++){ $a=if($i -lt $L.Count){$L[$i]}else{"<none>"}; $b=if($i -lt $B.Count){$B[$i]}else{"<none>"}; if($a -ne $b){ $mism++; if($firstMism.Count -lt 5){$firstMism+=("  row $($i+1): live=[$a] base=[$b]")} } }

Write-Host ""
Write-Host "=====V23LIVE_AB_START====="
Write-Host $diag
Write-Host $safety
Write-Host ("baseline rows : {0}   net {1:N2}" -f $B.Count,$netB)
Write-Host ("v23_live rows : {0}   net {1:N2}" -f $L.Count,$netL)
Write-Host ("mismatched rows: {0}" -f $mism)
if($mism -gt 0){ Write-Host "first mismatches:"; $firstMism|ForEach-Object{Write-Host $_} }
if($mism -eq 0 -and $L.Count -eq $B.Count -and $L.Count -gt 0){ Write-Host "VERDICT: IDENTICAL trade sequence -> execution-hardening confirmed (no strategy change)" } else { Write-Host "VERDICT: DIVERGENCE -> check safety line above to trace which fix fired" }
Write-Host "=====V23LIVE_AB_END====="
Write-Host ""
Write-Host "^ Copy the whole block back to me. (detail CSV also written: ck_v23live_regression_detail.csv)"

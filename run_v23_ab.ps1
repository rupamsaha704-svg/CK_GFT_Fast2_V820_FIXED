$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# AIRTIGHT A/B: runs BOTH v23_ts (baseline) AND v23_live back-to-back in the SAME session on the
# SAME real ticks, then diffs the two freshly-written CSVs. Eliminates GitHub-download parsing AND
# tick-drift (comparing today's live run vs a days-old baseline CSV was not a clean A/B).
# NOTE: stops ALL running MT5 terminals; assumes a SINGLE MT5 install. Two backtests => takes a while.
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"; $common=Join-Path $dataDir "..\Common\Files"
$csvB=Join-Path $common "ck_v23ts_trades.csv"; $csvL=Join-Path $common "ck_v23live_trades.csv"

function Fetch($name){ Invoke-WebRequest "$base/$name" -OutFile (Join-Path $exp $name) }
function Compile($name){ $mq=Join-Path $exp $name; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
   Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}; return (Test-Path $ex5) }
function RunBT($ex5name,$ini,$extraInputs){
   $cfg="[Tester]`nExpert=$ex5name`nSymbol=XAUUSD`nPeriod=M15`nModel=4`nExecutionMode=0`nFromDate=2025.08.01`nToDate=2026.08.01`nForwardMode=0`nDeposit=5000`nCurrency=USD`nLeverage=10`nOptimization=0`nShutdownTerminal=1`nVisual=0`n[TesterInputs]`nInpRR=3.0`nInpMaxSL_ATR=2.5`nInpRiskPercent=0.5`nInpMaxLot=0.09`n$extraInputs"
   Set-Content -Encoding ascii $ini $cfg
   Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 3
   $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
   $p|Wait-Process -Timeout 900 -ErrorAction SilentlyContinue
   if(-not $p.HasExited){$p|Stop-Process -Force -ErrorAction SilentlyContinue}; Start-Sleep 3 }

Write-Host "[1/6] downloading + compiling BOTH EAs..."
Fetch "CK_GFT_v23_ts.mq5"; Fetch "CK_GFT_v23_live.mq5"
if(-not (Compile "CK_GFT_v23_ts.mq5")){Write-Host "  v23_ts compile FAILED";exit}
if(-not (Compile "CK_GFT_v23_live.mq5")){Write-Host "  v23_live compile FAILED";exit}
Write-Host "  both compiled OK"

Write-Host "[2/6] clearing old CSVs..."
if(Test-Path $csvB){Remove-Item $csvB -Force}; if(Test-Path $csvL){Remove-Item $csvL -Force}

Write-Host "[3/6] backtest BASELINE v23_ts (real ticks, risk 0.5%, MaxLot 0.09)..."
RunBT "CK_GFT_v23_ts.ex5"   (Join-Path $research "ab_ts.ini")   ""
Write-Host "[4/6] backtest v23_live (SAME settings, SAME session/ticks)..."
RunBT "CK_GFT_v23_live.ex5" (Join-Path $research "ab_live.ini") "InpMaxSpreadPrice=0.60`n"

Write-Host "[5/6] reading [v23live] log lines..."
$diag="(none)"; $safety="(none)"; $fails=@()
$logDir=Join-Path $dataDir "Tester\logs"
if(Test-Path $logDir){ $lg=Get-ChildItem $logDir -Filter *.log -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 6
  foreach($f in $lg){ $m=Select-String -Path $f.FullName -Pattern "\[v23live\]" -ErrorAction SilentlyContinue
    if($m){ foreach($ln in $m){ $t=$ln.Line.Trim(); $ix=$t.IndexOf("[v23live]"); if($ix -lt 0){continue}; $t=$t.Substring($ix); if($t -match "digits="){$diag=$t}; if($t -match "safety triggers"){$safety=$t}; if($t -match "ORDER_FAIL" -and $fails.Count -lt 6){$fails+=$t} }; if($safety -ne "(none)"){break} } } }

Write-Host "[6/6] row-by-row diff of the TWO fresh CSVs (same ticks)..."
function LoadRows($p){ if(-not(Test-Path $p)){return ,@()} $r=@(); foreach($l in (Get-Content $p)){ $t=("$l").Trim(); if($t -eq ""){continue}; if($t -match "^time,"){continue}; $r+=$t }; return ,$r }
$B=LoadRows $csvB; $L=LoadRows $csvL
$netB=0.0; foreach($r in $B){ $netB+=[double]($r -split ",")[1] }
$netL=0.0; foreach($r in $L){ $netL+=[double]($r -split ",")[1] }
$mism=0; $first=@(); $max=[Math]::Max($B.Count,$L.Count)
for($i=0;$i -lt $max;$i++){ $a=if($i -lt $L.Count){$L[$i]}else{"<none>"}; $b=if($i -lt $B.Count){$B[$i]}else{"<none>"}; if($a -ne $b){ $mism++; if($first.Count -lt 8){$first+=("  row $($i+1): base=[$b]  live=[$a]")} } }

Write-Host ""
Write-Host "=====V23_AB2_START====="
Write-Host $diag
Write-Host $safety
if($fails.Count -gt 0){ Write-Host "order-fail detail:"; $fails|ForEach-Object{Write-Host ("  "+$_)} }
Write-Host ("baseline v23_ts : {0} rows   net {1:N2}" -f $B.Count,$netB)
Write-Host ("v23_live        : {0} rows   net {1:N2}" -f $L.Count,$netL)
Write-Host ("mismatched rows : {0}" -f $mism)
if($mism -gt 0){ Write-Host "first mismatches (base vs live):"; $first|ForEach-Object{Write-Host $_} }
if($B.Count -eq 0){ Write-Host "VERDICT: baseline CSV empty - v23_ts run/dump failed" }
elseif($mism -eq 0 -and $B.Count -eq $L.Count){ Write-Host "VERDICT: IDENTICAL on same ticks -> pure execution-hardening, ZERO strategy change" }
else { Write-Host "VERDICT: divergence -> trace via first mismatch timestamp + safety line above" }
Write-Host "=====V23_AB2_END====="
Write-Host ""
Write-Host "^ Copy the whole block back to me."

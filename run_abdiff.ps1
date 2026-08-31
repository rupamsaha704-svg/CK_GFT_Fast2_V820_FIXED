$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
# DIFF-ONLY (no backtest): re-diff the two CSVs already on disk, with a bug-free array loader.
# The earlier "baseline 1 row / 199 mismatch" was a PowerShell function-return array-unwrap bug,
# NOT a real divergence (csvdiag proved both files are well-formed and share identical opening rows).
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$common=Join-Path $dataDir "..\Common\Files"
$csvB=Join-Path $common "ck_v23ts_trades.csv"; $csvL=Join-Path $common "ck_v23live_trades.csv"

# bug-free: @(...) forces a flat string array; filter header + blanks
$B=@(Get-Content $csvB | Where-Object { $_ -and ($_ -notmatch '^time,') } | ForEach-Object { $_.Trim() })
$L=@(Get-Content $csvL | Where-Object { $_ -and ($_ -notmatch '^time,') } | ForEach-Object { $_.Trim() })

$netB=0.0; foreach($r in $B){ $netB+=[double]($r.Split(",")[1]) }
$netL=0.0; foreach($r in $L){ $netL+=[double]($r.Split(",")[1]) }

# how many identical leading rows (common prefix) before the FIRST real divergence
$prefix=0; $n=[Math]::Min($B.Count,$L.Count)
while($prefix -lt $n -and $B[$prefix] -eq $L[$prefix]){ $prefix++ }

$mism=0; $first=@(); $max=[Math]::Max($B.Count,$L.Count)
for($i=0;$i -lt $max;$i++){ $a=if($i -lt $L.Count){$L[$i]}else{"<none>"}; $b=if($i -lt $B.Count){$B[$i]}else{"<none>"}; if($a -ne $b){ $mism++; if($first.Count -lt 10){$first+=("  row $($i+1): base=[$b]  live=[$a]")} } }

Write-Host "=====ABDIFF_START====="
Write-Host ("baseline v23_ts : {0} rows   net {1:N2}" -f $B.Count,$netB)
Write-Host ("v23_live        : {0} rows   net {1:N2}" -f $L.Count,$netL)
Write-Host ("identical leading rows (common prefix): {0}" -f $prefix)
Write-Host ("total mismatched rows: {0}" -f $mism)
if($mism -gt 0){ Write-Host "FIRST divergence onward (base vs live):"; $first|ForEach-Object{Write-Host $_} }
if($mism -eq 0 -and $B.Count -eq $L.Count){ Write-Host "VERDICT: byte-identical trade lists -> pure execution-hardening, ZERO strategy change" }
else { Write-Host ("VERDICT: identical for first {0} trades, then {1} row(s) differ - trace from the timestamp above" -f $prefix,$mism) }
Write-Host "=====ABDIFF_END====="
Write-Host "^ Copy the whole block back to me."

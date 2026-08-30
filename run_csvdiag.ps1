$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
# Diagnostic only (no backtest): inspect the two trade CSVs to explain why baseline parses to 1 row.
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$common=Join-Path $dataDir "..\Common\Files"
$csvB=Join-Path $common "ck_v23ts_trades.csv"; $csvL=Join-Path $common "ck_v23live_trades.csv"

function Inspect($label,$p){
   Write-Host "----- $label : $p"
   if(-not(Test-Path $p)){ Write-Host "  MISSING"; return }
   $bytes=[System.IO.File]::ReadAllBytes($p)
   $cr=0;$lf=0; foreach($b in $bytes){ if($b -eq 13){$cr++}; if($b -eq 10){$lf++} }
   $glc=@(Get-Content $p).Count
   $raw=Get-Content $p -Raw; $rawlen=("$raw").Length
   $splitN=@(("$raw") -split "`n").Count
   Write-Host ("  bytes={0}  CR={1}  LF={2}  GetContentLines={3}  RawLen={4}  splitByLF={5}" -f $bytes.Length,$cr,$lf,$glc,$rawlen,$splitN)
   $head=("$raw").Substring(0,[Math]::Min(160,("$raw").Length)); $head=$head -replace "`r","<CR>" -replace "`n","<LF>`n"
   Write-Host "  FIRST 160 chars (control chars marked):"
   Write-Host $head
}
Write-Host "=====CSVDIAG_START====="
Inspect "BASELINE ck_v23ts_trades" $csvB
Inspect "LIVE ck_v23live_trades" $csvL
Write-Host "=====CSVDIAG_END====="
Write-Host "^ Copy the whole block back to me."

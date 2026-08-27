$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
# Pulls the relevant lines from the most recent Strategy Tester log(s): our EA prints + any error/reject/fail.
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$dirs=@((Join-Path $dataDir "Tester\logs"), (Join-Path $dataDir "MQL5\Logs"), (Join-Path $dataDir "logs"))
$logs=@()
foreach($d in $dirs){ if(Test-Path $d){ $logs += Get-ChildItem $d -Filter *.log -ErrorAction SilentlyContinue } }
$logs=$logs | Sort-Object LastWriteTime -Descending | Select-Object -First 4
$pat="CK_GOLD_PRO|ORDER_FAIL|fail|error|reject|invalid|no money|not enough|market closed|requote"
Write-Host "=====JOURNAL_START====="
if($logs.Count -eq 0){ Write-Host "no tester logs found" }
else{
  $hits=@()
  foreach($f in $logs){ $m=Select-String -Path $f.FullName -Pattern $pat -ErrorAction SilentlyContinue
     foreach($ln in $m){ $hits += $ln.Line.Trim() } }
  if($hits.Count -eq 0){ Write-Host "No EA prints or errors/rejects found in recent tester logs (clean run)." }
  else{ $hits | Select-Object -Last 60 | ForEach-Object { Write-Host $_ } }
}
Write-Host "=====JOURNAL_END====="
Write-Host "^ Copy this block back to me."

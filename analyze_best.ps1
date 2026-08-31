$ErrorActionPreference="Continue"
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$common=Join-Path $dataDir "..\Common\Files"
$csv=Join-Path $common "ck_best_trades.csv"
if(-not (Test-Path $csv)){ Write-Host "ck_best_trades.csv NOT found - run run_best_dump.ps1 first."; exit }

$bal=5000.0; $peak=5000.0; $mddPct=0.0; $mddAmt=0.0
$net=0.0; $n=0; $wins=0; $gp=0.0; $gl=0.0; $maxWin=-1e9; $maxLoss=1e9
Get-Content $csv | Select-Object -Skip 1 | ForEach-Object {
  $a=$_ -split ","
  if($a.Count -ge 2){
    $p=[double]$a[$a.Count-1]
    $n++; $net+=$p; $bal+=$p
    if($p -gt 0){$wins++; $gp+=$p} elseif($p -lt 0){$gl+=(-$p)}
    if($p -gt $maxWin){$maxWin=$p}; if($p -lt $maxLoss){$maxLoss=$p}
    if($bal -gt $peak){$peak=$bal}
    $dd=$peak-$bal; $ddp=$dd/$peak*100
    if($dd -gt $mddAmt){$mddAmt=$dd}; if($ddp -gt $mddPct){$mddPct=$ddp}
  }
}
$pf = if($gl -gt 0){$gp/$gl}else{999}
$winPct = if($n -gt 0){$wins/$n*100}else{0}
$ret = $net/5000.0*100
Write-Host "=====BEST_SUMMARY_START====="
Write-Host ("Trades        : {0}" -f $n)
Write-Host ("Net profit    : {0:N2}   (return {1:N0}% on 5000)" -f $net,$ret)
Write-Host ("Final equity  : {0:N2}" -f (5000+$net))
Write-Host ("Profit factor : {0:N3}" -f $pf)
Write-Host ("Win rate      : {0:N1}%" -f $winPct)
Write-Host ("Max drawdown  : {0:N2}  ({1:N1}%)   <- realized equity DD (compounding)" -f $mddAmt,$mddPct)
Write-Host ("Biggest win   : {0:N2}    Biggest loss : {1:N2}" -f $maxWin,$maxLoss)
Write-Host "=====BEST_SUMMARY_END====="
Write-Host "Copy this whole block and paste it back to me."

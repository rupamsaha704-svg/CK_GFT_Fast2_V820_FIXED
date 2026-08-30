$ErrorActionPreference="Continue"
$research="C:\Users\prita\CK_GFT_V22_RESEARCH"
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName "MQL5\Experts") } | Select-Object -First 1).FullName
Write-Host ("Data dir: " + $dataDir)
$anyReport=$false
foreach($n in @("CK_v23_IS","CK_v23_OOS")){
  $rf=Get-ChildItem $dataDir -Filter "$n.*" -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".htm",".html" } | Select-Object -First 1
  if($rf){
    $anyReport=$true
    $b=[IO.File]::ReadAllBytes($rf.FullName)
    if(($b[0..([Math]::Min(2000,$b.Length-1))] -contains 0)){ $t=[Text.Encoding]::Unicode.GetString($b) } else { $t=[Text.Encoding]::UTF8.GetString($b) }
    $t=$t.TrimStart([char]0xFEFF)
    [IO.File]::WriteAllText((Join-Path $research ($n+".htm")),$t,(New-Object Text.UTF8Encoding($false)))
    $x=($t -replace '<[^>]+>',' ' -replace '&nbsp;',' ' -replace '\s+',' ')
    $np=[regex]::Match($x,'Total Net Profit\s*:?\s*(-?\d[\d .,]*)').Groups[1].Value -replace '(?<=\d)\s+(?=\d)',''
    $pf=[regex]::Match($x,'Profit Factor\s*:?\s*(-?\d[\d .,]*)').Groups[1].Value -replace '(?<=\d)\s+(?=\d)',''
    $tr=[regex]::Match($x,'Total Trades\s*:?\s*(\d+)').Groups[1].Value
    Write-Host ("FOUND " + $n + " -> Net=" + $np + "  PF=" + $pf + "  Trades=" + $tr)
  } else { Write-Host ($n + " : report not found") }
}
if(-not $anyReport){
  Write-Host ""
  Write-Host "-------- newest Tester log (why it failed) --------"
  $logs=Get-ChildItem $dataDir -Recurse -Include *.log -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match "Tester\\logs|\\logs" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($logs){
    Write-Host ("Log: " + $logs.FullName)
    $lb=[IO.File]::ReadAllBytes($logs.FullName)
    if(($lb[0..([Math]::Min(2000,$lb.Length-1))] -contains 0)){ $lt=[Text.Encoding]::Unicode.GetString($lb) } else { $lt=[Text.Encoding]::UTF8.GetString($lb) }
    ($lt -split "`n" | Select-Object -Last 30) | ForEach-Object { Write-Host $_ }
  } else { Write-Host "No tester log found under data dir." }
}
Write-Host "== DIAG END =="

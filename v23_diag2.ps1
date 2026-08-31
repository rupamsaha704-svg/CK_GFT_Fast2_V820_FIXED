$ErrorActionPreference="Continue"
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName "MQL5\Experts") } | Select-Object -First 1).FullName
Write-Host ("Data dir: " + $dataDir)
Write-Host ""
Write-Host "-------- search for CK_v23 report files (recursive) --------"
$hits=Get-ChildItem $dataDir -Recurse -Filter "CK_v23_*" -ErrorAction SilentlyContinue
$hits += Get-ChildItem "C:\Program Files\MetaTrader 5" -Recurse -Filter "CK_v23_*" -ErrorAction SilentlyContinue
if($hits){ $hits | ForEach-Object { Write-Host ("  " + $_.FullName + "  (" + $_.Length + " bytes)") } } else { Write-Host "  none found anywhere" }
Write-Host ""
Write-Host "-------- newest AGENT tester log (shows trades / activity) --------"
$alog=Get-ChildItem (Join-Path $dataDir "Tester") -Recurse -Include *.log -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($alog){
  Write-Host ("Agent log: " + $alog.FullName)
  $b=[IO.File]::ReadAllBytes($alog.FullName)
  if(($b[0..([Math]::Min(2000,$b.Length-1))] -contains 0)){ $t=[Text.Encoding]::Unicode.GetString($b) } else { $t=[Text.Encoding]::UTF8.GetString($b) }
  ($t -split "`n" | Select-Object -Last 40) | ForEach-Object { Write-Host $_ }
} else { Write-Host "No agent log found under Tester folder." }
Write-Host "== DIAG2 END =="

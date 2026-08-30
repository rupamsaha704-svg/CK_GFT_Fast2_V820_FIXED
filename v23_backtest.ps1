$ErrorActionPreference="Continue"
$research="C:\Users\prita\CK_GFT_V22_RESEARCH"
if(-not (Test-Path $research)){ New-Item -ItemType Directory -Force $research | Out-Null }
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if(-not $term){ Write-Host "MT5 not found"; exit }
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName "MQL5\Experts") } | Select-Object -First 1).FullName

function RunBT($name,$from,$to){
  $rep=Join-Path $dataDir $name
  Get-ChildItem $dataDir -Filter "$name.*" -ErrorAction SilentlyContinue | Remove-Item -Force
  $ini=Join-Path $research "$name.ini"
  $cfg="[Tester]`nExpert=CK_GFT_Fast_v23_ROBUST.ex5`nSymbol=XAUUSD`nPeriod=M15`nModel=0`nFromDate=$from`nToDate=$to`nDeposit=5000`nCurrency=USD`nLeverage=100`nOptimization=0`nShutdownTerminal=1`nReport=$rep`nReplaceReport=1`nVisual=0`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 3
  Write-Host ("Running " + $name + "  (" + $from + " -> " + $to + ") ...")
  Start-Process -FilePath $term -ArgumentList ('/config:"{0}"' -f $ini)
  $s=Get-Date; $rf=$null
  while(((Get-Date)-$s).TotalMinutes -lt 8){
    Start-Sleep 10
    $rf=Get-ChildItem $dataDir -Filter "$name.*" -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".htm",".html" } | Select-Object -First 1
    if($rf){ break }
  }
  if(-not $rf){ Write-Host ("  " + $name + ": NO REPORT (data/tester issue)"); return }
  $b=[IO.File]::ReadAllBytes($rf.FullName)
  if(($b[0..([Math]::Min(2000,$b.Length-1))] -contains 0)){ $t=[Text.Encoding]::Unicode.GetString($b) } else { $t=[Text.Encoding]::UTF8.GetString($b) }
  $t=$t.TrimStart([char]0xFEFF)
  [IO.File]::WriteAllText((Join-Path $research ($name+".htm")),$t,(New-Object Text.UTF8Encoding($false)))
  $x=($t -replace '<[^>]+>',' ' -replace '&nbsp;',' ' -replace '\s+',' ')
  $np=[regex]::Match($x,'Total Net Profit\s*:?\s*(-?\d[\d .,]*)').Groups[1].Value -replace '(?<=\d)\s+(?=\d)',''
  $pf=[regex]::Match($x,'Profit Factor\s*:?\s*(-?\d[\d .,]*)').Groups[1].Value -replace '(?<=\d)\s+(?=\d)',''
  $tr=[regex]::Match($x,'Total Trades\s*:?\s*(\d+)').Groups[1].Value
  $dd=[regex]::Match($x,'Balance Drawdown Maximal\s*:?\s*([\d .,]*\([\d.,%]*\))').Groups[1].Value -replace '(?<=\d)\s+(?=\d)',''
  Write-Host ("  RESULT " + $name + " -> Net=" + $np + "  PF=" + $pf + "  Trades=" + $tr + "  MaxDD=" + $dd)
}

Write-Host "==================== v23 IN-SAMPLE + OUT-OF-SAMPLE (XAUUSD M15) ===================="
RunBT "CK_v23_IS"  "2024.01.01" "2024.07.01"
RunBT "CK_v23_OOS" "2024.07.01" "2025.01.01"
Write-Host "===================================================================================="
Write-Host "Done. Reports saved to: $research  (CK_v23_IS.htm, CK_v23_OOS.htm)"

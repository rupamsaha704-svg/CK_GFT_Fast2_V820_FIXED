$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
if(-not $me -or -not $dataDir){Write-Host "MT5 not found";exit}
$exp=Join-Path $dataDir "MQL5\Experts"
Write-Host "downloading + compiling CK_GOLD_FINAL_v1 ..."
Invoke-WebRequest "$base/CK_GOLD_FINAL_v1.mq5" -OutFile (Join-Path $exp "CK_GOLD_FINAL_v1.mq5")
$mq=Join-Path $exp "CK_GOLD_FINAL_v1.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(Test-Path $ex5){
  Write-Host ""
  Write-Host "==================== INSTALLED ===================="
  Write-Host " $ex5"
  Write-Host ""
  Write-Host " NOW verify it yourself in MT5 Strategy Tester:"
  Write-Host "  Expert   : CK_GOLD_FINAL_v1"
  Write-Host "  Symbol   : XAUUSD      Period: M15"
  Write-Host "  Modelling: Every tick based on real ticks"
  Write-Host "  Dates    : 2025.08.01  ->  2026.08.01"
  Write-Host "  Deposit  : 5000        Leverage: 1:10"
  Write-Host "  Inputs   : InpRR=3.0  InpMaxSL_ATR=2.5  InpMaxLot=0.09"
  Write-Host "             InpRiskPercent=2.0  -> expect ~+200% (net ~+10,000), DD ~16%"
  Write-Host "             InpRiskPercent=0.5  -> expect ~+115% (net ~+5,760), DD ~15%"
  Write-Host " Press Start. Compare the tester's Net Profit / Drawdown to the above."
  Write-Host "==================================================="
} else { Write-Host "compile FAILED - send me the MetaEditor error." }

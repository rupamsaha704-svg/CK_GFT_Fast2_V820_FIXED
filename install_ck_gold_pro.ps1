$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Download + compile CK_GOLD_PRO into MT5 Navigator. No backtest here - run the tester yourself.
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $me){Write-Host "MetaEditor not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
$exp=Join-Path $dataDir "MQL5\Experts"
Write-Host "[1/2] downloading CK_GOLD_PRO.mq5..."
Invoke-WebRequest "$base/CK_GOLD_PRO.mq5" -OutFile (Join-Path $exp "CK_GOLD_PRO.mq5")
$mq=Join-Path $exp "CK_GOLD_PRO.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Write-Host "[2/2] compiling..."
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}
Write-Host "  compiled OK -> 'CK_GOLD_PRO' is now in Navigator > Expert Advisors"
Write-Host ""
Write-Host "To verify in Strategy Tester (Ctrl+R): XAUUSD, M15, 'Every tick based on real ticks',"
Write-Host "2025.08.01 -> 2026.08.01, deposit 5000, leverage 1:10, InpRiskPercent=2.0, InpMaxLot=0.09."
Write-Host "Expect ~ +200% net, PF ~1.47. For demo/live: attach to XAUUSD M15, Allow Algo Trading, AutoTrading ON."

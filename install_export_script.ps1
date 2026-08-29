$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Installs + compiles CK_ExportOHLC into your MT5 Scripts folder.
# Does NOT run anything. After this, run it manually from Navigator > Scripts (2 clicks).
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $me){Write-Host "MetaEditor not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Scripts")}|Select-Object -First 1).FullName
if(-not $dataDir){ $dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName }
$scripts=Join-Path $dataDir "MQL5\Scripts"; if(-not(Test-Path $scripts)){New-Item -ItemType Directory -Force $scripts|Out-Null}
$common=Join-Path $dataDir "..\Common\Files"

Write-Host "[1/2] downloading CK_ExportOHLC.mq5 into Scripts..."
Invoke-WebRequest "$base/CK_ExportOHLC.mq5" -OutFile (Join-Path $scripts "CK_ExportOHLC.mq5")
$mq=Join-Path $scripts "CK_ExportOHLC.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}

Write-Host "[2/2] compiling..."
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(Test-Path $ex5){ Write-Host "  compiled OK" } else { Write-Host "  compile FAILED - check MetaEditor" }

Write-Host ""
Write-Host "==================== DONE - NOW DO THIS MANUALLY ===================="
Write-Host "1) In MT5 Navigator (left panel): open the 'Scripts' folder."
Write-Host "   Right-click Navigator > Refresh if you don't see CK_ExportOHLC."
Write-Host "2) Open a XAGUSD chart, then DOUBLE-CLICK CK_ExportOHLC onto it."
Write-Host "   In the box: tick 'Allow' + Inputs tab -> InpSymbol=XAGUSD, InpTF=PERIOD_M15 -> OK"
Write-Host "3) Repeat on a DXY chart (InpSymbol=DXY) and XAUUSD chart (InpSymbol=XAUUSD)."
Write-Host "4) Check the Toolbox > Experts tab: you should see 'EXPORT OK ... bars=... file=...'"
Write-Host "5) The CSVs are here (opening the folder now):"
Write-Host "   $common"
Write-Host "6) Upload those CSVs to GitHub branch kiro/validation-toolkit (Add file > Upload files),"
Write-Host "   then tell me 'uploaded'."
Write-Host "===================================================================="
Start-Process explorer.exe $common

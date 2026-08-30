$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName
Write-Host "MetaEditor : $me"
Write-Host "MT5 data   : $dataDir"
if(-not $me){Write-Host "!! metaeditor64.exe NOT FOUND under C:\Program Files"; exit}
if(-not $dataDir){Write-Host "!! MT5 data folder NOT FOUND"; exit}
$exp=Join-Path $dataDir "MQL5\Experts"
$mq=Join-Path $exp "CK_GOLD_FINAL_v1.mq5"
$ex5=Join-Path $exp "CK_GOLD_FINAL_v1.ex5"
$log=Join-Path $exp "CK_GOLD_FINAL_v1.log"

Write-Host "[1] downloading .mq5 to Experts..."
Invoke-WebRequest "$base/CK_GOLD_FINAL_v1.mq5" -OutFile $mq
if(Test-Path $mq){ Write-Host "    .mq5 saved OK ($((Get-Item $mq).Length) bytes): $mq" } else { Write-Host "!! .mq5 DID NOT SAVE"; exit }

if(Test-Path $ex5){Remove-Item $ex5 -Force}
if(Test-Path $log){Remove-Item $log -Force}
Write-Host "[2] compiling (with log)..."
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}" /log:"{1}"' -f $mq,$log) -Wait
Start-Sleep 2

Write-Host ""
Write-Host "================= RESULT ================="
if(Test-Path $ex5){
  Write-Host " SUCCESS: .ex5 compiled ->"
  Write-Host "   $ex5"
  Write-Host ""
  Write-Host " It IS installed. If you don't see it in MT5:"
  Write-Host "   -> In MT5 Navigator panel, RIGHT-CLICK 'Expert Advisors' -> Refresh"
  Write-Host "   -> or close and reopen MT5. The EA 'CK_GOLD_FINAL_v1' will appear."
} else {
  Write-Host " .ex5 NOT created -> compile failed. Compile log below:"
  Write-Host "------------------------------------------"
  if(Test-Path $log){ Get-Content $log } else { Write-Host " (no log produced)" }
  Write-Host "------------------------------------------"
}
Write-Host "=========================================="
Write-Host "Copy everything from RESULT down and paste it back to me."

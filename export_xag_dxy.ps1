$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Exports XAGUSD_M15 and DXY_M15 (XAUUSD already done). Uses the same StartUp method;
# if a file comes out empty, just run CK_ExportOHLC manually from Navigator for that one.
$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Scripts")}|Select-Object -First 1).FullName
if(-not $dataDir){ $dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName }
$scripts=Join-Path $dataDir "MQL5\Scripts"; if(-not(Test-Path $scripts)){New-Item -ItemType Directory -Force $scripts|Out-Null}
$common=Join-Path $dataDir "..\Common\Files"

# ensure export script present + compiled
$mq=Join-Path $scripts "CK_ExportOHLC.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5")
if(-not (Test-Path $ex5)){
  Invoke-WebRequest "$base/CK_ExportOHLC.mq5" -OutFile $mq
  Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
}

$jobs=@(
  @{sym="XAGUSD"; out="XAGUSD_M15.csv"},
  @{sym="DXY";    out="DXY_M15.csv"}
)
foreach($j in $jobs){
  Write-Host "exporting $($j.sym) M15..."
  $out=Join-Path $common $j.out; if(Test-Path $out){Remove-Item $out -Force -ErrorAction SilentlyContinue}
  $ini=Join-Path $research "exp2.ini"
  $cfg="[StartUp]`nScript=CK_ExportOHLC`nSymbol=$($j.sym)`nPeriod=PERIOD_M15`n[Script]`nInpSymbol=$($j.sym)`nInpTF=PERIOD_M15`nInpYearsBack=6`nInpOutFile=$($j.out)`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  Start-Sleep 40
  if($p -and -not $p.HasExited){ $p|Stop-Process -Force -ErrorAction SilentlyContinue }; Start-Sleep 2
}

Write-Host ""
Write-Host "==================== RESULT ===================="
foreach($j in $jobs){
  $out=Join-Path $common $j.out
  if(Test-Path $out){ $kb=[math]::Round((Get-Item $out).Length/1KB,0); Write-Host ("  OK  {0}  ({1} KB)" -f $j.out,$kb) }
  else { Write-Host ("  EMPTY {0} - run CK_ExportOHLC manually on a {1} chart (InpSymbol={1}, InpTF=PERIOD_M15)" -f $j.out,$j.sym) }
}
Write-Host "Files folder (opening now):  $common"
Write-Host "Upload XAUUSD_M15_export.csv + XAGUSD_M15.csv + DXY_M15.csv to GitHub branch kiro/validation-toolkit, then tell me 'uploaded'."
Write-Host "================================================"
Start-Process explorer.exe $common

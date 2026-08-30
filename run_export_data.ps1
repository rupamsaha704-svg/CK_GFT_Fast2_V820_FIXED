$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Exports OHLC history for XAUUSD (long), XAGUSD, DXY via CK_ExportOHLC script.
# Prints each CSV between markers so you can copy-paste them back to me.
# EDIT the two lines below if your DXY symbol has a different name in Market Watch.
$DXY_SYMBOL = "DXY"        # <-- if your broker calls it USDX / USDIDX / DX, change this
$YEARS      = 6           # how many years of history to pull

$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Scripts")}|Select-Object -First 1).FullName
if(-not $dataDir){ $dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName }
$scripts=Join-Path $dataDir "MQL5\Scripts"; if(-not(Test-Path $scripts)){New-Item -ItemType Directory -Force $scripts|Out-Null}
$common=Join-Path $dataDir "..\Common\Files"

Write-Host "[1/3] downloading + compiling CK_ExportOHLC..."
Invoke-WebRequest "$base/CK_ExportOHLC.mq5" -OutFile (Join-Path $scripts "CK_ExportOHLC.mq5")
$mq=Join-Path $scripts "CK_ExportOHLC.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

# jobs: symbol, timeframe, output filename, marker tag
$jobs=@(
  @{sym="XAUUSD"; tf="PERIOD_M15"; out="XAUUSD_M15_long.csv"; tag="XAUUSD_M15"},
  @{sym="XAUUSD"; tf="PERIOD_M5";  out="XAUUSD_M5_long.csv";  tag="XAUUSD_M5"},
  @{sym="XAGUSD"; tf="PERIOD_M15"; out="XAGUSD_M15.csv";      tag="XAGUSD_M15"},
  @{sym="XAGUSD"; tf="PERIOD_M5";  out="XAGUSD_M5.csv";       tag="XAGUSD_M5"},
  @{sym=$DXY_SYMBOL; tf="PERIOD_M15"; out="DXY_M15.csv";      tag="DXY_M15"}
)

Write-Host "[2/3] running $($jobs.Count) exports ($YEARS years each)..."
foreach($j in $jobs){
  $out=Join-Path $common $j.out; if(Test-Path $out){Remove-Item $out -Force -ErrorAction SilentlyContinue}
  $ini=Join-Path $research "export.ini"
  # Run the script via tester-less start: use a chart config that launches the Script.
  # Simpler + reliable: use /portable-less Script run through the terminal's startup .ini
  $cfg="[StartUp]`nScript=CK_ExportOHLC`nSymbol=$($j.sym)`nPeriod=$($j.tf)`n[Script]`nInpSymbol=$($j.sym)`nInpTF=$($j.tf)`nInpYearsBack=$YEARS`nInpOutFile=$($j.out)`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  # give it time to download history + write; big M5 pulls take longer
  Start-Sleep 45
  if($p -and -not $p.HasExited){ $p|Stop-Process -Force -ErrorAction SilentlyContinue }
  Start-Sleep 2
}

Write-Host "[3/3] printing CSVs - COPY EACH BLOCK (including START/END markers) back to me:"
foreach($j in $jobs){
  $out=Join-Path $common $j.out
  Write-Host ""
  Write-Host ("=====EXPORT_{0}_START=====" -f $j.tag)
  if(Test-Path $out){
    $n=(Get-Content $out | Measure-Object -Line).Lines
    Write-Host ("# symbol=$($j.sym) tf=$($j.tf) rows=$n file=$($j.out)")
    Get-Content $out
  } else {
    Write-Host "# NO FILE for $($j.sym) $($j.tf) - symbol name wrong OR no history. If DXY failed, check its exact Market Watch name and edit `$DXY_SYMBOL at top of this script."
  }
  Write-Host ("=====EXPORT_{0}_END=====" -f $j.tag)
}
Write-Host ""
Write-Host "Done. If a block is huge, you can paste them to me one at a time - XAGUSD/DXY M15 first (needed for SMT), then the long XAUUSD."

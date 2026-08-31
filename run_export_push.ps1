$ErrorActionPreference="Continue"; $ProgressPreference="SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Export XAUUSD(long)/XAGUSD/DXY OHLC from MT5, gather the CSVs into one folder,
# and (if git is available) push them to GitHub so Kiro can pull them directly.
# EDIT these if needed:
$DXY_SYMBOL = "DXY"     # <-- your broker's dollar-index name (DXY / USDX / USDIDX / DX)
$YEARS      = 6
$GIT_REMOTE = "https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED.git"  # your repo over normal GitHub
$BRANCH     = "data-drop"   # a fresh branch just for data

$research=Join-Path $env:USERPROFILE "CK_GFT_V22_RESEARCH"; if(-not(Test-Path $research)){New-Item -ItemType Directory -Force $research|Out-Null}
$base="https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/kiro/validation-toolkit"
$term=(Get-ChildItem "C:\Program Files" -Recurse -Filter terminal64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
$me=(Get-ChildItem "C:\Program Files" -Recurse -Filter metaeditor64.exe -ErrorAction SilentlyContinue|Select-Object -First 1).FullName
if(-not $term -or -not $me){Write-Host "MT5 not found";exit}
$dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Scripts")}|Select-Object -First 1).FullName
if(-not $dataDir){ $dataDir=(Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory -ErrorAction SilentlyContinue|Where-Object{Test-Path (Join-Path $_.FullName "MQL5\Experts")}|Select-Object -First 1).FullName }
$scripts=Join-Path $dataDir "MQL5\Scripts"; if(-not(Test-Path $scripts)){New-Item -ItemType Directory -Force $scripts|Out-Null}
$common=Join-Path $dataDir "..\Common\Files"

Write-Host "[1/4] downloading + compiling CK_ExportOHLC..."
Invoke-WebRequest "$base/CK_ExportOHLC.mq5" -OutFile (Join-Path $scripts "CK_ExportOHLC.mq5")
$mq=Join-Path $scripts "CK_ExportOHLC.mq5"; $ex5=[System.IO.Path]::ChangeExtension($mq,".ex5"); if(Test-Path $ex5){Remove-Item $ex5 -Force}
Start-Process -FilePath $me -ArgumentList ('/compile:"{0}"' -f $mq); for($i=0;$i -lt 40;$i++){Start-Sleep 1; if(Test-Path $ex5){break}}
if(-not (Test-Path $ex5)){Write-Host "  compile FAILED";exit}; Write-Host "  compiled OK"

$jobs=@(
  @{sym="XAUUSD"; tf="PERIOD_M15"; out="XAUUSD_M15_long.csv"},
  @{sym="XAUUSD"; tf="PERIOD_M5";  out="XAUUSD_M5_long.csv"},
  @{sym="XAGUSD"; tf="PERIOD_M15"; out="XAGUSD_M15.csv"},
  @{sym="XAGUSD"; tf="PERIOD_M5";  out="XAGUSD_M5.csv"},
  @{sym=$DXY_SYMBOL; tf="PERIOD_M15"; out="DXY_M15.csv"}
)

Write-Host "[2/4] running exports via StartUp-script (best effort)..."
foreach($j in $jobs){
  $out=Join-Path $common $j.out; if(Test-Path $out){Remove-Item $out -Force -ErrorAction SilentlyContinue}
  $ini=Join-Path $research "export.ini"
  $cfg="[StartUp]`nScript=CK_ExportOHLC`nSymbol=$($j.sym)`nPeriod=$($j.tf)`n[Script]`nInpSymbol=$($j.sym)`nInpTF=$($j.tf)`nInpYearsBack=$YEARS`nInpOutFile=$($j.out)`n"
  Set-Content -Encoding ascii $ini $cfg
  Get-Process terminal64 -ErrorAction SilentlyContinue|Stop-Process -Force; Start-Sleep 2
  $p=Start-Process $term -ArgumentList ('/config:"{0}"' -f $ini) -PassThru
  Start-Sleep 45
  if($p -and -not $p.HasExited){ $p|Stop-Process -Force -ErrorAction SilentlyContinue }; Start-Sleep 2
}

Write-Host "[3/4] gathering CSVs into a drop folder..."
$drop=Join-Path $research "data_drop"; if(Test-Path $drop){Remove-Item $drop -Recurse -Force}; New-Item -ItemType Directory -Force $drop|Out-Null
$found=@()
foreach($j in $jobs){ $out=Join-Path $common $j.out; if(Test-Path $out){ Copy-Item $out (Join-Path $drop $j.out) -Force; $found+=$j.out } }
Write-Host ("  found CSVs: " + ($(if($found.Count){$found -join ', '}else{'NONE - StartUp auto-run may have failed; run the script manually (see notes)'})))

Write-Host "[4/4] trying to push to GitHub branch '$BRANCH'..."
$git=Get-Command git -ErrorAction SilentlyContinue
if(-not $git){
  Write-Host ""
  Write-Host "  git NOT installed on this PC. Two easy options:"
  Write-Host "   (A) Install Git for Windows (git-scm.com), re-run this script."
  Write-Host "   (B) Manually upload the CSVs in this folder to GitHub (drag-drop on github.com):"
  Write-Host "       $drop"
  Start-Process explorer.exe $drop
  exit
}
Push-Location $drop
& git init -q 2>$null
& git checkout -b $BRANCH 2>$null
& git add -f *.csv 2>$null
& git -c user.email="data@ck.local" -c user.name="CK Data Drop" commit -q -m "MT5 data drop: XAUUSD long + XAGUSD + DXY" 2>$null
& git remote remove origin 2>$null
& git remote add origin $GIT_REMOTE 2>$null
Write-Host "  pushing... (a GitHub login/token window may pop up - approve it)"
& git push -f origin $BRANCH 2>&1 | ForEach-Object { Write-Host "   $_" }
Pop-Location
Write-Host ""
Write-Host "If push succeeded: tell me 'pushed to data-drop' and I'll pull the CSVs directly."
Write-Host "If it asked for a password/token and failed: just open $drop and drag the CSVs onto github.com (branch $BRANCH)."
Start-Process explorer.exe $drop

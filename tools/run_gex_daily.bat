@echo off
REM Daily free GEX collector - schedule via Windows Task Scheduler (run ~after US close, Mon-Fri).
REM Builds our own historical GEX dataset in data_gex\ for future (disciplined, free) validation.
cd /d C:\Users\prita\CK_GFT_Repo
C:\Python314\python.exe tools\gex_calc.py _NDX
C:\Python314\python.exe tools\gex_calc.py QQQ
C:\Python314\python.exe tools\gex_calc.py _SPX

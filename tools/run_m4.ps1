# Final real-tick (Model-4) confirmation - ONE at a time, cooldown, crash-safe markers.
$ErrorActionPreference = "Continue"
$py = "C:\Python314\python.exe"
& $py tools\gen_m4.py
$runs = @(
  @{p="experiments\combo_m4_eval\preset.json";   o="tools\_e4.txt"},
  @{p="experiments\combo_m4_funded\preset.json"; o="tools\_f4.txt"}
)
foreach ($r in $runs) {
  powershell -ExecutionPolicy Bypass -File tools\run_candidate.ps1 -Preset $r.p -TimeoutSec 1800 *> $r.o 2>&1
  ("done " + $r.p) | Out-File tools\_m4_progress.txt -Append -Encoding utf8
  Start-Sleep -Seconds 20   # cooldown between heavy runs
}
"M4_DONE" | Out-File tools\_m4_done.txt -Encoding utf8

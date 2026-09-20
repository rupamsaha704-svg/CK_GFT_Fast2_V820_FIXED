# Funded lot sweep, REAL-TICK (Model-4) last1y - ONE at a time, cooldown, crash-safe markers.
$ErrorActionPreference = "Continue"
$py = "C:\Python314\python.exe"
& $py tools\gen_fsweep.py
$runs = @(
  @{p="experiments\combo_fs_a\preset.json"; o="tools\_fsa.txt"},
  @{p="experiments\combo_fs_b\preset.json"; o="tools\_fsb.txt"}
)
foreach ($r in $runs) {
  powershell -ExecutionPolicy Bypass -File tools\run_candidate.ps1 -Preset $r.p -TimeoutSec 1800 *> $r.o 2>&1
  ("done " + $r.p) | Out-File tools\_fsweep_progress.txt -Append -Encoding utf8
  Start-Sleep -Seconds 25
}
"FSWEEP_DONE" | Out-File tools\_fsweep_done.txt -Encoding utf8

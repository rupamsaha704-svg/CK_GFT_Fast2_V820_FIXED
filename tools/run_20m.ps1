# 20-month breadth check - ONE at a time (Model-1 fast, light), cooldown, markers.
$ErrorActionPreference = "Continue"
$py = "C:\Python314\python.exe"
& $py tools\gen_20m.py
$runs = @(
  @{p="experiments\combo_20m_eval\preset.json";   o="tools\_20e.txt"},
  @{p="experiments\combo_20m_funded\preset.json"; o="tools\_20f.txt"}
)
foreach ($r in $runs) {
  powershell -ExecutionPolicy Bypass -File tools\run_candidate.ps1 -Preset $r.p -TimeoutSec 1200 *> $r.o 2>&1
  ("done " + $r.p) | Out-File tools\_20m_progress.txt -Append -Encoding utf8
  Start-Sleep -Seconds 15
}
"M20_DONE" | Out-File tools\_20m_done.txt -Encoding utf8

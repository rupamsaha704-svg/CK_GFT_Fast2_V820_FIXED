# Sequential test matrix - ONE backtest at a time (peak load = single MT5), cooldown between.
$ErrorActionPreference = "Continue"
$py = "C:\Python314\python.exe"
& $py tools\gen_matrix.py
$runs = @(
  @{p="experiments\combo_mtf1\preset.json";       o="tools\_m1.txt"},
  @{p="experiments\combo_mtf3\preset.json";       o="tools\_m3.txt"},
  @{p="experiments\combo_mtf_old\preset.json";    o="tools\_mo.txt"},
  @{p="experiments\combo_funded_old\preset.json"; o="tools\_fo.txt"}
)
foreach ($r in $runs) {
  powershell -ExecutionPolicy Bypass -File tools\run_candidate.ps1 -Preset $r.p -TimeoutSec 900 *> $r.o 2>&1
  ("done " + $r.p) | Out-File tools\_matrix_progress.txt -Append -Encoding utf8
  Start-Sleep -Seconds 15   # small cooldown between runs
}
"MATRIX_DONE" | Out-File tools\_matrix_done.txt -Encoding utf8

# Two logical commits, then push
Set-Location 'C:\Users\prita\CK_GFT_Repo'
$ErrorActionPreference = 'Continue'

Write-Output "=== 1. Commit steering fix (E: HDD lesson) ==="
git add .kiro/steering/gft-mission-and-rules.md
git commit -m "steering: rewrite Section 8 (E: HDD root-cause + retirement) + add Section 10 (shell hygiene)" -m "Section 8: replace wrong PSU/thermal hypothesis with confirmed E: HDD (Daichi DI DE00D) SMART fault (240 reallocated sectors). Document completed resolution 2026-09-21: 12.26 GB migrated to C: (robocopy 53739/53739 files, 0 failed), shell folders redirected via HKCU registry, E: drive letter removed, disk offlined, boot-time SYSTEM task 'OfflineSickHDD_Daichi' registered. Add HARD RULES for future sessions/agents: never touch E: or Disk #0, never modify/delete the boot task, physical removal ultimate but not urgent. Section 10 (new): Shell hygiene rules from the phantom Get-WmiObject incident 2026-09-19 -- never redirect to a bare filename, no cd into System32/Windows/ProgramFiles, -NoProfile mandatory for E:-touching probes, elevated ops must write results to log files."
Write-Output ""

Write-Output "=== 2. Stage everything else (all new work + Section 9 cleanup) ==="
git add -A
Write-Output ""

Write-Output "=== 2b. Verify what will be committed (top-level summary) ==="
$staged = git diff --cached --stat | Select-Object -Last 1
Write-Output "staged: $staged"
Write-Output ""

Write-Output "=== 3. Commit workspace snapshot ==="
git commit -m "workspace snapshot: FundedNext configs + strategy docs + compliance tooling; Section 9 cleanup" -m "New: experiments/combo_fnext_03/ (live challenge config) and 20+ variant experiments (combo_fnext_02f_*, combo_m4_*, combo_mtf*, combo_noguard_04, combo_fnext_6k*, combo_fnext_ixu10k*, combo_funded_aggr, combo_funded_rr, idea104_stdv, orb_screen, bbsqz_screen); new EAs CK_BB_SQZ / CK_GOLD_FIX_VISUAL / CK_LDN_ORB; SPEC docs GFT_RULEBOOK / GFT_SUPPORT_QUESTIONS / STRATEGY_INDEX / STRATEGY_ORDERBOOK / EDGE_SEARCH_AGENT; sub-agent files eye-watch / gft-compliance / strategy-decoder; compliance tooling check_compliance.ps1 / gft_compliance.py / eye_watch.py / funded*_check.py; analysis tools analyze_*.py / gen_*.py / sensitivity_reset_hour.py; charts entry_timing / fundednext_journey (interim + final) / loss_by_hour; strategy PDF text extracts under docs/strategy_pdfs_text/. Modified: CK_GOLD_COMBO.set, tools/funded_check.py, tools/_compile/CK_GOLD_COMBO.compile.log. Cleanup (Section 9): remove ~200 experiments/*/windows/*/tester.log files (multi-MB junk each) and ~180 tools/_*.txt scratch files."
Write-Output ""

Write-Output "=== 4. Push to origin ==="
git push origin kiro/mt5-validation-backup 2>&1
Write-Output ""

Write-Output "=== 5. Final status ==="
git status -sb
Write-Output ""
git log --oneline -5

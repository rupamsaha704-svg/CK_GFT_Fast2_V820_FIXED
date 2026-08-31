# Candidate report - fix09_dep50k

- EA: CK_GOLD_PRO_FIX09
- Preset: experiments\fix09_dep50k\preset.json
- Generated (UTC): 2026-08-30 16:47:41Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: baseline_dep50k  (2025.06.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             369
  net                8863.44
  return_pct         17.73
  pf                 1.32
  win_rate           23.31
  expectancy         24.02
  avg_win            426.94
  avg_loss           -99.83
  max_dd_closed_pct  7.67
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_dep50k\windows\baseline_dep50k\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             369
  net                                8863.44
  return_pct                         17.73
  pf                                 1.32
  win_rate                           23.31
  expectancy                         24.02
  avg_win                            426.94
  avg_loss                           -99.83
  max_dd_closed_pct                  7.67

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

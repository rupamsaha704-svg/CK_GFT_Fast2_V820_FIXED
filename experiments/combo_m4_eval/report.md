# Candidate report - combo_m4_eval

- EA: CK_GOLD_COMBO
- Preset: experiments\combo_m4_eval\preset.json
- Generated (UTC): 2026-09-03 11:48:39Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: last1y  (2025.09.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             300
  net                6078220578.00
  return_pct         121564411.56
  pf                 inf
  win_rate           100.00
  expectancy         20260735.26
  avg_win            20260735.26
  avg_loss           0.00
  max_dd_closed_pct  0.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\combo_m4_eval\windows\last1y\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             300
  net                                6078220578.0
  return_pct                         121564411.56
  pf                                 inf
  win_rate                           100.0
  expectancy                         20260735.26
  avg_win                            20260735.26
  avg_loss                           0.0
  max_dd_closed_pct                  0.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

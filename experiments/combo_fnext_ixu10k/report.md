# Candidate report - combo_fnext_ixu10k

- EA: CK_GOLD_COMBO
- Preset: experiments\combo_fnext_ixu10k\preset.json
- Generated (UTC): 2026-09-18 17:55:24Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: oct25_sep26  (2025.10.01 to 2026.09.18)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             280
  net                5673008184.00
  return_pct         56730081.84
  pf                 inf
  win_rate           100.00
  expectancy         20260743.51
  avg_win            20260743.51
  avg_loss           0.00
  max_dd_closed_pct  0.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\combo_fnext_ixu10k\windows\oct25_sep26\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             280
  net                                5673008184.0
  return_pct                         56730081.84
  pf                                 inf
  win_rate                           100.0
  expectancy                         20260743.51
  avg_win                            20260743.51
  avg_loss                           0.0
  max_dd_closed_pct                  0.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

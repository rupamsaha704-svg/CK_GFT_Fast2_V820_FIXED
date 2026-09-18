# Candidate report - dtrend_m4

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_m4\preset.json
- Generated (UTC): 2026-09-02 10:13:52Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: last1y  (2025.09.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             39
  net                811.06
  return_pct         16.22
  pf                 1.43
  win_rate           46.15
  expectancy         20.80
  avg_win            149.51
  avg_loss           -89.53
  max_dd_closed_pct  13.61
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_m4\windows\last1y\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             39
  net                                811.06
  return_pct                         16.22
  pf                                 1.43
  win_rate                           46.15
  expectancy                         20.8
  avg_win                            149.51
  avg_loss                           -89.53
  max_dd_closed_pct                  13.61

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

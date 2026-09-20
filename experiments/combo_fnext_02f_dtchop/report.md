# Candidate report - combo_fnext_02f_dtchop

- EA: CK_GOLD_COMBO
- Preset: experiments\combo_fnext_02f_dtchop\preset.json
- Generated (UTC): 2026-09-18 07:10:19Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: last1y  (2025.09.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             301
  net                6098480224.00
  return_pct         121969604.48
  pf                 inf
  win_rate           100.00
  expectancy         20260731.64
  avg_win            20260731.64
  avg_loss           0.00
  max_dd_closed_pct  0.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\combo_fnext_02f_dtchop\windows\last1y\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             301
  net                                6098480224.0
  return_pct                         121969604.48
  pf                                 inf
  win_rate                           100.0
  expectancy                         20260731.64
  avg_win                            20260731.64
  avg_loss                           0.0
  max_dd_closed_pct                  0.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

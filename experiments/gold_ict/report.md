# Candidate report - gold_ict

- EA: CK_GOLD_ICT
- Preset: experiments\gold_ict\preset.json
- Generated (UTC): 2026-09-02 07:26:40Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: may  (2026.05.01 to 2026.06.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             17
  net                -402.04
  return_pct         -8.04
  pf                 0.38
  win_rate           11.76
  expectancy         -23.65
  avg_win            123.16
  avg_loss           -43.22
  max_dd_closed_pct  8.04
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_ict\windows\may\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             12
  net                -400.00
  return_pct         -8.00
  pf                 0.15
  win_rate           8.33
  expectancy         -33.33
  avg_win            70.24
  avg_loss           -42.75
  max_dd_closed_pct  8.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_ict\windows\chop\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             17
  net                                -402.04
  return_pct                         -8.04
  pf                                 0.38
  win_rate                           11.76
  expectancy                         -23.65
  avg_win                            123.16
  avg_loss                           -43.22
  max_dd_closed_pct                  8.04

[OUT-OF-SAMPLE]
  trades                             12
  net                                -400.0
  return_pct                         -8.0
  pf                                 0.15
  win_rate                           8.33
  expectancy                         -33.33
  avg_win                            70.24
  avg_loss                           -42.75
  max_dd_closed_pct                  8.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 12<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

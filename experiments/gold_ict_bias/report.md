# Candidate report - gold_ict_bias

- EA: CK_GOLD_ICT
- Preset: experiments\gold_ict_bias\preset.json
- Generated (UTC): 2026-09-02 07:57:41Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: may  (2026.05.01 to 2026.06.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             12
  net                -417.70
  return_pct         -8.35
  pf                 0.13
  win_rate           8.33
  expectancy         -34.81
  avg_win            62.52
  avg_loss           -43.66
  max_dd_closed_pct  8.35
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_ict_bias\windows\may\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             12
  net                -402.43
  return_pct         -8.05
  pf                 0.15
  win_rate           8.33
  expectancy         -33.54
  avg_win            70.24
  avg_loss           -42.97
  max_dd_closed_pct  8.05
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_ict_bias\windows\chop\report.htm

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             176
  net                -404.31
  return_pct         -8.09
  pf                 0.93
  win_rate           23.86
  expectancy         -2.30
  avg_win            137.66
  avg_loss           -46.16
  max_dd_closed_pct  12.96
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_ict_bias\windows\trend\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             12
  net                                -417.7
  return_pct                         -8.35
  pf                                 0.13
  win_rate                           8.33
  expectancy                         -34.81
  avg_win                            62.52
  avg_loss                           -43.66
  max_dd_closed_pct                  8.35

[OUT-OF-SAMPLE]
  trades                             12
  net                                -402.43
  return_pct                         -8.05
  pf                                 0.15
  win_rate                           8.33
  expectancy                         -33.54
  avg_win                            70.24
  avg_loss                           -42.97
  max_dd_closed_pct                  8.05

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 12<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

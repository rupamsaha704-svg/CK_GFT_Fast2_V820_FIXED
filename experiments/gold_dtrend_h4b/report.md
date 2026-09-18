# Candidate report - gold_dtrend_h4b

- EA: CK_GOLD_DTREND
- Preset: experiments\gold_dtrend_h4b\preset.json
- Generated (UTC): 2026-09-01 18:55:23Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             45
  net                6864.01
  return_pct         137.28
  pf                 1.90
  win_rate           31.11
  expectancy         152.53
  avg_win            1034.13
  avg_loss           -245.61
  max_dd_closed_pct  49.03
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend_h4b\windows\trend\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             57
  net                -1602.18
  return_pct         -32.04
  pf                 0.70
  win_rate           19.30
  expectancy         -28.11
  avg_win            347.00
  avg_loss           -117.81
  max_dd_closed_pct  66.86
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend_h4b\windows\chop\report.htm

## Window: full  (2025.09.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             99
  net                4138.51
  return_pct         82.77
  pf                 1.19
  win_rate           25.25
  expectancy         41.80
  avg_win            1020.30
  avg_loss           -288.77
  max_dd_closed_pct  60.92
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend_h4b\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             45
  net                                6864.01
  return_pct                         137.28
  pf                                 1.9
  win_rate                           31.11
  expectancy                         152.53
  avg_win                            1034.13
  avg_loss                           -245.61
  max_dd_closed_pct                  49.03

[OUT-OF-SAMPLE]
  trades                             57
  net                                -1602.18
  return_pct                         -32.04
  pf                                 0.7
  win_rate                           19.3
  expectancy                         -28.11
  avg_win                            347.0
  avg_loss                           -117.81
  max_dd_closed_pct                  66.86

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 57<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

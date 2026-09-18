# Candidate report - dtrend_h4c

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_h4c\preset.json
- Generated (UTC): 2026-09-02 08:50:33Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             21
  net                1831.50
  return_pct         36.63
  pf                 4.61
  win_rate           66.67
  expectancy         87.21
  avg_win            167.10
  avg_loss           -72.56
  max_dd_closed_pct  3.48
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4c\windows\trend\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             5
  net                -400.03
  return_pct         -8.00
  pf                 0.00
  win_rate           0.00
  expectancy         -80.01
  avg_win            0.00
  avg_loss           -80.01
  max_dd_closed_pct  8.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4c\windows\chop\report.htm

## Window: full  (2025.09.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             34
  net                1414.76
  return_pct         28.30
  pf                 2.06
  win_rate           47.06
  expectancy         41.61
  avg_win            171.81
  avg_loss           -74.12
  max_dd_closed_pct  12.05
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4c\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             21
  net                                1831.5
  return_pct                         36.63
  pf                                 4.61
  win_rate                           66.67
  expectancy                         87.21
  avg_win                            167.1
  avg_loss                           -72.56
  max_dd_closed_pct                  3.48

[OUT-OF-SAMPLE]
  trades                             5
  net                                -400.03
  return_pct                         -8.0
  pf                                 0.0
  win_rate                           0.0
  expectancy                         -80.01
  avg_win                            0.0
  avg_loss                           -80.01
  max_dd_closed_pct                  8.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 5<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

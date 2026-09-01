# Candidate report - sweep_trend_NZDUSD

- EA: CK_TREND_ATR_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_NZDUSD\preset.json
- Generated (UTC): 2026-08-31 19:34:25Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             109
  net                -438.62
  return_pct         -8.77
  pf                 0.59
  win_rate           24.77
  expectancy         -4.02
  avg_win            23.17
  avg_loss           -12.98
  max_dd_closed_pct  9.31
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_NZDUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             77
  net                -384.76
  return_pct         -7.70
  pf                 0.58
  win_rate           25.97
  expectancy         -5.00
  avg_win            26.59
  avg_loss           -16.08
  max_dd_closed_pct  8.89
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_NZDUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             33
  net                -133.59
  return_pct         -2.67
  pf                 0.63
  win_rate           24.24
  expectancy         -4.05
  avg_win            28.20
  avg_loss           -14.37
  max_dd_closed_pct  3.36
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_NZDUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             109
  net                                -438.62
  return_pct                         -8.77
  pf                                 0.59
  win_rate                           24.77
  expectancy                         -4.02
  avg_win                            23.17
  avg_loss                           -12.98
  max_dd_closed_pct                  9.31

[OUT-OF-SAMPLE]
  trades                             77
  net                                -384.76
  return_pct                         -7.7
  pf                                 0.58
  win_rate                           25.97
  expectancy                         -5.0
  avg_win                            26.59
  avg_loss                           -16.08
  max_dd_closed_pct                  8.89

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 77<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

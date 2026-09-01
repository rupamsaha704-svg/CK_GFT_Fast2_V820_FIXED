# Candidate report - sweep_trend_XAUUSD

- EA: CK_TREND_ATR_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_XAUUSD\preset.json
- Generated (UTC): 2026-08-31 19:39:20Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             90
  net                2538.48
  return_pct         50.77
  pf                 1.19
  win_rate           38.89
  expectancy         28.21
  avg_win            448.59
  avg_loss           -239.31
  max_dd_closed_pct  27.93
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_XAUUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             60
  net                1026.76
  return_pct         20.54
  pf                 1.13
  win_rate           36.67
  expectancy         17.11
  avg_win            417.88
  avg_loss           -214.91
  max_dd_closed_pct  40.75
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_XAUUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             30
  net                -1012.91
  return_pct         -20.26
  pf                 0.73
  win_rate           30.00
  expectancy         -33.76
  avg_win            304.97
  avg_loss           -178.94
  max_dd_closed_pct  28.69
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_XAUUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             90
  net                                2538.48
  return_pct                         50.77
  pf                                 1.19
  win_rate                           38.89
  expectancy                         28.21
  avg_win                            448.59
  avg_loss                           -239.31
  max_dd_closed_pct                  27.93

[OUT-OF-SAMPLE]
  trades                             60
  net                                1026.76
  return_pct                         20.54
  pf                                 1.13
  win_rate                           36.67
  expectancy                         17.11
  avg_win                            417.88
  avg_loss                           -214.91
  max_dd_closed_pct                  40.75

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 60<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

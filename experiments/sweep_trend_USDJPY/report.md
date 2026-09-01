# Candidate report - sweep_trend_USDJPY

- EA: CK_TREND_ATR_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDJPY\preset.json
- Generated (UTC): 2026-08-31 19:37:24Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             103
  net                129.82
  return_pct         2.60
  pf                 1.12
  win_rate           34.95
  expectancy         1.26
  avg_win            34.78
  avg_loss           -16.75
  max_dd_closed_pct  3.38
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDJPY\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             74
  net                -172.75
  return_pct         -3.45
  pf                 0.72
  win_rate           28.38
  expectancy         -2.33
  avg_win            21.40
  avg_loss           -11.74
  max_dd_closed_pct  4.42
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDJPY\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             36
  net                43.83
  return_pct         0.88
  pf                 1.16
  win_rate           33.33
  expectancy         1.22
  avg_win            26.93
  avg_loss           -11.64
  max_dd_closed_pct  1.63
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDJPY\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             103
  net                                129.82
  return_pct                         2.6
  pf                                 1.12
  win_rate                           34.95
  expectancy                         1.26
  avg_win                            34.78
  avg_loss                           -16.75
  max_dd_closed_pct                  3.38

[OUT-OF-SAMPLE]
  trades                             74
  net                                -172.75
  return_pct                         -3.45
  pf                                 0.72
  win_rate                           28.38
  expectancy                         -2.33
  avg_win                            21.4
  avg_loss                           -11.74
  max_dd_closed_pct                  4.42

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 74<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

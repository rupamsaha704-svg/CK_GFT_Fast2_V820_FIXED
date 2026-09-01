# Candidate report - sweep_trend_USDCHF

- EA: CK_TREND_ATR_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCHF\preset.json
- Generated (UTC): 2026-08-31 19:35:53Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             111
  net                -245.69
  return_pct         -4.91
  pf                 0.82
  win_rate           31.53
  expectancy         -2.21
  avg_win            31.81
  avg_loss           -17.88
  max_dd_closed_pct  9.26
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCHF\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             79
  net                -264.87
  return_pct         -5.30
  pf                 0.72
  win_rate           34.18
  expectancy         -3.35
  avg_win            24.86
  avg_loss           -18.00
  max_dd_closed_pct  6.73
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCHF\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             38
  net                -51.05
  return_pct         -1.02
  pf                 0.85
  win_rate           26.32
  expectancy         -1.34
  avg_win            28.34
  avg_loss           -11.95
  max_dd_closed_pct  3.23
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCHF\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             111
  net                                -245.69
  return_pct                         -4.91
  pf                                 0.82
  win_rate                           31.53
  expectancy                         -2.21
  avg_win                            31.81
  avg_loss                           -17.88
  max_dd_closed_pct                  9.26

[OUT-OF-SAMPLE]
  trades                             79
  net                                -264.87
  return_pct                         -5.3
  pf                                 0.72
  win_rate                           34.18
  expectancy                         -3.35
  avg_win                            24.86
  avg_loss                           -18.0
  max_dd_closed_pct                  6.73

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 79<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

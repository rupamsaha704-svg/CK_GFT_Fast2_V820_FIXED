# Candidate report - sweep_trend_AUDUSD

- EA: CK_TREND_ATR_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_AUDUSD\preset.json
- Generated (UTC): 2026-08-31 19:31:25Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             100
  net                -112.55
  return_pct         -2.25
  pf                 0.88
  win_rate           27.00
  expectancy         -1.13
  avg_win            30.30
  avg_loss           -12.75
  max_dd_closed_pct  4.97
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_AUDUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             74
  net                -113.65
  return_pct         -2.27
  pf                 0.85
  win_rate           33.78
  expectancy         -1.54
  avg_win            26.56
  avg_loss           -15.87
  max_dd_closed_pct  3.29
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_AUDUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             34
  net                -94.76
  return_pct         -1.90
  pf                 0.62
  win_rate           29.41
  expectancy         -2.79
  avg_win            15.55
  avg_loss           -10.43
  max_dd_closed_pct  3.28
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_AUDUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             100
  net                                -112.55
  return_pct                         -2.25
  pf                                 0.88
  win_rate                           27.0
  expectancy                         -1.13
  avg_win                            30.3
  avg_loss                           -12.75
  max_dd_closed_pct                  4.97

[OUT-OF-SAMPLE]
  trades                             74
  net                                -113.65
  return_pct                         -2.27
  pf                                 0.85
  win_rate                           33.78
  expectancy                         -1.54
  avg_win                            26.56
  avg_loss                           -15.87
  max_dd_closed_pct                  3.29

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 74<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

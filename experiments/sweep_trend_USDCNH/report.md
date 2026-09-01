# Candidate report - sweep_trend_USDCNH

- EA: CK_TREND_ATR_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCNH\preset.json
- Generated (UTC): 2026-08-31 19:36:37Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             90
  net                -105.64
  return_pct         -2.11
  pf                 0.71
  win_rate           26.67
  expectancy         -1.17
  avg_win            10.72
  avg_loss           -5.50
  max_dd_closed_pct  3.17
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCNH\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             21
  net                -51.61
  return_pct         -1.03
  pf                 0.63
  win_rate           33.33
  expectancy         -2.46
  avg_win            12.77
  avg_loss           -10.07
  max_dd_closed_pct  1.85
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCNH\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             39
  net                -81.38
  return_pct         -1.63
  pf                 0.46
  win_rate           17.95
  expectancy         -2.09
  avg_win            9.74
  avg_loss           -4.67
  max_dd_closed_pct  1.78
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCNH\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             90
  net                                -105.64
  return_pct                         -2.11
  pf                                 0.71
  win_rate                           26.67
  expectancy                         -1.17
  avg_win                            10.72
  avg_loss                           -5.5
  max_dd_closed_pct                  3.17

[OUT-OF-SAMPLE]
  trades                             21
  net                                -51.61
  return_pct                         -1.03
  pf                                 0.63
  win_rate                           33.33
  expectancy                         -2.46
  avg_win                            12.77
  avg_loss                           -10.07
  max_dd_closed_pct                  1.85

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 21<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - sweep_trend_USDCAD

- EA: CK_TREND_ATR_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCAD\preset.json
- Generated (UTC): 2026-08-31 19:35:08Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             120
  net                -256.01
  return_pct         -5.12
  pf                 0.71
  win_rate           27.50
  expectancy         -2.13
  avg_win            18.91
  avg_loss           -10.12
  max_dd_closed_pct  5.12
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCAD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             60
  net                210.89
  return_pct         4.22
  pf                 1.51
  win_rate           40.00
  expectancy         3.51
  avg_win            25.92
  avg_loss           -11.42
  max_dd_closed_pct  1.97
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCAD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             35
  net                -46.69
  return_pct         -0.93
  pf                 0.81
  win_rate           34.29
  expectancy         -1.33
  avg_win            16.33
  avg_loss           -10.55
  max_dd_closed_pct  3.13
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDCAD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             120
  net                                -256.01
  return_pct                         -5.12
  pf                                 0.71
  win_rate                           27.5
  expectancy                         -2.13
  avg_win                            18.91
  avg_loss                           -10.12
  max_dd_closed_pct                  5.12

[OUT-OF-SAMPLE]
  trades                             60
  net                                210.89
  return_pct                         4.22
  pf                                 1.51
  win_rate                           40.0
  expectancy                         3.51
  avg_win                            25.92
  avg_loss                           -11.42
  max_dd_closed_pct                  1.97

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 60<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - trend_gbpusd

- EA: CK_TREND_ATR_v1
- Preset: experiments\trend_gbpusd\preset.json
- Generated (UTC): 2026-08-31 19:16:30Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             105
  net                113.26
  return_pct         2.27
  pf                 1.09
  win_rate           38.10
  expectancy         1.08
  avg_win            34.11
  avg_loss           -19.25
  max_dd_closed_pct  5.69
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_gbpusd\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             83
  net                -293.88
  return_pct         -5.88
  pf                 0.71
  win_rate           27.71
  expectancy         -3.54
  avg_win            31.03
  avg_loss           -16.79
  max_dd_closed_pct  8.80
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_gbpusd\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             34
  net                -85.87
  return_pct         -1.72
  pf                 0.74
  win_rate           32.35
  expectancy         -2.53
  avg_win            22.05
  avg_loss           -14.28
  max_dd_closed_pct  2.58
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_gbpusd\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             105
  net                                113.26
  return_pct                         2.27
  pf                                 1.09
  win_rate                           38.1
  expectancy                         1.08
  avg_win                            34.11
  avg_loss                           -19.25
  max_dd_closed_pct                  5.69

[OUT-OF-SAMPLE]
  trades                             83
  net                                -293.88
  return_pct                         -5.88
  pf                                 0.71
  win_rate                           27.71
  expectancy                         -3.54
  avg_win                            31.03
  avg_loss                           -16.79
  max_dd_closed_pct                  8.8

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 83<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

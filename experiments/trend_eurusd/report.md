# Candidate report - trend_eurusd

- EA: CK_TREND_ATR_v1
- Preset: experiments\trend_eurusd\preset.json
- Generated (UTC): 2026-08-31 19:15:42Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             99
  net                -19.73
  return_pct         -0.39
  pf                 0.98
  win_rate           38.38
  expectancy         -0.20
  avg_win            23.88
  avg_loss           -15.20
  max_dd_closed_pct  4.90
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_eurusd\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             75
  net                -57.48
  return_pct         -1.15
  pf                 0.93
  win_rate           29.33
  expectancy         -0.77
  avg_win            36.01
  avg_loss           -16.03
  max_dd_closed_pct  5.55
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_eurusd\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             41
  net                -281.52
  return_pct         -5.63
  pf                 0.32
  win_rate           19.51
  expectancy         -6.87
  avg_win            16.87
  avg_loss           -12.62
  max_dd_closed_pct  7.47
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_eurusd\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             99
  net                                -19.73
  return_pct                         -0.39
  pf                                 0.98
  win_rate                           38.38
  expectancy                         -0.2
  avg_win                            23.88
  avg_loss                           -15.2
  max_dd_closed_pct                  4.9

[OUT-OF-SAMPLE]
  trades                             75
  net                                -57.48
  return_pct                         -1.15
  pf                                 0.93
  win_rate                           29.33
  expectancy                         -0.77
  avg_win                            36.01
  avg_loss                           -16.03
  max_dd_closed_pct                  5.55

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 75<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

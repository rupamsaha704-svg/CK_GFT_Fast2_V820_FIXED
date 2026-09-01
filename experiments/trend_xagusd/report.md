# Candidate report - trend_xagusd

- EA: CK_TREND_ATR_v1
- Preset: experiments\trend_xagusd\preset.json
- Generated (UTC): 2026-08-31 19:17:44Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             102
  net                9355.91
  return_pct         187.12
  pf                 1.59
  win_rate           37.25
  expectancy         91.72
  avg_win            664.25
  avg_loss           -248.21
  max_dd_closed_pct  21.52
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_xagusd\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             64
  net                -1150.23
  return_pct         -23.00
  pf                 0.83
  win_rate           31.25
  expectancy         -17.97
  avg_win            284.82
  avg_loss           -155.61
  max_dd_closed_pct  39.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_xagusd\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             35
  net                -1699.41
  return_pct         -33.99
  pf                 0.47
  win_rate           37.14
  expectancy         -48.55
  avg_win            116.74
  avg_loss           -146.23
  max_dd_closed_pct  33.99
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trend_xagusd\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             102
  net                                9355.91
  return_pct                         187.12
  pf                                 1.59
  win_rate                           37.25
  expectancy                         91.72
  avg_win                            664.25
  avg_loss                           -248.21
  max_dd_closed_pct                  21.52

[OUT-OF-SAMPLE]
  trades                             64
  net                                -1150.23
  return_pct                         -23.0
  pf                                 0.83
  win_rate                           31.25
  expectancy                         -17.97
  avg_win                            284.82
  avg_loss                           -155.61
  max_dd_closed_pct                  39.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 64<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

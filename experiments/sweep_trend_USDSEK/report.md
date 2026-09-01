# Candidate report - sweep_trend_USDSEK

- EA: CK_TREND_ATR_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDSEK\preset.json
- Generated (UTC): 2026-08-31 19:38:05Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
_No trades / CSV missing for this window._
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDSEK\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             6
  net                52.06
  return_pct         1.04
  pf                 2.39
  win_rate           50.00
  expectancy         8.68
  avg_win            29.83
  avg_loss           -12.47
  max_dd_closed_pct  0.59
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDSEK\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             3
  net                -54.17
  return_pct         -1.08
  pf                 0.00
  win_rate           0.00
  expectancy         -18.06
  avg_win            0.00
  avg_loss           -18.06
  max_dd_closed_pct  1.08
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_trend_USDSEK\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             6
  net                                52.06
  return_pct                         1.04
  pf                                 2.39
  win_rate                           50.0
  expectancy                         8.68
  avg_win                            29.83
  avg_loss                           -12.47
  max_dd_closed_pct                  0.59

[OUT-OF-SAMPLE]
  trades                             3
  net                                -54.17
  return_pct                         -1.08
  pf                                 0.0
  win_rate                           0.0
  expectancy                         -18.06
  avg_win                            0.0
  avg_loss                           -18.06
  max_dd_closed_pct                  1.08

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 3<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

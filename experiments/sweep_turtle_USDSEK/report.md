# Candidate report - sweep_turtle_USDSEK

- EA: CK_TURTLE_SOUP_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDSEK\preset.json
- Generated (UTC): 2026-08-31 19:46:01Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
_No trades / CSV missing for this window._
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDSEK\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             21
  net                2.57
  return_pct         0.05
  pf                 1.03
  win_rate           38.10
  expectancy         0.12
  avg_win            10.17
  avg_loss           -6.06
  max_dd_closed_pct  0.84
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDSEK\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             5
  net                44.75
  return_pct         0.90
  pf                 5.63
  win_rate           40.00
  expectancy         8.95
  avg_win            27.21
  avg_loss           -3.22
  max_dd_closed_pct  0.15
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDSEK\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             21
  net                                2.57
  return_pct                         0.05
  pf                                 1.03
  win_rate                           38.1
  expectancy                         0.12
  avg_win                            10.17
  avg_loss                           -6.06
  max_dd_closed_pct                  0.84

[OUT-OF-SAMPLE]
  trades                             5
  net                                44.75
  return_pct                         0.9
  pf                                 5.63
  win_rate                           40.0
  expectancy                         8.95
  avg_win                            27.21
  avg_loss                           -3.22
  max_dd_closed_pct                  0.15

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 5<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

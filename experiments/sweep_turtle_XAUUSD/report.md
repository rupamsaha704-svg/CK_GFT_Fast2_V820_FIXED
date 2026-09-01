# Candidate report - sweep_turtle_XAUUSD

- EA: CK_TURTLE_SOUP_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_XAUUSD\preset.json
- Generated (UTC): 2026-08-31 19:46:54Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             234
  net                327.78
  return_pct         6.56
  pf                 1.04
  win_rate           29.91
  expectancy         1.40
  avg_win            133.75
  avg_loss           -55.09
  max_dd_closed_pct  33.98
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_XAUUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             128
  net                1375.37
  return_pct         27.51
  pf                 1.22
  win_rate           38.28
  expectancy         10.75
  avg_win            154.91
  avg_loss           -78.68
  max_dd_closed_pct  18.67
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_XAUUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             39
  net                -1629.37
  return_pct         -32.59
  pf                 0.33
  win_rate           17.95
  expectancy         -41.78
  avg_win            115.10
  avg_loss           -76.10
  max_dd_closed_pct  33.20
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_XAUUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             234
  net                                327.78
  return_pct                         6.56
  pf                                 1.04
  win_rate                           29.91
  expectancy                         1.4
  avg_win                            133.75
  avg_loss                           -55.09
  max_dd_closed_pct                  33.98

[OUT-OF-SAMPLE]
  trades                             128
  net                                1375.37
  return_pct                         27.51
  pf                                 1.22
  win_rate                           38.28
  expectancy                         10.75
  avg_win                            154.91
  avg_loss                           -78.68
  max_dd_closed_pct                  18.67

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 128<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

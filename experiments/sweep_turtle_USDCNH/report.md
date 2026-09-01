# Candidate report - sweep_turtle_USDCNH

- EA: CK_TURTLE_SOUP_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCNH\preset.json
- Generated (UTC): 2026-08-31 19:44:44Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             370
  net                -346.34
  return_pct         -6.93
  pf                 0.47
  win_rate           18.38
  expectancy         -0.94
  avg_win            4.48
  avg_loss           -2.16
  max_dd_closed_pct  7.06
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCNH\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             71
  net                33.19
  return_pct         0.66
  pf                 1.26
  win_rate           35.21
  expectancy         0.47
  avg_win            6.44
  avg_loss           -2.78
  max_dd_closed_pct  0.55
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCNH\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             123
  net                -81.72
  return_pct         -1.63
  pf                 0.47
  win_rate           20.33
  expectancy         -0.66
  avg_win            2.93
  avg_loss           -1.58
  max_dd_closed_pct  1.63
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCNH\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             370
  net                                -346.34
  return_pct                         -6.93
  pf                                 0.47
  win_rate                           18.38
  expectancy                         -0.94
  avg_win                            4.48
  avg_loss                           -2.16
  max_dd_closed_pct                  7.06

[OUT-OF-SAMPLE]
  trades                             71
  net                                33.19
  return_pct                         0.66
  pf                                 1.26
  win_rate                           35.21
  expectancy                         0.47
  avg_win                            6.44
  avg_loss                           -2.78
  max_dd_closed_pct                  0.55

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 71<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - turtle_XAGUSD

- EA: CK_TURTLE_SOUP_v1
- Preset: experiments\turtle_XAGUSD\preset.json
- Generated (UTC): 2026-08-31 17:54:09Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             181
  net                -2926.55
  return_pct         -58.53
  pf                 0.70
  win_rate           22.65
  expectancy         -16.17
  avg_win            164.50
  avg_loss           -69.08
  max_dd_closed_pct  60.14
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_XAGUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             105
  net                -477.00
  return_pct         -9.54
  pf                 0.95
  win_rate           31.43
  expectancy         -4.54
  avg_win            284.05
  avg_loss           -136.81
  max_dd_closed_pct  42.81
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_XAGUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             47
  net                -1902.25
  return_pct         -38.05
  pf                 0.45
  win_rate           17.02
  expectancy         -40.47
  avg_win            193.35
  avg_loss           -88.44
  max_dd_closed_pct  47.05
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_XAGUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             181
  net                                -2926.55
  return_pct                         -58.53
  pf                                 0.7
  win_rate                           22.65
  expectancy                         -16.17
  avg_win                            164.5
  avg_loss                           -69.08
  max_dd_closed_pct                  60.14

[OUT-OF-SAMPLE]
  trades                             105
  net                                -477.0
  return_pct                         -9.54
  pf                                 0.95
  win_rate                           31.43
  expectancy                         -4.54
  avg_win                            284.05
  avg_loss                           -136.81
  max_dd_closed_pct                  42.81

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 105<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

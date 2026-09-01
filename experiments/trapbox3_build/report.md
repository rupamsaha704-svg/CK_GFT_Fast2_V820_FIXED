# Candidate report - trapbox3_build

- EA: CK_TRAPBOX_DKT_v3
- Preset: experiments\trapbox3_build\preset.json
- Generated (UTC): 2026-08-31 16:22:43Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             131
  net                -54.02
  return_pct         -1.08
  pf                 0.99
  win_rate           39.69
  expectancy         -0.41
  avg_win            180.18
  avg_loss           -119.28
  max_dd_closed_pct  25.35
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trapbox3_build\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             50
  net                -1228.10
  return_pct         -24.56
  pf                 0.77
  win_rate           36.00
  expectancy         -24.56
  avg_win            230.02
  avg_loss           -167.76
  max_dd_closed_pct  45.72
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trapbox3_build\windows\OOS_build\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             131
  net                                -54.02
  return_pct                         -1.08
  pf                                 0.99
  win_rate                           39.69
  expectancy                         -0.41
  avg_win                            180.18
  avg_loss                           -119.28
  max_dd_closed_pct                  25.35

[OUT-OF-SAMPLE]
  trades                             50
  net                                -1228.1
  return_pct                         -24.56
  pf                                 0.77
  win_rate                           36.0
  expectancy                         -24.56
  avg_win                            230.02
  avg_loss                           -167.76
  max_dd_closed_pct                  45.72

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 50<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

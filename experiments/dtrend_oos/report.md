# Candidate report - dtrend_oos

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_oos\preset.json
- Generated (UTC): 2026-09-02 09:26:28Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: oos_early2025  (2025.01.15 to 2025.05.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             14
  net                389.56
  return_pct         7.79
  pf                 2.44
  win_rate           50.00
  expectancy         27.83
  avg_win            94.37
  avg_loss           -38.72
  max_dd_closed_pct  2.20
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_oos\windows\oos_early2025\report.htm

## Window: oos_mid2025  (2025.05.01 to 2025.09.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             16
  net                32.75
  return_pct         0.66
  pf                 1.10
  win_rate           37.50
  expectancy         2.05
  avg_win            61.95
  avg_loss           -33.89
  max_dd_closed_pct  2.97
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_oos\windows\oos_mid2025\report.htm

## Window: oos_full2025  (2025.01.15 to 2025.09.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             30
  net                378.94
  return_pct         7.58
  pf                 1.58
  win_rate           43.33
  expectancy         12.63
  avg_win            79.41
  avg_loss           -38.43
  max_dd_closed_pct  3.90
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_oos\windows\oos_full2025\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             14
  net                                389.56
  return_pct                         7.79
  pf                                 2.44
  win_rate                           50.0
  expectancy                         27.83
  avg_win                            94.37
  avg_loss                           -38.72
  max_dd_closed_pct                  2.2

[OUT-OF-SAMPLE]
  trades                             16
  net                                32.75
  return_pct                         0.66
  pf                                 1.1
  win_rate                           37.5
  expectancy                         2.05
  avg_win                            61.95
  avg_loss                           -33.89
  max_dd_closed_pct                  2.97

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 16<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

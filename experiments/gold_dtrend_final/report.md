# Candidate report - gold_dtrend_final

- EA: CK_GOLD_DTREND
- Preset: experiments\gold_dtrend_final\preset.json
- Generated (UTC): 2026-09-02 08:11:53Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             6
  net                1978.33
  return_pct         39.57
  pf                 6.40
  win_rate           66.67
  expectancy         329.72
  avg_win            586.18
  avg_loss           -183.20
  max_dd_closed_pct  3.01
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend_final\windows\trend\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             3
  net                -411.51
  return_pct         -8.23
  pf                 0.00
  win_rate           0.00
  expectancy         -137.17
  avg_win            0.00
  avg_loss           -137.17
  max_dd_closed_pct  8.23
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend_final\windows\chop\report.htm

## Window: full  (2025.09.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             10
  net                1243.07
  return_pct         24.86
  pf                 2.53
  win_rate           50.00
  expectancy         124.31
  avg_win            411.41
  avg_loss           -162.79
  max_dd_closed_pct  5.91
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend_final\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             6
  net                                1978.33
  return_pct                         39.57
  pf                                 6.4
  win_rate                           66.67
  expectancy                         329.72
  avg_win                            586.18
  avg_loss                           -183.2
  max_dd_closed_pct                  3.01

[OUT-OF-SAMPLE]
  trades                             3
  net                                -411.51
  return_pct                         -8.23
  pf                                 0.0
  win_rate                           0.0
  expectancy                         -137.17
  avg_win                            0.0
  avg_loss                           -137.17
  max_dd_closed_pct                  8.23

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 3<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

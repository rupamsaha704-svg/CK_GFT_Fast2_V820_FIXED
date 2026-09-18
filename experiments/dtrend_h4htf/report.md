# Candidate report - dtrend_h4htf

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_h4htf\preset.json
- Generated (UTC): 2026-09-02 09:05:54Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: may_sep  (2026.05.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             7
  net                -90.91
  return_pct         -1.82
  pf                 0.71
  win_rate           14.29
  expectancy         -12.99
  avg_win            218.60
  avg_loss           -51.59
  max_dd_closed_pct  3.14
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4htf\windows\may_sep\report.htm

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             21
  net                1831.50
  return_pct         36.63
  pf                 4.61
  win_rate           66.67
  expectancy         87.21
  avg_win            167.10
  avg_loss           -72.56
  max_dd_closed_pct  3.48
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4htf\windows\trend\report.htm

## Window: full  (2025.09.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             35
  net                1099.45
  return_pct         21.99
  pf                 1.77
  win_rate           42.86
  expectancy         31.41
  avg_win            168.67
  avg_loss           -71.53
  max_dd_closed_pct  11.32
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4htf\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             7
  net                                -90.91
  return_pct                         -1.82
  pf                                 0.71
  win_rate                           14.29
  expectancy                         -12.99
  avg_win                            218.6
  avg_loss                           -51.59
  max_dd_closed_pct                  3.14

[OUT-OF-SAMPLE]
  trades                             21
  net                                1831.5
  return_pct                         36.63
  pf                                 4.61
  win_rate                           66.67
  expectancy                         87.21
  avg_win                            167.1
  avg_loss                           -72.56
  max_dd_closed_pct                  3.48

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 21<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - dtrend_h4htf50

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_h4htf50\preset.json
- Generated (UTC): 2026-09-02 09:08:25Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: may_sep  (2026.05.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             7
  net                -28.19
  return_pct         -0.56
  pf                 0.91
  win_rate           28.57
  expectancy         -4.03
  avg_win            146.16
  avg_loss           -64.10
  max_dd_closed_pct  3.24
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4htf50\windows\may_sep\report.htm

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
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4htf50\windows\trend\report.htm

## Window: full  (2025.09.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             34
  net                1266.13
  return_pct         25.32
  pf                 1.95
  win_rate           47.06
  expectancy         37.24
  avg_win            162.73
  avg_loss           -74.31
  max_dd_closed_pct  9.86
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h4htf50\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             7
  net                                -28.19
  return_pct                         -0.56
  pf                                 0.91
  win_rate                           28.57
  expectancy                         -4.03
  avg_win                            146.16
  avg_loss                           -64.1
  max_dd_closed_pct                  3.24

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

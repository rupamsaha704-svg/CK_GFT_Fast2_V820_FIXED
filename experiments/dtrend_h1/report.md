# Candidate report - dtrend_h1

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_h1\preset.json
- Generated (UTC): 2026-09-02 12:45:00Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             82
  net                1262.95
  return_pct         25.26
  pf                 1.74
  win_rate           47.56
  expectancy         15.40
  avg_win            76.09
  avg_loss           -39.65
  max_dd_closed_pct  7.57
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h1\windows\trend\report.htm

## Window: may_sep  (2026.05.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             16
  net                -100.01
  return_pct         -2.00
  pf                 0.75
  win_rate           31.25
  expectancy         -6.25
  avg_win            59.32
  avg_loss           -36.06
  max_dd_closed_pct  4.04
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h1\windows\may_sep\report.htm

## Window: full  (2025.09.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             109
  net                835.39
  return_pct         16.71
  pf                 1.34
  win_rate           42.20
  expectancy         7.66
  avg_win            72.36
  avg_loss           -39.58
  max_dd_closed_pct  10.37
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_h1\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             82
  net                                1262.95
  return_pct                         25.26
  pf                                 1.74
  win_rate                           47.56
  expectancy                         15.4
  avg_win                            76.09
  avg_loss                           -39.65
  max_dd_closed_pct                  7.57

[OUT-OF-SAMPLE]
  trades                             16
  net                                -100.01
  return_pct                         -2.0
  pf                                 0.75
  win_rate                           31.25
  expectancy                         -6.25
  avg_win                            59.32
  avg_loss                           -36.06
  max_dd_closed_pct                  4.04

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 16<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

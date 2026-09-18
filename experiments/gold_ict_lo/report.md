# Candidate report - gold_ict_lo

- EA: CK_GOLD_ICT
- Preset: experiments\gold_ict_lo\preset.json
- Generated (UTC): 2026-09-02 07:28:38Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: may  (2026.05.01 to 2026.06.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             11
  net                -405.13
  return_pct         -8.10
  pf                 0.03
  win_rate           9.09
  expectancy         -36.83
  avg_win            13.37
  avg_loss           -41.85
  max_dd_closed_pct  8.10
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_ict_lo\windows\may\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             14
  net                -403.86
  return_pct         -8.08
  pf                 0.15
  win_rate           7.14
  expectancy         -28.85
  avg_win            70.24
  avg_loss           -36.47
  max_dd_closed_pct  8.08
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_ict_lo\windows\chop\report.htm

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             39
  net                -404.17
  return_pct         -8.08
  pf                 0.71
  win_rate           20.51
  expectancy         -10.36
  avg_win            122.73
  avg_loss           -44.71
  max_dd_closed_pct  9.92
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_ict_lo\windows\trend\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             11
  net                                -405.13
  return_pct                         -8.1
  pf                                 0.03
  win_rate                           9.09
  expectancy                         -36.83
  avg_win                            13.37
  avg_loss                           -41.85
  max_dd_closed_pct                  8.1

[OUT-OF-SAMPLE]
  trades                             14
  net                                -403.86
  return_pct                         -8.08
  pf                                 0.15
  win_rate                           7.14
  expectancy                         -28.85
  avg_win                            70.24
  avg_loss                           -36.47
  max_dd_closed_pct                  8.08

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 14<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

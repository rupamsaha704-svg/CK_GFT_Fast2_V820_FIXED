# Candidate report - dtrend_ride

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_ride\preset.json
- Generated (UTC): 2026-09-02 08:48:12Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             1
  net                1809.41
  return_pct         36.19
  pf                 inf
  win_rate           100.00
  expectancy         1809.41
  avg_win            1809.41
  avg_loss           0.00
  max_dd_closed_pct  0.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_ride\windows\trend\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             4
  net                -452.09
  return_pct         -9.04
  pf                 0.00
  win_rate           0.00
  expectancy         -113.02
  avg_win            0.00
  avg_loss           -113.02
  max_dd_closed_pct  9.04
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_ride\windows\chop\report.htm

## Window: full  (2025.09.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             2
  net                947.38
  return_pct         18.95
  pf                 18.08
  win_rate           50.00
  expectancy         473.69
  avg_win            1002.85
  avg_loss           -55.47
  max_dd_closed_pct  0.92
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_ride\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             1
  net                                1809.41
  return_pct                         36.19
  pf                                 inf
  win_rate                           100.0
  expectancy                         1809.41
  avg_win                            1809.41
  avg_loss                           0.0
  max_dd_closed_pct                  0.0

[OUT-OF-SAMPLE]
  trades                             4
  net                                -452.09
  return_pct                         -9.04
  pf                                 0.0
  win_rate                           0.0
  expectancy                         -113.02
  avg_win                            0.0
  avg_loss                           -113.02
  max_dd_closed_pct                  9.04

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 4<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

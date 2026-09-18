# Candidate report - dtrend_ci45

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_ci45\preset.json
- Generated (UTC): 2026-09-02 10:08:35Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             22
  net                829.44
  return_pct         16.59
  pf                 1.87
  win_rate           59.09
  expectancy         37.70
  avg_win            136.76
  avg_loss           -105.38
  max_dd_closed_pct  12.17
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_ci45\windows\trend\report.htm

## Window: may_sep  (2026.05.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             4
  net                139.87
  return_pct         2.80
  pf                 1.92
  win_rate           50.00
  expectancy         34.97
  avg_win            146.16
  avg_loss           -76.23
  max_dd_closed_pct  2.88
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_ci45\windows\may_sep\report.htm

## Window: full  (2025.09.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             28
  net                761.41
  return_pct         15.23
  pf                 1.59
  win_rate           53.57
  expectancy         27.19
  avg_win            136.14
  avg_loss           -98.52
  max_dd_closed_pct  12.17
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_ci45\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             22
  net                                829.44
  return_pct                         16.59
  pf                                 1.87
  win_rate                           59.09
  expectancy                         37.7
  avg_win                            136.76
  avg_loss                           -105.38
  max_dd_closed_pct                  12.17

[OUT-OF-SAMPLE]
  trades                             4
  net                                139.87
  return_pct                         2.8
  pf                                 1.92
  win_rate                           50.0
  expectancy                         34.97
  avg_win                            146.16
  avg_loss                           -76.23
  max_dd_closed_pct                  2.88

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 4<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

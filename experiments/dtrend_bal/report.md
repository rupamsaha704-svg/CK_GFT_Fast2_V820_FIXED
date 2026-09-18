# Candidate report - dtrend_bal

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_bal\preset.json
- Generated (UTC): 2026-09-02 13:17:31Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             24
  net                4125.35
  return_pct         82.51
  pf                 5.19
  win_rate           62.50
  expectancy         171.89
  avg_win            340.71
  avg_loss           -109.48
  max_dd_closed_pct  6.18
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_bal\windows\trend\report.htm

## Window: may_sep  (2026.05.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             8
  net                -56.67
  return_pct         -1.13
  pf                 0.84
  win_rate           25.00
  expectancy         -7.08
  avg_win            146.16
  avg_loss           -58.16
  max_dd_closed_pct  3.91
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_bal\windows\may_sep\report.htm

## Window: full  (2025.09.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             39
  net                2766.07
  return_pct         55.32
  pf                 2.16
  win_rate           43.59
  expectancy         70.92
  avg_win            303.31
  avg_loss           -108.65
  max_dd_closed_pct  13.44
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_bal\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             24
  net                                4125.35
  return_pct                         82.51
  pf                                 5.19
  win_rate                           62.5
  expectancy                         171.89
  avg_win                            340.71
  avg_loss                           -109.48
  max_dd_closed_pct                  6.18

[OUT-OF-SAMPLE]
  trades                             8
  net                                -56.67
  return_pct                         -1.13
  pf                                 0.84
  win_rate                           25.0
  expectancy                         -7.08
  avg_win                            146.16
  avg_loss                           -58.16
  max_dd_closed_pct                  3.91

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 8<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

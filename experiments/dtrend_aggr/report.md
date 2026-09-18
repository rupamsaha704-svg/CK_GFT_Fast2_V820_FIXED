# Candidate report - dtrend_aggr

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_aggr\preset.json
- Generated (UTC): 2026-09-02 13:15:12Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             25
  net                5628.79
  return_pct         112.58
  pf                 5.39
  win_rate           60.00
  expectancy         225.15
  avg_win            460.77
  avg_loss           -128.27
  max_dd_closed_pct  5.94
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_aggr\windows\trend\report.htm

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
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_aggr\windows\may_sep\report.htm

## Window: full  (2025.09.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             40
  net                3708.73
  return_pct         74.17
  pf                 2.14
  win_rate           42.50
  expectancy         92.72
  avg_win            409.46
  avg_loss           -141.40
  max_dd_closed_pct  15.29
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_aggr\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             25
  net                                5628.79
  return_pct                         112.58
  pf                                 5.39
  win_rate                           60.0
  expectancy                         225.15
  avg_win                            460.77
  avg_loss                           -128.27
  max_dd_closed_pct                  5.94

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

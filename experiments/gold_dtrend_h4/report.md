# Candidate report - gold_dtrend_h4

- EA: CK_GOLD_DTREND
- Preset: experiments\gold_dtrend_h4\preset.json
- Generated (UTC): 2026-09-01 18:50:55Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: full  (2025.09.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             41
  net                18037.01
  return_pct         360.74
  pf                 1.91
  win_rate           46.34
  expectancy         439.93
  avg_win            1990.51
  avg_loss           -899.21
  max_dd_closed_pct  43.04
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend_h4\windows\full\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             2
  net                -431.79
  return_pct         -8.64
  pf                 0.00
  win_rate           0.00
  expectancy         -215.90
  avg_win            0.00
  avg_loss           -215.90
  max_dd_closed_pct  8.64
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend_h4\windows\chop\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             41
  net                                18037.01
  return_pct                         360.74
  pf                                 1.91
  win_rate                           46.34
  expectancy                         439.93
  avg_win                            1990.51
  avg_loss                           -899.21
  max_dd_closed_pct                  43.04

[OUT-OF-SAMPLE]
  trades                             2
  net                                -431.79
  return_pct                         -8.64
  pf                                 0.0
  win_rate                           0.0
  expectancy                         -215.9
  avg_win                            0.0
  avg_loss                           -215.9
  max_dd_closed_pct                  8.64

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 2<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - gold_dtrend

- EA: CK_GOLD_DTREND
- Preset: experiments\gold_dtrend\preset.json
- Generated (UTC): 2026-09-01 18:47:46Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: full  (2025.09.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             9
  net                3819.46
  return_pct         76.39
  pf                 3.60
  win_rate           55.56
  expectancy         424.38
  avg_win            1057.83
  avg_loss           -367.42
  max_dd_closed_pct  10.50
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend\windows\full\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             2
  net                -407.83
  return_pct         -8.16
  pf                 0.00
  win_rate           0.00
  expectancy         -203.92
  avg_win            0.00
  avg_loss           -203.92
  max_dd_closed_pct  8.16
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_dtrend\windows\chop\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             9
  net                                3819.46
  return_pct                         76.39
  pf                                 3.6
  win_rate                           55.56
  expectancy                         424.38
  avg_win                            1057.83
  avg_loss                           -367.42
  max_dd_closed_pct                  10.5

[OUT-OF-SAMPLE]
  trades                             2
  net                                -407.83
  return_pct                         -8.16
  pf                                 0.0
  win_rate                           0.0
  expectancy                         -203.92
  avg_win                            0.0
  avg_loss                           -203.92
  max_dd_closed_pct                  8.16

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 2<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

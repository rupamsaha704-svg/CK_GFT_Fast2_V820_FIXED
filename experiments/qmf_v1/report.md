# Candidate report - qmf_v1

- EA: CK_QM_ICT_FAITHFUL_v1
- Preset: experiments\qmf_v1\preset.json
- Generated (UTC): 2026-08-30 19:20:36Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             69
  net                3239.96
  return_pct         6.48
  pf                 2.15
  win_rate           18.84
  expectancy         46.96
  avg_win            466.38
  avg_loss           -50.41
  max_dd_closed_pct  1.92
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_v1\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             149
  net                -6407.01
  return_pct         -12.81
  pf                 0.53
  win_rate           8.72
  expectancy         -43.00
  avg_win            552.82
  avg_loss           -99.95
  max_dd_closed_pct  15.88
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_v1\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             61
  net                2525.93
  return_pct         5.05
  pf                 1.47
  win_rate           11.48
  expectancy         41.41
  avg_win            1134.39
  avg_loss           -100.27
  max_dd_closed_pct  6.78
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_v1\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             94
  net                -4410.89
  return_pct         -8.82
  pf                 0.48
  win_rate           9.57
  expectancy         -46.92
  avg_win            452.15
  avg_loss           -99.77
  max_dd_closed_pct  8.82
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_v1\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             69
  net                                3239.96
  return_pct                         6.48
  pf                                 2.15
  win_rate                           18.84
  expectancy                         46.96
  avg_win                            466.38
  avg_loss                           -50.41
  max_dd_closed_pct                  1.92

[OUT-OF-SAMPLE]
  trades                             149
  net                                -6407.01
  return_pct                         -12.81
  pf                                 0.53
  win_rate                           8.72
  expectancy                         -43.0
  avg_win                            552.82
  avg_loss                           -99.95
  max_dd_closed_pct                  15.88

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 149<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

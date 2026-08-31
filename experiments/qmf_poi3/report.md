# Candidate report - qmf_poi3

- EA: CK_QM_ICT_FAITHFUL_v1
- Preset: experiments\qmf_poi3\preset.json
- Generated (UTC): 2026-08-30 19:42:33Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             31
  net                2944.79
  return_pct         5.89
  pf                 3.06
  win_rate           22.58
  expectancy         94.99
  avg_win            624.79
  avg_loss           -59.53
  max_dd_closed_pct  1.54
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_poi3\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             60
  net                -747.24
  return_pct         -1.49
  pf                 0.83
  win_rate           11.67
  expectancy         -12.45
  avg_win            529.07
  avg_loss           -83.98
  max_dd_closed_pct  3.96
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_poi3\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             41
  net                -1274.46
  return_pct         -2.55
  pf                 0.57
  win_rate           12.20
  expectancy         -31.08
  avg_win            332.78
  avg_loss           -81.62
  max_dd_closed_pct  3.79
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_poi3\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             34
  net                343.34
  return_pct         0.69
  pf                 1.14
  win_rate           11.76
  expectancy         10.10
  avg_win            718.62
  avg_loss           -84.37
  max_dd_closed_pct  2.09
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_poi3\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             31
  net                                2944.79
  return_pct                         5.89
  pf                                 3.06
  win_rate                           22.58
  expectancy                         94.99
  avg_win                            624.79
  avg_loss                           -59.53
  max_dd_closed_pct                  1.54

[OUT-OF-SAMPLE]
  trades                             60
  net                                -747.24
  return_pct                         -1.49
  pf                                 0.83
  win_rate                           11.67
  expectancy                         -12.45
  avg_win                            529.07
  avg_loss                           -83.98
  max_dd_closed_pct                  3.96

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 60<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

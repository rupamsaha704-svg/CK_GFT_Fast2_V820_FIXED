# Candidate report - qmf_tp2

- EA: CK_QM_ICT_FAITHFUL_v1
- Preset: experiments\qmf_tp2\preset.json
- Generated (UTC): 2026-08-31 07:35:06Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             20
  net                -263.25
  return_pct         -0.53
  pf                 0.66
  win_rate           35.00
  expectancy         -13.16
  avg_win            72.37
  avg_loss           -59.22
  max_dd_closed_pct  1.16
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_tp2\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             38
  net                -1076.85
  return_pct         -2.15
  pf                 0.57
  win_rate           28.95
  expectancy         -28.34
  avg_win            128.36
  avg_loss           -92.18
  max_dd_closed_pct  2.96
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_tp2\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             22
  net                -941.85
  return_pct         -1.88
  pf                 0.34
  win_rate           22.73
  expectancy         -42.81
  avg_win            96.26
  avg_loss           -83.72
  max_dd_closed_pct  1.94
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_tp2\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             24
  net                -451.89
  return_pct         -0.90
  pf                 0.70
  win_rate           33.33
  expectancy         -18.83
  avg_win            132.40
  avg_loss           -94.44
  max_dd_closed_pct  1.43
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qmf_tp2\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             20
  net                                -263.25
  return_pct                         -0.53
  pf                                 0.66
  win_rate                           35.0
  expectancy                         -13.16
  avg_win                            72.37
  avg_loss                           -59.22
  max_dd_closed_pct                  1.16

[OUT-OF-SAMPLE]
  trades                             38
  net                                -1076.85
  return_pct                         -2.15
  pf                                 0.57
  win_rate                           28.95
  expectancy                         -28.34
  avg_win                            128.36
  avg_loss                           -92.18
  max_dd_closed_pct                  2.96

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 38<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

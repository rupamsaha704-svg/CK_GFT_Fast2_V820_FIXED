# Candidate report - qm_ict

- EA: CK_QM_ICT_EA
- Preset: experiments\qm_ict\preset.json
- Generated (UTC): 2026-08-30 17:57:46Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             29
  net                360.35
  return_pct         0.72
  pf                 1.22
  win_rate           48.28
  expectancy         12.43
  avg_win            141.16
  avg_loss           -107.73
  max_dd_closed_pct  1.68
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qm_ict\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             35
  net                -3325.01
  return_pct         -6.65
  pf                 0.50
  win_rate           37.14
  expectancy         -95.00
  avg_win            257.17
  avg_loss           -303.10
  max_dd_closed_pct  8.18
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qm_ict\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             21
  net                -2188.22
  return_pct         -4.38
  pf                 0.51
  win_rate           38.10
  expectancy         -104.20
  avg_win            288.42
  avg_loss           -345.81
  max_dd_closed_pct  5.90
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qm_ict\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             21
  net                -1744.29
  return_pct         -3.49
  pf                 0.44
  win_rate           28.57
  expectancy         -83.06
  avg_win            230.25
  avg_loss           -208.39
  max_dd_closed_pct  4.09
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qm_ict\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             29
  net                                360.35
  return_pct                         0.72
  pf                                 1.22
  win_rate                           48.28
  expectancy                         12.43
  avg_win                            141.16
  avg_loss                           -107.73
  max_dd_closed_pct                  1.68

[OUT-OF-SAMPLE]
  trades                             35
  net                                -3325.01
  return_pct                         -6.65
  pf                                 0.5
  win_rate                           37.14
  expectancy                         -95.0
  avg_win                            257.17
  avg_loss                           -303.1
  max_dd_closed_pct                  8.18

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 35<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

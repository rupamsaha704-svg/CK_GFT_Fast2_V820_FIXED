# Candidate report - qtcrt_v1

- EA: CK_QT_CRT_v1
- Preset: experiments\qtcrt_v1\preset.json
- Generated (UTC): 2026-08-31 12:41:05Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             96
  net                885.02
  return_pct         1.77
  pf                 1.24
  win_rate           40.62
  expectancy         9.22
  avg_win            116.02
  avg_loss           -63.86
  max_dd_closed_pct  2.20
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qtcrt_v1\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             155
  net                -3179.81
  return_pct         -6.36
  pf                 0.76
  win_rate           34.19
  expectancy         -20.51
  avg_win            186.98
  avg_loss           -128.33
  max_dd_closed_pct  7.61
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qtcrt_v1\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             85
  net                -676.67
  return_pct         -1.35
  pf                 0.90
  win_rate           41.18
  expectancy         -7.96
  avg_win            172.59
  avg_loss           -134.35
  max_dd_closed_pct  5.61
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qtcrt_v1\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             99
  net                -1573.32
  return_pct         -3.15
  pf                 0.80
  win_rate           32.32
  expectancy         -15.89
  avg_win            191.13
  avg_loss           -114.77
  max_dd_closed_pct  4.20
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qtcrt_v1\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             96
  net                                885.02
  return_pct                         1.77
  pf                                 1.24
  win_rate                           40.62
  expectancy                         9.22
  avg_win                            116.02
  avg_loss                           -63.86
  max_dd_closed_pct                  2.2

[OUT-OF-SAMPLE]
  trades                             155
  net                                -3179.81
  return_pct                         -6.36
  pf                                 0.76
  win_rate                           34.19
  expectancy                         -20.51
  avg_win                            186.98
  avg_loss                           -128.33
  max_dd_closed_pct                  7.61

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 155<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

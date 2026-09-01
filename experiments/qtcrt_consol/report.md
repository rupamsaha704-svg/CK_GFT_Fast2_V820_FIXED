# Candidate report - qtcrt_consol

- EA: CK_QT_CRT_v1
- Preset: experiments\qtcrt_consol\preset.json
- Generated (UTC): 2026-08-31 12:43:35Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             80
  net                -243.10
  return_pct         -0.49
  pf                 0.91
  win_rate           40.00
  expectancy         -3.04
  avg_win            81.57
  avg_loss           -59.45
  max_dd_closed_pct  1.05
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qtcrt_consol\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             106
  net                -1427.72
  return_pct         -2.86
  pf                 0.83
  win_rate           36.79
  expectancy         -13.47
  avg_win            173.41
  avg_loss           -122.25
  max_dd_closed_pct  4.44
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qtcrt_consol\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             65
  net                -1237.12
  return_pct         -2.47
  pf                 0.73
  win_rate           40.00
  expectancy         -19.03
  avg_win            128.55
  avg_loss           -117.42
  max_dd_closed_pct  2.97
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qtcrt_consol\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             68
  net                -272.87
  return_pct         -0.55
  pf                 0.94
  win_rate           36.76
  expectancy         -4.01
  avg_win            182.34
  avg_loss           -112.36
  max_dd_closed_pct  3.16
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\qtcrt_consol\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             80
  net                                -243.1
  return_pct                         -0.49
  pf                                 0.91
  win_rate                           40.0
  expectancy                         -3.04
  avg_win                            81.57
  avg_loss                           -59.45
  max_dd_closed_pct                  1.05

[OUT-OF-SAMPLE]
  trades                             106
  net                                -1427.72
  return_pct                         -2.86
  pf                                 0.83
  win_rate                           36.79
  expectancy                         -13.47
  avg_win                            173.41
  avg_loss                           -122.25
  max_dd_closed_pct                  4.44

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 106<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

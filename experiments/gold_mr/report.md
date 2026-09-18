# Candidate report - gold_mr

- EA: CK_GOLD_MR
- Preset: experiments\gold_mr\preset.json
- Generated (UTC): 2026-09-01 19:33:47Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: may  (2026.05.01 to 2026.06.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             34
  net                -112.07
  return_pct         -2.24
  pf                 0.86
  win_rate           44.12
  expectancy         -3.30
  avg_win            46.39
  avg_loss           -42.52
  max_dd_closed_pct  4.37
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_mr\windows\may\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             75
  net                -411.20
  return_pct         -8.22
  pf                 0.78
  win_rate           37.33
  expectancy         -5.48
  avg_win            51.26
  avg_loss           -39.29
  max_dd_closed_pct  10.63
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_mr\windows\chop\report.htm

## Window: trend  (2025.09.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             53
  net                -405.35
  return_pct         -8.11
  pf                 0.72
  win_rate           37.74
  expectancy         -7.65
  avg_win            52.23
  avg_loss           -43.94
  max_dd_closed_pct  12.27
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_mr\windows\trend\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             34
  net                                -112.07
  return_pct                         -2.24
  pf                                 0.86
  win_rate                           44.12
  expectancy                         -3.3
  avg_win                            46.39
  avg_loss                           -42.52
  max_dd_closed_pct                  4.37

[OUT-OF-SAMPLE]
  trades                             75
  net                                -411.2
  return_pct                         -8.22
  pf                                 0.78
  win_rate                           37.33
  expectancy                         -5.48
  avg_win                            51.26
  avg_loss                           -39.29
  max_dd_closed_pct                  10.63

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 75<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

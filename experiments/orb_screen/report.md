# Candidate report - orb_screen

- EA: CK_LDN_ORB
- Preset: experiments\orb_screen\preset.json
- Generated (UTC): 2026-09-05 15:23:25Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: is  (2025.09.02 to 2026.03.31)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             147
  net                -12.12
  return_pct         -0.24
  pf                 0.99
  win_rate           34.69
  expectancy         -0.08
  avg_win            29.89
  avg_loss           -16.01
  max_dd_closed_pct  10.72
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\orb_screen\windows\is\report.htm

## Window: oos  (2025.01.02 to 2025.08.31)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             169
  net                -42.03
  return_pct         -0.84
  pf                 0.94
  win_rate           30.77
  expectancy         -0.25
  avg_win            12.57
  avg_loss           -5.95
  max_dd_closed_pct  1.88
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\orb_screen\windows\oos\report.htm

## Window: is_h1  (2025.09.02 to 2025.12.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             74
  net                20.66
  return_pct         0.41
  pf                 1.04
  win_rate           35.14
  expectancy         0.28
  avg_win            21.29
  avg_loss           -11.10
  max_dd_closed_pct  4.08
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\orb_screen\windows\is_h1\report.htm

## Window: is_h2  (2025.12.15 to 2026.03.31)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             73
  net                -32.78
  return_pct         -0.66
  pf                 0.97
  win_rate           34.25
  expectancy         -0.45
  avg_win            38.84
  avg_loss           -20.91
  max_dd_closed_pct  7.50
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\orb_screen\windows\is_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             147
  net                                -12.12
  return_pct                         -0.24
  pf                                 0.99
  win_rate                           34.69
  expectancy                         -0.08
  avg_win                            29.89
  avg_loss                           -16.01
  max_dd_closed_pct                  10.72

[OUT-OF-SAMPLE]
  trades                             169
  net                                -42.03
  return_pct                         -0.84
  pf                                 0.94
  win_rate                           30.77
  expectancy                         -0.25
  avg_win                            12.57
  avg_loss                           -5.95
  max_dd_closed_pct                  1.88

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 169<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - chop_test

- EA: CK_GOLD_CHOP
- Preset: experiments\chop_test\preset.json
- Generated (UTC): 2026-09-02 09:50:00Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: may_sep  (2026.05.01 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             174
  net                -319.21
  return_pct         -6.38
  pf                 0.79
  win_rate           56.90
  expectancy         -1.83
  avg_win            12.07
  avg_loss           -20.19
  max_dd_closed_pct  8.58
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\chop_test\windows\may_sep\report.htm

## Window: aprsep  (2026.04.20 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             195
  net                -344.90
  return_pct         -6.90
  pf                 0.80
  win_rate           56.41
  expectancy         -1.77
  avg_win            12.48
  avg_loss           -20.21
  max_dd_closed_pct  8.34
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\chop_test\windows\aprsep\report.htm

## Window: chop2025  (2025.05.01 to 2025.09.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             233
  net                -386.13
  return_pct         -7.72
  pf                 0.80
  win_rate           60.52
  expectancy         -1.66
  avg_win            11.11
  avg_loss           -21.23
  max_dd_closed_pct  9.25
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\chop_test\windows\chop2025\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             174
  net                                -319.21
  return_pct                         -6.38
  pf                                 0.79
  win_rate                           56.9
  expectancy                         -1.83
  avg_win                            12.07
  avg_loss                           -20.19
  max_dd_closed_pct                  8.58

[OUT-OF-SAMPLE]
  trades                             195
  net                                -344.9
  return_pct                         -6.9
  pf                                 0.8
  win_rate                           56.41
  expectancy                         -1.77
  avg_win                            12.48
  avg_loss                           -20.21
  max_dd_closed_pct                  8.34

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 195<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

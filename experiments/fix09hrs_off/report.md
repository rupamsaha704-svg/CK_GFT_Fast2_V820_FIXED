# Candidate report - fix09hrs_off

- EA: CK_GOLD_PRO_FIX09_HRS
- Preset: experiments\fix09hrs_off\preset.json
- Generated (UTC): 2026-08-31 13:44:20Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: last1yr  (2025.08.28 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             291
  net                8740.25
  return_pct         174.81
  pf                 1.37
  win_rate           24.74
  expectancy         30.04
  avg_win            452.08
  avg_loss           -109.72
  max_dd_closed_pct  23.24
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_off\windows\last1yr\report.htm

## Window: older_trend  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             148
  net                11967.97
  return_pct         239.36
  pf                 2.23
  win_rate           30.41
  expectancy         80.86
  avg_win            482.03
  avg_loss           -95.33
  max_dd_closed_pct  9.70
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_off\windows\older_trend\report.htm

## Window: recent_regime  (2026.03.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             8
  net                -1661.23
  return_pct         -33.22
  pf                 0.29
  win_rate           25.00
  expectancy         -207.65
  avg_win            341.91
  avg_loss           -390.84
  max_dd_closed_pct  34.87
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_off\windows\recent_regime\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             291
  net                                8740.25
  return_pct                         174.81
  pf                                 1.37
  win_rate                           24.74
  expectancy                         30.04
  avg_win                            452.08
  avg_loss                           -109.72
  max_dd_closed_pct                  23.24

[OUT-OF-SAMPLE]
  trades                             148
  net                                11967.97
  return_pct                         239.36
  pf                                 2.23
  win_rate                           30.41
  expectancy                         80.86
  avg_win                            482.03
  avg_loss                           -95.33
  max_dd_closed_pct                  9.7

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 148<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

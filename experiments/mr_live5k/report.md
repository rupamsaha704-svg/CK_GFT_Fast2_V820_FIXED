# Candidate report - mr_live5k

- EA: CK_MR_StdDev_v1_T
- Preset: experiments\mr_live5k\preset.json
- Generated (UTC): 2026-08-31 15:31:50Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: last1yr  (2025.08.28 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             132
  net                -1593.50
  return_pct         -31.87
  pf                 0.86
  win_rate           43.18
  expectancy         -12.07
  avg_win            165.98
  avg_loss           -147.39
  max_dd_closed_pct  57.73
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\mr_live5k\windows\last1yr\report.htm

## Window: older_trend  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             84
  net                -1110.39
  return_pct         -22.21
  pf                 0.84
  win_rate           42.86
  expectancy         -13.22
  avg_win            156.17
  avg_loss           -140.26
  max_dd_closed_pct  39.51
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\mr_live5k\windows\older_trend\report.htm

## Window: recent_regime  (2026.03.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             66
  net                -1106.35
  return_pct         -22.13
  pf                 0.84
  win_rate           42.42
  expectancy         -16.76
  avg_win            200.03
  avg_loss           -176.51
  max_dd_closed_pct  33.29
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\mr_live5k\windows\recent_regime\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             132
  net                                -1593.5
  return_pct                         -31.87
  pf                                 0.86
  win_rate                           43.18
  expectancy                         -12.07
  avg_win                            165.98
  avg_loss                           -147.39
  max_dd_closed_pct                  57.73

[OUT-OF-SAMPLE]
  trades                             84
  net                                -1110.39
  return_pct                         -22.21
  pf                                 0.84
  win_rate                           42.86
  expectancy                         -13.22
  avg_win                            156.17
  avg_loss                           -140.26
  max_dd_closed_pct                  39.51

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 84<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

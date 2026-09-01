# Candidate report - fix09hrs_50k_off

- EA: CK_GOLD_PRO_FIX09_HRS
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_50k_off\preset.json
- Generated (UTC): 2026-08-31 13:51:20Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: older_trend  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             154
  net                13043.52
  return_pct         26.09
  pf                 2.22
  win_rate           30.52
  expectancy         84.70
  avg_win            504.66
  avg_loss           -100.71
  max_dd_closed_pct  3.15
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_50k_off\windows\older_trend\report.htm

## Window: recent_regime  (2026.03.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             144
  net                -4605.44
  return_pct         -9.21
  pf                 0.69
  win_rate           18.75
  expectancy         -31.98
  avg_win            374.09
  avg_loss           -126.77
  max_dd_closed_pct  9.52
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_50k_off\windows\recent_regime\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             154
  net                                13043.52
  return_pct                         26.09
  pf                                 2.22
  win_rate                           30.52
  expectancy                         84.7
  avg_win                            504.66
  avg_loss                           -100.71
  max_dd_closed_pct                  3.15

[OUT-OF-SAMPLE]
  trades                             144
  net                                -4605.44
  return_pct                         -9.21
  pf                                 0.69
  win_rate                           18.75
  expectancy                         -31.98
  avg_win                            374.09
  avg_loss                           -126.77
  max_dd_closed_pct                  9.52

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 144<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

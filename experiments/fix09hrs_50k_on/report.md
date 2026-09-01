# Candidate report - fix09hrs_50k_on

- EA: CK_GOLD_PRO_FIX09_HRS
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_50k_on\preset.json
- Generated (UTC): 2026-08-31 13:52:06Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: older_trend  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             132
  net                11919.29
  return_pct         23.84
  pf                 2.33
  win_rate           29.55
  expectancy         90.30
  avg_win            535.62
  avg_loss           -97.50
  max_dd_closed_pct  3.25
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_50k_on\windows\older_trend\report.htm

## Window: recent_regime  (2026.03.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             114
  net                -5044.65
  return_pct         -10.09
  pf                 0.58
  win_rate           17.54
  expectancy         -44.25
  avg_win            354.69
  avg_loss           -129.13
  max_dd_closed_pct  10.09
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09hrs_50k_on\windows\recent_regime\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             132
  net                                11919.29
  return_pct                         23.84
  pf                                 2.33
  win_rate                           29.55
  expectancy                         90.3
  avg_win                            535.62
  avg_loss                           -97.5
  max_dd_closed_pct                  3.25

[OUT-OF-SAMPLE]
  trades                             114
  net                                -5044.65
  return_pct                         -10.09
  pf                                 0.58
  win_rate                           17.54
  expectancy                         -44.25
  avg_win                            354.69
  avg_loss                           -129.13
  max_dd_closed_pct                  10.09

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 114<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

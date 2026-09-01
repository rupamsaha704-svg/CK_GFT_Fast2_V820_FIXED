# Candidate report - fix09_live5k

- EA: CK_GOLD_PRO_FIX09
- Preset: experiments\fix09_live5k\preset.json
- Generated (UTC): 2026-08-31 13:36:05Z
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
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_live5k\windows\last1yr\report.htm

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

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

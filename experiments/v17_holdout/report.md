# Candidate report - v17_holdout

- EA: CK_GFT_Fast_v17_T
- Preset: experiments\v17_holdout\preset.json
- Generated (UTC): 2026-08-31 16:37:21Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             111
  net                -391.27
  return_pct         -7.83
  pf                 0.75
  win_rate           60.36
  expectancy         -3.52
  avg_win            17.67
  avg_loss           -35.80
  max_dd_closed_pct  12.52
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\v17_holdout\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             111
  net                                -391.27
  return_pct                         -7.83
  pf                                 0.75
  win_rate                           60.36
  expectancy                         -3.52
  avg_win                            17.67
  avg_loss                           -35.8
  max_dd_closed_pct                  12.52

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - turtle_holdout

- EA: CK_TURTLE_SOUP_v1
- Preset: experiments\turtle_holdout\preset.json
- Generated (UTC): 2026-08-31 17:29:21Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             39
  net                -1629.37
  return_pct         -32.59
  pf                 0.33
  win_rate           17.95
  expectancy         -41.78
  avg_win            115.10
  avg_loss           -76.10
  max_dd_closed_pct  33.20
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_holdout\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             39
  net                                -1629.37
  return_pct                         -32.59
  pf                                 0.33
  win_rate                           17.95
  expectancy                         -41.78
  avg_win                            115.1
  avg_loss                           -76.1
  max_dd_closed_pct                  33.2

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

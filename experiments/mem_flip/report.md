# Candidate report - mem_flip

- EA: CK_GOLD_MEM
- Preset: experiments\mem_flip\preset.json
- Generated (UTC): 2026-09-02 08:36:53Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: aprsep  (2026.04.20 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             153
  net                -147.41
  return_pct         -2.95
  pf                 0.91
  win_rate           42.48
  expectancy         -0.96
  avg_win            22.33
  avg_loss           -18.17
  max_dd_closed_pct  8.20
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\mem_flip\windows\aprsep\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             153
  net                                -147.41
  return_pct                         -2.95
  pf                                 0.91
  win_rate                           42.48
  expectancy                         -0.96
  avg_win                            22.33
  avg_loss                           -18.17
  max_dd_closed_pct                  8.2

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

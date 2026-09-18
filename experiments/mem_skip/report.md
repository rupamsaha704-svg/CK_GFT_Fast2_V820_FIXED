# Candidate report - mem_skip

- EA: CK_GOLD_MEM
- Preset: experiments\mem_skip\preset.json
- Generated (UTC): 2026-09-02 08:36:40Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: aprsep  (2026.04.20 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             140
  net                -148.97
  return_pct         -2.98
  pf                 0.90
  win_rate           42.86
  expectancy         -1.06
  avg_win            21.90
  avg_loss           -18.29
  max_dd_closed_pct  6.93
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\mem_skip\windows\aprsep\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             140
  net                                -148.97
  return_pct                         -2.98
  pf                                 0.9
  win_rate                           42.86
  expectancy                         -1.06
  avg_win                            21.9
  avg_loss                           -18.29
  max_dd_closed_pct                  6.93

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

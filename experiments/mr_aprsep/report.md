# Candidate report - mr_aprsep

- EA: CK_GOLD_MR
- Preset: experiments\mr_aprsep\preset.json
- Generated (UTC): 2026-09-02 08:26:29Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: aprsep  (2026.04.20 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             152
  net                -162.43
  return_pct         -3.25
  pf                 0.90
  win_rate           42.76
  expectancy         -1.07
  avg_win            22.14
  avg_loss           -18.41
  max_dd_closed_pct  5.59
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\mr_aprsep\windows\aprsep\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             152
  net                                -162.43
  return_pct                         -3.25
  pf                                 0.9
  win_rate                           42.76
  expectancy                         -1.07
  avg_win                            22.14
  avg_loss                           -18.41
  max_dd_closed_pct                  5.59

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

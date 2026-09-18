# Candidate report - mem_wide

- EA: CK_GOLD_MEM
- Preset: experiments\mem_wide\preset.json
- Generated (UTC): 2026-09-02 08:38:45Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: aprsep  (2026.04.20 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             113
  net                -101.40
  return_pct         -2.03
  pf                 0.91
  win_rate           43.36
  expectancy         -0.90
  avg_win            21.33
  avg_loss           -17.92
  max_dd_closed_pct  4.83
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\mem_wide\windows\aprsep\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             113
  net                                -101.4
  return_pct                         -2.03
  pf                                 0.91
  win_rate                           43.36
  expectancy                         -0.9
  avg_win                            21.33
  avg_loss                           -17.92
  max_dd_closed_pct                  4.83

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - ictchoch_strict

- EA: CK_XAU_ICT_ChoCh_V3
- Preset: experiments\ictchoch_strict\preset.json
- Generated (UTC): 2026-09-01 10:25:27Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: full_cr  (2025.10.01 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             12
  net                0.15
  return_pct         0.00
  pf                 1.00
  win_rate           41.67
  expectancy         0.01
  avg_win            58.33
  avg_loss           -41.64
  max_dd_closed_pct  4.86
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\ictchoch_strict\windows\full_cr\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             12
  net                                0.15
  return_pct                         0.0
  pf                                 1.0
  win_rate                           41.67
  expectancy                         0.01
  avg_win                            58.33
  avg_loss                           -41.64
  max_dd_closed_pct                  4.86

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - ictchoch_relaxed

- EA: CK_XAU_ICT_ChoCh_V3
- Preset: experiments\ictchoch_relaxed\preset.json
- Generated (UTC): 2026-09-01 10:23:53Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: full_cr  (2025.10.01 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             25
  net                -211.48
  return_pct         -4.23
  pf                 0.72
  win_rate           32.00
  expectancy         -8.46
  avg_win            66.90
  avg_loss           -43.92
  max_dd_closed_pct  7.67
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\ictchoch_relaxed\windows\full_cr\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             25
  net                                -211.48
  return_pct                         -4.23
  pf                                 0.72
  win_rate                           32.0
  expectancy                         -8.46
  avg_win                            66.9
  avg_loss                           -43.92
  max_dd_closed_pct                  7.67

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

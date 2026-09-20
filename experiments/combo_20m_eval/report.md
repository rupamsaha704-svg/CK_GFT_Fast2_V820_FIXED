# Candidate report - combo_20m_eval

- EA: CK_GOLD_COMBO
- Preset: experiments\combo_20m_eval\preset.json
- Generated (UTC): 2026-09-03 12:32:45Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: m20  (2025.01.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             520
  net                10535583448.00
  return_pct         210711668.96
  pf                 inf
  win_rate           100.00
  expectancy         20260737.40
  avg_win            20260737.40
  avg_loss           0.00
  max_dd_closed_pct  0.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\combo_20m_eval\windows\m20\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             520
  net                                10535583448.0
  return_pct                         210711668.96
  pf                                 inf
  win_rate                           100.0
  expectancy                         20260737.4
  avg_win                            20260737.4
  avg_loss                           0.0
  max_dd_closed_pct                  0.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

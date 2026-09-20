# Candidate report - combo_20m_funded

- EA: CK_GOLD_COMBO
- Preset: experiments\combo_20m_funded\preset.json
- Generated (UTC): 2026-09-03 12:33:16Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: m20  (2025.01.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             481
  net                9745408034.00
  return_pct         194908160.68
  pf                 inf
  win_rate           100.00
  expectancy         20260723.56
  avg_win            20260723.56
  avg_loss           0.00
  max_dd_closed_pct  0.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\combo_20m_funded\windows\m20\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             481
  net                                9745408034.0
  return_pct                         194908160.68
  pf                                 inf
  win_rate                           100.0
  expectancy                         20260723.56
  avg_win                            20260723.56
  avg_loss                           0.0
  max_dd_closed_pct                  0.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - combo_funded_old

- EA: CK_GOLD_COMBO
- Preset: experiments\combo_funded_old\preset.json
- Generated (UTC): 2026-09-03 11:39:20Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: old2025h1  (2025.01.02 to 2025.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             210
  net                4254755068.00
  return_pct         85095101.36
  pf                 inf
  win_rate           100.00
  expectancy         20260738.42
  avg_win            20260738.42
  avg_loss           0.00
  max_dd_closed_pct  0.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\combo_funded_old\windows\old2025h1\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             210
  net                                4254755068.0
  return_pct                         85095101.36
  pf                                 inf
  win_rate                           100.0
  expectancy                         20260738.42
  avg_win                            20260738.42
  avg_loss                           0.0
  max_dd_closed_pct                  0.0

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

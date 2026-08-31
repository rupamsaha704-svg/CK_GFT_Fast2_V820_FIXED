# Candidate report - fix09_lev100

- EA: CK_GOLD_PRO_FIX09
- Preset: experiments\fix09_lev100\preset.json
- Generated (UTC): 2026-08-30 16:44:44Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: baseline_lev100  (2025.06.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             359
  net                8213.87
  return_pct         164.28
  pf                 1.32
  win_rate           23.12
  expectancy         22.88
  avg_win            412.88
  avg_loss           -95.79
  max_dd_closed_pct  23.94
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_lev100\windows\baseline_lev100\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             359
  net                                8213.87
  return_pct                         164.28
  pf                                 1.32
  win_rate                           23.12
  expectancy                         22.88
  avg_win                            412.88
  avg_loss                           -95.79
  max_dd_closed_pct                  23.94

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

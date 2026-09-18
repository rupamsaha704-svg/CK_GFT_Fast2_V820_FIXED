# Candidate report - gold_r1_off

- EA: CK_GOLD_TREND_R1
- Preset: experiments\gold_r1_off\preset.json
- Generated (UTC): 2026-09-01 17:55:49Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: full  (2025.09.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             290
  net                8827.24
  return_pct         176.54
  pf                 1.40
  win_rate           24.83
  expectancy         30.44
  avg_win            432.32
  avg_loss           -127.43
  max_dd_closed_pct  19.30
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_r1_off\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             290
  net                                8827.24
  return_pct                         176.54
  pf                                 1.4
  win_rate                           24.83
  expectancy                         30.44
  avg_win                            432.32
  avg_loss                           -127.43
  max_dd_closed_pct                  19.3

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

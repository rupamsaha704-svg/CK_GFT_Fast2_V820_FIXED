# Candidate report - gold_r1_on

- EA: CK_GOLD_TREND_R1
- Preset: experiments\gold_r1_on\preset.json
- Generated (UTC): 2026-09-01 17:56:02Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: full  (2025.09.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             151
  net                1642.20
  return_pct         32.84
  pf                 1.14
  win_rate           23.84
  expectancy         10.88
  avg_win            374.35
  avg_loss           -131.49
  max_dd_closed_pct  31.28
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_r1_on\windows\full\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             151
  net                                1642.2
  return_pct                         32.84
  pf                                 1.14
  win_rate                           23.84
  expectancy                         10.88
  avg_win                            374.35
  avg_loss                           -131.49
  max_dd_closed_pct                  31.28

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

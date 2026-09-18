# Candidate report - fix09_1y

- EA: CK_GOLD_PRO_FIX09
- Preset: experiments\fix09_1y\preset.json
- Generated (UTC): 2026-09-02 13:58:56Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: last1y  (2025.09.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             293
  net                9996.38
  return_pct         199.93
  pf                 1.45
  win_rate           25.60
  expectancy         34.12
  avg_win            431.34
  avg_loss           -127.74
  max_dd_closed_pct  18.70
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_1y\windows\last1y\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             293
  net                                9996.38
  return_pct                         199.93
  pf                                 1.45
  win_rate                           25.6
  expectancy                         34.12
  avg_win                            431.34
  avg_loss                           -127.74
  max_dd_closed_pct                  18.7

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

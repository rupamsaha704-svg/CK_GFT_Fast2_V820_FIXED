# Candidate report - dtrend_bal_m4

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_bal_m4\preset.json
- Generated (UTC): 2026-09-02 13:21:12Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: last1y_m4  (2025.09.02 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             39
  net                2642.33
  return_pct         52.85
  pf                 2.10
  win_rate           43.59
  expectancy         67.75
  avg_win            296.10
  avg_loss           -108.70
  max_dd_closed_pct  13.32
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_bal_m4\windows\last1y_m4\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             39
  net                                2642.33
  return_pct                         52.85
  pf                                 2.1
  win_rate                           43.59
  expectancy                         67.75
  avg_win                            296.1
  avg_loss                           -108.7
  max_dd_closed_pct                  13.32

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - dtrend_all

- EA: CK_GOLD_DTREND
- Preset: experiments\dtrend_all\preset.json
- Generated (UTC): 2026-09-02 09:35:14Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: all_20mo  (2025.01.15 to 2026.09.02)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             68
  net                1214.79
  return_pct         24.30
  pf                 1.47
  win_rate           44.12
  expectancy         17.86
  avg_win            127.16
  avg_loss           -68.42
  max_dd_closed_pct  13.80
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\dtrend_all\windows\all_20mo\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             68
  net                                1214.79
  return_pct                         24.3
  pf                                 1.47
  win_rate                           44.12
  expectancy                         17.86
  avg_win                            127.16
  avg_loss                           -68.42
  max_dd_closed_pct                  13.8

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

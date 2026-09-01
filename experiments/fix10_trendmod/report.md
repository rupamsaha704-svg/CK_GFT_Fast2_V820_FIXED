# Candidate report - fix10_trendmod

- EA: CK_GOLD_PRO_FIX10_regime
- Preset: experiments\fix10_trendmod\preset.json
- Generated (UTC): 2026-08-31 16:34:02Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: build  (2025.08.28 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             163
  net                2100.89
  return_pct         42.02
  pf                 1.15
  win_rate           25.15
  expectancy         12.89
  avg_win            382.58
  avg_loss           -112.27
  max_dd_closed_pct  41.61
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix10_trendmod\windows\build\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             163
  net                                2100.89
  return_pct                         42.02
  pf                                 1.15
  win_rate                           25.15
  expectancy                         12.89
  avg_win                            382.58
  avg_loss                           -112.27
  max_dd_closed_pct                  41.61

================================================================
VERDICT: INSUFFICIENT
================================================================
  - no OOS provided
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - sweep_turtle_USDJPY

- EA: CK_TURTLE_SOUP_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDJPY\preset.json
- Generated (UTC): 2026-08-31 19:45:23Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             389
  net                -226.36
  return_pct         -4.53
  pf                 0.84
  win_rate           29.82
  expectancy         -0.58
  avg_win            10.34
  avg_loss           -5.22
  max_dd_closed_pct  5.13
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDJPY\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             256
  net                -12.65
  return_pct         -0.25
  pf                 0.98
  win_rate           32.42
  expectancy         -0.05
  avg_win            7.08
  avg_loss           -3.47
  max_dd_closed_pct  1.79
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDJPY\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             118
  net                -36.49
  return_pct         -0.73
  pf                 0.88
  win_rate           28.81
  expectancy         -0.31
  avg_win            7.79
  avg_loss           -3.59
  max_dd_closed_pct  1.36
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDJPY\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             389
  net                                -226.36
  return_pct                         -4.53
  pf                                 0.84
  win_rate                           29.82
  expectancy                         -0.58
  avg_win                            10.34
  avg_loss                           -5.22
  max_dd_closed_pct                  5.13

[OUT-OF-SAMPLE]
  trades                             256
  net                                -12.65
  return_pct                         -0.25
  pf                                 0.98
  win_rate                           32.42
  expectancy                         -0.05
  avg_win                            7.08
  avg_loss                           -3.47
  max_dd_closed_pct                  1.79

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.98 exp -0.05
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.98  exp95CI [-0.80,0.70]
  M5 concentration (drop top10)      exp -0.70  PF 0.71
  M6 trade-removal 10% (>=95%net+)   34.3% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2026]
  MC (advisory)                      DD p95 4%  P(losing) 56%  net p5 -172
  WF (>=60%, med>=1.10, >=8win)      4/8 pos, med 1.10, worst 0.28, small-win 2
  M4 cost stress                     PENDING (supply --cost-per-trade, pre-declared)
  M7 benchmark                       PENDING (supply --price-csv for the OOS period)
  K5 locked holdout                  PENDING (sealed; supply --holdout once, single unlock)

================================================================
VERDICT: REJECT
================================================================
  - K2: no OOS edge
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest); M4 cost/slippage stress (supply baseline cost); M7 benchmark suite (supply OOS price); K5 locked holdout; M3 parameter plateau (MT5 grid)

  (deterministic: same input => same output; no LLM in this path)
```

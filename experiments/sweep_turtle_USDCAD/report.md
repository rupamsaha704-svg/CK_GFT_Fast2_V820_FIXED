# Candidate report - sweep_turtle_USDCAD

- EA: CK_TURTLE_SOUP_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCAD\preset.json
- Generated (UTC): 2026-08-31 19:43:28Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             380
  net                67.63
  return_pct         1.35
  pf                 1.10
  win_rate           32.63
  expectancy         0.18
  avg_win            6.02
  avg_loss           -2.65
  max_dd_closed_pct  1.00
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCAD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             261
  net                -137.58
  return_pct         -2.75
  pf                 0.71
  win_rate           26.82
  expectancy         -0.53
  avg_win            4.79
  avg_loss           -2.47
  max_dd_closed_pct  3.02
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCAD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             126
  net                -114.31
  return_pct         -2.29
  pf                 0.53
  win_rate           24.60
  expectancy         -0.91
  avg_win            4.23
  avg_loss           -2.58
  max_dd_closed_pct  2.40
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCAD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             380
  net                                67.63
  return_pct                         1.35
  pf                                 1.1
  win_rate                           32.63
  expectancy                         0.18
  avg_win                            6.02
  avg_loss                           -2.65
  max_dd_closed_pct                  1.0

[OUT-OF-SAMPLE]
  trades                             261
  net                                -137.58
  return_pct                         -2.75
  pf                                 0.71
  win_rate                           26.82
  expectancy                         -0.53
  avg_win                            4.79
  avg_loss                           -2.47
  max_dd_closed_pct                  3.02

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.71 exp -0.53
  K3 IS->OOS collapse                PFratio 0.64 EXPratio -2.96
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.71  exp95CI [-1.00,-0.03]
  M5 concentration (drop top10)      exp -0.99  PF 0.47
  M6 trade-removal 10% (>=95%net+)   0.0% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2026]
  MC (advisory)                      DD p95 5%  P(losing) 98%  net p5 -243
  WF (>=60%, med>=1.10, >=8win)      1/8 pos, med 0.84, worst 0.26, small-win 0
  M4 cost stress                     PENDING (supply --cost-per-trade, pre-declared)
  M7 benchmark                       PENDING (supply --price-csv for the OOS period)
  K5 locked holdout                  PENDING (sealed; supply --holdout once, single unlock)

================================================================
VERDICT: REJECT
================================================================
  - K2: no OOS edge
  - K3: severe IS->OOS collapse (overfit)
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest); M4 cost/slippage stress (supply baseline cost); M7 benchmark suite (supply OOS price); K5 locked holdout; M3 parameter plateau (MT5 grid)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - sweep_turtle_USDCHF

- EA: CK_TURTLE_SOUP_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCHF\preset.json
- Generated (UTC): 2026-08-31 19:44:06Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             388
  net                -449.21
  return_pct         -8.98
  pf                 0.66
  win_rate           20.62
  expectancy         -1.16
  avg_win            11.08
  avg_loss           -4.34
  max_dd_closed_pct  10.14
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCHF\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             261
  net                -294.11
  return_pct         -5.88
  pf                 0.61
  win_rate           24.52
  expectancy         -1.13
  avg_win            7.28
  avg_loss           -3.86
  max_dd_closed_pct  5.88
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCHF\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             122
  net                31.02
  return_pct         0.62
  pf                 1.09
  win_rate           27.05
  expectancy         0.25
  avg_win            11.68
  avg_loss           -3.98
  max_dd_closed_pct  1.22
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_USDCHF\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             388
  net                                -449.21
  return_pct                         -8.98
  pf                                 0.66
  win_rate                           20.62
  expectancy                         -1.16
  avg_win                            11.08
  avg_loss                           -4.34
  max_dd_closed_pct                  10.14

[OUT-OF-SAMPLE]
  trades                             261
  net                                -294.11
  return_pct                         -5.88
  pf                                 0.61
  win_rate                           24.52
  expectancy                         -1.13
  avg_win                            7.28
  avg_loss                           -3.86
  max_dd_closed_pct                  5.88

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.61 exp -1.13
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.61  exp95CI [-1.79,-0.44]
  M5 concentration (drop top10)      exp -1.74  PF 0.43
  M6 trade-removal 10% (>=95%net+)   0.0% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2026]
  MC (advisory)                      DD p95 9%  P(losing) 100%  net p5 -441
  WF (>=60%, med>=1.10, >=8win)      0/8 pos, med 0.61, worst 0.44, small-win 0
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

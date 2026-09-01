# Candidate report - sweep_turtle_AUDUSD

- EA: CK_TURTLE_SOUP_v1
- Preset: experiments\sweep_turtle_AUDUSD\preset.json
- Generated (UTC): 2026-08-31 19:29:01Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             389
  net                -400.90
  return_pct         -8.02
  pf                 0.66
  win_rate           22.37
  expectancy         -1.03
  avg_win            8.90
  avg_loss           -3.89
  max_dd_closed_pct  8.83
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_AUDUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             260
  net                -241.54
  return_pct         -4.83
  pf                 0.72
  win_rate           27.69
  expectancy         -0.93
  avg_win            8.55
  avg_loss           -4.56
  max_dd_closed_pct  4.83
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_AUDUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             125
  net                -35.20
  return_pct         -0.70
  pf                 0.87
  win_rate           29.60
  expectancy         -0.28
  avg_win            6.60
  avg_loss           -3.18
  max_dd_closed_pct  1.90
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_AUDUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             389
  net                                -400.9
  return_pct                         -8.02
  pf                                 0.66
  win_rate                           22.37
  expectancy                         -1.03
  avg_win                            8.9
  avg_loss                           -3.89
  max_dd_closed_pct                  8.83

[OUT-OF-SAMPLE]
  trades                             260
  net                                -241.54
  return_pct                         -4.83
  pf                                 0.72
  win_rate                           27.69
  expectancy                         -0.93
  avg_win                            8.55
  avg_loss                           -4.56
  max_dd_closed_pct                  4.83

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.72 exp -0.93
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.72  exp95CI [-1.79,-0.07]
  M5 concentration (drop top10)      exp -1.71  PF 0.50
  M6 trade-removal 10% (>=95%net+)   0.0% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2026]
  MC (advisory)                      DD p95 9%  P(losing) 98%  net p5 -428
  WF (>=60%, med>=1.10, >=8win)      2/8 pos, med 0.74, worst 0.36, small-win 1
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

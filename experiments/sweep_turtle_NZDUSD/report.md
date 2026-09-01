# Candidate report - sweep_turtle_NZDUSD

- EA: CK_TURTLE_SOUP_v1
- Preset: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_NZDUSD\preset.json
- Generated (UTC): 2026-08-31 19:42:49Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             385
  net                -429.36
  return_pct         -8.59
  pf                 0.63
  win_rate           21.82
  expectancy         -1.12
  avg_win            8.83
  avg_loss           -3.89
  max_dd_closed_pct  9.16
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_NZDUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             260
  net                -166.70
  return_pct         -3.33
  pf                 0.78
  win_rate           26.92
  expectancy         -0.64
  avg_win            8.29
  avg_loss           -3.93
  max_dd_closed_pct  4.68
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_NZDUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             121
  net                21.95
  return_pct         0.44
  pf                 1.08
  win_rate           34.71
  expectancy         0.18
  avg_win            6.96
  avg_loss           -3.42
  max_dd_closed_pct  1.08
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\sweep_turtle_NZDUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             385
  net                                -429.36
  return_pct                         -8.59
  pf                                 0.63
  win_rate                           21.82
  expectancy                         -1.12
  avg_win                            8.83
  avg_loss                           -3.89
  max_dd_closed_pct                  9.16

[OUT-OF-SAMPLE]
  trades                             260
  net                                -166.7
  return_pct                         -3.33
  pf                                 0.78
  win_rate                           26.92
  expectancy                         -0.64
  avg_win                            8.29
  avg_loss                           -3.93
  max_dd_closed_pct                  4.68

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.78 exp -0.64
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.78  exp95CI [-1.42,0.15]
  M5 concentration (drop top10)      exp -1.44  PF 0.52
  M6 trade-removal 10% (>=95%net+)   0.0% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2026]
  MC (advisory)                      DD p95 7%  P(losing) 94%  net p5 -338
  WF (>=60%, med>=1.10, >=8win)      2/8 pos, med 0.88, worst 0.34, small-win 0
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

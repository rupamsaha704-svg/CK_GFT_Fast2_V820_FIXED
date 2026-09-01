# Candidate report - turtle_GBPUSD

- EA: CK_TURTLE_SOUP_v1
- Preset: experiments\turtle_GBPUSD\preset.json
- Generated (UTC): 2026-08-31 17:53:07Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             389
  net                -342.99
  return_pct         -6.86
  pf                 0.76
  win_rate           26.48
  expectancy         -0.88
  avg_win            10.46
  avg_loss           -4.97
  max_dd_closed_pct  7.69
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_GBPUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             260
  net                -59.85
  return_pct         -1.20
  pf                 0.93
  win_rate           33.46
  expectancy         -0.23
  avg_win            9.77
  avg_loss           -5.26
  max_dd_closed_pct  2.90
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_GBPUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             126
  net                76.50
  return_pct         1.53
  pf                 1.24
  win_rate           34.92
  expectancy         0.61
  avg_win            8.98
  avg_loss           -3.88
  max_dd_closed_pct  1.02
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_GBPUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             389
  net                                -342.99
  return_pct                         -6.86
  pf                                 0.76
  win_rate                           26.48
  expectancy                         -0.88
  avg_win                            10.46
  avg_loss                           -4.97
  max_dd_closed_pct                  7.69

[OUT-OF-SAMPLE]
  trades                             260
  net                                -59.85
  return_pct                         -1.2
  pf                                 0.93
  win_rate                           33.46
  expectancy                         -0.23
  avg_win                            9.77
  avg_loss                           -5.26
  max_dd_closed_pct                  2.9

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.93 exp -0.23
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.93  exp95CI [-1.28,0.84]
  M5 concentration (drop top10)      exp -1.28  PF 0.65
  M6 trade-removal 10% (>=95%net+)   8.8% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2026]
  MC (advisory)                      DD p95 7%  P(losing) 68%  net p5 -289
  WF (>=60%, med>=1.10, >=8win)      2/8 pos, med 0.93, worst 0.59, small-win 1
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

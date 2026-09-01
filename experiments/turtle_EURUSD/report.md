# Candidate report - turtle_EURUSD

- EA: CK_TURTLE_SOUP_v1
- Preset: experiments\turtle_EURUSD\preset.json
- Generated (UTC): 2026-08-31 17:52:23Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_build  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             389
  net                -364.89
  return_pct         -7.30
  pf                 0.69
  win_rate           23.65
  expectancy         -0.94
  avg_win            8.75
  avg_loss           -3.94
  max_dd_closed_pct  7.61
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_EURUSD\windows\IS_build\report.htm

## Window: OOS_build  (2026.03.01 to 2026.07.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             260
  net                -235.35
  return_pct         -4.71
  pf                 0.70
  win_rate           28.46
  expectancy         -0.91
  avg_win            7.33
  avg_loss           -4.18
  max_dd_closed_pct  5.22
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_EURUSD\windows\OOS_build\report.htm

## Window: holdout  (2026.07.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             126
  net                30.51
  return_pct         0.61
  pf                 1.13
  win_rate           38.10
  expectancy         0.24
  avg_win            5.59
  avg_loss           -3.05
  max_dd_closed_pct  0.84
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\turtle_EURUSD\windows\holdout\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             389
  net                                -364.89
  return_pct                         -7.3
  pf                                 0.69
  win_rate                           23.65
  expectancy                         -0.94
  avg_win                            8.75
  avg_loss                           -3.94
  max_dd_closed_pct                  7.61

[OUT-OF-SAMPLE]
  trades                             260
  net                                -235.35
  return_pct                         -4.71
  pf                                 0.7
  win_rate                           28.46
  expectancy                         -0.91
  avg_win                            7.33
  avg_loss                           -4.18
  max_dd_closed_pct                  5.22

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.70 exp -0.91
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.70  exp95CI [-1.64,-0.14]
  M5 concentration (drop top10)      exp -1.56  PF 0.50
  M6 trade-removal 10% (>=95%net+)   0.0% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2026]
  MC (advisory)                      DD p95 8%  P(losing) 99%  net p5 -397
  WF (>=60%, med>=1.10, >=8win)      1/8 pos, med 0.79, worst 0.36, small-win 1
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

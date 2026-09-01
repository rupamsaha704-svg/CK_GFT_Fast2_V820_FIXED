# Candidate report - v17_live5k

- EA: CK_GFT_Fast_v17_T
- Preset: experiments\v17_live5k\preset.json
- Generated (UTC): 2026-08-31 14:22:09Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: last1yr  (2025.08.28 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             951
  net                5807.73
  return_pct         116.15
  pf                 1.49
  win_rate           66.25
  expectancy         6.11
  avg_win            28.02
  avg_loss           -37.97
  max_dd_closed_pct  9.21
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\v17_live5k\windows\last1yr\report.htm

## Window: older_trend  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             430
  net                3097.44
  return_pct         61.95
  pf                 1.67
  win_rate           67.21
  expectancy         7.20
  avg_win            26.63
  avg_loss           -33.81
  max_dd_closed_pct  9.21
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\v17_live5k\windows\older_trend\report.htm

## Window: recent_regime  (2026.03.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             416
  net                2175.02
  return_pct         43.50
  pf                 1.39
  win_rate           66.83
  expectancy         5.23
  avg_win            28.04
  avg_loss           -41.33
  max_dd_closed_pct  11.43
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\v17_live5k\windows\recent_regime\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             951
  net                                5807.73
  return_pct                         116.15
  pf                                 1.49
  win_rate                           66.25
  expectancy                         6.11
  avg_win                            28.02
  avg_loss                           -37.97
  max_dd_closed_pct                  9.21

[OUT-OF-SAMPLE]
  trades                             430
  net                                3097.44
  return_pct                         61.95
  pf                                 1.67
  win_rate                           67.21
  expectancy                         7.2
  avg_win                            26.63
  avg_loss                           -33.81
  max_dd_closed_pct                  9.21

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 1.67 exp 7.20
  K3 IS->OOS collapse                PFratio 1.12 EXPratio 1.18
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 1.67  exp95CI [2.37,12.39]
  M5 concentration (drop top10)      exp 1.59  PF 1.14
  M6 trade-removal 10% (>=95%net+)   100.0% runs net+
  M8 year concentration (<80%)       max-year share 97%  years [2025, 2026]
  MC (advisory)                      DD p95 13%  P(losing) 0%  net p5 1349
  WF (>=60%, med>=1.10, >=8win)      5/8 pos, med 1.70, worst 0.49, small-win 0
  M4 cost stress                     PENDING (supply --cost-per-trade, pre-declared)
  M7 benchmark                       PENDING (supply --price-csv for the OOS period)
  K5 locked holdout                  PENDING (sealed; supply --holdout once, single unlock)

================================================================
VERDICT: FAIL
================================================================
  - mandatory miss: M8 year-concentration
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest); M4 cost/slippage stress (supply baseline cost); M7 benchmark suite (supply OOS price); K5 locked holdout; M3 parameter plateau (MT5 grid)

  (deterministic: same input => same output; no LLM in this path)
```

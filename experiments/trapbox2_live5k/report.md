# Candidate report - trapbox2_live5k

- EA: CK_TRAPBOX_DKT_v2
- Preset: experiments\trapbox2_live5k\preset.json
- Generated (UTC): 2026-08-31 15:51:29Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: last1yr  (2025.08.28 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             358
  net                -1393.91
  return_pct         -27.88
  pf                 0.85
  win_rate           67.60
  expectancy         -3.89
  avg_win            32.34
  avg_loss           -84.59
  max_dd_closed_pct  32.06
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trapbox2_live5k\windows\last1yr\report.htm

## Window: older_trend  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             238
  net                -153.63
  return_pct         -3.07
  pf                 0.97
  win_rate           67.23
  expectancy         -0.65
  avg_win            33.35
  avg_loss           -76.25
  max_dd_closed_pct  14.82
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trapbox2_live5k\windows\older_trend\report.htm

## Window: recent_regime  (2026.03.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             109
  net                -1401.34
  return_pct         -28.03
  pf                 0.61
  win_rate           68.81
  expectancy         -12.86
  avg_win            29.16
  avg_loss           -108.73
  max_dd_closed_pct  28.74
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trapbox2_live5k\windows\recent_regime\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             358
  net                                -1393.91
  return_pct                         -27.88
  pf                                 0.85
  win_rate                           67.6
  expectancy                         -3.89
  avg_win                            32.34
  avg_loss                           -84.59
  max_dd_closed_pct                  32.06

[OUT-OF-SAMPLE]
  trades                             238
  net                                -153.63
  return_pct                         -3.07
  pf                                 0.97
  win_rate                           67.23
  expectancy                         -0.65
  avg_win                            33.35
  avg_loss                           -76.25
  max_dd_closed_pct                  14.82

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.97 exp -0.65
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.97  exp95CI [-8.51,6.56]
  M5 concentration (drop top10)      exp -3.17  PF 0.87
  M6 trade-removal 10% (>=95%net+)   29.6% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2025, 2026]
  MC (advisory)                      DD p95 42%  P(losing) 57%  net p5 -1721
  WF (>=60%, med>=1.10, >=8win)      4/8 pos, med 1.13, worst 0.66, small-win 4
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

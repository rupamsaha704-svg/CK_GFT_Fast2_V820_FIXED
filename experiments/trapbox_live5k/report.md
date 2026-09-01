# Candidate report - trapbox_live5k

- EA: CK_TRAPBOX_DKT_v1
- Preset: experiments\trapbox_live5k\preset.json
- Generated (UTC): 2026-08-31 15:46:21Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: last1yr  (2025.08.28 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             291
  net                -1407.47
  return_pct         -28.15
  pf                 0.84
  win_rate           73.20
  expectancy         -4.84
  avg_win            34.05
  avg_loss           -112.46
  max_dd_closed_pct  30.05
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trapbox_live5k\windows\last1yr\report.htm

## Window: older_trend  (2025.08.28 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             215
  net                -508.77
  return_pct         -10.18
  pf                 0.92
  win_rate           73.49
  expectancy         -2.37
  avg_win            34.82
  avg_loss           -107.34
  max_dd_closed_pct  19.94
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trapbox_live5k\windows\older_trend\report.htm

## Window: recent_regime  (2026.03.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             129
  net                -1400.00
  return_pct         -28.00
  pf                 0.68
  win_rate           73.64
  expectancy         -10.85
  avg_win            31.71
  avg_loss           -129.78
  max_dd_closed_pct  28.41
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\trapbox_live5k\windows\recent_regime\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             291
  net                                -1407.47
  return_pct                         -28.15
  pf                                 0.84
  win_rate                           73.2
  expectancy                         -4.84
  avg_win                            34.05
  avg_loss                           -112.46
  max_dd_closed_pct                  30.05

[OUT-OF-SAMPLE]
  trades                             215
  net                                -508.77
  return_pct                         -10.18
  pf                                 0.92
  win_rate                           73.49
  expectancy                         -2.37
  avg_win                            34.82
  avg_loss                           -107.34
  max_dd_closed_pct                  19.94

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.92 exp -2.37
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.92  exp95CI [-11.27,6.09]
  M5 concentration (drop top10)      exp -5.32  PF 0.82
  M6 trade-removal 10% (>=95%net+)   6.4% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2025, 2026]
  MC (advisory)                      DD p95 47%  P(losing) 71%  net p5 -2063
  WF (>=60%, med>=1.10, >=8win)      3/8 pos, med 0.98, worst 0.49, small-win 5
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

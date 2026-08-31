# Candidate report - poc_sess_ny

- EA: CK_POC_VA_SESS
- Preset: experiments\poc_sess_ny\preset.json
- Generated (UTC): 2026-08-30 18:29:59Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             174
  net                -653.29
  return_pct         -1.31
  pf                 0.93
  win_rate           21.26
  expectancy         -3.75
  avg_win            247.11
  avg_loss           -71.51
  max_dd_closed_pct  5.31
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_sess_ny\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             235
  net                -6833.95
  return_pct         -13.67
  pf                 0.74
  win_rate           22.98
  expectancy         -29.08
  avg_win            358.16
  avg_loss           -144.61
  max_dd_closed_pct  16.07
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_sess_ny\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             135
  net                -1704.95
  return_pct         -3.41
  pf                 0.88
  win_rate           25.93
  expectancy         -12.63
  avg_win            350.84
  avg_loss           -139.84
  max_dd_closed_pct  7.55
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_sess_ny\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             159
  net                -4686.06
  return_pct         -9.37
  pf                 0.73
  win_rate           22.01
  expectancy         -29.47
  avg_win            359.18
  avg_loss           -139.17
  max_dd_closed_pct  12.26
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_sess_ny\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             174
  net                                -653.29
  return_pct                         -1.31
  pf                                 0.93
  win_rate                           21.26
  expectancy                         -3.75
  avg_win                            247.11
  avg_loss                           -71.51
  max_dd_closed_pct                  5.31

[OUT-OF-SAMPLE]
  trades                             235
  net                                -6833.95
  return_pct                         -13.67
  pf                                 0.74
  win_rate                           22.98
  expectancy                         -29.08
  avg_win                            358.16
  avg_loss                           -144.61
  max_dd_closed_pct                  16.07

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.74 exp -29.08
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.74  exp95CI [-62.46,5.83]
  M5 concentration (drop top10)      exp -66.21  PF 0.43
  M6 trade-removal 10% (>=95%net+)   0.0% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2025, 2026]
  MC (advisory)                      DD p95 28%  P(losing) 95%  net p5 -13332
  WF (>=60%, med>=1.10, >=8win)      2/8 pos, med 0.74, worst 0.32, small-win 3
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

# Candidate report - poc_sess_us

- EA: CK_POC_VA_SESS
- Preset: experiments\poc_sess_us\preset.json
- Generated (UTC): 2026-08-30 18:23:18Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             254
  net                735.13
  return_pct         1.47
  pf                 1.06
  win_rate           21.26
  expectancy         2.89
  avg_win            232.81
  avg_loss           -59.18
  max_dd_closed_pct  4.91
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_sess_us\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             341
  net                -4142.27
  return_pct         -8.28
  pf                 0.88
  win_rate           21.70
  expectancy         -12.15
  avg_win            393.21
  avg_loss           -124.49
  max_dd_closed_pct  13.92
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_sess_us\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             200
  net                91.84
  return_pct         0.18
  pf                 1.01
  win_rate           24.00
  expectancy         0.46
  avg_win            371.20
  avg_loss           -116.62
  max_dd_closed_pct  6.11
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_sess_us\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             224
  net                -2638.04
  return_pct         -5.28
  pf                 0.88
  win_rate           20.09
  expectancy         -11.78
  avg_win            413.76
  avg_loss           -118.76
  max_dd_closed_pct  13.46
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_sess_us\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             254
  net                                735.13
  return_pct                         1.47
  pf                                 1.06
  win_rate                           21.26
  expectancy                         2.89
  avg_win                            232.81
  avg_loss                           -59.18
  max_dd_closed_pct                  4.91

[OUT-OF-SAMPLE]
  trades                             341
  net                                -4142.27
  return_pct                         -8.28
  pf                                 0.88
  win_rate                           21.7
  expectancy                         -12.15
  avg_win                            393.21
  avg_loss                           -124.49
  max_dd_closed_pct                  13.92

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 0.88 exp -12.15
  K3 IS->OOS collapse                PFratio 0.82 EXPratio -4.20
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 0.88  exp95CI [-40.97,19.65]
  M5 concentration (drop top10)      exp -46.75  PF 0.53
  M6 trade-removal 10% (>=95%net+)   0.2% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2025, 2026]
  MC (advisory)                      DD p95 28%  P(losing) 78%  net p5 -12519
  WF (>=60%, med>=1.10, >=8win)      4/8 pos, med 1.00, worst 0.31, small-win 0
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

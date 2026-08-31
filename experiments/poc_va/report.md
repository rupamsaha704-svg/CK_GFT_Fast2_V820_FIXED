# Candidate report - poc_va

- EA: CK_POC_VA_v1
- Preset: experiments\poc_va\preset.json
- Generated (UTC): 2026-08-30 17:47:46Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             341
  net                2644.79
  return_pct         5.29
  pf                 1.17
  win_rate           20.82
  expectancy         7.76
  avg_win            255.43
  avg_loss           -57.37
  max_dd_closed_pct  5.26
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_va\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             462
  net                2433.04
  return_pct         4.87
  pf                 1.06
  win_rate           22.73
  expectancy         5.27
  avg_win            408.68
  avg_loss           -113.38
  max_dd_closed_pct  10.27
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_va\windows\OOS_2026\report.htm

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             292
  net                4216.09
  return_pct         8.43
  pf                 1.18
  win_rate           23.29
  expectancy         14.44
  avg_win            405.78
  avg_loss           -104.36
  max_dd_closed_pct  9.60
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_va\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             291
  net                1891.42
  return_pct         3.78
  pf                 1.08
  win_rate           21.65
  expectancy         6.50
  avg_win            421.10
  avg_loss           -108.06
  max_dd_closed_pct  8.85
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\poc_va\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             341
  net                                2644.79
  return_pct                         5.29
  pf                                 1.17
  win_rate                           20.82
  expectancy                         7.76
  avg_win                            255.43
  avg_loss                           -57.37
  max_dd_closed_pct                  5.26

[OUT-OF-SAMPLE]
  trades                             462
  net                                2433.04
  return_pct                         4.87
  pf                                 1.06
  win_rate                           22.73
  expectancy                         5.27
  avg_win                            408.68
  avg_loss                           -113.38
  max_dd_closed_pct                  10.27

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 1.06 exp 5.27
  K3 IS->OOS collapse                PFratio 0.91 EXPratio 0.68
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 1.06  exp95CI [-19.52,30.50]
  M5 concentration (drop top10)      exp -20.36  PF 0.77
  M6 trade-removal 10% (>=95%net+)   88.2% runs net+
  M8 year concentration (<80%)       max-year share 66%  years [2025, 2026]
  MC (advisory)                      DD p95 21%  P(losing) 35%  net p5 -7261
  WF (>=60%, med>=1.10, >=8win)      4/8 pos, med 1.19, worst 0.53, small-win 0
  M4 cost stress                     PENDING (supply --cost-per-trade, pre-declared)
  M7 benchmark                       PENDING (supply --price-csv for the OOS period)
  K5 locked holdout                  PENDING (sealed; supply --holdout once, single unlock)

================================================================
VERDICT: FAIL
================================================================
  - mandatory miss: M1 OOS PF/exp-CI
  - mandatory miss: M5 concentration
  - mandatory miss: M6 trade-removal
  - mandatory miss: M2 walk-forward
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest); M4 cost/slippage stress (supply baseline cost); M7 benchmark suite (supply OOS price); K5 locked holdout; M3 parameter plateau (MT5 grid)

  (deterministic: same input => same output; no LLM in this path)
```

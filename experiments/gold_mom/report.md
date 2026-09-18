# Candidate report - gold_mom

- EA: CK_GOLD_MR
- Preset: experiments\gold_mom\preset.json
- Generated (UTC): 2026-09-01 19:37:38Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 1). Python analyzes MT5 outputs only.

## Window: may  (2026.05.01 to 2026.06.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             40
  net                -198.29
  return_pct         -3.97
  pf                 0.84
  win_rate           30.00
  expectancy         -4.96
  avg_win            84.88
  avg_loss           -43.46
  max_dd_closed_pct  13.11
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_mom\windows\may\report.htm

## Window: chop  (2026.03.01 to 2026.08.27)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             241
  net                727.54
  return_pct         14.55
  pf                 1.10
  win_rate           36.51
  expectancy         3.02
  avg_win            88.78
  avg_loss           -46.31
  max_dd_closed_pct  13.80
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\gold_mom\windows\chop\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             40
  net                                -198.29
  return_pct                         -3.97
  pf                                 0.84
  win_rate                           30.0
  expectancy                         -4.96
  avg_win                            84.88
  avg_loss                           -43.46
  max_dd_closed_pct                  13.11

[OUT-OF-SAMPLE]
  trades                             241
  net                                727.54
  return_pct                         14.55
  pf                                 1.1
  win_rate                           36.51
  expectancy                         3.02
  avg_win                            88.78
  avg_loss                           -46.31
  max_dd_closed_pct                  13.8

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 1.10 exp 3.02
  K3 IS->OOS collapse                n/a
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 1.10  exp95CI [-5.16,11.50]
  M5 concentration (drop top10)      exp -1.53  PF 0.95
  M6 trade-removal 10% (>=95%net+)   97.7% runs net+
  M8 year concentration (<80%)       max-year share 100%  years [2026]
  MC (advisory)                      DD p95 32%  P(losing) 24%  net p5 -932
  WF (>=60%, med>=1.10, >=8win)      4/8 pos, med 1.03, worst 0.61, small-win 3
  M4 cost stress                     PENDING (supply --cost-per-trade, pre-declared)
  M7 benchmark                       PENDING (supply --price-csv for the OOS period)
  K5 locked holdout                  PENDING (sealed; supply --holdout once, single unlock)

================================================================
VERDICT: FAIL
================================================================
  - mandatory miss: M1 OOS PF/exp-CI
  - mandatory miss: M5 concentration
  - mandatory miss: M8 year-concentration
  - mandatory miss: M2 walk-forward
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest); M4 cost/slippage stress (supply baseline cost); M7 benchmark suite (supply OOS price); K5 locked holdout; M3 parameter plateau (MT5 grid)

  (deterministic: same input => same output; no LLM in this path)
```

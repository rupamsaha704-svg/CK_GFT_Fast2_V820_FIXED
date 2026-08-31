# Candidate report - fix09_is_oos

- EA: CK_GOLD_PRO_FIX09
- Preset: experiments\fix09_is_oos\preset.json
- Generated (UTC): 2026-08-30 16:50:46Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: IS_2025H2  (2025.06.01 to 2025.12.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             154
  net                5950.41
  return_pct         11.90
  pf                 1.98
  win_rate           27.27
  expectancy         38.64
  avg_win            286.26
  avg_loss           -55.71
  max_dd_closed_pct  2.20
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_is_oos\windows\IS_2025H2\report.htm

## Window: OOS_2026  (2025.12.01 to 2026.08.28)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             215
  net                2913.03
  return_pct         5.83
  pf                 1.13
  win_rate           20.47
  expectancy         13.55
  avg_win            561.22
  avg_loss           -128.12
  max_dd_closed_pct  8.46
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_is_oos\windows\OOS_2026\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             154
  net                                5950.41
  return_pct                         11.9
  pf                                 1.98
  win_rate                           27.27
  expectancy                         38.64
  avg_win                            286.26
  avg_loss                           -55.71
  max_dd_closed_pct                  2.2

[OUT-OF-SAMPLE]
  trades                             215
  net                                2913.03
  return_pct                         5.83
  pf                                 1.13
  win_rate                           20.47
  expectancy                         13.55
  avg_win                            561.22
  avg_loss                           -128.12
  max_dd_closed_pct                  8.46

[STAGES on OOS]
  K2 OOS PF>1.0 & exp>0              PF 1.13 exp 13.55
  K3 IS->OOS collapse                PFratio 0.57 EXPratio 0.35
  M1 OOS PF>=1.20 & exp-CI-LB>0      PF 1.13  exp95CI [-33.15,65.93]
  M5 concentration (drop top10)      exp -45.11  PF 0.58
  M6 trade-removal 10% (>=95%net+)   93.0% runs net+
  M8 year concentration (<80%)       max-year share 123%  years [2025, 2026]
  MC (advisory)                      DD p95 17%  P(losing) 31%  net p5 -5574
  WF (>=60%, med>=1.10, >=8win)      4/8 pos, med 1.07, worst 0.25, small-win 6
  M4 cost stress                     PENDING (supply --cost-per-trade, pre-declared)
  M7 benchmark                       PENDING (supply --price-csv for the OOS period)
  K5 locked holdout                  PENDING (sealed; supply --holdout once, single unlock)

================================================================
VERDICT: REJECT
================================================================
  - K3: severe IS->OOS collapse (overfit)
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest); M4 cost/slippage stress (supply baseline cost); M7 benchmark suite (supply OOS price); K5 locked holdout; M3 parameter plateau (MT5 grid)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - fix09_current_regime

- EA: CK_GOLD_PRO_FIX09
- Preset: experiments\fix09_current_regime\preset.json
- Generated (UTC): 2026-08-30 17:02:24Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: cr_h1  (2025.10.01 to 2026.03.15)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             129
  net                12322.51
  return_pct         24.65
  pf                 2.16
  win_rate           29.46
  expectancy         95.52
  avg_win            603.58
  avg_loss           -117.93
  max_dd_closed_pct  3.22
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_current_regime\windows\cr_h1\report.htm

## Window: cr_h2  (2026.03.15 to 2026.08.29)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             135
  net                -4509.04
  return_pct         -9.02
  pf                 0.67
  win_rate           18.52
  expectancy         -33.40
  avg_win            368.02
  avg_loss           -125.77
  max_dd_closed_pct  9.50
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_current_regime\windows\cr_h2\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             129
  net                                12322.51
  return_pct                         24.65
  pf                                 2.16
  win_rate                           29.46
  expectancy                         95.52
  avg_win                            603.58
  avg_loss                           -117.93
  max_dd_closed_pct                  3.22

[OUT-OF-SAMPLE]
  trades                             135
  net                                -4509.04
  return_pct                         -9.02
  pf                                 0.67
  win_rate                           18.52
  expectancy                         -33.4
  avg_win                            368.02
  avg_loss                           -125.77
  max_dd_closed_pct                  9.5

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 135<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

# Candidate report - fix09_proof

- EA: CK_GOLD_PRO_FIX09
- Preset: experiments\fix09_proof\preset.json
- Generated (UTC): 2026-08-30 15:59:31Z
- Trade simulator: MT5 Strategy Tester (real ticks, Model 4). Python analyzes MT5 outputs only.

## Window: is_2025H2  (2025.08.01 to 2026.03.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             165
  net                11313.83
  return_pct         226.28
  pf                 2.12
  win_rate           27.88
  expectancy         68.57
  avg_win            465.98
  avg_loss           -85.77
  max_dd_closed_pct  10.52
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_proof\windows\is_2025H2\report.htm

## Window: oos_2026H1  (2026.03.01 to 2026.08.01)
```
METRIC DICTIONARY v1.0 ù canonical summary
  trades             8
  net                -1661.23
  return_pct         -33.22
  pf                 0.29
  win_rate           25.00
  expectancy         -207.65
  avg_win            341.91
  avg_loss           -390.84
  max_dd_closed_pct  34.87
```
- MT5 native report: C:\Users\prita\CK_GFT_Repo\experiments\fix09_proof\windows\oos_2026H1\report.htm

## Deterministic verdict (pipeline.py)
```
================================================================
DETERMINISTIC VALIDATION PIPELINE ù Design v1.0
================================================================

[IN-SAMPLE]
  trades                             165
  net                                11313.83
  return_pct                         226.28
  pf                                 2.12
  win_rate                           27.88
  expectancy                         68.57
  avg_win                            465.98
  avg_loss                           -85.77
  max_dd_closed_pct                  10.52

[OUT-OF-SAMPLE]
  trades                             8
  net                                -1661.23
  return_pct                         -33.22
  pf                                 0.29
  win_rate                           25.0
  expectancy                         -207.65
  avg_win                            341.91
  avg_loss                           -390.84
  max_dd_closed_pct                  34.87

================================================================
VERDICT: INSUFFICIENT
================================================================
  - OOS trades 8<200
  PENDING stages (need MT5/data): P1 integrity hash not supplied (attach manifest)

  (deterministic: same input => same output; no LLM in this path)
```

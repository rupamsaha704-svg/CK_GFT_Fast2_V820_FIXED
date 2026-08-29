# QM/ICT Variant Grid — Out-of-Sample Report (Block 7)

Generated deterministically by `v1_lab/variant_runner.py`. Same input data + same grid =>
byte-identical `variant_results.csv` and this report. No LLM is in this measurement path.

## Governing rule (inviolable)

> AI discovers and explains; deterministic code measures and judges; locked/unseen data is
> final evidence; no single metric equals PASS; overfitting is forbidden.

- **IS results are EXPLORATION ONLY.** They do not constitute evidence of an edge.
- A real verdict requires **locked / unseen data** and (per DESIGN v1.1) **forward evidence**.
- The verdict column below comes from the **unmodified** `v1_lab/pipeline.py` (its thresholds
  were not changed). This runner only enumerates variants and captures the pipeline's judgement.

## Pre-declared IS/OOS split

- Boundary (fixed in code, chosen a priori as the dataset's chronological midpoint): **2026.02.01 00:00**
- Trades with entry time `< boundary` are IN-SAMPLE; `>= boundary` are OUT-OF-SAMPLE.
- This date was NOT chosen after seeing results. Tuning the split to flatter outcomes would be
  overfitting and is forbidden.

## Multiple-testing disclosure (researcher degrees of freedom)

- **25 variants** were enumerated in this run. Each variant is a separate trial and
  therefore a researcher degree of freedom. With this many comparisons, an apparently good OOS
  result on a single variant can arise by chance; discount accordingly. The grid is a
  BASELINE + one-switch-at-a-time (OFAT) sweep (each row differs from the default by exactly
  one open switch) — deliberately NOT a full cartesian product, to limit over-search.
- **Effective (distinct) trials: 24.** 1 enumerated row(s) are, BY
  CONSTRUCTION, identical to another row and are NOT independent trials: `tp_partial` == `tp_fixed_rr`. Reason:
  `partial_be_trail` is currently modeled as the `fixed_rr` target level (a documented
  proxy), so it produces the same trades as `tp_fixed_rr` at the same `fixed_rr`. The row is
  kept for traceability but flagged here so the effective trial count is not inflated.
- Pipeline minimum OOS-trade bar (pre-declared, unmodified): **>= 200 OOS trades**.

## Headline outcome

- Variants enumerated: **25** (effective distinct trials: **24**)
- Reached the >= 200-OOS-trade bar (eligible for a verdict): **0**
- Returned INSUFFICIENT (too few OOS trades to judge): **25**
- PASS (pending MT5/extra-data stages): **0**

### Honest verdict: INSUFFICIENT / no robust edge established

**No variant reached the pre-declared minimum of 200 out-of-sample trades**, so the deterministic pipeline cannot certify an
out-of-sample edge for ANY variant. This is an expected and legitimate outcome: the QM
engine is highly selective (the default variant produces ~155 trades over the full ~12
month period, so a chronological half has far fewer than 200 OOS trades). We therefore do
**NOT** declare a best variant. The honest answer is: *insufficient out-of-sample evidence
yet — no robust edge established.* More data (a longer history and/or forward-collected,
locked/unseen trades) is required before any variant can be judged.

## Per-variant ranking (OOS)

Ordered by verdict, then OOS expectancy / PF / max-DD / trade-count / Monte-Carlo net-p5. This
ordering is a READING AID for comparison, **not** a selection — the verdict column is the only
judgement, and it comes from the unmodified pipeline.

| # | variant | verdict | OOS n | OOS PF | OOS exp | OOS maxDD% | MC net-p5 | switch |
|---|---------|---------|-------|--------|---------|-----------|-----------|--------|
| 1 | disp_0p4 | INSUFFICIENT | 88 | 1.37 | 23.55 | 23.65 |  | MSS displacement gate = 0.4 (looser) |
| 2 | session_all | INSUFFICIENT | 177 | 1.37 | 23.10 | 28.51 |  | session scope = ny_london_asia (24h eligible) |
| 3 | idm_body | INSUFFICIENT | 59 | 1.30 | 18.70 | 17.74 |  | IDM clear precision = body |
| 4 | tp_fixed_rr | INSUFFICIENT | 77 | 1.33 | 16.73 | 13.33 |  | TP mode = fixed_rr (2R target) |
| 5 | tp_partial (== tp_fixed_rr) | INSUFFICIENT | 77 | 1.33 | 16.73 | 13.33 |  | TP mode = partial_be_trail (proxy; EQUIVALENT to tp_fixed_rr — not a distinct trial) |
| 6 | ob_lb_3 | INSUFFICIENT | 75 | 1.24 | 15.45 | 28.39 |  | POI qm_ob + ob_lookback=3 (tighter displacement-leg OB bound) |
| 7 | sl_buf_0p25 | INSUFFICIENT | 74 | 1.20 | 14.01 | 19.70 |  | SL buffer = 0.25*ATR (tighter) |
| 8 | erl_h4 | INSUFFICIENT | 71 | 1.21 | 13.26 | 17.74 |  | ERL source TF = H4 |
| 9 | poi_qm_ob | INSUFFICIENT | 74 | 1.15 | 10.04 | 18.65 |  | POI type = qm_ob (order-block confluence) |
| 10 | minrr_1p5 | INSUFFICIENT | 62 | 1.13 | 9.14 | 19.71 |  | min projected-RR gate = 1.5 |
| 11 | erl_lb_8 | INSUFFICIENT | 73 | 1.13 | 8.86 | 19.71 |  | ERL lookback = 8 swings (wider external range) |
| 12 | sl_tight_poi | INSUFFICIENT | 72 | 1.10 | 8.22 | 21.11 |  | SL mode = tight_poi (stop at POI edge) |
| 13 | baseline | INSUFFICIENT | 72 | 1.11 | 7.47 | 19.71 |  | documented default config (no switch changed) |
| 14 | reentry_on | INSUFFICIENT | 72 | 1.11 | 7.47 | 19.71 |  | reentry = True (permit one extra same-day entry per stop-out) |
| 15 | smt_dxy | INSUFFICIENT | 72 | 1.11 | 7.47 | 19.71 |  | SMT pair = dxy (needs DXY series) |
| 16 | smt_xag | INSUFFICIENT | 72 | 1.11 | 7.47 | 19.71 |  | SMT pair = xag (needs XAGUSD series) |
| 17 | max_trades_4 | INSUFFICIENT | 97 | 1.09 | 6.08 | 33.51 |  | max trades/day = 4 (looser cap) |
| 18 | rr_3 | INSUFFICIENT | 77 | 1.10 | 5.88 | 17.90 |  | fixed_rr target = 3R |
| 19 | erl_lb_3 | INSUFFICIENT | 69 | 1.07 | 4.85 | 19.71 |  | ERL lookback = 3 swings (tighter external range) |
| 20 | disp_0p8 | INSUFFICIENT | 54 | 1.04 | 2.80 | 21.50 |  | MSS displacement gate = 0.8 (stricter) |
| 21 | sl_buf_1p0 | INSUFFICIENT | 73 | 0.99 | -0.90 | 21.71 |  | SL buffer = 1.0*ATR (wider) |
| 22 | erl_m15 | INSUFFICIENT | 51 | 0.90 | -6.29 | 22.47 |  | ERL source TF = M15 |
| 23 | poi_qm_fvg | INSUFFICIENT | 49 | 0.89 | -7.59 | 30.80 |  | POI type = qm_fvg (FVG confluence) |
| 24 | idm_optional | INSUFFICIENT | 142 | 0.81 | -13.39 | 48.55 |  | IDM clear optional (experimental) |
| 25 | pivot_3 | INSUFFICIENT | 64 | 0.28 | -60.87 | 78.54 |  | swing pivot L/R = 3 (stricter swings) |

## Per-variant detail

### disp_0p4 — INSUFFICIENT

- switch: MSS displacement gate = 0.4 (looser)
- trades: total 186, IS 98, OOS 88
- OOS: PF 1.37, expectancy 23.55, net 2072.51, win-rate 36.4%, max-DD 23.65%
- IS (exploration only): PF 1.51, expectancy 29.83
- pipeline reasons: OOS trades 88<200

### session_all — INSUFFICIENT

- switch: session scope = ny_london_asia (24h eligible)
- trades: total 365, IS 188, OOS 177
- OOS: PF 1.37, expectancy 23.10, net 4088.19, win-rate 35.0%, max-DD 28.51%
- IS (exploration only): PF 1.21, expectancy 12.92
- pipeline reasons: OOS trades 177<200

### idm_body — INSUFFICIENT

- switch: IDM clear precision = body
- trades: total 130, IS 71, OOS 59
- OOS: PF 1.30, expectancy 18.70, net 1103.16, win-rate 37.3%, max-DD 17.74%
- IS (exploration only): PF 1.54, expectancy 33.05
- pipeline reasons: OOS trades 59<200

### tp_fixed_rr — INSUFFICIENT

- switch: TP mode = fixed_rr (2R target)
- trades: total 170, IS 93, OOS 77
- OOS: PF 1.33, expectancy 16.73, net 1288.43, win-rate 45.5%, max-DD 13.33%
- IS (exploration only): PF 1.36, expectancy 20.20
- pipeline reasons: OOS trades 77<200

### tp_partial — INSUFFICIENT

- switch: TP mode = partial_be_trail (proxy; EQUIVALENT to tp_fixed_rr — not a distinct trial)
- **equivalence: identical BY CONSTRUCTION to `tp_fixed_rr`** (`partial_be_trail` is modeled as the `fixed_rr` level). Not an independent trial.
- trades: total 170, IS 93, OOS 77
- OOS: PF 1.33, expectancy 16.73, net 1288.43, win-rate 45.5%, max-DD 13.33%
- IS (exploration only): PF 1.36, expectancy 20.20
- pipeline reasons: OOS trades 77<200

### ob_lb_3 — INSUFFICIENT

- switch: POI qm_ob + ob_lookback=3 (tighter displacement-leg OB bound)
- trades: total 147, IS 72, OOS 75
- OOS: PF 1.24, expectancy 15.45, net 1158.54, win-rate 34.7%, max-DD 28.39%
- IS (exploration only): PF 1.10, expectancy 6.80
- pipeline reasons: OOS trades 75<200

### sl_buf_0p25 — INSUFFICIENT

- switch: SL buffer = 0.25*ATR (tighter)
- trades: total 155, IS 81, OOS 74
- OOS: PF 1.20, expectancy 14.01, net 1037.05, win-rate 29.7%, max-DD 19.70%
- IS (exploration only): PF 1.40, expectancy 25.68
- pipeline reasons: OOS trades 74<200

### erl_h4 — INSUFFICIENT

- switch: ERL source TF = H4
- trades: total 152, IS 81, OOS 71
- OOS: PF 1.21, expectancy 13.26, net 941.29, win-rate 35.2%, max-DD 17.74%
- IS (exploration only): PF 1.71, expectancy 42.32
- pipeline reasons: OOS trades 71<200

### poi_qm_ob — INSUFFICIENT

- switch: POI type = qm_ob (order-block confluence)
- trades: total 157, IS 83, OOS 74
- OOS: PF 1.15, expectancy 10.04, net 743.24, win-rate 33.8%, max-DD 18.65%
- IS (exploration only): PF 1.38, expectancy 24.19
- pipeline reasons: OOS trades 74<200

### minrr_1p5 — INSUFFICIENT

- switch: min projected-RR gate = 1.5
- trades: total 142, IS 80, OOS 62
- OOS: PF 1.13, expectancy 9.14, net 566.44, win-rate 29.0%, max-DD 19.71%
- IS (exploration only): PF 1.72, expectancy 42.04
- pipeline reasons: OOS trades 62<200

### erl_lb_8 — INSUFFICIENT

- switch: ERL lookback = 8 swings (wider external range)
- trades: total 156, IS 83, OOS 73
- OOS: PF 1.13, expectancy 8.86, net 646.56, win-rate 34.2%, max-DD 19.71%
- IS (exploration only): PF 1.71, expectancy 42.52
- pipeline reasons: OOS trades 73<200

### sl_tight_poi — INSUFFICIENT

- switch: SL mode = tight_poi (stop at POI edge)
- trades: total 156, IS 84, OOS 72
- OOS: PF 1.10, expectancy 8.22, net 592.20, win-rate 19.4%, max-DD 21.11%
- IS (exploration only): PF 1.39, expectancy 29.14
- pipeline reasons: OOS trades 72<200

### baseline — INSUFFICIENT

- switch: documented default config (no switch changed)
- trades: total 155, IS 83, OOS 72
- OOS: PF 1.11, expectancy 7.47, net 538.04, win-rate 33.3%, max-DD 19.71%
- IS (exploration only): PF 1.62, expectancy 36.91
- pipeline reasons: OOS trades 72<200

### reentry_on — INSUFFICIENT

- switch: reentry = True (permit one extra same-day entry per stop-out)
- trades: total 157, IS 85, OOS 72
- OOS: PF 1.11, expectancy 7.47, net 538.04, win-rate 33.3%, max-DD 19.71%
- IS (exploration only): PF 1.62, expectancy 37.12
- pipeline reasons: OOS trades 72<200

### smt_dxy — INSUFFICIENT

- switch: SMT pair = dxy (needs DXY series)
- trades: total 155, IS 83, OOS 72
- OOS: PF 1.11, expectancy 7.47, net 538.04, win-rate 33.3%, max-DD 19.71%
- IS (exploration only): PF 1.62, expectancy 36.91
- SMT: SMT 'dxy' requested but no --pair-csv supplied: XAGUSD/DXY are NOT in the repo. SMT treated as UNAVAILABLE (0 signals); export the partner series to enable.
- pipeline reasons: OOS trades 72<200

### smt_xag — INSUFFICIENT

- switch: SMT pair = xag (needs XAGUSD series)
- trades: total 155, IS 83, OOS 72
- OOS: PF 1.11, expectancy 7.47, net 538.04, win-rate 33.3%, max-DD 19.71%
- IS (exploration only): PF 1.62, expectancy 36.91
- SMT: SMT 'xag' requested but no --pair-csv supplied: XAGUSD/DXY are NOT in the repo. SMT treated as UNAVAILABLE (0 signals); export the partner series to enable.
- pipeline reasons: OOS trades 72<200

### max_trades_4 — INSUFFICIENT

- switch: max trades/day = 4 (looser cap)
- trades: total 208, IS 111, OOS 97
- OOS: PF 1.09, expectancy 6.08, net 589.99, win-rate 32.0%, max-DD 33.51%
- IS (exploration only): PF 1.43, expectancy 26.21
- pipeline reasons: OOS trades 97<200

### rr_3 — INSUFFICIENT

- switch: fixed_rr target = 3R
- trades: total 170, IS 93, OOS 77
- OOS: PF 1.10, expectancy 5.88, net 453.05, win-rate 37.7%, max-DD 17.90%
- IS (exploration only): PF 1.83, expectancy 45.77
- pipeline reasons: OOS trades 77<200

### erl_lb_3 — INSUFFICIENT

- switch: ERL lookback = 3 swings (tighter external range)
- trades: total 150, IS 81, OOS 69
- OOS: PF 1.07, expectancy 4.85, net 334.37, win-rate 33.3%, max-DD 19.71%
- IS (exploration only): PF 1.70, expectancy 42.04
- pipeline reasons: OOS trades 69<200

### disp_0p8 — INSUFFICIENT

- switch: MSS displacement gate = 0.8 (stricter)
- trades: total 122, IS 68, OOS 54
- OOS: PF 1.04, expectancy 2.80, net 151.18, win-rate 31.5%, max-DD 21.50%
- IS (exploration only): PF 1.47, expectancy 27.86
- pipeline reasons: OOS trades 54<200

### sl_buf_1p0 — INSUFFICIENT

- switch: SL buffer = 1.0*ATR (wider)
- trades: total 156, IS 83, OOS 73
- OOS: PF 0.99, expectancy -0.90, net -65.51, win-rate 35.6%, max-DD 21.71%
- IS (exploration only): PF 1.31, expectancy 17.92
- pipeline reasons: OOS trades 73<200

### erl_m15 — INSUFFICIENT

- switch: ERL source TF = M15
- trades: total 116, IS 65, OOS 51
- OOS: PF 0.90, expectancy -6.29, net -320.96, win-rate 35.3%, max-DD 22.47%
- IS (exploration only): PF 1.36, expectancy 20.73
- pipeline reasons: OOS trades 51<200

### poi_qm_fvg — INSUFFICIENT

- switch: POI type = qm_fvg (FVG confluence)
- trades: total 131, IS 82, OOS 49
- OOS: PF 0.89, expectancy -7.59, net -371.90, win-rate 24.5%, max-DD 30.80%
- IS (exploration only): PF 0.67, expectancy -22.50
- pipeline reasons: OOS trades 49<200

### idm_optional — INSUFFICIENT

- switch: IDM clear optional (experimental)
- trades: total 307, IS 165, OOS 142
- OOS: PF 0.81, expectancy -13.39, net -1901.85, win-rate 28.9%, max-DD 48.55%
- IS (exploration only): PF 1.18, expectancy 11.80
- pipeline reasons: OOS trades 142<200

### pivot_3 — INSUFFICIENT

- switch: swing pivot L/R = 3 (stricter swings)
- trades: total 138, IS 74, OOS 64
- OOS: PF 0.28, expectancy -60.87, net -3895.54, win-rate 14.1%, max-DD 78.54%
- IS (exploration only): PF 1.28, expectancy 18.01
- pipeline reasons: OOS trades 64<200

## Data dependency notes

- **SMT variants (`smt_xag`, `smt_dxy`) had NO partner series** (XAGUSD / DXY are not in
  the repo). They were enumerated as legitimate degrees of freedom but SMT was disabled
  (variant = OFF) rather than fabricating a signal. Supply `--pair-csv` with an aligned
  partner series to actually exercise SMT.

## Provenance

- M15 data: `v1_lab/XAUUSD_M15_clean.csv`  (22849 bars)
- M5 data: `v1_lab/XAUUSD_M5_clean.csv`  (68418 bars)
- Deposit (metrics/MC sizing): 5000.00
- Verdicts computed via the unmodified `pipeline.py` logic (MIN_OOS_TRADES=200, M1_MIN_PF=1.2).


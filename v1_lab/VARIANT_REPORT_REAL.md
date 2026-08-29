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

- Boundary (fixed in code, chosen a priori as the dataset's chronological midpoint): **2024.07.01 00:00**
- Trades with entry time `< boundary` are IN-SAMPLE; `>= boundary` are OUT-OF-SAMPLE.
- This date was NOT chosen after seeing results. Tuning the split to flatter outcomes would be
  overfitting and is forbidden.

## Multiple-testing disclosure (researcher degrees of freedom)

- **27 variants** were enumerated in this run. Each variant is a separate trial and
  therefore a researcher degree of freedom. With this many comparisons, an apparently good OOS
  result on a single variant can arise by chance; discount accordingly. The grid is a
  BASELINE + one-switch-at-a-time (OFAT) sweep (each row differs from the default by exactly
  one open switch) — deliberately NOT a full cartesian product, to limit over-search.
- **Effective (distinct) trials: 26.** 1 enumerated row(s) are, BY
  CONSTRUCTION, identical to another row and are NOT independent trials: `tp_partial` == `tp_fixed_rr`. Reason:
  `partial_be_trail` is currently modeled as the `fixed_rr` target level (a documented
  proxy), so it produces the same trades as `tp_fixed_rr` at the same `fixed_rr`. The row is
  kept for traceability but flagged here so the effective trial count is not inflated.
- Pipeline minimum OOS-trade bar (pre-declared, unmodified): **>= 200 OOS trades**.

## Headline outcome

- Variants enumerated: **27** (effective distinct trials: **26**)
- Reached the >= 200-OOS-trade bar (eligible for a verdict): **3**
- Returned INSUFFICIENT (too few OOS trades to judge): **24**
- PASS (pending MT5/extra-data stages): **0**

### Honest verdict: no variant PASSES the out-of-sample gates

Some variants cleared the trade-count bar and were judged, but **none PASSED** the
pipeline's mandatory OOS gates. We do **NOT** manufacture a winner. The honest answer is:
*no robust out-of-sample edge established.* See the per-variant reasons below.

## Per-variant ranking (OOS)

Ordered by verdict, then OOS expectancy / PF / max-DD / trade-count / Monte-Carlo net-p5. This
ordering is a READING AID for comparison, **not** a selection — the verdict column is the only
judgement, and it comes from the unmodified pipeline.

| # | variant | verdict | OOS n | OOS PF | OOS exp | OOS maxDD% | MC net-p5 | switch |
|---|---------|---------|-------|--------|---------|-----------|-----------|--------|
| 1 | session_all | FAIL | 368 | 1.27 | 17.33 | 51.96 | 14 | session scope = ny_london_asia (24h eligible) |
| 2 | max_trades_4 | FAIL | 212 | 1.22 | 14.62 | 24.55 | -1566 | max trades/day = 4 (looser cap) |
| 3 | idm_optional | REJECT | 309 | 0.96 | -3.08 | 41.94 | -6025 | IDM clear optional (experimental) |
| 4 | erl_h4 | INSUFFICIENT | 157 | 1.42 | 25.95 | 21.51 |  | ERL source TF = H4 |
| 5 | minrr_1p5 | INSUFFICIENT | 145 | 1.39 | 25.03 | 15.96 |  | min projected-RR gate = 1.5 |
| 6 | disp_0p4 | INSUFFICIENT | 189 | 1.40 | 24.85 | 19.97 |  | MSS displacement gate = 0.4 (looser) |
| 7 | idm_body | INSUFFICIENT | 132 | 1.39 | 24.62 | 28.73 |  | IDM clear precision = body |
| 8 | erl_lb_8 | INSUFFICIENT | 159 | 1.39 | 24.38 | 17.32 |  | ERL lookback = 8 swings (wider external range) |
| 9 | rr_3 | INSUFFICIENT | 175 | 1.42 | 24.08 | 17.45 |  | fixed_rr target = 3R |
| 10 | erl_lb_3 | INSUFFICIENT | 152 | 1.37 | 23.29 | 18.48 |  | ERL lookback = 3 swings (tighter external range) |
| 11 | baseline | INSUFFICIENT | 158 | 1.33 | 20.89 | 17.54 |  | documented default config (no switch changed) |
| 12 | reentry_on | INSUFFICIENT | 161 | 1.32 | 20.46 | 19.42 |  | reentry = True (permit one extra same-day entry per stop-out) |
| 13 | sl_buf_0p25 | INSUFFICIENT | 157 | 1.28 | 18.58 | 18.35 |  | SL buffer = 0.25*ATR (tighter) |
| 14 | tp_fixed_rr | INSUFFICIENT | 175 | 1.31 | 16.95 | 23.42 |  | TP mode = fixed_rr (2R target) |
| 15 | tp_partial (== tp_fixed_rr) | INSUFFICIENT | 175 | 1.31 | 16.95 | 23.42 |  | TP mode = partial_be_trail (proxy; EQUIVALENT to tp_fixed_rr — not a distinct trial) |
| 16 | sl_tight_poi | INSUFFICIENT | 160 | 1.21 | 16.50 | 33.49 |  | SL mode = tight_poi (stop at POI edge) |
| 17 | disp_0p8 | INSUFFICIENT | 125 | 1.22 | 13.96 | 17.42 |  | MSS displacement gate = 0.8 (stricter) |
| 18 | poi_qm_ob | INSUFFICIENT | 162 | 1.21 | 13.89 | 27.47 |  | POI type = qm_ob (order-block confluence) |
| 19 | smt_xag | INSUFFICIENT | 24 | 1.19 | 10.85 | 7.61 |  | SMT pair = xag (needs XAGUSD series) |
| 20 | creator_confirmed | INSUFFICIENT | 26 | 1.12 | 9.99 | 25.20 |  | creator's FULL confirmed config: SMT=XAGUSD + rejection entry (2-switch hypothesis) |
| 21 | ob_lb_3 | INSUFFICIENT | 152 | 1.11 | 7.55 | 41.21 |  | POI qm_ob + ob_lookback=3 (tighter displacement-leg OB bound) |
| 22 | sl_buf_1p0 | INSUFFICIENT | 159 | 1.11 | 7.06 | 23.38 |  | SL buffer = 1.0*ATR (wider) |
| 23 | erl_m15 | INSUFFICIENT | 118 | 1.11 | 7.01 | 22.76 |  | ERL source TF = M15 |
| 24 | entry_rejection | INSUFFICIENT | 165 | 1.05 | 3.72 | 59.57 |  | entry mode = rejection (enter at rejection low, SL = rejection high) [creator rule] |
| 25 | smt_dxy | INSUFFICIENT | 47 | 0.95 | -3.47 | 20.93 |  | SMT pair = dxy (needs DXY series) |
| 26 | poi_qm_fvg | INSUFFICIENT | 134 | 0.73 | -18.78 | 53.59 |  | POI type = qm_fvg (FVG confluence) |
| 27 | pivot_3 | INSUFFICIENT | 143 | 0.59 | -31.17 | 89.63 |  | swing pivot L/R = 3 (stricter swings) |

## Per-variant detail

### session_all — FAIL

- switch: session scope = ny_london_asia (24h eligible)
- trades: total 368, IS 0, OOS 368
- OOS: PF 1.27, expectancy 17.33, net 6377.32, win-rate 34.2%, max-DD 51.96%
- IS (exploration only): PF inf, expectancy 0.00
- OOS Monte-Carlo (advisory): DD p95 65%, P(losing) 5%, net p5 14
- pipeline reasons: mandatory miss: M1 OOS PF/exp-CI; mandatory miss: M5 concentration

### max_trades_4 — FAIL

- switch: max trades/day = 4 (looser cap)
- trades: total 212, IS 0, OOS 212
- OOS: PF 1.22, expectancy 14.62, net 3099.16, win-rate 34.0%, max-DD 24.55%
- IS (exploration only): PF inf, expectancy 0.00
- OOS Monte-Carlo (advisory): DD p95 65%, P(losing) 14%, net p5 -1566
- pipeline reasons: mandatory miss: M1 OOS PF/exp-CI; mandatory miss: M5 concentration

### idm_optional — REJECT

- switch: IDM clear optional (experimental)
- trades: total 309, IS 0, OOS 309
- OOS: PF 0.96, expectancy -3.08, net -952.45, win-rate 29.8%, max-DD 41.94%
- IS (exploration only): PF inf, expectancy 0.00
- OOS Monte-Carlo (advisory): DD p95 133%, P(losing) 61%, net p5 -6025
- pipeline reasons: K2: no OOS edge

### erl_h4 — INSUFFICIENT

- switch: ERL source TF = H4
- trades: total 157, IS 0, OOS 157
- OOS: PF 1.42, expectancy 25.95, net 4073.98, win-rate 36.9%, max-DD 21.51%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 157<200

### minrr_1p5 — INSUFFICIENT

- switch: min projected-RR gate = 1.5
- trades: total 145, IS 0, OOS 145
- OOS: PF 1.39, expectancy 25.03, net 3629.59, win-rate 34.5%, max-DD 15.96%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 145<200

### disp_0p4 — INSUFFICIENT

- switch: MSS displacement gate = 0.4 (looser)
- trades: total 189, IS 0, OOS 189
- OOS: PF 1.40, expectancy 24.85, net 4695.84, win-rate 37.0%, max-DD 19.97%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 189<200

### idm_body — INSUFFICIENT

- switch: IDM clear precision = body
- trades: total 132, IS 0, OOS 132
- OOS: PF 1.39, expectancy 24.62, net 3250.00, win-rate 36.4%, max-DD 28.73%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 132<200

### erl_lb_8 — INSUFFICIENT

- switch: ERL lookback = 8 swings (wider external range)
- trades: total 159, IS 0, OOS 159
- OOS: PF 1.39, expectancy 24.38, net 3876.06, win-rate 35.8%, max-DD 17.32%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 159<200

### rr_3 — INSUFFICIENT

- switch: fixed_rr target = 3R
- trades: total 175, IS 0, OOS 175
- OOS: PF 1.42, expectancy 24.08, net 4214.76, win-rate 40.0%, max-DD 17.45%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 175<200

### erl_lb_3 — INSUFFICIENT

- switch: ERL lookback = 3 swings (tighter external range)
- trades: total 152, IS 0, OOS 152
- OOS: PF 1.37, expectancy 23.29, net 3539.59, win-rate 35.5%, max-DD 18.48%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 152<200

### baseline — INSUFFICIENT

- switch: documented default config (no switch changed)
- trades: total 158, IS 0, OOS 158
- OOS: PF 1.33, expectancy 20.89, net 3301.19, win-rate 35.4%, max-DD 17.54%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 158<200

### reentry_on — INSUFFICIENT

- switch: reentry = True (permit one extra same-day entry per stop-out)
- trades: total 161, IS 0, OOS 161
- OOS: PF 1.32, expectancy 20.46, net 3293.46, win-rate 35.4%, max-DD 19.42%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 161<200

### sl_buf_0p25 — INSUFFICIENT

- switch: SL buffer = 0.25*ATR (tighter)
- trades: total 157, IS 0, OOS 157
- OOS: PF 1.28, expectancy 18.58, net 2916.89, win-rate 31.8%, max-DD 18.35%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 157<200

### tp_fixed_rr — INSUFFICIENT

- switch: TP mode = fixed_rr (2R target)
- trades: total 175, IS 0, OOS 175
- OOS: PF 1.31, expectancy 16.95, net 2966.58, win-rate 43.4%, max-DD 23.42%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 175<200

### tp_partial — INSUFFICIENT

- switch: TP mode = partial_be_trail (proxy; EQUIVALENT to tp_fixed_rr — not a distinct trial)
- **equivalence: identical BY CONSTRUCTION to `tp_fixed_rr`** (`partial_be_trail` is modeled as the `fixed_rr` level). Not an independent trial.
- trades: total 175, IS 0, OOS 175
- OOS: PF 1.31, expectancy 16.95, net 2966.58, win-rate 43.4%, max-DD 23.42%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 175<200

### sl_tight_poi — INSUFFICIENT

- switch: SL mode = tight_poi (stop at POI edge)
- trades: total 160, IS 0, OOS 160
- OOS: PF 1.21, expectancy 16.50, net 2639.88, win-rate 22.5%, max-DD 33.49%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 160<200

### disp_0p8 — INSUFFICIENT

- switch: MSS displacement gate = 0.8 (stricter)
- trades: total 125, IS 0, OOS 125
- OOS: PF 1.22, expectancy 13.96, net 1745.53, win-rate 34.4%, max-DD 17.42%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 125<200

### poi_qm_ob — INSUFFICIENT

- switch: POI type = qm_ob (order-block confluence)
- trades: total 162, IS 0, OOS 162
- OOS: PF 1.21, expectancy 13.89, net 2250.62, win-rate 33.3%, max-DD 27.47%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 162<200

### smt_xag — INSUFFICIENT

- switch: SMT pair = xag (needs XAGUSD series)
- trades: total 24, IS 0, OOS 24
- OOS: PF 1.19, expectancy 10.85, net 260.49, win-rate 41.7%, max-DD 7.61%
- IS (exploration only): PF inf, expectancy 0.00
- SMT: SMT 'xag' active with 2907 signals.
- pipeline reasons: OOS trades 24<200

### creator_confirmed — INSUFFICIENT

- switch: creator's FULL confirmed config: SMT=XAGUSD + rejection entry (2-switch hypothesis)
- trades: total 26, IS 0, OOS 26
- OOS: PF 1.12, expectancy 9.99, net 259.85, win-rate 19.2%, max-DD 25.20%
- IS (exploration only): PF inf, expectancy 0.00
- SMT: SMT 'xag' active with 2907 signals.
- pipeline reasons: OOS trades 26<200

### ob_lb_3 — INSUFFICIENT

- switch: POI qm_ob + ob_lookback=3 (tighter displacement-leg OB bound)
- trades: total 152, IS 0, OOS 152
- OOS: PF 1.11, expectancy 7.55, net 1148.33, win-rate 31.6%, max-DD 41.21%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 152<200

### sl_buf_1p0 — INSUFFICIENT

- switch: SL buffer = 1.0*ATR (wider)
- trades: total 159, IS 0, OOS 159
- OOS: PF 1.11, expectancy 7.06, net 1121.90, win-rate 36.5%, max-DD 23.38%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 159<200

### erl_m15 — INSUFFICIENT

- switch: ERL source TF = M15
- trades: total 118, IS 0, OOS 118
- OOS: PF 1.11, expectancy 7.01, net 826.70, win-rate 37.3%, max-DD 22.76%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 118<200

### entry_rejection — INSUFFICIENT

- switch: entry mode = rejection (enter at rejection low, SL = rejection high) [creator rule]
- trades: total 165, IS 0, OOS 165
- OOS: PF 1.05, expectancy 3.72, net 613.75, win-rate 20.6%, max-DD 59.57%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 165<200

### smt_dxy — INSUFFICIENT

- switch: SMT pair = dxy (needs DXY series)
- trades: total 47, IS 0, OOS 47
- OOS: PF 0.95, expectancy -3.47, net -162.94, win-rate 34.0%, max-DD 20.93%
- IS (exploration only): PF inf, expectancy 0.00
- SMT: SMT 'dxy' active with 8642 signals.
- pipeline reasons: OOS trades 47<200

### poi_qm_fvg — INSUFFICIENT

- switch: POI type = qm_fvg (FVG confluence)
- trades: total 134, IS 0, OOS 134
- OOS: PF 0.73, expectancy -18.78, net -2516.65, win-rate 28.4%, max-DD 53.59%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 134<200

### pivot_3 — INSUFFICIENT

- switch: swing pivot L/R = 3 (stricter swings)
- trades: total 143, IS 0, OOS 143
- OOS: PF 0.59, expectancy -31.17, net -4457.96, win-rate 22.4%, max-DD 89.63%
- IS (exploration only): PF inf, expectancy 0.00
- pipeline reasons: OOS trades 143<200

## Data dependency notes

- SMT partner series present where required (see per-variant SMT notes).

## Provenance

- M15 data: `data_drop/XAUUSD_M15_export.csv`  (100000 bars)
- M5 data: `data_drop/XAUUSD_M5_drop.csv`  (68418 bars)
- Deposit (metrics/MC sizing): 5000.00
- Verdicts computed via the unmodified `pipeline.py` logic (MIN_OOS_TRADES=200, M1_MIN_PF=1.2).


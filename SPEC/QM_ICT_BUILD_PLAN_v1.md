# QM/ICT XAUUSD Setup — Python Detection + Variant-Engine Build Plan (v1)

**Branch:** `kiro/validation-toolkit`  ·  **Lab:** `v1_lab/`  ·  **Symbol:** XAUUSD only
**Governing rule (inviolable):** AI discovers and explains; deterministic code measures and judges;
locked/unseen data is final evidence; no single metric equals PASS; overfitting is forbidden.

## Why we are proceeding now (decision)
We are NOT waiting for the setup creator to confirm every hidden rule before working. Based on the
proofs already provided, we build the objective machinery now and turn every *unconfirmed* rule into a
tunable **parameter** or an explicit **variant switch**. We then run the SAME historical trades through
the variants and let out-of-sample expectancy / PF / max-DD / trade-count / Monte-Carlo robustness show
which (if any) works. Proof comes from the work, not from words. Pre-picking a good-looking value would
be overfitting and is forbidden.

## What is LOCKED (implement exactly)
- MSS = **body-CLOSE** (not wick) beyond the most-recent confirmed swing + displacement = body/ATR14.
- TF backbone **H4 -> H1 -> M15 -> M5**.
- Engine timezone = **America/New_York** (DST-aware) for the 8:30 and 9:30 legs; **display in IST**.
- US DST = 2nd Sunday March -> 1st Sunday November (EDT UTC-4) else EST UTC-5 (provable math).
- Neither the 8:30 nor the 9:30 leg is hard-coded as "manipulation" vs "expansion" — both examined.

## What is OPEN (variants/parameters — do NOT lock or guess a winner)
SMT pair (XAU-XAG | XAU-DXY | off) + rolling-correlation guard · POI type (QM left-shoulder | +OB | +FVG)
· SL (Head/SMT-high+buffer | tighter POI; buffer = ATR-multiple) · TP (full opposite-external | fixed-RR
| partial/BE/trail; min projected-RR gate) · IDM-clear mandatory(A+) vs optional(experimental) · swing
pivot L/R count · ERL source TF · max-trades/day & re-entry · session scope (NY-only | +London/Asia).

## Environment reality (important)
Python **3.9, standard library only** — no pandas/numpy/pytest in this sandbox. All blocks are pure
stdlib, matching the existing `v1_lab/qm_detect.py`. `zoneinfo` with `America/New_York` IS available and
is used to cross-check the hand-written DST math. Each module ships a `--selfcheck` (synthetic
assertions, positive + negative + gate-is-the-discriminator) and a real-data run on `v1_lab/*.csv`.

## Data dependency
SMT needs **XAGUSD** and/or **DXY** series aligned to XAUUSD; these are **not in the repo**. The SMT
block accepts an optional `--pair-csv`; when absent it reports the dependency and runs with SMT = OFF
(never fabricates data). User can export XAGUSD/DXY from MT5 in the same `datetime,open,high,low,close,volume`
format as the existing files.

## Blocks (each: deterministic, causal/no-lookahead, self-check + real-data numbers)
1. **(done, commit db2c748)** `qm_detect.py` — swing/pivot + M15 MSS.
2. **FEAT-001** `ny_session.py` — NY session + 8:30/9:30 legs, DST-aware, IST display. *Fully objective; first.*
3. **FEAT-002** `erl_detect.py` (ERL zones + raid) + `idm_detect.py` (IDM level + cleared test).
4. **FEAT-003** `poi_zone.py` (QM left-shoulder + OB/FVG confluence variants) + `smt_detect.py` (SMT + corr guard, data-dep handling).
5. **FEAT-004** `qm_state_machine.py` — full ERL->SMT->MSS->IDM->POI->M5-confirm->entry/SL/TP; every open rule a variant.
6. **FEAT-005** `variant_runner.py` — variant grid -> per-variant trade lists (pipeline format) -> `pipeline.py` -> honest OOS comparison report.

## Validation infra to REUSE (do not rebuild)
`metrics.py` (canonical PF/expectancy/DD; trade CSV `time,profit`), `pipeline.py` (verdict via K-gates +
M1–M8 + WF + MC + cost-stress), `walkforward.py`, `regime.py`, `cost_stress.py`, `benchmark.py`.

## Ledger discipline
Orchestrator owns verdict/submission entries in `SPEC/dof_ledger.jsonl` (currently seq26). This build
appends only technical build entries and REPORTS what should be logged. Every variant enumerated is a
researcher degree of freedom to be counted toward multiple-testing correction.

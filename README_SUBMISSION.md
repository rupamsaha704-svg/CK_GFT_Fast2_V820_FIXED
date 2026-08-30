# XAUUSD Algo Project — Submission Index (Design v1.0)

Scope: **XAUUSD (Gold) only** · MT5 = real-tick executor · Python = deterministic validator ·
Phase: research / demo-forward (NO real money). Start here: `SUBMISSION.md` (1-page honest summary).

## 1. Deliverable EA
| file | what |
|---|---|
| `CK_GOLD_PRO_FIX09.mq5` | deploy EA — Gold M15 trend, **fixed 0.09 lot**, execution-hardened, session-guarded |
| `install_fix09_demo.ps1` | download+compile into MT5 Navigator (then attach on a DEMO chart) |
| `write_fix09_preset.ps1` | writes a `.set` preset so no manual input typing |

**Backtest (real ticks, 2025-08→2026-08, $5k):** +204%, PF 1.50, closed-DD 16.1%.
**Status:** frozen 8-week DEMO forward test RUNNING (started; see ledger). Honest verdict = **RETEST / REGIME-ONLY candidate**, not a guaranteed edge.

## 2. Locked design & governance (`SPEC/`)
| file | what |
|---|---|
| `SPEC/DESIGN_v1.0.md` | authoritative locked spec: verdicts, PASS matrix (P/K/M/A), regime spec, forensic spec, 19 red-team guards, contamination rulebook, status vocab, master rule |
| `SPEC/metric_dictionary.md` | hash-locked metric definitions (PF, equity DD, expectancy, sessions, trade counting) |
| `SPEC/dof_ledger.py` + `dof_ledger.jsonl` | append-only, **hash-chained** researcher-degrees-of-freedom / event ledger (tamper-evident) |

Rule: **LLM discovers & explains; deterministic code measures & judges; locked unseen data = final evidence; no single metric = PASS.**

## 3. Deterministic validation pipeline (`v1_lab/`)
| file | stage(s) | run |
|---|---|---|
| `metrics.py` | canonical metrics (single source of truth) | `python3 metrics.py trades.csv` |
| `pipeline.py` | full engine: P1-3, K2/K3, M1/M2/M5/M6/M8 + wires M4/M7/K5 → verdict | `python3 pipeline.py --is IS.csv --oos OOS.csv --spec-hash <h> --cost-per-trade C --price-csv PX.csv` |
| `walkforward.py` | M2 rolling-OOS consistency | `python3 walkforward.py trades.csv 8` |
| `paramstability.py` (+ `run_paramgrid.ps1`) | M3 parameter plateau (needs MT5 grid) | grid on MT5 → `python3 paramstability.py grid.csv` |
| `cost_stress.py` | M4 cost/slippage stress | `python3 cost_stress.py trades.csv --cost-per-trade C` |
| `benchmark.py` | M7 matched-lot buy-hold + trend, MAR | `python3 benchmark.py PX.csv --strat-return R --strat-dd D` |
| `forensic_agent.py` (+ `hyp_good.json`) | governance: validates LLM hypotheses (budget/forbidden/root-order) | `python3 forensic_agent.py hyp.json` |

Verdicts: INSUFFICIENT · PASS · FAIL · REJECT · REGIME-ONLY. Any LLM hypothesis must re-enter the pipeline on fresh/untouched data.

## 4. Honest evidence reports
`SUBMISSION.md` · `CAPITAL_RETURN_SPEC.md` (why +$20k/yr not reachable under 0.09) ·
`MONTE_CARLO_STRESS.md` (DD risk 40-60%) · `OVERFIT_CHECK_RESULT.md` (tuned params = overfit, rejected) ·
`A_B_REGRESSION_RESULT.md` (execution-hardening ≡ v23) · `AUDIT_BUNDLE.md` (hashes/provenance) ·
`REGIME_TEST_RESULT.md` · `TFILTER_TEST_RESULT.md` (both filters rejected OOS).

## 5. Reproduce / verify
- Verify ledger integrity: `python3 SPEC/dof_ledger.py --file SPEC/dof_ledger.jsonl verify`
- Every result is hash-locked; no claim without its manifest. Numbers are real — no fabricated results.

## 6. Honest bottom line
Real, execution-safe Gold trend EA with a genuine risk-adjusted edge in-sample (beats buy-hold/trend on MAR),
but **thin & regime-dependent out-of-sample** (OOS PF ~1.13) with **large drawdown tail (40-60%)**.
Recommendation: continue demo-forward validation; size for deep drawdown; decide deployment only on
out-of-sample-consistent live evidence. **Demo-first. No real money yet.**

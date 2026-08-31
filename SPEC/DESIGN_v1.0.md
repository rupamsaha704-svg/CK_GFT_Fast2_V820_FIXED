# GOLD (XAUUSD) Strategy Validation — DESIGN v1.0 (LOCKED, red-team hardened)

Authoritative, ratified design. Scope: **XAUUSD only**. MT5 = deterministic real-tick executor.
Python = deterministic validator/measurement. Phase = research / demo / paper (NO real money).
Amendments: **prospective + versioned only**. Historical results may NOT be reinterpreted retroactively.

## 0. Governance (locked)
- **LLM discovers & explains. Deterministic code measures & judges. Locked unseen data = final evidence.**
- **No single metric = PASS.**
- Master rule: *No decision taken after seeing a result may cause that same result to be reused as
  "unseen evidence".*
- Boss = human ratifier (final authority). Kiro = implementation agent; may build but may NOT break this spec.

## 1. Verdicts
INSUFFICIENT · PASS · FAIL · REJECT · REGIME-ONLY (CONDITIONAL)
Order: Precondition fail → INSUFFICIENT; any Instant-REJECT → REJECT; all Mandatory pass → PASS;
mandatory-miss salvageable only by a leakage-free OOS-validated regime subset → REGIME-ONLY;
borderline/weak-sample → RETEST; else FAIL.

## 2. Evidence status vocabulary
- **VALID** — confirmatory use allowed
- **SPENT** — used once as valid evidence; no reuse (e.g. holdout after first unlock)
- **CONTAMINATED** — lost confirmatory independence via analysis/tuning exposure
- **INVALID** — hash/integrity/leakage/protocol failure; not acceptable

## 3. PASS MATRIX
### Precondition (missing → INSUFFICIENT/INVALID)
- P1 Version Integrity: source+input+dataset+config SHA-256 present & matching manifest
- P2 Min sample: >=200 OOS trades; >=30 per regime (>=50 preferred for REGIME-ONLY)
- P3 All required stages actually ran
### Instant-REJECT (any one → REJECT)
- K1 Look-ahead/leakage (uses info not available at decision timestamp)
- K2 OOS PF < 1.0 OR OOS expectancy <= 0
- K3 Severe IS→OOS collapse: (OOS_PF/IS_PF < 0.65) AND (OOS_exp/IS_exp < 0.50) with adequate sample
- K4 Not profitable at 1.0x realistic cost
- K5 Locked-holdout FAIL
- K6 Parameter lonely-spike (neighbourhood collapses)
- K7 Catastrophic-barrier breach probability >= 1% in stress-MC (barrier pre-declared)
### Mandatory (all must pass for PASS)
- M1 OOS PF >= 1.20 AND expectancy 95% CI lower-bound > 0 (>=200 OOS trades)
- M2 Walk-forward (frozen params, rolling OOS): >=60% windows net>0, median PF >=1.10,
     >=30 trades/window, >=8 usable windows (else INSUFFICIENT)
- M3 Parameter plateau: +/-2 steps per axis; >=80% neighbours PF>=1.0 AND neighbour-median expectancy>0;
     centre <= 1.30x neighbour-median; no cliff in any single axis
- M4 Cost/slippage stress: survives 1.5x baseline execution cost (net>0, PF>=1.0). Baseline =
     pre-declared broker spread+commission+swap+slippage. 2.0x = advisory red-flag only.
- M5 Performance concentration: after removing top-10 winners expectancy>=0 (and PF>=1.0 when >=200 trades)
- M6 Trade-removal stress: many deterministic-seeded runs dropping random 10%; >=95% runs net>0
- M7 Benchmark suite (matched-risk/exposure; Sharpe/Calmar/return-per-DD): beats a pre-declared canonical
     set — long-only XAUUSD baseline + simple-trend baseline + exposure-adjusted baseline. Dominated by a
     simple baseline → FAIL/RETEST.
- M8 Regime stability: performance not concentrated in one calendar year / one volatility episode
### Advisory (informs sizing/CONDITIONAL; never auto-fails)
- longest losing streak, recovery time, MC adverse-percentile equity DD, benchmark beta/correlation
- Confidence is reported LOW/MED/HIGH (evidence strength) and is NEVER a PASS/FAIL input

## 4. Regime classifier — leakage-free spec
- At decision time t, classifier uses only info truly known at t. No future candle/high/low/ATR/swing/
  ZigZag pivot as a feature. Closed-bar → last completed bar; intrabar → up to current tick.
- Future-derived labels allowed ONLY to build training ground-truth, never as a feature.
- Scalers/normalizers/thresholds fit on TRAINING fold only; OOS/holdout only transformed. WF retraining
  schedule pre-declared. HMM/similar: live-equivalent FILTERED state only (no future-smoothed state).
- REGIME-ONLY approval requires: classifier frozen & pre-registered BEFORE gating tests; OOS-proven that
  gating improves expectancy, cuts DD/false-trades, repeats across multiple WF windows; >=50 OOS trades
  per claimed regime preferred (<30 → INSUFFICIENT). Classifier itself is a trial in the ledger; one per cycle.

## 5. Forensic Agent
- Read-only over deterministic reports/manifest/verdict. Output = hypotheses only.
- Never edits thresholds, OOS split, holdout, PASS/FAIL, code/config; cannot peek sealed holdout;
  cannot trigger experiments that alter the frozen build.
- Root-cause order (must follow): 1 Data/integrity → 2 Execution/coding → 3 Sampling/concentration →
  4 Regime-specific → 5 Strategy-logic → 6 only then propose modification.
- Per-hypothesis required fields: observation(evidence ref) · proposed mechanism · falsifiable prediction ·
  **null hypothesis** · exact experiment(gate+params) · true-vs-false signal · **data-exposure count** ·
  **kill criterion** · priority · confidence(LOW/MED/HIGH).
- Multiple-testing budget per research cycle: **3 Primary (formally testable) + 2 Exploratory (log-only)**;
  hard ceiling 5; decision budget 3. 3 Primary tested → dataset CLOSED for further confirmatory hypotheses.
- Corrections: Holm-Bonferroni (formal p-family, preferred) · Deflated Sharpe (trial-inflated Sharpe) ·
  PBO (selection overfit). None replaces Locked OOS/holdout.

## 6. Red-team guards (LOCKED)
1 Cumulative global exposure ledger (dataset change ≠ history reset)
2 Version-lineage survivorship (FIX09→10→11 = one research family; counts to DSR/PBO)
3 Holdout correlation leakage → non-overlap + purge/embargo + genuinely-future/untouched
4 INSUFFICIENT ≠ deploy; converts to PASS/FAIL/REJECT after pre-defined data accrual
5 Amendment gaming → amendments prospective only; never retroactively rescue a seen failure
6 Benchmark/cost gaming → pre-declared canonical baselines, not tuned to be easy
7 Repaint/non-causal → recorded signal = info available at decision timestamp; completed-bar value immutable
8 Run cherry-pick/demo reset → append-only chained-hash log of ALL runs; logged crash-restart OK, manual reset/selection = contamination
9 Regime-classifier selection overfit → frozen+pre-registered, counts as trial, one per cycle
10 Metric-definition drift → Metric Dictionary hash-lock (PF, equity DD, expectancy, timezone, session
   boundaries, trade counting, partial-close, commission/swap). Change only via version bump.
11 Preprocessing leakage → fit on training portion only; OOS/holdout transform-only
12 Risk/exposure gaming → version compare must report return, equity DD, exposure/time-in-market,
   avg risk/trade, gross notional, return/DD, expectancy-per-unit-risk. More return from more risk ≠ edge.
13 Random-seed cherry-picking → seeds & sim-count pre-declared; aggregate percentiles; no favourable-run select
14 Optional stopping / demo timing → pre-lock min duration, min trades, review dates, termination condition
15 Date/regime exclusion gaming → all exclusions pre-declared; post-hoc exclusion = exploratory only, cannot
   rewrite current version's historical score
+ Master guard: **every analytical choice = a researcher degree of freedom, logged in the global ledger**
  (feature added, filter tried, regime def changed, date range changed, SL/TP altered, benchmark changed,
   cost assumption changed, classifier changed, hypothesis tested, version created).

## 7. Contamination rulebook (LOCKED)
- DATASET → CONTAMINATED/closed: 3 Primary tested; post-hoc exclusion/param re-scored on same data;
  preprocessing fit-then-reused; exploratory peeked (can't become Primary on same data);
  pre-declared exposure budget exceeded (else DoF feeds PBO/DSR — no post-hoc ceiling).
- HOLDOUT → SPENT at first unlock (one frozen evaluation); tuning after unlock → CONTAMINATED + version dead;
  hash mismatch → INVALID.
- VERSION → dead: holdout FAIL (→ new version + new untouched evidence); leakage found → INVALID/REJECT, fix
  = new version (FIX11), not in-place; missing valid manifest hashes → INVALID; run cherry-pick/hidden runs → CONTAMINATED.
- FORWARD/DEMO → INVALID run: manual reset/history-discard/multi-demo-select; mid-test param/logic change;
  optional-stopping outside pre-declared plan; unlogged restart (logged crash-restart with reason+gap+state OK).
- G1 Holdout family (FIX10A/B/C): pre-register + freeze before unlock; family size in ledger + correction;
  no new variant after seeing; unlock spends holdout for whole family.
- G2 Historical-data revision: broker history change → hash change → data-version-specific; new history =
  new manifest + rerun (old evidence not "fraud", just not comparable).
- G3 Metric/code change: validator version/hash changes; recompute affected evidence; no silent overwrite.
- G4 Hidden manual cleaning (bad tick/glitch removed after seeing result) = CONTAMINATED unless cleaning
  rule pre-declared and raw→clean transformation audit-logged.

## 8. FIX09 status
Post-hoc evaluated (results already seen → not truly pre-registered). Current: **RETEST / possibly
REGIME-ONLY candidate** — thin OOS edge (PF~1.13), large MC drawdown warning (47–61%). NOT a PASS.
Frozen for demo/forward as locked evidence. Any improvement idea → hypothesis → dev test → if proven → FIX10
with its own fresh independent forward test. Pre-registered criteria apply from FIX10 onward.

## 9. Build order (implementation)
1 Baseline freeze: this spec + hash + manifest + global DoF ledger (THIS STEP)
2 Deterministic stages one by one, each with pre-declared thresholds & PASS/FAIL
3 Forensic Agent last (hypotheses only, ledger-bound)

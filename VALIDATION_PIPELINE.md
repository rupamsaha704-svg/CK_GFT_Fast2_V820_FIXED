# Validation Pipeline + Forensic Agent — agreed architecture

## Governing rule
**LLM discovers and explains. Deterministic code measures and judges.**
The LLM never changes a PASS/FAIL. It only proposes hypotheses/experiments. A change is an "edge"
ONLY after it survives unseen data in the deterministic pipeline.

## A) Deterministic pipeline (all code; same input => same output; owns PASS/FAIL)
```
MT5 BACKTEST
  -> Deterministic Parser        (trades, deals, journal -> structured)
  -> Journal Analysis            (errors / rejects / retcodes)
  -> Loss-by-Time / Session / Regime
  -> MFE / MAE / Exit Analysis
  -> Locked OOS                  (period never used for tuning)
  -> Walk-Forward                (rolling IS->OOS)
  -> Monte Carlo / stress        (shuffle + bootstrap; DD & return distribution)
  -> Spread / Slippage / Missed-trade stress
  -> Parameter neighbourhood stability  (nearby params must not collapse)
  -> Locked Holdout              (final untouched slice)
  -> PASS / FAIL
```
Overfit is judged by the COMBINATION, not any single test:
Locked-OOS + Walk-forward + parameter-neighbourhood stability + MC/stress + IS->OOS degradation +
(where enough data) CPCV / PBO / Deflated Sharpe.

## B) ONE Forensic Analyst agent (LLM) — hypotheses only
- Input: the deterministic results above (read-only).
- Output: written hypotheses + which experiment to run next. Example:
  "Loss clusters in the first 20 min of London open (false breakouts) — test that filter in isolation."
- HARD limits: cannot edit PASS/FAIL, cannot declare a change 'better', cannot auto-tune. Every idea it
  raises must go back THROUGH the deterministic pipeline (incl. OOS) before it counts.

## Status
Already built (reuse, don't rebuild):
- Journal analysis .......... run_journal.ps1 / all-in-one journal extract
- Loss-by-Time/Session/Regime  Python trade-analysis (done ad hoc; fold into pipeline)
- Monte Carlo / stress ...... MONTE_CARLO_STRESS.md (shuffle + bootstrap)
- Locked OOS + IS/OOS degrade  run_overfit_check.ps1 (2x2 IS vs OOS)

To build (in priority order):
1. Single ORCHESTRATOR that chains the existing stages and emits one PASS/FAIL report.
2. Missing deterministic stages: MFE/MAE-exit analysis, Walk-Forward, parameter-neighbourhood stability,
   spread/slippage/missed-trade stress, locked holdout, and CPCV/PBO/Deflated Sharpe (Vibe quantlib)
   where data is sufficient.
3. THEN the single Forensic Analyst agent (hypotheses only), reading the orchestrator report.

## Non-negotiable
- No "auto-tune until profit" loop — that is an overfitting machine.
- Backtest != live. The final accuracy test is DEMO / forward / paper, not any backtest agent.
- "Perfect accuracy" is not a goal (markets are non-stationary); the goal is a real edge that survives
  unseen data with tolerable drawdown.


## FREEZE & separation discipline (locked rule)
- **CK_GOLD_PRO_FIX09 is FROZEN** during its demo/forward test. No parameter or logic change while it
  runs — otherwise the forward test becomes optimization data and is worthless as evidence.
- **Demo = locked evidence. Development data = separate.** They must never mix. This separation is the
  single biggest protection against overfitting.
- If the deterministic pipeline (incl. OOS) proves a real improvement from a Forensic-Agent hypothesis,
  it becomes a **NEW version (FIX10)** which starts its **own fresh, independent forward test**. You do
  not "patch" the frozen build mid-test.
- **No real-money deployment in this phase** — demo/paper forward validation only.

## Parallel plan (chosen: C, with the discipline above)
- Track 1 (today): start FIX09 demo/forward test, FROZEN (install_fix09_demo.ps1).
- Track 2 (in parallel): build the Orchestrator. Step 1 done (v1_lab/orchestrator.py: basic stats +
  loss-by-time/session/day/month + Monte Carlo + IS->OOS + deterministic PASS/FAIL; requires OOS to PASS).
  Next: add MFE/MAE-exit, Walk-Forward, parameter-neighbourhood stability, spread/slippage/missed-trade
  stress, locked holdout, CPCV/PBO/Deflated Sharpe. THEN one Forensic Analyst agent (hypotheses only).


## Ordered stages (locked) + threshold-integrity rule
```
FIX09 FROZEN DEMO ─► evidence accrues
DEV/VALIDATION DATA ─┘
        ↓ ORCHESTRATOR
  ① Evidence Manifest / Hash   (manifest.py)      ← FIRST (provenance)
  ② Walk-Forward consistency   (walkforward.py)   [frozen params, rolling OOS - NOT re-optimization]
  ③ Parameter stability        (paramstability.py + run_paramgrid.ps1)
  ④ MFE / MAE exit analysis     (to build)
  ⑤ Spread / slippage / missed-trade stress (to build)
  ⑥ Locked holdout              (to build)
  ⑦ CPCV / PBO / Deflated Sharpe (Vibe quantlib, where data sufficient)
        ↓ PASS / FAIL
```
- **All PASS/FAIL thresholds are PRE-DECLARED in code/config BEFORE looking at results.** Thresholds are
  never changed after seeing a result (that would be fitting the test to the answer).
- **Hard rule:** the LLM / Forensic Agent can NEVER edit validation thresholds, the OOS split, the locked
  holdout, or any PASS/FAIL. It reads results and proposes hypotheses only.
- Clarification recorded: classic "walk-forward optimization" (re-optimize each fold) is a parameter-
  SELECTION tool; since our discipline is frozen params (no optimization), stage ② is rolling OOS
  consistency of the frozen params. Re-optimization WF would re-introduce the overfit we are avoiding.
- Built so far: ① manifest.py, ② walkforward.py, ③ paramstability.py (+ run_paramgrid.ps1). Tested on
  local trade data. ④–⑦ next.

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

# XAUUSD Algo Strategy — Submission Summary

**Scope:** XAUUSD (Gold) only · MT5 real-tick validated · MaxLot 0.09 (hard-locked) · research/demo phase (no real money yet)
**Deliverable EA:** `CK_GOLD_PRO_FIX09` v1.03 (execution-hardened trend system, fixed 0.09 lot)

---

## 1. What was delivered
- A validated, execution-hardened **XAUUSD M15 trend EA** (`CK_GOLD_PRO_FIX09`), fixed **0.09 lot**, with 6
  live-safety fixes (price-based spread, verified fills, broker filling mode, sub-min-lot skip, persisted
  daily state, magic-scoped daily P/L, market-session guard). Clean tester journal, deterministic.
- A full **institutional-grade validation framework** (Design v1.0) governing how any strategy is judged.
- A **frozen demo / forward test** started today (8-week protocol, hash-logged).

## 2. Backtest result (real ticks, 2025-08 → 2026-08, $5,000)
| config | return | PF | closed-DD | trades |
|---|---|---|---|---|
| deploy (fixed 0.09) | **+204%** | 1.50 | 16.1% | 284 |

## 3. Honest validation findings (this is the important part)
- **Out-of-sample (2022–2025, 3 yr): edge is thin — PF ~1.13.** The +204% is a *favourable trending year*,
  NOT a repeatable annual figure. Earlier multi-year (2015–2018) showed losses → **regime-dependent**.
- **Monte Carlo (10k sims): drawdown risk is materially higher than the observed 16%** — realistic 25–47%,
  worst-case up to ~61%; at fixed 0.09 the swings roughly double. Plan for **40–60% drawdown, not 16%**.
- A parameter-optimised variant (EntryEMA21/Age9/BE0.44) looked great in-sample (+PF to 1.84) but was shown
  to be **mostly overfit** (OOS gain negligible) and was **rejected**; original non-overfit params kept.
- ~14 loss-reduction filters and a regime gate were tested and **rejected** (overfit / OOS-fail).
- **Current honest verdict: RETEST / possibly REGIME-ONLY candidate — NOT a guaranteed edge, NOT a PASS.**

## 4. On the profit target (documented, evidence-based)
- With MaxLot 0.09, the single-EA dollar output saturates (~$8–10k in the best tested year); **$20k/yr
  (+400%) is not achievable from this one EA under the 0.09 constraint** — measured, not assumed.
- We deliberately did **not** chase +200/400/600% by raising risk or overfitting, because that destroys
  live accounts. Numbers presented are real; no fabricated results.

## 5. Validation framework (the professional backbone)
Deterministic pipeline owns PASS/FAIL; an LLM "forensic" layer only suggests hypotheses. Includes:
PASS matrix (Precondition / Instant-REJECT / Mandatory / Advisory) · leakage-free regime spec ·
multiple-testing budget (3 primary + 2 exploratory) · 19 red-team anti-overfit guards ·
contamination rulebook · **hash-chained researcher-degrees-of-freedom ledger** (tamper-evident).
Governing rule: *LLM discovers & explains; deterministic code measures & judges; locked unseen data = final evidence; no single metric = PASS.*

## 6. Current status & recommendation
- **Running now:** frozen 8-week demo/forward test on XAUUSD M15 (started, hash-logged; min 8 weeks + 40 trades before any verdict).
- **Recommendation:** continue demo/forward validation; size for a possible 40–60% drawdown; decide on
  (reduced-size / regime-gated) deployment only after out-of-sample-consistent live evidence. **Demo-first;
  no real money until forward evidence holds.**

## 7. Evidence / audit trail
- Repo branch: `kiro/validation-toolkit` (all code, results, and this summary).
- Key docs: `DESIGN_v1.0.md`, `CAPITAL_RETURN_SPEC.md`, `MONTE_CARLO_STRESS.md`, `OVERFIT_CHECK_RESULT.md`,
  `A_B_REGRESSION_RESULT.md`, `AUDIT_BUNDLE.md`, `SPEC/dof_ledger.jsonl` (hash-chained, integrity-verified).
- Everything is hash-locked and reproducible; no result is claimed without its manifest.

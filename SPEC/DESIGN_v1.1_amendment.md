# DESIGN v1.1 — Amendment: non-stationarity & current-regime evidence (PROSPECTIVE)

Rationale: markets are non-stationary (structural shifts every few years). Demanding robustness across a
structurally-DIFFERENT past regime can be unfair to a valid current-regime edge. BUT "only recent data
counts" is the classic overfitting rationalisation. This amendment rebalances the EVIDENCE HIERARCHY
WITHOUT weakening anti-overfit discipline. Prospective only; it does NOT change any v1.0 verdict
(FIX09 dev-FAIL stands as recorded).

## Evidence hierarchy (amended)
1. **PRIMARY — forward / demo evidence in the CURRENT regime** (genuinely unseen, forward in time). This
   is the correct test for a changing market. MANDATORY before any PASS or real-money consideration.
2. **SUPPORTING — recent-weighted walk-forward** on data NOT used to build/tune the strategy.
3. **CONTEXT (not a pass/fail hammer) — older-history OOS.** A strategy that fails ONLY in a structurally
   different past regime is NOT auto-rejected; but it also CANNOT PASS on a recent backtest alone.

## New verdict tier: CURRENT-REGIME CANDIDATE
A strategy showing edge consistent with the current regime MAY be labelled **CURRENT-REGIME CANDIDATE**
and approved ONLY for forward/demo evidence-gathering **at minimal size**. It is NOT a PASS. It becomes
PASS only after pre-declared forward evidence (duration + trades) holds in the current regime.

## Anti-overfit guards (retained/strengthened — so "recent" != overfit)
- The window used to BUILD/TUNE a strategy is NEVER its own current-regime evidence (in-sample forbidden).
  => FIX09's 2025-26 is in-sample; it is NOT valid current-regime evidence. The LIVE DEMO is.
- "Current regime" must be defined OBJECTIVELY and pre-declared: a rolling trailing window (default: last
  12 months) OR forward-from-now demo — never cherry-picked to look good.
- Minimum recent sample still required (else INSUFFICIENT). Forward confirmation MANDATORY.
- NO tuning to the recent/forward window (that re-introduces overfit). All existing red-team guards,
  budgets, contamination rulebook, and the hash-chained ledger still apply.
- Structural-break claims must use an OBJECTIVE, pre-declared detector — not narrative ("2024 was unusual").

## Effect on FIX09 (honest, unchanged verdict + new framing)
- v1.0 dev-verdict (FAIL on older/recent OOS) STANDS and is not reinterpreted.
- Under v1.1 framing, FIX09's thin older-OOS is CONTEXT; its live status is **"CURRENT-REGIME CANDIDATE
  under live forward validation"** (the running 8-week frozen demo) — NOT a validated edge, NOT
  real-money-ready. No in-sample (2025-26) result counts as forward evidence.
- If the frozen demo shows current-regime edge consistent with the pre-declared protocol, it advances;
  if not, it is done. Size stays minimal until forward evidence holds.

Amendment status: PROSPECTIVE, hash-locked in the ledger. Supersedes nothing retroactively.

# Regime-gate (pre-registered EMA200-slope, K=0.5/N=20) — CONSISTENCY CHECK: REJECTED

Fixed 0.09, all params pinned. Same pre-registered gate, two periods:

| period | OFF (FIX09) | ON (regime gate) | gate effect |
|---|---|---|---|
| OOS 2022-25 | PF 1.13, DD 24.0%, exp 3.26 | PF 1.22, DD 14.6%, exp 5.31 | HELPS |
| IS 2025-26  | PF 1.47, DD 16.3%, +200% | PF 1.04, DD 46.5%, +10.5% | DEVASTATES |

## Verdict: REJECTED (period-dependent, fails SPEC §4 consistency)
The gate's benefit flips sign by period: it improves 2022-25 but destroys 2025-26 (return +200%→+10.5%,
drawdown 16%→46.5%). REGIME-ONLY approval requires consistent improvement across multiple windows; this
is the opposite of consistent. Not a robust FIX10.

## Why this matters (discipline working)
Judged on the 2022-25 OOS window alone, the gate looked like a clear win (PF↑, DD halved) and could have
been shipped as "FIX10 REGIME-ONLY". The cross-window consistency check (a single extra window) exposed
that it would have caused a 46.5% drawdown in 2025-26. A single OOS window is NOT enough — exactly the
failure mode DESIGN v1.0 was built to prevent.

## Standing conclusion
- FIX09 frozen: real in-sample edge, not overfit-fragile, but OOS thin/concentrated/cost-sensitive (dev FAIL).
- Tuned params (21/9/0.44): overfit (rejected).
- Regime gate: period-dependent (rejected).
- ~14 earlier loss-reduction filters: rejected.
Converging honest finding: **this single XAUUSD trend strategy does not have a robust, consistent
out-of-sample edge.** The value delivered is (a) a rigorous, auditable validation framework that
correctly refuses to certify it, and (b) an honest, non-fabricated assessment. No real money.
Genuinely different edges (a portfolio of independent strategies) would be a SEPARATE research project,
not another tweak to this one.

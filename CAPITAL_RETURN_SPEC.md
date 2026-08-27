# Capital / Return / Drawdown Specification — reframing the objective

Agreed pivot: stop chasing headline % (+200/+400/+600). First prove the edge is **repeatable,
drawdown-tolerable, execution-stable, and survives unseen data**. Set capital/return targets from
that — not the other way round.

## The hard constraint that changes the math: MaxLot 0.09

Return does NOT scale with risk, because the 0.09 lot cap binds above ~1% risk (same real-tick year,
$5,000, XAUUSD M15):

| risk% | net $ | return% | scaling |
|---|---|---|---|
| 0.5% | $5,760 | +115% | risk ×1.0 → return ×1.00 (lot ≈0.035, below cap) |
| 1.7% | $8,050 | +161% | risk ×3.4 → return ×**1.40** (cap binds → saturates) |

If sizing were uncapped, 3.4× risk should ≈3.4× return. We see ~1.4×. **The 0.09 cap limits the
strategy's absolute $ output**, not just its %.

### Consequence (this is the key finding)
- With MaxLot 0.09, this single EA's **maximum $ output in the best tested year ≈ $8–9k** — and this
  ceiling is roughly independent of account size and risk%, because once every trade is at 0.09 lot,
  more capital / more risk% adds nothing.
- Therefore **$20,000/year from this one EA under MaxLot 0.09 is not achievable — at any capital or
  risk — even in the best tested year.** More capital only lowers the % (same $ output on a bigger base).

## What $20k/year would actually require

| path | what it needs | verdict vs constraints |
|---|---|---|
| Raise lot cap (e.g. ~0.22+) | violates the hard MaxLot 0.09 rule | ❌ breaks constraint |
| More capital, same EA | doesn't help — 0.09 caps the $ output | ❌ math doesn't work |
| Multiple UNCORRELATED EAs/instruments | 2–3 independent edges each ~$8k | ⚠️ we tested ~18 alts; most rejected/weak; only 1–2 had low correlation but too weak alone |
| Accept a lower, honest target | e.g. protect capital + compound over years | ✅ defensible |

## The other reason not to annualize +115–161%
This is a **single-year sample** and the strategy is a **trend specialist**: walk-forward showed strong
H1 / weak H2, and a multi-year run (range-era years) showed **losses**. So +115–161% is a *good
trending year*, NOT a reliable annual expectation. A defensible plan must budget for **flat or losing
years** and drawdowns in the ~20–40% range (equity DD to be measured, not the 18.6% closed-trade figure).

## Defensible objective (proposed)
1. **Forward-test on DEMO** (or micro-live) for a meaningful window to get an *out-of-sample* estimate
   of the real repeatable return and the true equity drawdown.
2. Only after OOS confirmation, size capital to a **realistic** target. If a good trending year yields
   ~$8k at 0.09 on this EA, then a defensible annual *planning* figure is well below that once
   losing/flat years are averaged in.
3. If $20k/year is a firm requirement, the honest route is a **portfolio of uncorrelated edges** or a
   revised lot constraint — a separate research project, not a tweak to this EA.

## What this project HAS delivered (defensible)
- One validated trend EA (v23) + an execution-hardened build (v23_live) with an audited A/B
  (exit-level identity, provenance hashes in AUDIT_BUNDLE.md).
- Honest boundaries documented (DEFENSIBLE_SUMMARY.md): no edge-improvement claim, no extrapolation,
  DD-by-type pending, entry-level diff pending.

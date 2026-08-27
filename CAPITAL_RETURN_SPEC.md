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

Dollar profit scaled **far less** than the risk increase (0.5%→1.7% = ×3.4 risk, only ×1.4 $). This
is **strong evidence of cap saturation** — MaxLot 0.09 is materially limiting position-size growth in
the tested configs.

**Careful wording (not over-claimed):**
- We can NOT say "uncapped return would have been ×3.4." Even without the cap, scaling is nonlinear
  because of compounding, daily ±R gates, trade sequencing, and the changing balance.
- We can NOT yet call ~$8–9k an *absolute annual ceiling*. Changing risk% changes `g_oneR_money`,
  which shifts when the daily loss/profit gates fire, which can change trade count and path. The true
  economic ceiling of the 0.09 cap needs the Phase-2 study below (capped-trade frequency + daily-gate
  interaction across the full risk range) before any ceiling number is stated.

### What IS defensible right now
- In the tested configurations, MaxLot 0.09 materially caps dollar output (strong saturation evidence).
- So raising risk% is not a reliable path to much higher $ profit, and "$20k/year" is very unlikely to
  be reachable from this single EA under 0.09 — but the exact ceiling is to be measured, not asserted.

## What $20k/year would actually require

| path | what it needs | verdict vs constraints |
|---|---|---|
| Raise lot cap (e.g. ~0.22+) | violates the hard MaxLot 0.09 rule | ❌ breaks constraint |
| More capital, same EA | 0.09 cap limits $ output in tested configs (exact ceiling TBD in Phase 2) | ⚠️ likely insufficient — measure first |
| Multiple UNCORRELATED EAs/instruments | 2–3 independent edges | ⚠️ we tested ~18 alts; most rejected/weak; only 1–2 had low correlation but too weak alone |
| Accept a lower, honest target | protect capital + compound over years | ✅ defensible |

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

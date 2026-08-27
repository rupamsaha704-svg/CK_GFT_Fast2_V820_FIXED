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

### MEASURED cap-saturation evidence (Phase 2, risk 1.7%, real ticks, $5000)
Instrumented run (CK_GFT_v23_capstudy) logged per-trade intended vs actual lot:

| metric | value |
|---|---|
| trades | 274 |
| capped at 0.09 | **274 (100%)** |
| sum INTENDED risk $ (1.7% sizing) | $48,596 |
| sum ACTUAL risk $ (after 0.09 cap) | $3,580 |
| **risk actually realised** | **7.4% of intended** |
| net profit | $8,050 |

**What this measures (no longer asserted):**
- At 1.7%, the cap binds on **every** trade; the account's *effective* per-trade risk is ~0.26%
  (≈13.5× smaller than the 1.7% label). The "1.7% risk" setting is largely fictional under 0.09.
- Because all trades are **already at the 0.09 ceiling at 1.7%**, raising risk to 2.0% cannot increase
  per-trade size — dollar output stays ≈$8k (only daily-gate-driven trade-count shifts are possible).
  So a "+200% at 2.0%" outcome is **not supported** by this cap; it would need re-measurement to claim.
- Combined with the 0.5% run ($5,760, not fully capped) and the 1.7% run ($8,050, fully capped), the
  single-EA dollar output under 0.09 **plateaus around ~$8k in this trending-year sample**. This is the
  measured economic ceiling of this EA under the 0.09 constraint — not an assertion.
- Upside: the cap makes the *realised* risk very conservative (~0.26%/trade), which is why drawdown is
  contained. The return is being produced at low actual risk.

### Conclusion for the $20k question (now evidence-based)
$20k/year from this single EA under MaxLot 0.09 is **not reachable** — measured, not assumed. Raising
risk% does not help (already 100% capped at 1.7%). The only honest routes remain: relax the lot
constraint (breaks the rule) or build a portfolio of uncorrelated edges (Phase 3).

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

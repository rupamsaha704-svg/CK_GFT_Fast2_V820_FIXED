# System Design Principles — retained guidance (curated for THIS project)

Kept because these align with what we already proved empirically. Each item is annotated:
**[PROVEN]** = we already have evidence for it here; **[FUTURE/OOS]** = a valid experiment that must
pass the evidence gate before use. Implementation stays **deterministic & evidence-based** — NOT an
LLM/multi-agent swarm (that infra was rejected earlier as unreliable; "agents" below = validated code
modules / rules).

## 1. Market Regime Detection — **[PROVEN need]**
Classify market at least as Trend / Range / High-Vol / Low-Vol; measure each strategy's performance
per regime. *Why it matters here:* v23 is empirically a trend specialist — strong in trending H1, and
a multi-year run showed losses in range-era years. Regime awareness is the single most important
missing piece. Highest priority for any portfolio work (Phase 3).

## 2. Volatility-Adaptive Logic — **[FUTURE/OOS]**
Use ATR / StdDev to gauge expansion vs compression; let breakout/trend weight rise in high vol,
mean-reversion in low/ranging vol. Weights must come from historical OOS evidence, not opinion.

## 3. Mean-Reversion / Extension Detection — **[PARTLY TESTED]**
On statistically abnormal moves, test continuation vs reversal probabilities separately (Z-score /
StdDev / ATR extension), as both an entry filter and an exit/target rule. *Note:* a standalone StdDev
mean-reversion variant was already tested here and rejected on its own; the principle of separate
continuation-vs-reversal testing is retained.

## 4. Dynamic Strategy Selection — **[= Phase 3, deterministic]**
Specialists (trend, mean-reversion, etc.) should not all be active at once; a regime module picks the
one historically most reliable for the current regime, and disables/low-weights weak ones. Implement
as deterministic, validated rules — not an LLM decision layer.

## 5. Risk First — **[PROVEN policy]**
Set max acceptable risk before signal; a risk layer can reject trades on spread, volatility, drawdown
state, losing streak, execution condition. Raising risk to show more return is **not** an improvement.
*Already our policy;* the cap-study also showed realised risk is ~0.26%/trade at the 1.7% label.

## 6. Adaptive Target / Profit Capture — **[FUTURE/OOS]**
Don't blindly use fixed 3R everywhere; estimate a statistically realistic target from historical MFE /
ATR / StdDev / structure, and compare fixed vs adaptive targets in OOS / Walk-Forward.

## 7. Evidence Requirement — **[PROVEN bar — this is our gate]**
No new logic enters the system until it passes: Backtest → OOS → Walk-Forward → Monte Carlo →
Stress Test → Regime Test. Backtest profit alone is not proof; paper/incubation (DEMO) is required
before any live-usefulness claim. *This is exactly the standard v23 was held to.*

## 8. Final Design Principle — **[PROVEN stance]**
The goal is NOT to add more strategies — it is to keep only independently-proven specialists and use
the right one for the current regime.

## Implementation priority (when/if we build the portfolio)
Regime Detection → Strategy Specialists → Evidence-Based Weighting → Adaptive Target → Risk Judge →
Validation. Build each specialist only after it independently clears the Item-7 evidence gate.

---
**Scope note:** this is forward-looking design guidance, not a mandate to build now. Current
deliverable remains v23_live + Phase-1 DEMO/OOS validation. Anything above is Phase-3 territory and
must clear the evidence gate first.

# Regime-gate loss-reduction experiment — REJECTED

Hypothesis: an evidence-motivated HTF-EMA200-slope trend-regime gate (only trade when EMA200 has moved
≥ 0.5×HTF-ATR over 20 bars) would cut range-regime losses on v23.

## Result (same real ticks, risk 1.7%, $5000, 2025.08→2026.08)
| | trades | net | return | PF | closed DD |
|---|---|---|---|---|---|
| regime OFF (= v23 baseline) | 274 | +$8,050 | +161% | 1.39 | 18.6% |
| regime ON | 144 | −$1,492 | −30% | 0.88 | **56.9%** |

## Verdict: REJECT (decisive, in-sample — no OOS needed)
The gate removed 130 trades and turned +161% into −30%, with drawdown rising to 56.9%.

## Why (the lesson)
v23's large winners occur when the EMA200 slope is NOT yet strong — i.e. at the *start* of a move out
of a range. Requiring an already-confirmed trend makes entries late and filters out the big runners
that carry the profit factor, while the choppy small losers remain. The filter cut the winners and
kept the losers — the opposite of the goal.

## Standing conclusion
This is ~the 13th loss-reduction filter to fail on v23 (after ADX filter, regime-sizing, loss-hour
block, candle-confirm, DD-breaker, etc.). v23's edge is intrinsic and fragile to entry filtering; the
many small losses are the structural cost of catching the few large trend winners. Capital protection
is already provided by MaxLot 0.09 (realised risk ~0.26%/trade), daily ±R gates, and break-even — not
by adding entry filters. Do not bolt further discretionary filters onto v23.

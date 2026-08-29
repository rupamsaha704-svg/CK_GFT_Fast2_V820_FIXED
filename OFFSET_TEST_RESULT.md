# Pullback-Offset Entry Hypothesis — Test Result (CLOSED)

**Hypothesis (user):** Gold gets stop-hunted — price hits our SL first, then goes to TP.
Fix: enter at an *offset better price* (BUY at Ask − $X, SELL at Bid + $X) via limit order,
and move SL accordingly, so entries survive the hunt.

**Variant:** `CK_GOLD_PRO_OFFSET.mq5` (separate EA — FIX09 was NOT edited).
Pre-registered before any result: ledger seq18. Every strategy param pinned (guard #20).

## In-sample (2025-26) — EXPLORATORY only, NOT evidence

| offset | trades | return | PF | DD (closed) | expectancy |
|---|---|---|---|---|---|
| FIX09 (0) baseline | 280 | +200% | 1.47 | 16.3% | — |
| **$2.0** | 249 | **+202%** | **1.57** | **15.9%** | $40.6 |
| $3.0 | 224 | +168% | 1.53 | 20.3% | $37.5 |
| $4.0 | 199 | +128% | 1.47 | 28.1% | $32.1 |

Monotonic: larger offset → worse. Best = **$2.0** (marginally beats FIX09 in-sample).
Ledger: seq20 (prereg $2/$3), seq21 (IS results).

## The real test — OOS 2022-25, deterministic pipeline (Design v1.0)

Best in-sample offset ($2.0) was carried, un-tuned, to the locked out-of-sample period
and run through the same pipeline that FAILed FIX09 and REJECTed the tuned params.

| Gate | FIX09 | Offset $2.0 |
|---|---|---|
| OOS PF | 1.13 | 1.18 |
| OOS expectancy | $3.26 | $4.21 |
| M4 cost-stress @1.5x | FAIL | **PASS** (net 184, PF 1.02) |
| M1 (OOS PF≥1.20 & exp-CI lower-bound>0) | FAIL | FAIL (PF 1.18; exp95CI [-4.38, 13.64]) |
| M5 (drop top-10 winners) | FAIL | FAIL (exp −5.17, PF 0.78) |
| M8 (max single-year share <80%) | FAIL | FAIL (89% in one year) |
| K3 IS→OOS collapse | clear | clear (PFratio 0.75, not a collapse) |
| WF (≥60% pos, med≥1.10, ≥8 wins) | — | 6/8 pos, med 1.16, worst 0.42 |
| **VERDICT** | **FAIL** | **FAIL** |

Ledger: seq22.

## Conclusion

Offset $2.0 is *slightly* more robust than FIX09 (higher OOS PF/expectancy, and it survives
cost-stress). The user's read that a large offset was too much was correct — $4 was clearly worst.

**But even the best offset fails the same mandatory robustness gates:** the out-of-sample edge is
carried by a handful of big winners (M5) and concentrated in one calendar year (M8), and OOS PF
sits just under the 1.20 bar with an expectancy confidence interval that still crosses zero (M1).

**Decision:** the pullback-offset hypothesis is FORMALLY CLOSED. It does not produce a robust,
deployable out-of-sample edge. No further offset tuning will be done — chasing a better in-sample
number by nudging the offset is exactly the overfitting we have rejected repeatedly.

The frozen `CK_GOLD_PRO_FIX09` (fixed 0.09 lot, XAUUSD, real ticks), currently in an 8-week DEMO
forward test, remains the honest submission. Its dev-verdict is on record as FAIL for older-OOS
robustness (`FIX09_DEV_VERDICT.md`); the forward/current-regime test is the primary evidence per
Design v1.1.

# PREREG — CK_GOLD_DONCHIAN_20 — Classic Donchian 20-bar breakout on XAUUSD M15

**Status:** pre-registered 2026-09-21 (ledger seq287). Follows steering §5.

**Motivation:** After 16 REJECTs on gold (mean-reversion / volume-profile / range
fade patterns), the only surviving edge is TREND (steering §5). This test checks
whether a **pure Donchian breakout** — the classic Turtle Traders' entry — offers
a differentiated trend-following edge on XAUUSD that's NOT already covered by
FIX09's H1-trend + M15-pullback pattern.

**Difference from existing CK_GOLD_COMBO (FIX09 sleeve):**
- FIX09 waits for M15 pullback to EMA20 after breakout → better fill, may miss
- Donchian enters IMMEDIATELY on 20-bar close breakout → captures every trend
- FIX09 requires H1 EMA200 trend confirmation → filters counter-trend attempts
- Donchian has no trend filter → trades all breakouts, symmetric long/short
- FIX09 exits at 3R with BE @ 0.5R → smoother P&L
- Donchian exits at 3R or 10-bar counter-breakout (whichever first)

Different signal, different fill quality, different exit mechanism → truly
independent from FIX09 even though same "trend continuation" family.

## Rules (v1 — LOCKED)

### Entry signals (evaluated at M15 bar close)

- **LONG**: `close[1] > highest(close, 20, shift=2)` — bar 1 close broke above
  the highest of the prior 20 bars (starting at bar 2, so bar 1 itself doesn't
  count in the reference set).
- **SHORT**: `close[1] < lowest(close, 20, shift=2)` — mirror.
- Bar-close driven; enter at next bar open. Not tick-triggered.

### Stops and targets

- **SL**: `entry - 2.0 * ATR14(M15)` for longs (mirror for shorts). ATR at
  entry moment.
- **TP**: `entry + 3.0 * R` where R = entry-to-SL distance. Fixed R:R = 3.0.
- **Trailing / partials**: NONE. Static SL + TP for verifiability.

### Filters

- **Session**: entries only between 08:00 and 22:00 server (skip Asia; wide
  enough to catch London + NY). Force-close 22:30.
- **Friday after 20:00**: no new entries (weekend risk).
- **News gate**: ±6 min around high-impact events (`CalendarValueHistory`).
- **Spread**: skip entry if spread > 60 points.
- **Max concurrent (this EA)**: 1.
- **Max trades/day**: 3.

### Sizing

- Fixed lot **0.02** (same as Plan C for direct comparability).
- Magic number: `20260921003` (distinct from all other EAs).

## Pass/fail bar — LOCKED (same 8 bars as seq281/seq283)

Test environment:
- MT5 Model 1 (1-min OHLC) screen first. Model 4 real-tick if all 8 pass.
- XAUUSD M15, deposit $6000, leverage 1:100.
- Window: **2025-10-01 → 2026-09-17**.

ALL 8 must pass. Single fail = REJECT, no tuning.

1. **Net > +$600** — 10% return, meaningful additive value
2. **PF ≥ 1.20** — thick edge (Plan C is 1.42; anything under 1.2 dies to costs)
3. **cr_h1 PF > 1.0 AND cr_h2 PF > 1.0** — both halves positive
4. **Worst day > -$180** — under FN 3% funded line ($180 on $6k)
5. **Max DD < $400** — < 6.7% of $6k
6. **|Corr Plan C monthly| < 0.30** — independent additive value
7. **Consistency ≤ 40%** — FN On-Demand eligibility
8. **Cost stress net > +$300 with +$5/trade** — realistic slippage haircut

## Prior probability estimate

Donchian breakout is a **classic trend-continuation** strategy. On strongly
trending markets (which gold has been for the past 2 years) it should be
NET POSITIVE. Expected trade count is high (breakouts on M15 fire frequently),
so cost-stress bar 8 is the most likely killer if PF is thin.

**Setup-decoder equivalent prediction**: bar 8 (cost stress) is highest risk.
Bar 6 (correlation with Plan C) is second-highest risk — if this fires on the
same trending days as FIX09, we don't get portfolio diversification.

## Exit criteria for this experiment

- **If ALL 8 pass** → escalate to Model 4 real-tick → 2-week demo forward →
  candidate for Account 3 (multi-account plan Phase 3)
- **If ANY fail** → REJECT (log ledger), no tuning, move to next candidate
  (Phase 3 fallback: XAG port of Plan C)

## Implementation plan

- Phase 1 (THIS DOC + ledger seq287): pre-reg LOCKED
- Phase 2: code `CK_GOLD_DONCHIAN.mq5` (~250-350 lines)
- Phase 3: MT5 Model 1 screen — if bars fail, REJECT here
- Phase 4 (only if screen clean): Model 4 confirmation
- Phase 5 (only if Model 4 clean): demo forward-test alongside Plan C

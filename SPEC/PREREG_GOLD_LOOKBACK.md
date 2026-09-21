# PREREG — CK_GOLD_LOOKBACK — Keshav Jindal Gold LookBack (FRVP LVN continuation) on XAUUSD

**Status:** pre-registered 2026-09-21 (ledger seq281). NO code written yet. NO test run
yet. Rules and pass/fail bar LOCKED **BEFORE** any implementation to prevent p-hacking
and post-hoc tuning (steering §5).

**Source:** Hindi video by Keshav Jindal (@premium_piips on Instagram), "Gold LookBack
Strategy 🚀". Transcript relayed by user 2026-09-21. Setup-decoder sub-agent formalized
the rules; this document locks them.

**Purpose:** test whether a **CONTINUATION-through-LVN** signal on XAUUSD is a
standalone or portfolio-additive edge on FundedNext $6k. This is **STRUCTURALLY
DIFFERENT** from the 14 mean-reversion strategies previously REJECTED on gold
(seq95, 102, 107, 120, 141, 144, 155, 157, 158, 165, 232, 272, 274, 280) — those
faded levels; this trades WITH the break of a low-volume node, in the same
directional-flow family as the only surviving edge (CK_GOLD_COMBO's FIX09).

## 1. Hypothesis

Auction Market Theory: within a session's volume profile, **Low-Volume Nodes (LVNs)**
represent price zones where the market did not agree on fair value, so it moved
through them quickly. When price re-enters an LVN the next day, it should again
**punch through** rather than settle — because the historical order flow that made
it an LVN reflects the same market structure that persists into the next session.

Trigger sequence formalizes "punch-through":
1. Price ENTERS the LVN zone (crosses one boundary)
2. Price penetrates to at least the 50% MIDPOINT (proves this is not a scam wick)
3. Price EXITS the zone (closes beyond the opposite boundary)

Entry direction = exit direction. This is a **continuation-of-momentum** trade,
not a mean-reversion fade. Rejection has been REJECTED on gold 14 times; this
tests a different attack angle.

## 2. Rules (v1 — LOCKED)

### FRVP (Fixed Range Volume Profile) — the zone-marking scan

- **Timeframe:** M30 (30-minute chart).
- **Scan window (server GMT+3):** **13:00 previous day → 23:30 previous day** =
  10.5 hours. This maps Keshav's Indian IST 15:30 → 02:00 and sits inside gold's
  clean London-NY overlap (avoids the illiquid Asia session and the daily
  rollover break).
- **Bins:** 40 vertical price bins spanning the [low, high] of the scan window.
- **Volume source:** MT5 native `CopyTickVolume` (only volume MT5 exposes — tick
  volume, not true exchange volume). This is the same source that validated
  successfully in seq81-87 (CK_POC_VA_v1).

### LVN (Low-Volume Node) detection

For each bin `i` in the profile:
- `is_local_min[i]` = `vol[i] < vol[i-1]` AND `vol[i] < vol[i+1]`
- `is_low_percentage[i]` = `vol[i] <= 0.25 × max(vol)` (bin ≤ 25% of the tallest bin)

A bin qualifies as LVN if **both** conditions hold. This is deliberately strict —
one condition alone (e.g. just the 25% threshold) would flag too many bins.

### Zone (Block) construction

- Contiguous LVN bins collapse into one **zone** (upper boundary = top of highest
  LVN bin, lower boundary = bottom of lowest LVN bin).
- **Min zone height:** `max(0.30 × ATR14, $3)` — anything smaller = noise.
- **Min zone depth:** the average of vol[i] inside the LVN run must be **≤ 40%
  of max(vol)** (60% depth from the tallest bin). Keshav's "deeper block is
  better" quantified.
- **Top-K keep:** the deepest 4 zones only. Rest discarded.
- Zone list is FROZEN at 00:00 server time daily (before London opens) and
  used only that day.

### Entry — M5 state machine (per zone, independent)

State per zone: `IDLE → ENTERED → TOUCHED_50 → ARMED → TAKEN`

- **ENTERED:** first M5 bar where `low <= zone.upper` AND `high >= zone.lower`
  (any part of the bar overlaps the zone). Record `entry_side` = "top" (price
  came from above) or "bottom" (from below), based on where the pre-entry
  price bar sat relative to the zone.
- **TOUCHED_50:** the M5 bar's wick (high or low, whichever direction) has
  reached the midpoint `(zone.upper + zone.lower) / 2`. Wick-based, not close-
  based, so a fast rejection at 50% still counts.
- **ARMED:** the M5 bar's **CLOSE** is beyond the opposite boundary (i.e.
  closes ABOVE zone.upper if entry from below, closes BELOW zone.lower if
  entry from above). Close-based to avoid stop-hunts on wicks.
- **TAKEN:** open market order at the next M5 bar's open. Direction = the exit
  direction. If closed above zone.upper → **LONG**. If closed below zone.lower
  → **SHORT**.
- After TAKEN, zone is `CONSUMED` (no re-entry, no reload — one trade per
  zone lifetime).

### Stop-loss

- **SL = 0.30 × ATR14 beyond zone far-side** relative to trade direction.
  - LONG: `SL = zone.lower - 0.30 × ATR14`
  - SHORT: `SL = zone.upper + 0.30 × ATR14`
- ATR is computed on M5 timeframe at the moment of entry.

### Take-profit

- **TP = nearest remaining zone in trade direction** (from the top-4 list).
- If no zone remains in direction: **TP = entry ± 2R** (R = entry-to-SL
  distance). This 2R fallback ensures every trade has a defined target.
- No trailing, no partials. Static TP for verifiability.

### Risk & sizing

- **Fixed lot: 0.02** (same as CK_GOLD_COMBO FIX for direct comparison).
  Not risk-based — this keeps the test comparable to Plan C's real-tick baseline.
- **Max concurrent positions (this EA): 1** — one active zone at a time.
- **Max trades per day: 2.**
- **Magic number:** `20260921002` (distinct from all other EAs in the repo).

### Filters & guards

- **Session filter:** entries only 13:00 → 23:00 server time. Force-close any
  open position at 23:30 (no overnight carry).
- **News gate:** block entries ±6 minutes around high-impact `CalendarValueHistory`
  events. Reuse same code pattern as CK_GOLD_COMBO's `Combo_UseNewsGate`.
- **Weekend filter:** no entries Friday after 20:00 server.
- **Spread filter:** skip entries if spread > 60 points.

## 3. Pass / fail bar — PRE-DECLARED, LOCKED

Test environment:
- MT5 Strategy Tester **Model 1 (1-min OHLC, fast)** for the initial screen.
  If Model 1 passes all bars AND net > $1000, escalate to Model 4 real ticks
  (steering §5 truth standard). If Model 1 fails any bar, REJECT without
  running Model 4 — saves the machine 2-4 hours.
- Symbol: XAUUSD. Entry chart: M5 (as per video).
- Window: **2025-10-01 → 2026-09-17** (matches Plan C's real-tick window).
- Deposit: $6,000 (FundedNext basis).
- Leverage: 1:100.
- All inputs pinned per §2. NO optimization, NO walk-forward tuning.

**ALL of the following must PASS for adoption. A single failure = REJECT:**

| # | Metric | Bar | Rationale |
|---|---|---|---|
| 1 | Net profit | **> +$600** | 10% return on $6k — meaningful additive contribution vs Plan C's $2,240 |
| 2 | Profit factor | **≥ 1.20** | Thick edge, not the marginal 1.06 of POC_VA (seq81-89) which died to costs |
| 3 | Current-regime robustness | **PF > 1.0 in BOTH cr_h1 AND cr_h2** | Both halves of the window must be positive. POC_VA passed cr_h1 but failed cr_h2 at 0.88 — this bar catches that failure mode |
| 4 | Worst single-day loss | **> -$180** | Under FN funded 3% limit ($180 on $6k) |
| 5 | Max drawdown | **< $400** | < 6.7% of $6k, well under the 10% static kill line |
| 6 | Correlation with Plan C monthly P&L | **abs(ρ) < 0.30** | Independent additive value; if it just replays Plan C's P&L pattern, it doesn't help the portfolio |
| 7 | Consistency (FN On-Demand) | **biggest day / total profit ≤ 40%** | Preserves FN On-Demand 90% payout eligibility (Article 15586820) |
| 8 | Cost stress test | **Net > +$300 with +$5/trade added cost** | Realistic slippage + commission haircut. POC_VA net went from positive to negative at this stress — the definitive replay-killer bar |

If ALL 8 pass → adopt for Model 4 confirmation, then 2-week demo forward.
If ANY fail → log REJECT in ledger seq282 with the specific failing metric(s).
**Do NOT tune parameters to try to pass.** The rules in §2 are the hypothesis; if
the hypothesis fails at these rules, it is refuted, not re-tuned. This is the
falsifiability discipline that steering §5 mandates.

## 4. What this test is NOT

- **Not an optimization.** All inputs in §2 are pre-declared defaults derived
  from the video content, AMT convention, or the setup-decoder's rationale.
  If the test fails and someone later wants to try different bins/thresholds,
  that is a NEW pre-registration (separate ledger seq), not a rescue of this one.
- **Not a substitute for Plan C.** Even if this passes, it becomes an
  ADDITIONAL sleeve or a diversification candidate. Plan C remains the primary.
- **Not a green-light for live trading on its own.** Any positive result gets
  a 2-week demo forward-test on the FundedNext feed before live deployment
  (same discipline as Plan C).
- **Not portable across assets** even if it passes on gold — the video claims
  "works on all assets" but we test only XAUUSD.

## 5. Setup-decoder diagnosis summary (grounding evidence)

Setup-decoder sub-agent (invoked 2026-09-21) formalized rules and diagnosed fit.
Key findings archived here:

- **Structurally different from prior rejects** — this is continuation-through-
  LVN, same directional-flow family as the only surviving edge (FIX09). All
  14 prior rejects were mean-reversion at a level. Justifies spending Model 1
  budget on this test.
- **AMT-orthodox** — "price moves quickly through LVN because it did before"
  is the standard auction-market-theory prediction. Not a made-up rule.
- **Predicted most-likely outcome: POC_VA replay** — thin edge dies to cost
  stress (bar 8 above is designed to catch this).
- **Second-most-likely: trend-only** — works in trend months, blows up in
  chop, net near-zero (bar 3, cr_h1/cr_h2 split, catches this).
- **Small tail probability: genuine standalone or Plan C complement** — this
  is what the 8-bar test is trying to detect.

Setup-decoder verdict: **no verdict** — MT5 decides. Correct per steering §5.

## 6. Implementation plan (post-pre-reg)

- **Phase 1 (THIS DOC):** pre-reg + ledger seq281 entry. LOCKED.
- **Phase 2:** code `CK_GOLD_LOOKBACK.mq5` — fresh EA, ~500-600 lines. Reuse
  FRVP-build code pattern from `CK_POC_VA_v1.mq5` (already validated for
  MT5 tick-volume profiles). Compile clean = 0 errors, 0 warnings.
- **Phase 3:** MT5 Model 1 screen against §3 bars. If ANY of the 8 fail →
  REJECT immediately, log seq282, do not run Model 4. If all 8 pass AND
  net > $1000 → escalate to Model 4.
- **Phase 4 (only if Model 1 clean):** MT5 Model 4 real-tick verdict against
  §3 bars. This is the truth standard.
- **Phase 5 (only if adopted after Model 4):** 2-week demo forward-test on
  FundedNext feed alongside Plan C. Then FN deployment decision.

Deliverable of Phase 1 (this file + ledger seq281): NOTHING else changes
until Phase 2 starts.

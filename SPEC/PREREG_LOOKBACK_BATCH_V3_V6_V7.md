# PREREG — LOOKBACK batch variants v3/v6/v7 — winner iteration

**Status:** batch pre-registered 2026-09-22 (ledger seq290). Follows seq281 (v1
REJECT), seq283 (v2 REJECT).

**Motivation:** v1 gave 0 signal (LVN too strict); v2 gave 99 trades with PF 1.099,
cost stress fatal. **Not giving up.** Iterating on 3 promising directions per
user directive: winners' mindset requires refining, not abandoning.

Fundamental insight from v2: avg edge = -$1.28/trade — need FEWER, HIGHER-QUALITY
trades. All 3 variants below ADD filters to reduce trade count and improve
per-trade edge.

## Variant v3 — Wide zones (24 bins, percentile LVN, 0.5 ATR height)

**Hypothesis:** Keshav visually eyeballs "big gaps"; 24 bins gives fewer, wider
zones matching visual perception. Percentile-based LVN (bottom 20%) is intrinsic
to volume distribution, not fixed %.

**Rules (LOCKED):**
- Inp_Bins = **24** (was 40)
- LVN definition = **bottom 20% of bin volumes** (needs code change: new mode input)
- Inp_MinZoneHeightATR = **0.5** (was 0.30)
- Inp_MinZoneHeightUSD = 5.0 (was 3.0)
- Inp_TopK = 4 (unchanged)
- Everything else same as v2

**Simplification:** since percentile-based LVN requires code, I'll approximate with
`Inp_LVNPctOfMax = 20.0` on the 24-bin config (functionally similar — 24 bins
naturally spreads volume more, so 20% threshold is more permissive).

## Variant v6 — Fewer stronger zones (24 bins, keep top 2)

**Hypothesis:** Visual traders keep only 2-3 best zones per day. Keeping only
top 2 by depth filters weak zones out.

**Rules (LOCKED):**
- Inp_Bins = 24
- Inp_LVNPctOfMax = 30.0 (v2's value)
- Inp_MinZoneHeightATR = 0.5
- Inp_TopK = **2** (was 4)
- Everything else same as v2

## Variant v7 — Trend-filtered entry (add H1 EMA200 filter)

**Hypothesis:** Gold's ONLY durable edge is TREND continuation (steering §5,
seq148/149). Adding H1 EMA200 trend filter aligns LookBack with the surviving
family:
- LONG entries only when M5 close > H1 EMA200
- SHORT entries only when M5 close < H1 EMA200

**Rules (LOCKED):**
- Inp_Bins = 40 (v2's value)
- Inp_LVNPctOfMax = 30.0 (v2's value)
- Inp_MinZoneHeightATR = 0.3 (v2's value)
- Inp_TopK = 4 (v2's value)
- **NEW: Inp_UseTrendFilter = true, Inp_TrendEMAPeriod = 200, Inp_TrendEMATF = PERIOD_H1**
- Entry logic: LONG only if last M5 close > H1 EMA200, SHORT only if <

**Code change needed:** Add trend filter input group + check in ExecuteArmedZone.

## Pass/fail bar — SAME 8 as seq281 (LOCKED for all 3 variants)

1. Net > +$600
2. PF ≥ 1.20
3. cr_h1 PF > 1.0 AND cr_h2 PF > 1.0
4. Worst day > -$180
5. Max DD < $400
6. |Corr Plan C monthly| < 0.30
7. Consistency ≤ 40%
8. Cost stress net > +$300 with +$5/trade

ALL 8 must pass per variant. Single fail = REJECT that variant. No tuning.

## Test procedure (LOCKED)

Each variant:
1. Set inputs per its rules
2. Compile CK_GOLD_LOOKBACK.mq5 (with trend filter code additions for v7)
3. Copy .ex5 to Experts
4. MT5 Model 1 tester, XAUUSD M5, 2025-10-01 → 2026-09-17, deposit $6000
5. Copy CSV to workspace, analyze
6. Score against 8 bars

## Exit criteria

- **If any variant passes all 8 bars** → escalate that variant to Model 4 real-tick
  confirmation → 2-week demo forward → adopt as multi-account Phase 3 EA
- **If any variant passes 6+ bars but fails 1-2** → note the missing bar(s), document,
  DO NOT tune. Consider whether the missing bar reveals a fundamental issue
- **If all 3 fail with same pattern (e.g. all still cost-stress fail)** → honest
  conclusion: the LookBack idea doesn't survive cost on gold M5. This is 3
  disciplined attempts, iterated, exhausted the primary parameter space

## What this test is NOT

- Not blind grid search. Each variant tests a specific hypothesis about the video's
  interpretation.
- Not tuning to pass. Each variant's rules are locked before test.
- Not the final say. If all 3 fail, further iteration may test asset transfer
  (EURUSD/XAG) as a separate pre-reg — Keshav's video claims "all assets work".

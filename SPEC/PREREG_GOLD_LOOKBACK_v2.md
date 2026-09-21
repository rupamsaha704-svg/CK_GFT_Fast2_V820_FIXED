# PREREG — CK_GOLD_LOOKBACK v2 — Variant: looser LVN definition

**Status:** pre-registered 2026-09-21 (ledger seq283). Follows seq281 REJECT (seq282).

**Motivation:** seq281 rejected because LVN definition `local_min AND vol <= 25% of max`
produced ZERO candidates on 241 of 250 trading days. Root cause = too strict specification,
not regime-dependent edge failure. This variant loosens the LVN definition to test whether
the strategy has any tradable signal at all under a more permissive interpretation
consistent with the video (which shows "any short volume bar" as a gap).

**Rule change vs seq281:**
- `LVN bin definition`: OLD = `local_min AND vol <= 25% of max`, NEW = `vol <= 30% of max`
  (drop local-min requirement, slight threshold relax)
- All other rules unchanged from seq281 §2

**Everything else LOCKED as per seq281:**
- FRVP: M30 timeframe, session filter 13:00-23:30, 40 bins, tick-volume
- Zones: min height max(0.30*ATR, $3), min avg-depth ≤ 40% of max, top-4 by depth
- Entry state machine: IDLE → INSIDE → TOUCHED_50 → ARMED → TAKEN
- Direction: exit direction = trade direction (continuation break)
- SL: 0.30 * ATR14(M5) beyond zone far-side
- TP: nearest remaining zone or 2R fallback
- Sizing: fixed 0.02 lot
- Guards: max 2 trades/day, force-close 23:30, news gate ±6min, no Friday post-20:00

**Pass/fail bar — LOCKED, same 8 bars as seq281:**

1. Net > +$600 on $6k over 2025-10-01 → 2026-09-17
2. PF ≥ 1.20
3. cr_h1 PF > 1.0 AND cr_h2 PF > 1.0
4. Worst single-day loss > -$180
5. Max drawdown < $400
6. |correlation with Plan C monthly returns| < 0.30
7. Consistency biggest-day/total ≤ 40%
8. Cost stress net > +$300 with +$5/trade added cost

ALL 8 must pass. Single fail = REJECT. No tuning.

**Test environment:** MT5 Model 1 (1-min OHLC), XAUUSD M5, deposit $6000, leverage 1:100,
window 2025.10.01 to 2026.09.17. All inputs pinned per this doc.

**Exit criteria:**
- If ANY of 8 bars fail → REJECT (log seq284) → move to combo path (CK_GOLD_LOOKBACK
  as sleeve of CK_GOLD_COMBO_v2)
- If ALL 8 pass → escalate to Model 4 real ticks confirmation

**Setup-decoder prediction status update (seq281):**
- Predicted "thin edge dies to cost stress" — WRONG
- Actual failure mode = ZERO SIGNAL from over-strict LVN definition
- Variant v2 tests whether the underlying LVN-continuation idea has ANY signal on gold
- If v2 still finds ~0 signal → hypothesis is refuted on gold volume distribution
- If v2 finds many trades but fails bars 2/3/8 → original setup-decoder prediction validated

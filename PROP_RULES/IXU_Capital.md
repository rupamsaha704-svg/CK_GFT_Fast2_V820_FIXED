# IXU Capital — 2-Step — CONFIRMED RULES

**Status: ❌ INCOMPATIBLE with our current strategy.** Cheap and (per user) pays, and most rules match
ours — BUT it **bans weekend holding**, and our profit lives almost entirely in weekend-spanning trend
holds. Proven below. Sources: ixucapital.app + comparison table, verified 2026-09-18.

## Account & platform
- Products: **2-Step** (also 1-Step, Instant). Runs on **MT5** (EA plausible on MT5).
- Sizes include $10k, $25k, $50k, $100k, $200k. 2-Step **from ~$35**; **50% off code IXU50**.
- Leverage **1:100**. Scaling to **$400k**. Fee refund on **4th payout**.

## 2-Step rules
- **Profit target:** 8% + 5%.
- **Daily loss: 5%.** **Max overall loss: 10% STATIC** (fixed from initial, never trails).
- **Max risk / trade (FUNDED only): 2%** (stricter than FundedNext's 3%). On $10k = $200.
- **Minimum trading days: 3.** **Profit split: 80%.** **Payout: every 14 trading days.**
- **News trading: allowed.**
- **⚠️ WEEKEND HOLDING: NOT ALLOWED — must be flat before the weekend.**
- Daily-loss basis (initial vs day-start) + floating-included: not explicit on the site — confirm with support (reset 00:00 GMT+3).
- ⚠️ Independent payout proof / reviews: not found in public search (new firm). User vouches they pay; treat with the usual "prove a small payout first" caution.

## WHY IXU is incompatible with our strategy (tested, real ticks)
Our CK_GOLD_COMBO edge = trend trades **held over multiple days / weekends** (the DT swing sleeve).
- Diagnostic ($6k deals): the **25 weekend-held trades made 109% of total net**; the other 247 trades were **net −$181**.
- Built a `Combo_WeekendFlat` feature (closes all Fri 20:00 + blocks Sat/Sun) to honour IXU's rule, then tested $10k on real ticks:
  - IXU $10k, FIX 0.03, weekend-flat: net **$1,181** → take **~$81/mo (~৳9,370)**.
  - IXU $10k, FIX 0.04 (max lot), weekend-flat: net **$1,368** → take **~$94/mo (~৳10,849)**; worst day −$500 touches the $500 line.
  - **FundedNext $6k (weekend holds allowed): take ~$139/mo (~৳16,037).**
- **Verdict:** even a bigger, cheaper, maxed-lot IXU $10k LOSES to a $6k FundedNext, because the
  no-weekend rule guts the DT swing sleeve. The lot size was never the problem — the weekend rule is.

## When IXU WOULD be worth revisiting
Only with a genuinely **intraday / no-weekend-hold strategy** (closes same session). Our current combo
is not that. If we ever validate such a strategy, IXU's cheap $10k + static DD + 1:100 could be a good
home for it — but confirm a real payout first.

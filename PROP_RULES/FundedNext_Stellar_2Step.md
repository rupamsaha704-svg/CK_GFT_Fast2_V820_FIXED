# FundedNext — Stellar 2-Step ($6k) — CONFIRMED RULES

**Status: ✅ OUR DEPLOY TARGET.** Established firm, proven payouts, allows weekend holding, static DD.
Sources: help.fundednext.com + written support replies (Annie), verified 2026-09-18.

## Account & platform
- **Product:** Stellar **2-Step** on **MT5** (or MT4). EAs ALLOWED on MT4/MT5.
  - ❌ NOT the "FundedNext CFD" / **Match-Trader / cTrader** version — EAs are BANNED there (manual only).
- **Account sizes:** $6k · $15k · $25k · $50k · $100k · $200k. **(NO $5k or $10k in this model.)**
- **EA allowed only on accounts < $50,000.** Accounts **$50k and above = MANUAL ONLY**.
- Gold leverage **1:15**.

## Targets & drawdown
- **Profit target:** Phase 1 **8%**, Phase 2 **5%**. **No time limit.**
- **Daily loss limit: 5% of the INITIAL balance** (fixed, not day-start), and it **INCLUDES closed +
  floating + swap + commission** (equity-based). Resets **00:00 server time (GMT+3)**.
  - $6k → **$300/day**. (Our EA references this via `Combo_DailyRefInitial=true`.)
- **Max loss limit: 10% STATIC** of initial (never trails). Breach on **balance OR equity**.
  - $6k → floor **$5,400**.
- **Minimum trading days: 5 days AND 5 trades per phase** (≥1 trade on ≥5 separate days; non-consecutive OK; no max).
  - Funded phase min-days depends on the payout option chosen at checkout (**21-Day option = no min days, no target**).

## FUNDED-stage extra rule — 3% RISK LIMIT (help article 14702245)
- At any instant: (max potential SL loss) + (combined realized + unrealized/floating loss across all
  open trades), vs INITIAL, must stay **≤ 3%** ($180 on a $6k account). Swap/commission excluded.
- **NOT an instant kill:** 1st breach = warning + 100% of the violating trades' profit deducted that
  cycle; 2nd = permanent reclassification to a **1% risk cap**; later breaches keep deducting.
- Applies to the **funded account only** (NOT the challenge). Our funded config must cap combined risk
  under this (e.g. one open position at a time and/or a combined-floating flatten).

## Consistency, payout, news, weekend
- **Consistency (40% rule):** applies ONLY if you take **On-Demand** payouts. **Use the SCHEDULED payout
  and there is NO consistency rule.** (Scheduled = every 14 trading days; 21-Day first-payout option exists.)
- **Profit split: 80%**, scaling to **90%** (Lifetime 95% add-on available). *(15% challenge reward not for US clients.)*
- **Payout methods:** USDT (ERC20/TRC20), USDC (ERC20), RiseWorks, Bank Transfer, FNmarkets.
- **Weekend holding: ✅ ALLOWED.** (This is critical for our edge.)
- **News:** allowed; in the funded account news-trade **profit counted at 40%** (loss counted in full). No minimum hold time.
- **Strategy consistency:** must use the **SAME method in the Challenge and the Funded account** (no EA-pass-then-manual switch, or vice versa) → else review/suspension/reward denial.

## Prohibited strategies (our EA is CLEAN vs all of these)
HFT · Quick-Strike (trades closed <30s making ≥30% of profit) · tick-scalping · grid · any arbitrage ·
latency trading · account rolling · one-sided-betting (remedy = forced 1% risk rule, not instant kill) ·
hyperactivity (≥200 trades OR ≥2000 server messages/day) · cross-account hedging · copy-trading from
others · **settlement-window exploitation (00:00–02:00 server "dead zone")** · account/device sharing.
**Martingale is ALLOWED.** Our config blocks 00:00–02:00 via `Combo_BlockEntryHours=0,1`.

## Fees (verify at checkout; change often)
- $6k Stellar 2-Step base ≈ **$59** (list). Current coupon **START6K = up to 50% off** → ≈ $30.
- **EA add-on +$5** (run on own PC) **or VPS & EA add-on +$10** (using a VPS incl. your own AWS).
  EA/VPS usage fee tiers: $5k–$25k = $5 (EA) / $10 (VPS). $50k+ = manual, no EA.
- **Challenge fee is refundable** (returned via a payout once funded).
- Total to start a $6k with our setup ≈ **~$40** (START6K + VPS&EA) + your own AWS VPS ~$10/mo.

## Our validated numbers on this firm (real ticks, Oct 2025 → Sep 2026, $6k)
- Config: FIX **0.02** + DTChop + settlement-block (`Combo_BlockEntryHours=0,1`), `Combo_Stage=0`, `Combo_DailyRefInitial=true`.
- Net **+$2,022 (33.7%)**, worst realized day −$250 (< $300), min balance $5,914 (> $5,400), 0 breaches.
- Take @80% ≈ **~$139/mo (~৳16,000)** — lumpy (2 big months carry the year). $15k account ≈ ~৳40,000/mo.
- 0.03 lot BREACHES the $300 daily on $6k → stay at 0.02.

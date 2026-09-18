# Goat Funded Trader (GFT) — 2-Step Standard — CONFIRMED RULES

**Status: ⚠️ HISTORICAL.** The project began here (repo name "CK_GFT"), then dropped GFT for FundedNext
because GFT's **Goat Guard** (a floating-loss guard) forces smaller size for the same safety, i.e. ~3×
less return than FundedNext's no-Goat-Guard shape. Kept here as a reference. Sources: Goat Funded Trader
help centre + project notes.

## Account & platform
- Product: **2-Step Standard**. EAs allowed (no HFT / no arbitrage). Gold OK. MT4/MT5.

## Targets & drawdown
- **Profit target:** Step 1 **10%**, Step 2 **5%**.
- **Daily drawdown: 5%** — measured on the **higher of balance or equity**, reset ≈ **5 PM EST**
  (includes intraday floating).
- **Max overall loss: 10% STATIC** of the initial balance (fixed floor; $4,500 on a $5k account).
- **Minimum trading days: 3** (4 if the account was purchased on/after 25 Jul 2026).

## FUNDED-stage extra rule — GOAT GUARD (funded accounts only, excl. Instant)
- Watches the **combined FLOATING P&L of ALL open positions**.
- Triggers when combined **floating loss = 2% of the INITIAL account size** — a FIXED $ amount
  (**$100 on a $5k account**). Measured vs initial, does not grow with the account.
- **1st trigger:** NOT a breach, but the **profit split drops 80% → 50%** (positions stay open).
- **2nd trigger** (once the open-position set changes and again hits −2%): **account BREACHED / closed.**
- Also a discretionary **Risk-Limitation policy**: GFT may cap risk to **1% of initial** if they see excessive risk-taking.

## Payout / funded terms
- **Profit split 80%**, payout cycle **bi-weekly (14 days)**.
- Need **≥3 valid trading days per payout** (4 if bought ≥25 Jul 2026). A valid day = profit ≥ **0.5% of initial** (≥$25 on $5k).
- Funded **daily profit cap $3,000** (excess removed, not a breach).
- First 2 payouts capped at 6% of initial (4% for $5k accounts bought ≥25 Jul 2026) or $10k, whichever lower; cap removed after the 2nd payout.

## Why we dropped GFT (for the record)
- Goat Guard's 2%-floating flatten forces a tiny lot (funded needs `Combo_Stage=1` + a combined-floating
  flatten under $100), which caps funded return ~3× lower than FundedNext.
- FundedNext has **no float-based guard** → we can size 0.01→0.03 for ~3× the return at the same rule-safety.
- **Our strategy fits GFT** (weekend holds OK, static DD, EA OK) — GFT is a valid FALLBACK if FundedNext
  ever changes terms — but funded income would be lower here due to Goat Guard.

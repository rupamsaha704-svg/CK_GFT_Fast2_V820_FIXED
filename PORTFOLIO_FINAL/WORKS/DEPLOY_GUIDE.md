# Deploy Guide — CK_CRYPTO_TSMOM_v2 (the crypto + NQ book)

The one validated book. Daily **time-series-momentum**: BTC + ETH (~70% risk) + NQ / Nasdaq-100
trend (~30% risk). Long **and** short, inverse-volatility sized, daily rebalance.
Out-of-sample (2023–2026): **Sharpe ≈ 0.63, maxDD ≈ 8%, positive every year 2018–2026.** Found
on external daily data (Yahoo / Binance) with **no parameters optimized to the data**.

## ⚠️ Read first — the symbol constraint (honest)
This book needs the symbols **BTCUSD, ETHUSD, and NAS100 / US100 (Nasdaq-100)**.
The current **MetaQuotes-Demo** terminal used for our XAUUSD tests does **NOT** offer these
symbols — so the book **cannot be demo-run on that terminal as-is**. This is a data/broker
limitation, not a strategy problem (it is why the edge was validated on external daily data).

## How to demo it (no real money)
1. Open a **demo account with an MT5 broker that offers BTCUSD, ETHUSD and NAS100/US100**
   (most crypto-friendly MT5 brokers do; the MetaQuotes default demo does not).
2. Copy **`CK_CRYPTO_TSMOM_v2.ex5`** into that terminal's `MQL5\Experts\` folder
   (or copy `CK_CRYPTO_TSMOM_v2.mq5` and compile it in MetaEditor — it builds with 0 errors).
3. Attach the EA to each instrument's chart, loading the matching preset:
   - BTCUSD → `BTCUSD.set`
   - ETHUSD → `ETHUSD.set`
   - NAS100 / US100 → `NQ.set`
4. **Demo first. Size small.** Let it run — this is a slow, daily, position system with few trades.

## Honesty / risk
- **Backtest ≠ live.** Do not risk real money until a demo forward-test agrees with the backtest.
- Expect **long flat / drawdown stretches** — that is normal for trend-following. Do **not**
  turn it off during an ordinary drawdown (that is the #1 way people lose the edge).
- The edge is BTC + ETH + NQ only. Do not add more crypto coins (they are too correlated and
  dilute the book — see `../REJECTED/REJECTED.md`).

_Not financial advice._

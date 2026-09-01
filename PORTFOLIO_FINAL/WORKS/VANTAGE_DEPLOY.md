# Vantage (or any MT5 broker) — Turnkey Demo Deploy: crypto + NQ book

The book = **3 instances of `CK_CRYPTO_TSMOM_v2`**, one per instrument, each on the **D1 (Daily)**
chart with its own `.set`. Long/short daily time-series-momentum, inverse-vol sized.

## 0) Prerequisite — connect the broker on the PC MetaTrader 5
1. **File → Open an Account** → search **`Vantage`** → pick **VantageMarkets-Demo** → **Next**
   (this downloads/adds the server — required once).
2. **Connect with an existing trade account** → Login `26028438` → password → Server
   `VantageMarkets-Demo` → **Finish**.
3. Top-right must show **`26028438 @ VantageMarkets-Demo`** (green). Market Watch must list the
   crypto + Nasdaq symbols.

## 1) Install the EA
- Copy `CK_CRYPTO_TSMOM_v2.ex5` into `...\MQL5\Experts\` (or open `CK_CRYPTO_TSMOM_v2.mq5` in
  MetaEditor and compile — it builds 0 errors).
- In MT5: right-click Navigator → Refresh. The EA appears under Expert Advisors.

## 2) Attach one instance per instrument (all on **D1**)
| Instrument (Vantage name may vary) | Chart TF | Load this preset |
|---|---|---|
| BTCUSD | **D1** | `BTCUSD.set` |
| ETHUSD | **D1** | `ETHUSD.set` |
| NAS100 (Nasdaq-100) | **D1** | `NQ.set` |

For each: open the **Daily** chart of that symbol → drag the EA on → in the dialog click
**Load** and pick the matching `.set` → enable **Allow Algo Trading** → OK. Turn on the global
**Algo Trading** button. A smiley face on each chart = running.

> Symbol names differ per broker. Attach to whatever Vantage calls BTC / ETH / Nasdaq-100 — the
> EA is symbol-agnostic (it trades the chart's own symbol). Just load the matching `.set`.

## 3) Important behaviour (so nothing surprises you)
- **Warm-up:** the rule uses look-backs up to 250 days + a 252-day vol baseline, so each instance
  needs **~2 years of daily history before its first trade.** On a fresh chart, scroll back / let
  history download; it will not trade on day one. This is normal, not a bug.
- **Slow system:** few trades, daily rebalance. Expect **long flat / drawdown stretches** — do NOT
  switch it off in an ordinary drawdown (that is how the edge is lost).
- Each instance targets ~5% annual vol → the 3 together ≈ a ~10% book, ~70/30 crypto/NQ by
  correlation. To risk less, lower `InpTargetVolAnnual` (e.g., 0.03).

## 4) Before you let it run forward — MT5 backtest first (I do this)
Once the Vantage account is connected on the PC terminal, tell me **"connected"** and I will run
`CK_CRYPTO_TSMOM_v2` in the **Strategy Tester on Vantage data** (BTCUSD/ETHUSD/NAS100, D1, a
multi-year window) to confirm the numbers on this broker's feed **before** any forward run. That is
a simulation — it places no live orders.

## Reference (validated on 10y free daily data, NOT broker-specific)
- BTC+ETH sleeve: FULL Sharpe 1.17, **OOS 0.89**, 9/9 years positive, OOS bootstrap P(Sharpe>0) 97.7%.
- Crypto+NQ 70/30 book: **OOS Sharpe 0.66, OOS maxDD 7.7%**, positive every year 2018–2026.
- Survives cost stress to 25–50 bps; needs BOTH long & short (long-only OOS is negative).

_Demo only. Backtest ≠ live. Not financial advice._

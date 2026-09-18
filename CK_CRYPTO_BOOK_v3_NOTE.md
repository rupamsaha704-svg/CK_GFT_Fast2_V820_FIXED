# CK_CRYPTO_BOOK_v3 — the 3rd EA (unified trend book)

**What it is:** ONE EA that runs the whole validated book — **BTC + ETH + NQ** — from a single
chart. Each instrument uses the same rule as `CK_CRYPTO_TSMOM_v2` (daily time-series momentum,
sign of 20/60/120/250-day return, inverse-vol sizing, vol-target, vol-filter), internally
risk-weighted ~**70/30 crypto/NQ** (weights 1.0/1.0/0.85), rebalanced once per new daily bar,
per-symbol netting. Dumps all closed trades to `Common\Files\ck_crypto_book_trades.csv` via
`OnTester`.

**Why v3:** v2 required running 3 separate instances (one per symbol). v3 packages the full book
into a single attach — easier to deploy and to backtest as one unit.

**Status:**
- ✅ Compiles 0 errors. Logic = the already-validated v2 rule (Python OOS Sharpe ~0.66, DD ~8%,
  positive every year 2018–2026 on 10y free daily data).
- ⏳ **MT5 Strategy-Tester validation is pending a broker that (a) offers BTC/ETH/NAS100 and
  (b) has multi-year daily history**, connected on the PC terminal. The current MetaQuotes-Demo
  lacks crypto history, and automated login to external brokers (Eightcap/Vantage) failed because
  their server isn't installed in this terminal (needs a one-time GUI "Open an Account" add).
  This is a data/broker limitation, not a strategy issue.

**Deploy (demo, once a crypto-capable broker is connected on the PC MT5):**
1. Copy `CK_CRYPTO_BOOK_v3.ex5` to `MQL5\Experts\` (or compile the `.mq5`).
2. Attach it to any D1 chart, **Load `CK_CRYPTO_BOOK_v3.set`**, enable Algo Trading.
3. Rename `InpSymbols` to the broker's exact names if they differ (e.g., `NAS100`→`US100`).
4. Needs ~2 years of daily history per instrument to warm up before first trade. Demo first.

**Backtest note:** the Strategy Tester runs ONE chart symbol; to MT5-test the book, either run v3
on a crypto-capable broker and read `ck_crypto_book_trades.csv`, or test each sleeve separately
with `CK_CRYPTO_TSMOM_v2` + its `.set`. Trade simulation is MT5; Python only reads outputs.

_Not financial advice. Backtest ≠ live. Demo + small size first._

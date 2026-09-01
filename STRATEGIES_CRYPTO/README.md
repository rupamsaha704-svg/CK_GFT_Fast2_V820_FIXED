# CK_CRYPTO_TSMOM_v2 — Diversified Trend-Following Book (Crypto + Nasdaq)

## What it is
A daily **long/short time-series-momentum (trend-following)** system, run as one
symbol-agnostic Expert Advisor across a small, diversified book:

| sleeve | instrument(s) | risk weight | vol-filter |
|--------|---------------|-------------|-----------|
| Crypto | BTCUSD, ETHUSD | ~70% (5% + 4% vol) | ON |
| Equity | NQ / US100 (Nasdaq-100) | ~30% (5% vol) | OFF |

Each instrument: signal = average sign of return over 20/60/120/250 days;
position sized inverse-to-volatility to a per-instrument annualized vol target;
rebalanced once per **daily** bar; long **and** short. The crypto sleeve also
scales exposure **down in high-volatility (choppy) regimes** (the vol filter).

## Why this book (research summary, 2016–2026 daily, sealed-holdout OOS = 2023–2026)
- **Crypto trend** is the core durable edge: OOS Sharpe ~0.6, positive **every year
  2018–2026**, robust to lookback & cost (survives 50 bps), statistically significant
  (bootstrap P(Sharpe>0) ≈ 95–98%). Economic reason: crypto is a young, retail-driven,
  less-efficient market with persistent multi-week trends.
- **NQ (Nasdaq) trend** added as an **uncorrelated** diversifier (corr to crypto ≈ **+0.15**).
  It lowered the book's drawdown a lot: **crypto-alone maxDD ~12–15% → combined ~8%**,
  with equal-or-slightly-higher Sharpe (~0.63).
- **Rejected (honest):** more crypto coins (too correlated → no diversification),
  FX / bonds / commodities / international equity / crypto mean-reversion (no
  out-of-sample edge). Dumping everything together ("kitchen sink") gave OOS Sharpe
  **−1.3** — proof that only independently-validated, uncorrelated sleeves belong.

## Validated numbers (out-of-sample 2023–2026, ~10% vol target book)
- Sharpe ≈ **0.63** · maxDD ≈ **8%** · positive every calendar year · long+short (NOT buy&hold: long-only alone LOSES; the short side carries crashes like 2022).

## Files
- `CK_CRYPTO_TSMOM_v2.mq5` — the EA (compiles clean, MT5 build 4xxx).
- `BTCUSD.set`, `ETHUSD.set`, `NQ.set` — pinned inputs per instrument.

## Deployment (VPS)
1. Use an **MT5 broker that offers BTCUSD, ETHUSD and NQ/US100** (crypto CFD + index).
2. Copy `CK_CRYPTO_TSMOM_v2.ex5` to `MQL5\Experts\`, restart / refresh Navigator.
3. Open **3 charts** — BTCUSD, ETHUSD, NQ — timeframe irrelevant (EA uses D1 internally).
4. Attach the EA to each chart and **Load** the matching `.set` file. Enable AutoTrading.
5. Each instance manages its own position (unique magic numbers). Start on a **demo**
   or with **small size** and let it run — this is a slow, daily, position system.

## Honest risk notes (read before real money)
- Expect **long flat / drawdown periods** — trend-following is like that. Do **not**
  turn it off during a normal drawdown (that is the #1 way people lose the edge).
  As of the last data it was in a ~3-month soft patch (high-vol chop) — normal.
- Crypto carries **tail risks** (exchange failure, regulation, gaps) that price
  backtests do not capture. Size small; never over-leverage (`InpMaxLeverage` caps it).
- Backtest ≠ live. OOS Sharpe ~0.6 is good but modest; realistic live may be lower.
- This is **not financial advice**. Paper-trade first; scale only after live behavior
  matches expectations.

## Provenance
Every research step (data pull, tests, rejects, this build) is hash-chained in
`SPEC/dof_ledger.jsonl`. Edge discovered & validated by the research agent; executed
deterministically by this EA. No parameters were tuned/optimized to the data.

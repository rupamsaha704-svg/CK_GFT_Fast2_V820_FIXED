# CK Trading Lab — One-Page Summary (honest)

_Rule for the whole project: MT5 Strategy Tester = truth · sealed out-of-sample · no parameter
tuning · every step hash-chained in `SPEC/dof_ledger.jsonl` (141 records). No real money._

## The one thing that works ✅
A **daily long/short time-series-momentum book: BTC + ETH (~70%) + Nasdaq-100 / NQ (~30%)**.
Same simple rule on every instrument (sign of 20/60/120/250-day return, inverse-vol sized).

| Metric (out-of-sample 2023–2026) | Value |
|---|---|
| Book Sharpe (70/30) | **0.66** |
| Max drawdown | **~7.7%** |
| Years positive (2018–2026) | **9 / 9** |
| Bootstrap P(Sharpe > 0) | **97.7%** |
| Cost stress | survives 25–50 bps |
| Sleeve correlation (crypto vs NQ) | +0.15 (good diversification) |

Why trust it: it holds in **both halves** of history, uses **untuned** defaults, and needs
**both long and short** (long-only is negative — so it is not just "crypto went up").

## What we rejected — and why that is the good news ❌
The same strict test **refused every fake edge**, which is exactly what protects the money:
- **FX** (EURUSD OOS −0.91, GBPUSD −1.57), **bonds, commodities, intl equities** — no durable edge.
- **Gold / Silver** — positive recently but **negative 2016–2022** → recent-only, not proven → held out.
- **All gold pattern/ICT EAs** (Asian-scalp v17, trend FIX09, QM/ICT, QT/CRT, and the newest
  **ICT ChoCh V3**). ChoCh was MT5-tested on real ticks: **as-shipped loses (PF 0.72)**, spec-strict
  is **flat (PF 1.00, 12 trades)** → REJECT. The EA is bug-free/causal — the *edge* isn't there.

## Where we are / what's next
- ✅ Book **validated on 10 years of free daily data** + packaged for MT5 (`WORKS/`, deploy guides).
- ⏳ **Confirming on a live-data broker** (Vantage **demo** being connected) + a frozen **demo
  forward test**. Real money only after demo proof + explicit approval.
- Folders: `WORKS/` = what works · `REJECTED/` = what doesn't (+ why) · `RESULTS/` = raw evidence.

## Honest caveats
Backtest ≠ live. It is a **slow** system (few trades, long flat/drawdown stretches are normal).
Crypto history on retail brokers is short, so broker-side confirmation windows are limited. This is
a research/validation lab, **not financial advice**.

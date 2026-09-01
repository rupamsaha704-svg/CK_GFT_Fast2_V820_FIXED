# CK Trading Research — Final Portfolio & Honest Scorecard

_Last updated: 2026-09-01. Everything here is hash-chained in `SPEC/dof_ledger.jsonl`._

This folder is the clean, organized truth of the whole project: **what works, what does
not, on which instrument, and — honestly — what we did and did not test.**

---
## 1) TL;DR — the one thing that works
**`CK_CRYPTO_TSMOM_v2`** — a daily long/short **time-series-momentum** book:
- **Crypto sleeve: BTC + ETH** (+ volatility filter) ~70% risk
- **Diversifier: NQ / Nasdaq-100 trend** ~30% risk (uncorrelated, corr +0.15)
- Out-of-sample (2023–2026): **Sharpe ≈ 0.63, maxDD ≈ 8%, positive every year 2018–2026.**
- Files in `WORKS/`. Deploy on a broker offering BTC/ETH/NQ; **demo/small first**.

Everything else in our data was tested the same way and **did not** show a durable edge
(details below). That is the honest result, not a failure of effort.

---
## 2) WHAT WORKS vs WHAT DOES NOT — unified TSMOM scorecard
Same rule, same test for every instrument (IS = 2016–2022, OOS = 2023–2026):

| Instrument | IS Sharpe | OOS Sharpe | Verdict |
|---|---|---|---|
| BTC | +1.35 | +0.77 | ✅ DURABLE (both halves) — in book |
| ETH | +1.16 | +0.27 | ✅ DURABLE — in book |
| NQ (Nasdaq) | +0.28 | +0.40 | ✅ DURABLE — in book (diversifier) |
| XAU (gold) | −0.34 | +1.07 | ⚠️ RECENT-ONLY (IS negative) — not proven durable |
| XAG (silver) | −0.28 | +0.35 | ⚠️ RECENT-ONLY — not proven durable |
| EURUSD | −0.37 | −0.91 | ❌ NO EDGE |
| GBPUSD | −0.02 | −1.57 | ❌ NO EDGE |
| AUD/NZD/USDCAD/CHF/JPY/CNH/SEK | ≤0 | ≤0 | ❌ NO EDGE (FX worst for trend) |
| Commodities (CL/NG/HG/grains…) | ~0 | ~0/neg | ❌ NO durable edge |
| Bonds (ZN/ZB/ZF/ZT) | mixed | negative | ❌ NO edge (trend died post-2022) |
| Intl equities (DAX/FTSE/Nikkei/STOXX/HSI) | neg | ~0 | ❌ NO durable edge |
| Stocks (AMD/INTC/MSFT/NVDA) | — | — | ❌ generic EAs give ~0 trades (untestable) |

**Key nuance:** BTC/ETH/NQ work in BOTH halves = trustworthy. Gold/Silver look great
recently but were negative 2016–2022 = riding the current metals bull, **not proven** —
kept OUT of the book until they prove durable.

---
## 3) STRATEGIES tried (beyond TSMOM) — all rejected honestly
| Strategy | Type | Where tested | Result |
|---|---|---|---|
| CK_GFT_Fast_v17 | Gold Asian-session scalp | XAUUSD | edge decayed on sealed holdout — REJECT |
| CK_GOLD_PRO_FIX09 | Gold trend | XAUUSD | trend-only + margin wall — REJECT |
| QM/ICT, QT/CRT, MR_StdDev, Trapbox v1/v2/v3, FIX10 | Gold patterns | XAUUSD | all REJECT (holdout) |
| CK_XAU_ICT_ChoCh_V1/V2/V3 | ICT CHoCH + BOS + Fib OTE | XAUUSD (MT5 real-tick) | REJECT — relaxed PF 0.72 / −$211 / 25tr, strict PF 1.00 / flat / 12tr (seq 141) |
| CK_TURTLE_SOUP_v1 | Mean-reversion sweep | XAU,EUR,GBP,XAG,AUD,NZD,USDx…,stocks | all REJECT |
| CK_TREND_ATR_v1 | Donchian/ATR trend | EUR,GBP,XAG + broker sweep | all REJECT |
| Crypto basket (12 coins) | TSMOM | crypto | REJECT (coins too correlated, dilutes) |
| Crypto mean-reversion | reversal | BTC,ETH | REJECT (crypto trends, doesn't revert) |
| GEX / options overlay | regime filter | NQ | data-blocked (free history N/A) — live collector started |

---
## 4) HONEST COVERAGE — what we DID and DID NOT test
- ✅ **TSMOM applied uniformly to ALL instruments** (39 multi-asset + 20 crypto) — this is
  the comprehensive, "one level" test that found the edge.
- ⚠️ **Turtle & Trend-ATR**: only on the ~12 MT5-broker symbols, not the full 39.
- ⚠️ **Gold-specific EAs (v17/FIX09/etc.)**: gold only (they are gold-tuned, not portable).
- ❌ **NOT done — full strategy×instrument grid** (every strategy on every instrument):
  deliberately avoided — it is a multiple-testing / overfitting trap. We instead ran ONE
  robust, economically-grounded method (TSMOM) across everything.
- ⚠️ **Discretionary ICT patterns**: the **CHoCH + Fib OTE** family WAS fully coded from a Kiro
  spec and **MT5-tested on real ticks** (see `REJECTED/ICT_ChoCh_V3/`) → REJECT (relaxed loses,
  strict break-even). Remaining discretionary PDF patterns (MMXM/STDV/QML) are still un-coded
  (un-backtestable / overfit-prone).

If we ever want more coverage, the disciplined way is: add ONE more economically-motivated
method, run it uniformly across all instruments, keep only what survives OOS + is uncorrelated.

---
## 5) Folder map
- `WORKS/` — the validated strategy (EA `.mq5`+`.ex5`, `.set` files, deploy README).
- `REJECTED/` — `REJECTED.md`: full honest list of everything that did not work + why.
- `RESULTS/` — raw result text (dashboard, TSMOM, sweep, validation, combo, sleeve-screen, GEX).
- Provenance: `../SPEC/dof_ledger.jsonl` (hash-chained record of every step).

---
## 6) Method & discipline (why to trust this)
Time-series momentum: for each market, signal = average sign of return over 20/60/120/250
days; position sized inverse-to-volatility; long **and** short; daily rebalance. **No
parameters were optimized to the data.** Every claim was checked on a **sealed
out-of-sample** window (2023–2026), stress-tested for cost/lookback, and bootstrap-tested.
The strictness rejected many tempting-but-fake edges (e.g., silver trend +$9.3k in-sample →
−$1.7k holdout). The same strictness *passed* crypto+NQ — which is why we trust it.

**Not financial advice. Backtest ≠ live. Start on demo, size small, expect drawdowns.**

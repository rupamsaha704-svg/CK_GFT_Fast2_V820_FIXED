# REJECTED — the honest graveyard (what did NOT work, and why)

Every item was tested with sealed-holdout discipline. Rejection = could not prove a
durable, out-of-sample edge. Kept here so we never re-test the same dead ends by mistake.

## A) Gold-specific EAs (tested on XAUUSD only)
- **CK_GFT_Fast_v17** (Asian-session M5 scalp): showed a current-regime edge but **decayed
  to −7.8% on the sealed holdout**. REJECT as standalone durable edge.
- **CK_GOLD_PRO_FIX09** (M15 trend): profitable only in trending regime + hit a margin wall
  at $5k; not robust. REJECT.
- **QM/ICT, QT/CRT, MR_StdDev, Trapbox v1/v2/v3, FIX10-regime**: all REJECT on holdout
  (opening-range/mean-reversion/killzone ideas — no independent edge on current XAUUSD).
- **CK_XAU_ICT_ChoCh_V1/V2/V3** (H1 CHoCH → retrace to POI → M15 BOS → Fib **OTE 0.618–0.786**
  entry; full prop-firm rules). MT5 real-tick, current regime (2025-10→2026-08), $5k:
  as-shipped/relaxed = **PF 0.72, −$211, 25 trades (LOSES)**; spec-faithful/strict = **PF 1.00,
  ~$0, 12 trades (break-even, too few to certify)**. The "more-trades" relaxations *hurt* (they
  let entries fire up to $1.5 OUTSIDE the OTE zone). The EA is causal / no look-ahead — so the
  REJECT is the **edge**, not a coding bug. Evidence: `ICT_ChoCh_V3/`, ledger **seq 141**.

## B) Turtle Soup (generic mean-reversion sweep), M15 real-tick
- Tested: XAUUSD, EURUSD, GBPUSD, XAGUSD, AUDUSD, NZDUSD, USDCAD/CHF/JPY/CNH/SEK, AMD/INTC/MSFT/NVDA.
- Result: **all REJECT** (lose across IS/OOS/holdout). Stocks: ~0 trades (untestable with generic sizing).

## C) Trend (Donchian/ATR) H1 real-tick
- EURUSD/GBPUSD REJECT. XAGUSD **in-sample +$9,356 (PF1.59) → OOS −$1,150 → holdout −$1,699**
  = textbook in-sample mirage caught by the sealed holdout. REJECT.

## D) Daily TSMOM — instruments that FAILED the uniform test
- **FX (all): EUR, GBP, AUD, NZD, USDCAD, USDCHF, USDJPY, USDCNH, USDSEK** — OOS Sharpe ≤ 0
  (FX is the weakest asset class for trend; whipsaws in chop). REJECT.
- **Bonds (ZN, ZB, ZF, ZT)** — IS ok-ish, **OOS strongly negative** (bond trend died after 2022). REJECT.
- **Commodities (CL, BZ, NG, HG, PL, PA, grains, softs)** — no durable OOS edge (~0). REJECT.
- **Intl equities (DAX, FTSE, Nikkei, STOXX, HSI)** — no durable OOS edge. REJECT.
- **Gold (XAU) / Silver (XAG)** — OOS positive (+1.07 / +0.35) BUT **IS negative** →
  recent-only, NOT proven durable across regimes. HELD OUT of the book (revisit if it proves durable).

## E) "Improvement" ideas that did NOT help
- **Broaden crypto basket (12 coins)**: OOS Sharpe 0.59 → **0.49** (coins too correlated,
  ~0.7–0.9; dilution, no diversification). REJECT — keep BTC+ETH.
- **Crypto mean-reversion sleeve**: OOS negative (crypto trends, does not revert). REJECT.
- **Kitchen-sink (combine all sleeves equally)**: OOS **−1.29**, DD 24% (losers drag). REJECT.
- **Bonds/commod/equity/FX trend sleeves**: failed the inclusion rule (OOS ≤ 0.25 or no low-corr edge). REJECT.

## F) Data / infrastructure dead-ends
- **NAS100/BTC on MetaQuotes-Demo broker**: symbols not offered → used external data instead.
- **GEX / options overlay**: multi-year historical options data not available for free →
  cannot backtest/validate → REJECT for now. Live GEX (CBOE, free) + daily collector started
  to build our own history over time.
- **YouTube "live data" streams / DeepSeek "AI brain" bot**: hype; not usable/validatable data. Ignored.

## What SURVIVED (for contrast)
- **BTC, ETH, NQ daily TSMOM** — durable in both halves → the book (see `../WORKS/`).

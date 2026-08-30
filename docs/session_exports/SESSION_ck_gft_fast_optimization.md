# SESSION EXPORT — CK_GFT_Fast2 Optimization & Backtest Validation

> **Purpose:** Complete, honest handoff so a future agent can fully recover this session's state.
> **Export date:** 2026-07-22
> **Repository:** https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED
> **Branch this file lives on:** `kiro/validation-toolkit`
> **Communication language with user:** Bengali (Bangla). Code in MQL5.

---

## 0. HONESTY / STATUS BANNER (read this first)

- **The single most important unresolved problem in this session:** the **Python backtester results DO NOT match MetaTrader 5 (MT5) real results.** They diverge massively. Any number labeled "Python" below is **NOT trustworthy** until an MT5-accurate backtester is built and validated.
- **Only ONE strategy is MT5-verified as the best real result: V20 (+$4,456, DD 11.8%).** All bigger numbers ($10,546, $32K, $40K) came from the inaccurate Python backtester and did **not** reproduce in MT5.
- **The user's stated profit target ($35,000 in 6 months / $70,000 in 1 year) is very likely NOT achievable** with the current constraints (single pair XAUUSD, fixed lot 0.05–0.08, DD ≤ ~13%). A mathematical ceiling exists. Be honest and supportive about this — do not fabricate hope with fake backtest numbers.
- **An MT5-accurate backtester was NEVER successfully built.** This is the #1 next task.

---

## 1. PROJECT GOAL

**Pass a Goat Funded Trader (GFT) 5K prop-firm challenge, then maximize profit.**

- Firm: Goat Funded Trader (GFT) — 5K 2-Step Standard account
- Symbol: **XAUUSD only**
- Timeframe: **M5**
- Initial balance: **$5,000**
- Lot: **0.05–0.08 fixed** (user says this CANNOT be increased)
- Broker used for MT5 testing: **MetaQuotes Demo (server time GMT+3)**
- User's REAL target (ambitious): **$35,000 in 6 months / $70,000 in 1 year**

### GFT 5K 2-Step Standard — Firm Rules

| Rule | Phase 1 | Phase 2 | Funded |
|------|---------|---------|--------|
| Profit Target | 10% ($500) | 5% ($250) | None |
| Daily Drawdown | 5% ($250) | 5% ($250) | 5% |
| Max Overall Loss (Static) | 10% ($500) | 10% ($500) | 10% |
| Min Trading Days | 3 | 3 | 4 |
| Max Daily Profit | No Limit | No Limit | $3,000 |
| Consistency Rule | No | No | No |
| Profit Split | - | - | 80% |

**Drawdown is ABSOLUTE priority over profit.** Static max loss = $500 from initial balance.

---

## 2. THE CORE STRATEGY (Knee Breakout — the proven base)

The fundamentally working strategy across the whole session is the **"knee breakout"** (originally V8):

- **Pattern:** Green run (bullish momentum) → a Red "knee" (pullback candle) → price **breaks above the knee's high** → **BUY**. Mirror logic for SELL (red run → green knee → break below knee low → SELL).
- **Trend filter:** EMA21 / EMA50 on M5.
- **Break-even:** move SL to BE at 1R.
- **Entry strength filter:** candle body > 60% of range (70% for sells).
- **Sell side needs stricter rules:** MinRun 3, Body 70%.

### User's latest stated understanding of the "real edge" (from their most recent prompts)
> ⚠️ These are the user's words/beliefs, **not yet independently validated in this session**:
- Real edge window: **UTC 02:00–03:59** (broker GMT+3 → **05:00–06:59 broker time**).
- Green run → Red knee → break above knee high → BUY.
- Risk 0.35%, RR 2.0, BE at 1R.
- **Thursday/Friday: skip.** **Monday: half-risk.**
- **Process discipline (user's hard rule):** "NEVER over-filter. NEVER add multiple changes at once. ONE change → test → then next."

> NOTE: The session's own data experiments (V12–V15) found that a **session/time filter REMOVED good trades and hurt results.** This directly conflicts with the user's belief in the UTC 02:00–03:59 edge. This conflict is UNRESOLVED — a future agent should test the time-window edge carefully and honestly with an MT5-accurate backtester before trusting either side.

---

## 3. ALL VERSIONS TESTED — MT5-VERIFIED RESULTS

> These results were reported by the **user from real MT5 Strategy Tester runs** (except where noted as Python).

| Version | Result | PF | DD | Trades | Verdict / Lesson |
|--------|--------|----|----|--------|------------------|
| **V8** (original base, BUY only) | **+$4,732** | 1.87 | 12.9% | 224 (WR 32.6%) | Knee breakout; RR 2.5, Risk 0.35%. Fundamentally strong. |
| V10 (5 filters added) | **−$864** | 0.64 | — | — | ❌ Too many filters at once KILL profit. |
| V11 (relaxed filters) | +$140 | 1.06 | — | — | Marginal. Approach wrong. |
| V12 (session 07–21) | +$478 | 1.10 | — | 166 | Session filter removes good trades. |
| V13 (session 07–10, cooldown 45m, BE 1.3R, MaxTrades 2, MinSL 5) | +$1,036 | 1.57 | 7.7% | 58 (LR 0.90) | Best quality metrics but too few trades. |
| V14 (session 07–11, cooldown 30m, BE 1.2R) | +$828 | 1.39 | — | — | 10:00 hour = mostly losses. |
| V15 (SL 0.5ATR, MinSL 8, MaxTrades 4) | +$664 | 1.52 | — | 29 | MinSL 8 filters too many trades. Keep MinSL 5. |
| V16 (V8 base + daily loss limit, no session/cooldown) | +$3,217 | 1.45 | 14.7% | — | V8 works best WITHOUT session/cooldown. |
| V17 (V16 + RR 2.0 + entry strength 60% body) | +$2,921 | 1.51 | 9.8% | — (LR 0.94, Recovery 3.54) | RR 2.0 better than 2.5 for WR. |
| V18 (V17 + SELL side) | +$3,715 | 1.45 | 11.88% | — (Recovery 4.64, LR 0.94) | Buy WR 40.46%, Sell WR 35.94%. Sell adds profit, lower WR. |
| V19 (V18 + sell stricter: MinRun 3, Body 70%) | +$3,717 | 1.56 | 12.94% | — (Max consec loss 8, LR 0.96) | Better PF, less consecutive loss. |
| **V20** (V19 + Risk 0.70%) | **+$4,456** | **1.49** | **11.8%** | **270** (LR 0.97) | ✅ **MT5-VERIFIED BEST.** Short WR 36.36%, Long WR 38.86%. |
| V21 (failed-breakout reversal) | +$4,524 | — | — | — | Only +$68 vs V20. Reversal doesn't help. |
| V22 (H1 + M15 + candle-close confirm) | +$710 | 1.13 | 20% | — | ❌ Multi-TF EMA filters KILL volume. |
| V23 (M15 candle direction + RR 2.5) | +$2,728 | — | — | — | Worse than V20. |
| V24 (VWAP + RSI confirm) | +$4,160 | — | — | — | VWAP/RSI add no improvement. |
| V25 (adaptive RR + no daily limits + MaxTrades 6) | +$3,140 | — | **34%** | — | ❌ Removing daily limits → DD explodes. |
| V26 (dual signal: knee + EMA pullback) | +$1,239 | — | 22% | 432 | ❌ M5 EMA pullback too noisy. |
| FINAL Momentum (HA + EMA5 trend, no knee) | +$2,672 | — | 23% | — | Pure momentum works but DD high w/o position limits. |
| FINAL V2 (sell stricter momentum) | +$900 | 0.99 | — | — | ❌ Sell too strict kills it. |
| DKT (liquidity zones + session timing) | **−$344** | — | — | — | ❌ Session + liquidity together = almost no trades. |

### 🏆 V20 = THE MT5-VERIFIED BEST — EXACT SETTINGS
- Direction: **Buy + Sell** knee breakout
- **Risk: 0.70%** per trade
- **RR: 2.0**
- **MaxTrades: 4/day**
- **DailyLossStop: 1.5R**
- **MinSL: 5** points
- Entry strength: **60% body (buy) / 70% body (sell)**
- Trend: **EMA21 / EMA50** (M5)
- BE at **1R**
- Sell stricter: **MinRun 3, Body 70%**
- **Result: +$4,456, PF 1.49, DD 11.8%, LR 0.97, 270 trades.**
- **All later experiments (V21–V26, momentum, DKT) FAILED to beat V20.**

---

## 4. CRITICAL LEARNINGS

### ❌ NEVER DO
1. Never add multiple filters at once — always ONE at a time.
2. Never use a session/time filter — removed good trades (V12–V15). *(NOTE: conflicts with user's UTC 02:00–03:59 belief — unresolved.)*
3. Never use H1/M15 EMA trend filter — too restrictive (V22).
4. Never use candle-close confirmation — late entry = worse.
5. Never remove daily loss limits — DD explodes (V25).
6. Never use M5 EMA pullback entries — too noisy (V26).
7. Never force minimum lot — reject the trade instead.
8. Never calculate TP from trigger price — use actual fill price.
9. Never use ATR from current bar (shift 0) — use completed bar (shift 1).
10. Never count failed orders as trades.

### ✅ WHAT WORKS
1. Knee breakout (V8 base) — proven PF 1.87.
2. EMA21/50 trend filter on M5 — simple and effective.
3. Entry strength (body > 60% of range).
4. RR 2.0 — better WR balance than 2.5.
5. BE at 1R — protects capital.
6. Buy + Sell — adds profit without killing quality.
7. Sell needs stricter rules (MinRun 3, Body 70%).
8. DailyLossStop 1.5R — prevents bad-day damage.
9. MaxTrades 4/day — good balance.
10. No session filter, no cooldown — let strategy trade freely.

---

## 5. ⚠️ THE PYTHON ≠ MT5 PROBLEM (most important open issue)

A Python backtester was built on real exported MT5 CSV data. It produced results that **do not reproduce in MT5**:

| Metric | Python backtester said | MT5 real result (same strategy) |
|--------|------------------------|--------------------------------|
| Profit | **+$10,546** | **+$2,861** |
| Drawdown | **2.75%** | **48%** |
| Profit Factor | (high) | **1.05** |
| Trades | — | **1,661** (3,322 deals) |

Strategy tested = "HA Green/Red + EMA5>EMA21>EMA50 + Trailing 6×ATR, SL 0.7×ATR, Risk 2%, single position." Python called it a dream; MT5 called it garbage.

### Why Python ≠ MT5 (root causes identified)
1. Python used **Close as entry price**; MT5 uses **Ask/Bid with spread**.
2. Python did **not** properly simulate **within-bar** price movement.
3. Python ignored **slippage**.
4. Python entered on the **same bar** as the signal; MT5 has next-bar delay.
5. Python's SL/TP check was simplified; MT5 checks **tick-by-tick**.

### Requirements for an MT5-ACCURATE backtester (TO BUILD)
- Entry = Close + spread (buy) / Close − spread (sell).
- **SL checked BEFORE TP** on the same bar (worst-case fill).
- Entry on the **NEXT bar** after signal (never same bar).
- No entry + exit on the same bar.
- Use the **Spread column** from the CSV data.
- Add commission if applicable.
- Lot/profit calc must match MT5's `OrderCalcProfit`.
- **Validation gate:** the accurate backtester must reproduce **V20 ≈ +$4,456** before its results are trusted.

---

## 6. DATA & ARTIFACTS

### Market data (referenced; may need re-upload)
- File: `XAUUSD_M5_202508010105_202607271000.csv`
- **68,419 bars**, Aug 2025 – Jul 2026.
- Tab-separated. Columns: `Date, Time, Open, High, Low, Close, TickVol, Vol, Spread`.
- Backtests filtered to **2026-01-01+ = 38,885 bars**.
- ⚠️ **At export time this CSV blob is MISSING from the local clone** (git fsck: "missing blob 181b5508…"). It was previously uploaded to the repo but is not fetchable in this sandbox. May need re-upload/re-fetch to use it.

### MT5 report parsed
- File: `ReportTester-109861033.html`
- Encoding: **UTF-16-LE** (important when parsing).
- **3,322 deals = 1,661 trades.**
- Strategy: `CK_GFT_BEST_Strategy.v2`, XAUUSD M5, 2026.01.01–2026.07.28.

### MQL5 files in repo (on `main`)
- `CK_GFT_Fast2_V811.mq5` — V8.20 bug-fixed version
- `CK_GFT_LIR_V1.mq5` — Liquidity Injection Retest strategy
- `CK_GFT_DKT_V1.mq5` — DKT Operator strategy (failed −$344)
- `CK_GFT_BEST_Strategy.mq5` — HA+EMA+Trailing (Python said great, MT5 said bad)
- `CK_XAU_DonchianTrend_H2_V1_FIXED.mq5` — Donchian trend H2 (uploaded by user, not yet analyzed in depth)
- `CK_XAU_DonchianTrend_H2_V1_RESEARCH` — research notes
- `stored_strategies.json` — 49 Python strategies claiming $15K+ (UNVERIFIED in MT5)
- `PROMPT_LEDGER.md` — full V8→V26 knowledge ledger (source of much of this doc)

### Referenced but NOT in repo
- `HANDOVER_DOCUMENT.md` — user mentioned it; **does not exist** in repo.
- `CK_GFT_Fast_v13.mq5` — user mentioned it; **does not exist** in repo.

---

## 7. USER PREFERENCES & WORKING STYLE
- Lot: 0.05–0.08 FIXED (cannot increase).
- Pair: XAUUSD ONLY (no multi-pair).
- Timeframe: M5. Account: $5,000 initial.
- Friday trading: preferably OFF (data showed losses).
- Thursday London: OFF (DKT rule). Monday: half-risk.
- Code: full compile-ready MQL5.
- Delivery: push to GitHub, share raw link.
- **Communication: Bengali (Bangla).**
- User is emotionally invested — be honest but supportive.
- Hard process rule: **ONE change → test in MT5 → then next.** No batching changes.

---

## 8. NEXT STEPS (priority order)
1. **Build an MT5-accurate Python backtester** (spread, SL-before-TP, next-bar entry, tick-worst-case). Validate it reproduces **V20 ≈ +$4,456 / DD 11.8%** before trusting anything.
2. Re-upload the CSV data if a future agent needs it (its blob is missing from the local clone).
3. Honestly test the user's **UTC 02:00–03:59 edge** hypothesis vs the session's finding that session filters hurt. Resolve the conflict with data.
4. Only after the backtester is validated, optimize toward **≤ 13% DD**. Set realistic expectations vs the $35K target.
5. Generate final compile-ready MQL5 from validated params.

---

## 9. TOOLING / ENV NOTES FOR NEXT AGENT
- Repo path in sandbox: `/projects/sandbox/CK_GFT_Fast2_V820_FIXED`
- **Git push nuance:** the `origin` remote URL is missing the `/github/` gateway provider segment, so `git push origin …` fails with "Missing header field, please provide ProviderId". Push using the plain GitHub URL instead — the configured `insteadOf` rule rewrites it correctly: `git push https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED.git <branch>`.
- **Corrupt object:** the local clone is missing blob `181b5508…` for the CSV (git fsck broken link). Do NOT stage the resulting CSV/HTML deletions when committing unrelated work; stage only your intended files.
- Never push directly to `main`/`master` unless the user asks; use a feature branch + PR.
- The `SPEC/dof_ledger.py` append-only hash-chained ledger IS present on branch `kiro/validation-toolkit`. Append a `SESSION_EXPORT` record for every session export and run `verify`.

---

*End of session export. Everything above reflects the actual session state as honestly as possible. Numbers labeled "Python" are unverified; only V20 is MT5-verified.*

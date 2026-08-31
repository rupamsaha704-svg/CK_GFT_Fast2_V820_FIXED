# SESSION EXPORT — Institutional Gold Trader Pro X → PropFirm EA V3 (with FIRST real backtest)

> **Purpose:** Complete, honest handoff so a future agent (with NO access to this chat) can fully
> recover and continue this session's work.
> **Export date:** 2026-07-25 (session clock shown in chat) / written during 2026-08-29 consolidation window.
> **Consolidation repo:** https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED
> **Branch this file lives on:** `kiro/validation-toolkit`
> **User communication language:** Bengali (Bangla). Code in MQL5 + one Python script.
> **Source-of-truth GitHub repo for this session's code:** `https://github.com/mahamahagyaan-cpu/xau-smart-ea`

---

## 0. HONESTY / STATUS BANNER (READ FIRST)

1. **This session is RELATED TO BUT DISTINCT FROM** the existing export
   `SESSION_xau_smart_ea_breakout_retest.md` (ledger seq 40) on this same branch. That earlier
   file documented an EARLIER XAU Smart EA (V1→V3Final) and stated NO backtest existed.
   **THIS session went further and produced NEW artifacts not in that file**, most importantly:
   - a **20-file modular architecture** ("Institutional Gold Trader Pro X v2.0"),
   - a **single-file V2** that had a real compile error which was then fixed,
   - a **simplified V3** (`Institutional_Gold_Trader_ProX_V3.mq5`),
   - a **PropFirm EA V3** (`Institutional_PropFirm_EA_V3.mq5`, Multi-TF Breakout Retest),
   - **THE FIRST ACTUAL MT5 STRATEGY-TESTER BACKTEST RESULT** in this whole line of work,
   - a **Python Backtest Analyzer** script.

2. **A REAL BACKTEST WAS RUN THIS TIME** (unlike the earlier session). The user ran
   `Institutional_PropFirm_EA_V3.mq5` in the MT5 Strategy Tester on XAUUSD M5 and shared
   screenshots. Numbers below are **read from photographs of the screen** (slightly blurry), so
   treat ±small reading error as possible. See §4 for the full result and the one figure that was
   internally inconsistent between the screenshot and my chat text (Recovery Factor).

3. **The code was NEVER compiled by a real MQL5 compiler inside the sandbox** (no MetaEditor here).
   HOWEVER, the user DID compile `Institutional_Gold_Trader_ProX_V2.mq5` in their own MetaEditor and
   it produced a **real compile error** ("function declarations are allowed on global, namespace or
   class scope only" at ~line 1075). That was a genuine bug (a nested function inside
   `UpdateDashboard()`), which I fixed. So at least the V2 single-file was compiled by the user.
   The later `Institutional_PropFirm_EA_V3.mq5` DID compile & run for the user (it produced the
   backtest), so it is compile-clean on their build. The 20-file modular version was NEVER confirmed
   compiled.

4. **Account identity clue:** The MT5 demo account in the backtest screenshots is
   **"Rupam Saha", login 109861021, MetaQuotes-Demo, Hedge**. The consolidation repo owner is
   `rupamsaha704-svg`. The code was pushed to `mahamahagyaan-cpu/xau-smart-ea`. Strong signal that
   **`mahamahagyaan-cpu` and `rupamsaha704-svg` are the SAME person (Rupam Saha)** using two GitHub
   accounts. Not 100% certain, but likely.

5. **The user is a self-described beginner** at GitHub and MQL5, Bengali speaker. Chat copy-paste
   kept corrupting the code. The reliable delivery method is: **push to GitHub → open file → click
   "Raw" → Ctrl+A / Ctrl+C → paste into MetaEditor.** Use the `raw.githubusercontent.com` URL.

6. **No profit is promised or proven.** 10 trades is far too few to conclude anything. The user
   himself correctly concluded the EA is NOT ready for a prop-firm challenge yet.

---

## 1. PURPOSE / GOAL OF THIS SESSION

Build a **production-grade MQL5 Expert Advisor for XAUUSD (Gold)** using **Smart Money Concept /
market-structure + breakout + retest** logic, with **prop-firm ($5,000, 5ers/GFT/FTMO-style) risk
controls**, that:
- compiles cleanly in MetaEditor (0 errors, 0 warnings),
- actually TAKES TRADES in the Strategy Tester (an earlier version took 0 trades — over-filtered),
- is data-driven: backtest → analyze → improve, not guesswork.

The session also pivoted (near the end) toward building a **Python analysis + automation pipeline**
so improvements are measured, not guessed.

Fixed context throughout:
- **Symbol:** XAUUSD / Gold only
- **Execution timeframe:** M5
- **Structure timeframe:** M15
- **Bias timeframe:** H1 (added in the PropFirm V3)
- **Direction:** BUY and SELL
- **Account:** $5,000 evaluation, max lot 0.06 (PropFirm V3) / 0.05 (earlier), strict DD control

---

## 2. TIMELINE / VERSION HISTORY (what was produced this session, in order)

The session actually opened with a long back-and-forth writing a **5-part written specification**
before any code. Then code was produced. Order:

1. **Written spec docs (no code)** — pushed to `mahamahagyaan-cpu/xau-smart-ea` in an
   `Institutional_Gold_Trader_ProX/` folder:
   - `Part-1_SRS.md` — Software Requirements Spec
   - `Part-2_Inputs_Specification.md` — all EA inputs + defaults
   - `Part-3_Algorithm_Flow.md` — 21-step flowchart-style logic
   - `Part-4_AI_Coding_Prompt.md` — self-contained coder prompt
   - `Part-5_Strategy_Optimization.md` — enhancement layer (FVG, Order Block, Quality Score, etc.)
   - `Master_Specification_v2.0.md` and `Final_Master_Specification_v2.0_Professional.md` —
     consolidated 12-module blueprint (Market Structure, Liquidity, Displacement, FVG, Entry, Risk,
     Trade Mgmt, Protection, News/Session, Confidence Score, Dashboard, Market Condition).

2. **"Institutional Gold Trader Pro X v2.0" — 20-file MODULAR EA** — folder `InstitutionalGoldTraderProX/`:
   - `Main.mq5` + `Modules/` with 19 `.mqh` files: Utilities, Logger, IndicatorManager,
     SwingDetector, MarketStructure, BOSDetector, LiquidityDetector, OrderBlock, FVGDetector,
     TrendFilter, TradeFilters, SessionFilter, NewsFilter, RiskManager, TradeManager,
     ProtectionEngine, EntryLogic, ExitLogic, Dashboard.
   - ~4,516 lines total. **Never confirmed compiled.** 16-condition entry (very strict).

3. **`Institutional_Gold_Trader_ProX_V2.mq5` — SINGLE-FILE version** (~1,190 lines) — merged all
   modules into one file for easy copy-paste. **HAD A COMPILE ERROR** (nested function). Fixed
   (see §8). This is the version the user compiled first.

4. **`Institutional_Gold_Trader_ProX_V3.mq5` — SIMPLIFIED** (~586 lines) — because the strict
   version risked taking 0 trades. Removed FVG/OrderBlock/Multi-TF alignment; kept BOS + Retest +
   EMA + ADX + ATR; relaxed ADX to 20, retest tolerance 0.5 ATR, session 7–21, max 3 trades/day,
   risk 0.5%, full `Print()` debug at each step. Intent: GUARANTEE trades.

5. **`Institutional_PropFirm_EA_V3.mq5` — "Multi-Timeframe Breakout Retest EA, Prop Firm
   Risk-Controlled"** (~931 lines) — the fullest single-file version, built from a very detailed
   user spec (see §5). **THIS is the one that was actually backtested** (§4).

6. **`Python_Analyzer/backtest_analyzer.py`** (~357 lines) — connects to MT5 via the `MetaTrader5`
   python package, pulls closed deals by magic number, computes PF/WR/DD/RF/expectancy/RR, time &
   direction analysis, consecutive streaks, a 0–9 "VERDICT" score, and recommendations. **Never
   confirmed run by the user.** Caveat: it reads the LIVE/terminal account history, not the
   Strategy-Tester history — a separate HTML-report parser was promised but NOT built.

> IMPORTANT: All of items 1–6 were pushed to **`mahamahagyaan-cpu/xau-smart-ea`** (branch `main`),
> NOT to the consolidation repo. That repo is the source of truth for the actual code. This export
> captures the design, decisions, results, and the full text of the two most important EAs (V3 and
> PropFirm V3) plus the Python analyzer, in case that repo is lost.

---

## 3. STRATEGY RULES

### 3.1 `Institutional_Gold_Trader_ProX_V3.mq5` (simplified, "guarantee trades") logic
- **Bias/filter:** EMA200 on M15. Price above EMA → BUY only; below → SELL only.
- **Structure:** find recent swing high/low (swing strength = 3 bars each side) over lookback 20 (M15).
- **BOS:** a recent M15 candle CLOSES beyond the swing (above SH for buy, below SL for sell) and body
  in direction.
- **Retest:** price returns within `0.5 × ATR` of the broken level (checked on past bars + current price).
- **Confirmation:** last closed M5 candle in the trade direction (bullish for buy, bearish for sell).
- **SL:** `ATR × 1.5` (min-distance validated vs broker stops level; falls back to broker min + 20 pts).
- **TP:** `RR × SL`, RR default 2.0.
- **Risk:** 0.5% per trade; max lot 0.1; lot from tickvalue/ticksize/point.
- **BE:** at +1.0R move SL to entry + 15 pts (buffer). **Trail:** starts +1.3R, ATR×1.0, min step 15 pts.
- **Protection:** max 3 trades/day; daily loss stop 2.0%; overall DD stop 6.0% (uses day-start equity).
- **Session:** hours 7–21 (broad); weekend blocked.
- **Magic:** 30260001. Full `Print()` debug at each rejection.

### 3.2 `Institutional_PropFirm_EA_V3.mq5` (the backtested one) logic
This implements the user's detailed "Multi-Timeframe Breakout Retest EA — Prop Firm Risk-Controlled"
spec. Key rules (all exposed as inputs):
- **Bias:** H1 closed price vs **EMA200 (H1)**. Above → long bias; below → short bias.
- **Structure (M15):** two most-recent confirmed swing highs & lows (swing strength 2 each side,
  lookback 30). Bullish requires **HH + HL** (sh1>sh2 AND sl1>sl2); bearish requires **LH + LL**.
- **BOS (M15):** a recent candle CLOSES beyond the latest swing (above sh1 / below sl1).
- **Retest (M15):** price returns within `0.25 × ATR(M15,14)` of the broken level.
- **Confirmation (M5):** last CLOSED M5 candle is either
  - a **rejection/pin**: (bull) lower wick ≥ 2× body AND close in top 50% AND bullish close;
    (bear) mirror; OR
  - an **engulfing**: current body engulfs previous opposite-color body.
- **SL:** structure swing ± `0.20 × ATR` buffer. **Reject trade if SL distance > `2.0 × ATR`** or
  below broker min stop.
- **TP:** Standard `1.5R` (input `inp_StandardRR`) or Strong `2.0R` (`inp_StrongRR`, toggle
  `inp_UseStrongRR=false` by default). Strong-setup classification is input-driven, NOT invented.
- **Trade management:** profit-protection flag at +0.8R; **BE at +1.0R** (entry ± 0.05R buffer);
  **ATR trailing from +1.5R** at `1.0 × ATR`; SL only ever moves to reduce risk (never loosened).
- **Min holding time:** 120 seconds before management modifies.
- **Cooldown:** after 1 loss → 30 min; after 2 consecutive → 120 min; after 3 consecutive → stop for
  the rest of the day (resets next day). A win resets the consecutive counter.
- **Risk:** `inp_RiskPct` default **1.0%** of equity (NOTE: higher than earlier 0.25%); **max lot
  0.06**; lot computed from real tick value/size; skip if below broker min.
- **Margin guard:** compute `OrderCalcMargin`; if required/equity > **77%**, skip.
- **Max positions:** 1 (counts only this EA's magic).
- **Daily loss stop:** **1.25%** of day-start equity → stop new trades (manage existing).
- **Emergency stop:** **9.90%** equity DD from `inp_InitBalance` (default 5000) → PERMANENT lock,
  persisted via terminal **Global Variable** `PropV3_EmergencyLock_<magic>`; requires manual
  `inp_ResetEmergency=true` to clear.
- **Sessions (server hours):** Asia (enabled, 0→LondonStart), London 8–12, New York 13–20; weekend off.
- **Spread filter:** max 50 points. **Slippage/deviation:** 20 points.
- **Magic:** 30300001. Comment "PropV3". `inp_Debug` prints each rejection reason.

---

## 4. DATA — THE ACTUAL BACKTEST RESULT (READ FROM SCREENSHOTS)

**EA:** `Institutional_PropFirm_EA_V3.mq5` · **Symbol:** XAUUSD · **TF:** M5 ·
**Account:** MetaQuotes-Demo, Hedge, login 109861021 "Rupam Saha" ·
**Bars:** 38,561 · **Ticks:** 95,388,731 · **History quality:** 100%.

| Metric | Value |
|---|---|
| Initial Deposit | 5000.00 |
| Total Net Profit | **+309.24** (approx; one view showed +309.84) |
| Gross Profit | 918.78 |
| Gross Loss | -609.54 |
| **Profit Factor** | **1.51** |
| Expected Payoff | 30.92 |
| **Recovery Factor** | **0.54 shown on screenshot** (⚠️ my chat text later said 0.84 — UNRESOLVED; trust screenshot 0.54) |
| Sharpe Ratio | 1.93 |
| Balance DD Maximal | 337.92 (**6.06%**) |
| Equity DD Maximal | 366.48 (**6.57%**) |
| Total Trades | **10** |
| Total Deals | 20 |
| Profit Trades | 4 (**40%**) |
| Loss Trades | 6 (60%) |
| **Long trades** | 3, won **0.00%** ← ⚠️ ALL LOSERS |
| **Short trades** | 7, won **57.14%** |
| Largest profit trade | 400.02 |
| Largest loss trade | -143.14 |
| Max consecutive wins | 3 (723.90) |
| Max consecutive losses | 3 (-337.92) |
| Z-Score | -0.21 (16.63%) |

**Interpretation agreed with the user:**
- Profitable (PF 1.51, +$309) and DD within many firms' 10% overall cap — a decent *start*.
- **BUT only 10 trades — statistically meaningless.** Need 200–500 trades across regimes.
- **Long side is broken: 0% win over 3 longs.** Something in the BUY path (EMA/structure/retest)
  is mis-selecting. This is the #1 thing to debug next.
- Recovery Factor weak (0.54).
- Win rate 40% is low for 1.5R; needs either higher RR or better confirmation.

---

## 5. USER'S DETAILED PROPFIRM SPEC (verbatim intent, for rebuilding)

The user pasted a very complete spec titled **"Multi-Timeframe Breakout Retest EA — Prop Firm
Risk-Controlled Version"**. Salient fixed rules a future agent MUST preserve:
- Instruments priority: **XAUUSD, NASDAQ, GBPUSD, EURUSD, BTCUSD** (support broker suffix/prefix via
  configurable symbol input / robust mapping). *(Current V3 only really handles the single chart
  symbol; multi-symbol scan is NOT implemented — see §7.)*
- Account: ref balance **5000**; Phase-1 target 8% = 400; Phase-2 target 6% = 300.
- Firm limits (SEPARATE from EA internal limits): **daily 4%**, **overall static 10%**.
  EA internal: **daily 1.25%**, **emergency 9.90%** — must stay strictly inside firm limits.
- TFs: **H1 bias / M15 structure / M5 execution**. Indicators ONLY: EMA200, ATR14, ADX14
  (min ADX 20). Do NOT add other indicators.
- Sessions: Asia enabled; London 08:00–12:00; NY 13:00–20:00; **timezone must be configurable**;
  do not hard-assume broker server tz or fixed DST.
- Long/Short entry, SL, TP, trade-management, cooldown, risk, margin, max-position, hedging-off,
  news-allowed, overnight/weekend-allowed rules = as coded in §3.2.
- "Valid trading day" = a day with ≥ +0.5% profit (track if practical; do NOT force-close winners
  to manufacture it).
- Swing = **confirmed** swing points only (default strength 2/side); **no look-ahead**, no repaint,
  operate on **closed candles**.
- The user (acting as senior architect) asked for these to be made explicit and deterministic:
  swing-confirmation bar count; exact rejection/engulfing definitions; duplicate-signal handling;
  ATR-trailing per-tick vs per-bar; cooldown persistence across restart; emergency manual-reset
  mechanism; timezone/DST determinism; partial-fill/filling-mode behavior; multi-symbol scan order.
  He also proposed a **Finite State Machine** (IDLE→WAIT_BREAKOUT→WAIT_RETEST→WAIT_CONFIRMATION→
  READY→IN_POSITION→COOLDOWN→EMERGENCY_LOCK) and full module separation — this FSM was **discussed
  but NOT yet implemented** in code.

---

## 6. MY INSTRUCTIONS / USER PREFERENCES (remember these)

- **Reply in Bengali.** User is a beginner; keep steps simple and numbered.
- **Deliver code via GitHub Raw copy**, never rely on chat paste (it corrupts code). Provide the
  `raw.githubusercontent.com/...` link and the Raw→Ctrl+A→Ctrl+C→MetaEditor steps.
- **Push to an existing repo** — the sandbox push tool only worked on a Kiro-cloned repo; a brand-new
  repo could not be created from the sandbox. User's working repo: `mahamahagyaan-cpu/xau-smart-ea`.
- **Be honest, no guarantees.** User explicitly accepts that no EA can guarantee passing a challenge
  or a fixed profit; goal = positive expectancy + low DD + rigorous testing.
- **Data-driven only from now on.** User's stated plan: freeze the EA, collect ALL reports
  (HTML+Report+Journal+Optimization), build a Python analyzer, then change ONE thing and re-test.
- No Martingale / Grid / Hedging / Averaging / Recovery. Max 1 position.

---

## 7. UNFINISHED WORK / NEXT STEPS

1. **Debug the BUY side (0% win over 3 longs)** in `Institutional_PropFirm_EA_V3.mq5` — inspect the
   H1-EMA bias + M15 HH/HL detection + retest tolerance for longs. This is the top priority.
2. **Get trade count up to 200–500** — run a 1–2 year backtest (2023–2024 dev, 2025 validation,
   2026 out-of-sample as the user proposed). Current 10 trades proves nothing.
3. **Python analyzer** (`backtest_analyzer.py`) is written but reads the *live terminal* account
   history, NOT the Strategy-Tester deals. **PROMISED-BUT-NOT-BUILT:** an **MT5 HTML-report parser**
   that ingests the exported Strategy-Tester report directly. Build that next.
4. Then the intended pipeline: **Auto-Optimization Controller** → **EA Improvement Loop**
   (data-driven single-change iterations). Only conceptual so far.
5. **Multi-symbol scanning is NOT implemented** despite the spec's 5-symbol priority list — the EA
   effectively trades the single attached chart symbol. If multi-symbol is wanted, enforce the
   GLOBAL max-1-position across the portfolio (do not open one per symbol).
6. The **20-file modular version was never confirmed to compile** — either compile it or treat the
   single-file `Institutional_PropFirm_EA_V3.mq5` as the canonical base.
7. FSM + full module separation (§5) was designed but not coded.

---

## 8. WARNINGS / BUGS / CAVEATS (a future agent MUST know)

1. **Fixed compile bug (V2):** `Institutional_Gold_Trader_ProX_V2.mq5` had a **nested function
   defined inside `UpdateDashboard()`** (`string trend_str(...) {...}`), causing MetaEditor error
   *"function declarations are allowed on global, namespace or class scope only"* (~line 1075).
   **Fix applied:** deleted the nested function (inline ternaries already did the job). Lesson:
   **MQL5 does NOT allow nested/local function definitions.** Never emit them.
2. **The "0 trades" trap:** the first over-filtered version (16 simultaneous conditions incl.
   FVG+OrderBlock+multi-TF alignment) took **0 trades** in the tester. The fix was to strip filters
   down (V3). Over-filtering = no trades. Keep entries realistic.
3. **Backtest numbers are read from blurry phone photos** — Net Profit read as 309.24 vs 309.84 in
   two glances; **Recovery Factor screenshot 0.54 vs my chat text 0.84 — unresolved.** Trust the
   screenshot (0.54) unless re-measured.
4. **Only 10 trades** — do NOT treat PF 1.51 / DD 6.57% as stable or tradeable. It is noise-level
   sample size.
5. **BUY logic is broken (0% win).** Do not deploy long side until fixed.
6. **Sessions use raw server hours** (0–7 Asia, 8–12 London, 13–20 NY) with **no timezone/DST
   handling**, despite the spec demanding configurable tz. Daily/emergency resets also key off
   server `dt.day`. On a non-GMT broker these windows will be wrong.
7. **Risk jumped to 1.0%/trade** in PropFirm V3 (was 0.25–0.5% earlier). At 1% with max DD rules,
   verify it cannot breach the firm's 4% daily / 10% overall.
8. **Emergency lock uses a terminal Global Variable** `PropV3_EmergencyLock_<magic>`. In the
   Strategy Tester this persists per-test; on a live terminal it persists across restarts and
   **must be manually reset** (`inp_ResetEmergency=true`) or the EA will stay locked forever.
9. **Python analyzer caveat:** it filters `deal.entry == 1` (DEAL_ENTRY_OUT) and `magic ==
   30300001`. If the magic changes, it silently finds nothing. It also needs `MetaTrader5` pip pkg
   and an OPEN, logged-in MT5 terminal; it does NOT parse Strategy-Tester HTML.
10. **Two GitHub accounts** (`mahamahagyaan-cpu` code vs `rupamsaha704-svg` consolidation, demo acct
    "Rupam Saha"): almost certainly the same person, but code lives in the OTHER repo.
11. **Sandbox could not create a new GitHub repo or push to an arbitrary remote** — only a
    Kiro-cloned existing repo worked. Plan delivery accordingly.

---

## 9. KEY FILE INVENTORY (source of truth = mahamahagyaan-cpu/xau-smart-ea @ main)

| File | ~Lines | Status |
|---|---|---|
| `Institutional_Gold_Trader_ProX/Part-1..5 + Master + Final_Master` (`.md`) | — | Spec docs, saved |
| `InstitutionalGoldTraderProX/Main.mq5` + `Modules/*.mqh` (20 files) | ~4,516 | Modular EA, **compile unconfirmed** |
| `Institutional_Gold_Trader_ProX_V2.mq5` | ~1,190 | Single-file; nested-fn bug **fixed** |
| `Institutional_Gold_Trader_ProX_V3.mq5` | ~586 | Simplified, debug-logged |
| `Institutional_PropFirm_EA_V3.mq5` | ~931 | **Backtested** (10 trades, PF1.51, DD6.57%) |
| `Python_Analyzer/backtest_analyzer.py` | ~357 | Written, **not run**; reads live acct not tester HTML |

> The full text of `Institutional_PropFirm_EA_V3.mq5`, `Institutional_Gold_Trader_ProX_V3.mq5`, and
> `backtest_analyzer.py` is preserved alongside this export under
> `docs/session_exports/institutional_propfirm_v3_files/` (added in the same commit). The 20-module
> version and spec `.md` files remain only in `mahamahagyaan-cpu/xau-smart-ea`.

---

## 10. ONE-PARAGRAPH RECOVERY SUMMARY

This session built, for a Bengali-speaking beginner (MT5 demo "Rupam Saha" 109861021), a series of
XAUUSD SMC breakout-retest EAs, culminating in **`Institutional_PropFirm_EA_V3.mq5`** (H1 EMA200
bias, M15 HH/HL structure + BOS + 0.25×ATR retest, M5 rejection/engulfing confirmation, ATR SL
capped at 2×ATR, 1.5R/2.0R TP, BE@1R, ATR-trail@1.5R, cooldowns 30m/2h/day, risk 1%/trade max lot
0.06, margin ≤77%, daily-loss 1.25%, emergency 9.90% GV-locked, sessions Asia/London/NY). Its FIRST
real MT5 backtest = **10 trades, PF 1.51, +$309, equity DD 6.57%, but LONGS 0% win** — promising
plumbing, useless sample size, broken buy side. Next: fix BUY logic, get 200–500 trades over
multi-year windows, build an MT5-HTML-report parser + optimization loop. Code source of truth =
`mahamahagyaan-cpu/xau-smart-ea` (branch main). Deliver via GitHub Raw copy; reply in Bengali; make
no profit guarantees.

*END OF EXPORT.*

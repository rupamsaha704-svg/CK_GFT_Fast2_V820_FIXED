# SESSION EXPORT — Python MT5-Style Backtester for CK_GFT_Fast2_V20 (XAUUSD M5)

> **Export date:** 2026-07-29 (session clock) / committed 2026-08-29 to repo
> **Session topic:** Building a from-scratch Python backtester that reproduces MetaTrader 5
> Strategy Tester behaviour, translating the `CK_GFT_Fast2_V20_Funded.mq5` "knee" EA into Python,
> and running it on EURUSD (synthetic) and XAUUSD (synthetic + **real MT5-exported data**).
> **Exported by:** the Kiro session that built `/projects/sandbox/py_mt5_backtester/`.

---

## ⚠️ READ THIS FIRST — THE SINGLE MOST IMPORTANT CAVEAT

**This session produced a PYTHON-ONLY backtester. Its results were NEVER verified against the real
MT5 Strategy Tester in this session.** A *previous* session already discovered (see ledger seq 39,
`SESSION_ck_gft_fast_optimization.md`) that an earlier Python backtester **did NOT match MT5**:

| Metric | Earlier Python backtester | Real MT5 (same strategy) |
|---|---|---|
| Net profit | +10,546 | +2,861 |
| Profit Factor | (very high) | 1.05 |
| Max Drawdown | 2.75% | **48%** |
| Trades | — | 1,661 |

That mismatch was **never resolved**, and the "MT5-accurate backtester" was declared **NOT built**.

**This session did NOT fix that problem.** It built a *new, independent* bar-based Python engine.
Its XAUUSD result (+$305.40 / +6.11%, see below) is **a Python-model number only**. Do NOT treat it
as MT5-equivalent or live-equivalent until it is cross-checked against an actual MT5 tester run on
the same data and date range. Treat every number in this document as *"what the Python model said"*,
not *"what MT5 will say"*.

---

## 1. PURPOSE / GOAL OF THIS SESSION

The user (Rupam Saha) wanted to be able to **fully automatically backtest their MQL5 EA in Python**,
with the explicit requirement that:

- The Python backtest must be **realistic** — spread, commission, swap, slippage, margin all modelled.
- The result should be such that **when later run in MT5 (or on a real/funded account) it comes out
  the same or better** — "no bad surprises". The user is trading a **GoatFundedTrader (GFT) 5K
  challenge** and wants confidence before going live.
- Ultimately: run the specific EA `CK_GFT_Fast2_V20_Funded.mq5` and report performance "with all
  details like MT5".

The session began as a discussion of the MetaQuotes article *"Python-MetaTrader 5 Strategy Tester
(Part 01): Trade Simulator"* (by Omega J Msigwa, GitHub `MegaJoctan/PyMetaTester`), which the user
pasted in. That article is only a **real-time trade simulator**, not a historical backtester, so we
built our own historical bar-based backtester instead.

---

## 2. THE STRATEGY — `CK_GFT_Fast2_V20_Funded.mq5` ("knee" breakout)

The user pasted the **full MQL5 source** of the EA. Key facts:

- **Name/version:** `CK_GFT_Fast2_V20_Funded`, version 20.00, `#property strict`.
- **Magic number:** `20260715`.
- **Deviation/slippage:** 30 points (`trade.SetDeviationInPoints(30)`).
- **Indicators:** ATR(14), EMA(21) fast, EMA(50) slow — all on the chart timeframe (intended M5).

### 2.1 Inputs (defaults)
```
InpMagic            = 20260715
InpRiskPercent      = 0.70      // % of balance risked per trade
InpRR               = 2.0       // reward:risk
InpBreakEvenAt1R    = true      // move SL to entry once +1R reached
InpMaxTradesPerDay  = 4
InpDailyLossStopR   = 1.5       // stop trading for the day at -1.5R realised
InpDailyProfitStopR = 5.0       // stop trading for the day at +5.0R realised
InpMaxSpreadPoints  = 50
InpMaxLot           = 0.08

InpUseTrend         = true
InpEMAPeriod        = 21        // fast EMA
InpEMASlow          = 50        // slow EMA

InpKneeMinRunBuy    = 2         // min consecutive green candles before the red "knee"
InpMinBodyRatioBuy  = 0.60      // strong-candle body/range on bar[2]

InpKneeMinRunSell   = 3         // sell stricter: min consecutive red candles before green knee
InpMinBodyRatioSell = 0.70      // sell stricter body ratio

InpValidBars        = 5         // setup remains armed for 5 bars
InpSLBufferATR      = 0.3       // SL buffer = 0.3 * ATR beyond the knee
InpMinSLPoints      = 5.0       // reject setups with 1R smaller than 5 points
```

### 2.2 Entry logic (the "knee" pattern)
**BUY setup** (evaluated on a new bar, only if no position & no armed setup):
1. Bar[1] (last closed) is **red** (the pullback / "knee").
2. Count a run of **green** candles from bar[2] backwards (up to bar[12]); need `run >= KneeMinRunBuy` (2).
3. Trend filter (if `UseTrend`): `EMA21(1) > EMA50(1)` AND `close[1] > EMA21(1)`.
4. Strong-candle filter: bar[2] body/range `>= MinBodyRatioBuy` (0.60).
5. If all pass: arm setup with
   - `trigger = high[1]` (knee high)
   - `SL = low[1] - 0.3*ATR`
   - `1R = trigger - SL`; require `1R >= MinSLPoints*point`
   - `TP = trigger + RR*1R`
   - stays armed for `ValidBars` (5) bars.
6. **Entry executes** when Ask >= trigger (buy stop-style trigger), subject to spread & daily limits.

**SELL setup** is the mirror, but **stricter**: needs 3 consecutive greens before a green knee (`KneeMinRunSell=3`),
body ratio 0.70, `EMA21<EMA50` and `close<EMA21`; `trigger=low[1]`, `SL=high[1]+0.3*ATR`, `TP=trigger-RR*1R`.
Entry when Bid <= trigger.

### 2.3 Money management & exits
- **Lot sizing:** risk `RiskPercent`% of *balance*; lots = riskMoney / (SL_distance/tickSize * tickValue),
  floored to volume step, clamped to `[volume_min, MaxLot=0.08]`.
- **Break-even:** if `BreakEvenAt1R`, once price reaches entry ± 1R, move SL to entry (`ManageBE`).
- **Daily gates (`TradingAllowed`)**: stop if realised R today >= +5R, or <= -1.5R, or trades today >= 4.
  Daily counters reset when the D1 bar changes (`ResetDaily`), based on `ACCOUNT_BALANCE` at day start.
- **Spread gate:** skip entry if current spread > `MaxSpreadPoints` (50).
- One position at a time (per symbol+magic).

---

## 3. WHAT WAS BUILT (the Python backtester)

Location in the originating session workspace: `/projects/sandbox/py_mt5_backtester/`.
**All source files are preserved alongside this document in**
`docs/session_exports/python_mt5_backtester_files/`.

| File | Role |
|---|---|
| `symbol_info.py` | MT5-like symbol properties (digits, point, tick value, contract size, swap, spread) for EURUSD/GBPUSD/USDJPY/XAUUSD; profit & margin math. |
| `data_loader.py` | (a) `generate_realistic_m5_data()` synthetic OHLC generator w/ impulse-pullback state machine & sessions; (b) `load_csv_data()` reads **real MT5 History-Center CSV** (tab-sep `<DATE> <TIME> <OPEN>…` OR comma `time,open,…`), with date-range filtering. |
| `backtest_engine.py` | Core engine: `Position`/`Deal` dataclasses, bar-by-bar processing, **intra-bar SL/TP detection via High/Low**, spread (Bid=close, Ask=close+spread), slippage, commission, **daily swap (triple on Wednesday)**, margin, equity/drawdown tracking, break-even SL modify. |
| `strategy_ck_gft.py` | Line-by-line Python translation of the EA: ATR(14), EMA(21/50) computed from bar history, `try_arm_setup`, `open_buy_trade`/`open_sell_trade`, `manage_break_even`, daily gates, `on_bar` driver. |
| `report_generator.py` | MT5-style text report + `equity_curve.png` + `trade_distribution.png` (matplotlib Agg). Metrics: PF, win rate, avg win/loss, largest, consecutive, drawdown, recovery factor, Sharpe, monthly breakdown, full trade list. |
| `run_backtest.py` | Config + orchestration. Holds the strategy params & symbol props; switches `DATA_SOURCE` between `"synthetic"` and `"csv"`. |
| `requirements.txt` | `pandas, numpy, matplotlib, tabulate`. |

**Environment:** Linux sandbox, Python 3.11. **MetaTrader5 cannot run here (Windows-only)**, which is
exactly why a self-contained data-driven engine was built rather than using the `MetaTrader5` module.

### 3.1 How to run (for the next agent)
```bash
cd py_mt5_backtester       # (recreate this dir from the preserved files)
pip install -r requirements.txt
# edit run_backtest.py: SYMBOL, DATA_SOURCE ("csv" or "synthetic"), CSV_PATH, dates, params
python3 run_backtest.py    # NOTE: bare `python` is not on PATH in the sandbox; use python3
```
Outputs go to `results/`: `backtest_report.txt`, `equity_curve.png`, `trade_distribution.png`.

---

## 4. DATA USED

- **EURUSD:** synthetic only (generator, seed=42). No real EURUSD data.
- **XAUUSD synthetic:** generator, base 2650, ~3500-point (=$35) daily range.
- **XAUUSD REAL:** obtained by cloning the user's repo **`rupamsaha704-svg/Trading_Project`**, which
  contained `XAUUSD_M5_202508010105_202607271000.zip` → extracted CSV = **68,418 M5 bars**,
  **2025-08-01 → 2026-07-27**, MT5 History-Center tab-separated format
  (`<DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> <TICKVOL> <VOL> <SPREAD>`).
  Gold ranged ~$3291 → ~$4100 in the file; after filtering to the backtest window
  (2026-01-02 → 2026-07-23) it was **38,512 bars**, price range **3942.48 – 5598.03**, avg spread ~4.4 points.
  - That same repo also had a small `XAUUSD_M5.csv` (only ~1000 bars) — **not used** (too short).

> NOTE: This consolidation repo *also* already contains its own
> `XAUUSD_M5_202508010105_202607271000.csv` at root — likely the same export.

---

## 5. THE RESULTS (Python model only — NOT MT5-verified)

### 5.1 Settings used (from the user's MT5 Strategy Tester screenshot)
The user sent a photo of their MT5 tester config for a *different* EA file (`XAU_Smart_EA_V3.ex5`)
but we adopted its **account/period settings** for the CK_GFT run:
- Symbol XAUUSD, M5, **Deposit $5000, Leverage 1:30**, "Every tick based on real ticks", Delays 50ms.
- Period we used: **2026-01-01 → 2026-07-24** (the CSV covered from 2026-01-02).
- Slippage modelled as 5 points; commission 0; swap long −43 / short +7 per lot/day (assumed, NOT confirmed).

### 5.2 XAUUSD on REAL data — headline (Python model)
```
Initial Deposit:   $5,000.00
Final Balance:     $5,305.40
Net Profit:        +$305.40   (+6.11%)
Profit Factor:     1.05
Total Trades:      411
Win Rate:          34.8%   (Buy 36.0% / Sell 31.6%)
Avg Win:           $44.75    Avg Loss: -$23.53
Largest Win:       $261.84   Largest Loss: -$102.80
Max Consecutive:   5 wins / 14 losses
Max Drawdown:      $699.44   (13.03%)
Sharpe Ratio:      0.46
Gross Profit:      $6,399.47  Gross Loss: -$6,094.07
Total Swap:        -$10.76    Commission: $0
Close reasons:     TP 150 / SL 261 / BE 0 / other 0
Direction P/L:     Buy +$495.78 / Sell -$190.38  (sell side lost money overall)
```

Monthly breakdown (real data, Python model):

| Month | Trades | Wins | Losses | Win% | Profit | Running Balance |
|---|---|---|---|---|---|---|
| 2026-01 | 67 | 23 | 42 | 34.3% | +$220.88 | $5,220.88 |
| 2026-02 | 57 | 17 | 39 | 29.8% | **−$322.22** | $4,898.66 |
| 2026-03 | 60 | 24 | 36 | 40.0% | +$136.98 | $5,035.64 |
| 2026-04 | 62 | 16 | 44 | 25.8% | **−$252.48** | $4,783.16 |
| 2026-05 | 56 | 24 | 32 | 42.9% | +$229.24 | $5,012.40 |
| 2026-06 | 56 | 20 | 32 | 35.7% | +$163.56 | $5,175.96 |
| 2026-07 | 53 | 19 | 34 | 35.8% | +$129.44 | $5,305.40 |

> The full 411-line trade list is in `python_mt5_backtester_files/XAUUSD_realdata_backtest_report.txt`.

### 5.3 XAUUSD on SYNTHETIC data (Python model) — for contrast, losing
```
Period 2026-01-01 → 2026-07-24, 42,049 synthetic bars, deposit $5000, 1:30
Final Balance: $4,798.16   Net: -$201.84 (-4.04%)
Trades 601, Win 33.3%, PF 0.82, Avg Win $4.71 / Avg Loss -$2.88
Largest Win $23.92 / Largest Loss -$10.32, MaxDD 5.24%
```
(An earlier synthetic XAUUSD run with too-small volatility produced **0 trades** — fixed by scaling
the gold daily range to 3500 points = $35 and using `point=0.01`.)

### 5.4 EURUSD on SYNTHETIC data (Python model) — losing
```
Period 2025-01-01 → 2025-06-30, ~36,865 synthetic bars, deposit $5000, 1:500
Final Balance: $4,813.86   Net: -$186.14 (-3.72%)
Trades 458, Win 27.5%, PF 0.42, MaxDD 3.73%
```

### 5.5 Honest interpretation given at the time
- With **RR = 1:2**, breakeven win-rate ≈ 33.3%. On synthetic random-ish data the strategy sat at
  27–33% → net loss. On **real gold data** it reached 34.8% and squeezed out **+6.11%** with PF 1.05.
- PF 1.05 is **thin** — a small increase in spread/commission/slippage could flip it negative.
- The strategy's **edge is entirely on the BUY side** in this window; **SELL lost money** (−$190.38).
  Gold trended up strongly 2026-01→2026-05 (≈$3900→$5600) which flatters longs — this is
  **regime-dependent**, consistent with the earlier session's "buy-only / regime-dependent / overfit"
  diagnosis (ledger seq 37 & 39).

---

## 6. KEY DECISIONS MADE (and why)

1. **Build a bar-based historical backtester, not use the pasted article's real-time simulator.**
   The article (`PyMetaTester`) only opens/monitors live trades; it can't iterate history. Reason:
   user wants historical backtesting.
2. **Self-contained engine (no `MetaTrader5` module).** MT5 is Windows-only; sandbox is Linux.
3. **Intra-bar SL/TP via High/Low** — closest bar-level approximation to MT5's tick fills.
   Bid = bar close; Ask = close + spread(points). For SELL, SL check uses `High + spread` (worst case).
4. **Use the bar's own `<SPREAD>` column** when present (real data) instead of a flat spread.
5. **Break-even applied on bar close**, not tick — a known source of divergence from MT5 (see WARNINGS).
6. **Trigger approximation:** because we're bar-based, a BUY triggers if `bar.high + spread >= trigger`
   within the armed window; SELL if `bar.low <= trigger`. In real MT5 this is a tick event.
7. **Swap:** charged at day change, **tripled on Wednesday** (weekend carry) — MT5 convention.
8. **Adopted the user's MT5 screenshot account settings** ($5000, 1:30, 2026-01-01→2026-07-24).
9. **Reused the user's real XAUUSD CSV** from `rupamsaha704-svg/Trading_Project` to get a meaningful
   (non-synthetic) result.

---

## 7. USER INSTRUCTIONS / PREFERENCES TO REMEMBER

- User is on a **GoatFundedTrader 5K challenge**; wants realism and **no negative surprises** going live.
- Wants results **"with all details, like MT5"** (full stats + trade list + monthly).
- Communicates in **Bengali**; wants replies in Bengali.
- Wants Python results that will **match or be beaten by** MT5 / live (i.e. conservative, not optimistic).
- Global learning already on file: *do not run slow/full multi-period validation unless asked; run
  fast tests only by default.*
- The user is losing AWS free-tier access and is **consolidating all sessions** into repo
  `rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED`, branch `kiro/validation-toolkit`.

---

## 8. UNFINISHED WORK / INTENDED NEXT STEPS

1. **CROSS-VALIDATE against real MT5** — the #1 open task. Run `CK_GFT_Fast2_V20_Funded.mq5` in the
   real MT5 Strategy Tester on the *same* XAUUSD data & window (2026-01-02→2026-07-23, $5000, 1:30,
   every-tick) and compare trade count, PF, net, DD against the Python +$305.40 / PF 1.05 / DD 13.03%.
   Until this matches, the Python numbers are unproven.
2. **Tune the bar-based trigger / BE to tick-accuracy** (or add a tick-replay mode) to close the gap
   the previous session found (Python DD 2.75% vs MT5 DD 48%).
3. **Confirm real broker cost inputs** — swap (−43/+7 assumed), commission (0 assumed), typical spread.
4. Offered but **not yet done:** parameter optimization to raise win rate; drawdown-reduction work;
   running the same EA in actual MT5 to compare.
5. The user's last on-screen options were: (1) compare in MT5, (2) optimize params, (3) reduce drawdown.
   **No selection was made before this export.**

---

## 9. WARNINGS / BUGS / CAVEATS FOR A FUTURE AGENT

- 🔴 **Python ≠ MT5 (unresolved, project-wide).** A prior session proved a Python backtester of this
  same EA diverged massively from MT5 (DD 2.75% vs 48%, net 10546 vs 2861). **This session did not
  resolve that.** The MT5-verified best config from that session was **V20: +4456, PF 1.49, DD 11.8%,
  270 trades** — trust MT5 numbers over any Python number.
- 🔴 **All results here are from a bar-based model**, which is optimistic about fills:
  - SL/TP "hit" is decided from bar High/Low, but the **exit price is assumed to be exactly SL/TP**
    (no gap-through / slippage beyond the fixed slippage points). Real MT5 can fill worse on gaps.
  - If **both SL and TP** lie inside one bar's range, the code checks **SL first for buys via low,
    then TP via high** — the actual intrabar order is unknown; this can bias results either way.
  - **Break-even moves at bar close**, so intrabar spikes that would have hit BE-SL in MT5 may be
    modelled differently.
- 🟠 **Thin edge:** PF 1.05 on real gold. Highly sensitive to costs. Sell side is net negative.
  Result is **regime-dependent** (strong 2026 gold uptrend). Do not assume it generalises.
- 🟠 **Synthetic data is not a validation** — the EURUSD and synthetic-XAUUSD losses are expected and
  mean little; only the **real-CSV** run is worth discussing, and even that needs MT5 confirmation.
- 🟠 **Assumptions baked in:** swap long −43 / short +7 per lot/day, commission 0, slippage 5 points,
  leverage 1:30, XAUUSD tick_value $1 / contract 100 oz. Verify against the real broker
  (MetaQuotes Demo / GFT broker) before trusting P/L.
- 🟠 **Timezone:** CSV timestamps used as-is (broker server time, likely GMT+2/+3). Daily reset &
  swap-day logic use the bar date directly — no explicit TZ/DST handling.
- 🟠 **`python` not on PATH** in the sandbox — must use `python3`.
- 🟠 The MT5 screenshot the user provided was actually for **`XAU_Smart_EA_V3.ex5`**, a *different* EA
  (see `SESSION_xau_smart_ea_breakout_retest.md`). We only borrowed its account/period settings; the
  strategy tested here is the CK_GFT knee EA.

---

## 10. FILE INVENTORY (preserved with this export)

In `docs/session_exports/python_mt5_backtester_files/`:
- `symbol_info.py`, `data_loader.py`, `backtest_engine.py`, `strategy_ck_gft.py`,
  `report_generator.py`, `run_backtest.py`, `requirements.txt`
- `XAUUSD_realdata_backtest_report.txt` — the full 411-trade MT5-style text report from the real-data run.

Real XAUUSD M5 data lives at repo root: `XAUUSD_M5_202508010105_202607271000.csv`
(and in `rupamsaha704-svg/Trading_Project`). The synthetic CSVs were scratch and are not preserved.

---

*End of session export. Every number above is a Python-model output and is explicitly NOT confirmed
against MetaTrader 5. The honest bottom line: the backtester runs, is realistic in structure, and gave
+6.11% / PF 1.05 on real 2026 gold data — but it must be reconciled with an actual MT5 tester run
before any trust is placed in it.*

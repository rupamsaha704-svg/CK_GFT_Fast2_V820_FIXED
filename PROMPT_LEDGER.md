# CK_GFT_Fast2 — Complete Prompt Ledger
## Everything Learned from V8 to V26+ (Full Knowledge Transfer)

---

## 🎯 PROJECT GOAL

**Funded Account Challenge Pass + Maximum Profit**
- Firm: Goat Funded Trader (GFT) 5K 2-Step Standard
- Phase 1: 10% profit ($500) target
- Phase 2: 5% profit ($250) target
- Static Drawdown Limit: 10% ($500 from initial balance)
- Daily Drawdown: 5% ($250)
- Lot: 0.05-0.08 (max)
- Symbol: XAUUSD only
- Timeframe: M5
- User's REAL target: $35,000 in 6 months / $70,000 in 1 year

---

## 📊 ALL VERSIONS TESTED (MT5 Verified Results)

### V8 (Original Base — BUY ONLY)
- **Profit: $4,732 | PF: 1.87 | Trades: 224 | WR: 32.6% | DD: 12.9%**
- Logic: Knee breakout (green run → red knee → break above knee high)
- EMA21/50 trend filter, BE at 1R, RR 2.5
- Risk: 0.35%, MaxLot: 0.08, MaxTrades: 3/day
- **LESSON: Original strategy fundamentally good. PF 1.87 is excellent.**

### V10 (5 Filters Added)
- **FAILED: -$864, PF 0.64**
- Added: Session 08-22, Entry confirmation (candle close wait), Partial profit 50% at 1R, Min run distance 1.5 ATR, H1 trend filter
- **LESSON: Too many filters KILL profits. Never add 5 filters at once.**

### V11 (Relaxed Filters)
- **Marginal: +$140, PF 1.06**
- **LESSON: Relaxing V10 filters only slightly improves. Fundamental approach wrong.**

### V12 (Session Filter Only 07-21)
- **Weak: +$478, PF 1.10, Trades: 166**
- **LESSON: Session filter removes good trades. V8 with NO session = better.**

### V13 (Session 07-10, Cooldown 45m, BE 1.3R, MaxTrades 2, MinSL 5)
- **Safe: +$1,036, PF 1.57, DD 7.7%, LR 0.90**
- **LESSON: Best quality metrics but too few trades (58). Conservative = safe but slow.**

### V14 (V13 + Session 07-11, Cooldown 30m, BE 1.2R)
- **Worse: +$828, PF 1.39**
- **LESSON: 10:00 hour = mostly losses. Don't expand to 10:00.**

### V15 (Wider SL 0.5ATR, MinSL 8, MaxTrades 4)
- **Low trades: +$664, PF 1.52, only 29 trades**
- **LESSON: MinSL 8 filters too many trades. Keep MinSL 5.**

### V16 (V8 Base + Daily Loss Limit, No Session, No Cooldown)
- **Good: +$3,217, PF 1.45, DD 14.7%**
- **LESSON: V8 strategy works best WITHOUT session/cooldown filters.**

### V17 (V16 + RR 2.0 + Entry Strength 60% body)
- **BEST BALANCED: +$2,921, PF 1.51, DD 9.8%, LR 0.94, Recovery 3.54**
- **LESSON: RR 2.0 better than 2.5 for win rate. Entry strength helps.**

### V18 (V17 + SELL Side Added)
- **+$3,715, PF 1.45, DD 11.88%, Recovery 4.64, LR 0.94**
- Buy WR: 40.46%, Sell WR: 35.94%
- **LESSON: SELL side adds profit but lower WR. Sell needs stricter rules.**

### V19 (V18 + Sell Stricter: MinRun 3, Body 70%)
- **+$3,717, PF 1.56, DD 12.94%, LR 0.96, Max Consec Loss 8**
- **LESSON: Sell stricter = better PF, same profit, less consecutive loss.**

### V20 (V19 + Risk 0.70%)
- **MT5 VERIFIED: +$4,456, PF 1.49, DD 11.8%, LR 0.97, Trades 270**
- Short WR: 36.36%, Long WR: 38.86%
- **THIS IS THE MT5-VERIFIED BEST. All later experiments failed to beat it.**
- **Settings: Risk 0.70%, RR 2.0, MaxTrades 4, DailyLoss 1.5R, MinSL 5**

### V21 (Failed Breakout Reversal)
- **+$4,524 — only +$68 more than V20**
- **LESSON: Reversal after SL hit doesn't help. Market is choppy.**

### V22 (H1 + M15 + Candle Close Confirmation)
- **DISASTER: +$710, PF 1.13, DD 20%**
- **LESSON: Multi-timeframe EMA filters KILL volume drastically.**

### V23 (M15 Candle Direction + RR 2.5)
- **Worse: +$2,728**
- **LESSON: M15 candle filter + RR 2.5 = worse than V20.**

### V24 (VWAP + RSI Confirmation)
- **+$4,160 — slightly less than V20**
- **LESSON: VWAP/RSI add no real improvement to this strategy.**

### V25 (Adaptive RR + No Daily Limits + MaxTrades 6)
- **DISASTER: +$3,140, DD 34%!**
- **LESSON: Removing daily limits = quality drops massively.**

### V26 (Dual Signal: Knee + EMA Pullback)
- **DISASTER: +$1,239, DD 22%, 432 trades**
- **LESSON: M5 EMA pullback = too noisy. Generates too many false signals.**

### FINAL Momentum (HA+EMA5 trend, no knee)
- **+$2,672, DD 23%**
- **LESSON: Pure momentum HA+EMA works but DD high without position limits.**

### FINAL V2 (Sell stricter momentum)
- **+$900, PF 0.99 — WORSE**
- **LESSON: Making sell too strict kills it.**

### DKT Strategy (Liquidity zones + Session timing)
- **-$344 — FAILED (too restrictive)**
- **LESSON: Session+Liquidity filter together = almost no trades.**

---

## 🧠 CRITICAL LEARNINGS (What WORKS vs What DOESN'T)

### ❌ NEVER DO:
1. **Never add multiple filters at once** — always one at a time
2. **Never use session filter** — removes good trades (V12-V15 proved this)
3. **Never use H1/M15 EMA trend filter** — too restrictive (V22 proved this)
4. **Never use candle close confirmation** — late entry = worse
5. **Never remove daily loss limits** — quality drops (V25 proved)
6. **Never use M5 EMA pullback entries** — too noisy (V26 proved)
7. **Never force minimum lot** — reject trade instead
8. **Never calculate TP from trigger price** — use actual fill price
9. **Never use ATR from current bar (shift 0)** — use completed bar (shift 1)
10. **Never count failed orders as trades**

### ✅ WHAT WORKS:
1. **Knee breakout (V8 base) = proven PF 1.87**
2. **EMA21/50 trend filter on M5** — simple and effective
3. **Entry strength (body > 60% of range)** — filters weak entries
4. **RR 2.0** — better balance than 2.5 for win rate
5. **BE at 1R** — protects capital
6. **Buy + Sell** — adds profit without killing quality
7. **Sell needs stricter rules** (MinRun 3, Body 70%)
8. **DailyLossStop 1.5R** — prevents bad day damage
9. **MaxTrades 4/day** — good balance
10. **No session filter, no cooldown** — let strategy trade freely
11. **Trailing stop with high multiple (6×ATR)** — lets big winners run
12. **Heiken Ashi + EMA5>EMA21>EMA50** — clean trend signal
13. **Compound lot (lot grows with balance)** — accelerates growth

---

## 📊 PYTHON BACKTEST FINDINGS

### Best Config (Python, NOT MT5 verified):
- **HA Green/Red + EMA5>EMA21>EMA50 + Trailing 6×ATR**
- SL: 0.7×ATR, Risk: 2%, MaxTrades: 3/day, Single position
- Python result: $10,546, DD 2.75% (static from initial)
- **WARNING: MT5 result was VERY different ($2,861, DD 48%)!**

### Why Python ≠ MT5:
1. Python uses Close as entry price; MT5 uses Ask/Bid with spread
2. Python doesn't properly simulate within-bar price movement
3. Python doesn't account for slippage
4. Python entry on same bar as signal; MT5 may have delay
5. Python SL/TP check is simplified; MT5 checks tick-by-tick
6. **MUST FIX: Need MT5-accurate backtester to get real results**

### MT5-Accurate Backtester Requirements:
- Entry = Close + Spread (for buy) / Close - Spread (for sell)
- SL checked BEFORE TP on same bar (worst-case)
- Entry on NEXT bar after signal (not same bar)
- No entry+exit on same bar
- Spread from data (column exists in CSV)
- Commission if applicable
- Proper lot calculation matching MT5's OrderCalcProfit

---

## 📋 FIRM RULES (GFT 5K 2-Step Standard)

| Rule | Phase 1 | Phase 2 | Funded |
|------|---------|---------|--------|
| Profit Target | 10% ($500) | 5% ($250) | None |
| Daily Drawdown | 5% ($250) | 5% ($250) | 5% |
| Max Overall Loss (Static) | 10% ($500) | 10% ($500) | 10% |
| Min Trading Days | 3 | 3 | 4 |
| Max Daily Profit | No Limit | No Limit | $3,000 |
| Consistency Rule | No | No | No |
| Profit Split | - | - | 80% |

---

## 📂 DATA AVAILABLE

- **XAUUSD M5 CSV**: `XAUUSD_M5_202508010105_202607271000.csv` (68,419 bars, Aug 2025 - Jul 2026)
- Format: Tab-separated, columns: Date, Time, Open, High, Low, Close, TickVol, Vol, Spread
- Located in GitHub repo: `rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED`

---

## 🎯 NEXT STEPS NEEDED

1. **Build MT5-accurate Python backtester** (spread, SL-first, next-bar entry)
2. **Validate against MT5 results** (V20 = $4,456 should match)
3. **Optimize strategy with accurate backtester**
4. **Target: $35,000 in 6 months with DD ≤ 13%**
5. **Final MQL5 code generation from optimized params**

---

## 📌 USER PREFERENCES

- Lot: 0.05-0.08 (FIXED, cannot increase)
- Pair: XAUUSD ONLY (no multi-pair)
- Timeframe: M5
- Account: $5,000 initial
- Friday trading: preferably OFF (data showed losses)
- Thursday London: OFF (DKT rule)
- Code format: Full MQL5 code ready to compile
- Delivery: Push to GitHub, share raw link
- Communication: Bengali (Bangla)

---

## 🔗 REPOSITORY

**https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED**

Files:
- `CK_GFT_Fast2_V811.mq5` — V8.20 bug-fixed version
- `CK_GFT_LIR_V1.mq5` — Liquidity Injection Retest strategy
- `CK_GFT_DKT_V1.mq5` — DKT Operator strategy
- `CK_GFT_BEST_Strategy.mq5` — Best strategy (HA+EMA+Trailing)
- `stored_strategies.json` — 49 Python strategies $15K+
- `XAUUSD_M5_202508010105_202607271000.csv` — Market data
- `PROMPT_LEDGER.md` — This file

---

## ⚠️ IMPORTANT WARNINGS FOR NEXT AI

1. **Python backtest results DO NOT match MT5** — always verify in MT5
2. **V20 ($4,456) is the only MT5-verified profitable strategy**
3. **$35K target with 0.08 lot, single pair, DD≤13% may not be achievable** — mathematical limit exists
4. **User is emotionally invested** — be honest but supportive
5. **User's funded account rules are STRICT** — DD is absolute priority over profit
6. **Build MT5-accurate backtester FIRST before claiming any results**

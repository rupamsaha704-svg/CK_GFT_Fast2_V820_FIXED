# SESSION EXPORT — CK_GFT_Fast EA for Goat Funded Trader ($5K, XAUUSD M5)

> Honest, exhaustive export of one Kiro session. Nothing here is fabricated.
> Where a number is an approximation or unverified, it is marked as such.
> Language of original discussion: Bengali. This document mixes Bengali intent + English technical detail.

---

## 1. PURPOSE OF THIS SESSION

Build and iteratively refine an **MT5 Expert Advisor** named **CK_GFT_Fast** that trades **XAUUSD on the M5 timeframe**, with the explicit goal of **passing a Goat Funded Trader (GFT) 2-Step Standard $5,000 challenge** and then surviving the **Funded** phase (which adds "Goat Guard").

The user is on a **MetaQuotes-Demo** account (server ~GMT+3) for backtesting, leverage was 1:10 on that demo. Real target firm = **Goat Funded Trader**.

The user's overarching priority near the end: **capital preservation / never breach**. Profit is welcome but "must not lose big; losing = real money lost." The user saved this money with difficulty.

---

## 2. STRATEGY — CORE LOGIC (the "knee breakout")

The base strategy (unchanged across all versions, originally "CK_GFT_Fast2 / v8.10"):

- **BUY setup:**
  - Previous closed bar (bar[1]) is **RED**.
  - Before that red "knee" candle, there must be **≥ 2 consecutive GREEN candles** (a bullish run). (`InpKneeMinRun = 2`, loop scans bars 2..12.)
  - Trend filter: `EMA(fast) > EMA(slow)` AND `close[1] > EMA(fast)`.
  - **Trigger** = High of the red knee candle. Enter BUY when price breaks **above** knee high.
  - **SL** = knee Low − (ATR14 × SL buffer).
  - **TP** = trigger + RR × (trigger − SL).
  - Setup valid for `InpValidBars` bars, else disarmed.
- **SELL setup (mirror, added in v17):**
  - Previous bar GREEN; before it ≥2 consecutive RED candles.
  - Trend: `EMA(fast) < EMA(slow)` AND `close[1] < EMA(fast)`.
  - Trigger = knee Low, break **below**. SL = knee High + ATR buffer. TP = trigger − RR × (SL − trigger).
- Only **one position at a time** (checks `MyPositions()==0`). **No hedging.**
- **Break-even** logic: at a chosen progress toward TP, move SL to entry.

### Optimized indicator/param values (from user's MT5 optimization, screenshot)
These were read off the user's Strategy Tester "Inputs" panel and baked in as defaults (v22 onward):

| Param | Value |
|---|---|
| InpRR | 3.0 |
| InpMaxTradesPerDay | 3 |
| InpEMAPeriod (fast) | 17 |
| InpEMASlow | 51 |
| InpKneeMinRun | 2 |
| InpValidBars | 8 |
| InpSLBufferATR | 0.29 |
| InpMaxSpreadPoints | 50 |
| InpUseTrend | true |
| Buy / Sell | both enabled |

> NOTE: earlier the user briefly explored a UTC 02:00–03:59 "whitelist" time window (v13) based on a
> trade-by-trade edge analysis, but the FINAL direction abandoned time-window filtering and used the
> optimized inputs above with full-day trading + strict money management instead.

---

## 3. GOAT FUNDED TRADER — RULES THAT MUST BE OBEYED ($5K, 2-Step Standard)

From the GFT FAQ the user pasted (converted to $5,000 account):

| Rule | Step 1 | Step 2 | Funded |
|---|---|---|---|
| Profit target | $500 (10%) | $250 (5%) | none |
| Daily drawdown (5%) | $250 | $250 | $250 |
| Max overall loss (10%, STATIC) | $4,500 floor | $4,500 | $4,500 |
| Min trading days | 3 | 3 | 4 (accounts bought ≥ 25 Jul 2026), each day ≥ 0.5% = **$25** profit |
| Consistency rule | none | none | none |

- **Daily drawdown** measured at 5PM EST rollover: 5% of the HIGHER of balance/equity that day = the day's floor. Must not be breached intraday either.
- **Max overall loss** = STATIC $4,500 (never below, balance OR equity).
- **Goat Guard (FUNDED phase only):** if floating loss reaches ~**$100** (≈2% of $5K) → 1st time: profit split drops 80%→50%; 2nd time: **account breach**. So in funded, floating loss must never approach $100.
- **Leverage:** Evaluation — Forex 1:100, Commodities/Indices (GOLD) **1:20**, Crypto 1:2. Funded — Forex 1:50, Commodities/Indices (GOLD) **1:10**, Crypto 1:2.
- Other stated firm rules (user reported as standard): **min 2-minute holding time**, **no hedging**, **no martingale**, **max 80% margin usage**.
- Profit split 80%; payout every 14 days; first 2 payouts capped at 6% of $5K = $300; funded daily profit cap $3,000 (irrelevant at $5K).

---

## 4. FINAL MONEY-MANAGEMENT RULES (decided with the user, implemented in v29)

These are the user's explicit, final instructions — follow strictly:

1. **Auto-risk lot sizing** so that a full SL hit loses ≈ **$85** (target), hard ceiling **$90**.
   - `lot = 85 / (SLdistance × contract$perLotPer$move)`.
2. **Lot range clamp: 0.06 – 0.09.**
   - If computed lot **> 0.09 → use 0.09** (loss will be < $85, fine).
   - If computed lot **< 0.06 → SKIP the trade** (SL too wide; do NOT enter). "0.06 এর নিচে entry দেবে না।"
3. **Max loss per trade = $85–$90, never beyond.** Achieved by the sizing + the SL (not by a fast force-close, to respect the 2-min rule).
4. **Max DAILY loss = $90.** Once the day's loss reaches $90 → **stop trading that day**, resume next day. Pre-open check blocks a new trade if `(today's realized loss) + (this trade's SL risk) > $90`. In practice this means ~1 losing trade per day; wins keep the day open.
   - Rationale (user): total budget is only $500; 3–4 uncontrolled losses = breach. Spread risk across days.
5. **No martingale (STRICT).** After a losing trade, the lot **must not increase** until the balance recovers to its prior high-water mark. While in drawdown, lot ceiling = the losing trade's lot. Once recovered/in-profit → full lot (up to 0.09) allowed again. "লস হলে লট বাড়ানো যাবে না" — firm treats this as a hard breach.
6. **2-minute rule + 0.01 lock.** After the trade is held **≥ 120 seconds** AND price has moved **≥ 25% of the way to TP**, close **0.01 lot** (a small "lock"). Nothing closes before 2 minutes. The rest of the lot runs on.
7. **Break-even at 65% progress.** When price reaches 65% of the distance to TP, move SL to entry (so from there we can't lose; we stay slightly in profit thanks to the 0.01 lock).
8. **Overall floor hard stop at $4,550** (NOT $4,500 — a $50 buffer before the real GFT breach). If equity ≤ $4,550 → close position + halt EA permanently.
9. **Evaluation and Funded use the SAME strict settings** — because it's an EA with fixed rules, we design for the strictest case (funded Goat Guard $100 floating) from the start. Since max floating ≈ $85 (one position), it stays under $100. ✅

---

## 5. FULL VERSION HISTORY (this repo has each as CK_GFT_Fast_vNN.mq5)

Honest record of what each iteration was and what happened:

- **v8.10 / CK_GFT_Fast2 (base):** original knee-breakout, BUY-only, RR 2.5, risk 0.35%. User's reference "best raw" result (~+$4,030 PF 1.98 in one long backtest per earlier notes; exact figure not re-verified this session).
- **v9:** added many filters at once (HTF H1 trend, session, ATR vol, sell, invalidation) → **made it worse** (PF ~0.88 to 1.06). Lesson: don't stack filters without edge; change ONE thing at a time.
- **PropKiller v1/v2/v3 (Asian-range breakout, different strategy):** produced **0 trades** repeatedly due to broker server-time vs UTC confusion, pip-vs-dollar range confusion (25 "pips" = $2.50 vs gold Asian range $5–15), and once the user ran the wrong EA. **Abandoned** — returned to the proven knee strategy.
- **v10:** knee base + UTC death-zone/Thu/Fri filters. Backtest (Jan–Apr 2026) ≈ +$2,876 PF 2.08; forward (Apr–Jul) ≈ +$427 PF 1.27; **avg win collapsed $221→$100** while win rate stayed ~33% → market regime change; RR 2.5 TP not being reached.
- **v11 / v12:** further filter iterations (whitelist UTC 02–03, Monday risk mult, London/NY block). Not all separately verified by the user.
- **v13:** whitelist approach + RR 2.0 + full Friday skip + Monday 0.5x + TP-from-actual-Ask + force-close-outside-window. (Also produced a HANDOVER_DOCUMENT.md earlier.)
- **v14:** partial TP (25% @25%, 25% @60%) + BE.
- **v15:** BE at 65% with a "+20% profit lock" idea; TP1 at 10%.
- **v16:** stripped back to pure v8.10 base + risk mgmt only (no time filters). Backtest showed ~67–83% WR but **avg win tiny ($14) vs avg loss ($48)** → net small/negative because partial TPs capped winners.
- **v17:** **added SELL side + RR 3.0** + partial TP1@10%/TP2@60% + BE@65%. This was a comparatively GOOD run.
  - **v17 verified MT5 report ("report 17" in repo):** Net **+$6,135.41**, PF **1.80**, Recovery **9.40**, Sharpe 17.96, 579 trades, Long 72.6% won / Short 64.7% won, **Profit trades 399 (68.9%) / Loss 180 (31.1%)**, avg profit **$34.69**, avg loss **−$42.80**, max consecutive losses **3 (−$249.93)**, Balance DD max 5.99%, Equity DD max 7.34%, **min holding time 0:00:05 (⚠ 5 seconds — 2-min rule violation), max holding 17:03:33, avg holding 1:03:06.** Period 2026.01.01–2026.08.01, deposit $5,000, leverage 1:10, inputs: Risk 0.35, RR 3.0, MaxTrades 3, EMA 21/50 (older), SLBufferATR 0.3, MaxLot 0.09, partial TP on.
- **v18:** RR 1.33, BE-at-65%-with-+20%-profit-lock. Backtest ≈ +$2,820, PF 1.48, WR 83%, but avg win $14 vs avg loss $48 (partial TP too aggressive).
- **v19:** removed TP1. Backtest ≈ +$2,986, PF 1.47, WR 74%, avg win $29 (better) but trade count dropped ~40% (daily loss stop tripping).
- **v20:** removed TP2 too (only BE). Result got worse — confirmed TP2 was providing downside savings, not capping upside.
- **v22:** returned to v17 logic, baked in the user's OPTIMIZED inputs (Risk 0.53, RR 3.0, EMA 17/51, ValidBars 8, SLBuffer 0.29, DailyLossStopR 0.9, DailyProfitStopR 3.4).
- **v23:** TP1 only @ (progress) with TP2 removed; some back-and-forth on the exact TP1 close ratio.
- **v24:** TP1 at 25% progress closing 0.02 (of 0.08), TP2 removed.
- **v25:** matched the optimization screenshot exactly; TP1 close ratio was 0.00 in that screenshot → TP1 removed, TP2 active (0.60 / 0.22). All optimized inputs baked.
- **v26:** added max-loss-per-trade force close ($230 → later $150).
- **v27:** after a max-loss hit, stop trading for the rest of that day (resume next day).
- **v28:** GFT compliance guards — min 2-min hold before EA-initiated closes, equity-based daily DD stop (4%), overall floor hard stop ($4,500), max loss per trade lowered to $150.
- **v29 (FINAL this session):** complete money-management rewrite per Section 4 (auto-risk $85, lot 0.06–0.09 clamp + skip, daily $90 cap, no-martingale, 2-min + 0.01 lock, BE@65%, overall floor $4,550). **This is the version to use.**

Each `CK_GFT_Fast_vNN.mq5` was pushed to its own branch `kiro/vNN-*`. v29 is on `kiro/v29-final-management`.

---

## 6. v29 PYTHON BACKTEST RESULTS (approximate — READ CAVEATS)

I (the agent) wrote an ad-hoc **bar-level Python simulation** of v29 over the CSV
`XAUUSD_M5_202508010105_202607271000.csv` (68,418 M5 bars, 2025-08-01 01:05 → 2026-07-27 10:00),
XAUUSD contract assumed 100 oz (so $1 price move = $100 per 1.0 lot).

**Results (corrected measurement, floating loss bounded at SL):**
- Net profit: **+$8,186.50** (starting $5,000; note balance was allowed to compound — NOT reset per GFT phase)
- Trades: **684**, Win rate **45.0%** (308 W / 376 L), RR 3.0
- **Worst TRUE daily equity drawdown: $89.61** → under the $90 cap ✅
- **Days exceeding $90 daily loss: 0** ✅
- **Biggest single-trade loss: −$84.16** → under $90 ✅
- **No-martingale violations: 0** ✅
- **Max lot used: 0.09** (within 0.06–0.09) ✅

**IMPORTANT CAVEATS (do not treat these numbers as final):**
1. This is **bar-level (M5 OHLC), NOT tick** data. MT5 tick backtest is the real test.
2. Conservative assumption: when a bar contains BOTH the SL and TP levels, I assumed **SL hit first** (worst case). Real fills may be slightly better.
3. **Spread and commission NOT modeled** → real net profit will be somewhat lower.
4. The **2-minute rule cannot be fully verified at bar level**; the 0.01 lock was approximated as "≥1 bar (5 min) after entry". MT5 will show true holding times.
5. First (buggy) measurement of daily DD used bar CLOSE for floating and wrongly reported worst days of $130–$352; that was a **measurement artifact** (close price overshooting the SL). When floating was correctly bounded at the SL, the true worst daily DD was **$89.61**. The correct figure is $89.61, not $352.
6. Net +$8,186 assumes continuous compounding on a growing balance; under GFT the account resets to $5K each phase, so the real-world meaning is "passes Step-1 $500 target comfortably", not raw $8K.

The Python script was ad-hoc/inline (run via `python3 <<EOF`), it was **not saved as a file** in the repo. If a future agent wants it, it must be re-derived from the v29 MQL5 logic; the exact inline script is in this session's chat history only.

---

## 7. THE FINAL EA CODE — CK_GFT_Fast_v29.mq5 (FULL, this is the source of truth)

> This file already exists in the repo on branch `kiro/v29-final-management`. Full contents reproduced here for safety.

```mql5
//+------------------------------------------------------------------+
//|                                             CK_GFT_Fast_v29.mq5  |
//|  Base: v28 logic + FINAL risk-management per user discussion      |
//|                                                                    |
//|  Strategy (UNCHANGED - optimized inputs):                          |
//|   BUY:  Green run + Red knee + uptrend, break above knee high     |
//|   SELL: Red run + Green knee + downtrend, break below knee low    |
//|   EMA 17/51, ValidBars 8, SLBuffer 0.29, RR 3.0                   |
//|                                                                    |
//|  NEW MANAGEMENT (v29):                                             |
//|   1. Auto-risk lot: sized so SL loss ~= $85, clamped [0.06, 0.09] |
//|      -> if computed lot < 0.06 (SL too wide) => SKIP trade         |
//|   2. Max loss per trade hard cap = $90                            |
//|   3. Max DAILY loss = $90 -> stop trading that day, resume next   |
//|   4. No-martingale: after a loss, lot cannot increase until        |
//|      balance recovers to prior high-water mark                     |
//|   5. 2-min rule: after 120s AND >=25% progress -> lock 0.01 lot    |
//|   6. BE at 65% progress (SL -> entry)                             |
//|   7. Overall floor hard stop at $4550 (GFT $4500 + buffer)        |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast v29"
#property version   "29.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE (optimized inputs - UNCHANGED) ===
input long   InpMagic            = 20260715;
input double InpRR               = 3.0;
input int    InpMaxTradesPerDay  = 3;
input int    InpMaxSpreadPoints  = 50;
input bool   InpUseTrend         = true;
input int    InpEMAPeriod        = 17;
input int    InpEMASlow          = 51;
input int    InpKneeMinRun       = 2;
input int    InpValidBars        = 8;
input double InpSLBufferATR      = 0.29;

//=== DIRECTIONS ===
input bool   InpAllowBuy         = true;
input bool   InpAllowSell        = true;

//=== LOT SIZING (v29: auto-risk $85, clamped 0.06-0.09) ===
input double InpRiskMoney        = 85.0;   // Target $ loss at SL per trade
input double InpMinLot           = 0.06;   // If computed lot < this -> SKIP trade (SL too wide)
input double InpMaxLot           = 0.09;   // Lot cap

//=== HARD LOSS LIMITS (v29) ===
// Per-trade loss is capped at ~$85 by the SL + auto lot sizing (never > ~$90).
input double InpMaxDailyLoss     = 90.0;   // Daily loss cap ($) -> stop trading that day
input bool   InpUseOverallFloor  = true;   // Overall static floor hard stop
input double InpOverallFloorMoney= 4550.0; // Halt EA permanently if equity <= this ($)

//=== NO-MARTINGALE (v29) ===
input bool   InpNoMartingale     = true;   // After a loss, lot cannot increase until recovered

//=== 2-MIN + 0.01 LOCK (v29) ===
input int    InpMinHoldSeconds   = 120;    // 2-min rule
input bool   InpUseLock          = true;   // Enable 0.01 lock
input double InpLockProgress     = 0.25;   // Lock when price >= 25% of TP distance
input double InpLockLot          = 0.01;   // Lot to lock (close) after 2 min

//=== BREAK-EVEN ===
input bool   InpUseBreakEven     = true;
input double InpBEProgress       = 0.65;   // BE at 65% progress

//=== HANDLES / STATE ===
int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime  = 0;
datetime g_dayStart   = 0;
double   g_dayStartBal= 0.0;
int      g_tradesToday= 0;
int      g_dir        = 0;
double   g_trigger    = 0.0;
double   g_kneeLow    = 0.0;
double   g_kneeHigh   = 0.0;
double   g_pendingSL  = 0.0;
double   g_pendingTP  = 0.0;
int      g_barsLeft   = 0;

//=== Trade / management state ===
double   g_initialLots   = 0.0;
bool     g_lockDone      = false;
bool     g_beActivated   = false;

//=== v29 protection state ===
double   g_startBalance   = 0.0;
double   g_peakBalance    = 0.0;
double   g_lockedLot      = 0.0;
double   g_lotAtOpen      = 0.0;
double   g_balAtOpen      = 0.0;
bool     g_hadPosition    = false;
bool     g_dailyLossHit   = false;
bool     g_haltAll        = false;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   g_startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_peakBalance  = g_startBalance;
   atrHandle     = iATR(_Symbol, _Period, 14);
   emaFastHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, _Period, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE || emaFastHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle     != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

double ATR(){ double b[]; if(CopyBuffer(atrHandle,0,0,1,b)<=0) return(0); return(b[0]); }
double EMAFast(int s){ double b[]; if(CopyBuffer(emaFastHandle,0,s,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int s){ double b[]; if(CopyBuffer(emaSlowHandle,0,s,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,_Period,0); if(t!=lastBarTime){lastBarTime=t;return(true);} return(false); }
bool IsGreen(int s){ return(iClose(_Symbol,_Period,s)>iOpen(_Symbol,_Period,s)); }
bool IsRed(int s){ return(iClose(_Symbol,_Period,s)<iOpen(_Symbol,_Period,s)); }

void ResetDaily()
{
   g_dayStart    = iTime(_Symbol,PERIOD_D1,0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_tradesToday = 0;
   g_dailyLossHit= false;
}

void Disarm(){ g_dir=0; g_trigger=0; g_kneeLow=0; g_kneeHigh=0; g_barsLeft=0; g_pendingSL=0; g_pendingTP=0; }

void ResetTradeState()
{
   g_initialLots = 0.0;
   g_lockDone    = false;
   g_beActivated = false;
}

bool IsTrendBuy(){ return(EMAFast(1)>EMASlow(1) && iClose(_Symbol,_Period,1)>EMAFast(1)); }
bool IsTrendSell(){ return(EMAFast(1)<EMASlow(1) && iClose(_Symbol,_Period,1)<EMAFast(1)); }

long PositionAgeSeconds(ulong tk)
{
   if(!PositionSelectByTicket(tk)) return(0);
   return((long)(TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME)));
}

void TryArmSetup()
{
   double atr = ATR();
   if(atr <= 0) return;
   double buf = InpSLBufferATR * atr;

   if(InpAllowBuy && IsRed(1))
   {
      int run=0;
      for(int i=2;i<=12;i++){ if(IsGreen(i)) run++; else break; }
      bool trendOK=(!InpUseTrend)||IsTrendBuy();
      if(run>=InpKneeMinRun && trendOK)
      {
         g_dir=+1;
         g_kneeHigh=iHigh(_Symbol,_Period,1);
         g_kneeLow =iLow(_Symbol,_Period,1);
         g_trigger =g_kneeHigh;
         g_pendingSL=g_kneeLow-buf;
         double oneR=g_trigger-g_pendingSL;
         g_pendingTP=g_trigger+(InpRR*oneR);
         g_barsLeft=InpValidBars;
         return;
      }
   }

   if(InpAllowSell && IsGreen(1))
   {
      int run=0;
      for(int i=2;i<=12;i++){ if(IsRed(i)) run++; else break; }
      bool trendOK=(!InpUseTrend)||IsTrendSell();
      if(run>=InpKneeMinRun && trendOK)
      {
         g_dir=-1;
         g_kneeHigh=iHigh(_Symbol,_Period,1);
         g_kneeLow =iLow(_Symbol,_Period,1);
         g_trigger =g_kneeLow;
         g_pendingSL=g_kneeHigh+buf;
         double oneR=g_pendingSL-g_trigger;
         g_pendingTP=g_trigger-(InpRR*oneR);
         g_barsLeft=InpValidBars;
      }
   }
}

double LossPerLot(double slDist)
{
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0 || ts<=0 || slDist<=0) return(0);
   return((slDist/ts)*tv);
}

double ComputeLot(double slDist)
{
   double lpl = LossPerLot(slDist);
   if(lpl<=0) return(0);

   double lot = InpRiskMoney / lpl;
   double st  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot/st)*st;

   if(lot > InpMaxLot) lot = InpMaxLot;

   if(InpNoMartingale && g_lockedLot > 0.0 && lot > g_lockedLot)
      lot = g_lockedLot;

   if(lot < InpMinLot) return(0);
   return(lot);
}

int MyPositions()
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol) c++;
   }
   return(c);
}

ulong GetMyTicket()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol) return(tk);
   }
   return(0);
}

double NormVol(double vol)
{
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double n=MathFloor(vol/st)*st;
   if(n<mn) return(0);
   return(n);
}

double DailyLossUsed()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double used = g_dayStartBal - bal;
   return(used>0 ? used : 0);
}

void OpenBuy()
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double sl=g_pendingSL, tp=g_pendingTP;
   double slDist=ask-sl; if(slDist<=0) return;

   double lot=ComputeLot(slDist);
   if(lot<=0) return;

   double thisRisk = lot * LossPerLot(slDist);
   if(DailyLossUsed() + thisRisk > InpMaxDailyLoss) return;

   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Buy(lot,_Symbol,0,sl,tp))
   {
      g_tradesToday++;
      g_initialLots=lot; g_lockDone=false; g_beActivated=false;
      g_lotAtOpen=lot; g_balAtOpen=AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

void OpenSell()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=g_pendingSL, tp=g_pendingTP;
   double slDist=sl-bid; if(slDist<=0) return;

   double lot=ComputeLot(slDist);
   if(lot<=0) return;

   double thisRisk = lot * LossPerLot(slDist);
   if(DailyLossUsed() + thisRisk > InpMaxDailyLoss) return;

   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Sell(lot,_Symbol,0,sl,tp))
   {
      g_tradesToday++;
      g_initialLots=lot; g_lockDone=false; g_beActivated=false;
      g_lotAtOpen=lot; g_balAtOpen=AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

void ManageTrade()
{
   if(MyPositions()==0) return;
   ulong ticket=GetMyTicket();
   if(ticket==0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double slc =PositionGetDouble(POSITION_SL);
   double tp  =PositionGetDouble(POSITION_TP);
   double vol =PositionGetDouble(POSITION_VOLUME);
   long   type=PositionGetInteger(POSITION_TYPE);
   int    dg  =(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   double totalDist=0, progress=0;
   if(type==POSITION_TYPE_BUY)
   {
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      totalDist=tp-open; if(totalDist<=0) return;
      progress=(bid-open)/totalDist;
   }
   else if(type==POSITION_TYPE_SELL)
   {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      totalDist=open-tp; if(totalDist<=0) return;
      progress=(open-ask)/totalDist;
   }
   else return;

   double mnLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   long   age  =PositionAgeSeconds(ticket);

   if(InpUseLock && !g_lockDone && age>=InpMinHoldSeconds && progress>=InpLockProgress)
   {
      double v=NormVol(InpLockLot);
      if(v>0 && vol>v && (vol-v)>=mnLot)
      {
         if(trade.PositionClosePartial(ticket,v))
         {
            g_lockDone=true;
            Print(">>> LOCK 0.01 @ ",(int)(progress*100),"% (age ",age,"s)");
         }
      }
      else g_lockDone=true;
   }

   if(InpUseBreakEven && !g_beActivated && progress>=InpBEProgress)
   {
      double be=NormalizeDouble(open,dg);
      if(type==POSITION_TYPE_BUY && slc<be)
      {
         if(trade.PositionModify(ticket,be,tp)){ g_beActivated=true; Print(">>> BE (BUY) @ ",(int)(progress*100),"%"); }
      }
      else if(type==POSITION_TYPE_SELL && slc>be)
      {
         if(trade.PositionModify(ticket,be,tp)){ g_beActivated=true; Print(">>> BE (SELL) @ ",(int)(progress*100),"%"); }
      }
      else g_beActivated=true;
   }
}

void OnTradeClosedUpdate()
{
   bool hasPos = (MyPositions()>0);

   if(g_hadPosition && !hasPos)
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);

      if(bal < g_balAtOpen - 0.01)
      {
         if(InpNoMartingale)
            g_lockedLot = g_lotAtOpen;

         if(DailyLossUsed() >= InpMaxDailyLoss - 0.01)
            g_dailyLossHit = true;
      }

      ResetTradeState();
   }

   double bnow = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bnow > g_peakBalance) g_peakBalance = bnow;

   if(InpNoMartingale && g_lockedLot > 0.0 && bnow >= g_peakBalance - 0.01)
      g_lockedLot = 0.0;

   g_hadPosition = hasPos;
}

bool OverallFloorGuard()
{
   if(!InpUseOverallFloor) return(false);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= InpOverallFloorMoney)
   {
      ulong tk=GetMyTicket(); if(tk>0) trade.PositionClose(tk);
      ResetTradeState();
      g_haltAll=true;
      Print(">>> OVERALL FLOOR ($",InpOverallFloorMoney,") breached at equity ",eq," - EA HALTED");
      return(true);
   }
   return(false);
}

bool DailyLossGuard()
{
   if(g_dailyLossHit) return(true);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_dayStartBal - eq >= InpMaxDailyLoss)
   {
      ulong tk=GetMyTicket(); if(tk>0) trade.PositionClose(tk);
      ResetTradeState();
      g_dailyLossHit=true;
      Print(">>> DAILY LOSS CAP ($",InpMaxDailyLoss,") hit - stopped for today");
      return(true);
   }
   return(false);
}

bool TradingAllowed()
{
   if(g_haltAll)       return(false);
   if(g_dailyLossHit)  return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();

   OnTradeClosedUpdate();

   if(OverallFloorGuard()) return;
   if(DailyLossGuard())    return;

   ManageTrade();

   if(IsNewBar())
   {
      if(g_dir!=0){ g_barsLeft--; if(g_barsLeft<=0) Disarm(); }
      if(g_dir==0 && MyPositions()==0) TryArmSetup();
   }

   if(g_dir!=0 && MyPositions()==0)
   {
      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(g_dir>0 && ask>=g_trigger){ OpenBuy(); Disarm(); }
      else if(g_dir<0 && bid<=g_trigger){ OpenSell(); Disarm(); }
   }
}
//+------------------------------------------------------------------+
```

---

## 8. DATA FILES IN THIS REPO (relevant to this session)

- `XAUUSD_M5_202508010105_202607271000.csv` — M5 OHLC used for the Python backtest (tab-separated: DATE, TIME, OPEN, HIGH, LOW, CLOSE, TICKVOL, VOL, SPREAD; gold prices ~$3,291 in Aug-2025 rising to ~$4,000–5,400 in 2026).
- `report 17` — the MT5 Strategy Tester HTML report for **v17** (source of the verified v17 numbers in Section 5).
- `ReportTester-*.html` — other MT5 reports.
- `PROMPT_LEDGER.md`, `HANDOVER_DOCUMENT.md` — earlier knowledge-transfer docs (some numbers there are from other sessions / earlier versions; treat this SESSION doc as most current for v29).
- Many `CK_GFT_*.mq5`, `CK_XAU_*.mq5` — other strategies from other sessions (Donchian, HybridKnee, LIR, DKT, etc.) — NOT part of this session's final work.

---

## 9. USER INSTRUCTIONS / PREFERENCES (remember these)

- **Talk first, finalize, THEN code.** The user was repeatedly frustrated when the agent coded prematurely. Discuss and confirm the plan before writing.
- **Change ONLY what is explicitly agreed** — do not silently alter other inputs.
- **Push every version to GitHub and give a RAW link** (`raw.githubusercontent.com/.../branch/file`) because the user copies it into MetaEditor. Branch view links weren't copy-friendly; raw links are.
- Respond in **Bengali**.
- **Capital preservation is paramount** — never risk a firm breach; the money was hard-earned.
- The user does their own MT5 backtests and pushes reports back to the repo for the agent to read.
- Lot must effectively be controlled/auto so risk is constant; user says "lot fixed" but accepted auto-risk sizing after it was explained that fixed lot cannot give constant $ loss (SL distance varies 5×).

---

## 10. WARNINGS / KNOWN CAVEATS FOR THE NEXT AGENT

1. **2-minute rule residual risk (IMPORTANT):** The EA no longer closes anything before 120s, BUT if the broker **SL or TP** fills within 2 minutes of entry, that is outside the EA's control and could still be flagged. v17's report showed **min holding time of 5 seconds**. In v29 the EA-initiated closes are gated to ≥120s, so most trades should be >2min, but fast SL/TP hits remain possible. **Check "Minimal position holding time" in the MT5 report.** If many trades are <2min, widen SL or add an entry-confirmation filter.
2. **Day-boundary mismatch:** EA resets its "day" at broker **midnight (D1 bar)**; GFT's daily drawdown resets at **5PM EST**. This is a mismatch, BUT the $90 daily cap is far under GFT's $250, so the buffer absorbs it. Still, be aware.
3. **Python backtest is bar-level, not tick** — treat its numbers as indicative only. MT5 tick backtest is authoritative. The inline Python script was NOT saved as a file.
4. **Positions can span midnight** (v17 max holding 17 hours). A losing position carried into a new day contributes to that new day's drawdown before any fresh trade — the $90 cap still bounds it in the sim, but verify in MT5.
5. **Regime dependence:** v10 showed avg-win collapse ($221→$100) between backtest and forward as market regime changed. Do NOT trust a single in-sample backtest; always forward-test.
6. **Over-filtering kills the edge:** v9 proved stacking many filters at once destroyed profitability. Change one thing at a time and re-test.
7. **Slippage/commission/gaps** are not in the Python sim; a price gap beyond SL could realize a loss larger than $85 (SL becomes market). The $4,550 overall floor + $90 daily cap add buffer, but gaps are an inherent risk.
8. **Leverage difference eval vs funded:** Gold is 1:20 in evaluation, 1:10 in funded. At 0.09 lot, margin is ~36% (eval) / ~72% (funded) of $5K — both under 80%. Fine, but re-check if gold price rises a lot.

---

## 11. UNFINISHED WORK / NEXT STEPS

1. **Run v29 in the MT5 tick backtester** (XAUUSD M5, full period, "every tick based on real ticks"). Confirm:
   - No day loses > $90.
   - Biggest single trade loss ≤ ~$85–90.
   - Lot always within 0.06–0.09; never increases after a loss until recovery (no-martingale).
   - **Minimal position holding time ≥ ~2:00** (the key open worry).
   - Step-1 $500 target is reachable, and ≥3 days each ≥ $25 profit.
2. If min-hold shows sub-2min trades, decide on a fix (wider SL / candle-close entry confirmation / delay).
3. Consider whether to add a "stop after phase target reached" so the EA banks the pass (currently it keeps trading; loss guards protect, but banking the target is cleaner).
4. Optional: re-verify the abandoned time-window edge (UTC 02–03) as an additional filter — but only via proper out-of-sample testing.
5. Save the Python validation script as a real file in the repo if a reusable validator is wanted.

---

## 12. QUICK-START FOR A FUTURE AGENT

- The production EA is **`CK_GFT_Fast_v29.mq5`** (full code in Section 7; also on branch `kiro/v29-final-management`).
- Defaults are already GFT-safe; the user's optimized inputs are baked in.
- Money-management rules that MUST hold: Section 4. Firm limits: Section 3.
- Talk to the user in Bengali; discuss before coding; push raw links.

*End of session export. Everything above reflects what actually happened in this session; approximations and unverified items are marked as such.*

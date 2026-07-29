//+------------------------------------------------------------------+
//|                                    CK_XAU_HybridKnee_V23.mq5     |
//|                                                      CK GFT Fast |
//|------------------------------------------------------------------|
//|  STRATEGY : Hybrid Knee Breakout (XAUUSD / M5)                   |
//|  VERSION  : 23 ("HybridKnee") - V22 infrastructure, V20 settings |
//|                                                                  |
//|  WHAT THIS COMBINES                                              |
//|    1. V20 Knee Breakout entries - RESTORED EXACTLY               |
//|         - BUY : >=2 consecutive green bars -> 1 bearish "knee"    |
//|                 bar -> break of the knee HIGH, body >= 0.60      |
//|         - SELL: >=3 consecutive red bars  -> 1 bullish "knee"    |
//|                 bar -> break of the knee LOW,  body >= 0.70      |
//|         - EMA(21)/EMA(50) trend alignment + knee close vs EMA21  |
//|         - The BUY/SELL asymmetry is DELIBERATE: it is the V19 /  |
//|           V20 finding ("sell needs stricter rules") and it is    |
//|           the configuration that produced the only MT5-verified  |
//|           profitable run this project has.                       |
//|    2. Hybrid exit, V20 shape                                     |
//|         - Fixed TP at RR 2.0 recomputed from the ACTUAL fill     |
//|         - Break-even at +1.0R (V20 used BE at 1R)                |
//|         - Trailing-stop code is PRESENT but OFF by default       |
//|    3. Prop-firm-grade risk controls (Goat Funded Trader 5K,      |
//|       2-Step): 5% daily DD, 10% total DD, 0.08 lot cap,          |
//|       max 4 entries/day, single position only                    |
//|    4. All V22 engineering: per-bar indicator cache, per-setup    |
//|       guard latches, fixed-lot mode, TP from the actual fill,    |
//|       frozen R yardstick, idempotent BE, monotonic trail,        |
//|       STATIC drawdown tracking, full realized-performance DIAG   |
//|                                                                  |
//|==================================================================|
//|  WHY V23 EXISTS                                                  |
//|==================================================================|
//|  THE EVIDENCE (XAUUSD M5, $5,000, Jan-Jul 2026, real ticks):     |
//|                                                                  |
//|      V20 : 270 trades, PF 1.49, +$4,456, DD 11.8%                |
//|            Long WR 38.86%, Short WR 36.36%  <-- MT5 VERIFIED     |
//|      V21 : 110 trades, PF 0.90, -$172.91                         |
//|      V22 : 148 trades, PF 1.03                                   |
//|                                                                  |
//|  V20 is the ONLY MT5-verified profitable configuration this      |
//|  project has ever produced. V21 and V22 both LOST that edge.     |
//|                                                                  |
//|  WHAT CAUSED THE REGRESSION                                      |
//|    V21 / V22 added, ALL AT THE SAME TIME:                        |
//|      (a) an ADX(14) regime filter that blocks "ranging" bars     |
//|      (b) a Thursday + Friday blackout                            |
//|      (c) a 6xATR trailing stop                                   |
//|      (d) BUY tightened from run 2 / body 0.60 to run 3 / 0.70    |
//|    Trade count collapsed 270 -> 110 -> 148 and profit factor     |
//|    fell 1.49 -> 0.90 -> 1.03. Nothing about the ENTRY EDGE was   |
//|    improved: the filters simply deleted valid setups, and the    |
//|    setups that survived were not a better population.            |
//|                                                                  |
//|  EVERY ONE OF THOSE CHANGES IS ON THE PROJECT LEDGER'S           |
//|  "NEVER DO" LIST:                                                |
//|    * "Never add multiple filters at once - always one at a time" |
//|    * "Never use session filter - removes good trades" - a        |
//|      weekday blackout is a session filter in disguise            |
//|    * ADX must default to OFF; ADX = overfit risk                 |
//|    * the 6xATR trail came from CK_GFT_BEST_Strategy, whose       |
//|      Python result ($10,546 / DD 2.75%) did NOT survive MT5      |
//|      ($2,861 / DD 48%) - it is NOT a verified improvement        |
//|                                                                  |
//|  WHAT V23 DOES                                                   |
//|    1. Restores the V20 defaults EXACTLY. Every reverted input    |
//|       carries a comment naming the V20 value it restores, so no  |
//|       one can silently re-tighten it later.                      |
//|    2. Keeps 100% of the V22 infrastructure - none of it is       |
//|       implicated in the regression, and it is what makes a run   |
//|       diagnosable in the first place.                            |
//|    3. Moves every later idea into ONE clearly labelled input     |
//|       group where it is OFF by default.                          |
//|                                                                  |
//|  >>> EVERY OPTIONAL FEATURE IS NOW OFF BY DEFAULT AND MUST BE    |
//|  >>> ENABLED AND FORWARD-TESTED **ONE AT A TIME**.               |
//|                                                                  |
//|    Reproduce the V20 baseline FIRST, on untouched defaults.      |
//|    Only once ~270 trades / PF ~1.49 is back on the screen may a  |
//|    single optional toggle be switched on, backtested alone, and  |
//|    forward-tested alone. Never two at a time. Ever.              |
//|                                                                  |
//|  GUARD RAILS ADDED IN V23 (so this cannot happen silently again) |
//|    * OnInit prints BASELINE|OK when the configuration is pure    |
//|      V20, or BASELINE|MODIFIED plus one line naming EVERY        |
//|      deviation (optional features ON, core values changed).      |
//|    * The DIAG summary prints the V20 reference (270 trades,      |
//|      PF 1.49, +$4,456), this run's trade count as a percentage   |
//|      of it, and an explicit over-filtering WARNING below 200.    |
//|==================================================================|
//|                                                                  |
//|  KEY INPUTS (defaults ARE the V20 MT5-verified configuration)    |
//|    InpRiskPercent      0.70   risk per trade, compounded         |
//|    InpRR              2.00    fixed take-profit multiple         |
//|    InpKneeMinRunBuy      2 /  InpEntryStrengthBuy  0.60          |
//|    InpKneeMinRunSell     3 /  InpEntryStrengthSell 0.70          |
//|    InpMaxTradesPerDay    4    InpDailyLossStopR         1.50     |
//|    InpMinSLPoints        5    InpValidBars                 5     |
//|    InpSLBufferATR     0.30    InpMaxLot                 0.08     |
//|    InpUseBreakEven    true    InpBEAtR                  1.00     |
//|    InpUseRegimeFilter FALSE   InpUseTrailing           FALSE     |
//|    InpSkipThursday    FALSE   InpSkipFriday            FALSE     |
//|    InpUseFixedLot     false   InpFixedLot               0.06     |
//|    InpMinLot / InpMaxSpread   0.01 / 70 (execution hygiene)      |
//|    InpVerboseLog      false   (journal-cap protection)           |
//|                                                                  |
//|  RECOMMENDED STRATEGY TESTER SETTINGS                            |
//|    Symbol      : XAUUSD                                          |
//|    Timeframe   : M5                                              |
//|    Modelling   : Every tick based on real ticks                  |
//|    Deposit     : 5000 USD                                        |
//|    Leverage    : 1:30   (gold is capped at 1:30 on this prop     |
//|                          firm - do NOT test at 1:100)            |
//|    Period      : 2026.01.01 - 2026.07.28 for a like-for-like     |
//|                  comparison against V20 / V21 / V22              |
//|    InpVerboseLog: false for full runs (keeps the journal under   |
//|                   the 16,384-record cap so DIAG always prints)   |
//|    Optimisation: off for the baseline run                        |
//|    Journal     : grep for the "V23|" prefix on every log line -  |
//|                  read the BASELINE| line FIRST                   |
//|                                                                  |
//|  EVERY toggle below is honoured by the logic, so features can be |
//|  A/B tested by flipping a single input in the Strategy Tester -  |
//|  ONE input per test run.                                         |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property link      ""
#property version   "23.00"
#property strict
#property description "XAUUSD M5 Hybrid Knee Breakout V23 - V22 infrastructure reverted to the MT5-verified V20 configuration. All optional filters OFF by default, enable ONE at a time."

#include <Trade/Trade.mqh>

//==================================================================//
//  SECTION 1 - INPUTS                                              //
//==================================================================//

//------------------------------------------------------------------//
//  DEFAULTS = THE MT5-VERIFIED V20 CONFIGURATION.                  //
//                                                                  //
//  Every value below that carries a "V20:" comment is a REVERT of a //
//  V21/V22 change that coincided with the collapse from 270 trades  //
//  / PF 1.49 to 148 trades / PF 1.03. Do not re-tighten any of them //
//  without an MT5 run that BEATS +$4,456 at DD <= 11.8%.           //
//------------------------------------------------------------------//

//--- Identity -----------------------------------------------------//
input group "=== Identity ==="
input long   InpMagic             = 20260801;   // Magic number (position ownership)

//--- Risk management ----------------------------------------------//
input group "=== Risk Management ==="
input double InpRiskPercent       = 0.70;       // Risk per trade (%) - V20: 0.70 (KEEP)
input double InpRR                = 2.0;        // Fixed TP reward:risk - V20: 2.0 (KEEP)
input int    InpMaxTradesPerDay   = 4;          // Max entries per day  - V20: 4 (KEEP)
input double InpDailyLossStopR    = 1.5;        // Daily loss stop in R - V20: 1.5 (KEEP)
input double InpDailyLossPct      = 5.0;        // Daily loss stop, % of day-start balance
input double InpMaxLot            = 0.08;       // Max lot              - V20: 0.08 (KEEP)
input double InpMinLot            = 0.01;       // Min lot - V22 hygiene, smaller sizes REJECT
input bool   InpCompoundLots      = true;       // Grow risk with balance (compound)
input bool   InpUseFixedLot       = false;      // Bypass risk-based sizing, trade a flat lot
input double InpFixedLot          = 0.06;       // Lot used when InpUseFixedLot = true

//--- Entry logic --------------------------------------------------//
//  The BUY/SELL asymmetry here is the V19/V20 finding, NOT an
//  oversight: "sell needs stricter rules". V22 symmetrised the BUY
//  side up to the SELL thresholds and the trade count halved.
input group "=== Entry Logic (Knee Breakout) ==="
input int    InpKneeMinRunBuy     = 2;          // BUY  min green run  - V20: 2 (REVERTED from V22's 3)
input int    InpKneeMinRunSell    = 3;          // SELL min red run    - V20: 3 (unchanged)
input double InpEntryStrengthBuy  = 0.60;       // BUY  min body/range - V20: 0.60 (REVERTED from V22's 0.70)
input double InpEntryStrengthSell = 0.70;       // SELL min body/range - V20: 0.70 (unchanged)
input int    InpValidBars         = 5;          // Setup validity window (bars) - V20: 5 (KEEP)
input double InpSLBufferATR       = 0.30;       // SL buffer beyond knee, ATR    - V20: 0.30 (KEEP)
input int    InpMinSLPoints       = 5;          // Minimum SL distance (points)  - V20: 5 (KEEP)
input int    InpLookback          = 12;         // Max bars scanned for the run count

//--- Exit tuning (break-even) -------------------------------------//
input group "=== Exit Tuning (Break-even) ==="
input bool   InpUseBreakEven      = true;       // Enable break-even   - V20: ON (KEEP)
input double InpBEAtR             = 1.0;        // R multiple that fires BE - V20: 1.0 (0 = BE off)
input int    InpBEOffsetPoints    = 0;          // Points beyond entry for the BE stop - V20: 0

//--- Indicators ---------------------------------------------------//
input group "=== Indicators ==="
input int    InpEMAFast           = 21;         // Fast EMA period - V20: 21
input int    InpEMASlow           = 50;         // Slow EMA period - V20: 50
input int    InpATRPeriod         = 14;         // ATR period      - V20: 14
input int    InpADXPeriod         = 14;         // ADX period (only used when the ADX filter is ON)

//--- Direction / execution hygiene filters ------------------------//
//  These are NOT strategy filters: they are broker-reality guards.
input group "=== Direction & Execution Hygiene ==="
input int    InpMaxSpread         = 70;         // Max spread (points) at entry - V22 hygiene value
input bool   InpAllowBuy          = true;       // Allow long setups
input bool   InpAllowSell         = true;       // Allow short setups

//==================================================================//
//  OPTIONAL FEATURES - READ THIS BEFORE TOUCHING ANY OF THEM        //
//==================================================================//
//  The single most repeated lesson in this project's ledger is that
//  STACKING FILTERS DESTROYS THIS STRATEGY. It has now been proven
//  five separate times (ledger experiment numbers, not EA versions):
//
//     ledger V10 : five filters at once     -> -$864,   PF 0.64
//     ledger V12 : session filter           -> +$478,   PF 1.10
//     ledger V22 : multi-timeframe filters  -> +$710,   PF 1.13
//     ledger V26 : dual signal              -> +$1,239, DD 22%
//     ... against the V20 reference of      -> +$4,456, PF 1.49
//
//  and once more in THIS EA's own lineage:
//
//     HybridKnee V21 / V22 : ADX filter + Thu/Fri blackout + 6xATR
//                            trail + tighter BUY, ALL IN ONE STEP
//                            -> 270 trades / PF 1.49 collapsed to
//                               110 trades / PF 0.90, then
//                               148 trades / PF 1.03
//
//  Ledger, verbatim: "Never add multiple filters at once - always one
//  at a time" and "Never use session filter - removes good trades".
//  A Thursday/Friday blackout IS a session filter. ADX is an overfit
//  risk. The 6xATR trail is inherited from a strategy that measured
//  DD 48% in MT5.
//
//  THE PROTOCOL - no exceptions:
//    1. Run the DEFAULTS first and confirm the BASELINE|OK line plus
//       roughly 270 trades over Jan-Jul 2026. That is the edge.
//    2. Enable EXACTLY ONE toggle below. Nothing else changes.
//    3. Backtest it alone. Compare trades, PF, net, DD against the
//       270 / 1.49 / +$4,456 / 11.8% reference.
//    4. Forward-test that same single toggle before you believe it.
//    5. Only if it BEAT the baseline does it stay on - and only then
//       may the next toggle be considered.
//    6. If two toggles are on at once, the result is uninterpretable.
//       Do not do it. That is exactly how V21 and V22 happened.
//==================================================================//
input group "=== OPTIONAL FEATURES - ALL OFF BY DEFAULT, ENABLE ONE AT A TIME ==="
input bool   InpUseRegimeFilter   = false;      // OFF - ADX regime filter (overfit risk; V20 had none)
input double InpADXThreshold      = 20.0;       //   ... min ADX when the filter is ON [15 - 30]
input bool   InpUseTrailing       = false;      // OFF - 6xATR trail (from BEST strategy: MT5 DD 48%)
input double InpTrailATR          = 6.0;        //   ... trail distance in ATR when ON (>= 3.0)
input double InpTrailStartR       = 1.0;        //   ... R multiple that arms the trail when ON
input bool   InpSkipThursday      = false;      // OFF - Thursday blackout (V20 had no weekday filter)
input bool   InpSkipFriday        = false;      // OFF - Friday blackout  (V20 had no weekday filter)

//--- Total drawdown guard (prop firm) -----------------------------//
input group "=== Total Drawdown Guard ==="
input double InpTotalDDReduceAt   = 8.0;        // Total DD % at which risk is halved
input double InpTotalDDStopAt     = 9.0;        // Total DD % at which entries stop
input double InpTotalDDHardAt     = 10.0;       // Total DD % = hard breach (critical log)

//--- Execution / logging ------------------------------------------//
input group "=== Execution & Logging ==="
input int    InpDeviationPoints   = 30;         // Max slippage (points)
input bool   InpVerboseLog        = false;      // Verbose per-event journal logging

//==================================================================//
//  SECTION 2 - CONSTANTS                                           //
//==================================================================//

// Absolute ceiling enforced by every code path that produces a lot size.
// No input, no compounding factor, no fixed-lot override and no rounding
// can push a trade above this value - it is the prop firm contractual
// limit.
const double HARD_MAX_LOT = 0.08;

// Journal prefix. Every single Print in this EA starts with it so the
// Strategy Tester journal can be filtered with a plain text search.
#define LOGP "V23|"

// ADX indicator buffer indices (iADX): 0 = main, 1 = +DI, 2 = -DI.
#define ADX_MAIN_BUFFER 0

//------------------------------------------------------------------//
//  V20 MT5-VERIFIED REFERENCE RESULT (XAUUSD M5, $5,000, 1:30,     //
//  2026.01.01 - 2026.07.28, every tick based on real ticks).       //
//  These constants exist so the DIAG block can measure a run       //
//  against the only configuration this project has ever verified   //
//  as profitable, instead of relying on somebody's memory.         //
//------------------------------------------------------------------//
#define V20_REF_TRADES  270      // entries taken
#define V20_REF_PF      1.49     // profit factor
#define V20_REF_NET_TXT "+$4,456" // net profit (text, pre-formatted)
#define V20_REF_DD_TXT  "11.8%"  // max drawdown (text, pre-formatted)

// Below this many entries the run is almost certainly over-filtered
// rather than unlucky: V20 took 270, V21 took 110, V22 took 148.
#define TRADE_COUNT_FLOOR 200

//==================================================================//
//  SECTION 3 - GLOBAL STATE                                        //
//==================================================================//

CTrade g_trade;

//--- Indicator handles --------------------------------------------//
int g_hATR     = INVALID_HANDLE;
int g_hEMAFast = INVALID_HANDLE;
int g_hEMASlow = INVALID_HANDLE;
int g_hADX     = INVALID_HANDLE;

//--- Symbol / broker constraints (cached once in OnInit) ----------//
int    g_digits     = 2;
double g_point      = 0.01;
double g_tickSize   = 0.01;
double g_volMin     = 0.01;
double g_volMax     = 100.0;
double g_volStep    = 0.01;
int    g_volDigits  = 2;
long   g_stopsLevel = 0;

//--- Indicator cache (refreshed at most once per bar) -------------//
datetime g_indBarTime = 0;      // bar whose values are currently cached
bool     g_indValid   = false;  // ATR + both EMAs are usable  (fail-CLOSED)
bool     g_adxValid   = false;  // ADX is usable               (fail-OPEN)
double   g_atr        = 0.0;
double   g_emaFast    = 0.0;
double   g_emaSlow    = 0.0;
double   g_adx        = 0.0;

//--- Bar / day tracking -------------------------------------------//
datetime g_lastBarTime      = 0;
datetime g_dayStart         = 0;
double   g_dayStartBalance  = 0.0;
double   g_initialBalance   = 0.0;
double   g_oneRMoney        = 0.0;   // dollar value of 1R for the current day
int      g_tradesToday      = 0;
double   g_dailyRealizedPnL = 0.0;   // signed: negative = losing day
bool     g_dailyLimitHit    = false;
bool     g_hardDDLogged     = false;

//--- Drawdown high-water marks (V22-infra #9) ---------------------------//
//  MT5 reports PEAK-relative drawdown; the prop firm rule is STATIC
//  from the initial balance, so we track that ourselves.
double   g_maxStaticDD      = 0.0;   // worst (initialBal - equity)/initialBal %
double   g_minEquity        = 0.0;   // lowest equity seen in the run
double   g_maxDailyDD       = 0.0;   // worst daily DD % seen across the run

//--- Armed setup state --------------------------------------------//
int      g_setupDirection = 0;    // +1 = buy, -1 = sell, 0 = none
double   g_triggerPrice   = 0.0;
double   g_pendingSL      = 0.0;
int      g_barsRemaining  = 0;
datetime g_setupTime      = 0;    // time of the knee bar that armed the setup
datetime g_lastTradedSetup= 0;    // knee already traded - never re-arm it

//--- Per-setup guard latches (V22-infra #3) -----------------------------//
//  Each guard may increment its counter and log AT MOST ONCE per armed
//  setup. Every latch is cleared in ArmSetup() and Disarm(), so the
//  DIAG counters read "how many setups did this guard kill", not "how
//  many ticks did this guard see" (which is what flooded V21's log).
bool g_latchSpread     = false;
bool g_latchDailyLimit = false;
bool g_latchMaxTrades  = false;
bool g_latchPosition   = false;
bool g_latchTotalDD    = false;
bool g_latchLot        = false;

//--- Weekday rejection is counted once per BAR (V22-infra #2) -----------//
datetime g_weekdayRejBar = 0;

//--- Live position state ------------------------------------------//
bool     g_hasPosition    = false;
ulong    g_positionTicket = 0;
double   g_entryPrice     = 0.0;
double   g_initialRisk    = 0.0;  // |entry - original SL|, frozen at fill time
bool     g_beApplied      = false;

//--- Diagnostics counters -----------------------------------------//
int g_cntEntries      = 0;   // positions successfully opened
int g_cntEntriesBuy   = 0;   // ... of which BUY
int g_cntEntriesSell  = 0;   // ... of which SELL
int g_rejSpread       = 0;   // blocked: spread too wide           (per setup)
int g_rejRegime       = 0;   // blocked: ADX says ranging          (per bar)
int g_rejDailyLimit   = 0;   // blocked: daily loss limit (R or %) (per setup)
int g_rejWeekday      = 0;   // blocked: Thursday / Friday         (per bar)
int g_rejMaxTrades    = 0;   // blocked: max trades per day        (per setup)
int g_rejPosition     = 0;   // blocked: a position is already open(per setup)
int g_rejTotalDD      = 0;   // blocked: total drawdown guard      (per setup)
int g_rejLot          = 0;   // blocked: lot size rejected         (per setup)
int g_orderFails      = 0;   // order send / fill lookup failures
int g_setupsArmed     = 0;   // setups armed
int g_setupsArmedBuy  = 0;   // ... of which BUY
int g_setupsArmedSell = 0;   // ... of which SELL
int g_setupsExpired   = 0;   // setups that expired unused
int g_indFailures     = 0;   // indicator read failures

//--- Realized-performance tracking (V22-infra #10) ----------------------//
//  Accumulated by the EA itself from the OnTradeTransaction deal
//  stream so the DIAG block alone is enough to judge a run.
int    g_realWins   = 0;     // closing deals with pnl > 0
int    g_realLosses = 0;     // closing deals with pnl < 0
int    g_realFlat   = 0;     // closing deals with pnl == 0
double g_grossWin   = 0.0;   // sum of winning pnl  (positive)
double g_grossLoss  = 0.0;   // sum of |losing pnl| (positive)

//==================================================================//
//  SECTION 4 - LOW LEVEL HELPERS (rounding, logging, symbol data)  //
//==================================================================//

//------------------------------------------------------------------//
//| Verbose log - gated behind InpVerboseLog                        |
//------------------------------------------------------------------//
void VLog(const string msg)
{
   if(InpVerboseLog)
      Print(LOGP + msg);
}

//------------------------------------------------------------------//
//| Always-on log (init, errors, summary)                           |
//------------------------------------------------------------------//
void ALog(const string msg)
{
   Print(LOGP + msg);
}

//------------------------------------------------------------------//
//| Effective tick size (falls back to point if the broker lies)    |
//------------------------------------------------------------------//
double TickSizeSafe()
{
   if(g_tickSize > 0.0) return g_tickSize;
   if(g_point    > 0.0) return g_point;
   return 0.01;
}

//------------------------------------------------------------------//
//| Round a price to the nearest valid tick                         |
//------------------------------------------------------------------//
double RoundToTick(const double price)
{
   double ts = TickSizeSafe();
   return NormalizeDouble(MathRound(price / ts) * ts, g_digits);
}

//------------------------------------------------------------------//
//| Round a price DOWN to a valid tick (used for buy SL / sell TP)  |
//------------------------------------------------------------------//
double FloorToTick(const double price)
{
   double ts = TickSizeSafe();
   return NormalizeDouble(MathFloor(price / ts) * ts, g_digits);
}

//------------------------------------------------------------------//
//| Round a price UP to a valid tick (used for buy trigger / sell SL)|
//------------------------------------------------------------------//
double CeilToTick(const double price)
{
   double ts = TickSizeSafe();
   return NormalizeDouble(MathCeil(price / ts) * ts, g_digits);
}

//------------------------------------------------------------------//
//| Broker minimum stop distance, in price units                    |
//------------------------------------------------------------------//
double MinStopDistance()
{
   return (double)g_stopsLevel * g_point;
}

//------------------------------------------------------------------//
//| Number of decimals implied by the broker volume step            |
//------------------------------------------------------------------//
int VolumeDigitsFromStep(const double step)
{
   if(step <= 0.0) return 2;
   double s = step;
   int    d = 0;
   while(d < 8 && MathAbs(s - MathRound(s)) > 1e-9)
   {
      s *= 10.0;
      d++;
   }
   return d;
}

//------------------------------------------------------------------//
//| Cache all broker constraints once, so the hot path stays cheap  |
//------------------------------------------------------------------//
void CacheSymbolInfo()
{
   g_digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_volMin     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_volMax     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_volStep    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   if(g_point    <= 0.0) g_point    = 0.01;
   if(g_tickSize <= 0.0) g_tickSize = g_point;
   if(g_volStep  <= 0.0) g_volStep  = 0.01;
   if(g_volMin   <= 0.0) g_volMin   = g_volStep;
   if(g_volMax   <= 0.0) g_volMax   = 100.0;

   g_volDigits = VolumeDigitsFromStep(g_volStep);
}

//------------------------------------------------------------------//
//| True exactly once per newly opened bar of the working timeframe |
//------------------------------------------------------------------//
bool IsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t <= 0) return false;
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return true;
   }
   return false;
}

//==================================================================//
//  SECTION 5 - INDICATOR CACHE                                     //
//==================================================================//
//  All readings come from shift 1 (the last CLOSED bar) so that no
//  decision is ever taken on a repainting, still-forming candle.
//
//  Failure policy (design.md "Error Scenario 5"):
//    * ATR / EMA read failure -> fail CLOSED: g_indValid = false, no
//      scanning, no trailing. We would rather miss a trade than size
//      or place a stop from a garbage value.
//    * ADX read failure       -> fail OPEN : g_adxValid = false and
//      the regime filter waves the trade through.
//------------------------------------------------------------------//
bool UpdateIndicatorCache()
{
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt <= 0) return false;

   // Already cached for this bar -> nothing to copy. This is the branch
   // taken on the overwhelming majority of ticks.
   if(bt == g_indBarTime && g_indValid)
      return true;

   double buf[];
   ArraySetAsSeries(buf, true);

   double atr  = 0.0;
   double emaF = 0.0;
   double emaS = 0.0;
   bool   coreOk = true;

   if(CopyBuffer(g_hATR, 0, 1, 1, buf) == 1 && buf[0] > 0.0) atr = buf[0];
   else coreOk = false;

   if(CopyBuffer(g_hEMAFast, 0, 1, 1, buf) == 1 && buf[0] > 0.0) emaF = buf[0];
   else coreOk = false;

   if(CopyBuffer(g_hEMASlow, 0, 1, 1, buf) == 1 && buf[0] > 0.0) emaS = buf[0];
   else coreOk = false;

   if(!coreOk)
   {
      // Do NOT stamp g_indBarTime: we want to retry on the next tick.
      g_indValid = false;
      g_indFailures++;
      VLog(StringFormat("IND|FAIL|ATR/EMA copy failed err=%d - scanning blocked (fail-closed)",
                        GetLastError()));
      return false;
   }

   // ADX is optional: a failure must not block trading.
   double adx    = 0.0;
   bool   adxOk  = false;
   if(CopyBuffer(g_hADX, ADX_MAIN_BUFFER, 1, 1, buf) == 1 && buf[0] >= 0.0)
   {
      adx   = buf[0];
      adxOk = true;
   }
   else
   {
      g_indFailures++;
      VLog(StringFormat("IND|WARN|ADX copy failed err=%d - regime filter fails OPEN",
                        GetLastError()));
   }

   g_atr        = atr;
   g_emaFast    = emaF;
   g_emaSlow    = emaS;
   g_adx        = adx;
   g_adxValid   = adxOk;
   g_indValid   = true;
   g_indBarTime = bt;
   return true;
}

//==================================================================//
//  SECTION 6 - DAILY BOOK-KEEPING AND DRAWDOWN MATH                //
//==================================================================//

//------------------------------------------------------------------//
//| Reset every per-day counter at the D1 boundary                  |
//------------------------------------------------------------------//
void ResetDaily()
{
   datetime ds = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStart = (ds > 0 ? ds : TimeCurrent());

   g_dayStartBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_dayStartBalance <= 0.0)
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_EQUITY);

   g_tradesToday      = 0;
   g_dailyRealizedPnL = 0.0;
   g_dailyLimitHit    = false;

   // Per-day 1R reference in account currency. Everything expressed in
   // "R" (the 1.5R daily loss stop) is measured against this number so
   // the limit scales with the account as it compounds.
   g_oneRMoney = g_dayStartBalance * (InpRiskPercent / 100.0);
   if(g_oneRMoney <= 0.0) g_oneRMoney = 1.0;

   ALog(StringFormat("DAY|RESET|start=%s bal=%.2f 1R=%.2f",
                     TimeToString(g_dayStart, TIME_DATE), g_dayStartBalance, g_oneRMoney));
}

//------------------------------------------------------------------//
//| Daily drawdown, % of day-start balance (0 when in profit)       |
//------------------------------------------------------------------//
double DailyDDPercent()
{
   if(g_dayStartBalance <= 0.0) return 0.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (g_dayStartBalance - eq) / g_dayStartBalance * 100.0;
   return (dd > 0.0 ? dd : 0.0);
}

//------------------------------------------------------------------//
//| Total drawdown, % of the initial (challenge start) balance      |
//| This is the STATIC prop firm measure, not MT5's peak-relative   |
//| figure.                                                          |
//------------------------------------------------------------------//
double TotalDDPercent()
{
   if(g_initialBalance <= 0.0) return 0.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (g_initialBalance - eq) / g_initialBalance * 100.0;
   return (dd > 0.0 ? dd : 0.0);
}

//------------------------------------------------------------------//
//| Critical-warning watchdog for the hard 10% prop firm breach     |
//| plus (V22-infra #9) the STATIC drawdown high-water marks. Called on   |
//| every tick, so g_minEquity / g_maxStaticDD / g_maxDailyDD see   |
//| intrabar excursions, not just bar closes.                        |
//------------------------------------------------------------------//
void CheckHardDrawdown()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   //--- Lowest equity of the whole run --------------------------//
   if(eq > 0.0 && (g_minEquity <= 0.0 || eq < g_minEquity))
      g_minEquity = eq;

   //--- Worst STATIC drawdown vs the initial balance ------------//
   double dd = TotalDDPercent();
   if(dd > g_maxStaticDD)
      g_maxStaticDD = dd;

   //--- Worst daily drawdown seen anywhere in the run -----------//
   double ddDay = DailyDDPercent();
   if(ddDay > g_maxDailyDD)
      g_maxDailyDD = ddDay;

   //--- Hard breach: log once -----------------------------------//
   if(dd >= InpTotalDDHardAt && !g_hardDDLogged)
   {
      g_hardDDLogged = true;
      ALog(StringFormat("CRITICAL|TOTAL DD %.2f%% >= hard limit %.2f%% - trading ceased. "
                        "Manual intervention required.", dd, InpTotalDDHardAt));
   }
}

//------------------------------------------------------------------//
//| Day-of-week filter - OPTIONAL, BOTH LEGS OFF BY DEFAULT IN V23  |
//|                                                                  |
//| V20 had NO weekday filter and took 270 trades. A Thu/Fri blackout|
//| is a session filter in disguise, and the ledger is unambiguous:  |
//| "Never use session filter - removes good trades". With both       |
//| toggles false this returns true immediately and the gate is a    |
//| no-op, which is the V20 behaviour.                                |
//------------------------------------------------------------------//
bool IsWeekdayAllowed()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(InpSkipThursday && dt.day_of_week == 4) return false;   // Thursday
   if(InpSkipFriday   && dt.day_of_week == 5) return false;   // Friday
   return true;
}

//==================================================================//
//  SECTION 7 - POSITION HELPERS                                    //
//==================================================================//
//  EVERY loop over PositionsTotal() filters on BOTH the magic number
//  and the symbol, so this EA can never touch a position it does not
//  own, even when several EAs share the terminal.
//------------------------------------------------------------------//

//------------------------------------------------------------------//
//| Ticket of this EA's position on this symbol, or 0               |
//------------------------------------------------------------------//
ulong FindPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)   continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;
      return tk;
   }
   return 0;
}

//------------------------------------------------------------------//
//| Count of this EA's positions on this symbol (expected 0 or 1)   |
//------------------------------------------------------------------//
int CountMyPositions()
{
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)   continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)    continue;
      c++;
   }
   return c;
}

//------------------------------------------------------------------//
//| Keep the cached position state in sync with the terminal.       |
//| Handles: normal close (TP/SL), manual close, and adoption of an |
//| existing position after a restart / recompile.                  |
//------------------------------------------------------------------//
void SyncPositionState()
{
   ulong tk = FindPositionTicket();

   if(tk == 0)
   {
      if(g_hasPosition)
         VLog(StringFormat("POS|CLOSED|ticket=%I64u dailyPnL=%.2f", g_positionTicket,
                           g_dailyRealizedPnL));
      g_hasPosition    = false;
      g_positionTicket = 0;
      g_entryPrice     = 0.0;
      g_initialRisk    = 0.0;
      g_beApplied      = false;
      return;
   }

   g_positionTicket = tk;

   if(!g_hasPosition)
   {
      // First time we see this ticket (fresh fill handled in OpenPosition,
      // this branch mainly covers EA restart with a live position).
      g_hasPosition = true;
      if(PositionSelectByTicket(tk))
      {
         g_entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl    = PositionGetDouble(POSITION_SL);
         if(g_initialRisk <= 0.0 && sl > 0.0)
            g_initialRisk = MathAbs(g_entryPrice - sl);
      }
      VLog(StringFormat("POS|ADOPT|ticket=%I64u entry=%s risk=%s", tk,
                        DoubleToString(g_entryPrice, g_digits),
                        DoubleToString(g_initialRisk, g_digits)));
   }
}

//==================================================================//
//  SECTION 8 - LOT SIZING                                          //
//==================================================================//
//  Two modes:
//    A) InpUseFixedLot = false (default)  -> risk-based sizing with
//       compound growth, a drawdown de-risk step, a hard 0.08 ceiling
//       and a REJECT (not a force-up) below minimum. Identical to V21.
//    B) InpUseFixedLot = true             -> flat InpFixedLot, still
//       clamped by every ceiling, and the IMPLIED risk percentage is
//       logged so a flat lot can never silently breach the intended
//       risk budget (V22-infra #4).
//------------------------------------------------------------------//

//------------------------------------------------------------------//
//| Money lost per 1.00 lot if the stop is hit. 0 = undeterminable. |
//------------------------------------------------------------------//
double LossPerLot(const double entryPrice, const double stopPrice, const int direction)
{
   double lossPerLot = 0.0;
   double profit     = 0.0;

   ENUM_ORDER_TYPE ot = ORDER_TYPE_SELL;
   if(direction == 1) ot = ORDER_TYPE_BUY;

   if(OrderCalcProfit(ot, _Symbol, 1.0, entryPrice, stopPrice, profit))
      lossPerLot = MathAbs(profit);

   if(lossPerLot <= 0.0)
   {
      // Fallback: tick-value based conversion.
      double tvLoss = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      double ts     = TickSizeSafe();
      if(tvLoss > 0.0 && ts > 0.0)
         lossPerLot = (MathAbs(entryPrice - stopPrice) / ts) * tvLoss;
   }
   return lossPerLot;
}

//------------------------------------------------------------------//
//| Apply every ceiling / floor to a candidate lot size.            |
//| Returns the clamped lot, or 0.0 when it cannot be traded.       |
//------------------------------------------------------------------//
double ClampLot(const double candidate)
{
   double lots = candidate;

   // Never below what the broker will accept ...
   lots = MathMax(lots, g_volMin);
   // ... and never above ANY of the ceilings.
   lots = MathMin(lots, InpMaxLot);
   lots = MathMin(lots, HARD_MAX_LOT);
   lots = MathMin(lots, g_volMax);

   // Floor to the broker volume step (never round up into more risk).
   lots = MathFloor(lots / g_volStep) * g_volStep;
   lots = NormalizeDouble(lots, g_volDigits);

   if(lots < g_volMin - 1e-9) return 0.0;
   return lots;
}

//------------------------------------------------------------------//
//| Position size for the pending entry                             |
//------------------------------------------------------------------//
double CalcLot(const double entryPrice, const double stopPrice, const int direction)
{
   if(entryPrice <= 0.0 || stopPrice <= 0.0) return 0.0;
   if(direction ==  1 && entryPrice <= stopPrice) return 0.0;   // BUY  needs SL below
   if(direction == -1 && stopPrice  <= entryPrice) return 0.0;  // SELL needs SL above

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 0.0;
   if(g_initialBalance <= 0.0) g_initialBalance = balance;

   //--- Loss per 1.00 lot: needed by BOTH modes ------------------//
   double lossPerLot = LossPerLot(entryPrice, stopPrice, direction);
   if(lossPerLot <= 0.0)
   {
      ALog("LOT|REJECT|cannot determine loss-per-lot (OrderCalcProfit and fallback failed)");
      return 0.0;
   }

   //==============================================================//
   //  MODE B - fixed lot (V22-infra #4)                                 //
   //==============================================================//
   if(InpUseFixedLot)
   {
      double fixedLots = ClampLot(InpFixedLot);
      if(fixedLots <= 0.0)
      {
         ALog(StringFormat("LOT|REJECT|FIXED lot %.2f cannot be clamped into "
                           "[%.2f .. min(%.2f, %.2f, %.2f)]",
                           InpFixedLot, g_volMin, InpMaxLot, HARD_MAX_LOT, g_volMax));
         return 0.0;
      }

      // The whole point of this log line: show the user what risk a flat
      // lot actually implies for THIS stop distance. A 0.06 lot on a wide
      // stop can quietly be several times the intended 0.70%.
      double riskMoney   = fixedLots * lossPerLot;
      double impliedRisk = (balance > 0.0 ? riskMoney / balance * 100.0 : 0.0);

      ALog(StringFormat("LOT|FIXED|lots=%s impliedRisk=%s%% riskMoney=%s lossPerLot=%s",
                        DoubleToString(fixedLots, g_volDigits),
                        DoubleToString(impliedRisk, 2),
                        DoubleToString(riskMoney, 2),
                        DoubleToString(lossPerLot, 2)));

      if(impliedRisk > InpRiskPercent + 1e-9)
         ALog(StringFormat("LOT|FIXED|WARN implied risk %s%% exceeds InpRiskPercent %s%% "
                           "- flat lot is riskier than the configured budget",
                           DoubleToString(impliedRisk, 2),
                           DoubleToString(InpRiskPercent, 2)));

      double totalDDFixed = TotalDDPercent();
      if(totalDDFixed >= InpTotalDDReduceAt)
         ALog(StringFormat("LOT|FIXED|WARN totalDD %s%% >= %s%% but fixed-lot mode does NOT "
                           "de-risk - consider InpUseFixedLot=false",
                           DoubleToString(totalDDFixed, 2),
                           DoubleToString(InpTotalDDReduceAt, 2)));

      return fixedLots;
   }

   //==============================================================//
   //  MODE A - risk-based sizing (unchanged from V21)              //
   //==============================================================//

   //--- 1. Effective risk percentage -----------------------------//
   double effRisk = InpRiskPercent;
   if(InpCompoundLots && g_initialBalance > 0.0)
   {
      double growth = balance / g_initialBalance;
      effRisk = InpRiskPercent * growth;
      // Safety clamp: compounding may never more than double the risk.
      effRisk = MathMin(effRisk, InpRiskPercent * 2.0);
   }

   //--- 2. Drawdown de-risk: halve the risk near the DD ceiling ---//
   double totalDD = TotalDDPercent();
   if(totalDD >= InpTotalDDReduceAt)
   {
      effRisk *= 0.5;
      VLog(StringFormat("LOT|DERISK|totalDD=%.2f%% >= %.2f%% -> risk halved to %.3f%%",
                        totalDD, InpTotalDDReduceAt, effRisk));
   }

   double riskMoney = balance * (effRisk / 100.0);
   if(riskMoney <= 0.0) return 0.0;

   //--- 3. Raw lots -> floored to the broker volume step ---------//
   double rawLots = riskMoney / lossPerLot;
   double lots    = MathFloor(rawLots / g_volStep) * g_volStep;

   //--- 4. Ceilings (input cap, hard prop cap, broker cap) -------//
   lots = MathMin(lots, InpMaxLot);
   lots = MathMin(lots, HARD_MAX_LOT);
   lots = MathMin(lots, g_volMax);
   lots = MathFloor(lots / g_volStep) * g_volStep;
   lots = NormalizeDouble(lots, g_volDigits);

   //--- 5. Floors: REJECT, never force the size upward ----------//
   if(lots < g_volMin - 1e-9)
   {
      VLog(StringFormat("LOT|REJECT|raw=%.4f floored=%.4f < brokerMin=%.4f (risk=%.2f/lotLoss=%.2f)",
                        rawLots, lots, g_volMin, riskMoney, lossPerLot));
      return 0.0;
   }
   if(lots < InpMinLot - 1e-9)
   {
      VLog(StringFormat("LOT|REJECT|raw=%.4f floored=%.4f < InpMinLot=%.4f (risk=%.2f/lotLoss=%.2f)",
                        rawLots, lots, InpMinLot, riskMoney, lossPerLot));
      return 0.0;
   }

   VLog(StringFormat("LOT|OK|lots=%.2f effRisk=%.3f%% riskMoney=%.2f lossPerLot=%.2f raw=%.4f",
                     lots, effRisk, riskMoney, lossPerLot, rawLots));
   return lots;
}

//==================================================================//
//  SECTION 9 - PRE-TRADE GUARDS                                    //
//==================================================================//
//  Master gate. Each rejection increments its own counter AT MOST
//  ONCE PER ARMED SETUP (V22-infra #3): the first blocking tick counts and
//  logs, every later tick for the same setup returns false silently.
//  That is what turns the DIAG block from a tick histogram into a
//  readable "where did my setups die" report.
//------------------------------------------------------------------//

//------------------------------------------------------------------//
//| Clear every per-setup guard latch (called on arm and disarm)    |
//------------------------------------------------------------------//
void ResetGuardLatches()
{
   g_latchSpread     = false;
   g_latchDailyLimit = false;
   g_latchMaxTrades  = false;
   g_latchPosition   = false;
   g_latchTotalDD    = false;
   g_latchLot        = false;
}

bool IsAllowedToTrade()
{
   //--- Guard 1: spread -----------------------------------------//
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > (long)InpMaxSpread)
   {
      if(!g_latchSpread)
      {
         g_latchSpread = true;
         g_rejSpread++;
         VLog(StringFormat("GUARD|SPREAD|%d > max %d - entry blocked, setup stays armed",
                           (int)spread, InpMaxSpread));
      }
      return false;
   }

   //--- Guard 2: daily loss latch --------------------------------//
   // Once a daily limit has been hit it stays hit for the REST of the
   // day (Requirements 1.1 / 14.1), even if a later winner would pull
   // the running P&L back above the threshold.
   if(g_dailyLimitHit)
   {
      if(!g_latchDailyLimit)
      {
         g_latchDailyLimit = true;
         g_rejDailyLimit++;
      }
      return false;
   }

   //--- Guard 3: daily loss as % of day-start balance ------------//
   double dailyDD = DailyDDPercent();
   if(dailyDD >= InpDailyLossPct)
   {
      if(!g_latchDailyLimit)
      {
         g_latchDailyLimit = true;
         g_rejDailyLimit++;
      }
      if(!g_dailyLimitHit)
      {
         // Day-level latch: this always-on line prints at most once
         // per day, so it cannot flood the journal.
         g_dailyLimitHit = true;
         ALog(StringFormat("GUARD|DAILY_DD|%.2f%% >= %.2f%% - no more entries today",
                           dailyDD, InpDailyLossPct));
      }
      return false;
   }

   //--- Guard 4: daily loss in R terms --------------------------//
   double lossR = 0.0;
   if(g_oneRMoney > 0.0 && g_dailyRealizedPnL < 0.0)
      lossR = (-g_dailyRealizedPnL) / g_oneRMoney;
   if(lossR >= InpDailyLossStopR)
   {
      if(!g_latchDailyLimit)
      {
         g_latchDailyLimit = true;
         g_rejDailyLimit++;
      }
      if(!g_dailyLimitHit)
      {
         g_dailyLimitHit = true;
         ALog(StringFormat("GUARD|DAILY_R|loss=%.2fR >= %.2fR (pnl=%.2f, 1R=%.2f) - no more entries today",
                           lossR, InpDailyLossStopR, g_dailyRealizedPnL, g_oneRMoney));
      }
      return false;
   }

   //--- Guard 5: max trades per day -----------------------------//
   if(g_tradesToday >= InpMaxTradesPerDay)
   {
      if(!g_latchMaxTrades)
      {
         g_latchMaxTrades = true;
         g_rejMaxTrades++;
         VLog(StringFormat("GUARD|MAX_TRADES|%d/%d reached", g_tradesToday, InpMaxTradesPerDay));
      }
      return false;
   }

   //--- Guard 6: single position only ---------------------------//
   if(CountMyPositions() > 0)
   {
      if(!g_latchPosition)
      {
         g_latchPosition = true;
         g_rejPosition++;
         VLog("GUARD|POSITION|an EA position is already open");
      }
      return false;
   }

   //--- Guard 7: weekday blackout - SILENT safety net (V22-infra #2) --//
   // The real weekday decision now happens at SCAN time in OnTick
   // Phase 3, so no setup is ever armed on a blocked weekday. This
   // check stays here purely so a setup armed on Wednesday night can
   // never fire after the Thursday rollover. It deliberately does NOT
   // log and does NOT touch g_rejWeekday - that per-tick logging is
   // exactly what flooded the V21 journal (4,752,056 records).
   if(!IsWeekdayAllowed())
      return false;

   //--- Guard 8: total drawdown -> stop entering entirely -------//
   double totalDD = TotalDDPercent();
   if(totalDD >= InpTotalDDStopAt)
   {
      if(!g_latchTotalDD)
      {
         g_latchTotalDD = true;
         g_rejTotalDD++;
         VLog(StringFormat("GUARD|TOTAL_DD|%.2f%% >= %.2f%% - entries stopped",
                           totalDD, InpTotalDDStopAt));
      }
      return false;
   }

   return true;
}

//==================================================================//
//  SECTION 10 - SETUP LIFECYCLE                                    //
//==================================================================//

//------------------------------------------------------------------//
//| Arm a setup for InpValidBars bars                               |
//------------------------------------------------------------------//
void ArmSetup(const int direction, const double trigger, const double sl, const datetime kneeTime)
{
   g_setupDirection = direction;
   g_triggerPrice   = trigger;
   g_pendingSL      = sl;
   g_barsRemaining  = InpValidBars;
   g_setupTime      = kneeTime;
   g_setupsArmed++;

   if(direction == 1) g_setupsArmedBuy++;
   else               g_setupsArmedSell++;

   // Fresh setup -> every guard gets one count and one log again.
   ResetGuardLatches();

   ALog(StringFormat("SETUP|ARM|%s trigger=%s sl=%s dist=%.1fpts valid=%d adx=%.1f atr=%s",
                     (direction == 1 ? "BUY" : "SELL"),
                     DoubleToString(trigger, g_digits),
                     DoubleToString(sl, g_digits),
                     MathAbs(trigger - sl) / g_point,
                     InpValidBars, g_adx,
                     DoubleToString(g_atr, g_digits)));
}

//------------------------------------------------------------------//
//| Clear the armed setup                                           |
//------------------------------------------------------------------//
void Disarm(const string reason)
{
   if(g_setupDirection != 0)
      VLog(StringFormat("SETUP|DISARM|%s (%s)",
                        (g_setupDirection == 1 ? "BUY" : "SELL"), reason));
   g_setupDirection = 0;
   g_triggerPrice   = 0.0;
   g_pendingSL      = 0.0;
   g_barsRemaining  = 0;
   g_setupTime      = 0;

   // No setup armed -> no guard may hold a stale latch.
   ResetGuardLatches();
}

//==================================================================//
//  SECTION 11 - REGIME FILTER (ADX) - OPTIONAL, OFF BY DEFAULT      //
//==================================================================//
//  Returns true when new setups are permitted.
//
//  V23: InpUseRegimeFilter defaults to FALSE, so this routine returns
//  true on the very first line and the strategy behaves exactly like
//  V20, which had no ADX filter at all. The code is kept so the idea
//  can be tested ON ITS OWN later - the ledger classes ADX as an
//  overfit risk, and in V21/V22 it was one of three filters added
//  simultaneously, which is why nobody can say what it actually cost.
//
//  Fails OPEN on indicator trouble so a broken ADX feed does not
//  silently switch the strategy off.
//------------------------------------------------------------------//
bool RegimeFilter()
{
   if(!InpUseRegimeFilter) return true;    // DEFAULT PATH in V23 (feature off)
   if(!g_adxValid)         return true;    // fail-open
   if(g_adx <= 0.0)        return true;    // fail-open

   return (g_adx >= InpADXThreshold);
}

//==================================================================//
//  SECTION 12 - KNEE PATTERN SCANNERS                              //
//==================================================================//
//  Shift 1 is the most recent CLOSED bar and is always the "knee".
//  Shift 2..InpLookback are the bars of the preceding run.
//
//  V23: the ASYMMETRY between the two sides is restored to V20 -
//  BUY needs run >= 2 and body >= 0.60, SELL needs run >= 3 and
//  body >= 0.70. That asymmetry is the V19/V20 finding ("sell needs
//  stricter rules") and it is the shape of the only MT5-verified
//  profitable run. V22 symmetrised BUY up to 3/0.70 and the trade
//  count halved, so the tightening is REVERTED here.
//
//  The scan logic itself is byte-for-byte the V22 logic; only the
//  input DEFAULTS moved. Both sides remain separate inputs so they
//  stay independently tunable in the Strategy Tester - one at a time.
//------------------------------------------------------------------//

//------------------------------------------------------------------//
//| BUY knee: green run -> bearish knee -> break of the knee high   |
//------------------------------------------------------------------//
bool ScanBuyKnee()
{
   if(!InpAllowBuy)                  return false;
   if(!g_indValid || g_atr <= 0.0)   return false;   // fail-closed
   if(Bars(_Symbol, _Period) < InpLookback + 3) return false;

   //--- Step 1: the knee bar must be bearish --------------------//
   double   kOpen  = iOpen (_Symbol, _Period, 1);
   double   kHigh  = iHigh (_Symbol, _Period, 1);
   double   kLow   = iLow  (_Symbol, _Period, 1);
   double   kClose = iClose(_Symbol, _Period, 1);
   datetime kTime  = iTime (_Symbol, _Period, 1);
   if(kOpen <= 0.0 || kHigh <= 0.0 || kLow <= 0.0 || kClose <= 0.0) return false;
   if(kClose >= kOpen) return false;

   //--- Step 2: never re-arm a knee we have already traded ------//
   if(kTime == g_lastTradedSetup) return false;

   //--- Step 3: consecutive green bars immediately before knee --//
   int greenRun = 0;
   for(int i = 2; i <= InpLookback; i++)
   {
      double o = iOpen (_Symbol, _Period, i);
      double c = iClose(_Symbol, _Period, i);
      if(o <= 0.0 || c <= 0.0) break;
      if(c > o) greenRun++;
      else      break;                       // run is broken - stop counting
   }
   if(greenRun < InpKneeMinRunBuy) return false;

   //--- Step 4: entry strength of the last green bar (shift 2) --//
   double lgOpen  = iOpen (_Symbol, _Period, 2);
   double lgClose = iClose(_Symbol, _Period, 2);
   double lgHigh  = iHigh (_Symbol, _Period, 2);
   double lgLow   = iLow  (_Symbol, _Period, 2);
   double body    = MathAbs(lgClose - lgOpen);
   double range   = lgHigh - lgLow;
   if(range > 0.0 && (body / range) < InpEntryStrengthBuy) return false;

   //--- Step 5: EMA trend alignment ----------------------------//
   if(!(g_emaFast > g_emaSlow && kClose > g_emaFast)) return false;

   //--- Step 6: trigger and protective stop --------------------//
   double trigger = CeilToTick(kHigh);
   double sl      = FloorToTick(kLow - InpSLBufferATR * g_atr);
   if(trigger <= sl) return false;

   //--- Step 7: minimum stop distance --------------------------//
   double slPts = (trigger - sl) / g_point;
   if(slPts < (double)InpMinSLPoints) return false;

   ArmSetup(1, trigger, sl, kTime);
   return true;
}

//------------------------------------------------------------------//
//| SELL knee: red run -> bullish knee -> break of the knee low     |
//| This side stays STRICTER than BUY (run 3 / body 0.70 vs 2/0.60) |
//| exactly as V20 had it. V20 measured Short WR 36.36% against     |
//| Long WR 38.86% on this split, so both sides earned their place. |
//------------------------------------------------------------------//
bool ScanSellKnee()
{
   if(!InpAllowSell)                 return false;
   if(!g_indValid || g_atr <= 0.0)   return false;   // fail-closed
   if(Bars(_Symbol, _Period) < InpLookback + 3) return false;

   //--- Step 1: the knee bar must be bullish -------------------//
   double   kOpen  = iOpen (_Symbol, _Period, 1);
   double   kHigh  = iHigh (_Symbol, _Period, 1);
   double   kLow   = iLow  (_Symbol, _Period, 1);
   double   kClose = iClose(_Symbol, _Period, 1);
   datetime kTime  = iTime (_Symbol, _Period, 1);
   if(kOpen <= 0.0 || kHigh <= 0.0 || kLow <= 0.0 || kClose <= 0.0) return false;
   if(kClose <= kOpen) return false;

   //--- Step 2: never re-arm a knee we have already traded -----//
   if(kTime == g_lastTradedSetup) return false;

   //--- Step 3: consecutive red bars immediately before knee ---//
   int redRun = 0;
   for(int i = 2; i <= InpLookback; i++)
   {
      double o = iOpen (_Symbol, _Period, i);
      double c = iClose(_Symbol, _Period, i);
      if(o <= 0.0 || c <= 0.0) break;
      if(c < o) redRun++;
      else      break;
   }
   if(redRun < InpKneeMinRunSell) return false;

   //--- Step 4: entry strength of the last red bar (shift 2) ---//
   double lrOpen  = iOpen (_Symbol, _Period, 2);
   double lrClose = iClose(_Symbol, _Period, 2);
   double lrHigh  = iHigh (_Symbol, _Period, 2);
   double lrLow   = iLow  (_Symbol, _Period, 2);
   double body    = MathAbs(lrOpen - lrClose);
   double range   = lrHigh - lrLow;
   if(range > 0.0 && (body / range) < InpEntryStrengthSell) return false;

   //--- Step 5: EMA trend alignment (bearish) ------------------//
   if(!(g_emaFast < g_emaSlow && kClose < g_emaFast)) return false;

   //--- Step 6: trigger and protective stop -------------------//
   double trigger = FloorToTick(kLow);
   double sl      = CeilToTick(kHigh + InpSLBufferATR * g_atr);
   if(sl <= trigger) return false;

   //--- Step 7: minimum stop distance -------------------------//
   double slPts = (sl - trigger) / g_point;
   if(slPts < (double)InpMinSLPoints) return false;

   ArmSetup(-1, trigger, sl, kTime);
   return true;
}

//==================================================================//
//  SECTION 13 - TRADE EXECUTION                                    //
//==================================================================//

//------------------------------------------------------------------//
//| Transient retcodes: worth retrying on the next tick             |
//------------------------------------------------------------------//
bool IsTransientRetcode(const uint rc)
{
   return (rc == TRADE_RETCODE_REQUOTE       ||
           rc == TRADE_RETCODE_PRICE_CHANGED ||
           rc == TRADE_RETCODE_PRICE_OFF     ||
           rc == TRADE_RETCODE_TIMEOUT       ||
           rc == TRADE_RETCODE_REJECT);
}

//------------------------------------------------------------------//
//| Recompute the fixed TP from the ACTUAL fill price and apply it. |
//| Requirement 5.1: TP = fill +/- RR * |fill - SL|                 |
//------------------------------------------------------------------//
bool ApplyTPFromFill(const ulong ticket, const int direction)
{
   if(!PositionSelectByTicket(ticket)) return false;

   double fill = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl   = PositionGetDouble(POSITION_SL);
   if(fill <= 0.0 || sl <= 0.0) return false;

   double risk = MathAbs(fill - sl);
   if(risk <= 0.0) return false;

   double tp = (direction == 1) ? RoundToTick(fill + InpRR * risk)
                                : RoundToTick(fill - InpRR * risk);

   //--- Validate the TP against the broker stops level ---------//
   MqlTick t;
   if(SymbolInfoTick(_Symbol, t))
   {
      double minDist = MinStopDistance();
      if(direction == 1)
      {
         if(tp - t.bid < minDist) tp = CeilToTick(t.bid + minDist + TickSizeSafe());
      }
      else
      {
         if(t.ask - tp < minDist) tp = FloorToTick(t.ask - minDist - TickSizeSafe());
      }
   }

   //--- Directional sanity (Requirements 5.4 / 5.5) ------------//
   if(direction ==  1 && tp <= fill) return false;
   if(direction == -1 && tp >= fill) return false;

   if(!g_trade.PositionModify(ticket, sl, tp))
   {
      ALog(StringFormat("TP|FAIL|ticket=%I64u sl=%s tp=%s rc=%d (%s)", ticket,
                        DoubleToString(sl, g_digits), DoubleToString(tp, g_digits),
                        (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
      return false;
   }

   VLog(StringFormat("TP|SET|ticket=%I64u fill=%s sl=%s risk=%s RR=%.2f tp=%s", ticket,
                     DoubleToString(fill, g_digits), DoubleToString(sl, g_digits),
                     DoubleToString(risk, g_digits), InpRR,
                     DoubleToString(tp, g_digits)));
   return true;
}

//------------------------------------------------------------------//
//| Open a position in the armed direction.                         |
//| Returns true when a position exists and is fully configured.    |
//------------------------------------------------------------------//
bool OpenPosition(const int direction)
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
   {
      g_orderFails++;
      ALog("ORDER|FAIL|SymbolInfoTick failed");
      return false;
   }

   double entryRef = (direction == 1 ? t.ask : t.bid);
   double sl       = g_pendingSL;
   if(entryRef <= 0.0 || sl <= 0.0) return false;

   //--- Broker stops level: widen the SL if it sits too close.
   //    Widening is safe because the lot size is computed from the
   //    widened distance, so the money at risk is unchanged.
   double minDist = MinStopDistance();
   if(direction == 1)
   {
      if(entryRef - sl < minDist)
         sl = FloorToTick(entryRef - minDist - TickSizeSafe());
      if(sl <= 0.0 || sl >= entryRef) return false;
   }
   else
   {
      if(sl - entryRef < minDist)
         sl = CeilToTick(entryRef + minDist + TickSizeSafe());
      if(sl <= entryRef) return false;
   }

   //--- Position size -------------------------------------------//
   double lots = CalcLot(entryRef, sl, direction);
   if(lots <= 0.0)
   {
      if(!g_latchLot)
      {
         g_latchLot = true;
         g_rejLot++;
      }
      ALog(StringFormat("ORDER|REJECT|lot size rejected (%s entry=%s sl=%s) - setup disarmed",
                        (direction == 1 ? "BUY" : "SELL"),
                        DoubleToString(entryRef, g_digits),
                        DoubleToString(sl, g_digits)));
      Disarm("lot rejected");
      return false;
   }

   //--- Submit the market order (TP applied after the fill) -----//
   string comment = (direction == 1 ? "V23_KNEE_BUY" : "V23_KNEE_SELL");
   bool sent = (direction == 1)
               ? g_trade.Buy (lots, _Symbol, 0.0, sl, 0.0, comment)
               : g_trade.Sell(lots, _Symbol, 0.0, sl, 0.0, comment);

   uint rc = g_trade.ResultRetcode();

   if(!sent || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED &&
                rc != TRADE_RETCODE_DONE_PARTIAL))
   {
      g_orderFails++;
      bool transient = IsTransientRetcode(rc);
      ALog(StringFormat("ORDER|FAIL|%s lots=%.2f sl=%s rc=%d (%s) -> %s",
                        (direction == 1 ? "BUY" : "SELL"), lots,
                        DoubleToString(sl, g_digits),
                        (int)rc, g_trade.ResultRetcodeDescription(),
                        (transient ? "TRANSIENT, setup stays armed" : "PERMANENT, disarming")));
      if(!transient)
         Disarm("permanent order failure");
      return false;
   }

   //--- Confirm the fill ---------------------------------------//
   ulong tk = FindPositionTicket();
   if(tk == 0)
   {
      // Filled then instantly closed, or a rejected fill reported as OK.
      g_orderFails++;
      ALog(StringFormat("ORDER|FAIL|no position found after send (deal=%I64u rc=%d) - disarming",
                        g_trade.ResultDeal(), (int)rc));
      Disarm("position not found after fill");
      return false;
   }

   //--- Freeze the entry state ---------------------------------//
   // g_initialRisk is the 1R yardstick for break-even and for arming the
   // trailing stop. It is captured ONCE here, from the real fill, so it
   // cannot drift later when the stop starts moving. (Unchanged from V21
   // on purpose - this logic is correct and must not regress.)
   double actualSL = sl;
   if(PositionSelectByTicket(tk))
   {
      g_entryPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      actualSL      = PositionGetDouble(POSITION_SL);
      if(actualSL <= 0.0) actualSL = sl;
      g_initialRisk = MathAbs(g_entryPrice - actualSL);
   }
   else
   {
      g_entryPrice  = g_trade.ResultPrice();
      g_initialRisk = MathAbs(g_entryPrice - sl);
   }

   g_positionTicket = tk;
   g_hasPosition    = true;
   g_beApplied      = false;

   //--- TP from the actual fill --------------------------------//
   ApplyTPFromFill(tk, direction);

   //--- Book-keeping ------------------------------------------//
   g_tradesToday++;
   g_cntEntries++;
   if(direction == 1) g_cntEntriesBuy++;
   else               g_cntEntriesSell++;
   g_lastTradedSetup = g_setupTime;

   ALog(StringFormat("ENTRY|%s|ticket=%I64u lots=%.2f fill=%s sl=%s risk=%s "
                     "trade#%d/%d adx=%.1f atr=%s spread=%d",
                     (direction == 1 ? "BUY" : "SELL"), tk, lots,
                     DoubleToString(g_entryPrice, g_digits),
                     DoubleToString(actualSL, g_digits),
                     DoubleToString(g_initialRisk, g_digits),
                     g_tradesToday, InpMaxTradesPerDay, g_adx,
                     DoubleToString(g_atr, g_digits),
                     (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));

   Disarm("entered");
   return true;
}

bool OpenBuy()  { return OpenPosition(1);  }
bool OpenSell() { return OpenPosition(-1); }

//==================================================================//
//  SECTION 14 - EXIT MANAGEMENT (break-even + trailing)            //
//==================================================================//
//  V23 defaults: break-even ON at +1.0R (V20 used BE at 1R) and the
//  trailing stop OFF. The trail code below is fully functional and is
//  kept verbatim from V22, but it is an OPTIONAL FEATURE: V20 never
//  had it, and the 6xATR trail it came from measured DD 48% in MT5.
//
//  The R multiples that fire break-even and arm the trail are inputs
//  (InpBEAtR / InpTrailStartR), and the BE stop can sit a cushion of
//  InpBEOffsetPoints ABOVE entry for a BUY (BELOW for a SELL). V21
//  parked the BE stop at the exact entry, so the spread alone could
//  stop out a break-even'd trade for a small loss.
//
//  Unchanged on purpose:
//    * g_initialRisk stays FROZEN at fill time (no self-feeding R)
//    * BE stays idempotent through g_beApplied
//    * the trail stays strictly monotonic
//    * neither routine EVER modifies the take profit
//------------------------------------------------------------------//

//------------------------------------------------------------------//
//| Break-even: move SL to entry (+/- optional cushion) at +BEAtR R |
//------------------------------------------------------------------//
void ManageBreakEven()
{
   if(!InpUseBreakEven) return;
   if(InpBEAtR <= 0.0)  return;              // 0 disables BE entirely
   if(g_beApplied)      return;              // already done - no-op

   ulong tk = g_positionTicket;
   if(tk == 0) return;
   if(!PositionSelectByTicket(tk)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)  return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   long   ptype = PositionGetInteger(POSITION_TYPE);

   // The R reference is FROZEN at fill time so it cannot drift once
   // the stop has been moved (that would make BE/trail self-feeding).
   double risk = g_initialRisk;
   if(risk <= 0.0) risk = MathAbs(entry - curSL);
   if(risk <= 0.0) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   double minDist = MinStopDistance();
   double cushion = (double)InpBEOffsetPoints * g_point;

   if(ptype == POSITION_TYPE_BUY)
   {
      double armAt = entry + InpBEAtR * risk;
      if(t.bid < armAt) return;                        // BE level not reached yet

      double newSL = RoundToTick(entry + cushion);     // cushion ABOVE entry
      if(newSL <= curSL) { g_beApplied = true; return; }   // trail already better
      if(newSL >= t.bid)          return;              // sanity
      if(t.bid - newSL < minDist) return;              // broker would refuse

      if(g_trade.PositionModify(tk, newSL, curTP))
      {
         g_beApplied = true;
         ALog(StringFormat("BE|BUY|ticket=%I64u sl %s -> %s (entry+%dpts; +%.2fR=%s reached)", tk,
                           DoubleToString(curSL, g_digits),
                           DoubleToString(newSL, g_digits),
                           InpBEOffsetPoints, InpBEAtR,
                           DoubleToString(armAt, g_digits)));
      }
      else
      {
         VLog(StringFormat("BE|FAIL|BUY ticket=%I64u rc=%d (%s)", tk,
                           (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
      }
   }
   else if(ptype == POSITION_TYPE_SELL)
   {
      double armAt = entry - InpBEAtR * risk;
      if(t.ask > armAt) return;                        // BE level not reached yet

      double newSL = RoundToTick(entry - cushion);     // cushion BELOW entry
      if(curSL > 0.0 && newSL >= curSL) { g_beApplied = true; return; }
      if(newSL <= t.ask)          return;              // sanity
      if(newSL - t.ask < minDist) return;

      if(g_trade.PositionModify(tk, newSL, curTP))
      {
         g_beApplied = true;
         ALog(StringFormat("BE|SELL|ticket=%I64u sl %s -> %s (entry-%dpts; +%.2fR=%s reached)", tk,
                           DoubleToString(curSL, g_digits),
                           DoubleToString(newSL, g_digits),
                           InpBEOffsetPoints, InpBEAtR,
                           DoubleToString(armAt, g_digits)));
      }
      else
      {
         VLog(StringFormat("BE|FAIL|SELL ticket=%I64u rc=%d (%s)", tk,
                           (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
      }
   }
}

//------------------------------------------------------------------//
//| Trailing stop at InpTrailATR x ATR, armed after +InpTrailStartR |
//| Strictly monotonic: the SL can only ever move toward profit.    |
//| Never touches the TP - if the trail is wider than the fixed TP  |
//| the TP closes the trade; if price blows past the TP the trail   |
//| is what captures the runner (the "hybrid" in HybridKnee).       |
//------------------------------------------------------------------//
void ManageTrailingStop()
{
   if(!InpUseTrailing) return;
   if(!g_indValid || g_atr <= 0.0) return;    // fail-closed on bad ATR

   ulong tk = g_positionTicket;
   if(tk == 0) return;
   if(!PositionSelectByTicket(tk)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)  return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   long   ptype = PositionGetInteger(POSITION_TYPE);

   double risk = g_initialRisk;
   if(risk <= 0.0) risk = MathAbs(entry - curSL);
   if(risk <= 0.0) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   double minDist  = MinStopDistance();
   double trailDst = InpTrailATR * g_atr;

   if(ptype == POSITION_TYPE_BUY)
   {
      double armAt = entry + InpTrailStartR * risk;
      if(t.bid < armAt) return;                        // trail not armed yet

      double newSL = FloorToTick(t.bid - trailDst);
      if(newSL <= curSL)          return;              // monotonic: never backward
      if(newSL >= t.bid)          return;              // sanity
      if(t.bid - newSL < minDist) return;              // broker minimum

      if(g_trade.PositionModify(tk, newSL, curTP))
         VLog(StringFormat("TRAIL|BUY|ticket=%I64u sl %s -> %s (bid=%s - %.1fxATR %s)", tk,
                           DoubleToString(curSL, g_digits),
                           DoubleToString(newSL, g_digits),
                           DoubleToString(t.bid, g_digits),
                           InpTrailATR, DoubleToString(g_atr, g_digits)));
      else
         VLog(StringFormat("TRAIL|FAIL|BUY ticket=%I64u rc=%d (%s)", tk,
                           (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
   }
   else if(ptype == POSITION_TYPE_SELL)
   {
      double armAt = entry - InpTrailStartR * risk;
      if(t.ask > armAt) return;                        // trail not armed yet

      double newSL = CeilToTick(t.ask + trailDst);
      if(curSL > 0.0 && newSL >= curSL) return;        // monotonic: never backward
      if(newSL <= t.ask)                return;        // sanity
      if(newSL - t.ask < minDist)       return;        // broker minimum

      if(g_trade.PositionModify(tk, newSL, curTP))
         VLog(StringFormat("TRAIL|SELL|ticket=%I64u sl %s -> %s (ask=%s + %.1fxATR %s)", tk,
                           DoubleToString(curSL, g_digits),
                           DoubleToString(newSL, g_digits),
                           DoubleToString(t.ask, g_digits),
                           InpTrailATR, DoubleToString(g_atr, g_digits)));
      else
         VLog(StringFormat("TRAIL|FAIL|SELL ticket=%I64u rc=%d (%s)", tk,
                           (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
   }
}

//==================================================================//
//  SECTION 15 - DIAGNOSTICS SUMMARY                                //
//==================================================================//
//  V22-infra #10: this block is designed to be sufficient on its own. It
//  reports the realized win/loss split the EA counted from the deal
//  stream, the payoff ratio, the profit factor, the breakeven WR that
//  payoff implies, and the STATIC drawdown the MT5 report omits.
//------------------------------------------------------------------//

//------------------------------------------------------------------//
//| Realized payoff ratio (avg win / avg loss). 0 when unknown.     |
//------------------------------------------------------------------//
double RealizedPayoff()
{
   if(g_realWins <= 0 || g_realLosses <= 0) return 0.0;
   double avgWin  = g_grossWin  / (double)g_realWins;
   double avgLoss = g_grossLoss / (double)g_realLosses;
   if(avgLoss <= 0.0) return 0.0;
   return avgWin / avgLoss;
}

//------------------------------------------------------------------//
//| Win rate % over closed trades that actually won or lost         |
//------------------------------------------------------------------//
double RealizedWinRate()
{
   int decided = g_realWins + g_realLosses;
   if(decided <= 0) return 0.0;
   return (double)g_realWins / (double)decided * 100.0;
}

//------------------------------------------------------------------//
//| Break-even win rate implied by a payoff ratio: 1/(1+payoff)     |
//------------------------------------------------------------------//
double BreakevenWinRate(const double payoff)
{
   if(payoff <= 0.0) return 0.0;
   return 100.0 / (1.0 + payoff);
}

void PrintDiagnostics(const string label)
{
   double payoff       = RealizedPayoff();
   double winRate      = RealizedWinRate();
   double beWinRate    = BreakevenWinRate(payoff);
   double profitFactor = (g_grossLoss > 0.0 ? g_grossWin / g_grossLoss : 0.0);
   int    decided      = g_realWins + g_realLosses;

   ALog("================ " + label + " ================");

   //--- Activity ------------------------------------------------//
   ALog(StringFormat("DIAG|Entries taken .............. %d", g_cntEntries));

   //--- Trade-count sanity check against V20 (NEW IN V23) -------//
   //  Trade COUNT is the leading indicator of over-filtering: V20 took
   //  270, V21 took 110, V22 took 148. A collapse here means a filter
   //  is deleting valid setups, and it shows up long before the P&L
   //  figures are statistically meaningful.
   double refPct = ((double)g_cntEntries / (double)V20_REF_TRADES - 1.0) * 100.0;
   ALog(StringFormat("DIAG|V20 reference ............... %d trades, PF %s, %s",
                     V20_REF_TRADES, DoubleToString(V20_REF_PF, 2), V20_REF_NET_TXT));
   ALog(StringFormat("DIAG|This run vs V20 ............. %d trades (%s%s%%) "
                     "<- over-filtering warning if far below",
                     g_cntEntries,
                     (refPct >= 0.0 ? "+" : ""),
                     DoubleToString(refPct, 0)));
   if(g_cntEntries < TRADE_COUNT_FLOOR)
      ALog("DIAG|WARNING trade count far below the V20 baseline - a filter is removing valid setups");

   ALog(StringFormat("DIAG|Entries BUY / SELL ......... %d / %d",
                     g_cntEntriesBuy, g_cntEntriesSell));
   ALog(StringFormat("DIAG|Setups armed ............... %d", g_setupsArmed));
   ALog(StringFormat("DIAG|Setups armed BUY / SELL .... %d / %d",
                     g_setupsArmedBuy, g_setupsArmedSell));
   ALog(StringFormat("DIAG|Setups expired unused ...... %d", g_setupsExpired));

   //--- Rejections: PER SETUP (V22-infra #3), not per tick ------------//
   ALog("DIAG|Rejected (per setup, not per tick)");
   ALog(StringFormat("DIAG|  spread ................... %d", g_rejSpread));
   ALog(StringFormat("DIAG|  ADX regime (per bar) ..... %d", g_rejRegime));
   ALog(StringFormat("DIAG|  daily limit .............. %d", g_rejDailyLimit));
   ALog(StringFormat("DIAG|  weekday (per bar) ........ %d", g_rejWeekday));
   ALog(StringFormat("DIAG|  max trades/day ........... %d", g_rejMaxTrades));
   ALog(StringFormat("DIAG|  open position ............ %d", g_rejPosition));
   ALog(StringFormat("DIAG|  total DD guard ........... %d", g_rejTotalDD));
   ALog(StringFormat("DIAG|  lot size ................. %d", g_rejLot));

   //--- Failures ------------------------------------------------//
   ALog(StringFormat("DIAG|Order failures ............. %d", g_orderFails));
   ALog(StringFormat("DIAG|Indicator failures ......... %d", g_indFailures));

   //--- Realized performance, counted by the EA itself ----------//
   ALog(StringFormat("DIAG|Closed trades (decided) .... %d  (flat/zero: %d)",
                     decided, g_realFlat));
   ALog(StringFormat("DIAG|Realized wins / losses ..... %d / %d",
                     g_realWins, g_realLosses));
   ALog(StringFormat("DIAG|Achieved win rate .......... %s%%",
                     DoubleToString(winRate, 2)));
   ALog(StringFormat("DIAG|Gross win / gross loss ..... %s / %s",
                     DoubleToString(g_grossWin, 2), DoubleToString(g_grossLoss, 2)));
   ALog(StringFormat("DIAG|Net realized P&L ........... %s",
                     DoubleToString(g_grossWin - g_grossLoss, 2)));
   ALog(StringFormat("DIAG|Payoff ratio (avgW/avgL) ... %s",
                     DoubleToString(payoff, 2)));
   ALog(StringFormat("DIAG|Profit factor .............. %s",
                     DoubleToString(profitFactor, 2)));
   ALog(StringFormat("DIAG|Breakeven WR needed at this payoff .. %s%%   (achieved %s%% -> %s)",
                     DoubleToString(beWinRate, 1),
                     DoubleToString(winRate, 1),
                     (payoff <= 0.0 ? "n/a"
                      : (winRate >= beWinRate ? "ABOVE breakeven" : "BELOW breakeven"))));

   //--- Drawdown: the STATIC prop firm measure (V22-infra #9) ---------//
   ALog(StringFormat("DIAG|Max STATIC DD (vs initial bal) .. %s%%  (min equity %s)",
                     DoubleToString(g_maxStaticDD, 2),
                     DoubleToString(g_minEquity, 2)));
   ALog(StringFormat("DIAG|Max daily DD (worst day) ........ %s%%",
                     DoubleToString(g_maxDailyDD, 2)));

   //--- Account snapshot ---------------------------------------//
   ALog(StringFormat("DIAG|Balance %.2f  Equity %.2f  InitialBal %.2f  TotalDD %.2f%%",
                     AccountInfoDouble(ACCOUNT_BALANCE),
                     AccountInfoDouble(ACCOUNT_EQUITY),
                     g_initialBalance, TotalDDPercent()));
   ALog("=========================================================");
}

//==================================================================//
//  SECTION 16 - INPUT VALIDATION                                   //
//==================================================================//
bool ValidateInputs()
{
   if(InpRiskPercent < 0.1 || InpRiskPercent > 2.0)
   {
      ALog(StringFormat("INIT|FAIL|InpRiskPercent=%.2f outside allowed range [0.1, 2.0]",
                        InpRiskPercent));
      return false;
   }
   if(InpRR < 1.5)
   {
      ALog(StringFormat("INIT|FAIL|InpRR=%.2f must be >= 1.5", InpRR));
      return false;
   }
   if(InpTrailATR < 3.0)
   {
      ALog(StringFormat("INIT|FAIL|InpTrailATR=%.2f must be >= 3.0 (tighter trails get "
                        "shaken out by gold volatility)", InpTrailATR));
      return false;
   }
   if(InpADXThreshold < 15.0 || InpADXThreshold > 30.0)
   {
      ALog(StringFormat("INIT|FAIL|InpADXThreshold=%.2f outside allowed range [15, 30]",
                        InpADXThreshold));
      return false;
   }
   if(InpMaxLot > HARD_MAX_LOT + 1e-9)
   {
      ALog(StringFormat("INIT|FAIL|InpMaxLot=%.3f exceeds the hard prop firm cap %.3f",
                        InpMaxLot, HARD_MAX_LOT));
      return false;
   }
   if(InpMinLot <= 0.0 || InpMinLot > InpMaxLot)
   {
      ALog(StringFormat("INIT|FAIL|InpMinLot=%.3f must be > 0 and <= InpMaxLot=%.3f",
                        InpMinLot, InpMaxLot));
      return false;
   }
   //--- Fixed-lot mode (V22-infra #4) --------------------------------//
   if(InpFixedLot <= 0.0)
   {
      ALog(StringFormat("INIT|FAIL|InpFixedLot=%.3f must be > 0", InpFixedLot));
      return false;
   }
   if(InpFixedLot > HARD_MAX_LOT + 1e-9)
   {
      ALog(StringFormat("INIT|FAIL|InpFixedLot=%.3f exceeds the hard prop firm cap %.3f",
                        InpFixedLot, HARD_MAX_LOT));
      return false;
   }
   if(InpKneeMinRunBuy < 2)
   {
      ALog(StringFormat("INIT|FAIL|InpKneeMinRunBuy=%d must be >= 2", InpKneeMinRunBuy));
      return false;
   }
   // V23 runs the V20 split (buy 2 / sell 3). Equality stays legal so a
   // symmetric experiment is still possible, but the SELL side may never
   // be LOOSER than the BUY side.
   if(InpKneeMinRunSell < InpKneeMinRunBuy)
   {
      ALog(StringFormat("INIT|FAIL|InpKneeMinRunSell=%d must be >= InpKneeMinRunBuy=%d "
                        "(the sell side may match but never be looser)",
                        InpKneeMinRunSell, InpKneeMinRunBuy));
      return false;
   }
   if(InpEntryStrengthBuy <= 0.0 || InpEntryStrengthBuy > 1.0 ||
      InpEntryStrengthSell <= 0.0 || InpEntryStrengthSell > 1.0)
   {
      ALog(StringFormat("INIT|FAIL|entry strength must be in (0, 1]: buy=%.2f sell=%.2f",
                        InpEntryStrengthBuy, InpEntryStrengthSell));
      return false;
   }
   if(InpValidBars < 1)
   {
      ALog(StringFormat("INIT|FAIL|InpValidBars=%d must be >= 1", InpValidBars));
      return false;
   }
   if(InpLookback < InpKneeMinRunSell + 2)
   {
      ALog(StringFormat("INIT|FAIL|InpLookback=%d too small for InpKneeMinRunSell=%d",
                        InpLookback, InpKneeMinRunSell));
      return false;
   }
   if(InpSLBufferATR < 0.0)
   {
      ALog(StringFormat("INIT|FAIL|InpSLBufferATR=%.2f must be >= 0", InpSLBufferATR));
      return false;
   }
   if(InpMinSLPoints < 1)
   {
      ALog(StringFormat("INIT|FAIL|InpMinSLPoints=%d must be >= 1", InpMinSLPoints));
      return false;
   }
   //--- Exit tuning (V22-infra #5) -----------------------------------//
   if(InpBEAtR < 0.0)
   {
      ALog(StringFormat("INIT|FAIL|InpBEAtR=%.2f must be >= 0 (0 disables break-even)",
                        InpBEAtR));
      return false;
   }
   if(InpBEOffsetPoints < 0)
   {
      ALog(StringFormat("INIT|FAIL|InpBEOffsetPoints=%d must be >= 0", InpBEOffsetPoints));
      return false;
   }
   if(InpTrailStartR < 0.0)
   {
      ALog(StringFormat("INIT|FAIL|InpTrailStartR=%.2f must be >= 0", InpTrailStartR));
      return false;
   }
   if(InpEMAFast < 2 || InpEMASlow < 2 || InpEMAFast >= InpEMASlow)
   {
      ALog(StringFormat("INIT|FAIL|EMA periods invalid: fast=%d slow=%d",
                        InpEMAFast, InpEMASlow));
      return false;
   }
   if(InpATRPeriod < 2)
   {
      ALog(StringFormat("INIT|FAIL|InpATRPeriod=%d must be >= 2", InpATRPeriod));
      return false;
   }
   if(InpADXPeriod < 7)
   {
      ALog(StringFormat("INIT|FAIL|InpADXPeriod=%d must be >= 7", InpADXPeriod));
      return false;
   }
   if(InpMaxTradesPerDay < 1)
   {
      ALog(StringFormat("INIT|FAIL|InpMaxTradesPerDay=%d must be >= 1", InpMaxTradesPerDay));
      return false;
   }
   if(InpDailyLossStopR <= 0.0)
   {
      ALog(StringFormat("INIT|FAIL|InpDailyLossStopR=%.2f must be > 0", InpDailyLossStopR));
      return false;
   }
   if(InpDailyLossPct <= 0.0 || InpDailyLossPct > 10.0)
   {
      ALog(StringFormat("INIT|FAIL|InpDailyLossPct=%.2f must be in (0, 10]", InpDailyLossPct));
      return false;
   }
   if(InpMaxSpread < 1)
   {
      ALog(StringFormat("INIT|FAIL|InpMaxSpread=%d must be >= 1", InpMaxSpread));
      return false;
   }
   if(!(InpTotalDDReduceAt > 0.0 &&
        InpTotalDDReduceAt < InpTotalDDStopAt &&
        InpTotalDDStopAt   < InpTotalDDHardAt))
   {
      ALog(StringFormat("INIT|FAIL|total DD ladder must satisfy 0 < reduce(%.2f) < stop(%.2f) "
                        "< hard(%.2f)", InpTotalDDReduceAt, InpTotalDDStopAt, InpTotalDDHardAt));
      return false;
   }
   if(InpDeviationPoints < 0)
   {
      ALog(StringFormat("INIT|FAIL|InpDeviationPoints=%d must be >= 0", InpDeviationPoints));
      return false;
   }
   if(!InpAllowBuy && !InpAllowSell)
   {
      ALog("INIT|FAIL|both InpAllowBuy and InpAllowSell are false - nothing to trade");
      return false;
   }
   return true;
}

//==================================================================//
//  SECTION 17 - BASELINE GUARD (NEW IN V23)                        //
//==================================================================//
//  This is the guard rail that would have caught the V21/V22 mistake
//  on the FIRST run instead of after two losing backtests.
//
//  It answers one question at the top of the journal: "am I looking at
//  the MT5-verified V20 baseline, or at something else?" If anything
//  deviates it says so explicitly and names every single deviation, so
//  a result can never be mistaken for the baseline again.
//
//  Optional features audited : InpUseRegimeFilter, InpUseTrailing,
//                              InpSkipThursday, InpSkipFriday
//  Core V20 values audited   : knee run / body per side, risk %, RR,
//                              max trades per day
//------------------------------------------------------------------//
void LogBaselineStatus()
{
   //--- 1. Optional features: the V20 baseline has ALL of them off //
   string optDesc[4];
   int    optOn = 0;

   if(InpUseRegimeFilter)
   {
      optDesc[optOn] = StringFormat("InpUseRegimeFilter=true (ADX>=%s) - V20 had NO ADX filter",
                                    DoubleToString(InpADXThreshold, 1));
      optOn++;
   }
   if(InpUseTrailing)
   {
      optDesc[optOn] = StringFormat("InpUseTrailing=true (%sxATR from %sR) - V20 had NO trailing stop",
                                    DoubleToString(InpTrailATR, 1),
                                    DoubleToString(InpTrailStartR, 2));
      optOn++;
   }
   if(InpSkipThursday)
   {
      optDesc[optOn] = "InpSkipThursday=true - V20 had NO weekday filter";
      optOn++;
   }
   if(InpSkipFriday)
   {
      optDesc[optOn] = "InpSkipFriday=true - V20 had NO weekday filter";
      optOn++;
   }

   //--- 2. Core V20 strategy values -----------------------------//
   string coreDesc[7];
   int    coreChanged = 0;

   if(InpKneeMinRunBuy != 2)
   {
      coreDesc[coreChanged] = StringFormat("InpKneeMinRunBuy=%d (V20: 2)", InpKneeMinRunBuy);
      coreChanged++;
   }
   if(MathAbs(InpEntryStrengthBuy - 0.60) > 1e-9)
   {
      coreDesc[coreChanged] = StringFormat("InpEntryStrengthBuy=%s (V20: 0.60)",
                                          DoubleToString(InpEntryStrengthBuy, 2));
      coreChanged++;
   }
   if(InpKneeMinRunSell != 3)
   {
      coreDesc[coreChanged] = StringFormat("InpKneeMinRunSell=%d (V20: 3)", InpKneeMinRunSell);
      coreChanged++;
   }
   if(MathAbs(InpEntryStrengthSell - 0.70) > 1e-9)
   {
      coreDesc[coreChanged] = StringFormat("InpEntryStrengthSell=%s (V20: 0.70)",
                                          DoubleToString(InpEntryStrengthSell, 2));
      coreChanged++;
   }
   if(MathAbs(InpRiskPercent - 0.70) > 1e-9)
   {
      coreDesc[coreChanged] = StringFormat("InpRiskPercent=%s (V20: 0.70)",
                                          DoubleToString(InpRiskPercent, 2));
      coreChanged++;
   }
   if(MathAbs(InpRR - 2.0) > 1e-9)
   {
      coreDesc[coreChanged] = StringFormat("InpRR=%s (V20: 2.00)", DoubleToString(InpRR, 2));
      coreChanged++;
   }
   if(InpMaxTradesPerDay != 4)
   {
      coreDesc[coreChanged] = StringFormat("InpMaxTradesPerDay=%d (V20: 4)", InpMaxTradesPerDay);
      coreChanged++;
   }

   //--- 3. Verdict ----------------------------------------------//
   if(optOn == 0 && coreChanged == 0)
   {
      ALog("BASELINE|OK|pure V20 configuration - expect ~270 trades over Jan-Jul 2026");
      return;
   }

   ALog(StringFormat("BASELINE|MODIFIED|%d optional feature(s) ON, %d core value(s) changed "
                     "- this is NO LONGER the V20 baseline", optOn, coreChanged));

   for(int i = 0; i < optOn; i++)
      ALog("BASELINE|  optional ON   : " + optDesc[i]);
   for(int i = 0; i < coreChanged; i++)
      ALog("BASELINE|  core changed  : " + coreDesc[i]);

   ALog(StringFormat("BASELINE|  reference to beat: %d trades, PF %s, %s, DD %s (MT5-verified V20)",
                     V20_REF_TRADES, DoubleToString(V20_REF_PF, 2),
                     V20_REF_NET_TXT, V20_REF_DD_TXT));

   if(optOn > 1)
      ALog(StringFormat("BASELINE|WARNING %d optional features are ON at the same time - the ledger "
                        "rule is ONE AT A TIME. This run will be uninterpretable.", optOn));
}

//==================================================================//
//  SECTION 18 - MT5 EVENT HANDLERS                                 //
//==================================================================//

//------------------------------------------------------------------//
//| OnInit                                                          |
//------------------------------------------------------------------//
int OnInit()
{
   //--- 1. Input sanity ----------------------------------------//
   if(!ValidateInputs())
      return INIT_FAILED;

   //--- 2. Broker / symbol constraints -------------------------//
   CacheSymbolInfo();

   //--- 3. Indicator handles (all validated) -------------------//
   g_hATR     = iATR(_Symbol, _Period, InpATRPeriod);
   g_hEMAFast = iMA (_Symbol, _Period, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMASlow = iMA (_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_hADX     = iADX(_Symbol, _Period, InpADXPeriod);

   if(g_hATR == INVALID_HANDLE)
   {
      ALog(StringFormat("INIT|FAIL|iATR(%d) handle invalid err=%d", InpATRPeriod, GetLastError()));
      return INIT_FAILED;
   }
   if(g_hEMAFast == INVALID_HANDLE)
   {
      ALog(StringFormat("INIT|FAIL|iMA fast(%d) handle invalid err=%d", InpEMAFast, GetLastError()));
      return INIT_FAILED;
   }
   if(g_hEMASlow == INVALID_HANDLE)
   {
      ALog(StringFormat("INIT|FAIL|iMA slow(%d) handle invalid err=%d", InpEMASlow, GetLastError()));
      return INIT_FAILED;
   }
   if(g_hADX == INVALID_HANDLE)
   {
      ALog(StringFormat("INIT|FAIL|iADX(%d) handle invalid err=%d", InpADXPeriod, GetLastError()));
      return INIT_FAILED;
   }

   //--- 4. Trade object ---------------------------------------//
   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints((ulong)InpDeviationPoints);
   g_trade.SetMarginMode();
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   //--- 5. Runtime state --------------------------------------//
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_initialBalance <= 0.0)
      g_initialBalance = AccountInfoDouble(ACCOUNT_EQUITY);

   g_indBarTime      = 0;
   g_indValid        = false;
   g_adxValid        = false;
   g_hardDDLogged    = false;
   g_lastTradedSetup = 0;
   g_weekdayRejBar   = 0;

   // Drawdown high-water marks start at "no drawdown yet".
   g_minEquity       = AccountInfoDouble(ACCOUNT_EQUITY);
   g_maxStaticDD     = 0.0;
   g_maxDailyDD      = 0.0;

   Disarm("init");

   ResetDaily();
   g_lastBarTime = iTime(_Symbol, _Period, 0);
   SyncPositionState();
   UpdateIndicatorCache();

   //--- 6. Environment warnings (non fatal) -------------------//
   if(_Period != PERIOD_M5)
      ALog(StringFormat("INIT|WARN|running on %s - this strategy was developed and verified "
                        "on M5. Results on other timeframes are untested.",
                        EnumToString((ENUM_TIMEFRAMES)_Period)));

   if(StringFind(_Symbol, "XAU") < 0)
      ALog(StringFormat("INIT|WARN|symbol %s does not look like XAUUSD - the knee/ATR "
                        "constants are tuned for gold.", _Symbol));

   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
      ALog("INIT|WARN|Algo trading is disabled in the terminal - the EA will not send orders.");

   ALog(StringFormat("INIT|OK|CK_XAU_HybridKnee_V23 %s %s magic=%d",
                     _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), (int)InpMagic));
   ALog(StringFormat("INIT|CFG|risk=%.2f%% RR=%.2f BE=%s regime=%s trail=%s",
                     InpRiskPercent, InpRR,
                     (InpUseBreakEven ? "on" : "off"),
                     (InpUseRegimeFilter ? "ON" : "off"),
                     (InpUseTrailing  ? "ON" : "off")));
   ALog(StringFormat("INIT|CFG|exit tuning: BE at %.2fR offset %dpts; trail %.1fxATR arms at %.2fR "
                     "(only when InpUseTrailing=true)",
                     InpBEAtR, InpBEOffsetPoints, InpTrailATR, InpTrailStartR));
   ALog(StringFormat("INIT|CFG|knee buy(run>=%d, body>=%.2f) sell(run>=%d, body>=%.2f) valid=%dbars "
                     "slBuf=%.2fxATR",
                     InpKneeMinRunBuy, InpEntryStrengthBuy,
                     InpKneeMinRunSell, InpEntryStrengthSell,
                     InpValidBars, InpSLBufferATR));
   ALog(StringFormat("INIT|CFG|lots[%.2f..%.2f] compound=%s fixedLot=%s(%.2f) maxTrades/day=%d "
                     "dailyStop=%.2fR/%.2f%% DD ladder %.1f/%.1f/%.1f%%",
                     InpMinLot, InpMaxLot, (InpCompoundLots ? "on" : "off"),
                     (InpUseFixedLot ? "ON" : "off"), InpFixedLot,
                     InpMaxTradesPerDay, InpDailyLossStopR, InpDailyLossPct,
                     InpTotalDDReduceAt, InpTotalDDStopAt, InpTotalDDHardAt));
   ALog(StringFormat("INIT|CFG|maxSpread=%dpts verbose=%s skipThu=%s skipFri=%s adx=%s(>=%.1f)",
                     InpMaxSpread, (InpVerboseLog ? "on" : "off"),
                     (InpSkipThursday ? "ON" : "off"), (InpSkipFriday ? "ON" : "off"),
                     (InpUseRegimeFilter ? "ON" : "off"), InpADXThreshold));
   ALog(StringFormat("INIT|BROKER|digits=%d point=%.5f tick=%.5f volMin=%.2f volStep=%.2f "
                     "stopsLevel=%d bal=%.2f",
                     g_digits, g_point, g_tickSize, g_volMin, g_volStep,
                     (int)g_stopsLevel, g_initialBalance));

   //--- 7. Baseline guard (V23): is this still the V20 config? --//
   LogBaselineStatus();

   return INIT_SUCCEEDED;
}

//------------------------------------------------------------------//
//| OnDeinit - release handles and dump the diagnostics summary     |
//------------------------------------------------------------------//
void OnDeinit(const int reason)
{
   PrintDiagnostics("V23 SESSION SUMMARY");

   if(g_hATR     != INVALID_HANDLE) { IndicatorRelease(g_hATR);     g_hATR     = INVALID_HANDLE; }
   if(g_hEMAFast != INVALID_HANDLE) { IndicatorRelease(g_hEMAFast); g_hEMAFast = INVALID_HANDLE; }
   if(g_hEMASlow != INVALID_HANDLE) { IndicatorRelease(g_hEMASlow); g_hEMASlow = INVALID_HANDLE; }
   if(g_hADX     != INVALID_HANDLE) { IndicatorRelease(g_hADX);     g_hADX     = INVALID_HANDLE; }

   ALog(StringFormat("DEINIT|reason=%d", reason));
}

//------------------------------------------------------------------//
//| OnTick - the exact order of operations demanded by the design:  |
//|   1. daily reset                                                |
//|   2. exit management (break-even, then trailing) - every tick   |
//|   3. new-bar work: expire setup, WEEKDAY gate, regime, scan      |
//|   4. trigger check -> guards -> entry                           |
//|                                                                  |
//|  V22-infra #2: the weekday gate now lives in Phase 3, so no setup is  |
//|  ever ARMED on a blocked weekday and the weekday counter is a   |
//|  bar count instead of a tick count.                              |
//------------------------------------------------------------------//
void OnTick()
{
   //================ PHASE 0: state synchronisation ============//
   SyncPositionState();
   UpdateIndicatorCache();      // no-op after the first tick of a bar

   //================ PHASE 1: daily boundary ===================//
   datetime ds = iTime(_Symbol, PERIOD_D1, 0);
   if(ds > 0 && ds != g_dayStart)
      ResetDaily();

   CheckHardDrawdown();         // also updates the static DD watermarks

   //================ PHASE 2: exit management ==================//
   // Runs on EVERY tick and is completely independent of the entry
   // logic, filters and daily limits: an open trade must always be
   // managed, even on a blocked day or in a ranging regime.
   if(g_hasPosition)
   {
      ManageBreakEven();       // BE first ...
      ManageTrailingStop();    // ... then trail (trail can only improve on BE)
   }

   //================ PHASE 3: new bar work =====================//
   if(IsNewBar())
   {
      //--- 3a. Age the armed setup: exactly one decrement/bar --//
      // Runs before the weekday gate so a setup armed on Wednesday
      // still expires normally over a blacked-out Thursday.
      if(g_setupDirection != 0)
      {
         g_barsRemaining--;
         if(g_barsRemaining <= 0)
         {
            g_setupsExpired++;
            Disarm("validity window expired");
         }
      }

      //--- 3b. Weekday gate at SCAN time (V22-infra #2) -------------//
      // One count and at most one (verbose) log per BAR. Because we
      // never scan on a blocked weekday, nothing can be armed on one
      // either - the silent guard in IsAllowedToTrade() only has to
      // catch a setup that survives the rollover into Thursday.
      bool weekdayOk = IsWeekdayAllowed();
      if(!weekdayOk)
      {
         datetime curBar = iTime(_Symbol, _Period, 0);
         if(curBar != g_weekdayRejBar)
         {
            g_weekdayRejBar = curBar;
            g_rejWeekday++;
            VLog("SCAN|SKIP|Thursday/Friday blackout - no scanning on this bar");
         }
      }

      //--- 3c. Scan only when idle: no position, no armed setup//
      if(weekdayOk && g_setupDirection == 0 && !g_hasPosition)
      {
         if(!g_indValid)
         {
            // Fail-closed: never scan on stale/broken ATR or EMA data.
            VLog("SCAN|SKIP|indicator cache invalid (fail-closed)");
         }
         else if(!RegimeFilter())
         {
            g_rejRegime++;
            VLog(StringFormat("SCAN|SKIP|regime ranging: ADX=%.2f < %.2f",
                              g_adx, InpADXThreshold));
         }
         else
         {
            // Buy is attempted first, then sell (design.md order).
            if(!ScanBuyKnee())
               ScanSellKnee();
         }
      }
   }

   //================ PHASE 4: trigger + guards + entry =========//
   if(g_setupDirection == 0) return;
   if(g_hasPosition)         return;
   if(!IsAllowedToTrade())   return;    // each rejection counted ONCE per setup

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   if(g_setupDirection == 1)
   {
      if(t.ask >= g_triggerPrice)
         OpenBuy();
   }
   else if(g_setupDirection == -1)
   {
      if(t.bid <= g_triggerPrice)
         OpenSell();
   }
}

//------------------------------------------------------------------//
//| OnTradeTransaction                                              |
//|  * accumulates realised P&L per closing deal into the daily     |
//|    tracker that feeds the 1.5R daily loss stop                  |
//|  * accumulates the run-wide win/loss/gross figures the DIAG      |
//|    block reports (V22-infra #10)                                       |
//|  * detects that the EA position is gone so the state flags and   |
//|    the break-even latch reset immediately (not on the next tick) |
//------------------------------------------------------------------//
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest    &request,
                        const MqlTradeResult     &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal != 0)
   {
      if(HistoryDealSelect(trans.deal))
      {
         string dealSym   = HistoryDealGetString (trans.deal, DEAL_SYMBOL);
         long   dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         long   dealEntry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

         if(dealSym == _Symbol && dealMagic == InpMagic &&
            (dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY ||
             dealEntry == DEAL_ENTRY_INOUT))
         {
            double pnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                       + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                       + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

            g_dailyRealizedPnL += pnl;

            //--- Run-wide realized stats (V22-infra #10) ------------//
            if(pnl > 0.0)
            {
               g_realWins++;
               g_grossWin += pnl;
            }
            else if(pnl < 0.0)
            {
               g_realLosses++;
               g_grossLoss += -pnl;
            }
            else
            {
               g_realFlat++;
            }

            double lossR = (g_oneRMoney > 0.0 && g_dailyRealizedPnL < 0.0)
                           ? (-g_dailyRealizedPnL) / g_oneRMoney : 0.0;

            ALog(StringFormat("DEAL|CLOSE|deal=%I64u pnl=%.2f dailyPnL=%.2f (%.2fR) trades=%d/%d "
                              "runW/L=%d/%d",
                              trans.deal, pnl, g_dailyRealizedPnL, lossR,
                              g_tradesToday, InpMaxTradesPerDay,
                              g_realWins, g_realLosses));

            if(!g_dailyLimitHit && lossR >= InpDailyLossStopR)
            {
               g_dailyLimitHit = true;
               ALog(StringFormat("DAILY|LIMIT|%.2fR >= %.2fR - entries blocked for the rest of the day",
                                 lossR, InpDailyLossStopR));
            }
         }
      }
   }

   //--- Position gone? Reset the tracked state right away. -----//
   if(g_hasPosition && FindPositionTicket() == 0)
   {
      VLog(StringFormat("POS|GONE|ticket=%I64u state reset from OnTradeTransaction",
                        g_positionTicket));
      g_hasPosition    = false;
      g_positionTicket = 0;
      g_entryPrice     = 0.0;
      g_initialRisk    = 0.0;
      g_beApplied      = false;
   }
}
//+------------------------------------------------------------------+
//|                          END OF FILE                             |
//+------------------------------------------------------------------+

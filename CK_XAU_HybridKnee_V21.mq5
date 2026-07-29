//+------------------------------------------------------------------+
//|                                    CK_XAU_HybridKnee_V21.mq5     |
//|                                                      CK GFT Fast |
//|------------------------------------------------------------------|
//|  STRATEGY : Hybrid Knee Breakout (XAUUSD / M5)                   |
//|  VERSION  : 21 ("HybridKnee")                                    |
//|                                                                  |
//|  WHAT THIS COMBINES                                              |
//|    1. V20 Knee Breakout entries                                  |
//|         - BUY : >=2 consecutive green bars -> 1 bearish "knee"    |
//|                 bar -> break of the knee HIGH                    |
//|         - SELL: >=3 consecutive red bars  -> 1 bullish "knee"     |
//|                 bar -> break of the knee LOW   (STRICTER)        |
//|         - EMA(21)/EMA(50) trend alignment + knee close vs EMA21   |
//|         - Entry-strength filter on the last run bar (body/range)  |
//|    2. Hybrid exit borrowed from CK_GFT_BEST_Strategy              |
//|         - Fixed TP at RR 2.0 recomputed from the ACTUAL fill      |
//|         - Break-even (SL -> exact entry) once +1R is reached      |
//|         - Trailing stop at 6 x ATR(14), armed only after +1R      |
//|           (lets runners pass the fixed TP and keep going)        |
//|    3. ADX(14) regime filter - blocks new setups in ranging chop,  |
//|       the dominant failure mode found across 105 live trades      |
//|    4. Prop-firm-grade risk controls (Goat Funded Trader 5K,       |
//|       2-Step): 5% daily DD, 10% total DD, 0.05-0.08 lot band,     |
//|       max 4 entries/day, Thu/Fri blackout, single position only   |
//|                                                                  |
//|  KEY INPUTS (defaults are the MT5-verified V21 configuration)     |
//|    InpRiskPercent      0.70   risk per trade, compounded          |
//|    InpRR              2.00    fixed take-profit multiple          |
//|    InpTrailATR        6.00    trailing distance in ATR units      |
//|    InpADXThreshold   20.00    minimum ADX to call it "trending"   |
//|    InpKneeMinRunBuy      2 /  InpKneeMinRunSell        3          |
//|    InpEntryStrengthBuy 0.60 /  InpEntryStrengthSell 0.70          |
//|    InpMaxTradesPerDay    4    InpValidBars                 5      |
//|    InpMinLot / InpMaxLot 0.05 / 0.08 (hard capped at 0.08)        |
//|                                                                  |
//|  RECOMMENDED STRATEGY TESTER SETTINGS                            |
//|    Symbol      : XAUUSD                                          |
//|    Timeframe   : M5                                              |
//|    Modelling   : Every tick based on real ticks                  |
//|    Deposit     : 5000 USD                                        |
//|    Leverage    : 1:100                                           |
//|    Optimisation: off for the baseline run                        |
//|    Journal     : grep for the "V21|" prefix on every log line     |
//|                                                                  |
//|  EVERY toggle below is honoured by the logic, so features can be  |
//|  A/B tested by flipping a single input in the Strategy Tester.    |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property link      ""
#property version   "21.00"
#property strict
#property description "XAUUSD M5 Hybrid Knee Breakout - V20 entries + hybrid exit (TP RR2 / BE 1R / 6xATR trail) + ADX regime filter, prop-firm risk controls."

#include <Trade/Trade.mqh>

//==================================================================//
//  SECTION 1 - INPUTS                                              //
//==================================================================//

//--- Identity -----------------------------------------------------//
input group "=== Identity ==="
input long   InpMagic             = 20260801;   // Magic number (position ownership)

//--- Risk management ----------------------------------------------//
input group "=== Risk Management ==="
input double InpRiskPercent       = 0.70;       // Risk per trade (% of balance) [0.1 - 2.0]
input double InpRR                = 2.0;        // Fixed TP reward:risk multiple  (>= 1.5)
input double InpTrailATR          = 6.0;        // Trailing stop distance in ATR  (>= 3.0)
input int    InpMaxTradesPerDay   = 4;          // Max entries per calendar day
input double InpDailyLossStopR    = 1.5;        // Daily loss stop, expressed in R
input double InpDailyLossPct      = 5.0;        // Daily loss stop, % of day-start balance
input double InpMaxLot            = 0.08;       // Max lot (prop firm cap, never above 0.08)
input double InpMinLot            = 0.05;       // Min lot - smaller sizes REJECT the trade
input bool   InpCompoundLots      = true;       // Grow risk with balance (compound)

//--- Entry logic --------------------------------------------------//
input group "=== Entry Logic (Knee Breakout) ==="
input int    InpKneeMinRunBuy     = 2;          // BUY : min consecutive green bars before knee
input int    InpKneeMinRunSell    = 3;          // SELL: min consecutive red bars before knee
input double InpEntryStrengthBuy  = 0.60;       // BUY : min body/range of last run bar
input double InpEntryStrengthSell = 0.70;       // SELL: min body/range of last run bar
input int    InpValidBars         = 5;          // Setup validity window (bars)
input double InpSLBufferATR       = 0.30;       // SL buffer beyond the knee, in ATR units
input int    InpMinSLPoints       = 5;          // Minimum SL distance (points)
input int    InpLookback          = 12;         // Max bars scanned for the run count

//--- Indicators ---------------------------------------------------//
input group "=== Indicators ==="
input int    InpEMAFast           = 21;         // Fast EMA period
input int    InpEMASlow           = 50;         // Slow EMA period
input int    InpATRPeriod         = 14;         // ATR period
input int    InpADXPeriod         = 14;         // ADX period
input double InpADXThreshold      = 20.0;       // Min ADX to allow new setups [15 - 30]

//--- Filters / feature toggles ------------------------------------//
input group "=== Filters & Toggles ==="
input int    InpMaxSpread         = 50;         // Max spread (points) at entry
input bool   InpUseRegimeFilter   = true;       // Enable ADX regime filter
input bool   InpUseTrailing       = true;       // Enable 6xATR trailing stop
input bool   InpUseBreakEven      = true;       // Enable break-even at +1R
input bool   InpSkipThursday      = true;       // Block new entries on Thursday
input bool   InpSkipFriday        = true;       // Block new entries on Friday
input bool   InpAllowBuy          = true;       // Allow long setups
input bool   InpAllowSell         = true;       // Allow short setups

//--- Total drawdown guard (prop firm) -----------------------------//
input group "=== Total Drawdown Guard ==="
input double InpTotalDDReduceAt   = 8.0;        // Total DD % at which risk is halved
input double InpTotalDDStopAt     = 9.0;        // Total DD % at which entries stop
input double InpTotalDDHardAt     = 10.0;       // Total DD % = hard breach (critical log)

//--- Execution / logging ------------------------------------------//
input group "=== Execution & Logging ==="
input int    InpDeviationPoints   = 30;         // Max slippage (points)
input bool   InpVerboseLog        = true;       // Verbose per-event journal logging

//==================================================================//
//  SECTION 2 - CONSTANTS                                           //
//==================================================================//

// Absolute ceiling enforced by every code path that produces a lot size.
// No input, no compounding factor and no rounding can push a trade above
// this value - it is the prop firm contractual limit.
const double HARD_MAX_LOT = 0.08;

// Journal prefix. Every single Print in this EA starts with it so the
// Strategy Tester journal can be filtered with a plain text search.
#define LOGP "V21|"

// ADX indicator buffer indices (iADX): 0 = main, 1 = +DI, 2 = -DI.
#define ADX_MAIN_BUFFER 0

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

//--- Armed setup state --------------------------------------------//
int      g_setupDirection = 0;    // +1 = buy, -1 = sell, 0 = none
double   g_triggerPrice   = 0.0;
double   g_pendingSL      = 0.0;
int      g_barsRemaining  = 0;
datetime g_setupTime      = 0;    // time of the knee bar that armed the setup
datetime g_lastTradedSetup= 0;    // knee already traded - never re-arm it

//--- Live position state ------------------------------------------//
bool     g_hasPosition    = false;
ulong    g_positionTicket = 0;
double   g_entryPrice     = 0.0;
double   g_initialRisk    = 0.0;  // |entry - original SL|, frozen at fill time
bool     g_beApplied      = false;

//--- Diagnostics counters -----------------------------------------//
int g_cntEntries      = 0;   // positions successfully opened
int g_rejSpread       = 0;   // blocked: spread too wide
int g_rejRegime       = 0;   // blocked: ADX says ranging
int g_rejDailyLimit   = 0;   // blocked: daily loss limit (R or %)
int g_rejWeekday      = 0;   // blocked: Thursday / Friday
int g_rejMaxTrades    = 0;   // blocked: max trades per day
int g_rejPosition     = 0;   // blocked: a position is already open
int g_rejTotalDD      = 0;   // blocked: total drawdown guard
int g_rejLot          = 0;   // blocked: lot size rejected (below minimum)
int g_orderFails      = 0;   // order send / fill lookup failures
int g_setupsArmed     = 0;   // setups armed
int g_setupsExpired   = 0;   // setups that expired unused
int g_indFailures     = 0;   // indicator read failures

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
//------------------------------------------------------------------//
void CheckHardDrawdown()
{
   double dd = TotalDDPercent();
   if(dd >= InpTotalDDHardAt && !g_hardDDLogged)
   {
      g_hardDDLogged = true;
      ALog(StringFormat("CRITICAL|TOTAL DD %.2f%% >= hard limit %.2f%% - trading ceased. "
                        "Manual intervention required.", dd, InpTotalDDHardAt));
   }
}

//------------------------------------------------------------------//
//| Day-of-week filter (both legs individually switchable)          |
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
//  Risk-based sizing with compound growth, a drawdown de-risk step,
//  a hard 0.08 ceiling and a REJECT (not a force-up) below minimum.
//------------------------------------------------------------------//
double CalcLot(const double entryPrice, const double stopPrice, const int direction)
{
   if(entryPrice <= 0.0 || stopPrice <= 0.0) return 0.0;
   if(direction ==  1 && entryPrice <= stopPrice) return 0.0;   // BUY  needs SL below
   if(direction == -1 && stopPrice  <= entryPrice) return 0.0;  // SELL needs SL above

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 0.0;
   if(g_initialBalance <= 0.0) g_initialBalance = balance;

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

   //--- 3. Money lost per 1.00 lot if the stop is hit ------------//
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
   if(lossPerLot <= 0.0)
   {
      ALog("LOT|REJECT|cannot determine loss-per-lot (OrderCalcProfit and fallback failed)");
      return 0.0;
   }

   //--- 4. Raw lots -> floored to the broker volume step ---------//
   double rawLots = riskMoney / lossPerLot;
   double lots    = MathFloor(rawLots / g_volStep) * g_volStep;

   //--- 5. Ceilings (input cap, hard prop cap, broker cap) -------//
   lots = MathMin(lots, InpMaxLot);
   lots = MathMin(lots, HARD_MAX_LOT);
   lots = MathMin(lots, g_volMax);
   lots = MathFloor(lots / g_volStep) * g_volStep;
   lots = NormalizeDouble(lots, g_volDigits);

   //--- 6. Floors: REJECT, never force the size upward ----------//
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
//  Master gate. Each rejection increments its own counter so the
//  OnDeinit summary explains exactly where the trades went.
//------------------------------------------------------------------//
bool IsAllowedToTrade()
{
   //--- Guard 1: spread -----------------------------------------//
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > (long)InpMaxSpread)
   {
      g_rejSpread++;
      VLog(StringFormat("GUARD|SPREAD|%d > max %d - entry blocked, setup stays armed",
                        (int)spread, InpMaxSpread));
      return false;
   }

   //--- Guard 2: daily loss latch --------------------------------//
   // Once a daily limit has been hit it stays hit for the REST of the
   // day (Requirements 1.1 / 14.1), even if a later winner would pull
   // the running P&L back above the threshold.
   if(g_dailyLimitHit)
   {
      g_rejDailyLimit++;
      return false;
   }

   //--- Guard 3: daily loss as % of day-start balance ------------//
   double dailyDD = DailyDDPercent();
   if(dailyDD >= InpDailyLossPct)
   {
      g_rejDailyLimit++;
      if(!g_dailyLimitHit)
      {
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
      g_rejDailyLimit++;
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
      g_rejMaxTrades++;
      VLog(StringFormat("GUARD|MAX_TRADES|%d/%d reached", g_tradesToday, InpMaxTradesPerDay));
      return false;
   }

   //--- Guard 6: single position only ---------------------------//
   if(CountMyPositions() > 0)
   {
      g_rejPosition++;
      VLog("GUARD|POSITION|an EA position is already open");
      return false;
   }

   //--- Guard 7: weekday blackout -------------------------------//
   if(!IsWeekdayAllowed())
   {
      g_rejWeekday++;
      VLog("GUARD|WEEKDAY|Thursday/Friday blackout - entry blocked (setup may expire)");
      return false;
   }

   //--- Guard 8: total drawdown -> stop entering entirely -------//
   double totalDD = TotalDDPercent();
   if(totalDD >= InpTotalDDStopAt)
   {
      g_rejTotalDD++;
      VLog(StringFormat("GUARD|TOTAL_DD|%.2f%% >= %.2f%% - entries stopped",
                        totalDD, InpTotalDDStopAt));
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
}

//==================================================================//
//  SECTION 11 - REGIME FILTER (ADX)                                //
//==================================================================//
//  Returns true when new setups are permitted.
//  Fails OPEN on indicator trouble so a broken ADX feed does not
//  silently switch the strategy off.
//------------------------------------------------------------------//
bool RegimeFilter()
{
   if(!InpUseRegimeFilter) return true;    // feature switched off
   if(!g_adxValid)         return true;    // fail-open
   if(g_adx <= 0.0)        return true;    // fail-open

   return (g_adx >= InpADXThreshold);
}

//==================================================================//
//  SECTION 12 - KNEE PATTERN SCANNERS                              //
//==================================================================//
//  Shift 1 is the most recent CLOSED bar and is always the "knee".
//  Shift 2..InpLookback are the bars of the preceding run.
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
//| Deliberately STRICTER than the buy side (min run 3, body 0.70)  |
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
      g_rejLot++;
      ALog(StringFormat("ORDER|REJECT|lot size rejected (%s entry=%s sl=%s) - setup disarmed",
                        (direction == 1 ? "BUY" : "SELL"),
                        DoubleToString(entryRef, g_digits),
                        DoubleToString(sl, g_digits)));
      Disarm("lot rejected");
      return false;
   }

   //--- Submit the market order (TP applied after the fill) -----//
   string comment = (direction == 1 ? "V21_KNEE_BUY" : "V21_KNEE_SELL");
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
   // cannot drift later when the stop starts moving.
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

//------------------------------------------------------------------//
//| Break-even: move SL to the EXACT entry once +1R is reached.     |
//| Idempotent via g_beApplied. Never touches the TP.               |
//------------------------------------------------------------------//
void ManageBreakEven()
{
   if(!InpUseBreakEven) return;
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

   // The 1R reference is FROZEN at fill time so it cannot drift once
   // the stop has been moved (that would make BE/trail self-feeding).
   double risk = g_initialRisk;
   if(risk <= 0.0) risk = MathAbs(entry - curSL);
   if(risk <= 0.0) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   double minDist = MinStopDistance();
   double newSL   = RoundToTick(entry);       // offset 0 - exact entry

   if(ptype == POSITION_TYPE_BUY)
   {
      if(t.bid < entry + risk) return;        // +1R not reached yet
      if(newSL <= curSL) { g_beApplied = true; return; }   // trail already better
      if(t.bid - newSL < minDist) return;     // broker would refuse

      if(g_trade.PositionModify(tk, newSL, curTP))
      {
         g_beApplied = true;
         ALog(StringFormat("BE|BUY|ticket=%I64u sl %s -> %s (entry; +1R=%s reached)", tk,
                           DoubleToString(curSL, g_digits),
                           DoubleToString(newSL, g_digits),
                           DoubleToString(entry + risk, g_digits)));
      }
      else
      {
         VLog(StringFormat("BE|FAIL|BUY ticket=%I64u rc=%d (%s)", tk,
                           (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
      }
   }
   else if(ptype == POSITION_TYPE_SELL)
   {
      if(t.ask > entry - risk) return;        // +1R not reached yet
      if(curSL > 0.0 && newSL >= curSL) { g_beApplied = true; return; }
      if(newSL - t.ask < minDist) return;

      if(g_trade.PositionModify(tk, newSL, curTP))
      {
         g_beApplied = true;
         ALog(StringFormat("BE|SELL|ticket=%I64u sl %s -> %s (entry; +1R=%s reached)", tk,
                           DoubleToString(curSL, g_digits),
                           DoubleToString(newSL, g_digits),
                           DoubleToString(entry - risk, g_digits)));
      }
      else
      {
         VLog(StringFormat("BE|FAIL|SELL ticket=%I64u rc=%d (%s)", tk,
                           (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
      }
   }
}

//------------------------------------------------------------------//
//| Trailing stop at InpTrailATR x ATR, armed only after +1R.       |
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
      if(t.bid < entry + risk) return;                 // trail not armed yet

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
      if(t.ask > entry - risk) return;                 // trail not armed yet

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
void PrintDiagnostics(const string label)
{
   ALog("================ " + label + " ================");
   ALog(StringFormat("DIAG|Entries taken .............. %d", g_cntEntries));
   ALog(StringFormat("DIAG|Setups armed ............... %d", g_setupsArmed));
   ALog(StringFormat("DIAG|Setups expired unused ...... %d", g_setupsExpired));
   ALog(StringFormat("DIAG|Rejected - spread .......... %d", g_rejSpread));
   ALog(StringFormat("DIAG|Rejected - ADX regime ...... %d", g_rejRegime));
   ALog(StringFormat("DIAG|Rejected - daily limit ..... %d", g_rejDailyLimit));
   ALog(StringFormat("DIAG|Rejected - weekday ......... %d", g_rejWeekday));
   ALog(StringFormat("DIAG|Rejected - max trades/day .. %d", g_rejMaxTrades));
   ALog(StringFormat("DIAG|Rejected - open position ... %d", g_rejPosition));
   ALog(StringFormat("DIAG|Rejected - total DD guard .. %d", g_rejTotalDD));
   ALog(StringFormat("DIAG|Rejected - lot size ........ %d", g_rejLot));
   ALog(StringFormat("DIAG|Order failures ............. %d", g_orderFails));
   ALog(StringFormat("DIAG|Indicator failures ......... %d", g_indFailures));
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
   if(InpKneeMinRunBuy < 2)
   {
      ALog(StringFormat("INIT|FAIL|InpKneeMinRunBuy=%d must be >= 2", InpKneeMinRunBuy));
      return false;
   }
   if(InpKneeMinRunSell < InpKneeMinRunBuy)
   {
      ALog(StringFormat("INIT|FAIL|InpKneeMinRunSell=%d must be >= InpKneeMinRunBuy=%d "
                        "(the sell side must stay the stricter one)",
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
//  SECTION 17 - MT5 EVENT HANDLERS                                 //
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

   ALog(StringFormat("INIT|OK|CK_XAU_HybridKnee_V21 %s %s magic=%d",
                     _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), (int)InpMagic));
   ALog(StringFormat("INIT|CFG|risk=%.2f%% RR=%.2f trail=%.1fxATR BE=%s trail=%s regime=%s(ADX>=%.1f)",
                     InpRiskPercent, InpRR, InpTrailATR,
                     (InpUseBreakEven ? "on" : "off"),
                     (InpUseTrailing  ? "on" : "off"),
                     (InpUseRegimeFilter ? "on" : "off"), InpADXThreshold));
   ALog(StringFormat("INIT|CFG|knee buy(run>=%d, body>=%.2f) sell(run>=%d, body>=%.2f) valid=%dbars "
                     "slBuf=%.2fxATR",
                     InpKneeMinRunBuy, InpEntryStrengthBuy,
                     InpKneeMinRunSell, InpEntryStrengthSell,
                     InpValidBars, InpSLBufferATR));
   ALog(StringFormat("INIT|CFG|lots[%.2f..%.2f] compound=%s maxTrades/day=%d dailyStop=%.2fR/%.2f%% "
                     "DD ladder %.1f/%.1f/%.1f%%",
                     InpMinLot, InpMaxLot, (InpCompoundLots ? "on" : "off"),
                     InpMaxTradesPerDay, InpDailyLossStopR, InpDailyLossPct,
                     InpTotalDDReduceAt, InpTotalDDStopAt, InpTotalDDHardAt));
   ALog(StringFormat("INIT|BROKER|digits=%d point=%.5f tick=%.5f volMin=%.2f volStep=%.2f "
                     "stopsLevel=%d bal=%.2f",
                     g_digits, g_point, g_tickSize, g_volMin, g_volStep,
                     (int)g_stopsLevel, g_initialBalance));

   return INIT_SUCCEEDED;
}

//------------------------------------------------------------------//
//| OnDeinit - release handles and dump the diagnostics summary     |
//------------------------------------------------------------------//
void OnDeinit(const int reason)
{
   PrintDiagnostics("V21 SESSION SUMMARY");

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
//|   3. new-bar work: expire setup, regime check, scan / arm       |
//|   4. trigger check -> guards -> entry                           |
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

   CheckHardDrawdown();

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
      if(g_setupDirection != 0)
      {
         g_barsRemaining--;
         if(g_barsRemaining <= 0)
         {
            g_setupsExpired++;
            Disarm("validity window expired");
         }
      }

      //--- 3b. Scan only when idle: no position, no armed setup//
      if(g_setupDirection == 0 && !g_hasPosition)
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
   if(!IsAllowedToTrade())   return;    // each rejection is counted inside

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

            double lossR = (g_oneRMoney > 0.0 && g_dailyRealizedPnL < 0.0)
                           ? (-g_dailyRealizedPnL) / g_oneRMoney : 0.0;

            ALog(StringFormat("DEAL|CLOSE|deal=%I64u pnl=%.2f dailyPnL=%.2f (%.2fR) trades=%d/%d",
                              trans.deal, pnl, g_dailyRealizedPnL, lossR,
                              g_tradesToday, InpMaxTradesPerDay));

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

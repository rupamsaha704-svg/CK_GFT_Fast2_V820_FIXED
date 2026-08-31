//+------------------------------------------------------------------+
//|                                    CK_XAU_ICT_ChoCh_V2.mq5      |
//|                                                      CK GFT Fast |
//|------------------------------------------------------------------|
//|  STRATEGY : ICT CHoCH + Fibonacci OTE (Multi-TF)                 |
//|  VERSION  : 2.00 - Relaxed Confirmation                          |
//|                                                                  |
//|  Entry  : H1 CHoCH bias -> M15 BOS confirm -> M5 OTE zone       |
//|           (0.618-0.786) + confirmation candle                    |
//|  Exit   : TP1 at 2R (50% close) + TP2 at 3R + BE after TP1      |
//|  Risk   : 1.5% per trade, max lot 0.08, 13% static DD limit     |
//|                                                                  |
//|  Recommended: XAUUSD, M5 chart, Every tick real, $5000, 1:30    |
//|                                                                  |
//|  CHANGES FROM V1 (CK_XAU_ICT_ChoCh_V1.mq5)                      |
//|  ============================================                    |
//|  V1 Backtest Evidence (7 months):                                |
//|    - 307 CHoCH detected, 103 BOS confirmed, 55 OTE zones valid  |
//|    - Only 9 confirmation candles found (16% of valid OTEs)       |
//|    - 11 entries total, 2 wins / 8 losses, PF 0.45               |
//|    - 26 setups rejected for OTE width invalid                    |
//|    - 15+ setups timed out before OTE retrace                     |
//|    - Funnel: 307 -> 103 -> 55 -> 9 -> 11 (massive drop at       |
//|      confirmation stage)                                         |
//|                                                                  |
//|  1. RELAXED CONFIRMATION (Critical Fix):                         |
//|     Old: Required Engulfing/Doji+Follow/Pin Bar (only 16% pass)  |
//|     New: ANY M5 bar that closes in bias direction AND touches    |
//|          the OTE zone (wick or body) counts as confirmation.     |
//|     Toggle: InpStrictConfirmation (false=relaxed, true=V1 mode)  |
//|                                                                  |
//|  2. WIDER OTE ZONE WIDTH:                                        |
//|     MinOTEWidth: $2.0 -> $1.0  (catch tighter structures)       |
//|     MaxOTEWidth: $15.0 -> $25.0 (catch wider swings)            |
//|     Would have saved 26 rejected setups.                         |
//|                                                                  |
//|  3. WIDER SL RANGE:                                              |
//|     MinSL: $5.0 -> $3.0  (allow tighter structural SLs)         |
//|     MaxSL: $15.0 -> $20.0 (allow wider swings)                  |
//|                                                                  |
//|  4. LONGER SETUP TIMEOUT:                                        |
//|     12 H1 bars (12h) -> 24 H1 bars (24h)                        |
//|     Gold often takes 24h to retrace to OTE after BOS.            |
//|                                                                  |
//|  5. OTE ZONE CHECK ON HIGH/LOW (not just close):                 |
//|     If bar's wick touches OTE zone AND closes in bias direction, |
//|     the bar qualifies even if close is not exactly inside zone.  |
//|                                                                  |
//|  6. TRADE COOLDOWN:                                              |
//|     New InpCooldownMinutes=60. After any trade closes, wait      |
//|     60 minutes before next entry. Prevents revenge trading.      |
//|                                                                  |
//|  7. RISK INCREASED:                                              |
//|     1.0% -> 1.5% (still within 13% DD budget @ 3 trades/day)    |
//|     Magnifies P&L for faster signal evaluation on small account. |
//|                                                                  |
//|  MULTI-TIMEFRAME DATA FLOW                                       |
//|    H1 (CopyRates, on new H1 bar):                                |
//|      - Detect Swing Highs/Lows (3-bar fractal)                   |
//|      - Detect CHoCH (bias shift)                                 |
//|      - Mark POI zone (last opposite candle before impulse)       |
//|    M15 (CopyRates, on new M15 bar):                              |
//|      - Detect BOS in bias direction after POI retest             |
//|      - Mark M15 Order Block (body range of opposite candle)      |
//|      - Calculate Fibonacci OTE zone (0.618 - 0.786)              |
//|    M5 (native chart, on new M5 bar):                             |
//|      - Price must touch or close in the OTE zone                 |
//|      - Confirmation candle (relaxed or strict mode)              |
//|      - Entry at close of confirmation candle                     |
//|                                                                  |
//|  STATE MACHINE                                                   |
//|    IDLE -> H1_CHOCH -> WAIT_POI -> M15_BOS -> WAIT_OTE ->        |
//|    POSITION_OPEN -> TP1_HIT -> COMPLETED                         |
//|                                                                  |
//|  All position loops filter on BOTH POSITION_MAGIC AND            |
//|  POSITION_SYMBOL. All prices normalized via tick-rounding.       |
//|  Prefix all logs with "ICT|".                                    |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property link      ""
#property version   "2.00"
#property strict
#property description "XAUUSD M5 ICT CHoCH + Fibonacci OTE Multi-TF Strategy V2 - relaxed confirmation"

#include <Trade/Trade.mqh>

//==================================================================//
//  SECTION 1 - INPUT PARAMETERS                                    //
//==================================================================//

//--- Identity & Risk Management -----------------------------------//
input group "=== Identity & Risk ==="
input long   InpMagicNumber       = 20260801;   // Magic number
input double InpRiskPercent       = 1.5;        // Risk per trade (%) [V1: 1.0]
input double InpMaxLot            = 0.08;       // Maximum lot size
input double InpRR_TP1            = 2.0;        // TP1 risk-reward ratio
input double InpRR_TP2            = 3.0;        // TP2 risk-reward ratio
input int    InpPartialClosePercent = 50;       // Partial close at TP1 (%)
input int    InpMaxTradesPerDay   = 3;          // Max trades per day
input double InpDailyLossPercent  = 4.0;        // Daily loss limit (%)
input double InpStaticDDPercent   = 13.0;       // Static drawdown limit (%)
input int    InpMaxSpreadPoints   = 50;         // Max spread for entry (points)
input int    InpMinHoldSeconds    = 120;        // Minimum hold time (sec)
input double InpSLBufferDollars   = 1.0;        // SL buffer beyond OB ($)
input double InpMinSLDollars      = 3.0;        // Minimum SL distance ($) [V1: 5.0]
input double InpMaxSLDollars      = 20.0;       // Maximum SL distance ($) [V1: 15.0]
input double InpInitialBalance    = 5000.0;     // Initial account balance ($)
input int    InpCooldownMinutes   = 60;         // Minimum minutes between consecutive trades [NEW in V2]

//--- Structure Detection ------------------------------------------//
input group "=== Structure Detection ==="
input int    InpH1SwingBars       = 3;          // H1 swing bars (each side)
input int    InpM15SwingBars      = 2;          // M15 swing bars (each side)
input double InpFibLevelLow       = 0.618;      // OTE lower fib level
input double InpFibLevelHigh      = 0.786;      // OTE upper fib level
input double InpMinOTEWidthDollars = 1.0;       // Min OTE zone width ($) [V1: 2.0]
input double InpMaxOTEWidthDollars = 25.0;      // Max OTE zone width ($) [V1: 15.0]
input int    InpSetupTimeoutH1Bars = 24;        // Setup timeout (H1 bars) [V1: 12]

//--- Confirmation Mode --------------------------------------------//
input group "=== Confirmation Mode ==="
input bool   InpStrictConfirmation = false;     // true = require Engulfing/Doji/PinBar (V1 mode); false = any directional close in OTE zone [NEW in V2]

//--- Optional Filters ---------------------------------------------//
input group "=== Optional Filters ==="
input bool   InpUseEMA200Filter   = false;      // Use EMA 200 trend filter
input int    InpEMA200Period      = 200;        // EMA period
input ENUM_TIMEFRAMES InpEMA200TF = PERIOD_H1;  // EMA timeframe

//--- Execution & Diagnostics --------------------------------------//
input group "=== Execution & Diagnostics ==="
input int    InpDeviationPoints   = 30;         // Max slippage (points)
input bool   InpVerboseLogs       = true;       // Verbose logging

//==================================================================//
//  SECTION 2 - ENUMERATIONS                                        //
//==================================================================//

enum ENUM_BIAS
{
   BIAS_NONE    = 0,
   BIAS_BULLISH = 1,
   BIAS_BEARISH = -1
};

enum ENUM_SETUP_STATE
{
   STATE_IDLE = 0,
   STATE_H1_CHOCH_DETECTED,
   STATE_WAITING_FOR_POI_RETEST,
   STATE_M15_BOS_CONFIRMED,
   STATE_WAITING_FOR_OTE_ENTRY,
   STATE_POSITION_OPEN,
   STATE_TP1_HIT,
   STATE_DISABLED
};

enum ENUM_CANDLE_PATTERN
{
   PATTERN_NONE = 0,
   PATTERN_BULLISH_ENGULFING,
   PATTERN_BEARISH_ENGULFING,
   PATTERN_DOJI_FOLLOW,
   PATTERN_PIN_BAR,
   PATTERN_DIRECTIONAL_CLOSE     // V2: any bar closing in bias direction touching OTE zone
};

//==================================================================//
//  SECTION 3 - DATA STRUCTURES                                     //
//==================================================================//

struct SwingPoint
{
   double   price;        // High for swing high, Low for swing low
   datetime time;         // Time of the swing bar
   int      bar_index;    // Bar index at detection time
   bool     is_high;      // true = swing high, false = swing low
   bool     valid;        // Has been populated
};

struct CHoCH_Event
{
   ENUM_BIAS   direction;        // New bias direction after CHoCH
   double      swing_broken;     // Price level of broken swing
   datetime    time;             // Detection timestamp
   double      poi_high;         // POI zone upper boundary
   double      poi_low;          // POI zone lower boundary
   bool        valid;            // Currently active
   int         h1_bars_since;    // H1 bars since detection (for timeout)
};

struct BOS_Event
{
   ENUM_BIAS   direction;        // BOS direction (matches H1 bias)
   double      ob_high;          // M15 Order Block upper boundary
   double      ob_low;           // M15 Order Block lower boundary
   double      swing_high_used;  // M15 swing high price
   double      swing_low_used;   // M15 swing low price
   datetime    time;             // Detection time
   datetime    expiry;           // Timeout (24 H1 bars from detection)
   bool        valid;
};

struct OTE_Zone
{
   double fib_618;        // 61.8% retracement level
   double fib_705;        // 70.5% retracement level (midpoint reference)
   double fib_786;        // 78.6% retracement level
   double zone_high;      // Upper boundary of entry zone
   double zone_low;       // Lower boundary of entry zone
   double swing_high;     // Source swing high
   double swing_low;      // Source swing low
   bool   valid;
};

struct TradeSetup
{
   ENUM_BIAS            direction;
   ENUM_CANDLE_PATTERN  pattern;
   double               entry_price;
   double               stop_loss;
   double               tp1;
   double               tp2;
   double               lot_size;
   double               risk_money;
   double               sl_distance_pts;
};

//==================================================================//
//  SECTION 4 - GLOBAL STATE                                        //
//==================================================================//

// Journal prefix
#define LOGP "ICT|"

CTrade g_trade;

//--- Symbol / broker constraints (cached once in OnInit) ----------//
int    g_digits     = 2;
double g_point      = 0.01;
double g_tickSize   = 0.01;
double g_lotMin     = 0.01;
double g_lotMax     = 100.0;
double g_lotStep    = 0.01;
int    g_lotDigits  = 2;

//--- EMA 200 indicator handle -------------------------------------//
int    g_hEMA200    = INVALID_HANDLE;

//--- New bar tracking per timeframe -------------------------------//
datetime g_lastM5Time  = 0;
datetime g_lastM15Time = 0;
datetime g_lastH1Time  = 0;

//--- State machine ------------------------------------------------//
ENUM_SETUP_STATE g_state = STATE_IDLE;

//--- H1 structural data -------------------------------------------//
CHoCH_Event  g_choch;
ENUM_BIAS    g_priorTrend = BIAS_NONE;
SwingPoint   g_h1_lastSH;
SwingPoint   g_h1_lastSL;
SwingPoint   g_h1_prevSH;   // Previous SH for trend detection
SwingPoint   g_h1_prevSL;   // Previous SL for trend detection

//--- M15 structural data ------------------------------------------//
BOS_Event    g_bos;
SwingPoint   g_m15_lastSH;
SwingPoint   g_m15_lastSL;
bool         g_poiTested = false;  // Price has retraced into H1 POI zone

//--- OTE zone data ------------------------------------------------//
OTE_Zone     g_ote;

//--- Position management ------------------------------------------//
bool         g_tp1Hit        = false;
ulong        g_positionTicket = 0;
double       g_posEntryPrice = 0.0;
double       g_posInitialSL  = 0.0;
double       g_posTP1        = 0.0;
double       g_posTP2        = 0.0;
double       g_posInitialLot = 0.0;

//--- Cooldown tracking (V2) ---------------------------------------//
datetime     g_lastTradeCloseTime = 0;   // Timestamp of last trade close

//--- Risk control -------------------------------------------------//
bool         g_ddTriggered        = false;
bool         g_dailyLossTriggered = false;
datetime     g_dayStart           = 0;
double       g_dayStartBalance    = 0.0;
int          g_tradesToday        = 0;

//--- Diagnostics --------------------------------------------------//
int g_cntEntries       = 0;
int g_cntEntriesBuy    = 0;
int g_cntEntriesSell   = 0;
int g_cntChoch         = 0;
int g_cntBos           = 0;
int g_cntOTEValid      = 0;
int g_cntConfirmations = 0;
int g_rejSpread        = 0;
int g_rejMargin        = 0;
int g_rejDailyLimit    = 0;
int g_rejMaxTrades     = 0;
int g_rejPosition      = 0;
int g_rejTotalDD       = 0;
int g_rejLot           = 0;
int g_rejSLTooWide     = 0;
int g_rejOTEWidth      = 0;
int g_rejSetupInvalid  = 0;
int g_rejCooldown      = 0;   // V2: cooldown rejections
int g_cntInvalidations = 0;
int g_cntTimeouts      = 0;
int g_cntTP1           = 0;
int g_cntTP2           = 0;
int g_cntBE            = 0;
int g_orderFails       = 0;

//==================================================================//
//  SECTION 5 - UTILITY FUNCTIONS                                   //
//==================================================================//

//------------------------------------------------------------------//
//| Always-on log                                                    |
//------------------------------------------------------------------//
void LogMsg(const string tag, const string msg)
{
   Print(LOGP + tag + "|" + msg);
}

//------------------------------------------------------------------//
//| Verbose log - gated behind InpVerboseLogs                        |
//------------------------------------------------------------------//
void VLog(const string tag, const string msg)
{
   if(InpVerboseLogs)
      Print(LOGP + tag + "|" + msg);
}

//------------------------------------------------------------------//
//| Effective tick size (falls back to point if broker lies)         |
//------------------------------------------------------------------//
double TickSizeSafe()
{
   if(g_tickSize > 0.0) return g_tickSize;
   if(g_point    > 0.0) return g_point;
   return 0.01;
}

//------------------------------------------------------------------//
//| Round a price to the nearest valid tick                          |
//------------------------------------------------------------------//
double RoundToTick(const double price)
{
   double ts = TickSizeSafe();
   return NormalizeDouble(MathRound(price / ts) * ts, g_digits);
}

//------------------------------------------------------------------//
//| Round a price DOWN to a valid tick                               |
//------------------------------------------------------------------//
double FloorToTick(const double price)
{
   double ts = TickSizeSafe();
   return NormalizeDouble(MathFloor(price / ts) * ts, g_digits);
}

//------------------------------------------------------------------//
//| Round a price UP to a valid tick                                 |
//------------------------------------------------------------------//
double CeilToTick(const double price)
{
   double ts = TickSizeSafe();
   return NormalizeDouble(MathCeil(price / ts) * ts, g_digits);
}

//------------------------------------------------------------------//
//| Number of decimals implied by the volume step                    |
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
//| Cache all broker constraints once                                |
//------------------------------------------------------------------//
void CacheSymbolInfo()
{
   g_digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_lotMin   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_lotMax   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(g_point    <= 0.0) g_point    = 0.01;
   if(g_tickSize <= 0.0) g_tickSize = g_point;
   if(g_lotStep  <= 0.0) g_lotStep  = 0.01;
   if(g_lotMin   <= 0.0) g_lotMin   = g_lotStep;
   if(g_lotMax   <= 0.0) g_lotMax   = 100.0;

   g_lotDigits = VolumeDigitsFromStep(g_lotStep);
}

//------------------------------------------------------------------//
//| State transition with logging                                    |
//------------------------------------------------------------------//
void TransitionState(ENUM_SETUP_STATE new_state, string reason)
{
   LogMsg("STATE", StringFormat("%s -> %s | %s",
          EnumToString(g_state), EnumToString(new_state), reason));
   g_state = new_state;
}

//------------------------------------------------------------------//
//| Invalidate entire setup and return to IDLE                       |
//------------------------------------------------------------------//
void InvalidateSetup(string reason)
{
   if(g_state == STATE_POSITION_OPEN || g_state == STATE_TP1_HIT ||
      g_state == STATE_DISABLED || g_state == STATE_IDLE)
      return;

   g_choch.valid = false;
   g_bos.valid   = false;
   g_ote.valid   = false;
   g_poiTested   = false;
   g_cntInvalidations++;
   TransitionState(STATE_IDLE, "Invalidated: " + reason);
   LogMsg("INVALIDATE", reason);
}

//------------------------------------------------------------------//
//| Convert state enum to readable string                            |
//------------------------------------------------------------------//
string BiasToString(ENUM_BIAS b)
{
   if(b == BIAS_BULLISH) return "BULLISH";
   if(b == BIAS_BEARISH) return "BEARISH";
   return "NONE";
}

string PatternToString(ENUM_CANDLE_PATTERN p)
{
   switch(p)
   {
      case PATTERN_BULLISH_ENGULFING:  return "BullEngulf";
      case PATTERN_BEARISH_ENGULFING:  return "BearEngulf";
      case PATTERN_DOJI_FOLLOW:        return "DojiFollow";
      case PATTERN_PIN_BAR:            return "PinBar";
      case PATTERN_DIRECTIONAL_CLOSE:  return "DirClose";
      default:                         return "None";
   }
}

//==================================================================//
//  SECTION 6 - NEW BAR DETECTION                                   //
//==================================================================//

//------------------------------------------------------------------//
//| True on new M5 bar (native chart timeframe)                     |
//------------------------------------------------------------------//
bool IsNewM5Bar()
{
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t <= 0) return false;
   if(t != g_lastM5Time)
   {
      g_lastM5Time = t;
      return true;
   }
   return false;
}

//------------------------------------------------------------------//
//| True on new M15 bar                                             |
//------------------------------------------------------------------//
bool IsNewM15Bar()
{
   datetime t = iTime(_Symbol, PERIOD_M15, 0);
   if(t <= 0) return false;
   if(t != g_lastM15Time)
   {
      g_lastM15Time = t;
      return true;
   }
   return false;
}

//------------------------------------------------------------------//
//| True on new H1 bar                                              |
//------------------------------------------------------------------//
bool IsNewH1Bar()
{
   datetime t = iTime(_Symbol, PERIOD_H1, 0);
   if(t <= 0) return false;
   if(t != g_lastH1Time)
   {
      g_lastH1Time = t;
      return true;
   }
   return false;
}

//==================================================================//
//  SECTION 7 - SWING DETECTION                                     //
//==================================================================//

//------------------------------------------------------------------//
//| Fractal-based swing high detection                              |
//| bar[index] High must be > High of all bars_required bars on     |
//| each side.                                                       |
//------------------------------------------------------------------//
bool IsSwingHigh(const MqlRates &bars[], int index, int bars_required, int total)
{
   if(index < bars_required || index + bars_required >= total)
      return false;

   double pivot = bars[index].high;
   for(int i = 1; i <= bars_required; i++)
   {
      if(bars[index - i].high >= pivot) return false;  // left side
      if(bars[index + i].high >= pivot) return false;  // right side
   }
   return true;
}

//------------------------------------------------------------------//
//| Fractal-based swing low detection                               |
//------------------------------------------------------------------//
bool IsSwingLow(const MqlRates &bars[], int index, int bars_required, int total)
{
   if(index < bars_required || index + bars_required >= total)
      return false;

   double pivot = bars[index].low;
   for(int i = 1; i <= bars_required; i++)
   {
      if(bars[index - i].low <= pivot) return false;
      if(bars[index + i].low <= pivot) return false;
   }
   return true;
}

//==================================================================//
//  SECTION 8 - H1 ANALYSIS (CHoCH Detection)                      //
//==================================================================//

//------------------------------------------------------------------//
//| Find POI zone: last opposite-color candle before impulse        |
//| For Bullish CHoCH: find last bearish candle (POI = Open to Low) |
//| For Bearish CHoCH: find last bullish candle (POI = High to Open)|
//------------------------------------------------------------------//
void FindPOI(const MqlRates &bars[], int impulse_start_idx, int total,
             bool find_bullish_candle, double &poi_high, double &poi_low)
{
   poi_high = 0.0;
   poi_low  = 0.0;

   for(int i = impulse_start_idx; i < total - 1; i++)
   {
      bool is_bullish = (bars[i].close > bars[i].open);

      if(find_bullish_candle && is_bullish)
      {
         // Bearish CHoCH: POI = last bullish candle (High to Open)
         poi_high = bars[i].high;
         poi_low  = bars[i].open;
         return;
      }
      else if(!find_bullish_candle && !is_bullish)
      {
         // Bullish CHoCH: POI = last bearish candle (Open to Low)
         poi_high = bars[i].open;
         poi_low  = bars[i].low;
         return;
      }
   }
}

//------------------------------------------------------------------//
//| Full H1 structural analysis: swing detection + CHoCH + POI      |
//------------------------------------------------------------------//
void AnalyzeH1Structure()
{
   MqlRates h1_bars[];
   ArraySetAsSeries(h1_bars, true);

   int copied = CopyRates(_Symbol, PERIOD_H1, 0, 250, h1_bars);
   if(copied < 50)
   {
      LogMsg("H1", StringFormat("CopyRates failed or insufficient data: %d bars", copied));
      return;
   }

   //--- Scan for swing highs and lows (on confirmed bars) -------//
   // We start from index bars_required so we have left+right context
   // Index 0 is current (forming) bar, so start from InpH1SwingBars
   SwingPoint foundSH, foundSL;
   foundSH.valid = false;
   foundSL.valid = false;

   // Find the two most recent swing highs and swing lows
   SwingPoint sh1, sh2, sl1, sl2;
   sh1.valid = false; sh2.valid = false;
   sl1.valid = false; sl2.valid = false;

   for(int i = InpH1SwingBars; i < copied - InpH1SwingBars; i++)
   {
      if(IsSwingHigh(h1_bars, i, InpH1SwingBars, copied))
      {
         if(!sh1.valid)
         {
            sh1.price = h1_bars[i].high;
            sh1.time  = h1_bars[i].time;
            sh1.bar_index = i;
            sh1.is_high = true;
            sh1.valid = true;
         }
         else if(!sh2.valid)
         {
            sh2.price = h1_bars[i].high;
            sh2.time  = h1_bars[i].time;
            sh2.bar_index = i;
            sh2.is_high = true;
            sh2.valid = true;
         }
      }

      if(IsSwingLow(h1_bars, i, InpH1SwingBars, copied))
      {
         if(!sl1.valid)
         {
            sl1.price = h1_bars[i].low;
            sl1.time  = h1_bars[i].time;
            sl1.bar_index = i;
            sl1.is_high = false;
            sl1.valid = true;
         }
         else if(!sl2.valid)
         {
            sl2.price = h1_bars[i].low;
            sl2.time  = h1_bars[i].time;
            sl2.bar_index = i;
            sl2.is_high = false;
            sl2.valid = true;
         }
      }

      // Stop once we have 2 of each
      if(sh2.valid && sl2.valid) break;
   }

   // Update global swing points
   if(sh1.valid) g_h1_lastSH = sh1;
   if(sl1.valid) g_h1_lastSL = sl1;
   if(sh2.valid) g_h1_prevSH = sh2;
   if(sl2.valid) g_h1_prevSL = sl2;

   VLog("H1", StringFormat("Swings: SH1=%s @%s, SL1=%s @%s, SH2=%s, SL2=%s",
        (sh1.valid ? DoubleToString(sh1.price, g_digits) : "none"),
        (sh1.valid ? TimeToString(sh1.time, TIME_DATE|TIME_MINUTES) : ""),
        (sl1.valid ? DoubleToString(sl1.price, g_digits) : "none"),
        (sl1.valid ? TimeToString(sl1.time, TIME_DATE|TIME_MINUTES) : ""),
        (sh2.valid ? DoubleToString(sh2.price, g_digits) : "none"),
        (sl2.valid ? DoubleToString(sl2.price, g_digits) : "none")));

   //--- Determine prior trend from swing relationships ----------//
   // Bullish: higher highs AND higher lows
   // Bearish: lower highs AND lower lows
   if(sh1.valid && sh2.valid && sl1.valid && sl2.valid)
   {
      if(sh1.price > sh2.price && sl1.price > sl2.price)
         g_priorTrend = BIAS_BULLISH;
      else if(sh1.price < sh2.price && sl1.price < sl2.price)
         g_priorTrend = BIAS_BEARISH;
      // else mixed = keep previous trend assessment
   }

   //--- CHoCH detection: close breaks swing against prevailing trend //
   // Use the most recently completed H1 bar (index 1, since 0 is forming)
   if(copied < 2) return;
   double close_price = h1_bars[1].close;

   // Bearish CHoCH: in bullish trend, close breaks below last swing low
   if(g_priorTrend == BIAS_BULLISH && sl1.valid && close_price < sl1.price)
   {
      // Check if this is an opposing CHoCH to current bias
      if(g_choch.valid && g_choch.direction == BIAS_BULLISH)
      {
         // Opposing CHoCH detected - invalidate pending setup
         InvalidateSetup("Opposing H1 CHoCH (now Bearish)");
      }

      g_choch.direction    = BIAS_BEARISH;
      g_choch.swing_broken = sl1.price;
      g_choch.time         = h1_bars[1].time;
      g_choch.h1_bars_since = 0;

      // POI = last bullish candle before the bearish impulse
      FindPOI(h1_bars, sl1.bar_index, copied, true, g_choch.poi_high, g_choch.poi_low);
      g_choch.valid = true;

      g_poiTested = false;
      g_bos.valid = false;
      g_ote.valid = false;
      g_cntChoch++;

      LogMsg("CHOCH", StringFormat("BEARISH | broken SL=%s | POI=[%s - %s] | time=%s",
             DoubleToString(sl1.price, g_digits),
             DoubleToString(g_choch.poi_low, g_digits),
             DoubleToString(g_choch.poi_high, g_digits),
             TimeToString(g_choch.time, TIME_DATE|TIME_MINUTES)));

      if(g_state == STATE_IDLE || g_state == STATE_H1_CHOCH_DETECTED ||
         g_state == STATE_WAITING_FOR_POI_RETEST || g_state == STATE_M15_BOS_CONFIRMED ||
         g_state == STATE_WAITING_FOR_OTE_ENTRY)
      {
         TransitionState(STATE_H1_CHOCH_DETECTED, "Bearish CHoCH detected");
      }
   }
   // Bullish CHoCH: in bearish trend, close breaks above last swing high
   else if(g_priorTrend == BIAS_BEARISH && sh1.valid && close_price > sh1.price)
   {
      // Check if this is an opposing CHoCH to current bias
      if(g_choch.valid && g_choch.direction == BIAS_BEARISH)
      {
         InvalidateSetup("Opposing H1 CHoCH (now Bullish)");
      }

      g_choch.direction    = BIAS_BULLISH;
      g_choch.swing_broken = sh1.price;
      g_choch.time         = h1_bars[1].time;
      g_choch.h1_bars_since = 0;

      // POI = last bearish candle before the bullish impulse
      FindPOI(h1_bars, sh1.bar_index, copied, false, g_choch.poi_high, g_choch.poi_low);
      g_choch.valid = true;

      g_poiTested = false;
      g_bos.valid = false;
      g_ote.valid = false;
      g_cntChoch++;

      LogMsg("CHOCH", StringFormat("BULLISH | broken SH=%s | POI=[%s - %s] | time=%s",
             DoubleToString(sh1.price, g_digits),
             DoubleToString(g_choch.poi_low, g_digits),
             DoubleToString(g_choch.poi_high, g_digits),
             TimeToString(g_choch.time, TIME_DATE|TIME_MINUTES)));

      if(g_state == STATE_IDLE || g_state == STATE_H1_CHOCH_DETECTED ||
         g_state == STATE_WAITING_FOR_POI_RETEST || g_state == STATE_M15_BOS_CONFIRMED ||
         g_state == STATE_WAITING_FOR_OTE_ENTRY)
      {
         TransitionState(STATE_H1_CHOCH_DETECTED, "Bullish CHoCH detected");
      }
   }

   //--- Increment H1 bars since CHoCH for timeout tracking -------//
   if(g_choch.valid)
      g_choch.h1_bars_since++;
}

//==================================================================//
//  SECTION 9 - M15 ANALYSIS (BOS Detection + OTE Calculation)      //
//==================================================================//

//------------------------------------------------------------------//
//| Check if price is in or near the H1 POI zone                    |
//------------------------------------------------------------------//
bool PriceInPOIZone(double bar_low, double bar_high, double poi_high, double poi_low)
{
   // Price is "in or near" POI if any part of the candle touches zone
   // or is within 50 points of the zone boundary
   double buffer = 50 * g_point;
   return (bar_low <= poi_high + buffer && bar_high >= poi_low - buffer);
}

//------------------------------------------------------------------//
//| Find M15 Order Block: last opposite candle before BOS impulse   |
//------------------------------------------------------------------//
void FindM15OrderBlock(const MqlRates &bars[], int impulse_idx, int total,
                       bool find_bullish, double &ob_high, double &ob_low)
{
   ob_high = 0.0;
   ob_low  = 0.0;

   for(int i = impulse_idx; i < total - 1; i++)
   {
      bool is_bullish = (bars[i].close > bars[i].open);
      if(find_bullish == is_bullish)
      {
         // Order Block = body range (Open to Close)
         ob_high = MathMax(bars[i].open, bars[i].close);
         ob_low  = MathMin(bars[i].open, bars[i].close);
         return;
      }
   }
}

//------------------------------------------------------------------//
//| Calculate Fibonacci OTE zone from BOS swing                      |
//------------------------------------------------------------------//
bool CalculateOTE(ENUM_BIAS direction, double swing_high, double swing_low)
{
   double range = swing_high - swing_low;
   if(range <= 0.0)
   {
      VLog("OTE", "Range is zero or negative - cannot calculate OTE");
      return false;
   }

   if(direction == BIAS_BULLISH)
   {
      // Retracement from high downward: level = high - range * ratio
      g_ote.fib_618 = swing_high - range * InpFibLevelLow;
      g_ote.fib_705 = swing_high - range * 0.705;
      g_ote.fib_786 = swing_high - range * InpFibLevelHigh;
      g_ote.zone_high = g_ote.fib_618;  // Shallowest (higher price for buy)
      g_ote.zone_low  = g_ote.fib_786;  // Deepest (lower price for buy)
   }
   else // BIAS_BEARISH
   {
      // Retracement from low upward: level = low + range * ratio
      g_ote.fib_618 = swing_low + range * InpFibLevelLow;
      g_ote.fib_705 = swing_low + range * 0.705;
      g_ote.fib_786 = swing_low + range * InpFibLevelHigh;
      g_ote.zone_low  = g_ote.fib_618;  // Shallowest (lower price for sell)
      g_ote.zone_high = g_ote.fib_786;  // Deepest (higher price for sell)
   }

   g_ote.swing_high = swing_high;
   g_ote.swing_low  = swing_low;

   // Validate zone width in dollars
   double width_dollars = (g_ote.zone_high - g_ote.zone_low);
   if(width_dollars < InpMinOTEWidthDollars)
   {
      LogMsg("REJECT", StringFormat("OTE zone too narrow: $%.2f < $%.2f min",
             width_dollars, InpMinOTEWidthDollars));
      g_ote.valid = false;
      g_rejOTEWidth++;
      return false;
   }
   if(width_dollars > InpMaxOTEWidthDollars)
   {
      LogMsg("REJECT", StringFormat("OTE zone too wide: $%.2f > $%.2f max",
             width_dollars, InpMaxOTEWidthDollars));
      g_ote.valid = false;
      g_rejOTEWidth++;
      return false;
   }

   g_ote.valid = true;
   g_cntOTEValid++;

   LogMsg("OTE", StringFormat("%s | zone=[%s - %s] width=$%.2f | fib618=%s fib786=%s | swing=[%s - %s]",
          BiasToString(direction),
          DoubleToString(g_ote.zone_low, g_digits),
          DoubleToString(g_ote.zone_high, g_digits),
          width_dollars,
          DoubleToString(g_ote.fib_618, g_digits),
          DoubleToString(g_ote.fib_786, g_digits),
          DoubleToString(swing_low, g_digits),
          DoubleToString(swing_high, g_digits)));

   return true;
}

//------------------------------------------------------------------//
//| Full M15 structural analysis: BOS detection + OTE calc          |
//------------------------------------------------------------------//
void AnalyzeM15Structure()
{
   // Preconditions: H1 bias must be active
   if(!g_choch.valid) return;
   if(g_state != STATE_H1_CHOCH_DETECTED &&
      g_state != STATE_WAITING_FOR_POI_RETEST &&
      g_state != STATE_M15_BOS_CONFIRMED)
      return;

   MqlRates m15_bars[];
   ArraySetAsSeries(m15_bars, true);

   int copied = CopyRates(_Symbol, PERIOD_M15, 0, 100, m15_bars);
   if(copied < 20)
   {
      LogMsg("M15", StringFormat("CopyRates failed or insufficient data: %d bars", copied));
      return;
   }

   //--- Check if price has retraced into H1 POI zone -----------//
   if(!g_poiTested)
   {
      for(int i = 0; i < MathMin(12, copied); i++)
      {
         if(PriceInPOIZone(m15_bars[i].low, m15_bars[i].high,
                           g_choch.poi_high, g_choch.poi_low))
         {
            g_poiTested = true;
            VLog("M15", "Price retraced into H1 POI zone");

            if(g_state == STATE_H1_CHOCH_DETECTED)
               TransitionState(STATE_WAITING_FOR_POI_RETEST, "Price entered POI zone");
            break;
         }
      }
   }

   // Must have POI tested to look for BOS
   if(!g_poiTested) return;
   if(g_state != STATE_WAITING_FOR_POI_RETEST) return;

   //--- Scan for M15 swing highs and lows ----------------------//
   SwingPoint m15_sh, m15_sl;
   m15_sh.valid = false;
   m15_sl.valid = false;

   for(int i = InpM15SwingBars; i < copied - InpM15SwingBars; i++)
   {
      if(!m15_sh.valid && IsSwingHigh(m15_bars, i, InpM15SwingBars, copied))
      {
         m15_sh.price     = m15_bars[i].high;
         m15_sh.time      = m15_bars[i].time;
         m15_sh.bar_index = i;
         m15_sh.is_high   = true;
         m15_sh.valid     = true;
      }
      if(!m15_sl.valid && IsSwingLow(m15_bars, i, InpM15SwingBars, copied))
      {
         m15_sl.price     = m15_bars[i].low;
         m15_sl.time      = m15_bars[i].time;
         m15_sl.bar_index = i;
         m15_sl.is_high   = false;
         m15_sl.valid     = true;
      }
      if(m15_sh.valid && m15_sl.valid) break;
   }

   if(m15_sh.valid) g_m15_lastSH = m15_sh;
   if(m15_sl.valid) g_m15_lastSL = m15_sl;

   VLog("M15", StringFormat("Swings: SH=%s @%s, SL=%s @%s",
        (m15_sh.valid ? DoubleToString(m15_sh.price, g_digits) : "none"),
        (m15_sh.valid ? TimeToString(m15_sh.time, TIME_DATE|TIME_MINUTES) : ""),
        (m15_sl.valid ? DoubleToString(m15_sl.price, g_digits) : "none"),
        (m15_sl.valid ? TimeToString(m15_sl.time, TIME_DATE|TIME_MINUTES) : "")));

   //--- BOS detection: close breaks M15 swing in bias direction --//
   double close_price = m15_bars[1].close;  // Last completed M15 bar

   if(g_choch.direction == BIAS_BULLISH && m15_sh.valid && close_price > m15_sh.price)
   {
      g_bos.direction       = BIAS_BULLISH;
      g_bos.swing_high_used = m15_sh.price;
      g_bos.swing_low_used  = (m15_sl.valid ? m15_sl.price : m15_bars[m15_sh.bar_index].low);
      g_bos.time            = m15_bars[1].time;
      g_bos.expiry          = g_bos.time + InpSetupTimeoutH1Bars * PeriodSeconds(PERIOD_H1);

      // Order Block = last bearish candle before bullish impulse
      FindM15OrderBlock(m15_bars, m15_sh.bar_index, copied, false, g_bos.ob_high, g_bos.ob_low);
      g_bos.valid = true;
      g_cntBos++;

      LogMsg("BOS", StringFormat("BULLISH | OB=[%s - %s] | swingH=%s swingL=%s | time=%s",
             DoubleToString(g_bos.ob_high, g_digits),
             DoubleToString(g_bos.ob_low, g_digits),
             DoubleToString(g_bos.swing_high_used, g_digits),
             DoubleToString(g_bos.swing_low_used, g_digits),
             TimeToString(g_bos.time, TIME_DATE|TIME_MINUTES)));

      TransitionState(STATE_M15_BOS_CONFIRMED, "Bullish BOS confirmed");

      // Calculate OTE from the BOS swing
      double ote_swing_high = m15_sh.price;  // The swing high that was broken
      double ote_swing_low  = (m15_sl.valid ? m15_sl.price : m15_bars[m15_sh.bar_index].low);

      // For bullish BOS, fib from the swing that caused BOS (high to low)
      if(CalculateOTE(BIAS_BULLISH, ote_swing_high, ote_swing_low))
      {
         TransitionState(STATE_WAITING_FOR_OTE_ENTRY, "OTE zone calculated and valid");
      }
      else
      {
         InvalidateSetup("OTE zone invalid (width out of range)");
      }
   }
   else if(g_choch.direction == BIAS_BEARISH && m15_sl.valid && close_price < m15_sl.price)
   {
      g_bos.direction       = BIAS_BEARISH;
      g_bos.swing_high_used = (m15_sh.valid ? m15_sh.price : m15_bars[m15_sl.bar_index].high);
      g_bos.swing_low_used  = m15_sl.price;
      g_bos.time            = m15_bars[1].time;
      g_bos.expiry          = g_bos.time + InpSetupTimeoutH1Bars * PeriodSeconds(PERIOD_H1);

      // Order Block = last bullish candle before bearish impulse
      FindM15OrderBlock(m15_bars, m15_sl.bar_index, copied, true, g_bos.ob_high, g_bos.ob_low);
      g_bos.valid = true;
      g_cntBos++;

      LogMsg("BOS", StringFormat("BEARISH | OB=[%s - %s] | swingH=%s swingL=%s | time=%s",
             DoubleToString(g_bos.ob_high, g_digits),
             DoubleToString(g_bos.ob_low, g_digits),
             DoubleToString(g_bos.swing_high_used, g_digits),
             DoubleToString(g_bos.swing_low_used, g_digits),
             TimeToString(g_bos.time, TIME_DATE|TIME_MINUTES)));

      TransitionState(STATE_M15_BOS_CONFIRMED, "Bearish BOS confirmed");

      // Calculate OTE from the BOS swing
      double ote_swing_high = (m15_sh.valid ? m15_sh.price : m15_bars[m15_sl.bar_index].high);
      double ote_swing_low  = m15_sl.price;

      // For bearish BOS, fib from the swing that caused BOS (low to high)
      if(CalculateOTE(BIAS_BEARISH, ote_swing_high, ote_swing_low))
      {
         TransitionState(STATE_WAITING_FOR_OTE_ENTRY, "OTE zone calculated and valid");
      }
      else
      {
         InvalidateSetup("OTE zone invalid (width out of range)");
      }
   }
}

//==================================================================//
//  SECTION 10 - CONFIRMATION CANDLE DETECTION (M5)                 //
//==================================================================//

//------------------------------------------------------------------//
//| Bullish Engulfing: current body contains prev body, bullish     |
//------------------------------------------------------------------//
bool IsBullishEngulfing(const MqlRates &curr, const MqlRates &prev)
{
   double curr_body_high = MathMax(curr.open, curr.close);
   double curr_body_low  = MathMin(curr.open, curr.close);
   double prev_body_high = MathMax(prev.open, prev.close);
   double prev_body_low  = MathMin(prev.open, prev.close);

   return (curr.close > curr.open) &&              // Current is bullish
          (curr_body_high >= prev_body_high) &&     // Contains prev body
          (curr_body_low <= prev_body_low) &&
          (curr.close > prev.open);                 // Closes above prev open
}

//------------------------------------------------------------------//
//| Bearish Engulfing: current body contains prev body, bearish     |
//------------------------------------------------------------------//
bool IsBearishEngulfing(const MqlRates &curr, const MqlRates &prev)
{
   double curr_body_high = MathMax(curr.open, curr.close);
   double curr_body_low  = MathMin(curr.open, curr.close);
   double prev_body_high = MathMax(prev.open, prev.close);
   double prev_body_low  = MathMin(prev.open, prev.close);

   return (curr.close < curr.open) &&              // Current is bearish
          (curr_body_high >= prev_body_high) &&     // Contains prev body
          (curr_body_low <= prev_body_low) &&
          (curr.close < prev.open);                 // Closes below prev open
}

//------------------------------------------------------------------//
//| Doji: body < 20% of total range                                 |
//------------------------------------------------------------------//
bool IsDoji(const MqlRates &bar)
{
   double range = bar.high - bar.low;
   if(range <= 0.0) return false;
   double body = MathAbs(bar.close - bar.open);
   return (body < 0.20 * range);
}

//------------------------------------------------------------------//
//| Pin Bar: rejection wick >= 60% of total range in bias direction  |
//------------------------------------------------------------------//
bool IsPinBar(const MqlRates &bar, ENUM_BIAS bias_direction)
{
   double range = bar.high - bar.low;
   if(range <= 0.0) return false;

   double upper_wick = bar.high - MathMax(bar.open, bar.close);
   double lower_wick = MathMin(bar.open, bar.close) - bar.low;

   if(bias_direction == BIAS_BULLISH)
   {
      // Bullish pin bar: long lower wick (rejection of lower prices)
      return (lower_wick >= 0.60 * range);
   }
   else
   {
      // Bearish pin bar: long upper wick (rejection of higher prices)
      return (upper_wick >= 0.60 * range);
   }
}

//------------------------------------------------------------------//
//| Detect confirmation candle at OTE zone on M5                     |
//| V2: Two modes - Relaxed (default) and Strict (V1 behavior)     |
//------------------------------------------------------------------//
ENUM_CANDLE_PATTERN DetectConfirmation(const MqlRates &m5_bars[], ENUM_BIAS bias)
{
   //=== STRICT MODE (V1 behavior): Engulfing/Doji+Follow/Pin Bar ===//
   if(InpStrictConfirmation)
   {
      // Check if current completed M5 bar close is within OTE zone
      double close_price = m5_bars[1].close;
      if(close_price < g_ote.zone_low || close_price > g_ote.zone_high)
         return PATTERN_NONE;

      if(bias == BIAS_BULLISH)
      {
         if(IsBullishEngulfing(m5_bars[1], m5_bars[2]))
            return PATTERN_BULLISH_ENGULFING;
         if(IsPinBar(m5_bars[1], BIAS_BULLISH))
            return PATTERN_PIN_BAR;
         // Doji check: bar[2] was doji, bar[1] closed bullish
         if(IsDoji(m5_bars[2]) && m5_bars[1].close > m5_bars[1].open)
            return PATTERN_DOJI_FOLLOW;
      }
      else if(bias == BIAS_BEARISH)
      {
         if(IsBearishEngulfing(m5_bars[1], m5_bars[2]))
            return PATTERN_BEARISH_ENGULFING;
         if(IsPinBar(m5_bars[1], BIAS_BEARISH))
            return PATTERN_PIN_BAR;
         // Doji check: bar[2] was doji, bar[1] closed bearish
         if(IsDoji(m5_bars[2]) && m5_bars[1].close < m5_bars[1].open)
            return PATTERN_DOJI_FOLLOW;
      }

      return PATTERN_NONE;
   }

   //=== RELAXED MODE (V2 default): Directional close + OTE zone touch ===//
   // A bar qualifies if:
   //   1. Its wick touches the OTE zone (high/low overlaps zone)
   //   2. It closes in the bias direction (bullish close for bull, bearish for bear)
   //   3. Close is not trapped on the wrong side of the zone

   if(bias == BIAS_BULLISH)
   {
      // Bar reached down into or through the zone (wick touches zone)
      bool bar_touches_zone = (m5_bars[1].low <= g_ote.zone_high && m5_bars[1].high >= g_ote.zone_low);
      // Bar closed bullish (in bias direction)
      bool closes_bullish = (m5_bars[1].close > m5_bars[1].open);
      // Close is above the deepest OTE level (not trapped below)
      bool close_not_trapped = (m5_bars[1].close > g_ote.zone_low);

      if(bar_touches_zone && closes_bullish && close_not_trapped)
         return PATTERN_DIRECTIONAL_CLOSE;
   }
   else if(bias == BIAS_BEARISH)
   {
      // Bar reached up into or through the zone (wick touches zone)
      bool bar_touches_zone = (m5_bars[1].high >= g_ote.zone_low && m5_bars[1].low <= g_ote.zone_high);
      // Bar closed bearish (in bias direction)
      bool closes_bearish = (m5_bars[1].close < m5_bars[1].open);
      // Close is below the shallowest OTE level (not trapped above)
      bool close_not_trapped = (m5_bars[1].close < g_ote.zone_high);

      if(bar_touches_zone && closes_bearish && close_not_trapped)
         return PATTERN_DIRECTIONAL_CLOSE;
   }

   return PATTERN_NONE;
}

//==================================================================//
//  SECTION 11 - POSITION SIZING                                    //
//==================================================================//

//------------------------------------------------------------------//
//| Calculate lot size based on risk percentage and SL distance     |
//------------------------------------------------------------------//
double CalcVolume(double risk_money, double entry_price, double stop_loss)
{
   if(entry_price <= 0.0 || stop_loss <= 0.0 || risk_money <= 0.0)
      return 0.0;

   double sl_distance = MathAbs(entry_price - stop_loss);
   if(sl_distance <= 0.0) return 0.0;

   // Calculate loss per 1.00 lot
   double loss_per_lot = 0.0;
   double profit = 0.0;

   // Determine order type for profit calc
   ENUM_ORDER_TYPE ot = (entry_price > stop_loss) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(OrderCalcProfit(ot, _Symbol, 1.0, entry_price, stop_loss, profit))
      loss_per_lot = MathAbs(profit);

   // Fallback: tick-value based conversion
   if(loss_per_lot <= 0.0)
   {
      double tvLoss = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      double ts = TickSizeSafe();
      if(tvLoss > 0.0 && ts > 0.0)
         loss_per_lot = (sl_distance / ts) * tvLoss;
   }

   if(loss_per_lot <= 0.0)
   {
      LogMsg("LOT", "Cannot determine loss-per-lot - rejecting");
      return 0.0;
   }

   // Raw lot calculation
   double raw_lots = risk_money / loss_per_lot;

   // Floor to lot step (never round up into more risk)
   double lots = MathFloor(raw_lots / g_lotStep) * g_lotStep;

   // Apply caps
   lots = MathMin(lots, InpMaxLot);
   lots = MathMin(lots, g_lotMax);
   lots = NormalizeDouble(lots, g_lotDigits);

   // Floor check
   if(lots < g_lotMin)
   {
      LogMsg("LOT", StringFormat("Lot too small: %.4f < min %.4f (risk=$%.2f, lossPerLot=$%.2f)",
             lots, g_lotMin, risk_money, loss_per_lot));
      return 0.0;
   }

   VLog("LOT", StringFormat("OK | lots=%.2f | risk=$%.2f | lossPerLot=$%.2f | raw=%.4f",
        lots, risk_money, loss_per_lot, raw_lots));
   return lots;
}

//==================================================================//
//  SECTION 12 - RISK & PROTECTION LAYER                            //
//==================================================================//

//------------------------------------------------------------------//
//| Day boundary check and reset                                    |
//------------------------------------------------------------------//
void CheckDayReset()
{
   datetime ds = iTime(_Symbol, PERIOD_D1, 0);
   if(ds <= 0) return;

   if(ds != g_dayStart)
   {
      g_dayStart = ds;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_dayStartBalance <= 0.0)
         g_dayStartBalance = AccountInfoDouble(ACCOUNT_EQUITY);
      g_tradesToday = 0;
      g_dailyLossTriggered = false;

      LogMsg("DAY", StringFormat("RESET | start=%s balance=%.2f",
             TimeToString(g_dayStart, TIME_DATE), g_dayStartBalance));
   }
}

//------------------------------------------------------------------//
//| Static Drawdown check (every tick while position open)          |
//------------------------------------------------------------------//
void CheckStaticDrawdown()
{
   if(g_ddTriggered) return;

   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(InpInitialBalance <= 0.0) return;

   double dd_percent = (InpInitialBalance - current_balance) / InpInitialBalance * 100.0;

   if(dd_percent >= InpStaticDDPercent)
   {
      // Emergency: close all positions owned by this EA
      CloseAllPositions();
      g_ddTriggered = true;
      LogMsg("ALERT", StringFormat("STATIC DD TRIGGERED: Balance=%.2f, Loss=%.2f, DD=%.2f%% >= %.2f%%",
             current_balance, InpInitialBalance - current_balance, dd_percent, InpStaticDDPercent));
      TransitionState(STATE_DISABLED, "Static DD limit reached");
   }
}

//------------------------------------------------------------------//
//| Daily loss limit check                                          |
//------------------------------------------------------------------//
void CheckDailyLoss()
{
   if(g_dailyLossTriggered) return;
   if(g_dayStartBalance <= 0.0) return;

   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double day_loss = g_dayStartBalance - current_balance;
   double day_loss_percent = day_loss / g_dayStartBalance * 100.0;

   if(day_loss_percent >= InpDailyLossPercent)
   {
      g_dailyLossTriggered = true;
      LogMsg("WARNING", StringFormat("DAILY LOSS LIMIT: Loss=%.2f (%.2f%%), DayStart=%.2f",
             day_loss, day_loss_percent, g_dayStartBalance));
   }
}

//------------------------------------------------------------------//
//| Close all EA positions (emergency)                              |
//------------------------------------------------------------------//
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      g_trade.PositionClose(tk);
   }
}

//------------------------------------------------------------------//
//| Check if EA has an open position                                |
//------------------------------------------------------------------//
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      return true;
   }
   return false;
}

//------------------------------------------------------------------//
//| Get ticket of EA's open position (0 if none)                    |
//------------------------------------------------------------------//
ulong GetMyTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      return tk;
   }
   return 0;
}

//------------------------------------------------------------------//
//| Pre-trade validation checks                                     |
//------------------------------------------------------------------//
bool PreTradeChecks(const TradeSetup &setup)
{
   // 1. Static DD halt
   if(g_ddTriggered)
   {
      g_rejTotalDD++;
      LogMsg("REJECT", "Static DD halt active - no new trades");
      return false;
   }

   // 2. Daily loss limit
   if(g_dailyLossTriggered)
   {
      g_rejDailyLimit++;
      LogMsg("REJECT", "Daily loss limit active - no new trades today");
      return false;
   }

   // 3. Max trades per day
   if(g_tradesToday >= InpMaxTradesPerDay)
   {
      g_rejMaxTrades++;
      LogMsg("REJECT", StringFormat("Max trades reached: %d/%d", g_tradesToday, InpMaxTradesPerDay));
      return false;
   }

   // 4. No existing position (single position only)
   if(HasPosition())
   {
      g_rejPosition++;
      LogMsg("REJECT", "Position already open - single position rule");
      return false;
   }

   // 5. Spread check
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > (long)InpMaxSpreadPoints)
   {
      g_rejSpread++;
      LogMsg("REJECT", StringFormat("Spread too wide: %d > max %d", (int)spread, InpMaxSpreadPoints));
      return false;
   }

   // 6. Cooldown check (V2)
   if(InpCooldownMinutes > 0 && g_lastTradeCloseTime > 0)
   {
      datetime now = TimeCurrent();
      int elapsed_seconds = (int)(now - g_lastTradeCloseTime);
      int cooldown_seconds = InpCooldownMinutes * 60;
      if(elapsed_seconds < cooldown_seconds)
      {
         g_rejCooldown++;
         LogMsg("REJECT", StringFormat("Cooldown active: %d/%d seconds elapsed since last close",
                elapsed_seconds, cooldown_seconds));
         return false;
      }
   }

   // 7. Margin check (80% of free margin)
   double margin_required = 0.0;
   ENUM_ORDER_TYPE ot = (setup.direction == BIAS_BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(ot, _Symbol, setup.lot_size, setup.entry_price, margin_required))
   {
      g_rejMargin++;
      LogMsg("REJECT", "Cannot calculate required margin");
      return false;
   }
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(margin_required > free_margin * 0.80)
   {
      g_rejMargin++;
      LogMsg("REJECT", StringFormat("Margin exceeded: required=%.2f > 80%% of free=%.2f",
             margin_required, free_margin));
      return false;
   }

   return true;
}

//==================================================================//
//  SECTION 13 - TRADE SETUP BUILDING                               //
//==================================================================//

//------------------------------------------------------------------//
//| Build complete trade setup from current market state             |
//------------------------------------------------------------------//
bool BuildTradeSetup(ENUM_BIAS direction, double entry_price, ENUM_CANDLE_PATTERN pattern,
                     TradeSetup &setup)
{
   setup.direction   = direction;
   setup.entry_price = entry_price;
   setup.pattern     = pattern;

   // Calculate SL from M15 Order Block + buffer
   // Buffer in price terms: $1 = 1.0 on XAUUSD (digits=2, point=0.01)
   // So SL_buffer_dollars translates directly to price units
   double sl_buffer = InpSLBufferDollars;

   if(direction == BIAS_BULLISH)
      setup.stop_loss = RoundToTick(g_bos.ob_low - sl_buffer);
   else
      setup.stop_loss = RoundToTick(g_bos.ob_high + sl_buffer);

   // Enforce SL bounds (in dollars = price units for gold)
   double sl_dist = MathAbs(entry_price - setup.stop_loss);

   if(sl_dist < InpMinSLDollars)
   {
      // Clamp to minimum
      if(direction == BIAS_BULLISH)
         setup.stop_loss = RoundToTick(entry_price - InpMinSLDollars);
      else
         setup.stop_loss = RoundToTick(entry_price + InpMinSLDollars);
      sl_dist = InpMinSLDollars;
   }

   if(sl_dist > InpMaxSLDollars)
   {
      g_rejSLTooWide++;
      LogMsg("REJECT", StringFormat("SL too wide: $%.2f > max $%.2f", sl_dist, InpMaxSLDollars));
      return false;
   }

   setup.sl_distance_pts = sl_dist / g_point;

   // Calculate TP levels
   if(direction == BIAS_BULLISH)
   {
      setup.tp1 = RoundToTick(entry_price + sl_dist * InpRR_TP1);
      setup.tp2 = RoundToTick(entry_price + sl_dist * InpRR_TP2);
   }
   else
   {
      setup.tp1 = RoundToTick(entry_price - sl_dist * InpRR_TP1);
      setup.tp2 = RoundToTick(entry_price - sl_dist * InpRR_TP2);
   }

   // Calculate position size: risk = 1.5% of balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   setup.risk_money = balance * (InpRiskPercent / 100.0);
   setup.lot_size = CalcVolume(setup.risk_money, entry_price, setup.stop_loss);

   if(setup.lot_size <= 0.0)
   {
      g_rejLot++;
      LogMsg("REJECT", "Lot size calculation returned 0 - insufficient for minimum lot");
      return false;
   }

   return true;
}

//==================================================================//
//  SECTION 14 - TRADE EXECUTION                                    //
//==================================================================//

//------------------------------------------------------------------//
//| Execute market order                                             |
//------------------------------------------------------------------//
bool ExecuteTrade(TradeSetup &setup)
{
   // Pre-trade checks
   if(!PreTradeChecks(setup))
      return false;

   // Normalize all prices
   double entry = setup.entry_price;
   double sl    = setup.stop_loss;
   double tp2   = setup.tp2;  // Use TP2 as the order TP (TP1 managed by EA)

   string comment = "";
   if(setup.direction == BIAS_BULLISH)
      comment = "ICT_ChoCh_V2_BUY";
   else
      comment = "ICT_ChoCh_V2_SELL";

   bool sent = false;
   if(setup.direction == BIAS_BULLISH)
      sent = g_trade.Buy(setup.lot_size, _Symbol, 0.0, sl, tp2, comment);
   else
      sent = g_trade.Sell(setup.lot_size, _Symbol, 0.0, sl, tp2, comment);

   uint rc = g_trade.ResultRetcode();
   if(!sent || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED &&
                rc != TRADE_RETCODE_DONE_PARTIAL))
   {
      g_orderFails++;
      LogMsg("ORDER", StringFormat("FAIL | %s lots=%.2f sl=%s tp2=%s rc=%d (%s)",
             BiasToString(setup.direction), setup.lot_size,
             DoubleToString(sl, g_digits), DoubleToString(tp2, g_digits),
             (int)rc, g_trade.ResultRetcodeDescription()));
      return false;
   }

   // Confirm the fill
   ulong tk = GetMyTicket();
   if(tk == 0)
   {
      g_orderFails++;
      LogMsg("ORDER", "FAIL | No position found after send");
      return false;
   }

   // Store position state
   g_positionTicket = tk;
   g_tp1Hit         = false;

   if(PositionSelectByTicket(tk))
   {
      g_posEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      g_posInitialSL  = PositionGetDouble(POSITION_SL);
      g_posInitialLot = PositionGetDouble(POSITION_VOLUME);
   }
   else
   {
      g_posEntryPrice = entry;
      g_posInitialSL  = sl;
      g_posInitialLot = setup.lot_size;
   }

   g_posTP1 = setup.tp1;
   g_posTP2 = setup.tp2;

   // Book-keeping
   g_tradesToday++;
   g_cntEntries++;
   if(setup.direction == BIAS_BULLISH) g_cntEntriesBuy++;
   else                                g_cntEntriesSell++;
   g_cntConfirmations++;

   LogMsg("ENTRY", StringFormat("%s | ticket=%I64u lots=%.2f fill=%s sl=%s tp1=%s tp2=%s risk=$%.2f "
          "pattern=%s trade#%d/%d spread=%d",
          BiasToString(setup.direction), tk, setup.lot_size,
          DoubleToString(g_posEntryPrice, g_digits),
          DoubleToString(g_posInitialSL, g_digits),
          DoubleToString(setup.tp1, g_digits),
          DoubleToString(setup.tp2, g_digits),
          setup.risk_money,
          PatternToString(setup.pattern),
          g_tradesToday, InpMaxTradesPerDay,
          (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));

   TransitionState(STATE_POSITION_OPEN, "Trade executed");
   return true;
}

//==================================================================//
//  SECTION 15 - TRADE MANAGEMENT (TP1 Partial + BE + TP2)          //
//==================================================================//

//------------------------------------------------------------------//
//| Manage open position: TP1 partial close, BE, TP2 close          |
//------------------------------------------------------------------//
void ManageOpenPosition()
{
   ulong tk = GetMyTicket();
   if(tk == 0)
   {
      // Position was closed (SL hit by broker or manual)
      if(g_state == STATE_POSITION_OPEN || g_state == STATE_TP1_HIT)
      {
         g_lastTradeCloseTime = TimeCurrent();  // V2: record close time for cooldown
         LogMsg("POS", "Position closed externally (SL/broker/manual)");
         TransitionState(STATE_IDLE, "Position closed");
         // Reset setup data for next cycle
         g_bos.valid = false;
         g_ote.valid = false;
      }
      return;
   }

   if(!PositionSelectByTicket(tk)) return;

   // Verify ownership (defensive)
   if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return;

   // Check minimum hold time
   datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   if(TimeCurrent() - open_time < InpMinHoldSeconds)
      return;  // Suppress all management during hold period

   double entry   = PositionGetDouble(POSITION_PRICE_OPEN);
   double current = PositionGetDouble(POSITION_PRICE_CURRENT);
   double volume  = PositionGetDouble(POSITION_VOLUME);
   double sl      = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double sl_dist = MathAbs(entry - g_posInitialSL);
   if(sl_dist <= 0.0) sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0) return;

   double tp1_price = g_posTP1;
   double tp2_price = g_posTP2;

   //--- Check TP1 hit (if not already partially closed) ---------//
   if(!g_tp1Hit)
   {
      bool tp1_reached = false;
      if(ptype == POSITION_TYPE_BUY)
         tp1_reached = (current >= tp1_price);
      else
         tp1_reached = (current <= tp1_price);

      if(tp1_reached)
      {
         double close_lots = MathFloor(volume * (InpPartialClosePercent / 100.0)
                             / g_lotStep) * g_lotStep;
         close_lots = NormalizeDouble(close_lots, g_lotDigits);
         double remaining = volume - close_lots;

         if(remaining < g_lotMin)
         {
            // Close entire position at TP1
            if(g_trade.PositionClose(tk))
            {
               g_cntTP1++;
               g_lastTradeCloseTime = TimeCurrent();  // V2: cooldown
               LogMsg("TP1", StringFormat("Full close (remaining < min lot) | ticket=%I64u vol=%.2f",
                      tk, volume));
               g_tp1Hit = true;
               TransitionState(STATE_IDLE, "TP1 full close (lot too small for partial)");
               g_bos.valid = false;
               g_ote.valid = false;
            }
         }
         else
         {
            // Partial close at TP1
            if(g_trade.PositionClosePartial(tk, close_lots))
            {
               g_cntTP1++;
               LogMsg("TP1", StringFormat("Partial close %.2f lots | remaining=%.2f | ticket=%I64u",
                      close_lots, remaining, tk));

               // Move SL to break-even (entry price) with TP2
               double be_sl = RoundToTick(entry);
               if(g_trade.PositionModify(tk, be_sl, tp2_price))
               {
                  g_cntBE++;
                  LogMsg("BE", StringFormat("SL moved to entry %s | ticket=%I64u",
                         DoubleToString(be_sl, g_digits), tk));
               }
               else
               {
                  LogMsg("BE", StringFormat("FAIL to modify BE | rc=%d (%s)",
                         (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
               }

               g_tp1Hit = true;
               TransitionState(STATE_TP1_HIT, "TP1 hit + partial close + BE");
            }
            else
            {
               LogMsg("TP1", StringFormat("FAIL partial close | rc=%d (%s)",
                      (int)g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
            }
         }
      }
   }

   //--- Check TP2 hit (only after TP1 partial close) ------------//
   if(g_tp1Hit && g_state == STATE_TP1_HIT)
   {
      bool tp2_reached = false;
      if(ptype == POSITION_TYPE_BUY)
         tp2_reached = (current >= tp2_price);
      else
         tp2_reached = (current <= tp2_price);

      if(tp2_reached)
      {
         if(g_trade.PositionClose(tk))
         {
            g_cntTP2++;
            g_lastTradeCloseTime = TimeCurrent();  // V2: cooldown
            LogMsg("TP2", StringFormat("Full close remaining | ticket=%I64u", tk));
            TransitionState(STATE_IDLE, "TP2 hit - trade completed");
            g_bos.valid = false;
            g_ote.valid = false;
         }
      }
   }
}

//==================================================================//
//  SECTION 16 - M5 ENTRY LOGIC                                     //
//==================================================================//

//------------------------------------------------------------------//
//| Check for M5 entry signal at OTE zone                           |
//------------------------------------------------------------------//
void CheckM5Entry()
{
   if(g_state != STATE_WAITING_FOR_OTE_ENTRY) return;
   if(!g_ote.valid || !g_bos.valid || !g_choch.valid) return;

   //--- Timeout check ------------------------------------------//
   if(TimeCurrent() > g_bos.expiry)
   {
      g_cntTimeouts++;
      InvalidateSetup(StringFormat("Timeout: %d H1 bars elapsed without entry",
                      InpSetupTimeoutH1Bars));
      return;
   }

   //--- EMA 200 filter (optional) ------------------------------//
   if(InpUseEMA200Filter && g_hEMA200 != INVALID_HANDLE)
   {
      double ema_buf[];
      ArraySetAsSeries(ema_buf, true);
      if(CopyBuffer(g_hEMA200, 0, 0, 1, ema_buf) == 1)
      {
         MqlTick t;
         if(SymbolInfoTick(_Symbol, t))
         {
            if(g_choch.direction == BIAS_BULLISH && t.bid < ema_buf[0])
            {
               VLog("EMA200", "Price below EMA200 - bullish entry blocked");
               return;
            }
            if(g_choch.direction == BIAS_BEARISH && t.ask > ema_buf[0])
            {
               VLog("EMA200", "Price above EMA200 - bearish entry blocked");
               return;
            }
         }
      }
   }

   //--- Get M5 bars for confirmation candle check ---------------//
   MqlRates m5_bars[];
   ArraySetAsSeries(m5_bars, true);

   int m5_copied = CopyRates(_Symbol, PERIOD_M5, 0, 10, m5_bars);
   if(m5_copied < 4)
   {
      VLog("M5", "Insufficient M5 data for confirmation check");
      return;
   }

   //--- Check if price is in OTE zone (using last completed bar close) //
   double last_close = m5_bars[1].close;

   // Also check if price has passed THROUGH the OTE zone without entry
   // (invalidation condition from Requirement 14.3)
   if(g_choch.direction == BIAS_BULLISH && last_close < g_ote.zone_low)
   {
      // For bullish: if price went below the entire OTE zone (deeper than 78.6%)
      // Check if it already went through (passed beyond OB without trigger)
      if(last_close < g_bos.ob_low)
      {
         InvalidateSetup("Price passed through OTE zone beyond OB without entry (Bullish)");
         return;
      }
   }
   else if(g_choch.direction == BIAS_BEARISH && last_close > g_ote.zone_high)
   {
      // For bearish: if price went above the entire OTE zone (deeper than 78.6%)
      if(last_close > g_bos.ob_high)
      {
         InvalidateSetup("Price passed through OTE zone beyond OB without entry (Bearish)");
         return;
      }
   }

   //--- Detect confirmation candle at OTE zone ------------------//
   ENUM_CANDLE_PATTERN pattern = DetectConfirmation(m5_bars, g_choch.direction);
   if(pattern == PATTERN_NONE)
      return;

   //--- Confirmation found - build trade setup ------------------//
   double entry_price = m5_bars[1].close;  // Entry at close of confirmation candle

   TradeSetup setup;
   if(!BuildTradeSetup(g_choch.direction, entry_price, pattern, setup))
   {
      g_rejSetupInvalid++;
      return;
   }

   LogMsg("SIGNAL", StringFormat("%s | pattern=%s | entry=%s | OTE=[%s - %s] | close_in_zone=%s",
          BiasToString(g_choch.direction),
          PatternToString(pattern),
          DoubleToString(entry_price, g_digits),
          DoubleToString(g_ote.zone_low, g_digits),
          DoubleToString(g_ote.zone_high, g_digits),
          (last_close >= g_ote.zone_low && last_close <= g_ote.zone_high) ? "YES" : "NO"));

   //--- Execute the trade --------------------------------------//
   ExecuteTrade(setup);
}

//==================================================================//
//  SECTION 17 - INITIALIZATION                                     //
//==================================================================//

//------------------------------------------------------------------//
//| Input parameter validation                                       |
//------------------------------------------------------------------//
bool ValidateInputs()
{
   bool ok = true;

   if(InpRiskPercent <= 0.0 || InpRiskPercent > 5.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpRiskPercent=%.2f outside (0, 5]", InpRiskPercent));
      ok = false;
   }
   if(InpMaxLot <= 0.0 || InpMaxLot > 1.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpMaxLot=%.3f outside (0, 1]", InpMaxLot));
      ok = false;
   }
   if(InpRR_TP1 <= 0.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpRR_TP1=%.2f must be > 0", InpRR_TP1));
      ok = false;
   }
   if(InpRR_TP2 <= InpRR_TP1)
   {
      LogMsg("INIT", StringFormat("FAIL: InpRR_TP2=%.2f must be > InpRR_TP1=%.2f", InpRR_TP2, InpRR_TP1));
      ok = false;
   }
   if(InpPartialClosePercent < 10 || InpPartialClosePercent > 90)
   {
      LogMsg("INIT", StringFormat("FAIL: InpPartialClosePercent=%d outside [10, 90]", InpPartialClosePercent));
      ok = false;
   }
   if(InpMaxTradesPerDay < 1 || InpMaxTradesPerDay > 20)
   {
      LogMsg("INIT", StringFormat("FAIL: InpMaxTradesPerDay=%d outside [1, 20]", InpMaxTradesPerDay));
      ok = false;
   }
   if(InpDailyLossPercent <= 0.0 || InpDailyLossPercent > 10.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpDailyLossPercent=%.2f outside (0, 10]", InpDailyLossPercent));
      ok = false;
   }
   if(InpStaticDDPercent <= 0.0 || InpStaticDDPercent > 50.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpStaticDDPercent=%.2f outside (0, 50]", InpStaticDDPercent));
      ok = false;
   }
   if(InpMaxSpreadPoints < 1)
   {
      LogMsg("INIT", StringFormat("FAIL: InpMaxSpreadPoints=%d must be >= 1", InpMaxSpreadPoints));
      ok = false;
   }
   if(InpMinHoldSeconds < 0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpMinHoldSeconds=%d must be >= 0", InpMinHoldSeconds));
      ok = false;
   }
   if(InpSLBufferDollars < 0.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpSLBufferDollars=%.2f must be >= 0", InpSLBufferDollars));
      ok = false;
   }
   if(InpMinSLDollars <= 0.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpMinSLDollars=%.2f must be > 0", InpMinSLDollars));
      ok = false;
   }
   if(InpMaxSLDollars <= InpMinSLDollars)
   {
      LogMsg("INIT", StringFormat("FAIL: InpMaxSLDollars=%.2f must be > InpMinSLDollars=%.2f",
             InpMaxSLDollars, InpMinSLDollars));
      ok = false;
   }
   if(InpInitialBalance <= 0.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpInitialBalance=%.2f must be > 0", InpInitialBalance));
      ok = false;
   }
   if(InpCooldownMinutes < 0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpCooldownMinutes=%d must be >= 0", InpCooldownMinutes));
      ok = false;
   }
   if(InpH1SwingBars < 1)
   {
      LogMsg("INIT", StringFormat("FAIL: InpH1SwingBars=%d must be >= 1", InpH1SwingBars));
      ok = false;
   }
   if(InpM15SwingBars < 1)
   {
      LogMsg("INIT", StringFormat("FAIL: InpM15SwingBars=%d must be >= 1", InpM15SwingBars));
      ok = false;
   }
   if(InpFibLevelLow <= 0.0 || InpFibLevelLow >= 1.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpFibLevelLow=%.3f must be in (0, 1)", InpFibLevelLow));
      ok = false;
   }
   if(InpFibLevelHigh <= InpFibLevelLow || InpFibLevelHigh >= 1.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpFibLevelHigh=%.3f must be > InpFibLevelLow and < 1",
             InpFibLevelHigh));
      ok = false;
   }
   if(InpMinOTEWidthDollars <= 0.0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpMinOTEWidthDollars=%.2f must be > 0", InpMinOTEWidthDollars));
      ok = false;
   }
   if(InpMaxOTEWidthDollars <= InpMinOTEWidthDollars)
   {
      LogMsg("INIT", StringFormat("FAIL: InpMaxOTEWidthDollars=%.2f must be > InpMinOTEWidthDollars",
             InpMaxOTEWidthDollars));
      ok = false;
   }
   if(InpSetupTimeoutH1Bars < 1)
   {
      LogMsg("INIT", StringFormat("FAIL: InpSetupTimeoutH1Bars=%d must be >= 1", InpSetupTimeoutH1Bars));
      ok = false;
   }
   if(InpEMA200Period < 10)
   {
      LogMsg("INIT", StringFormat("FAIL: InpEMA200Period=%d must be >= 10", InpEMA200Period));
      ok = false;
   }
   if(InpDeviationPoints < 0)
   {
      LogMsg("INIT", StringFormat("FAIL: InpDeviationPoints=%d must be >= 0", InpDeviationPoints));
      ok = false;
   }

   return ok;
}

//------------------------------------------------------------------//
//| OnInit                                                           |
//------------------------------------------------------------------//
int OnInit()
{
   LogMsg("INIT", "=== CK_XAU_ICT_ChoCh_V2 Initialization (Relaxed Confirmation) ===");

   //--- Validate symbol ----------------------------------------//
   if(_Symbol != "XAUUSD" && _Symbol != "XAUUSD." && _Symbol != "XAUUSD.raw" &&
      StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
   {
      LogMsg("INIT", StringFormat("FAIL: Symbol %s is not XAUUSD. This EA is designed for gold only.", _Symbol));
      return INIT_FAILED;
   }

   //--- Validate timeframe -------------------------------------//
   if(_Period != PERIOD_M5)
   {
      LogMsg("INIT", StringFormat("FAIL: Chart timeframe must be M5, current is %s",
             EnumToString(_Period)));
      return INIT_FAILED;
   }

   //--- Validate trading permissions ---------------------------//
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      LogMsg("INIT", "FAIL: AutoTrading is disabled - enable it before running this EA");
      return INIT_FAILED;
   }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      LogMsg("INIT", "FAIL: EA trading is not allowed - check permissions");
      return INIT_FAILED;
   }

   //--- Validate inputs ----------------------------------------//
   if(!ValidateInputs())
      return INIT_FAILED;

   //--- Cache broker constraints --------------------------------//
   CacheSymbolInfo();

   //--- Check leverage -----------------------------------------//
   long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   if(leverage > 30)
   {
      LogMsg("INIT", StringFormat("WARNING: Account leverage %d:1 exceeds recommended 1:30 for prop firm",
             (int)leverage));
   }

   //--- Setup CTrade object ------------------------------------//
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetMarginMode();
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);

   //--- Create EMA 200 handle if filter is enabled -------------//
   if(InpUseEMA200Filter)
   {
      g_hEMA200 = iMA(_Symbol, InpEMA200TF, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
      if(g_hEMA200 == INVALID_HANDLE)
      {
         LogMsg("INIT", "WARNING: Failed to create EMA 200 indicator handle");
      }
   }

   //--- Verify historical data availability --------------------//
   MqlRates h1_test[];
   ArraySetAsSeries(h1_test, true);
   int h1_available = CopyRates(_Symbol, PERIOD_H1, 0, 200, h1_test);
   if(h1_available < 200)
   {
      LogMsg("INIT", StringFormat("FAIL: Insufficient H1 data: %d bars (need 200 minimum)",
             h1_available));
      return INIT_FAILED;
   }

   MqlRates m15_test[];
   ArraySetAsSeries(m15_test, true);
   int m15_available = CopyRates(_Symbol, PERIOD_M15, 0, 100, m15_test);
   if(m15_available < 100)
   {
      LogMsg("INIT", StringFormat("FAIL: Insufficient M15 data: %d bars (need 100 minimum)",
             m15_available));
      return INIT_FAILED;
   }

   //--- Initialize day tracking --------------------------------//
   g_dayStart = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_dayStartBalance <= 0.0)
      g_dayStartBalance = InpInitialBalance;

   //--- Initialize struct validity flags -----------------------//
   g_choch.valid   = false;
   g_bos.valid     = false;
   g_ote.valid     = false;
   g_h1_lastSH.valid = false;
   g_h1_lastSL.valid = false;
   g_h1_prevSH.valid = false;
   g_h1_prevSL.valid = false;
   g_m15_lastSH.valid = false;
   g_m15_lastSL.valid = false;
   g_lastTradeCloseTime = 0;

   //--- Log configuration summary ------------------------------//
   LogMsg("INIT", StringFormat("Magic=%d Risk=%.1f%% MaxLot=%.2f TP1=%.1fR TP2=%.1fR Partial=%d%%",
          (int)InpMagicNumber, InpRiskPercent, InpMaxLot, InpRR_TP1, InpRR_TP2, InpPartialClosePercent));
   LogMsg("INIT", StringFormat("MaxTrades=%d DailyLoss=%.1f%% StaticDD=%.1f%% MaxSpread=%d MinHold=%ds",
          InpMaxTradesPerDay, InpDailyLossPercent, InpStaticDDPercent, InpMaxSpreadPoints, InpMinHoldSeconds));
   LogMsg("INIT", StringFormat("H1Swing=%d M15Swing=%d FibLow=%.3f FibHigh=%.3f OTEMin=$%.1f OTEMax=$%.1f",
          InpH1SwingBars, InpM15SwingBars, InpFibLevelLow, InpFibLevelHigh,
          InpMinOTEWidthDollars, InpMaxOTEWidthDollars));
   LogMsg("INIT", StringFormat("SLBuffer=$%.1f MinSL=$%.1f MaxSL=$%.1f Timeout=%dH1bars InitBal=$%.0f",
          InpSLBufferDollars, InpMinSLDollars, InpMaxSLDollars, InpSetupTimeoutH1Bars, InpInitialBalance));
   LogMsg("INIT", StringFormat("StrictConfirmation=%s Cooldown=%d min",
          (InpStrictConfirmation ? "ON (V1 mode)" : "OFF (relaxed)"), InpCooldownMinutes));
   LogMsg("INIT", StringFormat("EMA200Filter=%s (period=%d, TF=%s)",
          (InpUseEMA200Filter ? "ON" : "OFF"), InpEMA200Period, EnumToString(InpEMA200TF)));
   LogMsg("INIT", StringFormat("Symbol=%s Digits=%d Point=%s TickSize=%s LotMin=%.2f LotStep=%.2f",
          _Symbol, g_digits, DoubleToString(g_point, g_digits+2),
          DoubleToString(g_tickSize, g_digits+2), g_lotMin, g_lotStep));
   LogMsg("INIT", "=== Initialization Complete - State: IDLE ===");

   return INIT_SUCCEEDED;
}

//==================================================================//
//  SECTION 18 - DEINITIALIZATION                                   //
//==================================================================//

void OnDeinit(const int reason)
{
   //--- Release indicator handles ------------------------------//
   if(g_hEMA200 != INVALID_HANDLE)
   {
      IndicatorRelease(g_hEMA200);
      g_hEMA200 = INVALID_HANDLE;
   }

   //--- Print comprehensive diagnostics summary ----------------//
   LogMsg("DEINIT", "================ DIAGNOSTICS SUMMARY ================");
   LogMsg("DEINIT", StringFormat("Deinit reason: %d", reason));
   LogMsg("DEINIT", StringFormat("Final state: %s", EnumToString(g_state)));
   LogMsg("DEINIT", "--- Activity ---");
   LogMsg("DEINIT", StringFormat("CHoCH events detected ......... %d", g_cntChoch));
   LogMsg("DEINIT", StringFormat("BOS events confirmed .......... %d", g_cntBos));
   LogMsg("DEINIT", StringFormat("OTE zones valid ............... %d", g_cntOTEValid));
   LogMsg("DEINIT", StringFormat("Confirmation candles found .... %d", g_cntConfirmations));
   LogMsg("DEINIT", StringFormat("Entries taken ................. %d", g_cntEntries));
   LogMsg("DEINIT", StringFormat("  BUY / SELL .................. %d / %d", g_cntEntriesBuy, g_cntEntriesSell));
   LogMsg("DEINIT", "--- Trade Management ---");
   LogMsg("DEINIT", StringFormat("TP1 partial closes ............ %d", g_cntTP1));
   LogMsg("DEINIT", StringFormat("TP2 full closes ............... %d", g_cntTP2));
   LogMsg("DEINIT", StringFormat("Break-even moves .............. %d", g_cntBE));
   LogMsg("DEINIT", "--- Rejections ---");
   LogMsg("DEINIT", StringFormat("Spread too wide ............... %d", g_rejSpread));
   LogMsg("DEINIT", StringFormat("Margin insufficient ........... %d", g_rejMargin));
   LogMsg("DEINIT", StringFormat("Daily loss limit .............. %d", g_rejDailyLimit));
   LogMsg("DEINIT", StringFormat("Max trades per day ............ %d", g_rejMaxTrades));
   LogMsg("DEINIT", StringFormat("Position already open ......... %d", g_rejPosition));
   LogMsg("DEINIT", StringFormat("Static DD halt ................ %d", g_rejTotalDD));
   LogMsg("DEINIT", StringFormat("Lot size rejected ............. %d", g_rejLot));
   LogMsg("DEINIT", StringFormat("SL too wide ................... %d", g_rejSLTooWide));
   LogMsg("DEINIT", StringFormat("OTE width invalid ............. %d", g_rejOTEWidth));
   LogMsg("DEINIT", StringFormat("Setup invalid at entry ........ %d", g_rejSetupInvalid));
   LogMsg("DEINIT", StringFormat("Cooldown rejections ........... %d", g_rejCooldown));
   LogMsg("DEINIT", "--- Invalidations ---");
   LogMsg("DEINIT", StringFormat("Setup invalidations ........... %d", g_cntInvalidations));
   LogMsg("DEINIT", StringFormat("Setup timeouts ................ %d", g_cntTimeouts));
   LogMsg("DEINIT", "--- Failures ---");
   LogMsg("DEINIT", StringFormat("Order failures ................ %d", g_orderFails));
   LogMsg("DEINIT", "--- Account ---");
   LogMsg("DEINIT", StringFormat("Balance=%.2f Equity=%.2f InitBal=%.2f",
          AccountInfoDouble(ACCOUNT_BALANCE),
          AccountInfoDouble(ACCOUNT_EQUITY),
          InpInitialBalance));
   double finalDD = 0.0;
   if(InpInitialBalance > 0.0)
      finalDD = (InpInitialBalance - AccountInfoDouble(ACCOUNT_BALANCE)) / InpInitialBalance * 100.0;
   LogMsg("DEINIT", StringFormat("Final Static DD: %.2f%%", finalDD));
   LogMsg("DEINIT", "=====================================================");
}

//==================================================================//
//  SECTION 19 - MAIN EVENT LOOP (OnTick)                           //
//==================================================================//

void OnTick()
{
   //=== Phase 1: Risk checks on every tick while position open ===//
   CheckStaticDrawdown();
   if(g_ddTriggered) return;

   //=== Phase 2: Trade management (if position open) ============//
   if(g_state == STATE_POSITION_OPEN || g_state == STATE_TP1_HIT)
   {
      ManageOpenPosition();
   }

   //=== Phase 3: New M5 bar processing only =====================//
   bool newM5  = IsNewM5Bar();
   bool newM15 = IsNewM15Bar();
   bool newH1  = IsNewH1Bar();

   if(!newM5) return;  // All structure analysis happens on bar close

   //=== Phase 4: Day boundary reset =============================//
   CheckDayReset();
   CheckDailyLoss();

   //=== Phase 5: H1 structure analysis (on H1 bar change) =======//
   if(newH1)
   {
      AnalyzeH1Structure();
   }

   //=== Phase 6: M15 structure analysis (on M15 bar change) =====//
   if(newM15)
   {
      AnalyzeM15Structure();
   }

   //=== Phase 7: Entry logic (every M5 bar, if setup pending) ===//
   if(g_state == STATE_WAITING_FOR_OTE_ENTRY)
   {
      CheckM5Entry();
   }

   //=== Phase 8: Sync position state (detect external close) ====//
   if(g_state == STATE_POSITION_OPEN || g_state == STATE_TP1_HIT)
   {
      if(!HasPosition())
      {
         g_lastTradeCloseTime = TimeCurrent();  // V2: cooldown
         LogMsg("POS", "Position no longer exists - returning to IDLE");
         TransitionState(STATE_IDLE, "Position closed (sync)");
         g_bos.valid = false;
         g_ote.valid = false;
      }
   }
}

//+------------------------------------------------------------------+
//| End of CK_XAU_ICT_ChoCh_V2.mq5                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                         Institutional_Gold_Trader_ProX_V2.mq5      |
//|                          Institutional Gold Trader Pro X v2.0      |
//|                          Professional Funded Challenge EA           |
//|                                                                    |
//|  SINGLE FILE VERSION - Copy this entire file into MetaEditor       |
//|  Compile and attach to XAUUSD M5 chart                            |
//+------------------------------------------------------------------+
#property copyright   "Institutional Gold Trader Pro X"
#property link        "https://github.com/mahamahagyaan-cpu/xau-smart-ea"
#property version     "2.00"
#property description "Professional SMC EA for XAUUSD - Funded Account Challenges"
#property description "Multi-TF (H1+M15+M5) | BOS+Liquidity+OB+FVG"
#property description "Risk: 0.25% | TP: 2R | BE: 1R | Trail: 1.5R"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Constants                                                          |
//+------------------------------------------------------------------+
#define EA_NAME           "Institutional Gold Trader Pro X"
#define EA_VERSION        "2.00"
#define MAX_RETRIES       3
#define RETRY_DELAY_MS    500

//+------------------------------------------------------------------+
//| Enumerations                                                       |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
   TREND_BULLISH = 1,
   TREND_BEARISH = -1,
   TREND_RANGE   = 0
};

enum ENUM_SIGNAL_TYPE
{
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1,
   SIGNAL_NONE = 0
};

//+------------------------------------------------------------------+
//| Structures                                                         |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double   price;
   datetime time;
   int      bar_index;
   bool     is_high;
};

struct BOSInfo
{
   bool              valid;
   ENUM_TREND_DIRECTION direction;
   double            level;
   datetime          time;
   int               bar_index;
   bool              has_displacement;
};

struct OrderBlockInfo
{
   bool              valid;
   ENUM_TREND_DIRECTION direction;
   double            high;
   double            low;
   datetime          time;
   int               bar_index;
   bool              mitigated;
};

struct FVGInfo
{
   bool              valid;
   ENUM_TREND_DIRECTION direction;
   double            upper;
   double            lower;
   datetime          time;
   int               bar_index;
   int               age;
   bool              filled;
};

//+------------------------------------------------------------------+
//| Input Parameters                                                    |
//+------------------------------------------------------------------+

//--- General
input group "=== General Settings ==="
input int      inp_MagicNumber      = 20260001;     // Magic Number
input string   inp_TradeComment     = "IGTP_X";     // Trade Comment

//--- Structure Detection
input group "=== Market Structure ==="
input int      inp_Swing_Left       = 2;            // Swing Lookback Left
input int      inp_Swing_Right      = 2;            // Swing Lookback Right
input int      inp_Swing_MaxScan    = 100;          // Max Bars to Scan

//--- Liquidity
input group "=== Liquidity Detection ==="
input int      inp_Liq_Lookback     = 15;           // Liquidity Sweep Lookback
input int      inp_Liq_EqTolerance  = 30;           // Equal Level Tolerance (pts)
input int      inp_Liq_MinWick      = 5;            // Min Wick Penetration (pts)

//--- Order Block
input group "=== Order Block ==="
input int      inp_OB_MaxLookback   = 20;           // OB Max Lookback Bars
input double   inp_OB_MinDisplace   = 60.0;         // OB Min Displacement %

//--- FVG
input group "=== Fair Value Gap ==="
input bool     inp_FVG_Enabled      = true;         // Enable FVG Filter
input int      inp_FVG_MinSize      = 30;           // Min FVG Size (pts)
input int      inp_FVG_MaxAge       = 10;           // Max FVG Age (bars)

//--- Trend Filter
input group "=== Trend Filter ==="
input int      inp_EMA_Period       = 200;          // EMA Period

//--- ATR/ADX Filters
input group "=== Volatility & Strength ==="
input int      inp_ATR_Period       = 14;           // ATR Period
input double   inp_ATR_MinPct       = 80.0;         // Min ATR % of Average
input int      inp_ADX_Period       = 14;           // ADX Period
input double   inp_ADX_Min          = 25.0;         // Minimum ADX

//--- Spread
input group "=== Spread Filter ==="
input int      inp_MaxSpread        = 30;           // Max Spread (pts)
input int      inp_MaxSlippage      = 10;           // Max Slippage (pts)

//--- Risk Management
input group "=== Risk Management ==="
input double   inp_Risk_Percent     = 0.25;         // Risk % Per Trade
input double   inp_Risk_MaxLot      = 0.05;         // Max Lot Size
input double   inp_Risk_MaxMargin   = 60.0;         // Max Margin Usage %
input double   inp_SL_ATRBuffer     = 0.30;         // SL ATR Buffer Factor
input double   inp_RR_Ratio         = 2.0;          // Risk:Reward Ratio

//--- Trade Management
input group "=== Trade Management ==="
input double   inp_BE_TriggerR      = 1.0;          // Break-Even Trigger (xR)
input int      inp_BE_Buffer        = 10;           // Break-Even Buffer (pts)
input double   inp_Trail_TriggerR   = 1.5;          // Trail Start Trigger (xR)
input double   inp_Trail_ATRMult    = 1.0;          // Trail ATR Multiplier
input int      inp_Trail_Step       = 10;           // Trail Min Step (pts)

//--- Protection
input group "=== Account Protection ==="
input int      inp_Prot_MaxTrades   = 2;            // Max Trades Per Day
input int      inp_Prot_MaxConsec   = 3;            // Max Consecutive Losses
input double   inp_Prot_DailyLoss   = 1.25;         // Daily Loss Limit %
input double   inp_Prot_DailyProfit = 1.50;         // Daily Profit Target %
input double   inp_Prot_MaxDD       = 6.0;          // Overall Max Drawdown %
input double   inp_Prot_EvalBalance = 5000.0;       // Evaluation Balance
input bool     inp_Prot_Reset       = false;        // Reset Permanent Stop

//--- Session
input group "=== Session Filter ==="
input string   inp_Ses_LondonStart  = "08:00";      // London Start
input string   inp_Ses_LondonEnd    = "12:00";      // London End
input string   inp_Ses_NYStart      = "13:00";      // New York Start
input string   inp_Ses_NYEnd        = "20:00";      // New York End
input string   inp_Ses_FridayStop   = "18:00";      // Friday Cutoff

//--- News
input group "=== News Filter ==="
input bool     inp_News_Enabled     = true;         // Enable News Filter
input int      inp_News_MinsBefore  = 30;           // Block Mins Before News
input int      inp_News_MinsAfter   = 30;           // Block Mins After News

//--- Day Reset
input group "=== Day Reset ==="
input int      inp_Day_ResetHour    = 22;           // Reset Hour (Server)
input int      inp_Day_ResetMinute  = 0;            // Reset Minute

//--- Display
input group "=== Display & Logging ==="
input bool     inp_ShowDash         = true;         // Show Dashboard
input bool     inp_LogEntries       = true;         // Log Entries
input bool     inp_LogExits         = true;         // Log Exits
input bool     inp_LogRejects       = true;         // Log Rejections
input bool     inp_LogErrors        = true;         // Log Errors

//+------------------------------------------------------------------+
//| Global Variables                                                    |
//+------------------------------------------------------------------+

// Indicator handles
int      h_EMA_M15    = INVALID_HANDLE;
int      h_EMA_H1     = INVALID_HANDLE;
int      h_ATR_M15    = INVALID_HANDLE;
int      h_ADX_M15    = INVALID_HANDLE;

// Trade objects
CTrade         g_trade;
CPositionInfo  g_position;

// New bar detection
datetime g_last_bar_time_m5 = 0;

// Swing point arrays
SwingPoint g_swing_highs_m15[];
SwingPoint g_swing_lows_m15[];
SwingPoint g_swing_highs_h1[];
SwingPoint g_swing_lows_h1[];
SwingPoint g_swing_highs_m5[];
SwingPoint g_swing_lows_m5[];

// Trend state
ENUM_TREND_DIRECTION g_trend_h1  = TREND_RANGE;
ENUM_TREND_DIRECTION g_trend_m15 = TREND_RANGE;
ENUM_TREND_DIRECTION g_trend_m5  = TREND_RANGE;

// BOS state
BOSInfo g_last_bos;

// Order Block state
OrderBlockInfo g_bullish_ob;
OrderBlockInfo g_bearish_ob;

// FVG state
FVGInfo g_bullish_fvg;
FVGInfo g_bearish_fvg;

// Trade state
bool     g_has_position      = false;
bool     g_be_applied        = false;
bool     g_trail_active      = false;
double   g_entry_price       = 0;
double   g_original_sl       = 0;
double   g_sl_distance       = 0;
ulong    g_ticket            = 0;
ENUM_POSITION_TYPE g_pos_type;
datetime g_entry_time        = 0;
int      g_entry_bar         = 0;

// Protection state
double   g_daily_start_balance = 0;
int      g_daily_trade_count   = 0;
int      g_consec_losses       = 0;
int      g_daily_wins          = 0;
int      g_daily_losses        = 0;
bool     g_daily_stop          = false;
bool     g_permanent_stop      = false;
int      g_last_reset_day      = -1;

// Liquidity state
bool     g_sell_side_swept   = false;
bool     g_buy_side_swept    = false;

// Dashboard state
string   g_last_signal       = "None";
string   g_last_reject       = "None";
string   g_ea_status         = "INITIALIZING";
bool     g_prev_had_position = false;

//+------------------------------------------------------------------+
//| Utility Functions                                                   |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size == 0) return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathRound(price / tick_size) * tick_size, _Digits);
}

double NormalizeVolume(double volume)
{
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lot_min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot_max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lot_step == 0) lot_step = 0.01;
   volume = MathFloor(volume / lot_step) * lot_step;
   volume = MathMax(lot_min, MathMin(volume, lot_max));
   return NormalizeDouble(volume, 2);
}

double GetMinStopDistance()
{
   int stops_level  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int min_level = MathMax(stops_level, freeze_level);
   if(min_level == 0) min_level = 10;
   return min_level * point;
}

int ParseTimeString(const string time_str)
{
   int colon_pos = StringFind(time_str, ":");
   if(colon_pos < 0) return -1;
   int hour = (int)StringToInteger(StringSubstr(time_str, 0, colon_pos));
   int minute = (int)StringToInteger(StringSubstr(time_str, colon_pos + 1));
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59) return -1;
   return hour * 60 + minute;
}

bool IsValidSymbol()
{
   if(StringFind(_Symbol, "XAUUSD") >= 0) return true;
   if(StringFind(_Symbol, "GOLD") >= 0)   return true;
   return false;
}

bool IsNewBarM5()
{
   datetime current_bar_time = iTime(_Symbol, PERIOD_M5, 0);
   if(current_bar_time == 0) return false;
   if(g_last_bar_time_m5 == 0) { g_last_bar_time_m5 = current_bar_time; return false; }
   if(current_bar_time != g_last_bar_time_m5)
   {
      g_last_bar_time_m5 = current_bar_time;
      return true;
   }
   return false;
}

double GetBodyPercent(double open, double high, double low, double close)
{
   double range = high - low;
   if(range <= 0) return 0;
   return (MathAbs(close - open) / range) * 100.0;
}

double GetClosePosition(double high, double low, double close)
{
   double range = high - low;
   if(range <= 0) return 50.0;
   return ((close - low) / range) * 100.0;
}

//+------------------------------------------------------------------+
//| Swing Detection                                                    |
//+------------------------------------------------------------------+
bool DetectSwings(ENUM_TIMEFRAMES tf, SwingPoint &highs[], SwingPoint &lows[])
{
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, inp_Swing_MaxScan, rates);
   if(copied < inp_Swing_Left + inp_Swing_Right + 1) return false;
   
   for(int i = inp_Swing_Right; i < copied - inp_Swing_Left; i++)
   {
      // Swing High
      bool is_sh = true;
      for(int j = 1; j <= inp_Swing_Right; j++)
         if(i - j < 0 || rates[i - j].high >= rates[i].high) { is_sh = false; break; }
      if(is_sh)
         for(int j = 1; j <= inp_Swing_Left; j++)
            if(i + j >= copied || rates[i + j].high >= rates[i].high) { is_sh = false; break; }
      
      if(is_sh)
      {
         int sz = ArraySize(highs);
         ArrayResize(highs, sz + 1);
         highs[sz].price = rates[i].high;
         highs[sz].time = rates[i].time;
         highs[sz].bar_index = i;
         highs[sz].is_high = true;
      }
      
      // Swing Low
      bool is_sl = true;
      for(int j = 1; j <= inp_Swing_Right; j++)
         if(i - j < 0 || rates[i - j].low <= rates[i].low) { is_sl = false; break; }
      if(is_sl)
         for(int j = 1; j <= inp_Swing_Left; j++)
            if(i + j >= copied || rates[i + j].low <= rates[i].low) { is_sl = false; break; }
      
      if(is_sl)
      {
         int sz = ArraySize(lows);
         ArrayResize(lows, sz + 1);
         lows[sz].price = rates[i].low;
         lows[sz].time = rates[i].time;
         lows[sz].bar_index = i;
         lows[sz].is_high = false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Trend Detection (from swings)                                      |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION DetermineTrend(SwingPoint &highs[], SwingPoint &lows[])
{
   if(ArraySize(highs) < 2 || ArraySize(lows) < 2) return TREND_RANGE;
   
   bool hh = highs[0].price > highs[1].price;
   bool hl = lows[0].price > lows[1].price;
   bool lh = highs[0].price < highs[1].price;
   bool ll = lows[0].price < lows[1].price;
   
   if(hh && hl) return TREND_BULLISH;
   if(lh && ll) return TREND_BEARISH;
   return TREND_RANGE;
}

//+------------------------------------------------------------------+
//| BOS Detection                                                      |
//+------------------------------------------------------------------+
bool DetectBOS()
{
   g_last_bos.valid = false;
   
   if(ArraySize(g_swing_highs_m15) < 1 || ArraySize(g_swing_lows_m15) < 1)
      return false;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 20, rates) < 5) return false;
   
   for(int i = 1; i < 6; i++)
   {
      // Bullish BOS
      if(rates[i].close > g_swing_highs_m15[0].price && rates[i].close > rates[i].open)
      {
         double body_pct = GetBodyPercent(rates[i].open, rates[i].high, rates[i].low, rates[i].close);
         g_last_bos.valid = true;
         g_last_bos.direction = TREND_BULLISH;
         g_last_bos.level = g_swing_highs_m15[0].price;
         g_last_bos.time = rates[i].time;
         g_last_bos.bar_index = i;
         g_last_bos.has_displacement = (body_pct >= inp_OB_MinDisplace);
         return true;
      }
      
      // Bearish BOS
      if(rates[i].close < g_swing_lows_m15[0].price && rates[i].close < rates[i].open)
      {
         double body_pct = GetBodyPercent(rates[i].open, rates[i].high, rates[i].low, rates[i].close);
         g_last_bos.valid = true;
         g_last_bos.direction = TREND_BEARISH;
         g_last_bos.level = g_swing_lows_m15[0].price;
         g_last_bos.time = rates[i].time;
         g_last_bos.bar_index = i;
         g_last_bos.has_displacement = (body_pct >= inp_OB_MinDisplace);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Liquidity Sweep Detection                                          |
//+------------------------------------------------------------------+
void DetectLiquiditySweep()
{
   g_sell_side_swept = false;
   g_buy_side_swept = false;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, inp_Liq_Lookback + 5, rates) < 5) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double min_wick = inp_Liq_MinWick * point;
   
   // Sell-side sweep (for BUY)
   if(ArraySize(g_swing_lows_m15) > 0)
   {
      double sl_level = g_swing_lows_m15[0].price;
      for(int i = 1; i < MathMin(inp_Liq_Lookback, ArraySize(rates)); i++)
      {
         if(rates[i].low < sl_level - min_wick && rates[i].close > sl_level)
         {
            g_sell_side_swept = true;
            break;
         }
      }
   }
   
   // Buy-side sweep (for SELL)
   if(ArraySize(g_swing_highs_m15) > 0)
   {
      double sh_level = g_swing_highs_m15[0].price;
      for(int i = 1; i < MathMin(inp_Liq_Lookback, ArraySize(rates)); i++)
      {
         if(rates[i].high > sh_level + min_wick && rates[i].close < sh_level)
         {
            g_buy_side_swept = true;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Order Block Detection                                              |
//+------------------------------------------------------------------+
void DetectOrderBlocks()
{
   g_bullish_ob.valid = false;
   g_bearish_ob.valid = false;
   
   if(!g_last_bos.valid || !g_last_bos.has_displacement) return;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, inp_OB_MaxLookback + 5, rates) < 5) return;
   
   int bos_bar = g_last_bos.bar_index;
   int bars_count = ArraySize(rates);
   
   if(g_last_bos.direction == TREND_BULLISH)
   {
      // Find last bearish candle before BOS
      for(int i = bos_bar + 1; i < MathMin(bos_bar + 10, bars_count); i++)
      {
         if(rates[i].close < rates[i].open) // bearish
         {
            g_bullish_ob.valid = true;
            g_bullish_ob.direction = TREND_BULLISH;
            g_bullish_ob.high = rates[i].high;
            g_bullish_ob.low = rates[i].low;
            g_bullish_ob.time = rates[i].time;
            g_bullish_ob.bar_index = i;
            g_bullish_ob.mitigated = false;
            // Check mitigation
            for(int k = i - 1; k >= 1; k--)
               if(rates[k].close < g_bullish_ob.low) { g_bullish_ob.mitigated = true; g_bullish_ob.valid = false; break; }
            break;
         }
      }
   }
   else if(g_last_bos.direction == TREND_BEARISH)
   {
      for(int i = bos_bar + 1; i < MathMin(bos_bar + 10, bars_count); i++)
      {
         if(rates[i].close > rates[i].open) // bullish
         {
            g_bearish_ob.valid = true;
            g_bearish_ob.direction = TREND_BEARISH;
            g_bearish_ob.high = rates[i].high;
            g_bearish_ob.low = rates[i].low;
            g_bearish_ob.time = rates[i].time;
            g_bearish_ob.bar_index = i;
            g_bearish_ob.mitigated = false;
            for(int k = i - 1; k >= 1; k--)
               if(rates[k].close > g_bearish_ob.high) { g_bearish_ob.mitigated = true; g_bearish_ob.valid = false; break; }
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FVG Detection                                                      |
//+------------------------------------------------------------------+
void DetectFVG()
{
   g_bullish_fvg.valid = false;
   g_bearish_fvg.valid = false;
   if(!inp_FVG_Enabled) return;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, inp_FVG_MaxAge + 5, rates) < 4) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double min_gap = inp_FVG_MinSize * point;
   
   for(int i = 1; i < ArraySize(rates) - 2; i++)
   {
      if(i > inp_FVG_MaxAge) break;
      
      // Bullish FVG
      if(rates[i].low > rates[i + 2].high && !g_bullish_fvg.valid)
      {
         double gap = rates[i].low - rates[i + 2].high;
         if(gap >= min_gap)
         {
            g_bullish_fvg.valid = true;
            g_bullish_fvg.direction = TREND_BULLISH;
            g_bullish_fvg.upper = rates[i].low;
            g_bullish_fvg.lower = rates[i + 2].high;
            g_bullish_fvg.time = rates[i + 1].time;
            g_bullish_fvg.bar_index = i + 1;
            g_bullish_fvg.age = i;
            g_bullish_fvg.filled = false;
            // Check if filled
            for(int k = i - 1; k >= 1; k--)
               if(rates[k].close < g_bullish_fvg.lower) { g_bullish_fvg.valid = false; g_bullish_fvg.filled = true; break; }
         }
      }
      
      // Bearish FVG
      if(rates[i + 2].low > rates[i].high && !g_bearish_fvg.valid)
      {
         double gap = rates[i + 2].low - rates[i].high;
         if(gap >= min_gap)
         {
            g_bearish_fvg.valid = true;
            g_bearish_fvg.direction = TREND_BEARISH;
            g_bearish_fvg.upper = rates[i + 2].low;
            g_bearish_fvg.lower = rates[i].high;
            g_bearish_fvg.time = rates[i + 1].time;
            g_bearish_fvg.bar_index = i + 1;
            g_bearish_fvg.age = i;
            g_bearish_fvg.filled = false;
            for(int k = i - 1; k >= 1; k--)
               if(rates[k].close > g_bearish_fvg.upper) { g_bearish_fvg.valid = false; g_bearish_fvg.filled = true; break; }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Filter Checks                                                      |
//+------------------------------------------------------------------+
bool CheckEMAFilter(ENUM_SIGNAL_TYPE signal)
{
   double ema[];
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(h_EMA_M15, 0, 1, 1, ema) < 1) return false;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 1, 1, rates) < 1) return false;
   
   if(signal == SIGNAL_BUY && rates[0].close > ema[0]) return true;
   if(signal == SIGNAL_SELL && rates[0].close < ema[0]) return true;
   return false;
}

bool CheckATRFilter(double &atr_value)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(h_ATR_M15, 0, 1, 20, atr) < 20) return false;
   
   atr_value = atr[0];
   double avg = 0;
   for(int i = 0; i < 20; i++) avg += atr[i];
   avg /= 20.0;
   
   return (atr_value >= avg * (inp_ATR_MinPct / 100.0));
}

bool CheckADXFilter(double &adx_value)
{
   double adx[];
   ArraySetAsSeries(adx, true);
   if(CopyBuffer(h_ADX_M15, 0, 1, 1, adx) < 1) return false;
   adx_value = adx[0];
   return (adx_value >= inp_ADX_Min);
}

bool CheckSpread()
{
   return ((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= inp_MaxSpread);
}

bool CheckSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int mins = dt.hour * 60 + dt.min;
   
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   if(dt.day_of_week == 5 && mins >= ParseTimeString(inp_Ses_FridayStop)) return false;
   
   bool london = (mins >= ParseTimeString(inp_Ses_LondonStart) && mins < ParseTimeString(inp_Ses_LondonEnd));
   bool ny = (mins >= ParseTimeString(inp_Ses_NYStart) && mins < ParseTimeString(inp_Ses_NYEnd));
   
   return (london || ny);
}

bool CheckNews()
{
   if(!inp_News_Enabled) return true;
   
   datetime now = TimeCurrent();
   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, now - inp_News_MinsAfter * 60, now + inp_News_MinsBefore * 60);
   if(count <= 0) return true;
   
   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event)) continue;
      if(event.importance != CALENDAR_IMPORTANCE_HIGH) continue;
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country)) continue;
      if(country.currency != "USD") continue;
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Protection Engine                                                  |
//+------------------------------------------------------------------+
void CheckDayReset()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int mins = dt.hour * 60 + dt.min;
   int reset_mins = inp_Day_ResetHour * 60 + inp_Day_ResetMinute;
   
   if(dt.day != g_last_reset_day && mins >= reset_mins)
   {
      g_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_daily_trade_count = 0;
      g_consec_losses = 0;
      g_daily_wins = 0;
      g_daily_losses = 0;
      g_daily_stop = false;
      g_last_reset_day = dt.day;
   }
}

bool IsProtectionOK(string &reason)
{
   if(g_permanent_stop) { reason = "PERMANENT STOP"; return false; }
   if(g_daily_stop) { reason = "Daily stop"; return false; }
   if(g_daily_trade_count >= inp_Prot_MaxTrades) { reason = "Max trades"; g_daily_stop = true; return false; }
   if(g_consec_losses >= inp_Prot_MaxConsec) { reason = "Consec losses"; g_daily_stop = true; return false; }
   
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double pnl = bal - g_daily_start_balance;
   
   if(g_daily_start_balance > 0 && pnl < 0)
   {
      double loss_pct = MathAbs(pnl) / g_daily_start_balance * 100.0;
      if(loss_pct >= inp_Prot_DailyLoss) { reason = "Daily loss limit"; g_daily_stop = true; return false; }
   }
   if(g_daily_start_balance > 0 && pnl > 0)
   {
      double profit_pct = pnl / g_daily_start_balance * 100.0;
      if(profit_pct >= inp_Prot_DailyProfit) { reason = "Daily profit lock"; g_daily_stop = true; return false; }
   }
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double eval_bal = (inp_Prot_EvalBalance > 0) ? inp_Prot_EvalBalance : g_daily_start_balance;
   if(eval_bal > 0)
   {
      double dd = (eval_bal - equity) / eval_bal * 100.0;
      if(dd >= inp_Prot_MaxDD) { reason = "Overall DD"; g_permanent_stop = true; return false; }
   }
   
   reason = "";
   return true;
}

//+------------------------------------------------------------------+
//| Confirmation Candle (M5)                                           |
//+------------------------------------------------------------------+
bool HasConfirmationCandle(ENUM_SIGNAL_TYPE signal)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 2, rates) < 2) return false;
   
   if(signal == SIGNAL_BUY)
   {
      if(rates[0].close <= rates[0].open) return false;
      double body_pct = GetBodyPercent(rates[0].open, rates[0].high, rates[0].low, rates[0].close);
      double close_pos = GetClosePosition(rates[0].high, rates[0].low, rates[0].close);
      bool engulf = (rates[0].close > rates[1].open && rates[0].open < rates[1].close && body_pct >= 50.0);
      bool strong = (body_pct >= 60.0 && close_pos >= 70.0);
      return (engulf || strong);
   }
   else
   {
      if(rates[0].close >= rates[0].open) return false;
      double body_pct = GetBodyPercent(rates[0].open, rates[0].high, rates[0].low, rates[0].close);
      double close_pos = GetClosePosition(rates[0].high, rates[0].low, rates[0].close);
      bool engulf = (rates[0].close < rates[1].open && rates[0].open > rates[1].close && body_pct >= 50.0);
      bool strong = (body_pct >= 60.0 && close_pos <= 30.0);
      return (engulf || strong);
   }
}

//+------------------------------------------------------------------+
//| Trade Management (BE + Trail)                                      |
//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!g_has_position) return;
   
   // Check position exists
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_position.SelectByIndex(i) && g_position.Symbol() == _Symbol && g_position.Magic() == inp_MagicNumber)
      { found = true; g_ticket = g_position.Ticket(); break; }
   
   if(!found) { g_has_position = false; return; }
   
   // Spread spike - don't modify
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > inp_MaxSpread * 2) return;
   
   // Get current profit in R
   double profit_r = 0;
   if(g_sl_distance > 0)
   {
      if(g_pos_type == POSITION_TYPE_BUY)
         profit_r = (SymbolInfoDouble(_Symbol, SYMBOL_BID) - g_entry_price) / g_sl_distance;
      else
         profit_r = (g_entry_price - SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / g_sl_distance;
   }
   
   // Break-Even
   if(!g_be_applied && profit_r >= inp_BE_TriggerR)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double new_sl = (g_pos_type == POSITION_TYPE_BUY) ? 
                      g_entry_price + inp_BE_Buffer * point :
                      g_entry_price - inp_BE_Buffer * point;
      new_sl = NormalizePrice(new_sl);
      double cur_sl = g_position.StopLoss();
      
      bool should_modify = (g_pos_type == POSITION_TYPE_BUY) ? (new_sl > cur_sl) : (new_sl < cur_sl);
      if(should_modify && g_trade.PositionModify(g_ticket, new_sl, g_position.TakeProfit()))
      {
         g_be_applied = true;
         if(inp_LogEntries) Print("[BE] Break-even set at ", new_sl);
      }
   }
   
   // Trailing
   if(g_be_applied && profit_r >= inp_Trail_TriggerR)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(h_ATR_M15, 0, 1, 1, atr) < 1) return;
      
      double trail_dist = atr[0] * inp_Trail_ATRMult;
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double min_step = inp_Trail_Step * point;
      double cur_sl = g_position.StopLoss();
      double new_sl = 0;
      
      if(g_pos_type == POSITION_TYPE_BUY)
      {
         new_sl = NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - trail_dist);
         if(new_sl > cur_sl + min_step)
            g_trade.PositionModify(g_ticket, new_sl, g_position.TakeProfit());
      }
      else
      {
         new_sl = NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trail_dist);
         if(new_sl < cur_sl - min_step)
            g_trade.PositionModify(g_ticket, new_sl, g_position.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Entry                                                      |
//+------------------------------------------------------------------+
void ExecuteEntry(ENUM_SIGNAL_TYPE signal, double zone_high, double zone_low)
{
   double atr_val = 0;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(h_ATR_M15, 0, 1, 1, atr) < 1) return;
   atr_val = atr[0];
   
   double entry = (signal == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculate SL
   double sl = 0;
   double buffer = atr_val * inp_SL_ATRBuffer;
   if(signal == SIGNAL_BUY)
   {
      double swing_level = (ArraySize(g_swing_lows_m15) > 0) ? g_swing_lows_m15[0].price : zone_low;
      sl = swing_level - buffer;
   }
   else
   {
      double swing_level = (ArraySize(g_swing_highs_m15) > 0) ? g_swing_highs_m15[0].price : zone_high;
      sl = swing_level + buffer;
   }
   
   // Validate SL distance
   double min_dist = GetMinStopDistance();
   if(MathAbs(entry - sl) < min_dist)
      sl = (signal == SIGNAL_BUY) ? entry - min_dist - 10 * _Point : entry + min_dist + 10 * _Point;
   sl = NormalizePrice(sl);
   
   // Calculate TP
   double sl_dist = MathAbs(entry - sl);
   double tp = (signal == SIGNAL_BUY) ? entry + sl_dist * inp_RR_Ratio : entry - sl_dist * inp_RR_Ratio;
   tp = NormalizePrice(tp);
   
   // Calculate Lot
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * (inp_Risk_Percent / 100.0);
   double sl_points = sl_dist / _Point;
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_val <= 0 || tick_size <= 0 || sl_points <= 0) return;
   
   double cost_per_point = (tick_val / tick_size) * _Point;
   double lot = risk_amount / (sl_points * cost_per_point);
   lot = NormalizeVolume(lot);
   lot = MathMin(lot, inp_Risk_MaxLot);
   if(lot <= 0) return;
   
   // Margin check
   double margin_req = 0;
   ENUM_ORDER_TYPE ot = (signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(ot, _Symbol, lot, entry, margin_req)) return;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > 0 && (margin_req / eq * 100.0) > inp_Risk_MaxMargin) return;
   
   // Final spread check
   if(!CheckSpread()) return;
   
   // Execute
   bool success = false;
   for(int i = 0; i < MAX_RETRIES && !success; i++)
   {
      if(signal == SIGNAL_BUY)
         success = g_trade.Buy(lot, _Symbol, 0, sl, tp, inp_TradeComment);
      else
         success = g_trade.Sell(lot, _Symbol, 0, sl, tp, inp_TradeComment);
      
      if(!success)
      {
         int err = (int)g_trade.ResultRetcode();
         if(inp_LogErrors) Print("[ERROR] Trade failed: ", err, " - ", g_trade.ResultRetcodeDescription());
         if(err == TRADE_RETCODE_NO_MONEY || err == TRADE_RETCODE_MARKET_CLOSED) break;
         Sleep(RETRY_DELAY_MS);
      }
   }
   
   if(success)
   {
      g_has_position = true;
      g_be_applied = false;
      g_trail_active = false;
      g_entry_price = entry;
      g_original_sl = sl;
      g_sl_distance = sl_dist;
      g_ticket = g_trade.ResultOrder();
      g_pos_type = (signal == SIGNAL_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      g_entry_time = TimeCurrent();
      g_entry_bar = iBars(_Symbol, PERIOD_M5);
      
      string dir = (signal == SIGNAL_BUY) ? "BUY" : "SELL";
      g_last_signal = StringFormat("%s @ %.2f", dir, entry);
      g_ea_status = "IN TRADE";
      if(inp_LogEntries)
         Print(StringFormat("[ENTRY] %s | Price=%.5f | SL=%.5f | TP=%.5f | Lot=%.2f", dir, entry, sl, tp, lot));
   }
}

//+------------------------------------------------------------------+
//| Main Signal Logic                                                  |
//+------------------------------------------------------------------+
void LookForEntry()
{
   // Filters
   double atr_val = 0, adx_val = 0;
   if(!CheckSpread()) { g_last_reject = "Spread"; return; }
   if(!CheckATRFilter(atr_val)) { g_last_reject = "ATR low"; return; }
   if(!CheckADXFilter(adx_val)) { g_last_reject = StringFormat("ADX=%.1f", adx_val); return; }
   
   // Update structure
   DetectSwings(PERIOD_H1, g_swing_highs_h1, g_swing_lows_h1);
   DetectSwings(PERIOD_M15, g_swing_highs_m15, g_swing_lows_m15);
   DetectSwings(PERIOD_M5, g_swing_highs_m5, g_swing_lows_m5);
   
   g_trend_h1 = DetermineTrend(g_swing_highs_h1, g_swing_lows_h1);
   g_trend_m15 = DetermineTrend(g_swing_highs_m15, g_swing_lows_m15);
   g_trend_m5 = DetermineTrend(g_swing_highs_m5, g_swing_lows_m5);
   
   // Multi-TF alignment
   if(g_trend_h1 != g_trend_m15 || g_trend_m15 != g_trend_m5 || g_trend_h1 == TREND_RANGE)
   { g_last_reject = "MTF not aligned"; return; }
   
   ENUM_SIGNAL_TYPE signal = (g_trend_h1 == TREND_BULLISH) ? SIGNAL_BUY : SIGNAL_SELL;
   
   // EMA filter
   if(!CheckEMAFilter(signal)) { g_last_reject = "EMA filter"; return; }
   
   // BOS
   if(!DetectBOS() || !g_last_bos.valid || !g_last_bos.has_displacement)
   { g_last_reject = "No valid BOS"; return; }
   if(g_last_bos.direction != g_trend_h1) { g_last_reject = "BOS mismatch"; return; }
   
   // Liquidity sweep
   DetectLiquiditySweep();
   if(signal == SIGNAL_BUY && !g_sell_side_swept) { g_last_reject = "No sell-side sweep"; return; }
   if(signal == SIGNAL_SELL && !g_buy_side_swept) { g_last_reject = "No buy-side sweep"; return; }
   
   // Order Block
   DetectOrderBlocks();
   double ob_high = 0, ob_low = 0;
   if(signal == SIGNAL_BUY && g_bullish_ob.valid) { ob_high = g_bullish_ob.high; ob_low = g_bullish_ob.low; }
   else if(signal == SIGNAL_SELL && g_bearish_ob.valid) { ob_high = g_bearish_ob.high; ob_low = g_bearish_ob.low; }
   else { g_last_reject = "No Order Block"; return; }
   
   // FVG
   DetectFVG();
   double zone_high = ob_high, zone_low = ob_low;
   if(inp_FVG_Enabled)
   {
      if(signal == SIGNAL_BUY && g_bullish_fvg.valid)
      { zone_high = MathMax(ob_high, g_bullish_fvg.upper); zone_low = MathMin(ob_low, g_bullish_fvg.lower); }
      else if(signal == SIGNAL_SELL && g_bearish_fvg.valid)
      { zone_high = MathMax(ob_high, g_bearish_fvg.upper); zone_low = MathMin(ob_low, g_bearish_fvg.lower); }
      else { g_last_reject = "No FVG"; return; }
   }
   
   // Price in zone
   MqlRates m5r[];
   ArraySetAsSeries(m5r, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, m5r) < 1) return;
   double close_price = m5r[0].close;
   if(close_price < zone_low || close_price > zone_high) { g_last_reject = "Not in zone"; return; }
   
   // Confirmation candle
   if(!HasConfirmationCandle(signal)) { g_last_reject = "No confirmation"; return; }
   
   // ALL CONDITIONS MET
   ExecuteEntry(signal, zone_high, zone_low);
}

//+------------------------------------------------------------------+
//| Handle Position Closed                                             |
//+------------------------------------------------------------------+
void OnPositionClosed()
{
   HistorySelect(g_entry_time, TimeCurrent());
   int total = HistoryDealsTotal();
   double profit = 0;
   bool is_win = false;
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == inp_MagicNumber &&
         HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         is_win = (profit > 0);
         break;
      }
   }
   
   g_daily_trade_count++;
   if(is_win) { g_daily_wins++; g_consec_losses = 0; }
   else { g_daily_losses++; g_consec_losses++; }
   
   if(inp_LogExits)
      Print(StringFormat("[EXIT] Profit=%.2f | %s | Consec Loss=%d", profit, is_win ? "WIN" : "LOSS", g_consec_losses));
   
   g_has_position = false;
   g_be_applied = false;
   g_trail_active = false;
   g_ea_status = "RUNNING";
}

//+------------------------------------------------------------------+
//| Dashboard                                                          |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!inp_ShowDash) return;
   
   double pnl = AccountInfoDouble(ACCOUNT_BALANCE) - g_daily_start_balance;
   double pnl_pct = (g_daily_start_balance > 0) ? pnl / g_daily_start_balance * 100.0 : 0;
   double eval_bal = (inp_Prot_EvalBalance > 0) ? inp_Prot_EvalBalance : g_daily_start_balance;
   double dd_pct = (eval_bal > 0) ? (eval_bal - AccountInfoDouble(ACCOUNT_EQUITY)) / eval_bal * 100.0 : 0;
   
   string dash = "";
   dash += "====================================\n";
   dash += "  INSTITUTIONAL GOLD TRADER PRO X\n";
   dash += "====================================\n";
   dash += "Status:    " + g_ea_status + "\n";
   dash += StringFormat("H1:  %s | M15: %s | M5: %s\n",
           g_trend_h1==TREND_BULLISH?"BULL":(g_trend_h1==TREND_BEARISH?"BEAR":"RANGE"),
           g_trend_m15==TREND_BULLISH?"BULL":(g_trend_m15==TREND_BEARISH?"BEAR":"RANGE"),
           g_trend_m5==TREND_BULLISH?"BULL":(g_trend_m5==TREND_BEARISH?"BEAR":"RANGE"));
   dash += StringFormat("Spread: %d/%d | ADX: -- | ATR: --\n", (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), inp_MaxSpread);
   dash += "------------------------------------\n";
   dash += StringFormat("P/L: $%.2f (%.2f%%)\n", pnl, pnl_pct);
   dash += StringFormat("Trades: %d/%d | Loss: %d/%d\n", g_daily_trade_count, inp_Prot_MaxTrades, g_consec_losses, inp_Prot_MaxConsec);
   dash += StringFormat("DD: %.2f%% / %.2f%%\n", dd_pct, inp_Prot_MaxDD);
   dash += "------------------------------------\n";
   dash += "Signal: " + g_last_signal + "\n";
   dash += "Reject: " + g_last_reject + "\n";
   dash += "====================================\n";
   
   Comment(dash);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!IsValidSymbol())
   {
      Print("ERROR: EA designed for XAUUSD only! Current: ", _Symbol);
      return INIT_FAILED;
   }
   
   // Create indicators
   h_EMA_M15 = iMA(_Symbol, PERIOD_M15, inp_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_EMA_H1  = iMA(_Symbol, PERIOD_H1, inp_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ATR_M15 = iATR(_Symbol, PERIOD_M15, inp_ATR_Period);
   h_ADX_M15 = iADX(_Symbol, PERIOD_M15, inp_ADX_Period);
   
   if(h_EMA_M15 == INVALID_HANDLE || h_EMA_H1 == INVALID_HANDLE ||
      h_ATR_M15 == INVALID_HANDLE || h_ADX_M15 == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return INIT_FAILED;
   }
   
   // Setup trade object
   g_trade.SetExpertMagicNumber(inp_MagicNumber);
   g_trade.SetDeviationInPoints(inp_MaxSlippage);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   // Initialize protection
   g_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(inp_Prot_Reset) g_permanent_stop = false;
   
   g_ea_status = "RUNNING";
   Print("[INFO] ", EA_NAME, " v", EA_VERSION, " initialized on ", _Symbol);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(h_EMA_M15 != INVALID_HANDLE) IndicatorRelease(h_EMA_M15);
   if(h_EMA_H1  != INVALID_HANDLE) IndicatorRelease(h_EMA_H1);
   if(h_ATR_M15 != INVALID_HANDLE) IndicatorRelease(h_ATR_M15);
   if(h_ADX_M15 != INVALID_HANDLE) IndicatorRelease(h_ADX_M15);
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Manage existing position every tick
   if(g_has_position)
      ManagePosition();
   
   // Detect position closed
   if(g_prev_had_position && !g_has_position)
      OnPositionClosed();
   g_prev_had_position = g_has_position;
   
   // New bar logic only
   if(!IsNewBarM5()) return;
   
   CheckDayReset();
   
   // If position exists, update dashboard and return
   if(g_has_position) { UpdateDashboard(); return; }
   
   // Protection check
   string block = "";
   if(!IsProtectionOK(block)) { g_ea_status = block; UpdateDashboard(); return; }
   
   // Session check
   if(!CheckSession()) { g_ea_status = "NO SESSION"; UpdateDashboard(); return; }
   
   // News check
   if(!CheckNews()) { g_ea_status = "NEWS BLOCK"; UpdateDashboard(); return; }
   
   // Look for entry
   g_ea_status = "SCANNING";
   LookForEntry();
   UpdateDashboard();
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                          Institutional_PropFirm_EA_V3.mq5          |
//|              Multi-Timeframe Breakout Retest EA                     |
//|              Prop Firm Risk-Controlled Version                      |
//+------------------------------------------------------------------+
#property copyright   "Institutional Prop Firm EA"
#property link        "https://github.com/mahamahagyaan-cpu/xau-smart-ea"
#property version     "3.00"
#property description "Multi-TF Breakout Retest - Prop Firm Compliant"
#property description "H1 Bias | M15 Structure | M5 Execution"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                    |
//+------------------------------------------------------------------+

input group "=== General ==="
input int         inp_Magic              = 30300001;    // Magic Number
input string      inp_Comment            = "PropV3";    // Trade Comment
input string      inp_Symbol             = "";          // Symbol Override (empty = current)

input group "=== Indicators ==="
input int         inp_EMA_Period         = 200;         // EMA Period (H1)
input int         inp_ATR_Period         = 14;          // ATR Period (M15)
input int         inp_ADX_Period         = 14;          // ADX Period (M15)
input double      inp_ADX_Min            = 20.0;        // Minimum ADX

input group "=== Structure ==="
input int         inp_SwingStrength      = 2;           // Swing Bars Left/Right
input int         inp_BOS_Lookback       = 30;          // BOS Lookback Bars (M15)
input double      inp_Retest_ATR_Mult    = 0.25;        // Retest Zone = ATR x This

input group "=== Entry ==="
input double      inp_MaxSL_ATR          = 2.0;         // Max SL = ATR x This
input double      inp_SL_Buffer_ATR      = 0.20;        // SL Buffer = ATR x This
input int         inp_MaxSpread          = 50;          // Max Spread (points)
input int         inp_Slippage           = 20;          // Max Slippage (points)

input group "=== Risk ==="
input double      inp_RiskPct            = 1.0;         // Risk % Per Trade
input double      inp_MaxLot             = 0.06;        // Max Lot Size
input double      inp_MaxMarginPct       = 77.0;        // Max Margin Usage %
input double      inp_StandardRR         = 1.5;         // Standard TP (xR)
input double      inp_StrongRR           = 2.0;         // Strong TP (xR)
input bool        inp_UseStrongRR        = false;       // Use Strong RR

input group "=== Trade Management ==="
input double      inp_ProtectR           = 0.8;         // Profit Protection Start (xR)
input double      inp_BE_R               = 1.0;         // Break-Even at (xR)
input double      inp_BE_Buffer          = 0.05;        // BE Buffer (xR above/below entry)
input double      inp_Trail_StartR       = 1.5;         // Trail Start (xR)
input double      inp_Trail_ATR_Mult     = 1.0;         // Trail Distance = ATR x This
input int         inp_MinHoldSec         = 120;         // Min Holding Time (seconds)

input group "=== Protection ==="
input double      inp_DailyLossStop      = 1.25;        // Daily Loss Stop %
input double      inp_EmergencyDD        = 9.90;        // Emergency DD % (permanent lock)
input double      inp_InitBalance        = 5000.0;      // Initial Reference Balance
input int         inp_MaxPositions       = 1;           // Max Open Positions
input bool        inp_ResetEmergency     = false;       // Manual Emergency Reset

input group "=== Cooldown ==="
input int         inp_Cool1_Mins         = 30;          // After 1 loss: cooldown (mins)
input int         inp_Cool2_Mins         = 120;         // After 2 losses: cooldown (mins)
input int         inp_Cool3_DayStop      = 1;           // After 3 losses: stop for day (1=yes)

input group "=== Sessions ==="
input int         inp_London_Start       = 8;           // London Start Hour
input int         inp_London_End         = 12;          // London End Hour
input int         inp_NY_Start           = 13;          // New York Start Hour
input int         inp_NY_End             = 20;          // New York End Hour
input bool        inp_AsiaEnabled        = true;        // Allow Asia Session

input group "=== Debug ==="
input bool        inp_Debug              = true;        // Print Debug Logs

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                    |
//+------------------------------------------------------------------+
CTrade         g_trade;
CPositionInfo  g_pos;
CSymbolInfo    g_sym;

// Indicator handles
int h_EMA_H1, h_ATR_M15, h_ADX_M15;

// New bar tracking
datetime g_lastBar_M5;
datetime g_lastBar_M15;

// Position state
bool   g_hasPosition;
double g_entryPrice;
double g_slDistance;
bool   g_beApplied;
bool   g_protectionApplied;
bool   g_trailActive;
ulong  g_ticket;
ENUM_POSITION_TYPE g_posType;
datetime g_entryTime;

// Daily tracking
double g_dayStartEquity;
int    g_dayTrades;
int    g_lastDay;
int    g_consecLosses;
datetime g_cooldownUntil;

// Emergency
bool   g_emergencyLock;

// Structure tracking
double g_lastSwingHigh;
double g_lastSwingLow;
double g_prevSwingHigh;
double g_prevSwingLow;
double g_bosLevel;
bool   g_bullishBOS;
bool   g_bearishBOS;
bool   g_retestDone;
double g_retestLevel;

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   string sym = (inp_Symbol == "") ? _Symbol : inp_Symbol;
   
   if(!g_sym.Name(sym))
   {
      Print("ERROR: Invalid symbol: ", sym);
      return INIT_FAILED;
   }
   
   // Create indicators on appropriate timeframes
   h_EMA_H1 = iMA(sym, PERIOD_H1, inp_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ATR_M15 = iATR(sym, PERIOD_M15, inp_ATR_Period);
   h_ADX_M15 = iADX(sym, PERIOD_M15, inp_ADX_Period);
   
   if(h_EMA_H1 == INVALID_HANDLE || h_ATR_M15 == INVALID_HANDLE || h_ADX_M15 == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles! Err=", GetLastError());
      return INIT_FAILED;
   }
   
   // Setup trade
   g_trade.SetExpertMagicNumber(inp_Magic);
   g_trade.SetDeviationInPoints(inp_Slippage);
   
   // Init state
   g_lastBar_M5 = 0;
   g_lastBar_M15 = 0;
   g_hasPosition = false;
   g_beApplied = false;
   g_protectionApplied = false;
   g_trailActive = false;
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayTrades = 0;
   g_lastDay = -1;
   g_consecLosses = 0;
   g_cooldownUntil = 0;
   g_bullishBOS = false;
   g_bearishBOS = false;
   g_retestDone = false;
   
   // Emergency lock - check Global Variable
   g_emergencyLock = false;
   string gvName = "PropV3_EmergencyLock_" + IntegerToString(inp_Magic);
   if(GlobalVariableCheck(gvName))
   {
      if(GlobalVariableGet(gvName) > 0)
         g_emergencyLock = true;
   }
   
   // Manual reset
   if(inp_ResetEmergency)
   {
      g_emergencyLock = false;
      GlobalVariableSet(gvName, 0);
      Print("[RESET] Emergency lock cleared manually.");
   }
   
   Print("=== Institutional Prop Firm EA V3.0 INITIALIZED ===");
   Print("Symbol: ", sym, " | Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
   Print("Emergency Lock: ", g_emergencyLock ? "ACTIVE" : "OFF");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(h_EMA_H1 != INVALID_HANDLE)  IndicatorRelease(h_EMA_H1);
   if(h_ATR_M15 != INVALID_HANDLE) IndicatorRelease(h_ATR_M15);
   if(h_ADX_M15 != INVALID_HANDLE) IndicatorRelease(h_ADX_M15);
   Comment("");
}

//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   string sym = g_sym.Name();
   g_sym.RefreshRates();
   
   // === MANAGE EXISTING POSITION ===
   if(g_hasPosition)
   {
      ManagePosition();
      CheckPositionClosed();
   }
   
   // === NEW M5 BAR CHECK ===
   datetime barM5 = iTime(sym, PERIOD_M5, 0);
   if(barM5 == g_lastBar_M5) return;
   g_lastBar_M5 = barM5;
   
   // === DAY RESET ===
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != g_lastDay)
   {
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_dayTrades = 0;
      g_lastDay = dt.day;
      // Reset consecutive losses only at new day if 3+ (day stop)
      if(g_consecLosses >= 3) g_consecLosses = 0;
      if(inp_Debug) Print("[DAY RESET] Equity: ", g_dayStartEquity);
   }
   
   // === SKIP IF POSITION OPEN ===
   if(g_hasPosition) return;
   
   // === EMERGENCY LOCK ===
   if(g_emergencyLock)
   {
      if(inp_Debug) Print("[BLOCKED] Emergency lock active");
      return;
   }
   
   // === CHECK EMERGENCY DD ===
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPct = (inp_InitBalance - equity) / inp_InitBalance * 100.0;
   if(ddPct >= inp_EmergencyDD)
   {
      g_emergencyLock = true;
      string gvName = "PropV3_EmergencyLock_" + IntegerToString(inp_Magic);
      GlobalVariableSet(gvName, 1);
      Print("[EMERGENCY] DD=", ddPct, "% >= ", inp_EmergencyDD, "% - LOCKED!");
      return;
   }
   
   // === DAILY LOSS CHECK ===
   if(g_dayStartEquity > 0)
   {
      double dayLoss = (g_dayStartEquity - equity) / g_dayStartEquity * 100.0;
      if(dayLoss >= inp_DailyLossStop)
      {
         if(inp_Debug) Print("[BLOCKED] Daily loss: ", dayLoss, "%");
         return;
      }
   }
   
   // === COOLDOWN CHECK ===
   if(TimeCurrent() < g_cooldownUntil)
   {
      if(inp_Debug) Print("[COOLDOWN] Until: ", TimeToString(g_cooldownUntil));
      return;
   }
   
   // === 3 CONSECUTIVE LOSSES = DAY STOP ===
   if(g_consecLosses >= 3 && inp_Cool3_DayStop == 1)
   {
      if(inp_Debug) Print("[BLOCKED] 3 consecutive losses - day stop");
      return;
   }
   
   // === SESSION CHECK ===
   if(!IsSessionActive(dt))
      return;
   
   // === SPREAD CHECK ===
   int spread = (int)SymbolInfoInteger(sym, SYMBOL_SPREAD);
   if(spread > inp_MaxSpread)
   {
      if(inp_Debug) Print("[FILTER] Spread: ", spread, " > ", inp_MaxSpread);
      return;
   }
   
   // === GET INDICATORS ===
   double ema_h1 = GetIndicatorValue(h_EMA_H1, 0, 1);
   double atr_m15 = GetIndicatorValue(h_ATR_M15, 0, 1);
   double adx_m15 = GetIndicatorValue(h_ADX_M15, 0, 1);
   
   if(ema_h1 <= 0 || atr_m15 <= 0 || adx_m15 <= 0) return;
   
   // === ADX FILTER ===
   if(adx_m15 < inp_ADX_Min)
   {
      if(inp_Debug) Print("[FILTER] ADX=", DoubleToString(adx_m15, 1), " < ", inp_ADX_Min);
      return;
   }
   
   // === H1 TREND BIAS ===
   MqlRates h1[];
   ArraySetAsSeries(h1, true);
   if(CopyRates(sym, PERIOD_H1, 1, 1, h1) < 1) return;
   
   int bias = 0; // 1=bullish, -1=bearish
   if(h1[0].close > ema_h1) bias = 1;
   if(h1[0].close < ema_h1) bias = -1;
   if(bias == 0) return;
   
   // === M15 STRUCTURE + BOS + RETEST ===
   if(!AnalyzeStructure(sym, bias, atr_m15))
      return;
   
   // === M5 CONFIRMATION CANDLE ===
   if(!CheckConfirmation(sym, bias))
      return;
   
   // === ALL CONDITIONS MET — CALCULATE AND EXECUTE ===
   ExecuteEntry(sym, bias, atr_m15);
}

//+------------------------------------------------------------------+
//| Analyze M15 Structure: Swing → BOS → Retest                       |
//+------------------------------------------------------------------+
bool AnalyzeStructure(string sym, int bias, double atr)
{
   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   int copied = CopyRates(sym, PERIOD_M15, 0, inp_BOS_Lookback + 10, m15);
   if(copied < inp_BOS_Lookback) return false;
   
   // Find swing highs and lows
   double sh1 = 0, sh2 = 0, sl1 = 0, sl2 = 0;
   int shBar1 = -1, slBar1 = -1;
   int shCount = 0, slCount = 0;
   
   for(int i = inp_SwingStrength + 1; i < copied - inp_SwingStrength; i++)
   {
      // Swing High check
      if(shCount < 2)
      {
         bool isSH = true;
         for(int j = 1; j <= inp_SwingStrength; j++)
         {
            if(m15[i-j].high >= m15[i].high || m15[i+j].high >= m15[i].high)
            { isSH = false; break; }
         }
         if(isSH)
         {
            if(shCount == 0) { sh1 = m15[i].high; shBar1 = i; }
            else { sh2 = m15[i].high; }
            shCount++;
         }
      }
      
      // Swing Low check
      if(slCount < 2)
      {
         bool isSL = true;
         for(int j = 1; j <= inp_SwingStrength; j++)
         {
            if(m15[i-j].low <= m15[i].low || m15[i+j].low <= m15[i].low)
            { isSL = false; break; }
         }
         if(isSL)
         {
            if(slCount == 0) { sl1 = m15[i].low; slBar1 = i; }
            else { sl2 = m15[i].low; }
            slCount++;
         }
      }
      
      if(shCount >= 2 && slCount >= 2) break;
   }
   
   if(shCount < 2 || slCount < 2) return false;
   
   // === CHECK BULLISH STRUCTURE (HH + HL) ===
   if(bias == 1)
   {
      // Need: sh1 > sh2 (Higher High) AND sl1 > sl2 (Higher Low)
      if(!(sh1 > sh2 && sl1 > sl2))
      {
         if(inp_Debug) Print("[STRUCTURE] Not bullish. SH1=", sh1, " SH2=", sh2, " SL1=", sl1, " SL2=", sl2);
         return false;
      }
      
      // BOS: Check if any recent candle CLOSED above sh1 (the swing high)
      bool bosFound = false;
      int bosBar = -1;
      for(int i = 1; i < shBar1; i++)
      {
         if(m15[i].close > sh1)
         {
            bosFound = true;
            bosBar = i;
            break;
         }
      }
      if(!bosFound)
      {
         if(inp_Debug) Print("[BOS] No bullish BOS above ", sh1);
         return false;
      }
      
      // RETEST: After BOS, price must come back near the broken level
      double retestZone = atr * inp_Retest_ATR_Mult;
      bool retested = false;
      for(int i = 1; i < bosBar; i++)
      {
         if(m15[i].low <= sh1 + retestZone && m15[i].low >= sh1 - retestZone)
         {
            retested = true;
            break;
         }
      }
      // Also check current price area
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      if(!retested && bid >= sh1 - retestZone && bid <= sh1 + retestZone)
         retested = true;
      
      if(!retested)
      {
         if(inp_Debug) Print("[RETEST] No bullish retest at ", sh1, " zone=", retestZone);
         return false;
      }
      
      g_bosLevel = sh1;
      g_lastSwingLow = sl1;
      g_bullishBOS = true;
      g_bearishBOS = false;
      return true;
   }
   
   // === CHECK BEARISH STRUCTURE (LH + LL) ===
   if(bias == -1)
   {
      // Need: sh1 < sh2 (Lower High) AND sl1 < sl2 (Lower Low)
      if(!(sh1 < sh2 && sl1 < sl2))
      {
         if(inp_Debug) Print("[STRUCTURE] Not bearish. SH1=", sh1, " SH2=", sh2, " SL1=", sl1, " SL2=", sl2);
         return false;
      }
      
      // BOS: Check if any recent candle CLOSED below sl1
      bool bosFound = false;
      int bosBar = -1;
      for(int i = 1; i < slBar1; i++)
      {
         if(m15[i].close < sl1)
         {
            bosFound = true;
            bosBar = i;
            break;
         }
      }
      if(!bosFound)
      {
         if(inp_Debug) Print("[BOS] No bearish BOS below ", sl1);
         return false;
      }
      
      // RETEST
      double retestZone = atr * inp_Retest_ATR_Mult;
      bool retested = false;
      for(int i = 1; i < bosBar; i++)
      {
         if(m15[i].high >= sl1 - retestZone && m15[i].high <= sl1 + retestZone)
         {
            retested = true;
            break;
         }
      }
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      if(!retested && ask >= sl1 - retestZone && ask <= sl1 + retestZone)
         retested = true;
      
      if(!retested)
      {
         if(inp_Debug) Print("[RETEST] No bearish retest at ", sl1, " zone=", retestZone);
         return false;
      }
      
      g_bosLevel = sl1;
      g_lastSwingHigh = sh1;
      g_bullishBOS = false;
      g_bearishBOS = true;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check M5 Confirmation Candle                                       |
//+------------------------------------------------------------------+
bool CheckConfirmation(string sym, int bias)
{
   MqlRates m5[];
   ArraySetAsSeries(m5, true);
   if(CopyRates(sym, PERIOD_M5, 1, 3, m5) < 3) return false;
   
   // bar[0] = last closed M5 candle, bar[1] = previous
   
   if(bias == 1) // Bullish confirmation needed
   {
      // Option A: Bullish Rejection (pin bar)
      // Lower wick >= 2x body, close > 50% range, bullish
      double body = MathAbs(m5[0].close - m5[0].open);
      double range = m5[0].high - m5[0].low;
      if(range <= 0) return false;
      double lowerWick = MathMin(m5[0].open, m5[0].close) - m5[0].low;
      double closePos = (m5[0].close - m5[0].low) / range;
      
      bool rejection = (m5[0].close > m5[0].open && lowerWick >= 2.0 * body && closePos > 0.5);
      
      // Option B: Bullish Engulfing
      // Current bullish, body covers previous bearish body
      bool engulfing = (m5[0].close > m5[0].open &&  // current bullish
                        m5[1].close < m5[1].open &&  // previous bearish
                        m5[0].close > m5[1].open &&  // current close > prev open
                        m5[0].open < m5[1].close);   // current open < prev close
      
      if(!rejection && !engulfing)
      {
         if(inp_Debug) Print("[CONFIRM] No bullish confirmation on M5");
         return false;
      }
      return true;
   }
   
   if(bias == -1) // Bearish confirmation needed
   {
      double body = MathAbs(m5[0].close - m5[0].open);
      double range = m5[0].high - m5[0].low;
      if(range <= 0) return false;
      double upperWick = m5[0].high - MathMax(m5[0].open, m5[0].close);
      double closePos = (m5[0].close - m5[0].low) / range;
      
      bool rejection = (m5[0].close < m5[0].open && upperWick >= 2.0 * body && closePos < 0.5);
      
      bool engulfing = (m5[0].close < m5[0].open &&  // current bearish
                        m5[1].close > m5[1].open &&  // previous bullish
                        m5[0].close < m5[1].open &&  // current close < prev open
                        m5[0].open > m5[1].close);   // current open > prev close
      
      if(!rejection && !engulfing)
      {
         if(inp_Debug) Print("[CONFIRM] No bearish confirmation on M5");
         return false;
      }
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Execute Trade Entry                                                |
//+------------------------------------------------------------------+
void ExecuteEntry(string sym, int bias, double atr)
{
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   
   double entry, sl, tp, slDist;
   double slBuffer = atr * inp_SL_Buffer_ATR;
   double maxSLDist = atr * inp_MaxSL_ATR;
   double rrMult = inp_UseStrongRR ? inp_StrongRR : inp_StandardRR;
   
   if(bias == 1) // BUY
   {
      entry = ask;
      sl = g_lastSwingLow - slBuffer;
      slDist = entry - sl;
      
      if(slDist <= 0 || slDist > maxSLDist)
      {
         if(inp_Debug) Print("[SL] Invalid BUY SL dist=", slDist, " max=", maxSLDist);
         return;
      }
      
      tp = entry + slDist * rrMult;
   }
   else // SELL
   {
      entry = bid;
      sl = g_lastSwingHigh + slBuffer;
      slDist = sl - entry;
      
      if(slDist <= 0 || slDist > maxSLDist)
      {
         if(inp_Debug) Print("[SL] Invalid SELL SL dist=", slDist, " max=", maxSLDist);
         return;
      }
      
      tp = entry - slDist * rrMult;
   }
   
   // Normalize prices
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Validate stop levels
   int stopsLevel = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax(stopsLevel, 10) * point;
   if(slDist < minDist)
   {
      if(inp_Debug) Print("[SL] Below broker minimum. Dist=", slDist, " Min=", minDist);
      return;
   }
   
   // Calculate lot
   double lot = CalculateLot(slDist, sym);
   if(lot <= 0) return;
   
   // Margin check
   double marginReq = 0;
   ENUM_ORDER_TYPE ot = (bias == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(ot, sym, lot, entry, marginReq))
   {
      Print("[ERROR] OrderCalcMargin failed");
      return;
   }
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double equity2 = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity2 > 0 && (marginReq / equity2 * 100.0) > inp_MaxMarginPct)
   {
      if(inp_Debug) Print("[MARGIN] Usage too high: ", marginReq / equity2 * 100.0, "%");
      return;
   }
   
   // Check max positions
   if(CountMyPositions() >= inp_MaxPositions)
   {
      if(inp_Debug) Print("[BLOCKED] Max positions reached");
      return;
   }
   
   // EXECUTE
   bool success = false;
   if(bias == 1)
      success = g_trade.Buy(lot, sym, ask, sl, tp, inp_Comment);
   else
      success = g_trade.Sell(lot, sym, bid, sl, tp, inp_Comment);
   
   if(success)
   {
      g_hasPosition = true;
      g_entryPrice = entry;
      g_slDistance = slDist;
      g_beApplied = false;
      g_protectionApplied = false;
      g_trailActive = false;
      g_ticket = g_trade.ResultOrder();
      g_posType = (bias == 1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      g_entryTime = TimeCurrent();
      g_dayTrades++;
      
      Print("[ENTRY] ", bias == 1 ? "BUY" : "SELL",
            " | Entry=", entry, " | SL=", sl, " | TP=", tp,
            " | Lot=", lot, " | SLdist=", slDist, " | RR=", rrMult);
   }
   else
   {
      Print("[TRADE FAILED] Err=", g_trade.ResultRetcode(), " - ", g_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                                 |
//+------------------------------------------------------------------+
double CalculateLot(double slDist, string sym)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * (inp_RiskPct / 100.0);
   
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tickVal = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickVal <= 0 || tickSize <= 0 || point <= 0 || slDist <= 0)
   {
      Print("[ERROR] Invalid symbol info for lot calc");
      return 0;
   }
   
   double slPoints = slDist / point;
   double costPerPoint = (tickVal / tickSize) * point;
   double lot = riskMoney / (slPoints * costPerPoint);
   
   // Normalize
   double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double lotMin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double lotMax = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lotMin, MathMin(lot, inp_MaxLot));
   lot = MathMin(lot, lotMax);
   lot = NormalizeDouble(lot, 2);
   
   if(lot < lotMin)
   {
      if(inp_Debug) Print("[LOT] Below minimum: ", lot, " < ", lotMin);
      return 0;
   }
   
   return lot;
}

//+------------------------------------------------------------------+
//| Manage Position (BE + Trail)                                       |
//+------------------------------------------------------------------+
void ManagePosition()
{
   string sym = g_sym.Name();
   
   // Find position
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Magic() == inp_Magic && g_pos.Symbol() == sym)
         { found = true; g_ticket = g_pos.Ticket(); break; }
      }
   }
   if(!found) return;
   
   // Min holding time
   if((TimeCurrent() - g_entryTime) < inp_MinHoldSec) return;
   
   // Don't modify during spread spike
   if((int)SymbolInfoInteger(sym, SYMBOL_SPREAD) > inp_MaxSpread * 3) return;
   
   // Calculate current R
   double currentR = 0;
   if(g_slDistance <= 0) return;
   
   if(g_posType == POSITION_TYPE_BUY)
      currentR = (SymbolInfoDouble(sym, SYMBOL_BID) - g_entryPrice) / g_slDistance;
   else
      currentR = (g_entryPrice - SymbolInfoDouble(sym, SYMBOL_ASK)) / g_slDistance;
   
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double curSL = g_pos.StopLoss();
   
   // Break-Even at inp_BE_R
   if(!g_beApplied && currentR >= inp_BE_R)
   {
      double newSL;
      if(g_posType == POSITION_TYPE_BUY)
         newSL = g_entryPrice + g_slDistance * inp_BE_Buffer;
      else
         newSL = g_entryPrice - g_slDistance * inp_BE_Buffer;
      
      newSL = NormalizeDouble(newSL, _Digits);
      
      bool better = (g_posType == POSITION_TYPE_BUY) ? (newSL > curSL) : (newSL < curSL);
      if(better)
      {
         if(g_trade.PositionModify(g_ticket, newSL, g_pos.TakeProfit()))
         {
            g_beApplied = true;
            if(inp_Debug) Print("[BE] Set at ", newSL, " (R=", currentR, ")");
         }
      }
   }
   
   // ATR Trailing at inp_Trail_StartR
   if(g_beApplied && currentR >= inp_Trail_StartR)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(h_ATR_M15, 0, 1, 1, atr) < 1) return;
      
      double trailDist = atr[0] * inp_Trail_ATR_Mult;
      double newSL;
      double minStep = 10 * point;
      
      if(g_posType == POSITION_TYPE_BUY)
      {
         newSL = NormalizeDouble(SymbolInfoDouble(sym, SYMBOL_BID) - trailDist, _Digits);
         if(newSL > curSL + minStep)
         {
            g_trade.PositionModify(g_ticket, newSL, g_pos.TakeProfit());
            g_trailActive = true;
         }
      }
      else
      {
         newSL = NormalizeDouble(SymbolInfoDouble(sym, SYMBOL_ASK) + trailDist, _Digits);
         if(newSL < curSL - minStep)
         {
            g_trade.PositionModify(g_ticket, newSL, g_pos.TakeProfit());
            g_trailActive = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if position was closed                                       |
//+------------------------------------------------------------------+
void CheckPositionClosed()
{
   if(!g_hasPosition) return;
   
   string sym = g_sym.Name();
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Magic() == inp_Magic && g_pos.Symbol() == sym)
         { found = true; break; }
      }
   }
   
   if(!found)
   {
      // Position closed - determine win/loss
      g_hasPosition = false;
      g_beApplied = false;
      g_protectionApplied = false;
      g_trailActive = false;
      
      // Check last deal profit
      HistorySelect(g_entryTime, TimeCurrent());
      int deals = HistoryDealsTotal();
      double profit = 0;
      
      for(int i = deals - 1; i >= 0; i--)
      {
         ulong dticket = HistoryDealGetTicket(i);
         if(dticket == 0) continue;
         if(HistoryDealGetInteger(dticket, DEAL_MAGIC) == inp_Magic &&
            HistoryDealGetString(dticket, DEAL_SYMBOL) == sym &&
            HistoryDealGetInteger(dticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            profit = HistoryDealGetDouble(dticket, DEAL_PROFIT);
            break;
         }
      }
      
      if(profit >= 0)
      {
         g_consecLosses = 0; // Reset on win
         Print("[CLOSED] WIN profit=", profit);
      }
      else
      {
         g_consecLosses++;
         Print("[CLOSED] LOSS profit=", profit, " ConsecLoss=", g_consecLosses);
         
         // Set cooldown
         if(g_consecLosses == 1)
            g_cooldownUntil = TimeCurrent() + inp_Cool1_Mins * 60;
         else if(g_consecLosses == 2)
            g_cooldownUntil = TimeCurrent() + inp_Cool2_Mins * 60;
         // 3+ handled by day stop check
      }
   }
}

//+------------------------------------------------------------------+
//| Count positions by magic                                           |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Magic() == inp_Magic)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Session Check                                                      |
//+------------------------------------------------------------------+
bool IsSessionActive(MqlDateTime &dt)
{
   int hour = dt.hour;
   
   // Weekend
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   
   // Asia (if enabled, allow 0-7)
   if(inp_AsiaEnabled && hour >= 0 && hour < inp_London_Start)
      return true;
   
   // London
   if(hour >= inp_London_Start && hour < inp_London_End)
      return true;
   
   // New York
   if(hour >= inp_NY_Start && hour < inp_NY_End)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Get indicator value safely                                         |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double val[];
   ArraySetAsSeries(val, true);
   if(CopyBuffer(handle, buffer, shift, 1, val) < 1) return -1;
   return val[0];
}
//+------------------------------------------------------------------+

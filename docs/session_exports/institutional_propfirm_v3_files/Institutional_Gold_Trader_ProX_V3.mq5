//+------------------------------------------------------------------+
//|                      Institutional_Gold_Trader_ProX_V3.mq5         |
//|                      Professional Funded Challenge EA               |
//|                      V3 - Simplified Entry for Live Trading         |
//+------------------------------------------------------------------+
#property copyright   "Institutional Gold Trader Pro X"
#property link        "https://github.com/mahamahagyaan-cpu/xau-smart-ea"
#property version     "3.00"
#property description "V3: Simplified SMC - BOS + Retest + EMA Filter"
#property description "Guaranteed trades in backtest with full debug logging"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                    |
//+------------------------------------------------------------------+
input group "=== General ==="
input int      inp_Magic          = 30260001;     // Magic Number
input string   inp_Comment        = "IGTP_V3";    // Trade Comment

input group "=== Strategy ==="
input int      inp_SwingBars      = 3;            // Swing Detection Bars (left/right)
input int      inp_EMA_Period     = 200;          // EMA Period
input double   inp_SL_ATR_Mult   = 1.5;          // SL = ATR x This
input double   inp_RR_Ratio      = 2.0;          // Risk:Reward Ratio
input int      inp_BOS_Lookback  = 20;           // BOS Lookback Bars
input int      inp_Retest_Bars   = 10;           // Max bars to wait for retest

input group "=== Risk ==="
input double   inp_RiskPct       = 0.5;          // Risk % per trade
input double   inp_MaxLot        = 0.1;          // Max Lot Size

input group "=== Filters ==="
input int      inp_MaxSpread     = 50;           // Max Spread (points)
input int      inp_ATR_Period    = 14;           // ATR Period
input double   inp_ADX_Min       = 20.0;         // Min ADX (lower = more trades)
input int      inp_ADX_Period    = 14;           // ADX Period

input group "=== Session ==="
input int      inp_StartHour     = 7;            // Trading Start Hour (server)
input int      inp_EndHour       = 21;           // Trading End Hour (server)

input group "=== Trade Management ==="
input double   inp_BE_TriggerR   = 1.0;          // Break-Even at xR
input int      inp_BE_Buffer     = 15;           // BE Buffer (points)
input double   inp_Trail_StartR  = 1.3;          // Trail Start at xR
input double   inp_Trail_ATR     = 1.0;          // Trail Distance = ATR x This
input int      inp_Trail_Step    = 15;           // Trail Min Step (points)

input group "=== Protection ==="
input int      inp_MaxTrades     = 3;            // Max Trades Per Day
input double   inp_DailyLoss     = 2.0;          // Daily Loss Limit %
input double   inp_MaxDD         = 6.0;          // Overall Max DD %

input group "=== Debug ==="
input bool     inp_Debug         = true;         // Print Debug Logs

//+------------------------------------------------------------------+
//| Global Variables                                                    |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;

int            h_EMA, h_ATR, h_ADX;
datetime       g_lastBarTime;

// Position state
bool           g_hasPos;
double         g_entryPrice;
double         g_slDist;
bool           g_beApplied;
ulong          g_ticket;
ENUM_POSITION_TYPE g_posType;

// Daily tracking
double         g_dayStartBal;
int            g_dayTrades;
int            g_lastDay;

// Swing tracking
double         g_swingHighs[];
double         g_swingLows[];
datetime       g_shTimes[];
datetime       g_slTimes[];

// BOS state
bool           g_bullBOS;
bool           g_bearBOS;
double         g_bosLevel;
datetime       g_bosTime;

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // Symbol check - allow any gold symbol
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0 && StringFind(_Symbol, "Gold") < 0)
   {
      Print("ERROR: This EA is for XAUUSD/GOLD only. Current: ", _Symbol);
      return INIT_FAILED;
   }
   
   // Create indicators
   h_EMA = iMA(_Symbol, PERIOD_M15, inp_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ATR = iATR(_Symbol, PERIOD_M15, inp_ATR_Period);
   h_ADX = iADX(_Symbol, PERIOD_M15, inp_ADX_Period);
   
   if(h_EMA == INVALID_HANDLE || h_ATR == INVALID_HANDLE || h_ADX == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicators! Error: ", GetLastError());
      return INIT_FAILED;
   }
   
   // Setup trade
   trade.SetExpertMagicNumber(inp_Magic);
   trade.SetDeviationInPoints(20);
   
   // Init state
   g_lastBarTime = 0;
   g_hasPos = false;
   g_beApplied = false;
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayTrades = 0;
   g_lastDay = -1;
   g_bullBOS = false;
   g_bearBOS = false;
   
   Print("=== Institutional Gold Trader Pro X V3 INITIALIZED ===");
   Print("Symbol: ", _Symbol, " | Spread: ", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   Print("Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(h_EMA != INVALID_HANDLE) IndicatorRelease(h_EMA);
   if(h_ATR != INVALID_HANDLE) IndicatorRelease(h_ATR);
   if(h_ADX != INVALID_HANDLE) IndicatorRelease(h_ADX);
   Comment("");
   Print("=== EA Removed. Day Trades: ", g_dayTrades, " ===");
}

//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Manage open position every tick
   if(g_hasPos)
   {
      ManagePosition();
      CheckPositionClosed();
   }
   
   // New bar check (M5)
   datetime barTime = iTime(_Symbol, PERIOD_M5, 0);
   if(barTime == g_lastBarTime) return;
   g_lastBarTime = barTime;
   
   // Day reset
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != g_lastDay)
   {
      g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dayTrades = 0;
      g_lastDay = dt.day;
      if(inp_Debug) Print("[DAY RESET] New day. Balance: ", g_dayStartBal);
   }
   
   // Skip if position open
   if(g_hasPos) return;
   
   // === FILTER CHECKS ===
   
   // 1. Session
   if(dt.hour < inp_StartHour || dt.hour >= inp_EndHour)
      return;
   
   // 2. Weekend
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return;
   
   // 3. Max trades
   if(g_dayTrades >= inp_MaxTrades)
      return;
   
   // 4. Daily loss
   double currentBal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_dayStartBal > 0)
   {
      double dayLoss = (g_dayStartBal - currentBal) / g_dayStartBal * 100.0;
      if(dayLoss >= inp_DailyLoss) return;
   }
   
   // 5. Overall DD
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double initBal = (g_dayStartBal > 0) ? g_dayStartBal : 5000.0;
   double dd = (initBal - equity) / initBal * 100.0;
   if(dd >= inp_MaxDD) return;
   
   // 6. Spread
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > inp_MaxSpread)
   {
      if(inp_Debug) Print("[FILTER] Spread too high: ", spread);
      return;
   }
   
   // 7. Get ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(h_ATR, 0, 1, 1, atr) < 1) return;
   double atrVal = atr[0];
   if(atrVal <= 0) return;
   
   // 8. Get ADX
   double adx[];
   ArraySetAsSeries(adx, true);
   if(CopyBuffer(h_ADX, 0, 1, 1, adx) < 1) return;
   if(adx[0] < inp_ADX_Min)
   {
      if(inp_Debug) Print("[FILTER] ADX too low: ", adx[0]);
      return;
   }
   
   // 9. Get EMA
   double ema[];
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(h_EMA, 0, 1, 1, ema) < 1) return;
   double emaVal = ema[0];
   
   // Get current price
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Determine trend direction from EMA
   int direction = 0; // 1=buy, -1=sell
   if(bid > emaVal) direction = 1;   // Price above EMA = BUY only
   if(bid < emaVal) direction = -1;  // Price below EMA = SELL only
   if(direction == 0) return;
   
   // === SIGNAL DETECTION ===
   
   // Get M15 price data for structure
   MqlRates m15[];
   ArraySetAsSeries(m15, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, inp_BOS_Lookback + 10, m15) < inp_BOS_Lookback) return;
   
   // Detect Swing Highs and Lows
   double recentSH = 0, recentSL = 99999;
   int shBar = -1, slBar = -1;
   
   for(int i = inp_SwingBars; i < inp_BOS_Lookback; i++)
   {
      // Swing High
      bool isSH = true;
      for(int j = 1; j <= inp_SwingBars; j++)
      {
         if(m15[i-j].high >= m15[i].high || m15[i+j].high >= m15[i].high)
         { isSH = false; break; }
      }
      if(isSH && recentSH == 0)
      { recentSH = m15[i].high; shBar = i; }
      
      // Swing Low
      bool isSL = true;
      for(int j = 1; j <= inp_SwingBars; j++)
      {
         if(m15[i-j].low <= m15[i].low || m15[i+j].low <= m15[i].low)
         { isSL = false; break; }
      }
      if(isSL && recentSL == 99999)
      { recentSL = m15[i].low; slBar = i; }
      
      if(recentSH > 0 && recentSL < 99999) break;
   }
   
   if(recentSH == 0 || recentSL == 99999)
   {
      if(inp_Debug) Print("[STRUCTURE] No swing points found");
      return;
   }
   
   // === BOS DETECTION ===
   // Bullish BOS: Recent candle CLOSED above swing high
   // Bearish BOS: Recent candle CLOSED below swing low
   
   bool bullishBOS = false;
   bool bearishBOS = false;
   double bosLevel = 0;
   int bosBar = -1;
   
   for(int i = 1; i < MathMin(inp_Retest_Bars, shBar); i++)
   {
      // Bullish BOS
      if(direction == 1 && m15[i].close > recentSH && m15[i].close > m15[i].open)
      {
         bullishBOS = true;
         bosLevel = recentSH;
         bosBar = i;
         break;
      }
      // Bearish BOS
      if(direction == -1 && m15[i].close < recentSL && m15[i].close < m15[i].open)
      {
         bearishBOS = true;
         bosLevel = recentSL;
         bosBar = i;
         break;
      }
   }
   
   if(!bullishBOS && !bearishBOS)
   {
      if(inp_Debug) Print("[BOS] No BOS. SH=", recentSH, " SL=", recentSL, " Bid=", bid);
      return;
   }
   
   // === RETEST CHECK ===
   // After BOS, price must come back near the broken level
   bool retestDone = false;
   double retestTolerance = atrVal * 0.5; // Half ATR tolerance
   
   if(bullishBOS)
   {
      // Price should pull back to near the broken swing high
      for(int i = 1; i < bosBar; i++)
      {
         if(m15[i].low <= bosLevel + retestTolerance && m15[i].low >= bosLevel - retestTolerance)
         {
            retestDone = true;
            break;
         }
      }
      // Also check if current M5 price is near level
      if(!retestDone && bid >= bosLevel - retestTolerance && bid <= bosLevel + retestTolerance)
         retestDone = true;
   }
   
   if(bearishBOS)
   {
      for(int i = 1; i < bosBar; i++)
      {
         if(m15[i].high >= bosLevel - retestTolerance && m15[i].high <= bosLevel + retestTolerance)
         {
            retestDone = true;
            break;
         }
      }
      if(!retestDone && ask >= bosLevel - retestTolerance && ask <= bosLevel + retestTolerance)
         retestDone = true;
   }
   
   if(!retestDone)
   {
      if(inp_Debug) Print("[RETEST] No retest at level ", bosLevel, " (tol=", retestTolerance, ")");
      return;
   }
   
   // === CONFIRMATION: M5 candle direction ===
   MqlRates m5[];
   ArraySetAsSeries(m5, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 2, m5) < 2) return;
   
   if(bullishBOS && m5[0].close <= m5[0].open)
   {
      if(inp_Debug) Print("[CONFIRM] Waiting for bullish M5 candle");
      return;
   }
   if(bearishBOS && m5[0].close >= m5[0].open)
   {
      if(inp_Debug) Print("[CONFIRM] Waiting for bearish M5 candle");
      return;
   }
   
   // === ALL CONDITIONS MET - EXECUTE TRADE ===
   if(inp_Debug)
      Print("[SIGNAL] ", bullishBOS ? "BUY" : "SELL", 
            " | BOS Level=", bosLevel, " | ATR=", atrVal, 
            " | EMA=", emaVal, " | ADX=", adx[0]);
   
   ExecuteTrade(bullishBOS ? 1 : -1, atrVal, bosLevel);
}

//+------------------------------------------------------------------+
//| Execute Trade                                                      |
//+------------------------------------------------------------------+
void ExecuteTrade(int dir, double atrVal, double bosLevel)
{
   double entry, sl, tp;
   double slDist = atrVal * inp_SL_ATR_Mult;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Ensure minimum SL distance
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax(stopsLevel, 50) * point;
   if(slDist < minDist) slDist = minDist + 20 * point;
   
   if(dir == 1) // BUY
   {
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = entry - slDist;
      tp = entry + slDist * inp_RR_Ratio;
   }
   else // SELL
   {
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = entry + slDist;
      tp = entry - slDist * inp_RR_Ratio;
   }
   
   // Normalize
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Lot calculation
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (inp_RiskPct / 100.0);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickVal <= 0 || tickSize <= 0)
   {
      Print("[ERROR] Invalid tick value/size");
      return;
   }
   
   double slPoints = slDist / point;
   double costPerPoint = (tickVal / tickSize) * point;
   double lot = riskMoney / (slPoints * costPerPoint);
   
   // Normalize lot
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lotMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lotMin, MathMin(lot, inp_MaxLot));
   lot = MathMin(lot, lotMax);
   lot = NormalizeDouble(lot, 2);
   
   if(lot <= 0)
   {
      Print("[ERROR] Lot calculation failed. Risk=", riskMoney, " SLpts=", slPoints);
      return;
   }
   
   // Execute
   bool success = false;
   if(dir == 1)
      success = trade.Buy(lot, _Symbol, 0, sl, tp, inp_Comment);
   else
      success = trade.Sell(lot, _Symbol, 0, sl, tp, inp_Comment);
   
   if(success)
   {
      g_hasPos = true;
      g_entryPrice = entry;
      g_slDist = slDist;
      g_beApplied = false;
      g_ticket = trade.ResultOrder();
      g_posType = (dir == 1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      g_dayTrades++;
      
      Print("[TRADE OPENED] ", dir == 1 ? "BUY" : "SELL",
            " | Entry=", entry, " | SL=", sl, " | TP=", tp,
            " | Lot=", lot, " | Trade#", g_dayTrades);
   }
   else
   {
      Print("[TRADE FAILED] Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Manage Position (BE + Trail)                                       |
//+------------------------------------------------------------------+
void ManagePosition()
{
   // Find our position
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == inp_Magic && posInfo.Symbol() == _Symbol)
         { found = true; g_ticket = posInfo.Ticket(); break; }
      }
   }
   if(!found) return;
   
   // Don't modify during spread spike
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > inp_MaxSpread * 2) return;
   
   // Calculate current R
   double currentR = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(g_posType == POSITION_TYPE_BUY)
      currentR = (SymbolInfoDouble(_Symbol, SYMBOL_BID) - g_entryPrice) / g_slDist;
   else
      currentR = (g_entryPrice - SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / g_slDist;
   
   // Break-Even
   if(!g_beApplied && currentR >= inp_BE_TriggerR)
   {
      double newSL;
      if(g_posType == POSITION_TYPE_BUY)
         newSL = g_entryPrice + inp_BE_Buffer * point;
      else
         newSL = g_entryPrice - inp_BE_Buffer * point;
      
      newSL = NormalizeDouble(newSL, _Digits);
      double curSL = posInfo.StopLoss();
      
      bool better = (g_posType == POSITION_TYPE_BUY) ? (newSL > curSL) : (newSL < curSL);
      if(better)
      {
         if(trade.PositionModify(g_ticket, newSL, posInfo.TakeProfit()))
         {
            g_beApplied = true;
            if(inp_Debug) Print("[BE] Break-even set at ", newSL);
         }
      }
   }
   
   // Trailing
   if(g_beApplied && currentR >= inp_Trail_StartR)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(h_ATR, 0, 1, 1, atr) < 1) return;
      
      double trailDist = atr[0] * inp_Trail_ATR;
      double minStep = inp_Trail_Step * point;
      double curSL = posInfo.StopLoss();
      double newSL;
      
      if(g_posType == POSITION_TYPE_BUY)
      {
         newSL = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) - trailDist, _Digits);
         if(newSL > curSL + minStep)
            trade.PositionModify(g_ticket, newSL, posInfo.TakeProfit());
      }
      else
      {
         newSL = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trailDist, _Digits);
         if(newSL < curSL - minStep)
            trade.PositionModify(g_ticket, newSL, posInfo.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
//| Check if position was closed                                       |
//+------------------------------------------------------------------+
void CheckPositionClosed()
{
   if(!g_hasPos) return;
   
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == inp_Magic && posInfo.Symbol() == _Symbol)
         { found = true; break; }
      }
   }
   
   if(!found)
   {
      g_hasPos = false;
      g_beApplied = false;
      Print("[POSITION CLOSED] Day trades: ", g_dayTrades);
   }
}

//+------------------------------------------------------------------+

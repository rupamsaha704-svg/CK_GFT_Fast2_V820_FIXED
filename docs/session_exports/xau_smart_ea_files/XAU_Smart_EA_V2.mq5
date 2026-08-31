//+------------------------------------------------------------------+
//|                                           XAU_Smart_EA_V2.mq5   |
//|                        Copyright 2024, Institutional Gold Trader |
//|                                        https://www.mql5.com      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Institutional Gold Trader"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

//--- Input Parameters
input double RiskPercent            = 0.25;
input double MaxLot                 = 0.05;
input double RiskRewardRatio        = 2.0;

input int    MaxTradesPerDay        = 5;
input int    MaxOpenTrades          = 1;
input int    MaxConsecutiveLosses   = 3;

input double DailyLossLimit         = 1.25;
input double DailyProfitTarget      = 1.50;
input double MaxOverallLoss         = 6.0;
input double EvaluationBalance      = 5000.0;

input double MaxMarginUsage         = 60.0;
input int    MaxSpreadPoints        = 30;
input int    MaxSlippagePoints      = 10;

input long   MagicNumber            = 20260725;
input string TradeComment           = "XAU Smart EA V2";

input bool   EnableAsiaSession      = true;
input int    AsiaStartHour          = 0;
input int    AsiaEndHour            = 8;

input bool   EnableLondonSession    = true;
input int    LondonStartHour        = 8;
input int    LondonEndHour          = 12;

input bool   EnableNewYorkSession   = true;
input int    NewYorkStartHour       = 13;
input int    NewYorkEndHour         = 20;

input bool   AllowBuyTrades         = true;
input bool   AllowSellTrades        = true;

input int    SwingLookback          = 2;
input int    MaxSwingLookback       = 100;
input int    MaxRetestCandles       = 8;

input int    EMA200Period           = 200;
input int    ATRPeriod              = 14;
input int    ADXPeriod              = 14;
input int    MinADXValue            = 22;

input double RetestATRMultiplier    = 0.25;
input double SL_ATR_Buffer          = 0.30;
input double TrailingATRMultiplier  = 1.0;

input double BreakEvenTriggerR      = 1.0;
input double BreakEvenProfitR       = 0.05;
input double TrailingStartR         = 1.3;

input int    DailyResetHour         = 17;


//--- Global Variables
int gHandleEMA;
int gHandleATR;
int gHandleADX;

string gSymbol;
int gDigits;
double gPoint;
double gTickSize;
double gTickValue;
double gMinLot;
double gMaxLot;
double gLotStep;

double gDailyReference;
int gTradingDayKey;
int gTradesToday;
int gConsecutiveLosses;
bool gTradingAllowed;
ulong gCurrentTicket;
string gBlockReason;
datetime gLastBarTime;
int gLastDealsCount;

double gSwingHighs[];
double gSwingLows[];
int gSwingHighCount;
int gSwingLowCount;
double gResistance;
double gSupport;
int gTrendDirection;

double gBufEMA[];
double gBufATR[];
double gBufADX[];


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   gSymbol = _Symbol;
   gDigits = (int)SymbolInfoInteger(gSymbol, SYMBOL_DIGITS);
   gPoint = SymbolInfoDouble(gSymbol, SYMBOL_POINT);
   gTickSize = SymbolInfoDouble(gSymbol, SYMBOL_TRADE_TICK_SIZE);
   gTickValue = SymbolInfoDouble(gSymbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   gMinLot = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_MIN);
   gMaxLot = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_MAX);
   gLotStep = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_STEP);

   //--- Create indicator handles on M5
   gHandleEMA = iMA(gSymbol, PERIOD_M5, EMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   gHandleATR = iATR(gSymbol, PERIOD_M5, ATRPeriod);
   gHandleADX = iADX(gSymbol, PERIOD_M5, ADXPeriod);

   if(gHandleEMA == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create EMA indicator handle");
      return INIT_FAILED;
   }
   if(gHandleATR == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator handle");
      return INIT_FAILED;
   }
   if(gHandleADX == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ADX indicator handle");
      return INIT_FAILED;
   }

   //--- Set buffers as series
   ArraySetAsSeries(gBufEMA, true);
   ArraySetAsSeries(gBufATR, true);
   ArraySetAsSeries(gBufADX, true);

   //--- Initialize swing arrays
   ArrayResize(gSwingHighs, 50);
   ArrayResize(gSwingLows, 50);
   gSwingHighCount = 0;
   gSwingLowCount = 0;
   gTrendDirection = 0;
   gResistance = 0;
   gSupport = 0;

   //--- Initialize state
   gLastBarTime = 0;
   gBlockReason = "OK";
   gLastDealsCount = 0;
   gCurrentTicket = 0;
   gTradingAllowed = true;

   //--- Load persistent daily state
   LoadDailyState();
   gCurrentTicket = FindMyPosition();

   //--- Start timer for periodic updates
   EventSetTimer(30);

   Print("XAU Smart EA V2 initialized successfully on ", gSymbol);
   return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   if(gHandleEMA != INVALID_HANDLE) IndicatorRelease(gHandleEMA);
   if(gHandleATR != INVALID_HANDLE) IndicatorRelease(gHandleATR);
   if(gHandleADX != INVALID_HANDLE) IndicatorRelease(gHandleADX);

   SaveDailyState();
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Daily reset check
   CheckDailyReset();

   //--- Check for closed trades (loss tracking)
   CheckClosedTrades();

   //--- Update risk limits
   UpdateRiskLimits();

   //--- Find current position
   gCurrentTicket = FindMyPosition();

   //--- Manage existing position every tick
   if(gCurrentTicket > 0)
   {
      ManagePosition();
   }
   else if(gTradingAllowed)
   {
      //--- Signal analysis only on new M5 bar
      datetime currentBar = iTime(gSymbol, PERIOD_M5, 0);
      if(currentBar != gLastBarTime)
      {
         gLastBarTime = currentBar;
         AnalyzeAndTrade();
      }
   }

   //--- Update chart display
   ShowStatus();
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckDailyReset();
   UpdateRiskLimits();
   ShowStatus();
}


//+------------------------------------------------------------------+
//| Check if current time is within an active trading session         |
//+------------------------------------------------------------------+
bool IsSessionActive()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   //--- No trading on weekends
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;

   int hour = dt.hour;

   //--- Check Asia session
   if(EnableAsiaSession && hour >= AsiaStartHour && hour < AsiaEndHour)
      return true;

   //--- Check London session
   if(EnableLondonSession && hour >= LondonStartHour && hour < LondonEndHour)
      return true;

   //--- Check New York session
   if(EnableNewYorkSession && hour >= NewYorkStartHour && hour < NewYorkEndHour)
      return true;

   return false;
}


//+------------------------------------------------------------------+
//| Check if a bar is a swing high (fractal high)                    |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index, const double &high[])
{
   if(index < SwingLookback)
      return false;
   if(index >= ArraySize(high) - SwingLookback)
      return false;

   double pivot = high[index];

   for(int i = 1; i <= SwingLookback; i++)
   {
      if(high[index - i] >= pivot)
         return false;
      if(high[index + i] >= pivot)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if a bar is a swing low (fractal low)                      |
//+------------------------------------------------------------------+
bool IsSwingLow(int index, const double &low[])
{
   if(index < SwingLookback)
      return false;
   if(index >= ArraySize(low) - SwingLookback)
      return false;

   double pivot = low[index];

   for(int i = 1; i <= SwingLookback; i++)
   {
      if(low[index - i] <= pivot)
         return false;
      if(low[index + i] <= pivot)
         return false;
   }
   return true;
}


//+------------------------------------------------------------------+
//| Detect swing highs and lows on M15 timeframe                     |
//+------------------------------------------------------------------+
void DetectSwings()
{
   gSwingHighCount = 0;
   gSwingLowCount = 0;

   double high[];
   double low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   int bars = MathMin(MaxSwingLookback, iBars(gSymbol, PERIOD_M15));
   if(bars < SwingLookback * 2 + 1)
      return;

   int copiedH = CopyHigh(gSymbol, PERIOD_M15, 0, bars, high);
   if(copiedH != bars)
      return;

   int copiedL = CopyLow(gSymbol, PERIOD_M15, 0, bars, low);
   if(copiedL != bars)
      return;

   //--- Find swing highs (skip bar 0 as it may not be closed)
   for(int i = SwingLookback + 1; i < bars - SwingLookback; i++)
   {
      if(gSwingHighCount >= 50)
         break;
      if(IsSwingHigh(i, high))
      {
         gSwingHighs[gSwingHighCount] = high[i];
         gSwingHighCount = gSwingHighCount + 1;
      }
   }

   //--- Find swing lows
   for(int i = SwingLookback + 1; i < bars - SwingLookback; i++)
   {
      if(gSwingLowCount >= 50)
         break;
      if(IsSwingLow(i, low))
      {
         gSwingLows[gSwingLowCount] = low[i];
         gSwingLowCount = gSwingLowCount + 1;
      }
   }
}


//+------------------------------------------------------------------+
//| Detect market structure (HH/HL = bullish, LH/LL = bearish)       |
//+------------------------------------------------------------------+
void DetectTrendStructure()
{
   gTrendDirection = 0;
   gResistance = 0;
   gSupport = 0;

   //--- Need at least 2 swing highs and 2 swing lows
   if(gSwingHighCount < 2 || gSwingLowCount < 2)
      return;

   //--- Most recent swings (index 0 = most recent confirmed)
   double latestHigh = gSwingHighs[0];
   double previousHigh = gSwingHighs[1];
   double latestLow = gSwingLows[0];
   double previousLow = gSwingLows[1];

   //--- Bullish: Higher High + Higher Low
   if(latestHigh > previousHigh && latestLow > previousLow)
   {
      gTrendDirection = 1;
      gResistance = latestHigh;
      gSupport = latestLow;
   }
   //--- Bearish: Lower High + Lower Low
   else if(latestHigh < previousHigh && latestLow < previousLow)
   {
      gTrendDirection = -1;
      gResistance = latestHigh;
      gSupport = latestLow;
   }
   //--- Unclear structure: no trade
}


//+------------------------------------------------------------------+
//| Check for breakout-retest pattern                                 |
//| Returns: +1 for BUY signal, -1 for SELL signal, 0 for no signal  |
//+------------------------------------------------------------------+
int CheckBreakoutRetest()
{
   if(gTrendDirection == 0)
      return 0;
   if(gResistance <= 0 || gSupport <= 0)
      return 0;

   //--- Get M5 closed candle data
   double close[];
   double open[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);

   int needed = MaxRetestCandles + 2;
   if(CopyClose(gSymbol, PERIOD_M5, 0, needed, close) < needed)
      return 0;
   if(CopyOpen(gSymbol, PERIOD_M5, 0, needed, open) < needed)
      return 0;

   //--- Get ATR for dynamic retest zone
   if(CopyBuffer(gHandleATR, 0, 0, 3, gBufATR) < 3)
      return 0;
   double atr = gBufATR[1];
   double retestZone = atr * RetestATRMultiplier;

   //--- BUY: Bullish structure + resistance breakout + retest
   if(gTrendDirection == 1 && AllowBuyTrades)
   {
      //--- Check if resistance was broken (closed candle above resistance)
      bool brokeResistance = false;
      int breakBar = -1;
      for(int i = 2; i < needed; i++)
      {
         if(close[i] > gResistance)
         {
            brokeResistance = true;
            breakBar = i;
            break;
         }
      }

      if(!brokeResistance)
         return 0;

      //--- Check retest: price came back near broken resistance within MaxRetestCandles
      //--- Bar 1 is the latest closed candle (confirmation candle)
      bool retestFound = false;
      for(int i = 1; i < breakBar && i <= MaxRetestCandles; i++)
      {
         double lowVal = 0;
         double lowArr[];
         ArraySetAsSeries(lowArr, true);
         if(CopyLow(gSymbol, PERIOD_M5, 0, needed, lowArr) < needed)
            return 0;

         //--- Price touched or came within retest zone of resistance
         if(lowArr[i] <= gResistance + retestZone && lowArr[i] >= gResistance - retestZone)
         {
            retestFound = true;
            break;
         }
      }

      if(!retestFound)
         return 0;

      //--- Bullish confirmation: bar 1 closed bullish
      if(close[1] > open[1])
         return 1;
   }

   //--- SELL: Bearish structure + support breakdown + retest
   if(gTrendDirection == -1 && AllowSellTrades)
   {
      //--- Check if support was broken (closed candle below support)
      bool brokeSupport = false;
      int breakBar = -1;
      for(int i = 2; i < needed; i++)
      {
         if(close[i] < gSupport)
         {
            brokeSupport = true;
            breakBar = i;
            break;
         }
      }

      if(!brokeSupport)
         return 0;

      //--- Check retest: price came back near broken support within MaxRetestCandles
      bool retestFound = false;
      for(int i = 1; i < breakBar && i <= MaxRetestCandles; i++)
      {
         double highArr[];
         ArraySetAsSeries(highArr, true);
         if(CopyHigh(gSymbol, PERIOD_M5, 0, needed, highArr) < needed)
            return 0;

         //--- Price touched or came within retest zone of support
         if(highArr[i] >= gSupport - retestZone && highArr[i] <= gSupport + retestZone)
         {
            retestFound = true;
            break;
         }
      }

      if(!retestFound)
         return 0;

      //--- Bearish confirmation: bar 1 closed bearish
      if(close[1] < open[1])
         return -1;
   }

   return 0;
}


//+------------------------------------------------------------------+
//| Check EMA and ADX filters                                         |
//| Returns true if filters pass for given direction                  |
//+------------------------------------------------------------------+
bool CheckFilters(int direction)
{
   //--- Copy EMA buffer (closed bar = index 1)
   if(CopyBuffer(gHandleEMA, 0, 0, 3, gBufEMA) < 3)
      return false;

   //--- Copy ADX main line (buffer 0 = ADX value)
   if(CopyBuffer(gHandleADX, 0, 0, 3, gBufADX) < 3)
      return false;

   double ema200 = gBufEMA[1];
   double adxValue = gBufADX[1];
   double currentPrice = SymbolInfoDouble(gSymbol, SYMBOL_BID);

   //--- EMA Filter
   if(direction == 1 && currentPrice < ema200)
      return false;
   if(direction == -1 && currentPrice > ema200)
      return false;

   //--- ADX Filter
   if(adxValue < MinADXValue)
      return false;

   //--- Spread Filter
   long spread = SymbolInfoInteger(gSymbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints)
      return false;

   return true;
}


//+------------------------------------------------------------------+
//| Main analysis and trade entry function                            |
//+------------------------------------------------------------------+
void AnalyzeAndTrade()
{
   //--- Check session
   if(!IsSessionActive())
      return;

   //--- Detect M15 swing structure
   DetectSwings();
   DetectTrendStructure();

   //--- No clear structure = no trade
   if(gTrendDirection == 0)
      return;

   //--- Check breakout-retest pattern
   int signal = CheckBreakoutRetest();
   if(signal == 0)
      return;

   //--- Check EMA + ADX + Spread filters
   if(!CheckFilters(signal))
      return;

   //--- Execute trade
   if(signal == 1)
      OpenTrade(ORDER_TYPE_BUY);
   else if(signal == -1)
      OpenTrade(ORDER_TYPE_SELL);
}


//+------------------------------------------------------------------+
//| Calculate stop loss based on structure + ATR buffer                |
//+------------------------------------------------------------------+
double CalcStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   //--- Get ATR value
   if(CopyBuffer(gHandleATR, 0, 0, 3, gBufATR) < 3)
      return 0;
   double atr = gBufATR[1];
   double sl = 0;

   if(orderType == ORDER_TYPE_BUY)
   {
      //--- SL below latest confirmed support - ATR buffer
      if(gSupport > 0)
         sl = gSupport - atr * SL_ATR_Buffer;
      else
         sl = entryPrice - atr * 1.5;
   }
   else
   {
      //--- SL above latest confirmed resistance + ATR buffer
      if(gResistance > 0)
         sl = gResistance + atr * SL_ATR_Buffer;
      else
         sl = entryPrice + atr * 1.5;
   }

   //--- Validate against broker minimum stop distance
   long stopLevel = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist = MathMax(stopLevel, freezeLevel) * gPoint;
   if(minDist <= 0)
      minDist = 10 * gPoint;

   //--- Ensure SL is at least minDist away from entry
   double dist = MathAbs(entryPrice - sl);
   if(dist < minDist)
   {
      if(orderType == ORDER_TYPE_BUY)
         sl = entryPrice - minDist;
      else
         sl = entryPrice + minDist;
   }

   //--- Normalize to tick size
   sl = MathRound(sl / gTickSize) * gTickSize;
   return NormalizeDouble(sl, gDigits);
}


//+------------------------------------------------------------------+
//| Calculate lot size based on risk percent and SL distance          |
//+------------------------------------------------------------------+
double CalcLotSize(double entryPrice, double stopLoss)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
   double slDist = MathAbs(entryPrice - stopLoss);

   //--- Safety checks
   if(slDist <= 0)
      return 0;
   if(gTickSize <= 0)
      return 0;
   if(gTickValue <= 0)
      return 0;

   //--- Calculate lots
   double ticksInSL = slDist / gTickSize;
   double moneyPerLot = ticksInSL * gTickValue;
   if(moneyPerLot <= 0)
      return 0;

   double lots = riskMoney / moneyPerLot;

   //--- Normalize to volume step
   lots = MathFloor(lots / gLotStep) * gLotStep;

   //--- Apply limits
   lots = MathMin(lots, MaxLot);
   lots = MathMin(lots, gMaxLot);
   lots = MathMax(lots, gMinLot);

   //--- If calculated lot is below broker minimum, do not trade
   if(lots < gMinLot)
      return 0;

   //--- Check margin usage
   double margin = 0;
   bool marginOK = OrderCalcMargin(ORDER_TYPE_BUY, gSymbol, lots, entryPrice, margin);
   if(!marginOK)
      return 0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0)
      return 0;

   double marginPct = (margin / equity) * 100.0;
   if(marginPct > MaxMarginUsage)
      return 0;

   return NormalizeDouble(lots, 2);
}


//+------------------------------------------------------------------+
//| Open a market order                                               |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   //--- Pre-trade checks
   if(gTradesToday >= MaxTradesPerDay)
      return;
   if(gConsecutiveLosses >= MaxConsecutiveLosses)
      return;

   //--- Get entry price
   double price = 0;
   if(orderType == ORDER_TYPE_BUY)
      price = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
   else
      price = SymbolInfoDouble(gSymbol, SYMBOL_BID);

   //--- Calculate stop loss
   double sl = CalcStopLoss(orderType, price);
   if(sl <= 0)
      return;

   //--- Calculate lot size
   double lots = CalcLotSize(price, sl);
   if(lots <= 0)
      return;

   //--- Calculate take profit (Risk:Reward ratio)
   double slDist = MathAbs(price - sl);
   double tp = 0;
   if(orderType == ORDER_TYPE_BUY)
      tp = price + slDist * RiskRewardRatio;
   else
      tp = price - slDist * RiskRewardRatio;

   //--- Normalize TP to tick size
   tp = MathRound(tp / gTickSize) * gTickSize;
   tp = NormalizeDouble(tp, gDigits);

   //--- Build order request
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = gSymbol;
   request.volume = lots;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = MaxSlippagePoints;
   request.magic = MagicNumber;
   request.comment = TradeComment;

   //--- Send order
   bool sent = OrderSend(request, result);
   if(sent && result.retcode == TRADE_RETCODE_DONE)
   {
      gCurrentTicket = result.order;
      gTradesToday = gTradesToday + 1;
      SaveDailyState();
      Print("Trade opened: ",
            (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " Lots=", lots,
            " Price=", price,
            " SL=", sl,
            " TP=", tp);
   }
   else
   {
      Print("OrderSend failed. retcode=", result.retcode,
            " comment=", result.comment);
   }
}


//+------------------------------------------------------------------+
//| Find EA's open position by symbol and magic number                |
//+------------------------------------------------------------------+
ulong FindMyPosition()
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      bool selected = PositionSelectByTicket(ticket);
      if(!selected)
         continue;

      string posSymbol = PositionGetString(POSITION_SYMBOL);
      long posMagic = PositionGetInteger(POSITION_MAGIC);

      if(posSymbol == gSymbol && posMagic == MagicNumber)
         return ticket;
   }
   return 0;
}


//+------------------------------------------------------------------+
//| Manage open position: break-even and trailing stop                |
//+------------------------------------------------------------------+
void ManagePosition()
{
   bool selected = PositionSelectByTicket(gCurrentTicket);
   if(!selected)
      return;

   long posTypeVal = PositionGetInteger(POSITION_TYPE);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)posTypeVal;
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   //--- Get current market price
   double currentPrice = 0;
   if(posType == POSITION_TYPE_BUY)
      currentPrice = SymbolInfoDouble(gSymbol, SYMBOL_BID);
   else
      currentPrice = SymbolInfoDouble(gSymbol, SYMBOL_ASK);

   //--- Calculate R-multiple
   double slDist = MathAbs(openPrice - currentSL);
   if(slDist <= 0)
      return;

   double profit = 0;
   if(posType == POSITION_TYPE_BUY)
      profit = currentPrice - openPrice;
   else
      profit = openPrice - currentPrice;

   double rMultiple = profit / slDist;

   //--- Get broker minimum stop distance
   long stopLevel = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist = MathMax(stopLevel, freezeLevel) * gPoint;
   if(minDist <= 0)
      minDist = 10 * gPoint;

   //--- BREAK-EVEN at +1.0R
   if(rMultiple >= BreakEvenTriggerR && rMultiple < TrailingStartR)
   {
      double newSL = 0;
      if(posType == POSITION_TYPE_BUY)
         newSL = openPrice + slDist * BreakEvenProfitR;
      else
         newSL = openPrice - slDist * BreakEvenProfitR;

      //--- Normalize
      newSL = MathRound(newSL / gTickSize) * gTickSize;
      newSL = NormalizeDouble(newSL, gDigits);

      //--- Only move SL forward, never backward
      bool shouldMove = false;
      if(posType == POSITION_TYPE_BUY && newSL > currentSL)
         shouldMove = true;
      if(posType == POSITION_TYPE_SELL && newSL < currentSL)
         shouldMove = true;

      //--- Validate distance from current price
      if(shouldMove)
      {
         double distFromPrice = MathAbs(currentPrice - newSL);
         if(distFromPrice >= minDist)
         {
            ModifyPositionSL(newSL, currentTP);
         }
      }
   }

   //--- TRAILING STOP at +1.3R
   if(rMultiple >= TrailingStartR)
   {
      //--- Get ATR for trailing distance
      if(CopyBuffer(gHandleATR, 0, 0, 3, gBufATR) < 3)
         return;
      double atr = gBufATR[1];
      double trailDist = atr * TrailingATRMultiplier;

      double trailSL = 0;
      if(posType == POSITION_TYPE_BUY)
         trailSL = currentPrice - trailDist;
      else
         trailSL = currentPrice + trailDist;

      //--- Normalize
      trailSL = MathRound(trailSL / gTickSize) * gTickSize;
      trailSL = NormalizeDouble(trailSL, gDigits);

      //--- Only move SL forward, never backward
      bool shouldTrail = false;
      if(posType == POSITION_TYPE_BUY && trailSL > currentSL)
         shouldTrail = true;
      if(posType == POSITION_TYPE_SELL && trailSL < currentSL)
         shouldTrail = true;

      //--- Validate distance from current price
      if(shouldTrail)
      {
         double distFromPrice = MathAbs(currentPrice - trailSL);
         if(distFromPrice >= minDist)
         {
            ModifyPositionSL(trailSL, currentTP);
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Modify position stop loss                                         |
//+------------------------------------------------------------------+
void ModifyPositionSL(double newSL, double currentTP)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_SLTP;
   request.symbol = gSymbol;
   request.position = gCurrentTicket;
   request.sl = newSL;
   request.tp = currentTP;

   bool sent = OrderSend(request, result);
   if(!sent || result.retcode != TRADE_RETCODE_DONE)
   {
      Print("SL modify failed. retcode=", result.retcode);
   }
}


//+------------------------------------------------------------------+
//| Check for closed trades and update consecutive loss counter       |
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   if(!HistorySelect(0, TimeCurrent()))
      return;

   int totalDeals = HistoryDealsTotal();
   if(totalDeals <= gLastDealsCount)
   {
      gLastDealsCount = totalDeals;
      return;
   }

   for(int i = gLastDealsCount; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      string dealSymbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(dealSymbol != gSymbol)
         continue;
      if(dealMagic != MagicNumber)
         continue;
      if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY)
         continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double netProfit = profit + commission + swap;

      if(netProfit < 0)
         gConsecutiveLosses = gConsecutiveLosses + 1;
      else if(netProfit > 0)
         gConsecutiveLosses = 0;

      gCurrentTicket = 0;
      SaveDailyState();
      Print("Trade closed. Net P/L: ", DoubleToString(netProfit, 2),
            " Consecutive losses: ", gConsecutiveLosses);
   }

   gLastDealsCount = totalDeals;
}


//+------------------------------------------------------------------+
//| Get trading day key based on DailyResetHour (broker server time)  |
//+------------------------------------------------------------------+
int GetDayKey()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   //--- If current hour is before reset hour, it belongs to previous day
   datetime refTime = TimeCurrent();
   if(dt.hour < DailyResetHour)
   {
      refTime = refTime - 86400;
      TimeToStruct(refTime, dt);
   }

   int key = dt.year * 10000 + dt.mon * 100 + dt.day;
   return key;
}

//+------------------------------------------------------------------+
//| Save daily state to terminal global variables                     |
//+------------------------------------------------------------------+
void SaveDailyState()
{
   string prefix = "XAUV2_" + IntegerToString(MagicNumber) + "_" + gSymbol;
   GlobalVariableSet(prefix + "_KEY", (double)gTradingDayKey);
   GlobalVariableSet(prefix + "_REF", gDailyReference);
   GlobalVariableSet(prefix + "_TRADES", (double)gTradesToday);
   GlobalVariableSet(prefix + "_LOSSES", (double)gConsecutiveLosses);
}

//+------------------------------------------------------------------+
//| Load daily state from terminal global variables                   |
//+------------------------------------------------------------------+
void LoadDailyState()
{
   string prefix = "XAUV2_" + IntegerToString(MagicNumber) + "_" + gSymbol;
   int keyNow = GetDayKey();

   bool hasKey = GlobalVariableCheck(prefix + "_KEY");
   if(hasKey)
   {
      int savedKey = (int)GlobalVariableGet(prefix + "_KEY");
      if(savedKey == keyNow)
      {
         gTradingDayKey = keyNow;
         gDailyReference = GlobalVariableGet(prefix + "_REF");
         gTradesToday = (int)GlobalVariableGet(prefix + "_TRADES");
         gConsecutiveLosses = (int)GlobalVariableGet(prefix + "_LOSSES");
         return;
      }
   }

   //--- New day or first run
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   gDailyReference = MathMax(bal, eq);
   gTradingDayKey = keyNow;
   gTradesToday = 0;
   gConsecutiveLosses = 0;
   SaveDailyState();
}

//+------------------------------------------------------------------+
//| Check if a new trading day has started                            |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   int keyNow = GetDayKey();
   if(keyNow != gTradingDayKey)
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      gDailyReference = MathMax(bal, eq);
      gTradingDayKey = keyNow;
      gTradesToday = 0;
      gConsecutiveLosses = 0;
      SaveDailyState();
      Print("Daily reset completed. New reference: ", DoubleToString(gDailyReference, 2));
   }
}


//+------------------------------------------------------------------+
//| Update risk limits and determine if trading is allowed            |
//+------------------------------------------------------------------+
void UpdateRiskLimits()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = equity - gDailyReference;
   double dailyPct = 0;
   if(gDailyReference > 0)
      dailyPct = (dailyPL / gDailyReference) * 100.0;

   double overallPct = 0;
   if(EvaluationBalance > 0)
      overallPct = ((equity - EvaluationBalance) / EvaluationBalance) * 100.0;

   gTradingAllowed = true;
   gBlockReason = "OK";

   //--- Daily loss limit check
   if(dailyPct <= -DailyLossLimit)
   {
      gTradingAllowed = false;
      gBlockReason = "Daily Loss Limit";
      return;
   }

   //--- Daily profit target check
   if(dailyPct >= DailyProfitTarget)
   {
      gTradingAllowed = false;
      gBlockReason = "Daily Profit Target";
      return;
   }

   //--- Overall max loss check
   if(overallPct <= -MaxOverallLoss)
   {
      gTradingAllowed = false;
      gBlockReason = "Max Overall Loss";
      return;
   }

   //--- Max trades per day check
   if(gTradesToday >= MaxTradesPerDay)
   {
      gTradingAllowed = false;
      gBlockReason = "Max Trades/Day";
      return;
   }

   //--- Consecutive losses check
   if(gConsecutiveLosses >= MaxConsecutiveLosses)
   {
      gTradingAllowed = false;
      gBlockReason = "Consecutive Losses";
      return;
   }

   //--- Max open trades check
   ulong pos = FindMyPosition();
   if(pos > 0)
   {
      gTradingAllowed = false;
      gBlockReason = "Position Open";
   }
}


//+------------------------------------------------------------------+
//| Display EA status on chart                                        |
//+------------------------------------------------------------------+
void ShowStatus()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = equity - gDailyReference;

   string trend = "RANGE";
   if(gTrendDirection == 1) trend = "BULLISH";
   if(gTrendDirection == -1) trend = "BEARISH";

   string session = "CLOSED";
   if(IsSessionActive()) session = "ACTIVE";

   string stat = "BLOCKED";
   if(gTradingAllowed) stat = "READY";

   string line1 = "=== XAU Smart EA V2 ===";
   string line2 = "Status: " + stat + " | " + gBlockReason;
   string line3 = "Trend: " + trend + " | Session: " + session;
   string line4 = "Trades: " + IntegerToString(gTradesToday) + "/" + IntegerToString(MaxTradesPerDay);
   string line5 = "Consec Losses: " + IntegerToString(gConsecutiveLosses) + "/" + IntegerToString(MaxConsecutiveLosses);
   string line6 = "Daily PL: $" + DoubleToString(dailyPL, 2);
   string line7 = "Equity: $" + DoubleToString(equity, 2);
   string line8 = "R: " + DoubleToString(gResistance, gDigits) + " | S: " + DoubleToString(gSupport, gDigits);

   string output = line1 + "\n" + line2 + "\n" + line3 + "\n" + line4 + "\n" + line5 + "\n" + line6 + "\n" + line7 + "\n" + line8;
   Comment(output);
}
//+------------------------------------------------------------------+

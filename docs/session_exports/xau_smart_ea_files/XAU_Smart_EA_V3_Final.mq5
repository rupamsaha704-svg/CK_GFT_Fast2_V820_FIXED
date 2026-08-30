//+------------------------------------------------------------------+
//|                                     XAU_Smart_EA_V3_Final.mq5   |
//|                        Copyright 2024, Institutional Gold Trader |
//|                                        https://www.mql5.com      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Institutional Gold Trader"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property strict

//--- Input Parameters
input double RiskPercent            = 0.25;
input double MaxLot                 = 0.05;
input double RiskRewardRatio        = 1.80;

input int    MaxTradesPerDay        = 5;
input int    MaxOpenTrades          = 1;
input int    MaxConsecutiveLosses   = 3;

input double DailyLossLimit         = 1.25;
input double DailyProfitTarget      = 2.00;

input int    MaxSpreadPoints        = 30;
input int    MaxSlippagePoints      = 10;

input long   MagicNumber            = 20260725;
input string TradeComment           = "XAU Smart EA V3";

input bool   EnableAsiaSession      = true;
input bool   EnableLondonSession    = true;
input bool   EnableNewYorkSession   = true;

input int    AsiaStartHour          = 0;
input int    AsiaEndHour            = 8;
input int    LondonStartHour        = 8;
input int    LondonEndHour          = 13;
input int    NewYorkStartHour       = 13;
input int    NewYorkEndHour         = 21;

input int    SwingLeftBars          = 2;
input int    SwingRightBars         = 2;

input int    BreakoutBufferPoints   = 5;
input int    MaxRetestCandles       = 6;
input double RetestATRMultiplier    = 0.20;

input int    EMA200Period           = 200;
input int    ATRPeriod              = 14;
input int    ADXPeriod              = 14;
input int    MinADXValue            = 18;

input double SL_ATR_Buffer          = 0.30;
input double BreakEvenTriggerR      = 1.00;
input double BreakEvenLockR         = 0.10;
input double TrailingStartR         = 1.30;
input double TrailingATRMultiplier  = 1.00;

input int    DailyResetHourNY       = 17;


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
datetime gLastBreakoutTime;

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
//| Expert initialization                                            |
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

   gHandleEMA = iMA(gSymbol, PERIOD_M15, EMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   gHandleATR = iATR(gSymbol, PERIOD_M5, ATRPeriod);
   gHandleADX = iADX(gSymbol, PERIOD_M15, ADXPeriod);

   if(gHandleEMA == INVALID_HANDLE)
   { Print("ERROR: EMA handle failed"); return INIT_FAILED; }
   if(gHandleATR == INVALID_HANDLE)
   { Print("ERROR: ATR handle failed"); return INIT_FAILED; }
   if(gHandleADX == INVALID_HANDLE)
   { Print("ERROR: ADX handle failed"); return INIT_FAILED; }

   ArraySetAsSeries(gBufEMA, true);
   ArraySetAsSeries(gBufATR, true);
   ArraySetAsSeries(gBufADX, true);
   ArrayResize(gSwingHighs, 50);
   ArrayResize(gSwingLows, 50);

   gSwingHighCount = 0;
   gSwingLowCount = 0;
   gTrendDirection = 0;
   gResistance = 0;
   gSupport = 0;
   gLastBarTime = 0;
   gLastBreakoutTime = 0;
   gBlockReason = "OK";
   gLastDealsCount = 0;
   gCurrentTicket = 0;
   gTradingAllowed = true;

   LoadDailyState();
   gCurrentTicket = FindMyPosition();
   EventSetTimer(30);

   Print("XAU Smart EA V3 Final initialized on ", gSymbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
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
   CheckDailyReset();
   CheckClosedTrades();
   UpdateRiskLimits();
   gCurrentTicket = FindMyPosition();

   if(gCurrentTicket > 0)
   {
      ManagePosition();
   }
   else if(gTradingAllowed)
   {
      datetime currentBar = iTime(gSymbol, PERIOD_M5, 0);
      if(currentBar != gLastBarTime)
      {
         gLastBarTime = currentBar;
         AnalyzeAndTrade();
      }
   }
   ShowStatus();
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckDailyReset();
   UpdateRiskLimits();
}

//+------------------------------------------------------------------+
//| Session check                                                     |
//+------------------------------------------------------------------+
bool IsSessionActive()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   int hour = dt.hour;
   if(EnableAsiaSession && hour >= AsiaStartHour && hour < AsiaEndHour) return true;
   if(EnableLondonSession && hour >= LondonStartHour && hour < LondonEndHour) return true;
   if(EnableNewYorkSession && hour >= NewYorkStartHour && hour < NewYorkEndHour) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Swing high detection on M15                                       |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index, const double &high[])
{
   if(index < SwingLeftBars) return false;
   if(index >= ArraySize(high) - SwingRightBars) return false;
   double pivot = high[index];
   for(int i = 1; i <= SwingLeftBars; i++)
   { if(high[index - i] >= pivot) return false; }
   for(int i = 1; i <= SwingRightBars; i++)
   { if(high[index + i] >= pivot) return false; }
   return true;
}

//+------------------------------------------------------------------+
//| Swing low detection on M15                                        |
//+------------------------------------------------------------------+
bool IsSwingLow(int index, const double &low[])
{
   if(index < SwingLeftBars) return false;
   if(index >= ArraySize(low) - SwingRightBars) return false;
   double pivot = low[index];
   for(int i = 1; i <= SwingLeftBars; i++)
   { if(low[index - i] <= pivot) return false; }
   for(int i = 1; i <= SwingRightBars; i++)
   { if(low[index + i] <= pivot) return false; }
   return true;
}


//+------------------------------------------------------------------+
//| Detect swing points on M15                                        |
//+------------------------------------------------------------------+
void DetectSwings()
{
   gSwingHighCount = 0;
   gSwingLowCount = 0;
   double high[];
   double low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   int bars = MathMin(80, iBars(gSymbol, PERIOD_M15));
   if(bars < SwingLeftBars + SwingRightBars + 1) return;
   if(CopyHigh(gSymbol, PERIOD_M15, 0, bars, high) != bars) return;
   if(CopyLow(gSymbol, PERIOD_M15, 0, bars, low) != bars) return;

   for(int i = SwingRightBars + 1; i < bars - SwingLeftBars; i++)
   {
      if(gSwingHighCount >= 50) break;
      if(IsSwingHigh(i, high))
      { gSwingHighs[gSwingHighCount] = high[i]; gSwingHighCount = gSwingHighCount + 1; }
   }
   for(int i = SwingRightBars + 1; i < bars - SwingLeftBars; i++)
   {
      if(gSwingLowCount >= 50) break;
      if(IsSwingLow(i, low))
      { gSwingLows[gSwingLowCount] = low[i]; gSwingLowCount = gSwingLowCount + 1; }
   }
}

//+------------------------------------------------------------------+
//| Detect trend structure                                            |
//+------------------------------------------------------------------+
void DetectTrendStructure()
{
   gTrendDirection = 0;
   gResistance = 0;
   gSupport = 0;
   if(gSwingHighCount < 2 || gSwingLowCount < 2) return;

   double latestHigh = gSwingHighs[0];
   double prevHigh = gSwingHighs[1];
   double latestLow = gSwingLows[0];
   double prevLow = gSwingLows[1];

   if(latestHigh > prevHigh && latestLow > prevLow)
   { gTrendDirection = 1; gResistance = latestHigh; gSupport = latestLow; }
   else if(latestHigh < prevHigh && latestLow < prevLow)
   { gTrendDirection = -1; gResistance = latestHigh; gSupport = latestLow; }
}

//+------------------------------------------------------------------+
//| Breakout-Retest detection with false breakout protection          |
//+------------------------------------------------------------------+
int CheckBreakoutRetest()
{
   if(gTrendDirection == 0) return 0;
   if(gResistance <= 0 || gSupport <= 0) return 0;

   double close[];
   double open[];
   double high[];
   double low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   int needed = MaxRetestCandles + 4;
   if(CopyClose(gSymbol, PERIOD_M5, 0, needed, close) < needed) return 0;
   if(CopyOpen(gSymbol, PERIOD_M5, 0, needed, open) < needed) return 0;
   if(CopyHigh(gSymbol, PERIOD_M5, 0, needed, high) < needed) return 0;
   if(CopyLow(gSymbol, PERIOD_M5, 0, needed, low) < needed) return 0;

   if(CopyBuffer(gHandleATR, 0, 0, 3, gBufATR) < 3) return 0;
   double atr = gBufATR[1];
   double retestZone = atr * RetestATRMultiplier;
   double breakoutBuffer = BreakoutBufferPoints * gPoint;

   //--- BUY SIGNAL
   if(gTrendDirection == 1)
   {
      bool brokeRes = false;
      int breakBar = -1;
      for(int i = 2; i < needed; i++)
      {
         if(close[i] > open[i] && close[i] > gResistance + breakoutBuffer)
         { brokeRes = true; breakBar = i; break; }
      }
      if(!brokeRes) return 0;

      datetime breakTime = iTime(gSymbol, PERIOD_M5, breakBar);
      if(breakTime == gLastBreakoutTime) return 0;

      bool retestOK = false;
      for(int i = 1; i < breakBar && i <= MaxRetestCandles; i++)
      {
         if(low[i] <= gResistance + retestZone && low[i] >= gResistance - retestZone)
         { retestOK = true; break; }
      }
      if(!retestOK) return 0;

      if(close[1] > open[1] && close[1] > high[2])
      { gLastBreakoutTime = breakTime; return 1; }
   }

   //--- SELL SIGNAL
   if(gTrendDirection == -1)
   {
      bool brokeSup = false;
      int breakBar = -1;
      for(int i = 2; i < needed; i++)
      {
         if(close[i] < open[i] && close[i] < gSupport - breakoutBuffer)
         { brokeSup = true; breakBar = i; break; }
      }
      if(!brokeSup) return 0;

      datetime breakTime = iTime(gSymbol, PERIOD_M5, breakBar);
      if(breakTime == gLastBreakoutTime) return 0;

      bool retestOK = false;
      for(int i = 1; i < breakBar && i <= MaxRetestCandles; i++)
      {
         if(high[i] >= gSupport - retestZone && high[i] <= gSupport + retestZone)
         { retestOK = true; break; }
      }
      if(!retestOK) return 0;

      if(close[1] < open[1] && close[1] < low[2])
      { gLastBreakoutTime = breakTime; return -1; }
   }

   return 0;
}


//+------------------------------------------------------------------+
//| Check EMA, ADX, Spread filters                                    |
//+------------------------------------------------------------------+
bool CheckFilters(int direction)
{
   if(CopyBuffer(gHandleEMA, 0, 0, 3, gBufEMA) < 3) return false;
   if(CopyBuffer(gHandleADX, 0, 0, 3, gBufADX) < 3) return false;

   double ema200 = gBufEMA[1];
   double adxVal = gBufADX[1];

   double m15Close[];
   ArraySetAsSeries(m15Close, true);
   if(CopyClose(gSymbol, PERIOD_M15, 0, 3, m15Close) < 3) return false;

   if(direction == 1 && m15Close[1] < ema200) return false;
   if(direction == -1 && m15Close[1] > ema200) return false;
   if(adxVal < MinADXValue) return false;

   long spread = SymbolInfoInteger(gSymbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Main analysis                                                     |
//+------------------------------------------------------------------+
void AnalyzeAndTrade()
{
   if(!IsSessionActive()) return;
   DetectSwings();
   DetectTrendStructure();
   if(gTrendDirection == 0) return;
   int signal = CheckBreakoutRetest();
   if(signal == 0) return;
   if(!CheckFilters(signal)) return;
   if(signal == 1) OpenTrade(ORDER_TYPE_BUY);
   else if(signal == -1) OpenTrade(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                               |
//+------------------------------------------------------------------+
double CalcStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   if(CopyBuffer(gHandleATR, 0, 0, 3, gBufATR) < 3) return 0;
   double atr = gBufATR[1];
   double sl = 0;

   if(orderType == ORDER_TYPE_BUY)
   {
      if(gSupport > 0) sl = gSupport - atr * SL_ATR_Buffer;
      else sl = entryPrice - atr * 1.5;
   }
   else
   {
      if(gResistance > 0) sl = gResistance + atr * SL_ATR_Buffer;
      else sl = entryPrice + atr * 1.5;
   }

   long stopLevel = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double brokerMin = MathMax(stopLevel, freezeLevel) * gPoint;
   if(brokerMin <= 0) brokerMin = 10 * gPoint;

   double dist = MathAbs(entryPrice - sl);
   if(dist < brokerMin)
   {
      if(orderType == ORDER_TYPE_BUY) sl = entryPrice - brokerMin;
      else sl = entryPrice + brokerMin;
   }

   sl = MathRound(sl / gTickSize) * gTickSize;
   return NormalizeDouble(sl, gDigits);
}

//+------------------------------------------------------------------+
//| Calculate lot size                                                |
//+------------------------------------------------------------------+
double CalcLotSize(double entryPrice, double stopLoss)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
   double slDist = MathAbs(entryPrice - stopLoss);
   if(slDist <= 0 || gTickSize <= 0 || gTickValue <= 0) return 0;

   double ticksInSL = slDist / gTickSize;
   double moneyPerLot = ticksInSL * gTickValue;
   if(moneyPerLot <= 0) return 0;

   double lots = riskMoney / moneyPerLot;
   lots = MathFloor(lots / gLotStep) * gLotStep;
   lots = MathMin(lots, MaxLot);
   lots = MathMin(lots, gMaxLot);
   lots = MathMax(lots, gMinLot);
   if(lots < gMinLot) return 0;

   double margin = 0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, gSymbol, lots, entryPrice, margin)) return 0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) return 0;
   if((margin / equity) * 100.0 > 60.0) return 0;

   return NormalizeDouble(lots, 2);
}


//+------------------------------------------------------------------+
//| Open trade                                                        |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   if(gTradesToday >= MaxTradesPerDay) return;
   if(gConsecutiveLosses >= MaxConsecutiveLosses) return;

   double price = 0;
   if(orderType == ORDER_TYPE_BUY) price = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
   else price = SymbolInfoDouble(gSymbol, SYMBOL_BID);

   double sl = CalcStopLoss(orderType, price);
   if(sl <= 0) return;

   double lots = CalcLotSize(price, sl);
   if(lots <= 0) return;

   double slDist = MathAbs(price - sl);
   double tp = 0;
   if(orderType == ORDER_TYPE_BUY) tp = price + slDist * RiskRewardRatio;
   else tp = price - slDist * RiskRewardRatio;
   tp = MathRound(tp / gTickSize) * gTickSize;
   tp = NormalizeDouble(tp, gDigits);

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

   bool sent = OrderSend(request, result);
   if(sent && result.retcode == TRADE_RETCODE_DONE)
   {
      gCurrentTicket = result.order;
      gTradesToday = gTradesToday + 1;
      SaveDailyState();
      Print("Opened: ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " Lots=", lots, " SL=", sl, " TP=", tp);
   }
   else
   { Print("OrderSend failed: ", result.retcode, " ", result.comment); }
}

//+------------------------------------------------------------------+
//| Find EA position                                                  |
//+------------------------------------------------------------------+
ulong FindMyPosition()
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == gSymbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return ticket;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Modify SL helper                                                  |
//+------------------------------------------------------------------+
void ModifySL(double newSL, double currentTP)
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
   { Print("SL modify failed: ", result.retcode); }
}


//+------------------------------------------------------------------+
//| Position management: break-even and ATR trailing                  |
//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!PositionSelectByTicket(gCurrentTicket)) return;

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   double currentPrice = 0;
   if(posType == POSITION_TYPE_BUY) currentPrice = SymbolInfoDouble(gSymbol, SYMBOL_BID);
   else currentPrice = SymbolInfoDouble(gSymbol, SYMBOL_ASK);

   double slDist = MathAbs(openPrice - currentSL);
   if(slDist <= 0) return;

   double profit = 0;
   if(posType == POSITION_TYPE_BUY) profit = currentPrice - openPrice;
   else profit = openPrice - currentPrice;

   double rMultiple = profit / slDist;

   long stopLevel = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopLevel * gPoint;
   if(minDist <= 0) minDist = 10 * gPoint;

   //--- Break-even at +1.0R
   if(rMultiple >= BreakEvenTriggerR && rMultiple < TrailingStartR)
   {
      double newSL = 0;
      if(posType == POSITION_TYPE_BUY) newSL = openPrice + slDist * BreakEvenLockR;
      else newSL = openPrice - slDist * BreakEvenLockR;

      newSL = MathRound(newSL / gTickSize) * gTickSize;
      newSL = NormalizeDouble(newSL, gDigits);

      bool shouldMove = false;
      if(posType == POSITION_TYPE_BUY && newSL > currentSL) shouldMove = true;
      if(posType == POSITION_TYPE_SELL && newSL < currentSL) shouldMove = true;

      if(shouldMove && MathAbs(currentPrice - newSL) >= minDist)
         ModifySL(newSL, currentTP);
   }

   //--- Trailing at +1.3R
   if(rMultiple >= TrailingStartR)
   {
      if(CopyBuffer(gHandleATR, 0, 0, 3, gBufATR) < 3) return;
      double atr = gBufATR[1];
      double trailDist = atr * TrailingATRMultiplier;

      double trailSL = 0;
      if(posType == POSITION_TYPE_BUY) trailSL = currentPrice - trailDist;
      else trailSL = currentPrice + trailDist;

      trailSL = MathRound(trailSL / gTickSize) * gTickSize;
      trailSL = NormalizeDouble(trailSL, gDigits);

      bool shouldTrail = false;
      if(posType == POSITION_TYPE_BUY && trailSL > currentSL) shouldTrail = true;
      if(posType == POSITION_TYPE_SELL && trailSL < currentSL) shouldTrail = true;

      if(shouldTrail && MathAbs(currentPrice - trailSL) >= minDist)
         ModifySL(trailSL, currentTP);
   }
}

//+------------------------------------------------------------------+
//| Check closed trades                                               |
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   if(!HistorySelect(0, TimeCurrent())) return;
   int totalDeals = HistoryDealsTotal();
   if(totalDeals <= gLastDealsCount) { gLastDealsCount = totalDeals; return; }

   for(int i = gLastDealsCount; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != gSymbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;

      double netPL = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                   + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                   + HistoryDealGetDouble(ticket, DEAL_SWAP);

      if(netPL < 0) gConsecutiveLosses = gConsecutiveLosses + 1;
      else if(netPL > 0) gConsecutiveLosses = 0;

      gCurrentTicket = 0;
      SaveDailyState();
   }
   gLastDealsCount = totalDeals;
}


//+------------------------------------------------------------------+
//| Day key (broker server time based)                                |
//+------------------------------------------------------------------+
int GetDayKey()
{
   MqlDateTime dt;
   datetime refTime = TimeCurrent();
   TimeToStruct(refTime, dt);
   if(dt.hour < DailyResetHourNY)
   { refTime = refTime - 86400; TimeToStruct(refTime, dt); }
   return dt.year * 10000 + dt.mon * 100 + dt.day;
}

//+------------------------------------------------------------------+
//| Save daily state                                                  |
//+------------------------------------------------------------------+
void SaveDailyState()
{
   string p = "XAU3F_" + IntegerToString(MagicNumber) + "_" + gSymbol;
   GlobalVariableSet(p + "_K", (double)gTradingDayKey);
   GlobalVariableSet(p + "_R", gDailyReference);
   GlobalVariableSet(p + "_T", (double)gTradesToday);
   GlobalVariableSet(p + "_L", (double)gConsecutiveLosses);
}

//+------------------------------------------------------------------+
//| Load daily state                                                  |
//+------------------------------------------------------------------+
void LoadDailyState()
{
   string p = "XAU3F_" + IntegerToString(MagicNumber) + "_" + gSymbol;
   int keyNow = GetDayKey();
   if(GlobalVariableCheck(p + "_K"))
   {
      int savedKey = (int)GlobalVariableGet(p + "_K");
      if(savedKey == keyNow)
      {
         gTradingDayKey = keyNow;
         gDailyReference = GlobalVariableGet(p + "_R");
         gTradesToday = (int)GlobalVariableGet(p + "_T");
         gConsecutiveLosses = (int)GlobalVariableGet(p + "_L");
         return;
      }
   }
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   gDailyReference = MathMax(bal, eq);
   gTradingDayKey = keyNow;
   gTradesToday = 0;
   gConsecutiveLosses = 0;
   SaveDailyState();
}

//+------------------------------------------------------------------+
//| Check daily reset                                                 |
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
   }
}

//+------------------------------------------------------------------+
//| Update risk limits                                                |
//+------------------------------------------------------------------+
void UpdateRiskLimits()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = equity - gDailyReference;
   double dailyPct = 0;
   if(gDailyReference > 0) dailyPct = (dailyPL / gDailyReference) * 100.0;

   gTradingAllowed = true;
   gBlockReason = "OK";

   if(dailyPct <= -DailyLossLimit)
   { gTradingAllowed = false; gBlockReason = "Daily Loss"; return; }
   if(dailyPct >= DailyProfitTarget)
   { gTradingAllowed = false; gBlockReason = "Daily Target"; return; }
   if(gTradesToday >= MaxTradesPerDay)
   { gTradingAllowed = false; gBlockReason = "Max Trades"; return; }
   if(gConsecutiveLosses >= MaxConsecutiveLosses)
   { gTradingAllowed = false; gBlockReason = "Consec Loss"; return; }
   if(FindMyPosition() > 0)
   { gTradingAllowed = false; gBlockReason = "In Trade"; }
}

//+------------------------------------------------------------------+
//| Chart display                                                     |
//+------------------------------------------------------------------+
void ShowStatus()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = equity - gDailyReference;
   long spread = SymbolInfoInteger(gSymbol, SYMBOL_SPREAD);

   string trend = "RANGE";
   if(gTrendDirection == 1) trend = "BULLISH";
   if(gTrendDirection == -1) trend = "BEARISH";

   string session = "CLOSED";
   if(IsSessionActive()) session = "ACTIVE";

   string stat = "BLOCKED";
   if(gTradingAllowed) stat = "READY";

   string posInfo = "None";
   if(gCurrentTicket > 0) posInfo = "Active #" + IntegerToString((long)gCurrentTicket);

   string s = "=== XAU Smart EA V3 Final ===";
   s = s + "\n" + gSymbol + " | Spread: " + IntegerToString(spread);
   s = s + "\nSession: " + session + " | Trend: " + trend;
   s = s + "\nStatus: " + stat + " | " + gBlockReason;
   s = s + "\nTrades: " + IntegerToString(gTradesToday) + "/" + IntegerToString(MaxTradesPerDay);
   s = s + "\nLosses: " + IntegerToString(gConsecutiveLosses) + "/" + IntegerToString(MaxConsecutiveLosses);
   s = s + "\nDaily PL: $" + DoubleToString(dailyPL, 2);
   s = s + "\nEquity: $" + DoubleToString(equity, 2);
   s = s + "\nPosition: " + posInfo;
   s = s + "\nR: " + DoubleToString(gResistance, gDigits) + " | S: " + DoubleToString(gSupport, gDigits);
   Comment(s);
}
//+------------------------------------------------------------------+

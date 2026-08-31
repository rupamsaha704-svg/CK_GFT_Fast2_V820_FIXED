//+------------------------------------------------------------------+
//|                              Institutional_Gold_Trader_Pro.mq5   |
//|                                        Copyright 2024, XAU Smart |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, XAU Smart"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input double RiskPercent              = 0.25;
input double MaxLot                   = 0.05;
input double RiskRewardRatio          = 2.0;
input int    MaxTradesPerDay          = 5;
input int    MaxOpenTrades            = 1;
input int    MaxConsecutiveLosses     = 3;
input double DailyLossLimit           = 1.25;
input double DailyProfitTarget        = 1.50;
input double MaxOverallLoss           = 6.0;
input double EvaluationBalance        = 5000.0;
input double MaxMarginUsage           = 60.0;
input int    MaxSpreadPoints          = 30;
input int    MaxSlippagePoints        = 10;
input long   MagicNumber              = 20260725;
input string TradeComment             = "XAU Smart EA";
input bool   EnableLondonSession      = true;
input bool   EnableNewYorkSession     = true;
input int    LondonStartHour          = 8;
input int    LondonEndHour            = 12;
input int    NewYorkStartHour         = 13;
input int    NewYorkEndHour           = 20;
input int    SwingLookback            = 2;
input int    MaxSwingDistance         = 100;
input double RetestZonePoints         = 20.0;
input int    MaxRetestCandles         = 5;
input int    EMA200Period             = 200;
input int    ATRPeriod                = 14;
input int    ADXPeriod                = 14;
input int    MinADXValue              = 25;
input int    DailyResetHour           = 17;

int hEMA200;
int hATR;
int hADX;

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
double gSwingHighs[];
double gSwingLows[];
int gSwingHighCount;
int gSwingLowCount;
double gResistance;
double gSupport;
int gTrendDirection;
double gEMABuffer[];
double gATRBuffer[];
double gADXBuffer[];

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
   
   hEMA200 = iMA(gSymbol, PERIOD_M5, EMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   hATR = iATR(gSymbol, PERIOD_M5, ATRPeriod);
   hADX = iADX(gSymbol, PERIOD_M5, ADXPeriod);
   
   if(hEMA200 == INVALID_HANDLE || hATR == INVALID_HANDLE || hADX == INVALID_HANDLE)
      return INIT_FAILED;
   
   ArraySetAsSeries(gEMABuffer, true);
   ArraySetAsSeries(gATRBuffer, true);
   ArraySetAsSeries(gADXBuffer, true);
   ArrayResize(gSwingHighs, 50);
   ArrayResize(gSwingLows, 50);
   
   gSwingHighCount = 0;
   gSwingLowCount = 0;
   gTrendDirection = 0;
   gResistance = 0;
   gSupport = 0;
   gLastBarTime = 0;
   gBlockReason = "OK";
   
   LoadDailyState();
   gCurrentTicket = FindPosition();
   EventSetTimer(30);
   
   Print("Institutional Gold Trader Pro initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(hEMA200 != INVALID_HANDLE) IndicatorRelease(hEMA200);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
   SaveDailyState();
   Comment("");
}

void OnTick()
{
   CheckDailyReset();
   UpdateRiskLimits();
   gCurrentTicket = FindPosition();
   
   if(gCurrentTicket > 0)
      ManagePosition();
   else if(gTradingAllowed)
   {
      datetime currentBar = iTime(gSymbol, PERIOD_M5, 0);
      if(currentBar != gLastBarTime)
      {
         gLastBarTime = currentBar;
         AnalyzeMarket();
      }
   }
}

void OnTimer()
{
   CheckDailyReset();
   UpdateRiskLimits();
   ShowStatus();
}

bool IsSessionActive()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   bool londonOK = EnableLondonSession && dt.hour >= LondonStartHour && dt.hour < LondonEndHour;
   bool nyOK = EnableNewYorkSession && dt.hour >= NewYorkStartHour && dt.hour < NewYorkEndHour;
   return londonOK || nyOK;
}

bool IsSwingHigh(int index, const double &high[])
{
   if(index < SwingLookback || index >= ArraySize(high) - SwingLookback) return false;
   double checkHigh = high[index];
   for(int i = 1; i <= SwingLookback; i++)
   {
      if(high[index - i] >= checkHigh) return false;
      if(high[index + i] >= checkHigh) return false;
   }
   return true;
}

bool IsSwingLow(int index, const double &low[])
{
   if(index < SwingLookback || index >= ArraySize(low) - SwingLookback) return false;
   double checkLow = low[index];
   for(int i = 1; i <= SwingLookback; i++)
   {
      if(low[index - i] <= checkLow) return false;
      if(low[index + i] <= checkLow) return false;
   }
   return true;
}

void DetectSwings()
{
   gSwingHighCount = 0;
   gSwingLowCount = 0;
   
   double high[];
   double low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   int bars = MathMin(MaxSwingDistance, iBars(gSymbol, PERIOD_M15));
   if(CopyHigh(gSymbol, PERIOD_M15, 0, bars, high) != bars) return;
   if(CopyLow(gSymbol, PERIOD_M15, 0, bars, low) != bars) return;
   
   for(int i = SwingLookback + 1; i < bars - SwingLookback && gSwingHighCount < 50; i++)
   {
      if(IsSwingHigh(i, high))
      {
         gSwingHighs[gSwingHighCount] = high[i];
         gSwingHighCount++;
      }
   }
   
   for(int i = SwingLookback + 1; i < bars - SwingLookback && gSwingLowCount < 50; i++)
   {
      if(IsSwingLow(i, low))
      {
         gSwingLows[gSwingLowCount] = low[i];
         gSwingLowCount++;
      }
   }
}

void DetectTrendStructure()
{
   gTrendDirection = 0;
   if(gSwingHighCount < 2 || gSwingLowCount < 2) return;
   
   double sh1 = gSwingHighs[0];
   double sh2 = gSwingHighs[1];
   double sl1 = gSwingLows[0];
   double sl2 = gSwingLows[1];
   
   if(sh1 > sh2 && sl1 > sl2)
   {
      gTrendDirection = 1;
      gResistance = sh1;
      gSupport = sl1;
   }
   else if(sh1 < sh2 && sl1 < sl2)
   {
      gTrendDirection = -1;
      gResistance = sh1;
      gSupport = sl1;
   }
}

int CheckBreakoutRetest()
{
   if(gTrendDirection == 0 || gResistance <= 0 || gSupport <= 0) return 0;
   
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(gSymbol, PERIOD_M5, 0, MaxRetestCandles + 5, close) < MaxRetestCandles + 5) return 0;
   
   double currentPrice = close[0];
   double retestZone = RetestZonePoints * gPoint;
   
   if(gTrendDirection == 1)
   {
      bool brokeResistance = false;
      for(int i = 1; i <= MaxRetestCandles; i++)
         if(close[i] > gResistance) brokeResistance = true;
      
      if(brokeResistance && currentPrice >= gResistance - retestZone && currentPrice <= gResistance + retestZone)
         if(close[0] > close[1]) return 1;
   }
   else if(gTrendDirection == -1)
   {
      bool brokeSupport = false;
      for(int i = 1; i <= MaxRetestCandles; i++)
         if(close[i] < gSupport) brokeSupport = true;
      
      if(brokeSupport && currentPrice >= gSupport - retestZone && currentPrice <= gSupport + retestZone)
         if(close[0] < close[1]) return -1;
   }
   return 0;
}

bool CheckFilters(int direction)
{
   if(CopyBuffer(hEMA200, 0, 0, 5, gEMABuffer) != 5) return false;
   if(CopyBuffer(hATR, 0, 0, 25, gATRBuffer) != 25) return false;
   if(CopyBuffer(hADX, 0, 0, 5, gADXBuffer) != 5) return false;
   
   double ema200 = gEMABuffer[1];
   double atrNow = gATRBuffer[1];
   double adxNow = gADXBuffer[0];
   double currentPrice = SymbolInfoDouble(gSymbol, SYMBOL_BID);
   
   if(direction == 1 && currentPrice < ema200) return false;
   if(direction == -1 && currentPrice > ema200) return false;
   if(adxNow < MinADXValue) return false;
   
   double avgATR = 0;
   for(int i = 1; i <= 20; i++) avgATR += gATRBuffer[i];
   avgATR /= 20.0;
   if(atrNow < avgATR * 0.8) return false;
   
   long spread = SymbolInfoInteger(gSymbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints) return false;
   
   return true;
}

void AnalyzeMarket()
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

double CalcStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   if(CopyBuffer(hATR, 0, 0, 5, gATRBuffer) != 5) return 0;
   double atr = gATRBuffer[1];
   double sl = 0;
   
   if(orderType == ORDER_TYPE_BUY)
      sl = (gSupport > 0) ? gSupport - atr * 0.3 : entryPrice - atr * 1.5;
   else
      sl = (gResistance > 0) ? gResistance + atr * 0.3 : entryPrice + atr * 1.5;
   
   double minDist = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_STOPS_LEVEL) * gPoint * 1.5;
   if(MathAbs(entryPrice - sl) < minDist)
      sl = (orderType == ORDER_TYPE_BUY) ? entryPrice - minDist : entryPrice + minDist;
   
   return NormalizeDouble(sl, gDigits);
}

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
   if((margin / equity) * 100.0 > MaxMarginUsage) return 0;
   
   return NormalizeDouble(lots, 2);
}

void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   if(gTradesToday >= MaxTradesPerDay) return;
   if(gConsecutiveLosses >= MaxConsecutiveLosses) return;
   
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(gSymbol, SYMBOL_ASK) : SymbolInfoDouble(gSymbol, SYMBOL_BID);
   double sl = CalcStopLoss(orderType, price);
   if(sl <= 0) return;
   
   double lots = CalcLotSize(price, sl);
   if(lots <= 0) return;
   
   double slDist = MathAbs(price - sl);
   double tp = (orderType == ORDER_TYPE_BUY) ? price + slDist * RiskRewardRatio : price - slDist * RiskRewardRatio;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_DEAL;
   request.symbol = gSymbol;
   request.volume = lots;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = NormalizeDouble(tp, gDigits);
   request.deviation = MaxSlippagePoints;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         gCurrentTicket = result.order;
         gTradesToday++;
         SaveDailyState();
      }
   }
}

ulong FindPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == gSymbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return ticket;
   }
   return 0;
}

void ManagePosition()
{
   if(!PositionSelectByTicket(gCurrentTicket)) return;
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(gSymbol, SYMBOL_BID) : SymbolInfoDouble(gSymbol, SYMBOL_ASK);
   
   double slDist = MathAbs(openPrice - currentSL);
   if(slDist <= 0) return;
   
   double profit = (posType == POSITION_TYPE_BUY) ? currentPrice - openPrice : openPrice - currentPrice;
   double rMultiple = profit / slDist;
   
   if(rMultiple >= 1.0)
   {
      double newSL = (posType == POSITION_TYPE_BUY) ? openPrice + slDist * 0.05 : openPrice - slDist * 0.05;
      bool shouldMove = (posType == POSITION_TYPE_BUY && newSL > currentSL) || (posType == POSITION_TYPE_SELL && newSL < currentSL);
      
      if(shouldMove)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         request.action = TRADE_ACTION_SLTP;
         request.symbol = gSymbol;
         request.position = gCurrentTicket;
         request.sl = NormalizeDouble(newSL, gDigits);
         request.tp = currentTP;
         if(OrderSend(request, result)) { }
      }
   }
   
   if(rMultiple >= 1.3)
   {
      if(CopyBuffer(hATR, 0, 0, 3, gATRBuffer) != 3) return;
      double trailDist = gATRBuffer[1];
      double trailSL = (posType == POSITION_TYPE_BUY) ? currentPrice - trailDist : currentPrice + trailDist;
      bool shouldTrail = (posType == POSITION_TYPE_BUY && trailSL > currentSL) || (posType == POSITION_TYPE_SELL && trailSL < currentSL);
      
      if(shouldTrail)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         request.action = TRADE_ACTION_SLTP;
         request.symbol = gSymbol;
         request.position = gCurrentTicket;
         request.sl = NormalizeDouble(trailSL, gDigits);
         request.tp = currentTP;
         if(OrderSend(request, result)) { }
      }
   }
}

int GetNYDayKey()
{
   datetime gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   int offset = (dt.mon >= 3 && dt.mon <= 11) ? -4 : -5;
   datetime nyTime = gmt + offset * 3600;
   TimeToStruct(nyTime, dt);
   if(dt.hour < DailyResetHour)
   {
      nyTime -= 86400;
      TimeToStruct(nyTime, dt);
   }
   return dt.year * 10000 + dt.mon * 100 + dt.day;
}

void SaveDailyState()
{
   string prefix = StringFormat("IGT_%I64d_%s", MagicNumber, gSymbol);
   GlobalVariableSet(prefix + "_KEY", (double)gTradingDayKey);
   GlobalVariableSet(prefix + "_REF", gDailyReference);
   GlobalVariableSet(prefix + "_TRADES", (double)gTradesToday);
   GlobalVariableSet(prefix + "_LOSSES", (double)gConsecutiveLosses);
}

void LoadDailyState()
{
   string prefix = StringFormat("IGT_%I64d_%s", MagicNumber, gSymbol);
   int keyNow = GetNYDayKey();
   if(GlobalVariableCheck(prefix + "_KEY") && (int)GlobalVariableGet(prefix + "_KEY") == keyNow)
   {
      gTradingDayKey = keyNow;
      gDailyReference = GlobalVariableGet(prefix + "_REF");
      gTradesToday = (int)GlobalVariableGet(prefix + "_TRADES");
      gConsecutiveLosses = (int)GlobalVariableGet(prefix + "_LOSSES");
   }
   else
   {
      gDailyReference = MathMax(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY));
      gTradingDayKey = keyNow;
      gTradesToday = 0;
      gConsecutiveLosses = 0;
      SaveDailyState();
   }
}

void CheckDailyReset()
{
   int keyNow = GetNYDayKey();
   if(keyNow != gTradingDayKey)
   {
      gDailyReference = MathMax(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY));
      gTradingDayKey = keyNow;
      gTradesToday = 0;
      gConsecutiveLosses = 0;
      SaveDailyState();
   }
}

void UpdateRiskLimits()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = equity - gDailyReference;
   double dailyPct = (dailyPL / gDailyReference) * 100.0;
   double overallPct = ((equity - EvaluationBalance) / EvaluationBalance) * 100.0;
   
   gTradingAllowed = true;
   gBlockReason = "OK";
   
   if(dailyPct <= -DailyLossLimit) { gTradingAllowed = false; gBlockReason = "Daily Loss"; return; }
   if(dailyPct >= DailyProfitTarget) { gTradingAllowed = false; gBlockReason = "Daily Target"; return; }
   if(overallPct <= -MaxOverallLoss) { gTradingAllowed = false; gBlockReason = "Max Loss"; return; }
   if(gTradesToday >= MaxTradesPerDay) { gTradingAllowed = false; gBlockReason = "Max Trades"; return; }
   if(gConsecutiveLosses >= MaxConsecutiveLosses) { gTradingAllowed = false; gBlockReason = "Consec Loss"; return; }
   if(FindPosition() > 0) { gTradingAllowed = false; gBlockReason = "In Trade"; }
}

void ShowStatus()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = equity - gDailyReference;
   string trend = "RANGE";
   if(gTrendDirection == 1) trend = "BULLISH";
   if(gTrendDirection == -1) trend = "BEARISH";
   string session = IsSessionActive() ? "ACTIVE" : "CLOSED";
   
   Comment("=== Institutional Gold Trader Pro ===",
           "\nStatus: ", (gTradingAllowed ? "READY" : "BLOCKED"), " | ", gBlockReason,
           "\nTrend: ", trend, " | Session: ", session,
           "\nTrades: ", gTradesToday, "/", MaxTradesPerDay,
           "\nLosses: ", gConsecutiveLosses, "/", MaxConsecutiveLosses,
           "\nDaily PL: $", DoubleToString(dailyPL, 2),
           "\nR: ", DoubleToString(gResistance, gDigits), " S: ", DoubleToString(gSupport, gDigits));
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != gSymbol) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != MagicNumber) return;
   
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
   {
      double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
      if(profit < 0) gConsecutiveLosses++;
      else if(profit > 0) gConsecutiveLosses = 0;
      gCurrentTicket = 0;
      SaveDailyState();
   }
}
//+------------------------------------------------------------------+

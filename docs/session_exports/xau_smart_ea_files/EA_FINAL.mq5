//+------------------------------------------------------------------+
//|                              Institutional_Gold_Trader_Pro.mq5   |
//|                                        Copyright 2024, XAU Smart |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, XAU Smart"
#property link      "https://www.mql5.com"
#property version   "2.00"
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
int gLastDealsCount;

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
   {
      Print("Failed to create indicators");
      return INIT_FAILED;
   }
   
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
   gLastDealsCount = 0;
   
   LoadDailyState();
   gCurrentTicket = FindPosition();
   EventSetTimer(30);
   
   Print("Institutional Gold Trader Pro v2.0 initialized");
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
   CheckClosedTrades();
   UpdateRiskLimits();
   gCurrentTicket = FindPosition();
   
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
         AnalyzeMarket();
      }
   }
   ShowStatus();
}

void OnTimer()
{
   CheckDailyReset();
   UpdateRiskLimits();
   ShowStatus();
}

void CheckClosedTrades()
{
   if(!HistorySelect(0, TimeCurrent())) return;
   
   int totalDeals = HistoryDealsTotal();
   if(totalDeals <= gLastDealsCount)
   {
      gLastDealsCount = totalDeals;
      return;
   }
   
   for(int i = gLastDealsCount; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      string dealSymbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      
      if(dealSymbol != gSymbol) continue;
      if(dealMagic != MagicNumber) continue;
      if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY) continue;
      
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
   }
   
   gLastDealsCount = totalDeals;
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
   if(index < SwingLookback) return false;
   if(index >= ArraySize(high) - SwingLookback) return false;
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
   if(index < SwingLookback) return false;
   if(index >= ArraySize(low) - SwingLookback) return false;
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
         gSwingHighCount = gSwingHighCount + 1;
      }
   }
   
   for(int i = SwingLookback + 1; i < bars - SwingLookback && gSwingLowCount < 50; i++)
   {
      if(IsSwingLow(i, low))
      {
         gSwingLows[gSwingLowCount] = low[i];
         gSwingLowCount = gSwingLowCount + 1;
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
   if(gTrendDirection == 0) return 0;
   if(gResistance <= 0 || gSupport <= 0) return 0;
   
   double close[];
   ArraySetAsSeries(close, true);
   int needed = MaxRetestCandles + 5;
   if(CopyClose(gSymbol, PERIOD_M5, 0, needed, close) < needed) return 0;
   
   double currentPrice = close[0];
   double retestZone = RetestZonePoints * gPoint;
   
   if(gTrendDirection == 1)
   {
      bool brokeResistance = false;
      for(int i = 1; i <= MaxRetestCandles; i++)
      {
         if(close[i] > gResistance) brokeResistance = true;
      }
      
      if(brokeResistance)
      {
         if(currentPrice >= gResistance - retestZone && currentPrice <= gResistance + retestZone)
         {
            if(close[0] > close[1]) return 1;
         }
      }
   }
   else if(gTrendDirection == -1)
   {
      bool brokeSupport = false;
      for(int i = 1; i <= MaxRetestCandles; i++)
      {
         if(close[i] < gSupport) brokeSupport = true;
      }
      
      if(brokeSupport)
      {
         if(currentPrice >= gSupport - retestZone && currentPrice <= gSupport + retestZone)
         {
            if(close[0] < close[1]) return -1;
         }
      }
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
   for(int i = 1; i <= 20; i++)
   {
      avgATR = avgATR + gATRBuffer[i];
   }
   avgATR = avgATR / 20.0;
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
   {
      if(gSupport > 0)
         sl = gSupport - atr * 0.3;
      else
         sl = entryPrice - atr * 1.5;
   }
   else
   {
      if(gResistance > 0)
         sl = gResistance + atr * 0.3;
      else
         sl = entryPrice + atr * 1.5;
   }
   
   double minDist = SymbolInfoInteger(gSymbol, SYMBOL_TRADE_STOPS_LEVEL) * gPoint * 1.5;
   double diff = MathAbs(entryPrice - sl);
   if(diff < minDist)
   {
      if(orderType == ORDER_TYPE_BUY)
         sl = entryPrice - minDist;
      else
         sl = entryPrice + minDist;
   }
   
   return NormalizeDouble(sl, gDigits);
}


double CalcLotSize(double entryPrice, double stopLoss)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
   double slDist = MathAbs(entryPrice - stopLoss);
   if(slDist <= 0) return 0;
   if(gTickSize <= 0) return 0;
   if(gTickValue <= 0) return 0;
   
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
   bool ok = OrderCalcMargin(ORDER_TYPE_BUY, gSymbol, lots, entryPrice, margin);
   if(!ok) return 0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginPct = (margin / equity) * 100.0;
   if(marginPct > MaxMarginUsage) return 0;
   
   return NormalizeDouble(lots, 2);
}

void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   if(gTradesToday >= MaxTradesPerDay) return;
   if(gConsecutiveLosses >= MaxConsecutiveLosses) return;
   
   double price = 0;
   if(orderType == ORDER_TYPE_BUY)
      price = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
   else
      price = SymbolInfoDouble(gSymbol, SYMBOL_BID);
   
   double sl = CalcStopLoss(orderType, price);
   if(sl <= 0) return;
   
   double lots = CalcLotSize(price, sl);
   if(lots <= 0) return;
   
   double slDist = MathAbs(price - sl);
   double tp = 0;
   if(orderType == ORDER_TYPE_BUY)
      tp = price + slDist * RiskRewardRatio;
   else
      tp = price - slDist * RiskRewardRatio;
   
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
   request.tp = NormalizeDouble(tp, gDigits);
   request.deviation = MaxSlippagePoints;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   
   bool sent = OrderSend(request, result);
   if(sent)
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         gCurrentTicket = result.order;
         gTradesToday = gTradesToday + 1;
         SaveDailyState();
      }
   }
}


ulong FindPosition()
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      bool selected = PositionSelectByTicket(ticket);
      if(!selected) continue;
      
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      long posMagic = PositionGetInteger(POSITION_MAGIC);
      
      if(posSymbol == gSymbol && posMagic == MagicNumber)
         return ticket;
   }
   return 0;
}

void ManagePosition()
{
   bool selected = PositionSelectByTicket(gCurrentTicket);
   if(!selected) return;
   
   long posTypeVal = PositionGetInteger(POSITION_TYPE);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)posTypeVal;
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   
   double currentPrice = 0;
   if(posType == POSITION_TYPE_BUY)
      currentPrice = SymbolInfoDouble(gSymbol, SYMBOL_BID);
   else
      currentPrice = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
   
   double slDist = MathAbs(openPrice - currentSL);
   if(slDist <= 0) return;
   
   double profit = 0;
   if(posType == POSITION_TYPE_BUY)
      profit = currentPrice - openPrice;
   else
      profit = openPrice - currentPrice;
   
   double rMultiple = profit / slDist;
   
   if(rMultiple >= 1.0)
   {
      double newSL = 0;
      if(posType == POSITION_TYPE_BUY)
         newSL = openPrice + slDist * 0.05;
      else
         newSL = openPrice - slDist * 0.05;
      
      bool shouldMove = false;
      if(posType == POSITION_TYPE_BUY && newSL > currentSL)
         shouldMove = true;
      if(posType == POSITION_TYPE_SELL && newSL < currentSL)
         shouldMove = true;
      
      if(shouldMove)
      {
         MqlTradeRequest request;
         MqlTradeResult result;
         ZeroMemory(request);
         ZeroMemory(result);
         
         request.action = TRADE_ACTION_SLTP;
         request.symbol = gSymbol;
         request.position = gCurrentTicket;
         request.sl = NormalizeDouble(newSL, gDigits);
         request.tp = currentTP;
         
         bool sent = OrderSend(request, result);
         if(sent) { }
      }
   }
   
   if(rMultiple >= 1.3)
   {
      if(CopyBuffer(hATR, 0, 0, 3, gATRBuffer) != 3) return;
      double trailDist = gATRBuffer[1];
      
      double trailSL = 0;
      if(posType == POSITION_TYPE_BUY)
         trailSL = currentPrice - trailDist;
      else
         trailSL = currentPrice + trailDist;
      
      bool shouldTrail = false;
      if(posType == POSITION_TYPE_BUY && trailSL > currentSL)
         shouldTrail = true;
      if(posType == POSITION_TYPE_SELL && trailSL < currentSL)
         shouldTrail = true;
      
      if(shouldTrail)
      {
         MqlTradeRequest request;
         MqlTradeResult result;
         ZeroMemory(request);
         ZeroMemory(result);
         
         request.action = TRADE_ACTION_SLTP;
         request.symbol = gSymbol;
         request.position = gCurrentTicket;
         request.sl = NormalizeDouble(trailSL, gDigits);
         request.tp = currentTP;
         
         bool sent = OrderSend(request, result);
         if(sent) { }
      }
   }
}


int GetNYDayKey()
{
   datetime gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   
   int offset = -5;
   if(dt.mon >= 3 && dt.mon <= 11)
      offset = -4;
   
   datetime nyTime = gmt + offset * 3600;
   TimeToStruct(nyTime, dt);
   
   if(dt.hour < DailyResetHour)
   {
      nyTime = nyTime - 86400;
      TimeToStruct(nyTime, dt);
   }
   
   int key = dt.year * 10000 + dt.mon * 100 + dt.day;
   return key;
}

void SaveDailyState()
{
   string prefix = "IGT_" + IntegerToString(MagicNumber) + "_" + gSymbol;
   GlobalVariableSet(prefix + "_KEY", (double)gTradingDayKey);
   GlobalVariableSet(prefix + "_REF", gDailyReference);
   GlobalVariableSet(prefix + "_TRADES", (double)gTradesToday);
   GlobalVariableSet(prefix + "_LOSSES", (double)gConsecutiveLosses);
}

void LoadDailyState()
{
   string prefix = "IGT_" + IntegerToString(MagicNumber) + "_" + gSymbol;
   int keyNow = GetNYDayKey();
   
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
   
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   gDailyReference = MathMax(bal, eq);
   gTradingDayKey = keyNow;
   gTradesToday = 0;
   gConsecutiveLosses = 0;
   SaveDailyState();
}

void CheckDailyReset()
{
   int keyNow = GetNYDayKey();
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


void UpdateRiskLimits()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = equity - gDailyReference;
   double dailyPct = (dailyPL / gDailyReference) * 100.0;
   double overallPct = ((equity - EvaluationBalance) / EvaluationBalance) * 100.0;
   
   gTradingAllowed = true;
   gBlockReason = "OK";
   
   if(dailyPct <= -DailyLossLimit)
   {
      gTradingAllowed = false;
      gBlockReason = "Daily Loss";
      return;
   }
   
   if(dailyPct >= DailyProfitTarget)
   {
      gTradingAllowed = false;
      gBlockReason = "Daily Target";
      return;
   }
   
   if(overallPct <= -MaxOverallLoss)
   {
      gTradingAllowed = false;
      gBlockReason = "Max Loss";
      return;
   }
   
   if(gTradesToday >= MaxTradesPerDay)
   {
      gTradingAllowed = false;
      gBlockReason = "Max Trades";
      return;
   }
   
   if(gConsecutiveLosses >= MaxConsecutiveLosses)
   {
      gTradingAllowed = false;
      gBlockReason = "Consec Loss";
      return;
   }
   
   ulong pos = FindPosition();
   if(pos > 0)
   {
      gTradingAllowed = false;
      gBlockReason = "In Trade";
   }
}

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
   
   string line1 = "=== Institutional Gold Trader Pro v2 ===";
   string line2 = "Status: " + stat + " | " + gBlockReason;
   string line3 = "Trend: " + trend + " | Session: " + session;
   string line4 = "Trades: " + IntegerToString(gTradesToday) + "/" + IntegerToString(MaxTradesPerDay);
   string line5 = "Losses: " + IntegerToString(gConsecutiveLosses) + "/" + IntegerToString(MaxConsecutiveLosses);
   string line6 = "Daily PL: $" + DoubleToString(dailyPL, 2);
   string line7 = "R: " + DoubleToString(gResistance, gDigits) + " S: " + DoubleToString(gSupport, gDigits);
   
   string output = line1 + "\n" + line2 + "\n" + line3 + "\n" + line4 + "\n" + line5 + "\n" + line6 + "\n" + line7;
   Comment(output);
}
//+------------------------------------------------------------------+

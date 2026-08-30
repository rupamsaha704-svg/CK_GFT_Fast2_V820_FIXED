//+------------------------------------------------------------------+
//| GFT_2Step_5K_EA.mq5                                             |
//| XAUUSD M5 - GFT 2-Step 5K risk-managed Expert Advisor           |
//+------------------------------------------------------------------+
#property strict
#property version   "3.00"
#property description "GFT 2-Step 5K EA for XAUUSD M5"

input double RiskPercent              = 0.25;
input double MaxLot                   = 0.05;
input double RiskRewardRatio          = 2.0;
input int    MaxTradesPerDay          = 3;
input int    MaxOpenTrades            = 1;
input int    MaxConsecutiveLosses     = 2;
input double DailyLossLimit           = 1.25;
input double DailyProfitTarget        = 1.50;
input double MaxOverallLoss           = 6.0;
input int    MaxSpreadPoints          = 40;
input double MaxMarginUsage           = 60.0;
input bool   UseTrendFilter           = true;
input ENUM_TIMEFRAMES TrendTimeframe  = PERIOD_M15;
input int    FastEMA                  = 21;
input int    SlowEMA                  = 50;
input int    ATRPeriod                = 14;
input double ATRBuffer                = 0.30;
input double MinSL_ATR                = 0.50;
input double MaxSL_ATR                = 1.50;
input double MinMomentumBodyATR       = 0.50;
input double MaxPullbackDistanceATR   = 0.50;
input bool   UseBreakEven             = true;
input double BreakEvenTriggerR        = 1.0;
input double BreakEvenOffsetR         = 0.05;
input bool   UseTrailingStop          = true;
input double TrailingStartR           = 1.30;
input double TrailingATRMultiplier    = 1.0;
input int    MinTradeDurationMin      = 2;
input bool   UseVolatilityFilter      = true;
input double VolatilityATRMultiplier  = 1.8;
input string DailyResetTimezone       = "New York";
input int    DailyResetHour           = 17;
input double EvaluationInitialBalance = 5000.0;
input long   MagicNumber              = 250017;
input int    MaxSlippagePoints        = 20;

int trendFastHandle = INVALID_HANDLE;
int trendSlowHandle = INVALID_HANDLE;
int entryFastHandle = INVALID_HANDLE;
int atrHandle       = INVALID_HANDLE;


string tradeSymbol;
string statePrefix;
string blockReason = "READY";
int symbolDigits = 0;
double symbolPoint = 0.0;
double tickSize = 0.0;
double tickValue = 0.0;
double minVolume = 0.0;
double maxVolume = 0.0;
double volumeStep = 0.0;

double dailyReference = 0.0;
int tradingDayKey = 0;
int tradesToday = 0;
int consecutiveLosses = 0;
bool tradingAllowed = true;
ulong managedTicket = 0;
ulong lastProcessedPositionId = 0;
datetime lastEntryBar = 0;

double trendFastBuffer[];
double trendSlowBuffer[];
double entryFastBuffer[];
double atrBufferData[];

int FirstSunday(int year, int month)
{
   MqlDateTime value;
   ZeroMemory(value);
   value.year = year;
   value.mon = month;
   value.day = 1;
   datetime firstDay = StructToTime(value);
   TimeToStruct(firstDay, value);
   return 1 + ((7 - value.day_of_week) % 7);
}

bool IsNewYorkDST(datetime gmtTime)
{
   MqlDateTime value;
   TimeToStruct(gmtTime, value);
   int marchSunday = FirstSunday(value.year, 3) + 7;
   int novemberSunday = FirstSunday(value.year, 11);
   if(value.mon > 3 && value.mon < 11) return true;
   if(value.mon < 3 || value.mon > 11) return false;
   if(value.mon == 3)
   {
      if(value.day > marchSunday) return true;
      if(value.day < marchSunday) return false;
      return value.hour >= 7;
   }

   if(value.day < novemberSunday) return true;
   if(value.day > novemberSunday) return false;
   return value.hour < 6;
}

datetime NewYorkTime(datetime gmtTime)
{
   int offsetHours = -5;
   if(IsNewYorkDST(gmtTime)) offsetHours = -4;
   return gmtTime + offsetHours * 3600;
}

int CurrentTradingDayKey()
{
   datetime nyTime = NewYorkTime(TimeGMT());
   MqlDateTime value;
   TimeToStruct(nyTime, value);
   if(value.hour < DailyResetHour)
   {
      nyTime -= 86400;
      TimeToStruct(nyTime, value);
   }
   return value.year * 10000 + value.mon * 100 + value.day;
}

void SaveDailyState()
{
   GlobalVariableSet(statePrefix + "_KEY", (double)tradingDayKey);
   GlobalVariableSet(statePrefix + "_REF", dailyReference);
   GlobalVariableSet(statePrefix + "_TRADES", (double)tradesToday);
   GlobalVariableSet(statePrefix + "_LOSSES", (double)consecutiveLosses);
}

void ResetDailyState(int newKey)
{
   tradingDayKey = newKey;
   dailyReference = MathMax(AccountInfoDouble(ACCOUNT_BALANCE),
                            AccountInfoDouble(ACCOUNT_EQUITY));
   tradesToday = 0;
   consecutiveLosses = 0;
   SaveDailyState();
   Print("New York daily reset completed. Reference=", dailyReference);
}

void LoadDailyState()
{
   int keyNow = CurrentTradingDayKey();
   bool saved = GlobalVariableCheck(statePrefix + "_KEY");
   if(saved && (int)GlobalVariableGet(statePrefix + "_KEY") == keyNow &&
      GlobalVariableCheck(statePrefix + "_REF"))
   {
      tradingDayKey = keyNow;
      dailyReference = GlobalVariableGet(statePrefix + "_REF");

      tradesToday = (int)GlobalVariableGet(statePrefix + "_TRADES");
      consecutiveLosses = (int)GlobalVariableGet(statePrefix + "_LOSSES");
      return;
   }
   ResetDailyState(keyNow);
}

void CheckDailyReset()
{
   int keyNow = CurrentTradingDayKey();
   if(keyNow != tradingDayKey) ResetDailyState(keyNow);
}

bool InputsAreValid()
{
   if(RiskPercent <= 0.0 || MaxLot <= 0.0 || RiskRewardRatio <= 0.0) return false;
   if(MaxTradesPerDay < 1 || MaxOpenTrades < 1 || MaxConsecutiveLosses < 1) return false;
   if(FastEMA < 1 || SlowEMA <= FastEMA || ATRPeriod < 2) return false;
   if(MinSL_ATR <= 0.0 || MaxSL_ATR < MinSL_ATR || ATRBuffer < 0.0) return false;
   if(DailyResetHour < 0 || DailyResetHour > 23) return false;
   if(EvaluationInitialBalance <= 0.0 || MaxMarginUsage <= 0.0) return false;
   return true;
}

int OnInit()
{
   if(!InputsAreValid())
   {
      Print("Invalid EA input values");
      return INIT_PARAMETERS_INCORRECT;
   }
   tradeSymbol = _Symbol;
   symbolDigits = (int)SymbolInfoInteger(tradeSymbol, SYMBOL_DIGITS);
   symbolPoint = SymbolInfoDouble(tradeSymbol, SYMBOL_POINT);
   tickSize = SymbolInfoDouble(tradeSymbol, SYMBOL_TRADE_TICK_SIZE);
   tickValue = SymbolInfoDouble(tradeSymbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   minVolume = SymbolInfoDouble(tradeSymbol, SYMBOL_VOLUME_MIN);
   maxVolume = SymbolInfoDouble(tradeSymbol, SYMBOL_VOLUME_MAX);
   volumeStep = SymbolInfoDouble(tradeSymbol, SYMBOL_VOLUME_STEP);
   if(symbolPoint <= 0.0 || tickSize <= 0.0 || minVolume <= 0.0 || volumeStep <= 0.0)
      return INIT_FAILED;

   trendFastHandle = iMA(tradeSymbol, TrendTimeframe, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   trendSlowHandle = iMA(tradeSymbol, TrendTimeframe, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   entryFastHandle = iMA(tradeSymbol, PERIOD_M5, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(tradeSymbol, PERIOD_M5, ATRPeriod);

   if(trendFastHandle == INVALID_HANDLE || trendSlowHandle == INVALID_HANDLE ||
      entryFastHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Indicator handle creation failed");
      return INIT_FAILED;
   }
   ArraySetAsSeries(trendFastBuffer, true);
   ArraySetAsSeries(trendSlowBuffer, true);
   ArraySetAsSeries(entryFastBuffer, true);
   ArraySetAsSeries(atrBufferData, true);

   statePrefix = StringFormat("GFT_%I64d_%I64d_%s",
                              AccountInfoInteger(ACCOUNT_LOGIN), MagicNumber, tradeSymbol);
   LoadDailyState();
   managedTicket = FindManagedPosition();
   EventSetTimer(30);
   Print("GFT EA initialized. Timezone=", DailyResetTimezone,
         " ResetHour=", DailyResetHour, " Symbol=", tradeSymbol);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(trendFastHandle != INVALID_HANDLE) IndicatorRelease(trendFastHandle);
   if(trendSlowHandle != INVALID_HANDLE) IndicatorRelease(trendSlowHandle);
   if(entryFastHandle != INVALID_HANDLE) IndicatorRelease(entryFastHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   SaveDailyState();
   Comment("");
}

void OnTick()
{
   CheckDailyReset();
   managedTicket = FindManagedPosition();
   UpdateRiskLimits();
   if(managedTicket > 0)
      ManageOpenTrade();
   else if(tradingAllowed)
      CheckForNewTrade();
}

void OnTimer()
{
   CheckDailyReset();
   UpdateRiskLimits();
   UpdateStatusComment();
}

int CountOpenPositions()
{
   return PositionsTotal();
}


ulong FindManagedPosition()
{
   for(int index = PositionsTotal() - 1; index >= 0; index--)
   {
      ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == tradeSymbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return ticket;
   }
   return 0;
}

void UpdateRiskLimits()
{
   tradingAllowed = false;
   blockReason = "READY";
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(dailyReference <= 0.0 || EvaluationInitialBalance <= 0.0)
   {
      blockReason = "INVALID REFERENCE";
      return;
   }
   double dailyPercent = (equity - dailyReference) * 100.0 / dailyReference;
   double overallPercent = (equity - EvaluationInitialBalance) * 100.0 /
                           EvaluationInitialBalance;
   if(dailyPercent <= -DailyLossLimit)
   {
      blockReason = "DAILY LOSS STOP";
      return;
   }
   if(dailyPercent >= DailyProfitTarget)
   {
      blockReason = "DAILY PROFIT STOP";
      return;
   }
   if(overallPercent <= -MaxOverallLoss)
   {
      blockReason = "OVERALL LOSS STOP";
      return;
   }
   if(tradesToday >= MaxTradesPerDay)
   {
      blockReason = "MAX DAILY TRADES";
      return;
   }
   if(consecutiveLosses >= MaxConsecutiveLosses)
   {
      blockReason = "CONSECUTIVE LOSS STOP";
      return;
   }
   if(CountOpenPositions() >= MaxOpenTrades)
   {
      blockReason = "MAX OPEN TRADES";
      return;
   }
   tradingAllowed = true;
}


void UpdateStatusComment()
{
   string state = "BLOCKED";
   if(tradingAllowed) state = "READY";
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL = equity - dailyReference;
   Comment("GFT EA | ", state,
           " | Reason ", blockReason,
           " | Trades ", tradesToday,
           " | Losses ", consecutiveLosses,
           " | Daily P/L ", DoubleToString(dailyPL, 2),
           " | NY Day ", tradingDayKey);
}

bool LoadSignalData()
{
   if(BarsCalculated(trendFastHandle) < SlowEMA + 5) return false;
   if(BarsCalculated(trendSlowHandle) < SlowEMA + 5) return false;
   if(BarsCalculated(entryFastHandle) < FastEMA + 5) return false;
   if(BarsCalculated(atrHandle) < ATRPeriod + 20) return false;
   if(CopyBuffer(trendFastHandle, 0, 0, 3, trendFastBuffer) != 3) return false;
   if(CopyBuffer(trendSlowHandle, 0, 0, 3, trendSlowBuffer) != 3) return false;
   if(CopyBuffer(entryFastHandle, 0, 0, 3, entryFastBuffer) != 3) return false;
   if(CopyBuffer(atrHandle, 0, 0, 20, atrBufferData) != 20) return false;
   return true;
}

bool VolatilityIsSafe(double currentATR)
{
   if(!UseVolatilityFilter) return true;
   double averageATR = 0.0;
   for(int index = 2; index <= 15; index++)
      averageATR += atrBufferData[index];
   averageATR /= 14.0;
   if(averageATR <= 0.0) return false;
   return currentATR <= averageATR * VolatilityATRMultiplier;
}

bool MomentumSignal(bool buySignal, double currentATR)
{
   double openPrice[];
   double closePrice[];
   ArraySetAsSeries(openPrice, true);
   ArraySetAsSeries(closePrice, true);
   if(CopyOpen(tradeSymbol, PERIOD_M5, 1, 2, openPrice) != 2) return false;
   if(CopyClose(tradeSymbol, PERIOD_M5, 1, 2, closePrice) != 2) return false;
   double body = MathAbs(closePrice[0] - openPrice[0]);
   if(body < currentATR * MinMomentumBodyATR) return false;

   if(buySignal)
   {
      if(closePrice[0] <= openPrice[0] || closePrice[1] <= openPrice[1]) return false;
      if(closePrice[0] < entryFastBuffer[1]) return false;
   }
   else
   {
      if(closePrice[0] >= openPrice[0] || closePrice[1] >= openPrice[1]) return false;
      if(closePrice[0] > entryFastBuffer[1]) return false;
   }
   double pullbackDistance = MathAbs(closePrice[0] - entryFastBuffer[1]);
   if(pullbackDistance > currentATR * MaxPullbackDistanceATR) return false;
   return true;
}

void CheckForNewTrade()
{
   datetime currentBar = iTime(tradeSymbol, PERIOD_M5, 0);
   if(currentBar <= 0 || currentBar == lastEntryBar) return;
   lastEntryBar = currentBar;

   long spreadPoints = SymbolInfoInteger(tradeSymbol, SYMBOL_SPREAD);
   if(spreadPoints > MaxSpreadPoints) return;
   if(!LoadSignalData()) return;
   double currentATR = atrBufferData[1];
   if(currentATR <= 0.0 || !VolatilityIsSafe(currentATR)) return;

   bool buyTrend = true;
   bool sellTrend = true;
   if(UseTrendFilter)
   {
      buyTrend = trendFastBuffer[1] > trendSlowBuffer[1];
      sellTrend = trendFastBuffer[1] < trendSlowBuffer[1];
   }
   if(buyTrend && MomentumSignal(true, currentATR))
   {
      OpenTrade(ORDER_TYPE_BUY, currentATR);
      return;
   }
   if(sellTrend && MomentumSignal(false, currentATR))
      OpenTrade(ORDER_TYPE_SELL, currentATR);
}

double NormalizeStopPrice(double price, bool roundDown)
{
   if(tickSize <= 0.0) return NormalizeDouble(price, symbolDigits);
   double steps;
   if(roundDown)
      steps = MathFloor(price / tickSize + 0.0000001);
   else
      steps = MathCeil(price / tickSize - 0.0000001);
   return NormalizeDouble(steps * tickSize, symbolDigits);
}


double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice,
                         double currentATR)
{
   double highs[];
   double lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   if(CopyHigh(tradeSymbol, PERIOD_M5, 1, 5, highs) != 5) return 0.0;
   if(CopyLow(tradeSymbol, PERIOD_M5, 1, 5, lows) != 5) return 0.0;

   double stopPrice = 0.0;
   if(orderType == ORDER_TYPE_BUY)
   {
      int lowIndex = ArrayMinimum(lows, 0, 5);
      stopPrice = lows[lowIndex] - currentATR * ATRBuffer;
   }
   else
   {
      int highIndex = ArrayMaximum(highs, 0, 5);
      stopPrice = highs[highIndex] + currentATR * ATRBuffer;
   }

   double brokerDistance = (double)SymbolInfoInteger(tradeSymbol,
                                                     SYMBOL_TRADE_STOPS_LEVEL) * symbolPoint;
   double minimumDistance = MathMax(currentATR * MinSL_ATR,
                                    brokerDistance + tickSize);
   double maximumDistance = currentATR * MaxSL_ATR;
   double distance = MathAbs(entryPrice - stopPrice);
   if(distance < minimumDistance)
   {
      if(orderType == ORDER_TYPE_BUY)
         stopPrice = entryPrice - minimumDistance;
      else
         stopPrice = entryPrice + minimumDistance;
      distance = minimumDistance;
   }
   if(distance > maximumDistance || maximumDistance < minimumDistance) return 0.0;
   if(orderType == ORDER_TYPE_BUY)
      return NormalizeStopPrice(stopPrice, true);
   return NormalizeStopPrice(stopPrice, false);
}

int VolumeDigits()
{
   int digits = 0;
   while(digits < 8 && NormalizeDouble(volumeStep, digits) != volumeStep)
      digits++;
   return digits;
}

double CalculateVolume(ENUM_ORDER_TYPE orderType, double entryPrice,
                       double stopPrice)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
   double oneLotResult = 0.0;

   if(!OrderCalcProfit(orderType, tradeSymbol, 1.0, entryPrice,
                       stopPrice, oneLotResult))
   {
      double distance = MathAbs(entryPrice - stopPrice);
      if(tickSize <= 0.0 || tickValue <= 0.0) return 0.0;
      oneLotResult = -(distance / tickSize) * tickValue;
   }
   double lossPerLot = MathAbs(oneLotResult);
   if(lossPerLot <= 0.0 || riskMoney <= 0.0) return 0.0;

   double rawVolume = riskMoney / lossPerLot;
   double allowedMaximum = MathMin(MaxLot, maxVolume);
   double volume = MathFloor((rawVolume + 0.000000001) / volumeStep) * volumeStep;
   volume = MathMin(volume, allowedMaximum);
   volume = NormalizeDouble(volume, VolumeDigits());
   if(volume < minVolume) return 0.0;

   double requiredMargin = 0.0;
   if(!OrderCalcMargin(orderType, tradeSymbol, volume, entryPrice,
                       requiredMargin)) return 0.0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   if(equity <= 0.0) return 0.0;
   double projectedUsage = (usedMargin + requiredMargin) * 100.0 / equity;
   if(projectedUsage > MaxMarginUsage) return 0.0;
   return volume;
}

ENUM_ORDER_TYPE_FILLING FillingMode()
{
   long filling = SymbolInfoInteger(tradeSymbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
}

void OpenTrade(ENUM_ORDER_TYPE orderType, double currentATR)
{
   if(CountOpenPositions() >= MaxOpenTrades) return;
   double entryPrice = SymbolInfoDouble(tradeSymbol, SYMBOL_ASK);
   if(orderType == ORDER_TYPE_SELL)
      entryPrice = SymbolInfoDouble(tradeSymbol, SYMBOL_BID);
   double stopPrice = CalculateStopLoss(orderType, entryPrice, currentATR);
   if(stopPrice <= 0.0) return;
   double volume = CalculateVolume(orderType, entryPrice, stopPrice);
   if(volume <= 0.0) return;

   double riskDistance = MathAbs(entryPrice - stopPrice);
   double takeProfit;
   if(orderType == ORDER_TYPE_BUY)
      takeProfit = entryPrice + riskDistance * RiskRewardRatio;
   else
      takeProfit = entryPrice - riskDistance * RiskRewardRatio;
   takeProfit = NormalizeDouble(takeProfit, symbolDigits);

   MqlTradeRequest request;
   MqlTradeResult result;
   MqlTradeCheckResult check;
   ZeroMemory(request);
   ZeroMemory(result);
   ZeroMemory(check);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = tradeSymbol;
   request.magic = MagicNumber;
   request.volume = volume;
   request.type = orderType;
   request.price = entryPrice;
   request.sl = stopPrice;
   request.tp = takeProfit;
   request.deviation = MaxSlippagePoints;
   request.type_filling = FillingMode();
   request.type_time = ORDER_TIME_GTC;
   request.comment = "GFT_2Step_5K";

   if(!OrderCheck(request, check))
   {
      Print("OrderCheck failed. Error=", GetLastError(), " Comment=", check.comment);
      return;
   }
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed. Error=", GetLastError());
      return;
   }
   if(result.retcode != TRADE_RETCODE_DONE &&
      result.retcode != TRADE_RETCODE_PLACED &&
      result.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      Print("Trade rejected. Retcode=", result.retcode, " Comment=", result.comment);
      return;
   }
   managedTicket = FindManagedPosition();
   Print("Trade accepted. Volume=", volume, " SL=", stopPrice, " TP=", takeProfit);
}

bool StopIsValid(ENUM_POSITION_TYPE positionType, double stopPrice)
{
   double minimumDistance = (double)MathMax(
      SymbolInfoInteger(tradeSymbol, SYMBOL_TRADE_STOPS_LEVEL),
      SymbolInfoInteger(tradeSymbol, SYMBOL_TRADE_FREEZE_LEVEL)) * symbolPoint;

   double bid = SymbolInfoDouble(tradeSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(tradeSymbol, SYMBOL_ASK);
   if(positionType == POSITION_TYPE_BUY)
      return stopPrice < bid - minimumDistance;
   return stopPrice > ask + minimumDistance;
}

bool ModifyPositionStop(ulong ticket, double newStop, double takeProfit)
{
   if(!PositionSelectByTicket(ticket)) return false;
   ENUM_POSITION_TYPE positionType =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(!StopIsValid(positionType, newStop)) return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_SLTP;
   request.symbol = tradeSymbol;
   request.position = ticket;
   request.magic = MagicNumber;
   request.sl = newStop;
   request.tp = takeProfit;
   if(!OrderSend(request, result))
   {
      Print("Stop modification failed. Error=", GetLastError());
      return false;
   }
   if(result.retcode != TRADE_RETCODE_DONE)
   {
      Print("Stop modification rejected. Retcode=", result.retcode);
      return false;
   }
   return true;
}

void ManageOpenTrade()
{
   if(!PositionSelectByTicket(managedTicket)) return;
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   if(TimeCurrent() - openTime < MinTradeDurationMin * 60) return;

   ENUM_POSITION_TYPE positionType =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentStop = PositionGetDouble(POSITION_SL);
   double takeProfit = PositionGetDouble(POSITION_TP);
   double marketPrice = SymbolInfoDouble(tradeSymbol, SYMBOL_BID);
   if(positionType == POSITION_TYPE_SELL)
      marketPrice = SymbolInfoDouble(tradeSymbol, SYMBOL_ASK);


   double initialRisk = 0.0;
   if(RiskRewardRatio > 0.0 && takeProfit > 0.0)
      initialRisk = MathAbs(takeProfit - openPrice) / RiskRewardRatio;
   if(initialRisk <= 0.0) initialRisk = MathAbs(openPrice - currentStop);
   if(initialRisk <= 0.0) return;

   double profitDistance;
   if(positionType == POSITION_TYPE_BUY)
      profitDistance = marketPrice - openPrice;
   else
      profitDistance = openPrice - marketPrice;
   double currentR = profitDistance / initialRisk;

   if(UseBreakEven && currentR >= BreakEvenTriggerR)
   {
      double breakEvenStop;
      if(positionType == POSITION_TYPE_BUY)
         breakEvenStop = openPrice + initialRisk * BreakEvenOffsetR;
      else
         breakEvenStop = openPrice - initialRisk * BreakEvenOffsetR;
      breakEvenStop = NormalizeStopPrice(
         breakEvenStop, positionType == POSITION_TYPE_BUY);
      bool improvesStop = false;
      if(positionType == POSITION_TYPE_BUY && breakEvenStop > currentStop)
         improvesStop = true;
      if(positionType == POSITION_TYPE_SELL &&
         (currentStop == 0.0 || breakEvenStop < currentStop))
         improvesStop = true;
      if(improvesStop && ModifyPositionStop(managedTicket, breakEvenStop, takeProfit))
         currentStop = breakEvenStop;
   }

   if(!UseTrailingStop || currentR < TrailingStartR) return;
   if(CopyBuffer(atrHandle, 0, 0, 3, atrBufferData) != 3) return;
   double trailDistance = atrBufferData[1] * TrailingATRMultiplier;
   if(trailDistance <= 0.0) return;
   double trailingStop;
   if(positionType == POSITION_TYPE_BUY)
      trailingStop = NormalizeStopPrice(marketPrice - trailDistance, true);
   else
      trailingStop = NormalizeStopPrice(marketPrice + trailDistance, false);
   bool improvesTrail = false;
   if(positionType == POSITION_TYPE_BUY && trailingStop > currentStop)
      improvesTrail = true;
   if(positionType == POSITION_TYPE_SELL &&
      (currentStop == 0.0 || trailingStop < currentStop))
      improvesTrail = true;
   if(improvesTrail)
      ModifyPositionStop(managedTicket, trailingStop, takeProfit);
}

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(transaction.type != TRADE_TRANSACTION_DEAL_ADD || transaction.deal == 0)
      return;
   if(!HistoryDealSelect(transaction.deal)) return;
   if(HistoryDealGetString(transaction.deal, DEAL_SYMBOL) != tradeSymbol) return;
   if(HistoryDealGetInteger(transaction.deal, DEAL_MAGIC) != MagicNumber) return;

   ENUM_DEAL_ENTRY entryType =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(transaction.deal, DEAL_ENTRY);
   if(entryType == DEAL_ENTRY_IN)
   {
      CheckDailyReset();
      tradesToday++;
      SaveDailyState();
      return;
   }
   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY) return;

   ulong positionId =
      (ulong)HistoryDealGetInteger(transaction.deal, DEAL_POSITION_ID);
   if(positionId == 0 || positionId == lastProcessedPositionId) return;
   lastProcessedPositionId = positionId;
   double netResult = 0.0;
   if(HistorySelectByPosition(positionId))
   {
      int dealCount = HistoryDealsTotal();
      for(int index = 0; index < dealCount; index++)
      {
         ulong deal = HistoryDealGetTicket(index);
         if(deal == 0) continue;
         netResult += HistoryDealGetDouble(deal, DEAL_PROFIT);
         netResult += HistoryDealGetDouble(deal, DEAL_SWAP);
         netResult += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      }
   }
   if(netResult < 0.0)
      consecutiveLosses++;
   else if(netResult > 0.0)
      consecutiveLosses = 0;
   managedTicket = FindManagedPosition();
   SaveDailyState();
}
//+------------------------------------------------------------------+

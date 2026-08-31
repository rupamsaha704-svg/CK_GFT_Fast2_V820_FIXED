//+------------------------------------------------------------------+
//|             CK_XAU_DonchianTrend_H2_V1_FIXED.mq5                 |
//| XAUUSD H2 Donchian + EMA + ATR Trend Research EA                 |
//|                                                                  |
//| Entry: Completed-bar Donchian breakout                           |
//| Trend: EMA 10 / EMA 30 + fast EMA slope                          |
//| Initial stop: ATR(14) * 1.50                                     |
//| Exit: ATR(14) * 5.00 trailing stop                               |
//| TP: None                                                         |
//| Hard maximum lot: 0.06                                           |
//| One account exposure at a time                                   |
//+------------------------------------------------------------------+
#property copyright "CK XAUUSD research build"
#property version   "1.10"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//====================================================================
// ACCOUNT AND FIRM RULES
//====================================================================
input long   InpMagic                       = 2026072801;
input double InpInitialAccountBalance       = 5000.0;

input double InpFirmDailyDDPct              = 5.0;
input double InpFirmStaticMaxLossPct        = 10.0;
input double InpSafetyBufferPctPoints       = 0.20;

input bool   InpStopAtProfitTarget          = false;
input double InpProfitTargetUSD             = 5000.0;

input bool   InpBlockAnyAccountExposure     = true;
input int    InpMaxTradesPerDay             = 0;

//====================================================================
// STRATEGY SETTINGS
//====================================================================
input ENUM_TIMEFRAMES InpRequiredTimeframe  = PERIOD_H2;
input bool   InpEnforceTimeframe            = true;

input int    InpDonchianLookback            = 40;

input int    InpEMAFast                     = 10;
input int    InpEMASlow                     = 30;
input int    InpFastEMASlopeBars            = 3;

input int    InpATRPeriod                   = 14;
input double InpInitialStopATR              = 1.50;
input double InpTrailingStopATR             = 5.00;

input double InpRiskPercent                 = 2.25;
input double InpMaxLot                      = 0.06;

input bool   InpAllowBuy                    = true;
input bool   InpAllowSell                   = true;

//====================================================================
// EXECUTION SETTINGS
//====================================================================
input double InpCommissionPerSidePerLot     = 3.50;
input int    InpMaxSpreadPoints             = 0;
input int    InpDeviationPoints             = 30;
input double InpMaxMarginUsePct             = 30.0;

input bool   InpClosePositionOnRiskBreach   = true;

//====================================================================
// GLOBAL STATE
//====================================================================
int g_atrHandle      = INVALID_HANDLE;
int g_fastEMAHandle  = INVALID_HANDLE;
int g_slowEMAHandle  = INVALID_HANDLE;

datetime g_lastBarTime = 0;

int    g_dayKey          = 0;
double g_dayStartBalance = 0.0;
double g_dayAnchorEquity = 0.0;
int    g_tradesToday     = 0;

bool g_dayLocked    = false;
bool g_targetLocked = false;

double g_positionExtreme = 0.0;
ulong  g_positionTicket  = 0;

//====================================================================
// BASIC PRICE HELPERS
//====================================================================
double GetTickSize()
{
   double tickSize =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize <= 0.0)
      tickSize = _Point;

   return tickSize;
}

//+------------------------------------------------------------------+
double NormalizePriceDown(const double price)
{
   double tickSize = GetTickSize();

   int digits =
      (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double normalized =
      MathFloor((price + 1e-12) / tickSize) * tickSize;

   return NormalizeDouble(normalized, digits);
}

//+------------------------------------------------------------------+
double NormalizePriceUp(const double price)
{
   double tickSize = GetTickSize();

   int digits =
      (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double normalized =
      MathCeil((price - 1e-12) / tickSize) * tickSize;

   return NormalizeDouble(normalized, digits);
}

//+------------------------------------------------------------------+
int VolumeDigits(const double step)
{
   if(step < 0.001)
      return 4;

   if(step < 0.01)
      return 3;

   return 2;
}

//+------------------------------------------------------------------+
double NormalizeVolumeDown(const double requestedVolume)
{
   double minimumVolume =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double maximumBrokerVolume =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double volumeStep =
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(volumeStep <= 0.0)
      volumeStep = 0.01;

   double maximumAllowed =
      MathMin(InpMaxLot, maximumBrokerVolume);

   double cappedVolume =
      MathMin(requestedVolume, maximumAllowed);

   double normalized =
      MathFloor((cappedVolume + 1e-12) / volumeStep)
      * volumeStep;

   /*
      Minimum lot force করা হবে না।
      Calculated volume minimum-এর নিচে হলে trade skip হবে।
   */
   if(normalized < minimumVolume - 1e-12)
      return 0.0;

   return NormalizeDouble(
      normalized,
      VolumeDigits(volumeStep)
   );
}

//====================================================================
// SPREAD, STOPS AND MARGIN
//====================================================================
bool IsSpreadAllowed()
{
   if(InpMaxSpreadPoints <= 0)
      return true;

   MqlTick currentTick;

   if(!SymbolInfoTick(_Symbol, currentTick))
      return false;

   double spreadPoints =
      (currentTick.ask - currentTick.bid) / _Point;

   return spreadPoints <= InpMaxSpreadPoints;
}

//+------------------------------------------------------------------+
bool IsStopDistanceValid(
   const int direction,
   const double entryPrice,
   const double stopLoss
)
{
   int stopsLevel =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      );

   int freezeLevel =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_FREEZE_LEVEL
      );

   double minimumDistance =
      ((double)MathMax(stopsLevel, freezeLevel) + 2.0)
      * _Point;

   if(direction > 0)
      return stopLoss < entryPrice - minimumDistance;

   return stopLoss > entryPrice + minimumDistance;
}

//+------------------------------------------------------------------+
bool IsMarginAllowed(
   const int direction,
   const double volume,
   const double entryPrice
)
{
   ENUM_ORDER_TYPE orderType =
      direction > 0
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

   double requiredMargin = 0.0;

   if(
      !OrderCalcMargin(
         orderType,
         _Symbol,
         volume,
         entryPrice,
         requiredMargin
      )
   )
   {
      return false;
   }

   double equity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity <= 0.0)
      return false;

   double marginUsePercent =
      requiredMargin / equity * 100.0;

   return marginUsePercent <= InpMaxMarginUsePct;
}

//====================================================================
// NEW YORK TIME AND DAILY ROLLOVER
//====================================================================
int FirstSunday(
   const int year,
   const int month
)
{
   MqlDateTime dateData;
   ZeroMemory(dateData);

   dateData.year = year;
   dateData.mon  = month;
   dateData.day  = 1;

   datetime dateTime =
      StructToTime(dateData);

   TimeToStruct(dateTime, dateData);

   return 1 + ((7 - dateData.day_of_week) % 7);
}

//+------------------------------------------------------------------+
bool IsUnitedStatesDST(const datetime utcTime)
{
   MqlDateTime current;
   TimeToStruct(utcTime, current);

   int secondSundayMarch =
      FirstSunday(current.year, 3) + 7;

   int firstSundayNovember =
      FirstSunday(current.year, 11);

   MqlDateTime startData;
   MqlDateTime endData;

   ZeroMemory(startData);
   ZeroMemory(endData);

   startData.year = current.year;
   startData.mon  = 3;
   startData.day  = secondSundayMarch;
   startData.hour = 7;

   endData.year = current.year;
   endData.mon  = 11;
   endData.day  = firstSundayNovember;
   endData.hour = 6;

   datetime startUTC =
      StructToTime(startData);

   datetime endUTC =
      StructToTime(endData);

   return utcTime >= startUTC && utcTime < endUTC;
}

//+------------------------------------------------------------------+
int EasternOffsetHours(const datetime utcTime)
{
   if(IsUnitedStatesDST(utcTime))
      return -4;

   return -5;
}

//+------------------------------------------------------------------+
datetime EasternPseudoTime(const datetime utcTime)
{
   return utcTime + EasternOffsetHours(utcTime) * 3600;
}

//+------------------------------------------------------------------+
// Fixed version: datetime parameter, no MqlDateTime object parameter.
// This avoids "objects are passed by reference only" compile error.
//+------------------------------------------------------------------+
datetime EasternLocalTimestampToUTC(
   const datetime easternLocalTimestamp
)
{
   datetime candidateEDT =
      easternLocalTimestamp + 4 * 3600;

   if(
      EasternPseudoTime(candidateEDT)
      == easternLocalTimestamp
   )
   {
      return candidateEDT;
   }

   return easternLocalTimestamp + 5 * 3600;
}

//+------------------------------------------------------------------+
datetime CurrentRolloverUTC()
{
   datetime currentUTC =
      TimeGMT();

   datetime easternPseudo =
      EasternPseudoTime(currentUTC);

   MqlDateTime easternDate;
   TimeToStruct(easternPseudo, easternDate);

   if(easternDate.hour < 17)
   {
      easternPseudo -= 86400;
      TimeToStruct(easternPseudo, easternDate);
   }

   easternDate.hour = 17;
   easternDate.min  = 0;
   easternDate.sec  = 0;

   datetime easternRolloverTimestamp =
      StructToTime(easternDate);

   return EasternLocalTimestampToUTC(
      easternRolloverTimestamp
   );
}

//+------------------------------------------------------------------+
int CurrentTradingDayKey()
{
   datetime shiftedTime =
      EasternPseudoTime(TimeGMT()) - 17 * 3600;

   MqlDateTime dateData;
   TimeToStruct(shiftedTime, dateData);

   return
      dateData.year * 10000
      + dateData.mon * 100
      + dateData.day;
}

//+------------------------------------------------------------------+
int ServerOffsetSeconds()
{
   return (int)(TimeCurrent() - TimeGMT());
}

//====================================================================
// PERSISTENT DAILY STATE
//====================================================================
string DailyStatePrefix()
{
   return StringFormat(
      "CKDTH2.%I64d.%I64d.%s.%d",
      AccountInfoInteger(ACCOUNT_LOGIN),
      InpMagic,
      _Symbol,
      g_dayKey
   );
}

//+------------------------------------------------------------------+
double DealNetValue(const ulong dealTicket)
{
   return
      HistoryDealGetDouble(
         dealTicket,
         DEAL_PROFIT
      )
      +
      HistoryDealGetDouble(
         dealTicket,
         DEAL_SWAP
      )
      +
      HistoryDealGetDouble(
         dealTicket,
         DEAL_COMMISSION
      )
      +
      HistoryDealGetDouble(
         dealTicket,
         DEAL_FEE
      );
}

//+------------------------------------------------------------------+
void SaveDailyState()
{
   string prefix =
      DailyStatePrefix();

   GlobalVariableSet(
      prefix + ".Balance",
      g_dayStartBalance
   );

   GlobalVariableSet(
      prefix + ".Equity",
      g_dayAnchorEquity
   );

   GlobalVariableSet(
      prefix + ".Trades",
      (double)g_tradesToday
   );

   GlobalVariableSet(
      prefix + ".Locked",
      g_dayLocked ? 1.0 : 0.0
   );
}

//+------------------------------------------------------------------+
void RebuildDailyState()
{
   datetime historyStart =
      CurrentRolloverUTC()
      + ServerOffsetSeconds();

   datetime historyEnd =
      TimeCurrent();

   double realisedResult = 0.0;
   int entryDeals = 0;

   if(HistorySelect(historyStart, historyEnd))
   {
      int totalDeals =
         HistoryDealsTotal();

      for(int index = 0; index < totalDeals; index++)
      {
         ulong dealTicket =
            HistoryDealGetTicket(index);

         if(dealTicket == 0)
            continue;

         realisedResult +=
            DealNetValue(dealTicket);

         long dealMagic =
            HistoryDealGetInteger(
               dealTicket,
               DEAL_MAGIC
            );

         string dealSymbol =
            HistoryDealGetString(
               dealTicket,
               DEAL_SYMBOL
            );

         long dealEntry =
            HistoryDealGetInteger(
               dealTicket,
               DEAL_ENTRY
            );

         if(
            dealMagic == InpMagic
            &&
            dealSymbol == _Symbol
            &&
            (
               dealEntry == DEAL_ENTRY_IN
               ||
               dealEntry == DEAL_ENTRY_INOUT
            )
         )
         {
            entryDeals++;
         }
      }
   }

   double currentBalance =
      AccountInfoDouble(ACCOUNT_BALANCE);

   double currentEquity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   g_dayStartBalance =
      currentBalance - realisedResult;

   if(g_dayStartBalance <= 0.0)
      g_dayStartBalance = currentBalance;

   g_dayAnchorEquity =
      MathMax(
         g_dayStartBalance,
         MathMax(
            currentBalance,
            currentEquity
         )
      );

   g_tradesToday = entryDeals;
   g_dayLocked = false;

   SaveDailyState();
}

//+------------------------------------------------------------------+
void LoadOrRebuildDailyState()
{
   g_dayKey =
      CurrentTradingDayKey();

   /*
      Strategy Tester-এ পুরোনো terminal global state
      ব্যবহার করা হবে না।
   */
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      RebuildDailyState();
      return;
   }

   string prefix =
      DailyStatePrefix();

   bool stateExists =
      GlobalVariableCheck(prefix + ".Balance")
      &&
      GlobalVariableCheck(prefix + ".Equity")
      &&
      GlobalVariableCheck(prefix + ".Trades")
      &&
      GlobalVariableCheck(prefix + ".Locked");

   if(!stateExists)
   {
      RebuildDailyState();
      return;
   }

   g_dayStartBalance =
      GlobalVariableGet(prefix + ".Balance");

   g_dayAnchorEquity =
      GlobalVariableGet(prefix + ".Equity");

   g_tradesToday =
      (int)GlobalVariableGet(prefix + ".Trades");

   g_dayLocked =
      GlobalVariableGet(prefix + ".Locked") > 0.5;
}

//+------------------------------------------------------------------+
void ResetDailyState()
{
   g_dayKey =
      CurrentTradingDayKey();

   double currentBalance =
      AccountInfoDouble(ACCOUNT_BALANCE);

   double currentEquity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   g_dayStartBalance =
      currentBalance;

   g_dayAnchorEquity =
      MathMax(currentBalance, currentEquity);

   g_tradesToday = 0;
   g_dayLocked = false;

   SaveDailyState();
}

//====================================================================
// DRAWDOWN FLOORS
//====================================================================
double EffectiveDailyLossPercent()
{
   return MathMax(
      0.10,
      InpFirmDailyDDPct
      - InpSafetyBufferPctPoints
   );
}

//+------------------------------------------------------------------+
double EffectiveStaticLossPercent()
{
   return MathMax(
      0.10,
      InpFirmStaticMaxLossPct
      - InpSafetyBufferPctPoints
   );
}

//+------------------------------------------------------------------+
double DailyEquityFloor()
{
   return
      g_dayAnchorEquity
      *
      (
         1.0
         - EffectiveDailyLossPercent() / 100.0
      );
}

//+------------------------------------------------------------------+
double StaticEquityFloor()
{
   return
      InpInitialAccountBalance
      *
      (
         1.0
         - EffectiveStaticLossPercent() / 100.0
      );
}

//====================================================================
// POSITION HELPERS
//====================================================================
ulong FindMyPositionTicket()
{
   for(
      int index = PositionsTotal() - 1;
      index >= 0;
      index--
   )
   {
      ulong ticket =
         PositionGetTicket(index);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string positionSymbol =
         PositionGetString(POSITION_SYMBOL);

      long positionMagic =
         PositionGetInteger(POSITION_MAGIC);

      if(
         positionSymbol == _Symbol
         &&
         positionMagic == InpMagic
      )
      {
         return ticket;
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
bool HasMyPosition()
{
   return FindMyPositionTicket() > 0;
}

//+------------------------------------------------------------------+
bool HasBlockedAccountExposure()
{
   if(InpBlockAnyAccountExposure)
   {
      return
         PositionsTotal() > 0
         ||
         OrdersTotal() > 0;
   }

   return HasMyPosition();
}

//+------------------------------------------------------------------+
void ClearPositionExtreme()
{
   g_positionExtreme = 0.0;
   g_positionTicket  = 0;
}

//+------------------------------------------------------------------+
bool CloseMyPosition()
{
   ulong ticket =
      FindMyPositionTicket();

   if(ticket == 0)
      return true;

   if(!trade.PositionClose(ticket))
   {
      Print(
         "Position close failed. Retcode=",
         trade.ResultRetcode(),
         " ",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   long retcode =
      trade.ResultRetcode();

   bool result =
      retcode == TRADE_RETCODE_DONE
      ||
      retcode == TRADE_RETCODE_DONE_PARTIAL;

   if(result)
      ClearPositionExtreme();

   return result;
}

//====================================================================
// ACCOUNT PROTECTION
//====================================================================
bool ProtectAccount()
{
   int currentDayKey =
      CurrentTradingDayKey();

   if(currentDayKey != g_dayKey)
      ResetDailyState();

   double currentBalance =
      AccountInfoDouble(ACCOUNT_BALANCE);

   double currentEquity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   if(
      InpStopAtProfitTarget
      &&
      currentBalance >=
      InpInitialAccountBalance
      + InpProfitTargetUSD
   )
   {
      g_targetLocked = true;

      if(InpClosePositionOnRiskBreach)
         CloseMyPosition();

      return false;
   }

   bool dailyBreach =
      currentEquity <= DailyEquityFloor();

   bool staticBreach =
      currentEquity <= StaticEquityFloor();

   if(dailyBreach || staticBreach)
   {
      g_dayLocked = true;
      SaveDailyState();

      if(InpClosePositionOnRiskBreach)
         CloseMyPosition();

      Print(
         "Risk guard activated. Equity=",
         DoubleToString(currentEquity, 2),
         " DailyFloor=",
         DoubleToString(DailyEquityFloor(), 2),
         " StaticFloor=",
         DoubleToString(StaticEquityFloor(), 2)
      );

      return false;
   }

   if(g_dayLocked || g_targetLocked)
      return false;

   if(
      InpMaxTradesPerDay > 0
      &&
      g_tradesToday >= InpMaxTradesPerDay
   )
   {
      return false;
   }

   return true;
}

//====================================================================
// INDICATOR HELPERS
//====================================================================
double ReadIndicatorValue(
   const int indicatorHandle,
   const int shift
)
{
   double values[];
   ArraySetAsSeries(values, true);

   int copied =
      CopyBuffer(
         indicatorHandle,
         0,
         shift,
         1,
         values
      );

   if(copied != 1)
      return EMPTY_VALUE;

   return values[0];
}

//+------------------------------------------------------------------+
double ATRValue(const int shift)
{
   return ReadIndicatorValue(
      g_atrHandle,
      shift
   );
}

//+------------------------------------------------------------------+
double FastEMAValue(const int shift)
{
   return ReadIndicatorValue(
      g_fastEMAHandle,
      shift
   );
}

//+------------------------------------------------------------------+
double SlowEMAValue(const int shift)
{
   return ReadIndicatorValue(
      g_slowEMAHandle,
      shift
   );
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime =
      iTime(
         _Symbol,
         InpRequiredTimeframe,
         0
      );

   if(currentBarTime <= 0)
      return false;

   if(currentBarTime == g_lastBarTime)
      return false;

   g_lastBarTime =
      currentBarTime;

   return true;
}

//====================================================================
// SIGNAL
//====================================================================
int GetSignalDirection()
{
   int requiredBars =
      (int)MathMax(
         InpEMASlow
         + InpFastEMASlopeBars
         + 5,
         InpDonchianLookback + 5
      );

   if(
      Bars(
         _Symbol,
         InpRequiredTimeframe
      ) < requiredBars
   )
   {
      return 0;
   }

   /*
      Bar 1 = completed signal candle.
      Donchian channel = bars 2 to lookback+1.
      Signal candle channel calculation-এর মধ্যে নেই।
   */
   int highestShift =
      iHighest(
         _Symbol,
         InpRequiredTimeframe,
         MODE_HIGH,
         InpDonchianLookback,
         2
      );

   int lowestShift =
      iLowest(
         _Symbol,
         InpRequiredTimeframe,
         MODE_LOW,
         InpDonchianLookback,
         2
      );

   if(highestShift < 0 || lowestShift < 0)
      return 0;

   double signalClose =
      iClose(
         _Symbol,
         InpRequiredTimeframe,
         1
      );

   double channelHigh =
      iHigh(
         _Symbol,
         InpRequiredTimeframe,
         highestShift
      );

   double channelLow =
      iLow(
         _Symbol,
         InpRequiredTimeframe,
         lowestShift
      );

   double fastEMA =
      FastEMAValue(1);

   double slowEMA =
      SlowEMAValue(1);

   double oldFastEMA =
      FastEMAValue(
         1 + InpFastEMASlopeBars
      );

   if(
      signalClose <= 0.0
      ||
      fastEMA == EMPTY_VALUE
      ||
      slowEMA == EMPTY_VALUE
      ||
      oldFastEMA == EMPTY_VALUE
   )
   {
      return 0;
   }

   bool buySignal =
      InpAllowBuy
      &&
      signalClose > channelHigh
      &&
      fastEMA > slowEMA
      &&
      fastEMA > oldFastEMA;

   bool sellSignal =
      InpAllowSell
      &&
      signalClose < channelLow
      &&
      fastEMA < slowEMA
      &&
      fastEMA < oldFastEMA;

   if(buySignal && !sellSignal)
      return 1;

   if(sellSignal && !buySignal)
      return -1;

   return 0;
}

//====================================================================
// RISK CALCULATION
//====================================================================
double RemainingRiskBudget()
{
   double equity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   double strongestFloor =
      MathMax(
         DailyEquityFloor(),
         StaticEquityFloor()
      );

   return MathMax(
      0.0,
      equity - strongestFloor
   );
}

//+------------------------------------------------------------------+
double CalculateRiskVolume(
   const int direction,
   const double entryPrice,
   const double stopLoss
)
{
   double currentBalance =
      AccountInfoDouble(ACCOUNT_BALANCE);

   double requestedRiskMoney =
      currentBalance
      * InpRiskPercent
      / 100.0;

   double availableBudget =
      RemainingRiskBudget();

   double riskMoney =
      MathMin(
         requestedRiskMoney,
         availableBudget
      );

   if(riskMoney <= 0.0)
      return 0.0;

   ENUM_ORDER_TYPE orderType =
      direction > 0
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

   double oneLotPnL = 0.0;

   if(
      !OrderCalcProfit(
         orderType,
         _Symbol,
         1.0,
         entryPrice,
         stopLoss,
         oneLotPnL
      )
   )
   {
      return 0.0;
   }

   double commissionEstimate =
      2.0
      * MathMax(
         0.0,
         InpCommissionPerSidePerLot
      );

   double lossPerLot =
      MathAbs(oneLotPnL)
      + commissionEstimate;

   if(lossPerLot <= 0.0)
      return 0.0;

   double rawVolume =
      riskMoney / lossPerLot;

   return NormalizeVolumeDown(rawVolume);
}

//====================================================================
// TRAILING STOP
//====================================================================
void RebuildPositionExtreme(
   const ulong ticket
)
{
   if(
      ticket == 0
      ||
      !PositionSelectByTicket(ticket)
   )
   {
      ClearPositionExtreme();
      return;
   }

   double openPrice =
      PositionGetDouble(POSITION_PRICE_OPEN);

   datetime openTime =
      (datetime)PositionGetInteger(POSITION_TIME);

   long positionType =
      PositionGetInteger(POSITION_TYPE);

   g_positionExtreme =
      openPrice;

   int openBarShift =
      iBarShift(
         _Symbol,
         InpRequiredTimeframe,
         openTime,
         false
      );

   if(openBarShift > 0)
   {
      if(positionType == POSITION_TYPE_BUY)
      {
         int highestShift =
            iHighest(
               _Symbol,
               InpRequiredTimeframe,
               MODE_HIGH,
               openBarShift,
               1
            );

         if(highestShift >= 0)
         {
            g_positionExtreme =
               MathMax(
                  g_positionExtreme,
                  iHigh(
                     _Symbol,
                     InpRequiredTimeframe,
                     highestShift
                  )
               );
         }
      }
      else if(positionType == POSITION_TYPE_SELL)
      {
         int lowestShift =
            iLowest(
               _Symbol,
               InpRequiredTimeframe,
               MODE_LOW,
               openBarShift,
               1
            );

         if(lowestShift >= 0)
         {
            g_positionExtreme =
               MathMin(
                  g_positionExtreme,
                  iLow(
                     _Symbol,
                     InpRequiredTimeframe,
                     lowestShift
                  )
               );
         }
      }
   }

   g_positionTicket =
      ticket;
}

//+------------------------------------------------------------------+
bool ModifyPositionStop(
   const ulong ticket,
   const double newStopLoss
)
{
   if(
      !trade.PositionModify(
         ticket,
         newStopLoss,
         0.0
      )
   )
   {
      Print(
         "PositionModify failed. Retcode=",
         trade.ResultRetcode(),
         " ",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   long retcode =
      trade.ResultRetcode();

   return
      retcode == TRADE_RETCODE_DONE
      ||
      retcode == TRADE_RETCODE_NO_CHANGES;
}

//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   ulong ticket =
      FindMyPositionTicket();

   if(
      ticket == 0
      ||
      !PositionSelectByTicket(ticket)
   )
   {
      ClearPositionExtreme();
      return;
   }

   if(
      g_positionTicket != ticket
      ||
      g_positionExtreme <= 0.0
   )
   {
      RebuildPositionExtreme(ticket);
   }

   double atr =
      ATRValue(1);

   if(atr == EMPTY_VALUE || atr <= 0.0)
      return;

   long positionType =
      PositionGetInteger(POSITION_TYPE);

   double currentStopLoss =
      PositionGetDouble(POSITION_SL);

   MqlTick currentTick;

   if(!SymbolInfoTick(_Symbol, currentTick))
      return;

   int stopsLevel =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      );

   int freezeLevel =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_FREEZE_LEVEL
      );

   double minimumDistance =
      ((double)MathMax(stopsLevel, freezeLevel) + 2.0)
      * _Point;

   double tickSize =
      GetTickSize();

   if(positionType == POSITION_TYPE_BUY)
   {
      double completedHigh =
         iHigh(
            _Symbol,
            InpRequiredTimeframe,
            1
         );

      g_positionExtreme =
         MathMax(
            g_positionExtreme,
            completedHigh
         );

      double candidateStop =
         NormalizePriceDown(
            g_positionExtreme
            - InpTrailingStopATR * atr
         );

      bool stopImproved =
         candidateStop
         > currentStopLoss + tickSize * 0.5;

      bool stopValid =
         candidateStop
         < currentTick.bid - minimumDistance;

      if(stopImproved && stopValid)
      {
         ModifyPositionStop(
            ticket,
            candidateStop
         );
      }
   }
   else if(positionType == POSITION_TYPE_SELL)
   {
      double completedLow =
         iLow(
            _Symbol,
            InpRequiredTimeframe,
            1
         );

      g_positionExtreme =
         MathMin(
            g_positionExtreme,
            completedLow
         );

      double candidateStop =
         NormalizePriceUp(
            g_positionExtreme
            + InpTrailingStopATR * atr
         );

      bool stopImproved =
         currentStopLoss == 0.0
         ||
         candidateStop
         < currentStopLoss - tickSize * 0.5;

      bool stopValid =
         candidateStop
         > currentTick.ask + minimumDistance;

      if(stopImproved && stopValid)
      {
         ModifyPositionStop(
            ticket,
            candidateStop
         );
      }
   }
}

//====================================================================
// ORDER OPENING
//====================================================================
bool IsSuccessfulTradeRetcode()
{
   long retcode =
      trade.ResultRetcode();

   return
      retcode == TRADE_RETCODE_DONE
      ||
      retcode == TRADE_RETCODE_DONE_PARTIAL
      ||
      retcode == TRADE_RETCODE_PLACED;
}

//+------------------------------------------------------------------+
bool OpenSignalTrade(const int direction)
{
   if(direction == 0)
      return false;

   if(!IsSpreadAllowed())
      return false;

   if(HasBlockedAccountExposure())
      return false;

   MqlTick currentTick;

   if(!SymbolInfoTick(_Symbol, currentTick))
      return false;

   double atr =
      ATRValue(1);

   if(atr == EMPTY_VALUE || atr <= 0.0)
      return false;

   double expectedEntry =
      direction > 0
      ? currentTick.ask
      : currentTick.bid;

   double rawStopLoss =
      direction > 0
      ? expectedEntry - InpInitialStopATR * atr
      : expectedEntry + InpInitialStopATR * atr;

   double initialStopLoss =
      direction > 0
      ? NormalizePriceDown(rawStopLoss)
      : NormalizePriceUp(rawStopLoss);

   if(
      !IsStopDistanceValid(
         direction,
         expectedEntry,
         initialStopLoss
      )
   )
   {
      Print(
         "Trade skipped: invalid initial stop distance."
      );

      return false;
   }

   double volume =
      CalculateRiskVolume(
         direction,
         expectedEntry,
         initialStopLoss
      );

   if(volume <= 0.0)
   {
      Print(
         "Trade skipped: calculated lot is below minimum or risk budget is unavailable."
      );

      return false;
   }

   if(volume > InpMaxLot + 1e-9)
   {
      Print(
         "Trade skipped: hard maximum lot protection."
      );

      return false;
   }

   if(
      !IsMarginAllowed(
         direction,
         volume,
         expectedEntry
      )
   )
   {
      Print(
         "Trade skipped: margin-use protection."
      );

      return false;
   }

   bool orderSent = false;

   if(direction > 0)
   {
      orderSent =
         trade.Buy(
            volume,
            _Symbol,
            0.0,
            initialStopLoss,
            0.0,
            "CK_DONCHIAN_H2_BUY"
         );
   }
   else
   {
      orderSent =
         trade.Sell(
            volume,
            _Symbol,
            0.0,
            initialStopLoss,
            0.0,
            "CK_DONCHIAN_H2_SELL"
         );
   }

   if(
      !orderSent
      ||
      !IsSuccessfulTradeRetcode()
   )
   {
      Print(
         "Order failed. Retcode=",
         trade.ResultRetcode(),
         " ",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   ulong ticket =
      FindMyPositionTicket();

   if(
      ticket == 0
      ||
      !PositionSelectByTicket(ticket)
   )
   {
      Print(
         "Order succeeded but position could not be selected."
      );

      return false;
   }

   double actualOpenPrice =
      PositionGetDouble(POSITION_PRICE_OPEN);

   /*
      Actual fill থেকে initial ATR stop পুনরায় তৈরি করা হয়।
   */
   double actualRawStop =
      direction > 0
      ? actualOpenPrice - InpInitialStopATR * atr
      : actualOpenPrice + InpInitialStopATR * atr;

   double actualStopLoss =
      direction > 0
      ? NormalizePriceDown(actualRawStop)
      : NormalizePriceUp(actualRawStop);

   bool repairedStopValid =
      IsStopDistanceValid(
         direction,
         actualOpenPrice,
         actualStopLoss
      );

   if(
      !repairedStopValid
      ||
      !ModifyPositionStop(
         ticket,
         actualStopLoss
      )
   )
   {
      Print(
         "Actual-fill stop repair failed. Position will be closed."
      );

      CloseMyPosition();

      return false;
   }

   g_positionExtreme =
      actualOpenPrice;

   g_positionTicket =
      ticket;

   g_tradesToday++;

   SaveDailyState();

   return true;
}

//====================================================================
// INITIALISATION
//====================================================================
int OnInit()
{
   bool invalidParameters =
      InpInitialAccountBalance <= 0.0
      ||
      InpFirmDailyDDPct <= 0.0
      ||
      InpFirmStaticMaxLossPct <= 0.0
      ||
      InpRiskPercent <= 0.0
      ||
      InpRiskPercent > 5.0
      ||
      InpMaxLot <= 0.0
      ||
      InpMaxLot > 0.06
      ||
      InpDonchianLookback < 2
      ||
      InpEMAFast < 2
      ||
      InpEMASlow <= InpEMAFast
      ||
      InpFastEMASlopeBars < 1
      ||
      InpATRPeriod < 2
      ||
      InpInitialStopATR <= 0.0
      ||
      InpTrailingStopATR <= 0.0;

   if(invalidParameters)
   {
      Print(
         "Invalid parameters. Maximum lot must be 0.06 or lower."
      );

      return INIT_PARAMETERS_INCORRECT;
   }

   bool invalidSafetyBuffer =
      InpSafetyBufferPctPoints < 0.0
      ||
      InpSafetyBufferPctPoints >= InpFirmDailyDDPct
      ||
      InpSafetyBufferPctPoints >= InpFirmStaticMaxLossPct;

   if(invalidSafetyBuffer)
   {
      Print("Invalid safety-buffer setting.");

      return INIT_PARAMETERS_INCORRECT;
   }

   if(
      InpEnforceTimeframe
      &&
      _Period != InpRequiredTimeframe
   )
   {
      Print(
         "Attach EA to ",
         EnumToString(InpRequiredTimeframe),
         " timeframe."
      );

      return INIT_PARAMETERS_INCORRECT;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_atrHandle =
      iATR(
         _Symbol,
         InpRequiredTimeframe,
         InpATRPeriod
      );

   g_fastEMAHandle =
      iMA(
         _Symbol,
         InpRequiredTimeframe,
         InpEMAFast,
         0,
         MODE_EMA,
         PRICE_CLOSE
      );

   g_slowEMAHandle =
      iMA(
         _Symbol,
         InpRequiredTimeframe,
         InpEMASlow,
         0,
         MODE_EMA,
         PRICE_CLOSE
      );

   if(
      g_atrHandle == INVALID_HANDLE
      ||
      g_fastEMAHandle == INVALID_HANDLE
      ||
      g_slowEMAHandle == INVALID_HANDLE
   )
   {
      Print(
         "Indicator handle creation failed."
      );

      return INIT_FAILED;
   }

   g_lastBarTime =
      iTime(
         _Symbol,
         InpRequiredTimeframe,
         0
      );

   LoadOrRebuildDailyState();

   ulong existingTicket =
      FindMyPositionTicket();

   if(existingTicket > 0)
      RebuildPositionExtreme(existingTicket);

   if(
      InpStopAtProfitTarget
      &&
      AccountInfoDouble(ACCOUNT_BALANCE)
      >=
      InpInitialAccountBalance
      + InpProfitTargetUSD
   )
   {
      g_targetLocked = true;
   }

   Print(
      "CK Donchian H2 FIXED initialized. ",
      "Daily floor=",
      DoubleToString(DailyEquityFloor(), 2),
      " Static floor=",
      DoubleToString(StaticEquityFloor(), 2),
      " Max lot=",
      DoubleToString(InpMaxLot, 2)
   );

   return INIT_SUCCEEDED;
}

//====================================================================
// DEINITIALISATION
//====================================================================
void OnDeinit(const int reason)
{
   SaveDailyState();

   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   if(g_fastEMAHandle != INVALID_HANDLE)
      IndicatorRelease(g_fastEMAHandle);

   if(g_slowEMAHandle != INVALID_HANDLE)
      IndicatorRelease(g_slowEMAHandle);
}

//====================================================================
// MAIN TICK
//====================================================================
void OnTick()
{
   if(!ProtectAccount())
      return;

   if(!IsNewBar())
      return;

   /*
      Trailing stop completed H2 candle-এর পরে update হয়।
   */
   ManageTrailingStop();

   if(!ProtectAccount())
      return;

   if(HasBlockedAccountExposure())
      return;

   int signalDirection =
      GetSignalDirection();

   if(signalDirection != 0)
      OpenSignalTrade(signalDirection);
}

//====================================================================
// TRADE TRANSACTION
//====================================================================
void OnTradeTransaction(
   const MqlTradeTransaction &transaction,
   const MqlTradeRequest &request,
   const MqlTradeResult &result
)
{
   if(
      transaction.type
      != TRADE_TRANSACTION_DEAL_ADD
   )
   {
      return;
   }

   if(transaction.deal == 0)
      return;

   if(!HistoryDealSelect(transaction.deal))
      return;

   string dealSymbol =
      HistoryDealGetString(
         transaction.deal,
         DEAL_SYMBOL
      );

   long dealMagic =
      HistoryDealGetInteger(
         transaction.deal,
         DEAL_MAGIC
      );

   long dealEntry =
      HistoryDealGetInteger(
         transaction.deal,
         DEAL_ENTRY
      );

   if(
      dealSymbol == _Symbol
      &&
      dealMagic == InpMagic
      &&
      (
         dealEntry == DEAL_ENTRY_OUT
         ||
         dealEntry == DEAL_ENTRY_OUT_BY
      )
   )
   {
      if(!HasMyPosition())
         ClearPositionExtreme();
   }
}
//+------------------------------------------------------------------+

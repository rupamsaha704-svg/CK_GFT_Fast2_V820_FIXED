//+------------------------------------------------------------------+
//|                                              CK GFT Fast v8.12   |
//|                        Copyright - CK GFT Fast                   |
//|   Goat $1 Model - $10/day TP, 1.8% guard, 2min duration guard   |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.12"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputs
input long   InpMagic             = 20260715;
input double InpFixedLot          = 0.02;        // Fixed lot size
input double InpTPDollars         = 10.0;        // TP in dollars ($10 = 50 pips on 0.02)
input int    InpSLPips            = 50;          // Fixed SL in pips (backup)
input double InpSLDollars         = 10.0;        // SL in dollars (same as TP = $10)
input int    InpBEPips            = 30;          // Move SL to BE after this many pips profit
input bool   InpBreakEvenAt1R     = true;        // Enable break-even feature
input int    InpMaxTradesPerDay   = 3;
input double InpDailyProfitTarget = 10.0;        // Daily profit cap in $
input double InpFloatingLossMax   = 1.8;         // Max floating loss % (safety)
input int    InpMinTradeDuration  = 120;         // Min trade duration in seconds (2 min)
input int    InpMaxSpreadPoints   = 50;
input bool   InpUseTrend          = true;
input int    InpEMAPeriod         = 21;
input int    InpEMASlow           = 50;
input int    InpKneeMinRun        = 2;
input int    InpValidBars         = 5;
input double InpSLBufferATR       = 0.3;         // (legacy - not used with fixed SL)

//--- Handles & State
int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime    = 0;
datetime g_dayStart     = 0;
double   g_dayStartBal  = 0.0;
int      g_tradesToday  = 0;
int      g_dir          = 0;
double   g_trigger      = 0.0;
double   g_kneeLow      = 0.0;
double   g_kneeHigh     = 0.0;
double   g_pendingSL    = 0.0;
int      g_barsLeft     = 0;
bool     g_floatingBreached = false;
bool     g_lossToday    = false;   // True if SL hit with actual loss today

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   atrHandle     = iATR(_Symbol, _Period, 14);
   emaFastHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle == INVALID_HANDLE || emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)     IndicatorRelease(atrHandle);
   if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//+------------------------------------------------------------------+
//| Helper functions                                                  |
//+------------------------------------------------------------------+
double ATR()
{
   double b[];
   if(CopyBuffer(atrHandle, 0, 0, 1, b) <= 0) return(0);
   return(b[0]);
}

double EMAFast(int shift)
{
   double b[];
   if(CopyBuffer(emaFastHandle, 0, shift, 1, b) <= 0) return(0);
   return(b[0]);
}

double EMASlow(int shift)
{
   double b[];
   if(CopyBuffer(emaSlowHandle, 0, shift, 1, b) <= 0) return(0);
   return(b[0]);
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t != lastBarTime) { lastBarTime = t; return(true); }
   return(false);
}

bool IsGreen(int s) { return(iClose(_Symbol, _Period, s) > iOpen(_Symbol, _Period, s)); }
bool IsRed(int s)   { return(iClose(_Symbol, _Period, s) < iOpen(_Symbol, _Period, s)); }

//+------------------------------------------------------------------+
//| Daily Reset                                                       |
//+------------------------------------------------------------------+
void ResetDaily()
{
   g_dayStart     = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStartBal  = AccountInfoDouble(ACCOUNT_BALANCE);
   g_tradesToday  = 0;
   g_floatingBreached = false;
   g_lossToday    = false;
}

//+------------------------------------------------------------------+
//| Today's realized profit in $                                      |
//+------------------------------------------------------------------+
double RealizedProfitToday()
{
   return(AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal);
}

//+------------------------------------------------------------------+
//| Calculate TP price for exact $10 profit                           |
//+------------------------------------------------------------------+
double CalcTPPrice(double entryPrice)
{
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0) return(0);

   // $10 profit: how many ticks needed?
   // PnL = (ticks) * tick_value * lots
   // ticks = target$ / (tick_value * lots)
   double ticks = InpTPDollars / (tv * InpFixedLot);
   double tpDist = ticks * ts;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return(NormalizeDouble(entryPrice + tpDist, dg));
}

//+------------------------------------------------------------------+
//| Calculate fixed SL price ($10 loss below entry)                   |
//+------------------------------------------------------------------+
double CalcSLPrice(double entryPrice)
{
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0) return(0);

   // Same method as TP but going down
   // ticks = SL$ / (tick_value * lots)
   double ticks = InpSLDollars / (tv * InpFixedLot);
   double slDist = ticks * ts;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return(NormalizeDouble(entryPrice - slDist, dg));
}

//+------------------------------------------------------------------+
//| Floating PnL check - 1.8% guard                                  |
//+------------------------------------------------------------------+
double GetFloatingPnL()
{
   double floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      floating += PositionGetDouble(POSITION_PROFIT)
                + PositionGetDouble(POSITION_SWAP);
   }
   return(floating);
}

void CheckFloatingLossGuard()
{
   if(g_floatingBreached) return;

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return;

   double floating = GetFloatingPnL();
   double maxLoss  = -bal * (InpFloatingLossMax / 100.0);

   if(floating <= maxLoss)
   {
      CloseAllPositions();
      g_floatingBreached = true;
      Disarm();
      Print("FLOATING LOSS GUARD: ", DoubleToString(floating, 2),
            " hit limit ", DoubleToString(maxLoss, 2), " - ALL CLOSED");
   }
}

//+------------------------------------------------------------------+
//| Close all positions for this symbol/magic                         |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      trade.PositionClose(tk);
   }
}

//+------------------------------------------------------------------+
//| 2-Minute Duration Guard + $10 Profit Close                        |
//| - If profit >= $10 AND trade open > 2 min → close                |
//| - If TP hit by broker before 2 min, TP stays (broker closes it)  |
//|   but we also manage manually to be safe                         |
//+------------------------------------------------------------------+
void ManageProfitClose()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int elapsed = (int)(TimeCurrent() - openTime);

      // If profit >= $10 and trade has been open > 2 minutes → close
      if(profit >= InpTPDollars && elapsed >= InpMinTradeDuration)
      {
         trade.PositionClose(tk);
         Print("PROFIT TARGET HIT: $", DoubleToString(profit, 2),
               " after ", elapsed, " seconds - CLOSED");
      }
   }
}

//+------------------------------------------------------------------+
//| Disarm setup                                                      |
//+------------------------------------------------------------------+
void Disarm()
{
   g_dir = 0; g_trigger = 0; g_kneeLow = 0;
   g_kneeHigh = 0; g_barsLeft = 0; g_pendingSL = 0;
}

//+------------------------------------------------------------------+
//| Trend filter                                                      |
//+------------------------------------------------------------------+
bool IsTrendBuy()
{
   return(EMAFast(1) > EMASlow(1) && iClose(_Symbol, _Period, 1) > EMAFast(1));
}

//+------------------------------------------------------------------+
//| Try to arm a buy setup (knee pattern)                             |
//+------------------------------------------------------------------+
void TryArmSetup()
{
   double atr = ATR();
   if(atr <= 0) return;
   double buf = InpSLBufferATR * atr;

   if(IsRed(1))
   {
      int run = 0;
      for(int i = 2; i <= 12; i++)
      {
         if(IsGreen(i)) run++;
         else break;
      }
      bool trendOK = (!InpUseTrend) || IsTrendBuy();
      if(run >= InpKneeMinRun && trendOK)
      {
         g_dir       = +1;
         g_kneeHigh  = iHigh(_Symbol, _Period, 1);
         g_kneeLow   = iLow(_Symbol, _Period, 1);
         g_trigger   = g_kneeHigh;
         g_pendingSL = g_kneeLow - buf;
         g_barsLeft  = InpValidBars;
      }
   }
}

//+------------------------------------------------------------------+
//| Count my positions                                                |
//+------------------------------------------------------------------+
int MyPositions()
{
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         c++;
   }
   return(c);
}

//+------------------------------------------------------------------+
//| Open trade - Fixed 0.02 lot, TP = $10 (50 pips)                  |
//+------------------------------------------------------------------+
void OpenTrade(int dir)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Fixed SL: 50 pips below entry
   double sl = CalcSLPrice(ask);
   if(sl <= 0) return;
   
   // Fixed TP: $10 profit
   double tp = CalcTPPrice(ask);
   if(tp <= ask) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, dg);
   tp = NormalizeDouble(tp, dg);

   trade.Buy(InpFixedLot, _Symbol, 0, sl, tp);
   g_tradesToday++;

   Print("TRADE OPENED: Lot=", DoubleToString(InpFixedLot, 2),
         " Entry=", DoubleToString(ask, dg),
         " SL=", DoubleToString(sl, dg), " (", InpSLPips, " pips)",
         " TP=", DoubleToString(tp, dg),
         " (Target $", DoubleToString(InpTPDollars, 2), ")");
}

//+------------------------------------------------------------------+
//| Break-even management - Move SL to entry after 60% of TP profit  |
//| ($6 profit on $10 TP = same as 30 pips)                          |
//+------------------------------------------------------------------+
void ManageBE()
{
   if(!InpBreakEvenAt1R) return;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // Calculate BE trigger distance: 60% of TP distance (= $6 of $10)
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0) return;
   double beDollars = InpTPDollars * 0.6;  // $6 trigger (60% of $10)
   double beTicks = beDollars / (tv * InpFixedLot);
   double beDist = beTicks * ts;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double slc  = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double be   = NormalizeDouble(open, dg);
      
      // If price moved $6+ in profit AND SL is still below entry → move to BE
      if(bid >= open + beDist && slc < be)
      {
         trade.PositionModify(tk, be, tp);
         Print("BE MOVED: SL moved to entry at ", DoubleToString(be, dg),
               " (profit reached $", DoubleToString(beDollars, 2), ")");
      }
   }
}

//+------------------------------------------------------------------+
//| Trading allowed check                                             |
//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(g_floatingBreached) return(false);
   if(g_lossToday) return(false);            // Lost today → no more trades
   if(RealizedProfitToday() >= InpDailyProfitTarget) return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| Detect trade close - Loss = stop, BE = retry allowed              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Only care about deal additions (trade closed)
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   
   // Check if it's our deal
   ulong dealTicket = trans.deal;
   if(dealTicket == 0) return;
   
   if(HistoryDealSelect(dealTicket))
   {
      long magic = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      
      if(magic != InpMagic || symbol != _Symbol) return;
      if(entry != DEAL_ENTRY_OUT) return;  // Only exits
      
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                    + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                    + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      
      if(profit < -1.0)  // Actual loss (more than -$1 to avoid tiny rounding)
      {
         g_lossToday = true;
         Print("LOSS DETECTED: $", DoubleToString(profit, 2), " - NO MORE TRADES TODAY");
      }
      else if(profit >= -1.0 && profit < 1.0)  // Break-even (near zero)
      {
         Print("BREAK-EVEN: $", DoubleToString(profit, 2), " - RETRY ALLOWED");
         // g_lossToday stays false → can trade again
      }
      else if(profit >= InpTPDollars - 1.0)  // TP hit
      {
         Print("TP HIT: $", DoubleToString(profit, 2), " - DAILY TARGET DONE");
      }
   }
}

//+------------------------------------------------------------------+
//| Main tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Daily reset
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart) ResetDaily();

   // *** SAFETY FIRST - EVERY TICK ***
   CheckFloatingLossGuard();
   if(g_floatingBreached) return;

   // *** $10 PROFIT CLOSE + 2 MIN DURATION GUARD ***
   ManageProfitClose();

   // Break-even management
   ManageBE();

   // Daily target already reached? Stop.
   if(RealizedProfitToday() >= InpDailyProfitTarget) return;

   // New bar logic
   if(IsNewBar())
   {
      if(g_dir != 0)
      {
         g_barsLeft--;
         if(g_barsLeft <= 0) Disarm();
      }
      if(g_dir == 0 && MyPositions() == 0)
         TryArmSetup();
   }

   // Entry logic
   if(g_dir != 0 && MyPositions() == 0)
   {
      if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_dir > 0 && ask >= g_trigger)
      {
         OpenTrade(+1);
         Disarm();
      }
   }
}
//+------------------------------------------------------------------+

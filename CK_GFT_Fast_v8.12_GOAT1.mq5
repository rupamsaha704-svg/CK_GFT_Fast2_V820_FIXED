//+------------------------------------------------------------------+
//|                                    CK GFT Fast v8.14 FINAL       |
//|                        Copyright - CK GFT Fast                   |
//|   GOAT $1 Model - NO BROKER TP/SL - EA manages everything        |
//|   Profit/Loss tracked in DOLLARS not pips/points                  |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.14"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputs
input long   InpMagic             = 20260715;
input double InpFixedLot          = 0.02;        // Fixed lot size
input double InpTPDollars         = 10.0;        // Close when profit reaches $10
input double InpSLDollars         = 10.0;        // Close when loss reaches -$10
input double InpBEDollars         = 6.0;         // Move SL to entry after $6 profit
input int    InpMaxTradesPerDay   = 2;           // Max 2 trades/day (BE retry + 1)
input double InpDailyProfitTarget = 10.0;        // Stop trading after $10/day
input double InpFloatingLossMax   = 1.8;         // Emergency close at 1.8% floating loss
input int    InpMinTradeDuration  = 120;         // Min 2 minutes before closing for profit
input int    InpMaxSpreadPoints   = 50;
input bool   InpUseTrend          = true;
input int    InpEMAPeriod         = 21;
input int    InpEMASlow           = 50;
input int    InpKneeMinRun        = 2;
input int    InpValidBars         = 5;

//--- State
int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime    = 0;
datetime g_dayStart     = 0;
double   g_dayStartBal  = 0.0;
int      g_tradesToday  = 0;
int      g_dir          = 0;
double   g_trigger      = 0.0;
double   g_kneeHigh     = 0.0;
double   g_kneeLow      = 0.0;
int      g_barsLeft     = 0;
bool     g_floatingBreached = false;
bool     g_lossToday    = false;
bool     g_beApplied    = false;   // BE already applied to current trade
int      g_prevPosCount = 0;
double   g_prevBalance  = 0.0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   atrHandle     = iATR(_Symbol, _Period, 14);
   emaFastHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE || emaFastHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   g_prevPosCount = MyPositions();
   g_prevBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle!=INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle!=INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
double ATR()       { double b[]; if(CopyBuffer(atrHandle,0,0,1,b)<=0) return(0); return(b[0]); }
double EMAFast(int s) { double b[]; if(CopyBuffer(emaFastHandle,0,s,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int s) { double b[]; if(CopyBuffer(emaSlowHandle,0,s,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar() { datetime t=iTime(_Symbol,_Period,0); if(t!=lastBarTime){lastBarTime=t;return(true);} return(false); }
bool IsGreen(int s) { return(iClose(_Symbol,_Period,s)>iOpen(_Symbol,_Period,s)); }
bool IsRed(int s)   { return(iClose(_Symbol,_Period,s)<iOpen(_Symbol,_Period,s)); }

//+------------------------------------------------------------------+
//| Daily Reset                                                       |
//+------------------------------------------------------------------+
void ResetDaily()
{
   g_dayStart    = iTime(_Symbol,PERIOD_D1,0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_tradesToday = 0;
   g_floatingBreached = false;
   g_lossToday   = false;
}

double RealizedProfitToday() { return(AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal); }

//+------------------------------------------------------------------+
//| Count my positions                                                |
//+------------------------------------------------------------------+
int MyPositions()
{
   int c=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol) c++;
   }
   return(c);
}

//+------------------------------------------------------------------+
//| Get current floating profit of our position                       |
//+------------------------------------------------------------------+
double GetMyPositionProfit()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      return(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP));
   }
   return(0);
}

//+------------------------------------------------------------------+
//| Get position open time                                            |
//+------------------------------------------------------------------+
datetime GetMyPositionOpenTime()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      return((datetime)PositionGetInteger(POSITION_TIME));
   }
   return(0);
}

//+------------------------------------------------------------------+
//| MANAGE OPEN TRADE - This is the CORE logic                        |
//| - Close at +$10 profit (after 2 min)                              |
//| - Close at -$10 loss                                              |
//| - Move SL to entry at +$6 profit                                  |
//| ALL based on ACTUAL DOLLAR PROFIT (not price distance!)           |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   if(MyPositions() == 0) return;
   
   double profit = GetMyPositionProfit();
   datetime openTime = GetMyPositionOpenTime();
   int elapsed = (int)(TimeCurrent() - openTime);
   
   // === CLOSE AT -$10 LOSS (immediately, no waiting) ===
   if(profit <= -InpSLDollars)
   {
      CloseAllPositions();
      g_lossToday = true;
      Print("*** SL HIT: $", DoubleToString(profit,2), " - CLOSED + NO MORE TRADES TODAY ***");
      return;
   }
   
   // === CLOSE AT +$10 PROFIT (after 2 min) ===
   if(profit >= InpTPDollars && elapsed >= InpMinTradeDuration)
   {
      CloseAllPositions();
      Print("*** TP HIT: $", DoubleToString(profit,2), " after ", elapsed, "s - DAILY DONE ***");
      return;
   }
   
   // === BREAK-EVEN: Move SL to entry at +$6 ===
   if(profit >= InpBEDollars && !g_beApplied)
   {
      int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong tk=PositionGetTicket(i); if(tk==0) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double tp   = PositionGetDouble(POSITION_TP);
         double be   = NormalizeDouble(open, dg);
         trade.PositionModify(tk, be, tp);
         g_beApplied = true;
         Print("*** BE: SL moved to entry (profit=$", DoubleToString(profit,2), ") ***");
      }
   }
}

//+------------------------------------------------------------------+
//| Detect trade close (position count dropped)                       |
//+------------------------------------------------------------------+
void DetectTradeClose()
{
   int curPos = MyPositions();
   
   // Only check when position count CHANGES
   if(curPos != g_prevPosCount)
   {
      if(curPos < g_prevPosCount && g_prevPosCount > 0)
      {
         // Position closed - check balance change
         double curBal = AccountInfoDouble(ACCOUNT_BALANCE);
         double pnl = curBal - g_prevBalance;
         
         if(pnl < -1.0)
         {
            g_lossToday = true;
            Print("*** LOSS: $", DoubleToString(pnl,2), " - NO MORE TRADES TODAY ***");
         }
         else if(pnl < 1.0)
         {
            Print("*** BE: $", DoubleToString(pnl,2), " - RETRY OK ***");
         }
         else
         {
            Print("*** WIN: $", DoubleToString(pnl,2), " ***");
         }
         g_beApplied = false;
         g_prevBalance = curBal;  // Update balance ONLY after close
      }
      else if(curPos > g_prevPosCount)
      {
         // New position opened - save balance BEFORE trade
         g_prevBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      }
      g_prevPosCount = curPos;
   }
   // NOTE: g_prevBalance is NOT updated every tick anymore!
}

//+------------------------------------------------------------------+
//| Floating loss guard 1.8%                                          |
//+------------------------------------------------------------------+
void CheckFloatingGuard()
{
   if(g_floatingBreached) return;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return;
   double floating = GetMyPositionProfit();
   double maxLoss = -bal * (InpFloatingLossMax / 100.0);
   if(floating <= maxLoss)
   {
      CloseAllPositions();
      g_floatingBreached = true;
      g_lossToday = true;
      Disarm();
      Print("*** FLOATING GUARD: $", DoubleToString(floating,2), " ***");
   }
}

void CloseAllPositions()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      trade.PositionClose(tk);
   }
}

//+------------------------------------------------------------------+
void Disarm() { g_dir=0; g_trigger=0; g_kneeHigh=0; g_kneeLow=0; g_barsLeft=0; }
bool IsTrendBuy() { return(EMAFast(1)>EMASlow(1) && iClose(_Symbol,_Period,1)>EMAFast(1)); }

void TryArmSetup()
{
   if(IsRed(1))
   {
      int run=0;
      for(int i=2; i<=12; i++) { if(IsGreen(i)) run++; else break; }
      bool trendOK = (!InpUseTrend) || IsTrendBuy();
      if(run >= InpKneeMinRun && trendOK)
      {
         g_dir      = +1;
         g_kneeHigh = iHigh(_Symbol,_Period,1);
         g_kneeLow  = iLow(_Symbol,_Period,1);
         g_trigger  = g_kneeHigh;
         g_barsLeft = InpValidBars;
      }
   }
}

bool TradingAllowed()
{
   if(g_floatingBreached) return(false);
   if(g_lossToday) return(false);
   if(RealizedProfitToday() >= InpDailyProfitTarget) return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| Open trade - NO TP/SL on broker! EA manages manually              |
//+------------------------------------------------------------------+
void OpenTrade()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Emergency SL only - EA manages at -$10, this is just crash protection
   double emergencySL = NormalizeDouble(ask - 100.0, dg);
   
   trade.Buy(InpFixedLot, _Symbol, 0, emergencySL, 0);
   g_tradesToday++;
   g_beApplied = false;
   
   Print("*** OPENED: ", DoubleToString(ask,dg), " Lot=", InpFixedLot,
         " EmergSL=", DoubleToString(emergencySL,dg), " ***");
}

//+------------------------------------------------------------------+
//| MAIN TICK                                                         |
//+------------------------------------------------------------------+
void OnTick()
{
   // Daily reset
   if(iTime(_Symbol,PERIOD_D1,0) != g_dayStart) ResetDaily();

   // Detect closed trades
   DetectTradeClose();

   // If lost today - STOP EVERYTHING
   if(g_lossToday) return;

   // Floating guard
   CheckFloatingGuard();
   if(g_floatingBreached) return;

   // *** MANAGE OPEN TRADE: TP/SL/BE all by dollar profit ***
   ManageOpenTrade();

   // Daily target done?
   if(RealizedProfitToday() >= InpDailyProfitTarget) return;

   // New bar - arm setup
   if(IsNewBar())
   {
      if(g_dir != 0) { g_barsLeft--; if(g_barsLeft <= 0) Disarm(); }
      if(g_dir == 0 && MyPositions() == 0) TryArmSetup();
   }

   // Entry
   if(g_dir != 0 && MyPositions() == 0)
   {
      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(g_dir > 0 && ask >= g_trigger)
      {
         OpenTrade();
         Disarm();
      }
   }
}
//+------------------------------------------------------------------+

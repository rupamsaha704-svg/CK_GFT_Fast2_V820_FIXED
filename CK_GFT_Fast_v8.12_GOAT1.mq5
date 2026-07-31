//+------------------------------------------------------------------+
//|                                              CK GFT Fast v8.12   |
//|                        Copyright - CK GFT Fast                   |
//|   Goat $1 Model - FINAL FIX                                      |
//|   Broker: Tick Size=0.01, Tick Value=0.1, Contract=100           |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.12"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputs
input long   InpMagic             = 20260715;
input double InpFixedLot          = 0.02;        // Fixed lot size
input double InpTPDollars         = 10.0;        // TP target in dollars
input double InpSLDollars         = 10.0;        // SL calculated dollars (set same as TP)
input double InpBEDollars         = 6.0;         // Move SL to BE after this $ profit
input int    InpMaxTradesPerDay   = 3;
input double InpDailyProfitTarget = 10.0;        // Daily profit cap in $
input double InpFloatingLossMax   = 1.8;         // Max floating loss % (safety)
input int    InpMinTradeDuration  = 120;         // Min trade duration seconds (2 min)
input int    InpMaxSpreadPoints   = 50;
input bool   InpUseTrend          = true;
input int    InpEMAPeriod         = 21;
input int    InpEMASlow           = 50;
input int    InpKneeMinRun        = 2;
input int    InpValidBars         = 5;

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
int      g_barsLeft     = 0;
bool     g_floatingBreached = false;
bool     g_lossToday    = false;
int      g_lastPosCount = 0;   // Track position count to detect closes
double   g_lastBalance  = 0.0; // Track balance to detect loss/win

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
   g_lastPosCount = MyPositions();
   g_lastBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)     IndicatorRelease(atrHandle);
   if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
double ATR()       { double b[]; if(CopyBuffer(atrHandle,0,0,1,b)<=0) return(0); return(b[0]); }
double EMAFast(int s) { double b[]; if(CopyBuffer(emaFastHandle,0,s,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int s) { double b[]; if(CopyBuffer(emaSlowHandle,0,s,1,b)<=0) return(0); return(b[0]); }

bool IsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t != lastBarTime) { lastBarTime = t; return(true); }
   return(false);
}

bool IsGreen(int s) { return(iClose(_Symbol,_Period,s) > iOpen(_Symbol,_Period,s)); }
bool IsRed(int s)   { return(iClose(_Symbol,_Period,s) < iOpen(_Symbol,_Period,s)); }

//+------------------------------------------------------------------+
//| Dollar to price distance                                          |
//+------------------------------------------------------------------+
double DollarsToDistance(double dollars)
{
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0 || InpFixedLot <= 0) return(0);
   double dollarPerTick = tv * InpFixedLot;
   double ticksNeeded = dollars / dollarPerTick;
   double distance = ticksNeeded * ts;
   return(distance);
}

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

double RealizedProfitToday()
{
   return(AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal);
}

//+------------------------------------------------------------------+
//| Detect if a position just closed + determine if it was a loss     |
//| This replaces OnTradeTransaction (unreliable in Tester)           |
//+------------------------------------------------------------------+
void DetectTradeClose()
{
   int currentPos = MyPositions();
   double currentBal = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // A position just closed (count decreased)
   if(currentPos < g_lastPosCount && g_lastPosCount > 0)
   {
      double pnl = currentBal - g_lastBalance;
      
      if(pnl < -1.0)
      {
         // LOSS - stop trading today
         g_lossToday = true;
         Print("*** LOSS DETECTED: $", DoubleToString(pnl, 2), " - STOP TRADING TODAY ***");
      }
      else if(pnl >= -1.0 && pnl < 1.0)
      {
         // Break-even - retry allowed
         Print("*** BREAK-EVEN: $", DoubleToString(pnl, 2), " - RETRY ALLOWED ***");
      }
      else
      {
         // Win!
         Print("*** WIN: $", DoubleToString(pnl, 2), " ***");
      }
   }
   
   g_lastPosCount = currentPos;
   g_lastBalance = currentBal;
}

//+------------------------------------------------------------------+
//| Floating loss guard - 1.8%                                        |
//+------------------------------------------------------------------+
double GetFloatingPnL()
{
   double floating = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return(floating);
}

void CheckFloatingLossGuard()
{
   if(g_floatingBreached) return;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return;
   double floating = GetFloatingPnL();
   double maxLoss = -bal * (InpFloatingLossMax / 100.0);
   if(floating <= maxLoss)
   {
      CloseAllPositions();
      g_floatingBreached = true;
      g_lossToday = true;
      Disarm();
      Print("*** FLOATING GUARD: $", DoubleToString(floating,2), " - ALL CLOSED ***");
   }
}

void CloseAllPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      trade.PositionClose(tk);
   }
}

//+------------------------------------------------------------------+
//| Profit close + 2 min guard                                        |
//+------------------------------------------------------------------+
void ManageProfitClose()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int elapsed = (int)(TimeCurrent() - openTime);
      if(profit >= InpTPDollars && elapsed >= InpMinTradeDuration)
      {
         trade.PositionClose(tk);
         Print("*** TP CLOSE: $", DoubleToString(profit,2), " after ", elapsed, "s ***");
      }
   }
}

//+------------------------------------------------------------------+
//| Break-even at $6 profit (uses actual position profit)             |
//+------------------------------------------------------------------+
void ManageBE()
{
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double slc  = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double be   = NormalizeDouble(open, dg);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(profit >= InpBEDollars && slc < be)
      {
         trade.PositionModify(tk, be, tp);
         Print("*** BE: SL→entry at ", DoubleToString(be,dg), " (profit=$", DoubleToString(profit,2), ") ***");
      }
   }
}

//+------------------------------------------------------------------+
void Disarm() { g_dir=0; g_trigger=0; g_kneeLow=0; g_kneeHigh=0; g_barsLeft=0; }
bool IsTrendBuy() { return(EMAFast(1) > EMASlow(1) && iClose(_Symbol,_Period,1) > EMAFast(1)); }

//+------------------------------------------------------------------+
void TryArmSetup()
{
   if(IsRed(1))
   {
      int run = 0;
      for(int i = 2; i <= 12; i++) { if(IsGreen(i)) run++; else break; }
      bool trendOK = (!InpUseTrend) || IsTrendBuy();
      if(run >= InpKneeMinRun && trendOK)
      {
         g_dir      = +1;
         g_kneeHigh = iHigh(_Symbol, _Period, 1);
         g_kneeLow  = iLow(_Symbol, _Period, 1);
         g_trigger  = g_kneeHigh;
         g_barsLeft = InpValidBars;
      }
   }
}

//+------------------------------------------------------------------+
int MyPositions()
{
   int c = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol) c++;
   }
   return(c);
}

//+------------------------------------------------------------------+
//| Open trade - TP and SL both = $10 distance (same formula)         |
//+------------------------------------------------------------------+
void OpenTrade(int dir)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double dist = DollarsToDistance(InpTPDollars);  // Same distance for both TP and SL
   
   if(dist <= 0)
   {
      Print("ERROR: dist=0");
      return;
   }
   
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double tp = NormalizeDouble(ask + dist, dg);
   double sl = NormalizeDouble(ask - dist, dg);
   
   if(sl >= ask || tp <= ask) return;

   Print("*** OPEN: ", DoubleToString(ask,dg),
         " SL=", DoubleToString(sl,dg),
         " TP=", DoubleToString(tp,dg),
         " dist=", DoubleToString(dist,dg), " ***");

   trade.Buy(InpFixedLot, _Symbol, 0, sl, tp);
   g_tradesToday++;
}

//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(g_floatingBreached) return(false);
   if(g_lossToday) return(false);
   if(RealizedProfitToday() >= InpDailyProfitTarget) return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| MAIN TICK                                                         |
//+------------------------------------------------------------------+
void OnTick()
{
   // Daily reset
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart) ResetDaily();

   // Detect if trade closed (MUST be before anything else)
   DetectTradeClose();

   // Safety: floating loss guard
   CheckFloatingLossGuard();
   if(g_floatingBreached) return;

   // If lost today, do nothing
   if(g_lossToday) return;

   // Profit close + 2 min guard
   ManageProfitClose();

   // Break-even
   ManageBE();

   // Daily target reached?
   if(RealizedProfitToday() >= InpDailyProfitTarget) return;

   // New bar
   if(IsNewBar())
   {
      if(g_dir != 0) { g_barsLeft--; if(g_barsLeft <= 0) Disarm(); }
      if(g_dir == 0 && MyPositions() == 0) TryArmSetup();
   }

   // Entry
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

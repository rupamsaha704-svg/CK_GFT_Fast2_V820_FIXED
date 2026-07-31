//+------------------------------------------------------------------+
//|                                    CK GFT Fast v8.19 FINAL      |
//|   NO OVERNIGHT TRADES - Auto close before market close           |
//|   ONE TRADE PER DAY. Win=$10, Loss=$10. DONE.                    |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.19"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputs
input long   InpMagic             = 20260715;
input double InpFixedLot          = 0.02;
input double InpTPDollars         = 10.0;
input double InpSLDollars         = 10.0;
input double InpBEDollars         = 6.0;
input double InpFloatingLossMax   = 1.8;
input int    InpMinTradeDuration  = 120;
input int    InpMaxSpreadPoints   = 50;
input bool   InpUseTrend          = true;
input int    InpEMAPeriod         = 21;
input int    InpEMASlow           = 50;
input int    InpKneeMinRun        = 2;
input int    InpValidBars         = 5;

// TIME FILTERS - Broker server time
input int    InpTradeStartHour    = 8;           // Don't trade before this hour
input int    InpTradeStopHour     = 20;          // Don't OPEN new trades after this
input int    InpForceCloseHour    = 22;          // FORCE close all trades at this hour
input bool   InpNoFriday          = true;        // No trading on Friday

//--- State
enum ENUM_DAY_STATE
{
   STATE_LOOKING,
   STATE_ARMED,
   STATE_IN_TRADE,
   STATE_DONE_WIN,
   STATE_DONE_LOSS
};

int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime  = 0;
datetime g_dayStart   = 0;
ENUM_DAY_STATE g_state = STATE_LOOKING;
double   g_trigger    = 0.0;
int      g_barsLeft   = 0;
bool     g_beApplied  = false;

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
   g_dayStart = iTime(_Symbol, PERIOD_D1, 0);
   g_state = STATE_LOOKING;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle!=INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle!=INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//+------------------------------------------------------------------+
double EMAFast(int s) { double b[]; if(CopyBuffer(emaFastHandle,0,s,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int s) { double b[]; if(CopyBuffer(emaSlowHandle,0,s,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar() { datetime t=iTime(_Symbol,_Period,0); if(t!=lastBarTime){lastBarTime=t;return(true);} return(false); }
bool IsGreen(int s) { return(iClose(_Symbol,_Period,s)>iOpen(_Symbol,_Period,s)); }
bool IsRed(int s)   { return(iClose(_Symbol,_Period,s)<iOpen(_Symbol,_Period,s)); }
bool IsTrendBuy() { return(EMAFast(1)>EMASlow(1) && iClose(_Symbol,_Period,1)>EMAFast(1)); }

//+------------------------------------------------------------------+
//| Time helpers                                                      |
//+------------------------------------------------------------------+
int CurrentHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return(dt.hour);
}

int CurrentDayOfWeek()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return(dt.day_of_week);
}

bool IsGoodTimeToTrade()
{
   int hour = CurrentHour();
   int dow  = CurrentDayOfWeek();
   
   // No Sunday
   if(dow == 0) return(false);
   // No Friday if enabled
   if(InpNoFriday && dow == 5) return(false);
   // Only during trading window
   if(hour < InpTradeStartHour) return(false);
   if(hour >= InpTradeStopHour) return(false);
   return(true);
}

bool IsForceCloseTime()
{
   int hour = CurrentHour();
   return(hour >= InpForceCloseHour);
}

//+------------------------------------------------------------------+
//| Position helpers                                                  |
//+------------------------------------------------------------------+
double GetProfit()
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

int GetElapsed()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      return((int)(TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME)));
   }
   return(0);
}

bool HasPosition()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol)
         return(true);
   }
   return(false);
}

void ClosePosition()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      trade.PositionClose(tk);
   }
}

void MoveSLtoEntry()
{
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double be=NormalizeDouble(open,dg);
      trade.PositionModify(tk, be, 0);
   }
}

//+------------------------------------------------------------------+
//| MAIN TICK                                                         |
//+------------------------------------------------------------------+
void OnTick()
{
   // NEW DAY - reset state
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart)
   {
      g_dayStart = iTime(_Symbol, PERIOD_D1, 0);
      if(!HasPosition())
         g_state = STATE_LOOKING;
   }

   // FORCE CLOSE at 22:00 - NO OVERNIGHT TRADES!
   if(HasPosition() && IsForceCloseTime())
   {
      double p = GetProfit();
      ClosePosition();
      Print("*** FORCE CLOSE (end of day): $", DoubleToString(p,2), " ***");
      if(p < -1.0) g_state = STATE_DONE_LOSS;
      else if(p > 1.0) g_state = STATE_DONE_WIN;
      else g_state = STATE_DONE_LOSS;  // treat BE as done too
      return;
   }

   // If DONE - nothing else
   if(g_state == STATE_DONE_WIN || g_state == STATE_DONE_LOSS)
      return;

   // STATE_IN_TRADE - manage
   if(g_state == STATE_IN_TRADE)
   {
      if(!HasPosition())
      {
         // Broker closed it (SL/gap)
         g_state = STATE_DONE_LOSS;
         Print("*** POSITION GONE - DONE ***");
         return;
      }
      
      double profit = GetProfit();
      int elapsed = GetElapsed();
      
      // LOSS - close at -$10
      if(profit <= -InpSLDollars)
      {
         ClosePosition();
         g_state = STATE_DONE_LOSS;
         Print("*** SL: $", DoubleToString(profit,2), " - DONE ***");
         return;
      }
      
      // WIN - close at +$10 after 2 min
      if(profit >= InpTPDollars && elapsed >= InpMinTradeDuration)
      {
         ClosePosition();
         g_state = STATE_DONE_WIN;
         Print("*** TP: $", DoubleToString(profit,2), " - DONE ***");
         return;
      }
      
      // BE - move SL to entry at +$6
      if(profit >= InpBEDollars && !g_beApplied)
      {
         MoveSLtoEntry();
         g_beApplied = true;
         Print("*** BE at $", DoubleToString(profit,2), " ***");
      }
      
      // Floating guard
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(bal > 0 && profit <= -(bal * InpFloatingLossMax / 100.0))
      {
         ClosePosition();
         g_state = STATE_DONE_LOSS;
         Print("*** FLOATING GUARD: $", DoubleToString(profit,2), " ***");
         return;
      }
      return;
   }

   // Below: LOOKING or ARMED - need good time to trade
   if(!IsGoodTimeToTrade()) return;

   // STATE_ARMED - wait for trigger
   if(g_state == STATE_ARMED)
   {
      if(IsNewBar())
      {
         g_barsLeft--;
         if(g_barsLeft <= 0)
         {
            g_state = STATE_LOOKING;
            return;
         }
      }
      
      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask >= g_trigger)
      {
         // OPEN TRADE - tight emergency SL (30 points, ~$6 max)
         int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         double emergSL = NormalizeDouble(ask - 30.0, dg);
         
         trade.Buy(InpFixedLot, _Symbol, 0, emergSL, 0);
         g_state = STATE_IN_TRADE;
         g_beApplied = false;
         Print("*** OPEN @ ", DoubleToString(ask,dg), " ***");
      }
      return;
   }

   // STATE_LOOKING
   if(g_state == STATE_LOOKING)
   {
      if(IsNewBar())
      {
         if(IsRed(1))
         {
            int run=0;
            for(int i=2; i<=12; i++) { if(IsGreen(i)) run++; else break; }
            bool trendOK = (!InpUseTrend) || IsTrendBuy();
            if(run >= InpKneeMinRun && trendOK)
            {
               g_trigger  = iHigh(_Symbol, _Period, 1);
               g_barsLeft = InpValidBars;
               g_state    = STATE_ARMED;
               Print("*** ARMED @ ", DoubleToString(g_trigger,2), " ***");
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

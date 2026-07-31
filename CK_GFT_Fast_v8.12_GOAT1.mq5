//+------------------------------------------------------------------+
//|                                    CK GFT Fast v8.18 SIMPLE      |
//|   ONE TRADE PER DAY. Win=$10, Loss=$10. DONE.                    |
//|   No complex detection. Simple state machine.                     |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.18"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputs
input long   InpMagic             = 20260715;
input double InpFixedLot          = 0.02;
input double InpTPDollars         = 10.0;        // Close at +$10
input double InpSLDollars         = 10.0;        // Close at -$10
input double InpBEDollars         = 6.0;         // BE at +$6
input double InpFloatingLossMax   = 1.8;         // Emergency 1.8%
input int    InpMinTradeDuration  = 120;         // 2 min rule
input int    InpMaxSpreadPoints   = 50;
input bool   InpUseTrend          = true;
input int    InpEMAPeriod         = 21;
input int    InpEMASlow           = 50;
input int    InpKneeMinRun        = 2;
input int    InpValidBars         = 5;

//--- State
enum ENUM_DAY_STATE
{
   STATE_LOOKING,       // Looking for setup
   STATE_ARMED,         // Setup found, waiting trigger
   STATE_IN_TRADE,      // Trade open
   STATE_DONE_WIN,      // Won today - done
   STATE_DONE_LOSS      // Lost today - done
};

int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime       = 0;
datetime g_dayStart        = 0;
ENUM_DAY_STATE g_state     = STATE_LOOKING;
double   g_trigger         = 0.0;
double   g_kneeHigh        = 0.0;
int      g_barsLeft        = 0;
bool     g_beApplied       = false;

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
//| Helpers                                                           |
//+------------------------------------------------------------------+
double EMAFast(int s) { double b[]; if(CopyBuffer(emaFastHandle,0,s,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int s) { double b[]; if(CopyBuffer(emaSlowHandle,0,s,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar() { datetime t=iTime(_Symbol,_Period,0); if(t!=lastBarTime){lastBarTime=t;return(true);} return(false); }
bool IsGreen(int s) { return(iClose(_Symbol,_Period,s)>iOpen(_Symbol,_Period,s)); }
bool IsRed(int s)   { return(iClose(_Symbol,_Period,s)<iOpen(_Symbol,_Period,s)); }
bool IsTrendBuy() { return(EMAFast(1)>EMASlow(1) && iClose(_Symbol,_Period,1)>EMAFast(1)); }

//+------------------------------------------------------------------+
//| Get my position profit (returns 0 if no position)                 |
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
//| MAIN TICK - Simple state machine                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   // === NEW DAY? RESET ===
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart)
   {
      g_dayStart = iTime(_Symbol, PERIOD_D1, 0);
      if(!HasPosition())
         g_state = STATE_LOOKING;
      // If still in trade from yesterday, let it continue
   }

   // === STATE: DONE (win or loss) - do nothing ===
   if(g_state == STATE_DONE_WIN || g_state == STATE_DONE_LOSS)
      return;

   // === STATE: IN TRADE - manage it ===
   if(g_state == STATE_IN_TRADE)
   {
      if(!HasPosition())
      {
         // Position was closed by broker (SL hit or something)
         g_state = STATE_DONE_LOSS;
         Print("*** POSITION GONE (broker closed) - DONE FOR DAY ***");
         return;
      }
      
      double profit = GetProfit();
      int elapsed = GetElapsed();
      
      // LOSS: Close at -$10
      if(profit <= -InpSLDollars)
      {
         ClosePosition();
         g_state = STATE_DONE_LOSS;
         Print("*** LOSS: $", DoubleToString(profit,2), " - DONE FOR DAY ***");
         return;
      }
      
      // WIN: Close at +$10 (after 2 min)
      if(profit >= InpTPDollars && elapsed >= InpMinTradeDuration)
      {
         ClosePosition();
         g_state = STATE_DONE_WIN;
         Print("*** WIN: $", DoubleToString(profit,2), " - DONE FOR DAY ***");
         return;
      }
      
      // BE: Move SL to entry at +$6
      if(profit >= InpBEDollars && !g_beApplied)
      {
         MoveSLtoEntry();
         g_beApplied = true;
         Print("*** BE APPLIED at profit=$", DoubleToString(profit,2), " ***");
      }
      
      // Floating guard 1.8%
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(bal > 0 && profit <= -(bal * InpFloatingLossMax / 100.0))
      {
         ClosePosition();
         g_state = STATE_DONE_LOSS;
         Print("*** FLOATING GUARD: $", DoubleToString(profit,2), " ***");
         return;
      }
      
      return;  // While in trade, don't look for new setups
   }

   // === STATE: ARMED - waiting for trigger ===
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
      
      if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask >= g_trigger)
      {
         // OPEN TRADE - no broker TP/SL (only wide emergency SL)
         int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         double emergSL = NormalizeDouble(ask - 80.0, dg);  // ~$16 max if EA fails
         
         trade.Buy(InpFixedLot, _Symbol, 0, emergSL, 0);
         g_state = STATE_IN_TRADE;
         g_beApplied = false;
         Print("*** OPENED at ", DoubleToString(ask,dg), " ***");
      }
      return;
   }

   // === STATE: LOOKING - find setup ===
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
               Print("*** ARMED: trigger=", DoubleToString(g_trigger,2), " ***");
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

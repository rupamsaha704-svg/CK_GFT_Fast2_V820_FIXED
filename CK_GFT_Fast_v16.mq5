//+------------------------------------------------------------------+
//|                                             CK_GFT_Fast_v16.mq5  |
//|  Base: PURE v8.10 (user's original strategy) + Risk Mgmt ONLY    |
//|                                                                    |
//|  NO time filters, NO weekday skips. Same as v8.10 base.           |
//|                                                                    |
//|  ONLY additions:                                                   |
//|   - Partial TP1 at 10% progress → close 25% of position           |
//|   - Partial TP2 at 60% progress → close another 25% of position   |
//|   - BE at 65% progress (NOT at 1R)                                |
//|   - SL FIXED at original position until 65% BE trigger            |
//|   - MaxLot default 0.09 (72% margin @ 1:10 leverage, $5k account) |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast v16"
#property version   "16.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE (from v8.10 — unchanged) ===
input long   InpMagic            = 20260715;
input double InpRiskPercent      = 0.35;
input double InpRR               = 2.5;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 1.0;
input double InpDailyProfitStopR = 3.0;
input int    InpMaxSpreadPoints  = 50;
input bool   InpUseTrend         = true;
input int    InpEMAPeriod        = 21;
input int    InpEMASlow          = 50;
input int    InpKneeMinRun       = 2;
input int    InpValidBars        = 5;
input double InpSLBufferATR      = 0.3;
input double InpMaxLot           = 0.09;   // Was 0.08, now 0.09 (72% margin @ 1:10)

//=== RISK MANAGEMENT (v16 additions) ===
input bool   InpUsePartialTP     = true;   // Enable partial profit booking
input double InpTP1Progress      = 0.10;   // TP1 at 10% of TP distance
input double InpTP1CloseRatio    = 0.25;   // Close 25% of initial position
input double InpTP2Progress      = 0.60;   // TP2 at 60% of TP distance
input double InpTP2CloseRatio    = 0.25;   // Close 25% of initial position

input bool   InpUseBreakEven     = true;   // Enable BE
input double InpBEProgress       = 0.65;   // BE activates at 65% (NOT at 1R!)

//=== HANDLES / STATE ===
int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime  = 0;
datetime g_dayStart   = 0;
double   g_dayStartBal= 0.0;
double   g_oneR_money = 0.0;
int      g_tradesToday= 0;
int      g_dir        = 0;
double   g_trigger    = 0.0;
double   g_kneeLow    = 0.0;
double   g_kneeHigh   = 0.0;
double   g_pendingSL  = 0.0;
double   g_pendingTP  = 0.0;
int      g_barsLeft   = 0;

//=== Trade tracking (v16) ===
ulong    g_activeTicket  = 0;
double   g_initialLots   = 0.0;
int      g_partialsDone  = 0;    // 0=none, 1=TP1 done, 2=both done
bool     g_beActivated   = false;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   atrHandle     = iATR(_Symbol, _Period, 14);
   emaFastHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, _Period, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE || emaFastHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle     != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//=== Indicator helpers (unchanged from v8.10) ===
double ATR()
{
   double b[]; if(CopyBuffer(atrHandle,0,0,1,b)<=0) return(0); return(b[0]);
}
double EMAFast(int shift)
{
   double b[]; if(CopyBuffer(emaFastHandle,0,shift,1,b)<=0) return(0); return(b[0]);
}
double EMASlow(int shift)
{
   double b[]; if(CopyBuffer(emaSlowHandle,0,shift,1,b)<=0) return(0); return(b[0]);
}
bool IsNewBar()
{
   datetime t = iTime(_Symbol,_Period,0);
   if(t != lastBarTime){ lastBarTime=t; return(true); }
   return(false);
}
bool IsGreen(int s){ return(iClose(_Symbol,_Period,s) > iOpen(_Symbol,_Period,s)); }
bool IsRed(int s)  { return(iClose(_Symbol,_Period,s) < iOpen(_Symbol,_Period,s)); }

void ResetDaily()
{
   g_dayStart    = iTime(_Symbol,PERIOD_D1,0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_oneR_money  = g_dayStartBal * (InpRiskPercent/100.0);
   g_tradesToday = 0;
}

double RealizedRToday()
{
   if(g_oneR_money<=0) return(0);
   return((AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal) / g_oneR_money);
}

void Disarm()
{
   g_dir=0; g_trigger=0; g_kneeLow=0; g_kneeHigh=0;
   g_barsLeft=0; g_pendingSL=0; g_pendingTP=0;
}

void ResetTradeState()
{
   g_activeTicket  = 0;
   g_initialLots   = 0.0;
   g_partialsDone  = 0;
   g_beActivated   = false;
}

bool IsTrendBuy()
{
   return(EMAFast(1) > EMASlow(1) && iClose(_Symbol,_Period,1) > EMAFast(1));
}

//=== TryArmSetup (unchanged from v8.10) ===
void TryArmSetup()
{
   double atr = ATR();
   if(atr <= 0) return;
   double buf = InpSLBufferATR * atr;

   if(IsRed(1))
   {
      int run = 0;
      for(int i=2; i<=12; i++){ if(IsGreen(i)) run++; else break; }
      bool trendOK = (!InpUseTrend) || IsTrendBuy();
      if(run >= InpKneeMinRun && trendOK)
      {
         g_dir       = +1;
         g_kneeHigh  = iHigh(_Symbol, _Period, 1);
         g_kneeLow   = iLow(_Symbol,  _Period, 1);
         g_trigger   = g_kneeHigh;
         g_pendingSL = g_kneeLow - buf;
         double oneR = g_trigger - g_pendingSL;
         g_pendingTP = g_trigger + (InpRR * oneR);
         g_barsLeft  = InpValidBars;
      }
   }
}

//=== Lot sizing (unchanged from v8.10) ===
double LotForRisk(double riskMoney, double slDist)
{
   if(slDist <= 0) return(0);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0) return(0);
   double lossPerLot = (slDist / ts) * tv;
   if(lossPerLot <= 0) return(0);
   double lots = riskMoney / lossPerLot;
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / st) * st;
   if(lots < mn) lots = mn;
   if(lots > InpMaxLot) lots = InpMaxLot;
   return(lots);
}

double NormalizePartialVolume(double vol)
{
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double n  = MathFloor(vol / st) * st;
   if(n < mn) return(0);
   return(n);
}

int MyPositions()
{
   int c = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL)  == _Symbol) c++;
   }
   return(c);
}

ulong GetMyTicket()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL)  == _Symbol)
         return(tk);
   }
   return(0);
}

//=== OpenTrade (from v8.10, + tracking state) ===
void OpenTrade(int dir)
{
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl   = g_pendingSL;
   double tp   = g_pendingTP;
   double oneR = ask - sl;
   if(oneR <= 0) return;

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent/100.0);
   double lots = LotForRisk(riskMoney, oneR);
   if(lots <= 0) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, dg);
   tp = NormalizeDouble(tp, dg);

   if(trade.Buy(lots, _Symbol, 0, sl, tp))
   {
      g_tradesToday++;
      g_initialLots  = lots;
      g_partialsDone = 0;
      g_beActivated  = false;
   }
}

//+------------------------------------------------------------------+
//| v16 UNIFIED MANAGEMENT: Partial TPs (10%, 60%) + BE at 65%       |
//| SL stays FIXED at original until 65% BE trigger                   |
//+------------------------------------------------------------------+
void ManageTrade()
{
   if(MyPositions() == 0)
   {
      ResetTradeState();
      return;
   }

   ulong ticket = GetMyTicket();
   if(ticket == 0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double open       = PositionGetDouble(POSITION_PRICE_OPEN);
   double slc        = PositionGetDouble(POSITION_SL);
   double tp         = PositionGetDouble(POSITION_TP);
   double currentVol = PositionGetDouble(POSITION_VOLUME);
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    dg         = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double totalDist = tp - open;
   if(totalDist <= 0) return;

   double progress = (bid - open) / totalDist;

   if(g_initialLots <= 0) g_initialLots = currentVol;

   double mnLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   //=== TP1 at 10% progress ===
   if(InpUsePartialTP && g_partialsDone == 0 && progress >= InpTP1Progress)
   {
      double volToClose = NormalizePartialVolume(g_initialLots * InpTP1CloseRatio);
      if(volToClose > 0 && currentVol > volToClose && (currentVol - volToClose) >= mnLot)
      {
         if(trade.PositionClosePartial(ticket, volToClose))
         {
            g_partialsDone = 1;
            Print(">>> TP1 @ ", (int)(progress*100), "% — closed ", volToClose);
         }
      }
      else
      {
         g_partialsDone = 1;  // Volume too small, skip
      }
   }

   //=== TP2 at 60% progress ===
   if(InpUsePartialTP && g_partialsDone == 1 && progress >= InpTP2Progress)
   {
      double volToClose = NormalizePartialVolume(g_initialLots * InpTP2CloseRatio);
      if(volToClose > 0 && currentVol > volToClose && (currentVol - volToClose) >= mnLot)
      {
         if(trade.PositionClosePartial(ticket, volToClose))
         {
            g_partialsDone = 2;
            Print(">>> TP2 @ ", (int)(progress*100), "% — closed ", volToClose);
         }
      }
      else
      {
         g_partialsDone = 2;
      }
   }

   //=== BE at 65% progress (NOT at 1R!) ===
   //=== SL stays FIXED at original until this trigger ===
   if(InpUseBreakEven && !g_beActivated && progress >= InpBEProgress)
   {
      double be = NormalizeDouble(open, dg);
      if(slc < be)
      {
         if(trade.PositionModify(ticket, be, tp))
         {
            g_beActivated = true;
            Print(">>> BE activated @ ", (int)(progress*100), "% — SL to entry ", be);
         }
      }
      else
      {
         g_beActivated = true;
      }
   }
}

bool TradingAllowed()
{
   double r = RealizedRToday();
   if(InpDailyProfitStopR > 0 && r >=  InpDailyProfitStopR) return(false);
   if(InpDailyLossStopR   > 0 && r <= -InpDailyLossStopR)   return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| OnTick — v8.10 flow + new ManageTrade                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart) ResetDaily();

   ManageTrade();   // v16: Partial TPs + BE at 65% (SL fixed otherwise)

   if(IsNewBar())
   {
      if(g_dir != 0){ g_barsLeft--; if(g_barsLeft <= 0) Disarm(); }
      if(g_dir == 0 && MyPositions() == 0) TryArmSetup();
   }

   if(g_dir != 0 && MyPositions() == 0)
   {
      if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_dir > 0 && ask >= g_trigger){ OpenTrade(+1); Disarm(); }
   }
}
//+------------------------------------------------------------------+

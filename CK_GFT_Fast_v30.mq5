//+------------------------------------------------------------------+
//|                                             CK_GFT_Fast_v30.mq5  |
//|  Base: v29 logic + user-requested modifications                   |
//|                                                                    |
//|  Strategy (UNCHANGED - optimized inputs):                          |
//|   BUY:  Green run + Red knee + uptrend, break above knee high     |
//|   SELL: Red run + Green knee + downtrend, break below knee low    |
//|   EMA 17/51, ValidBars 8, SLBuffer 0.29, RR 3.0                   |
//|                                                                    |
//|  CHANGES FROM v29 (user request, 2026):                            |
//|   1. NO mid-trade partial booking:                                 |
//|        - 0.01 "lock" partial close ...... DISABLED (InpUseLock)    |
//|        - Break-even SL move ............. DISABLED (InpUseBreakEven)|
//|      => each trade only has ENTRY, SL and TP. Nothing booked mid.  |
//|   2. FIXED lot 0.02 per trade (auto-risk sizing turned off).       |
//|   3. Max DAILY loss = $50 -> stop trading that day, resume next.   |
//|   4. TIME FILTER: block NEW entries during the worst-loss hour     |
//|      (default 08:00-08:59 server time, from backtest analysis).    |
//|      Open trades are NOT closed by this filter - they run to       |
//|      their own SL / TP.                                            |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast v30"
#property version   "30.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE (optimized inputs - UNCHANGED) ===
input long   InpMagic            = 20260715;
input double InpRR               = 3.0;
input int    InpMaxTradesPerDay  = 3;
input int    InpMaxSpreadPoints  = 50;
input bool   InpUseTrend         = true;
input int    InpEMAPeriod        = 17;
input int    InpEMASlow          = 51;
input int    InpKneeMinRun       = 2;
input int    InpValidBars        = 8;
input double InpSLBufferATR      = 0.29;

//=== DIRECTIONS ===
input bool   InpAllowBuy         = true;
input bool   InpAllowSell        = true;

//=== LOT SIZING (v30: FIXED 0.02 lot per trade) ===
input bool   InpUseFixedLot      = true;   // Use a fixed lot (ignore auto-risk sizing)
input double InpFixedLot         = 0.02;   // Fixed lot per trade
input double InpRiskMoney        = 85.0;   // (auto-risk mode only) Target $ loss at SL per trade
input double InpMinLot           = 0.06;   // (auto-risk mode only) skip trade if computed lot < this
input double InpMaxLot           = 0.09;   // (auto-risk mode only) Lot cap

//=== HARD LOSS LIMITS (v30) ===
input double InpMaxDailyLoss     = 50.0;   // Daily loss cap ($) -> stop trading that day
input bool   InpUseOverallFloor  = true;   // Overall static floor hard stop
input double InpOverallFloorMoney= 4550.0; // Halt EA permanently if equity <= this ($)

//=== NO-MARTINGALE (v30) ===
input bool   InpNoMartingale     = true;   // After a loss, lot cannot increase until recovered

//=== TIME FILTER (v30: block worst-loss hour) ===
input bool   InpUseTimeFilter    = true;   // Block NEW entries during the hour window below
input int    InpBlockHourStart   = 8;      // Block from this server hour (inclusive, 0-23)
input int    InpBlockHourEnd     = 8;      // ...to this server hour (inclusive, 0-23)

//=== MID-TRADE MANAGEMENT (v30: ALL OFF - only SL/entry/TP) ===
input int    InpMinHoldSeconds   = 120;    // 2-min rule (only used if lock enabled)
input bool   InpUseLock          = false;  // v30: 0.01 partial lock DISABLED
input double InpLockProgress     = 0.25;   // Lock when price >= 25% of TP distance
input double InpLockLot           = 0.01;  // Lot to lock (close) after 2 min
input bool   InpUseBreakEven     = false;  // v30: break-even SL move DISABLED
input double InpBEProgress       = 0.65;   // BE at 65% progress

//=== HANDLES / STATE ===
int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime  = 0;
datetime g_dayStart   = 0;
double   g_dayStartBal= 0.0;
int      g_tradesToday= 0;
int      g_dir        = 0;
double   g_trigger    = 0.0;
double   g_kneeLow    = 0.0;
double   g_kneeHigh   = 0.0;
double   g_pendingSL  = 0.0;
double   g_pendingTP  = 0.0;
int      g_barsLeft   = 0;

//=== Trade / management state ===
double   g_initialLots   = 0.0;
bool     g_lockDone      = false;   // 0.01 lock done for current trade
bool     g_beActivated   = false;

//=== v29 protection state ===
double   g_startBalance   = 0.0;    // initial account balance (overall floor)
double   g_peakBalance    = 0.0;    // high-water mark (no-martingale recovery)
double   g_lockedLot      = 0.0;    // no-martingale ceiling (0 = free)
double   g_lotAtOpen      = 0.0;    // lot used for currently open trade
double   g_balAtOpen      = 0.0;    // balance when current trade opened
bool     g_hadPosition    = false;  // to detect close transition
bool     g_dailyLossHit   = false;  // daily loss cap reached -> stop today
bool     g_haltAll        = false;  // overall floor breached -> permanent halt

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   g_startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_peakBalance  = g_startBalance;
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

//=== Indicator helpers ===
double ATR(){ double b[]; if(CopyBuffer(atrHandle,0,0,1,b)<=0) return(0); return(b[0]); }
double EMAFast(int s){ double b[]; if(CopyBuffer(emaFastHandle,0,s,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int s){ double b[]; if(CopyBuffer(emaSlowHandle,0,s,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,_Period,0); if(t!=lastBarTime){lastBarTime=t;return(true);} return(false); }
bool IsGreen(int s){ return(iClose(_Symbol,_Period,s)>iOpen(_Symbol,_Period,s)); }
bool IsRed(int s){ return(iClose(_Symbol,_Period,s)<iOpen(_Symbol,_Period,s)); }

void ResetDaily()
{
   g_dayStart    = iTime(_Symbol,PERIOD_D1,0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_tradesToday = 0;
   g_dailyLossHit= false;   // reset daily loss cap each new day
}

void Disarm(){ g_dir=0; g_trigger=0; g_kneeLow=0; g_kneeHigh=0; g_barsLeft=0; g_pendingSL=0; g_pendingTP=0; }

void ResetTradeState()
{
   g_initialLots = 0.0;
   g_lockDone    = false;
   g_beActivated = false;
}

bool IsTrendBuy(){ return(EMAFast(1)>EMASlow(1) && iClose(_Symbol,_Period,1)>EMAFast(1)); }
bool IsTrendSell(){ return(EMAFast(1)<EMASlow(1) && iClose(_Symbol,_Period,1)<EMAFast(1)); }

long PositionAgeSeconds(ulong tk)
{
   if(!PositionSelectByTicket(tk)) return(0);
   return((long)(TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME)));
}

//+------------------------------------------------------------------+
//| TIME FILTER: is current server hour inside the blocked window?    |
//| (blocks NEW entries only; open trades are never touched here)     |
//+------------------------------------------------------------------+
bool InBlockedHour()
{
   if(!InpUseTimeFilter) return(false);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(InpBlockHourStart <= InpBlockHourEnd)
      return(h >= InpBlockHourStart && h <= InpBlockHourEnd);
   // window wraps past midnight (e.g. 22 -> 3)
   return(h >= InpBlockHourStart || h <= InpBlockHourEnd);
}

//+------------------------------------------------------------------+
//| TryArmSetup - BUY + SELL                                          |
//+------------------------------------------------------------------+
void TryArmSetup()
{
   double atr = ATR();
   if(atr <= 0) return;
   double buf = InpSLBufferATR * atr;

   if(InpAllowBuy && IsRed(1))
   {
      int run=0;
      for(int i=2;i<=12;i++){ if(IsGreen(i)) run++; else break; }
      bool trendOK=(!InpUseTrend)||IsTrendBuy();
      if(run>=InpKneeMinRun && trendOK)
      {
         g_dir=+1;
         g_kneeHigh=iHigh(_Symbol,_Period,1);
         g_kneeLow =iLow(_Symbol,_Period,1);
         g_trigger =g_kneeHigh;
         g_pendingSL=g_kneeLow-buf;
         double oneR=g_trigger-g_pendingSL;
         g_pendingTP=g_trigger+(InpRR*oneR);
         g_barsLeft=InpValidBars;
         return;
      }
   }

   if(InpAllowSell && IsGreen(1))
   {
      int run=0;
      for(int i=2;i<=12;i++){ if(IsRed(i)) run++; else break; }
      bool trendOK=(!InpUseTrend)||IsTrendSell();
      if(run>=InpKneeMinRun && trendOK)
      {
         g_dir=-1;
         g_kneeHigh=iHigh(_Symbol,_Period,1);
         g_kneeLow =iLow(_Symbol,_Period,1);
         g_trigger =g_kneeLow;
         g_pendingSL=g_kneeHigh+buf;
         double oneR=g_pendingSL-g_trigger;
         g_pendingTP=g_trigger-(InpRR*oneR);
         g_barsLeft=InpValidBars;
      }
   }
}

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//|  v30: fixed lot when InpUseFixedLot (default 0.02).               |
//|  Auto-risk mode kept for optional use (InpUseFixedLot=false).     |
//|  Returns 0 => skip trade.                                         |
//+------------------------------------------------------------------+
double LossPerLot(double slDist)
{
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0 || ts<=0 || slDist<=0) return(0);
   return((slDist/ts)*tv);   // $ loss per 1.0 lot at this SL distance
}

double ComputeLot(double slDist)
{
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(st<=0) st=0.01;

   //=== FIXED LOT MODE (v30 default) ===
   if(InpUseFixedLot)
      return(NormVol(InpFixedLot));   // 0 if below broker min

   //=== AUTO-RISK MODE (legacy v29) ===
   double lpl = LossPerLot(slDist);
   if(lpl<=0) return(0);

   double lot = InpRiskMoney / lpl;        // size to risk ~$85
   lot = MathFloor(lot/st)*st;

   if(lot > InpMaxLot) lot = InpMaxLot;    // cap at 0.09

   // No-martingale: don't exceed locked ceiling while in drawdown
   if(InpNoMartingale && g_lockedLot > 0.0 && lot > g_lockedLot)
      lot = g_lockedLot;

   if(lot < InpMinLot) return(0);          // SL too wide -> SKIP trade
   return(lot);
}

int MyPositions()
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol) c++;
   }
   return(c);
}

ulong GetMyTicket()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol) return(tk);
   }
   return(0);
}

double NormVol(double vol)
{
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(st<=0) st=0.01;
   double n=MathFloor(vol/st)*st;
   if(n<mn) return(0);
   return(n);
}

//+------------------------------------------------------------------+
//| Daily loss budget check                                           |
//+------------------------------------------------------------------+
double DailyLossUsed()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double used = g_dayStartBal - bal;
   return(used>0 ? used : 0);
}

//+------------------------------------------------------------------+
//| Open BUY / SELL                                                   |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double sl=g_pendingSL, tp=g_pendingTP;
   double slDist=ask-sl; if(slDist<=0) return;

   double lot=ComputeLot(slDist);
   if(lot<=0) return;   // skip (below min lot / SL too wide)

   // Daily loss guard: if this trade's max loss + today's loss > cap -> skip
   double thisRisk = lot * LossPerLot(slDist);
   if(DailyLossUsed() + thisRisk > InpMaxDailyLoss) return;

   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Buy(lot,_Symbol,0,sl,tp))
   {
      g_tradesToday++;
      g_initialLots=lot; g_lockDone=false; g_beActivated=false;
      g_lotAtOpen=lot; g_balAtOpen=AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

void OpenSell()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=g_pendingSL, tp=g_pendingTP;
   double slDist=sl-bid; if(slDist<=0) return;

   double lot=ComputeLot(slDist);
   if(lot<=0) return;

   double thisRisk = lot * LossPerLot(slDist);
   if(DailyLossUsed() + thisRisk > InpMaxDailyLoss) return;

   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Sell(lot,_Symbol,0,sl,tp))
   {
      g_tradesToday++;
      g_initialLots=lot; g_lockDone=false; g_beActivated=false;
      g_lotAtOpen=lot; g_balAtOpen=AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

//+------------------------------------------------------------------+
//| Manage open trade                                                 |
//|  v30: mid-trade actions run ONLY if their inputs are enabled.     |
//|  By default both are OFF -> trade runs untouched to SL / TP.      |
//+------------------------------------------------------------------+
void ManageTrade()
{
   // Nothing to do if all mid-trade management is disabled.
   if(!InpUseLock && !InpUseBreakEven) return;

   if(MyPositions()==0) return;
   ulong ticket=GetMyTicket();
   if(ticket==0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double slc =PositionGetDouble(POSITION_SL);
   double tp  =PositionGetDouble(POSITION_TP);
   double vol =PositionGetDouble(POSITION_VOLUME);
   long   type=PositionGetInteger(POSITION_TYPE);
   int    dg  =(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   double totalDist=0, progress=0;
   if(type==POSITION_TYPE_BUY)
   {
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      totalDist=tp-open; if(totalDist<=0) return;
      progress=(bid-open)/totalDist;
   }
   else if(type==POSITION_TYPE_SELL)
   {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      totalDist=open-tp; if(totalDist<=0) return;
      progress=(open-ask)/totalDist;
   }
   else return;

   double mnLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   long   age  =PositionAgeSeconds(ticket);

   //=== 0.01 LOCK (disabled by default in v30) ===
   if(InpUseLock && !g_lockDone && age>=InpMinHoldSeconds && progress>=InpLockProgress)
   {
      double v=NormVol(InpLockLot);
      if(v>0 && vol>v && (vol-v)>=mnLot)
      {
         if(trade.PositionClosePartial(ticket,v))
         {
            g_lockDone=true;
            Print(">>> LOCK 0.01 @ ",(int)(progress*100),"% (age ",age,"s)");
         }
      }
      else g_lockDone=true;
   }

   //=== BE at 65% (disabled by default in v30) ===
   if(InpUseBreakEven && !g_beActivated && progress>=InpBEProgress)
   {
      double be=NormalizeDouble(open,dg);
      if(type==POSITION_TYPE_BUY && slc<be)
      {
         if(trade.PositionModify(ticket,be,tp)){ g_beActivated=true; Print(">>> BE (BUY) @ ",(int)(progress*100),"%"); }
      }
      else if(type==POSITION_TYPE_SELL && slc>be)
      {
         if(trade.PositionModify(ticket,be,tp)){ g_beActivated=true; Print(">>> BE (SELL) @ ",(int)(progress*100),"%"); }
      }
      else g_beActivated=true;
   }
}

//+------------------------------------------------------------------+
//| Detect trade close -> update peak, no-martingale lock, daily loss |
//+------------------------------------------------------------------+
void OnTradeClosedUpdate()
{
   bool hasPos = (MyPositions()>0);

   if(g_hadPosition && !hasPos)
   {
      // A position just closed. Compare balance to balance-at-open.
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);

      if(bal < g_balAtOpen - 0.01)   // net loss on this trade
      {
         // No-martingale: lock lot ceiling at the lot we just used
         if(InpNoMartingale)
            g_lockedLot = g_lotAtOpen;

         // Daily loss cap check (realized)
         if(DailyLossUsed() >= InpMaxDailyLoss - 0.01)
            g_dailyLossHit = true;
      }

      ResetTradeState();
   }

   // Update peak balance high-water mark
   double bnow = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bnow > g_peakBalance) g_peakBalance = bnow;

   // No-martingale release: recovered to prior high-water mark
   if(InpNoMartingale && g_lockedLot > 0.0 && bnow >= g_peakBalance - 0.01)
      g_lockedLot = 0.0;

   g_hadPosition = hasPos;
}

//+------------------------------------------------------------------+
//| Overall floor hard stop                                           |
//+------------------------------------------------------------------+
bool OverallFloorGuard()
{
   if(!InpUseOverallFloor) return(false);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= InpOverallFloorMoney)
   {
      ulong tk=GetMyTicket(); if(tk>0) trade.PositionClose(tk);
      ResetTradeState();
      g_haltAll=true;
      Print(">>> OVERALL FLOOR ($",InpOverallFloorMoney,") breached at equity ",eq," - EA HALTED");
      return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Daily loss hard stop (equity-based intraday)                     |
//+------------------------------------------------------------------+
bool DailyLossGuard()
{
   if(g_dailyLossHit) return(true);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_dayStartBal - eq >= InpMaxDailyLoss)
   {
      ulong tk=GetMyTicket(); if(tk>0) trade.PositionClose(tk);
      ResetTradeState();
      g_dailyLossHit=true;
      Print(">>> DAILY LOSS CAP ($",InpMaxDailyLoss,") hit - stopped for today");
      return(true);
   }
   return(false);
}

bool TradingAllowed()
{
   if(g_haltAll)       return(false);
   if(g_dailyLossHit)  return(false);
   if(InBlockedHour()) return(false);   // v30: time filter blocks NEW entries only
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();

   // Detect close + maintain peak / no-martingale / daily loss
   OnTradeClosedUpdate();

   // Hard safety guards first
   if(OverallFloorGuard()) return;
   if(DailyLossGuard())    return;

   // Manage open trade (no-op by default in v30)
   ManageTrade();

   if(IsNewBar())
   {
      if(g_dir!=0){ g_barsLeft--; if(g_barsLeft<=0) Disarm(); }
      if(g_dir==0 && MyPositions()==0) TryArmSetup();
   }

   if(g_dir!=0 && MyPositions()==0)
   {
      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(g_dir>0 && ask>=g_trigger){ OpenBuy(); Disarm(); }
      else if(g_dir<0 && bid<=g_trigger){ OpenSell(); Disarm(); }
   }
}
//+------------------------------------------------------------------+

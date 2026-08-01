//+------------------------------------------------------------------+
//|                                             CK_GFT_Fast_v18.mq5  |
//|  Base: v17 + RR 1.33 + BE at 65% with +20% profit lock           |
//|                                                                    |
//|  CHANGES from v17:                                                 |
//|   - RR: 3.0 -> 1.33                                               |
//|   - BE at 65%: SL moves to ENTRY + 20% of TP distance            |
//|     (not breakeven, but profit-lock — we NEVER exit at loss       |
//|     once 65% is reached)                                           |
//|   - Everything else IDENTICAL to v17 (sell active, partial TP)    |
//|                                                                    |
//|  Logic:                                                            |
//|   65% reach → SL = Entry + 20% of (TP - Entry)                   |
//|   This means even if price reverses after 65%, minimum exit       |
//|   = 20% profit locked. NEVER goes to zero or loss after 65%.     |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast v18"
#property version   "18.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE ===
input long   InpMagic            = 20260715;
input double InpRiskPercent      = 0.35;
input double InpRR               = 1.33;   // RR 1:1.33
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
input double InpMaxLot           = 0.09;

//=== DIRECTIONS ===
input bool   InpAllowBuy         = true;
input bool   InpAllowSell        = true;

//=== PARTIAL TP ===
input bool   InpUsePartialTP     = true;
input double InpTP1Progress      = 0.10;   // 10% → close 25%
input double InpTP1CloseRatio    = 0.25;
input double InpTP2Progress      = 0.60;   // 60% → close 25%
input double InpTP2CloseRatio    = 0.25;

//=== BREAK-EVEN (PROFIT LOCK) ===
input bool   InpUseBreakEven     = true;
input double InpBEProgress       = 0.65;   // Trigger at 65% progress
input double InpBELockPercent    = 0.20;   // Lock 20% profit above entry (not zero!)

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

//=== Trade state ===
double   g_initialLots   = 0.0;
int      g_partialsDone  = 0;
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

double ATR(){ double b[]; if(CopyBuffer(atrHandle,0,0,1,b)<=0) return(0); return(b[0]); }
double EMAFast(int shift){ double b[]; if(CopyBuffer(emaFastHandle,0,shift,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int shift){ double b[]; if(CopyBuffer(emaSlowHandle,0,shift,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,_Period,0); if(t!=lastBarTime){lastBarTime=t;return(true);} return(false); }
bool IsGreen(int s){ return(iClose(_Symbol,_Period,s)>iOpen(_Symbol,_Period,s)); }
bool IsRed(int s){ return(iClose(_Symbol,_Period,s)<iOpen(_Symbol,_Period,s)); }

void ResetDaily()
{
   g_dayStart    = iTime(_Symbol,PERIOD_D1,0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_oneR_money  = g_dayStartBal*(InpRiskPercent/100.0);
   g_tradesToday = 0;
}

double RealizedRToday()
{
   if(g_oneR_money<=0) return(0);
   return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money);
}

void Disarm(){ g_dir=0; g_trigger=0; g_kneeLow=0; g_kneeHigh=0; g_barsLeft=0; g_pendingSL=0; g_pendingTP=0; }

void ResetTradeState()
{
   g_initialLots  = 0.0;
   g_partialsDone = 0;
   g_beActivated  = false;
}

bool IsTrendBuy(){ return(EMAFast(1)>EMASlow(1) && iClose(_Symbol,_Period,1)>EMAFast(1)); }
bool IsTrendSell(){ return(EMAFast(1)<EMASlow(1) && iClose(_Symbol,_Period,1)<EMAFast(1)); }

void TryArmSetup()
{
   double atr = ATR();
   if(atr <= 0) return;
   double buf = InpSLBufferATR * atr;

   // BUY
   if(InpAllowBuy && IsRed(1))
   {
      int run=0;
      for(int i=2;i<=12;i++){if(IsGreen(i))run++;else break;}
      bool trendOK=(!InpUseTrend)||IsTrendBuy();
      if(run>=InpKneeMinRun && trendOK)
      {
         g_dir=+1;
         g_kneeHigh=iHigh(_Symbol,_Period,1);
         g_kneeLow=iLow(_Symbol,_Period,1);
         g_trigger=g_kneeHigh;
         g_pendingSL=g_kneeLow-buf;
         double oneR=g_trigger-g_pendingSL;
         g_pendingTP=g_trigger+(InpRR*oneR);
         g_barsLeft=InpValidBars;
         return;
      }
   }

   // SELL
   if(InpAllowSell && IsGreen(1))
   {
      int run=0;
      for(int i=2;i<=12;i++){if(IsRed(i))run++;else break;}
      bool trendOK=(!InpUseTrend)||IsTrendSell();
      if(run>=InpKneeMinRun && trendOK)
      {
         g_dir=-1;
         g_kneeHigh=iHigh(_Symbol,_Period,1);
         g_kneeLow=iLow(_Symbol,_Period,1);
         g_trigger=g_kneeLow;
         g_pendingSL=g_kneeHigh+buf;
         double oneR=g_pendingSL-g_trigger;
         g_pendingTP=g_trigger-(InpRR*oneR);
         g_barsLeft=InpValidBars;
      }
   }
}

double LotForRisk(double riskMoney, double slDist)
{
   if(slDist<=0) return(0);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0) return(0);
   double lpl=(slDist/ts)*tv;
   if(lpl<=0) return(0);
   double lots=riskMoney/lpl;
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathFloor(lots/st)*st;
   if(lots<mn) lots=mn;
   if(lots>InpMaxLot) lots=InpMaxLot;
   return(lots);
}

double NormVol(double vol)
{
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double n=MathFloor(vol/st)*st;
   if(n<mn) return(0);
   return(n);
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
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol)
         return(tk);
   }
   return(0);
}

void OpenBuy()
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double sl=g_pendingSL; double tp=g_pendingTP;
   double oneR=ask-sl; if(oneR<=0) return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),oneR);
   if(lots<=0) return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Buy(lots,_Symbol,0,sl,tp))
   { g_tradesToday++; g_initialLots=lots; g_partialsDone=0; g_beActivated=false; }
}

void OpenSell()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=g_pendingSL; double tp=g_pendingTP;
   double oneR=sl-bid; if(oneR<=0) return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),oneR);
   if(lots<=0) return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Sell(lots,_Symbol,0,sl,tp))
   { g_tradesToday++; g_initialLots=lots; g_partialsDone=0; g_beActivated=false; }
}

//+------------------------------------------------------------------+
//| ManageTrade — Partial TPs + Profit Lock at 65%                    |
//| At 65%: SL = Entry + 20% of TP distance (NOT breakeven!)         |
//| This guarantees minimum 20% profit on remaining — never loss     |
//+------------------------------------------------------------------+
void ManageTrade()
{
   if(MyPositions()==0){ ResetTradeState(); return; }

   ulong ticket=GetMyTicket();
   if(ticket==0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double slc=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   double currentVol=PositionGetDouble(POSITION_VOLUME);
   long type=PositionGetInteger(POSITION_TYPE);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

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

   if(g_initialLots<=0) g_initialLots=currentVol;
   double mnLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

   // TP1 at 10%
   if(InpUsePartialTP && g_partialsDone==0 && progress>=InpTP1Progress)
   {
      double vol=NormVol(g_initialLots*InpTP1CloseRatio);
      if(vol>0 && currentVol>vol && (currentVol-vol)>=mnLot)
      { if(trade.PositionClosePartial(ticket,vol)) g_partialsDone=1; }
      else g_partialsDone=1;
   }

   // TP2 at 60%
   if(InpUsePartialTP && g_partialsDone==1 && progress>=InpTP2Progress)
   {
      double vol=NormVol(g_initialLots*InpTP2CloseRatio);
      if(vol>0 && currentVol>vol && (currentVol-vol)>=mnLot)
      { if(trade.PositionClosePartial(ticket,vol)) g_partialsDone=2; }
      else g_partialsDone=2;
   }

   // PROFIT LOCK at 65%: SL = Entry + 20% of TP distance
   // NOT breakeven! This locks minimum 20% profit.
   if(InpUseBreakEven && !g_beActivated && progress>=InpBEProgress)
   {
      double lockDist = totalDist * InpBELockPercent;  // 20% of TP distance

      if(type==POSITION_TYPE_BUY)
      {
         double newSL = NormalizeDouble(open + lockDist, dg);
         if(slc < newSL)
         {
            if(trade.PositionModify(ticket, newSL, tp))
            {
               g_beActivated=true;
               Print(">>> PROFIT LOCK (BUY) @ ",DoubleToString(progress*100,0),"% — SL to ",newSL," (+20% locked)");
            }
         }
         else g_beActivated=true;
      }
      else if(type==POSITION_TYPE_SELL)
      {
         double newSL = NormalizeDouble(open - lockDist, dg);
         if(slc > newSL)
         {
            if(trade.PositionModify(ticket, newSL, tp))
            {
               g_beActivated=true;
               Print(">>> PROFIT LOCK (SELL) @ ",DoubleToString(progress*100,0),"% — SL to ",newSL," (+20% locked)");
            }
         }
         else g_beActivated=true;
      }
   }
}

bool TradingAllowed()
{
   double r=RealizedRToday();
   if(InpDailyProfitStopR>0 && r>=InpDailyProfitStopR) return(false);
   if(InpDailyLossStopR>0 && r<=-InpDailyLossStopR) return(false);
   if(g_tradesToday>=InpMaxTradesPerDay) return(false);
   return(true);
}

void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();

   ManageTrade();

   if(IsNewBar())
   {
      if(g_dir!=0){g_barsLeft--;if(g_barsLeft<=0)Disarm();}
      if(g_dir==0 && MyPositions()==0) TryArmSetup();
   }

   if(g_dir!=0 && MyPositions()==0)
   {
      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(g_dir>0 && ask>=g_trigger){OpenBuy();Disarm();}
      else if(g_dir<0 && bid<=g_trigger){OpenSell();Disarm();}
   }
}
//+------------------------------------------------------------------+

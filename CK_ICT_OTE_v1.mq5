//+------------------------------------------------------------------+
//|                                              CK_ICT_OTE_v1.mq5    |
//|  STRATEGY #2 (agent-2): ICT liquidity-sweep + OTE reversal.       |
//|  Mechanical, few params (anti-overfit). Logic:                    |
//|   1) LIQUIDITY SWEEP (turtle soup): a bar takes out the recent    |
//|      swing low (sell-side liquidity) but CLOSES back above it =   |
//|      bullish sweep. Mirror for bearish (sweep of swing high).     |
//|   2) IMPULSE: after the sweep, price must rally (bull) forming an |
//|      impulse leg of at least InpMinImpulseATR * ATR.              |
//|   3) OTE ENTRY: enter on the retracement into the 0.62-0.79 zone  |
//|      of that impulse leg (Optimal Trade Entry, ~0.705).           |
//|   4) SL: just beyond the swept extreme (tight).                   |
//|   5) TP: fixed RR of the risk (targets opposing liquidity/STDV).  |
//|  Partial book + break-even carried over (user's requirement:      |
//|  book before a reversal can hit SL).                              |
//|  HARD: MaxLot cap 0.09, risk-based sizing. XAUUSD only.           |
//+------------------------------------------------------------------+
#property copyright "CK ICT-OTE v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE / RISK ===
input long   InpMagic            = 20260820;
input double InpRiskPercent      = 0.5;
input double InpRR               = 2.5;    // TP = RR * risk (opposing liquidity target)
input double InpMaxLot           = 0.09;   // HARD CAP
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input int    InpMaxSpreadPoints  = 60;
//=== STRUCTURE / SWEEP / OTE ===
input int    InpLiqLookback      = 20;     // swing-liquidity lookback (bars)
input double InpMinImpulseATR    = 1.5;    // impulse leg must be >= this * ATR
input double InpOTE_Lo           = 0.62;   // OTE zone low
input double InpOTE_Hi           = 0.79;   // OTE zone high
input int    InpMaxWaitBars      = 15;     // give up if no OTE entry within N bars of sweep
input double InpSLBufferATR      = 0.20;
input double InpMaxSL_ATR        = 3.0;    // reject too-wide stops
//=== PARTIAL BOOK + BREAK-EVEN ===
input bool   InpUsePartialTP     = true;
input double InpTP1Progress      = 0.40;
input double InpTP1CloseRatio    = 0.50;
input bool   InpUseBreakEven     = true;
input double InpBEProgress       = 0.45;

int      hAtr;
datetime lastBarTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_oneR_money=0;
int      g_tradesToday=0;
bool     g_beActivated=false, g_partialDone=false;
double   g_initLots=0.0;

// --- setup state machine ---
// dir: 0 none, +1 bullish setup armed, -1 bearish setup armed
int      g_dir=0;
double   g_sweepExtreme=0;   // swept low (bull) / high (bear) = 0% anchor
double   g_impulse=0;        // impulse high (bull) / low (bear) = 100% anchor
int      g_barsSinceSweep=0;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   if(hAtr==INVALID_HANDLE) return(INIT_FAILED);
   ResetDaily(); return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }

void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; }
double RealizedRToday(){ if(g_oneR_money<=0)return(0); return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }

int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }

double LotForRisk(double riskMoney,double slDist){ if(slDist<=0)return(0); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tv<=0||ts<=0)return(0); double lpl=(slDist/ts)*tv; if(lpl<=0)return(0); double lots=riskMoney/lpl; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); lots=MathFloor(lots/st)*st; if(lots<mn)lots=mn; if(lots>InpMaxLot)lots=InpMaxLot; return(lots); }
double NormPartial(double vol){ double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN); double n=MathFloor(vol/st)*st; if(n<mn)return(0); return(n); }

void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Buy(lots,_Symbol,0,sl,tp)){ g_tradesToday++; g_beActivated=false; g_partialDone=false; g_initLots=lots; } }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Sell(lots,_Symbol,0,sl,tp)){ g_tradesToday++; g_beActivated=false; g_partialDone=false; g_initLots=lots; } }

void ManageTrade()
{
   if(MyPositions()==0){ g_beActivated=false; g_partialDone=false; g_initLots=0; return; }
   ulong tk=GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP), vol=PositionGetDouble(POSITION_VOLUME);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_initLots<=0) g_initLots=vol;
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double prog=0;
   if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(tp-open<=0)return; prog=(bid-open)/(tp-open); }
   else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(open-tp<=0)return; prog=(open-ask)/(open-tp); }
   else return;
   if(InpUsePartialTP && !g_partialDone && prog>=InpTP1Progress){
      double cv=NormPartial(g_initLots*InpTP1CloseRatio);
      if(cv>0 && vol>cv && (vol-cv)>=mn){ if(trade.PositionClosePartial(tk,cv)) g_partialDone=true; }
      else g_partialDone=true;
   }
   if(InpUseBreakEven && !g_beActivated && prog>=InpBEProgress){
      double be=NormalizeDouble(open,dg);
      if(type==POSITION_TYPE_BUY && sl<be){ if(trade.PositionModify(tk,be,tp)) g_beActivated=true; }
      else if(type==POSITION_TYPE_SELL && sl>be){ if(trade.PositionModify(tk,be,tp)) g_beActivated=true; }
      else g_beActivated=true;
   }
}

// prior swing liquidity level from bars [2 .. 2+lookback] (exclude the just-closed bar 1 which does the sweep)
double PriorLow(){ int lo=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,InpLiqLookback,2); if(lo<0)return(0); return(iLow(_Symbol,PERIOD_CURRENT,lo)); }
double PriorHigh(){ int hi=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpLiqLookback,2); if(hi<0)return(0); return(iHigh(_Symbol,PERIOD_CURRENT,hi)); }

double OnTester()
{
   int h=FileOpen("ck_ict_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"deal","profit");
      HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
         if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,(string)tk,DoubleToString(p,2)); }
      FileClose(h);
   }
   return(0.0);
}

void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();
   ManageTrade();
   if(!IsNewBar()) return;
   if(MyPositions()>0){ g_dir=0; return; }   // one trade at a time; drop any pending setup
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return;

   double atr=ATR(); if(atr<=0)return; double buf=InpSLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   double l1=iLow(_Symbol,PERIOD_CURRENT,1);
   double h1=iHigh(_Symbol,PERIOD_CURRENT,1);

   //=== STEP 1: detect a NEW liquidity sweep on the just-closed bar (only if no setup armed) ===
   if(g_dir==0)
   {
      double pl=PriorLow(), ph=PriorHigh();
      // bullish sweep: bar-1 took out prior low but closed back above it
      if(pl>0 && l1<pl && c1>pl){ g_dir=+1; g_sweepExtreme=l1; g_impulse=h1; g_barsSinceSweep=0; }
      // bearish sweep: bar-1 took out prior high but closed back below it
      else if(ph>0 && h1>ph && c1<ph){ g_dir=-1; g_sweepExtreme=h1; g_impulse=l1; g_barsSinceSweep=0; }
      return; // wait for impulse/retrace on subsequent bars
   }

   //=== setup armed: update impulse, check invalidation, look for OTE entry ===
   g_barsSinceSweep++;
   if(g_barsSinceSweep>InpMaxWaitBars){ g_dir=0; return; }

   if(g_dir==+1)
   {
      // invalidation: price broke below the swept low -> structure failed
      if(l1<g_sweepExtreme){ g_dir=0; return; }
      // extend impulse high
      if(h1>g_impulse) g_impulse=h1;
      double range=g_impulse-g_sweepExtreme;
      if(range < InpMinImpulseATR*atr) return;   // impulse not big enough yet
      double oteHi=g_impulse-InpOTE_Lo*range;     // shallow edge of OTE (0.62)
      double oteLo=g_impulse-InpOTE_Hi*range;     // deep edge of OTE (0.79)
      // entry when price retraces DOWN into the OTE zone
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(l1<=oteHi && l1>=oteLo && c1>=oteLo)
      {
         double sl=g_sweepExtreme-buf; double risk=ask-sl;
         if(risk>0 && risk<=InpMaxSL_ATR*atr && TradingAllowed()){ OpenBuy(sl,ask+InpRR*risk); }
         g_dir=0; return;
      }
   }
   else if(g_dir==-1)
   {
      if(h1>g_sweepExtreme){ g_dir=0; return; }
      if(l1<g_impulse) g_impulse=l1;
      double range=g_sweepExtreme-g_impulse;
      if(range < InpMinImpulseATR*atr) return;
      double oteLo=g_impulse+InpOTE_Lo*range;
      double oteHi=g_impulse+InpOTE_Hi*range;
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(h1>=oteLo && h1<=oteHi && c1<=oteHi)
      {
         double sl=g_sweepExtreme+buf; double risk=sl-bid;
         if(risk>0 && risk<=InpMaxSL_ATR*atr && TradingAllowed()){ OpenSell(sl,bid-InpRR*risk); }
         g_dir=0; return;
      }
   }
}
//+------------------------------------------------------------------+

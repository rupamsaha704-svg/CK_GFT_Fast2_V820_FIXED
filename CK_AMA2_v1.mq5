//+------------------------------------------------------------------+
//|   CK_AMA2_v1.mq5 — DUAL Adaptive MA (39/79) crossover + retest   |
//|   From user's spec: two AMA lines (fast 39, slow 79), trade the   |
//|   trend when fast>slow, enter on FIRST-TOUCH retest of fast AMA,  |
//|   MACD confirmation. SL swing/ATR, TP RR, break-even.             |
//|   Deterministic, no look-ahead. Dumps time,profit for validation |
//|   + correlation vs v23.                                           |
//+------------------------------------------------------------------+
#property copyright "CK AMA2 v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic          = 20261110;
input double InpRiskPercent    = 0.5;
input double InpRR             = 2.5;
input double InpMaxLot         = 0.09;
input int    InpMaxTradesPerDay= 3;
input double InpDailyLossStopR = 2.0;
input double InpDailyProfitStopR=4.0;
input int    InpMaxSpreadPoints= 60;
input int    InpFastLen        = 39;   // fast AMA efficiency window
input int    InpSlowLen        = 79;   // slow AMA efficiency window
input int    InpAmaFast        = 2;
input int    InpAmaSlow        = 30;
input int    InpSeed           = 320;
input bool   InpUseMACD        = true;
input int    InpSwingLB        = 10;
input double InpSLBufferATR    = 0.30;
input double InpMaxSL_ATR      = 3.0;
input bool   InpUseBreakEven   = true;
input double InpBEProgress     = 0.50;

int      hAtr,hMacd;
double   g_fa,g_sa;
datetime lastBarTime=0, g_dayStart=0;
double   g_dayStartBal=0, g_oneR_money=0;
int      g_tradesToday=0; bool g_beActivated=false;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   hMacd=iMACD(_Symbol,PERIOD_CURRENT,12,26,9,PRICE_CLOSE);
   if(hAtr==INVALID_HANDLE||hMacd==INVALID_HANDLE)return(INIT_FAILED);
   g_fa=2.0/(InpAmaFast+1.0); g_sa=2.0/(InpAmaSlow+1.0);
   ResetDaily(); return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); if(hMacd!=INVALID_HANDLE)IndicatorRelease(hMacd); }
double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
bool MacdBull(){ double m[],s[]; if(CopyBuffer(hMacd,0,1,1,m)<=0)return(true); if(CopyBuffer(hMacd,1,1,1,s)<=0)return(true); return(m[0]>s[0]); }
bool MacdBear(){ double m[],s[]; if(CopyBuffer(hMacd,0,1,1,m)<=0)return(true); if(CopyBuffer(hMacd,1,1,1,s)<=0)return(true); return(m[0]<s[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }
void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; }
double RealizedRToday(){ if(g_oneR_money<=0)return(0); return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
double LotForRisk(double riskMoney,double slDist){ if(slDist<=0)return(0); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tv<=0||ts<=0)return(0); double lpl=(slDist/ts)*tv; if(lpl<=0)return(0); double lots=riskMoney/lpl; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); lots=MathFloor(lots/st)*st; if(lots<mn)lots=mn; if(lots>InpMaxLot)lots=InpMaxLot; return(lots); }

// AMA at bar1 & bar2 for a given efficiency length
bool AMA(int length,double &a1,double &a2){
   int seed=InpSeed; if(Bars(_Symbol,PERIOD_CURRENT)<seed+length+5)return(false);
   double ama=iClose(_Symbol,PERIOD_CURRENT,seed); bool g1=false,g2=false;
   for(int s=seed-1;s>=1;s--){
      int hi=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,length+1,s);
      int lo=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,length+1,s);
      if(hi<0||lo<0)continue;
      double hh=iHigh(_Symbol,PERIOD_CURRENT,hi),ll=iLow(_Symbol,PERIOD_CURRENT,lo),c=iClose(_Symbol,PERIOD_CURRENT,s);
      double mltp=(hh-ll!=0)?MathAbs(2*c-ll-hh)/(hh-ll):0;
      double ssc=mltp*(g_fa-g_sa)+g_sa;
      ama=ama+MathPow(ssc,2)*(c-ama);
      if(s==2){a2=ama;g2=true;} if(s==1){a1=ama;g1=true;}
   }
   return(g1&&g2);
}
void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Buy(lots,_Symbol,0,sl,tp)){ g_tradesToday++; g_beActivated=false; } }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Sell(lots,_Symbol,0,sl,tp)){ g_tradesToday++; g_beActivated=false; } }
void ManageTrade(){
   if(!InpUseBreakEven)return; if(MyPositions()==0){ g_beActivated=false; return; }
   ulong tk=GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_beActivated)return; double prog=0;
   if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(tp-open<=0)return; prog=(bid-open)/(tp-open); if(prog>=InpBEProgress&&sl<open){ if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
   else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(open-tp<=0)return; prog=(open-ask)/(open-tp); if(prog>=InpBEProgress&&sl>open){ if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
}
double OnTester(){
   int h=FileOpen("ck_ama2_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"time","profit");
      HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
         if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
         double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h);
   }
   return(0.0);
}
void OnTick(){
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();
   ManageTrade();
   if(!IsNewBar())return;
   if(MyPositions()>0)return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints)return;
   if(!TradingAllowed())return;
   double atr=ATR(); if(atr<=0)return; double buf=InpSLBufferATR*atr;
   double f1,f2,s1,s2; if(!AMA(InpFastLen,f1,f2))return; if(!AMA(InpSlowLen,s1,s2))return;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1),o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1),hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   bool bullRegime=(f1>s1), bearRegime=(f1<s1);
   // LONG: bull regime + first-touch retest of fast AMA (low dips to fama, closes back above) + bullish bar + MACD
   if(bullRegime && lo1<=f1 && c1>f1 && c1>o1 && (!InpUseMACD||MacdBull())){
      int loIdx=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,InpSwingLB,1); if(loIdx<0)return;
      double sl=iLow(_Symbol,PERIOD_CURRENT,loIdx)-buf; double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl;
      if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenBuy(sl,ask+InpRR*risk); return; }
   }
   // SHORT: bear regime + retest of fast AMA from below + bearish bar + MACD
   if(bearRegime && hi1>=f1 && c1<f1 && c1<o1 && (!InpUseMACD||MacdBear())){
      int hiIdx=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpSwingLB,1); if(hiIdx<0)return;
      double sl=iHigh(_Symbol,PERIOD_CURRENT,hiIdx)+buf; double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid;
      if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenSell(sl,bid-InpRR*risk); }
   }
}
//+------------------------------------------------------------------+

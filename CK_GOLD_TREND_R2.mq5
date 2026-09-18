//+------------------------------------------------------------------+
//|  CK_GOLD_TREND_R2.mq5 — 4H / 1H / 15min top-down gold trend.      |
//|  Cascade: 4H EMA trend = BIAS (only trade with it) -> 1H EMA200 + |
//|  breakout structure -> M15 pullback/entry candle (FIX09 core).    |
//|  + ADX chop filter on M15 (skip ranging). Fixed lot 0.09, RR 3,   |
//|  BE, 3 trades/day, daily +/-R limits. All filter params tunable.  |
//|  A/B: set InpUseBiasTF / InpUseADX = false to reproduce baseline. |
//+------------------------------------------------------------------+
#property copyright "CK GOLD TREND R2"
#property version   "2.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic            = 20260922;
input double InpFixedLot          = 0.09;
input double InpMaxLot           = 0.09;
input double InpRiskPercent      = 2.0;
input double InpRR               = 3.0;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input double InpMaxSpreadPrice   = 0.60;
input ENUM_TIMEFRAMES InpHTF     = PERIOD_H1;    // 1H structure timeframe
input int    InpTrendEMA         = 200;          // 1H trend EMA
input int    InpBreakoutLookback = 20;
input int    InpBreakoutMaxAge   = 12;
input int    InpEntryEMA         = 20;           // M15 entry EMA
input int    InpSwingLookback    = 10;
input double InpMaxSL_ATR        = 2.5;
input double InpSLBufferATR      = 0.20;
input bool   InpUseBreakEven     = true;
input double InpBEProgress       = 0.50;
//--- 4H top bias + M15 chop filter ---
input bool   InpUseBiasTF        = true;         // 4H trend bias gate
input ENUM_TIMEFRAMES InpBiasTF  = PERIOD_H4;    // 4H
input int    InpBiasEMA          = 200;          // 4H trend EMA (tunable)
input bool   InpUseADX           = true;         // skip ranging (ADX on M15)
input int    InpADXPeriod        = 14;
input double InpADXMin           = 20.0;         // trade only if ADX>=this (tunable)

int      hEmaHTF,hEmaLTF,hAtr,hADX,hEmaBias;
datetime lastBarTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_oneR_money=0;
int      g_tradesToday=0; bool g_beActivated=false;
datetime g_beTryBar=0;
int      g_cSpread=0,g_cReject=0,g_cRange=0,g_cBias=0;
string   GK_DAY, GK_BAL, GK_TRD;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hEmaHTF=iMA(_Symbol,InpHTF,InpTrendEMA,0,MODE_EMA,PRICE_CLOSE);
   hEmaLTF=iMA(_Symbol,PERIOD_CURRENT,InpEntryEMA,0,MODE_EMA,PRICE_CLOSE);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   hADX=iADX(_Symbol,PERIOD_CURRENT,InpADXPeriod);
   hEmaBias=iMA(_Symbol,InpBiasTF,InpBiasEMA,0,MODE_EMA,PRICE_CLOSE);
   if(hEmaHTF==INVALID_HANDLE||hEmaLTF==INVALID_HANDLE||hAtr==INVALID_HANDLE||hADX==INVALID_HANDLE||hEmaBias==INVALID_HANDLE)return(INIT_FAILED);
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_DAY="ckr2_day_"+scope; GK_BAL="ckr2_bal_"+scope; GK_TRD="ckr2_trd_"+scope;
   LoadOrResetDaily();
   PrintFormat("[R2] 4H-bias=%s(ema%d) ADX=%s(min%.0f) TFs=4H/1H/M15",(InpUseBiasTF?"ON":"OFF"),InpBiasEMA,(InpUseADX?"ON":"OFF"),InpADXMin);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ IndicatorRelease(hEmaHTF);IndicatorRelease(hEmaLTF);IndicatorRelease(hAtr);IndicatorRelease(hADX);IndicatorRelease(hEmaBias); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
double EmaHTF(int s){ double b[]; if(CopyBuffer(hEmaHTF,0,s,1,b)<=0)return(0); return(b[0]); }
double EmaLTF(int s){ double b[]; if(CopyBuffer(hEmaLTF,0,s,1,b)<=0)return(0); return(b[0]); }
double ADXv(){ double b[]; if(CopyBuffer(hADX,0,1,1,b)<=0)return(0); return(b[0]); }
double EmaBias(){ double b[]; if(CopyBuffer(hEmaBias,0,1,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }

bool MarketOpen(){
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int sec=dt.hour*3600+dt.min*60+dt.sec;
   datetime from,to; bool any=false;
   for(uint i=0;i<10;i++){ if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)dt.day_of_week,i,from,to)) break; any=true; if(sec>=(int)from && sec<(int)to) return(true); }
   if(!any) return(true); return(false);
}
double FixedLot(){
   double lot=InpFixedLot; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN); double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX); double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathRound(lot/st)*st; if(lot<mn) lot=mn; if(lot>InpMaxLot) lot=InpMaxLot; if(mx>0 && lot>mx) lot=mx; return(lot);
}
void LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0); datetime gday=(datetime)GlobalVariableGet(GK_DAY);
   if(gday==today && today>0){ g_dayStart=today; g_dayStartBal=GlobalVariableGet(GK_BAL); g_tradesToday=(int)GlobalVariableGet(GK_TRD); }
   else { g_dayStart=today; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)today); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }
   g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0);
}
void NewDay(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)g_dayStart); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }
double RealizedRToday(){
   if(g_oneR_money<=0)return(0); double pl=0; if(!HistorySelect(g_dayStart,TimeCurrent()))return(0); int td=HistoryDealsTotal();
   for(int i=0;i<td;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      pl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_FEE); }
   return(pl/g_oneR_money);
}
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
bool RecentBreakUp(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int hi=iHighest(_Symbol,InpHTF,MODE_HIGH,InpBreakoutLookback,s+1); if(hi<0)continue; if(iClose(_Symbol,InpHTF,s)>iHigh(_Symbol,InpHTF,hi))return(true);} return(false); }
bool RecentBreakDown(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int lo=iLowest(_Symbol,InpHTF,MODE_LOW,InpBreakoutLookback,s+1); if(lo<0)continue; if(iClose(_Symbol,InpHTF,s)<iLow(_Symbol,InpHTF,lo))return(true);} return(false); }
void CountIfFilled(bool sent,string tag){
   uint rc=trade.ResultRetcode(); bool filled = sent && (rc==TRADE_RETCODE_DONE||rc==TRADE_RETCODE_DONE_PARTIAL) && trade.ResultDeal()!=0;
   if(filled){ g_tradesToday++; g_beActivated=false; GlobalVariableSet(GK_TRD,g_tradesToday); }
   else { g_cReject++; PrintFormat("[R2] ORDER_FAIL %s rc=%u %s",tag,rc,trade.ResultRetcodeDescription()); }
}
void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(ask-sl<=0)return; double lots=FixedLot(); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=trade.Buy(lots,_Symbol,0,sl,tp); CountIfFilled(s,"BUY"); }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(sl-bid<=0)return; double lots=FixedLot(); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=trade.Sell(lots,_Symbol,0,sl,tp); CountIfFilled(s,"SELL"); }
void ManageTrade(){
   if(!InpUseBreakEven)return; if(MyPositions()==0){ g_beActivated=false; return; }
   ulong tk=GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_beActivated)return; double prog=0; if(!MarketOpen()) return; datetime cb=iTime(_Symbol,PERIOD_CURRENT,0); if(g_beTryBar==cb) return;
   if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(tp-open<=0)return; prog=(bid-open)/(tp-open); if(prog>=InpBEProgress&&sl<open){ g_beTryBar=cb; if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
   else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(open-tp<=0)return; prog=(open-ask)/(open-tp); if(prog>=InpBEProgress&&sl>open){ g_beTryBar=cb; if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
}
double OnTester(){
   PrintFormat("[R2] rangeSkip=%d biasSkip=%d spreadSkip=%d rejects=%d",g_cRange,g_cBias,g_cSpread,g_cReject);
   int h=FileOpen("ck_gold_r2_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit"); HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h); }
   return(0.0);
}
void OnTick(){
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) NewDay();
   ManageTrade();
   if(!IsNewBar())return;
   if(MyPositions()>0)return;
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ g_cSpread++; return; }
   if(!MarketOpen()) return;
   if(!TradingAllowed())return;
   // chop filter (M15 ADX)
   if(InpUseADX && ADXv() < InpADXMin){ g_cRange++; return; }
   // 4H top bias
   double biasC=iClose(_Symbol,InpBiasTF,1), biasE=EmaBias();
   bool biasUp = (!InpUseBiasTF) || (biasE>0 && biasC>biasE);
   bool biasDn = (!InpUseBiasTF) || (biasE>0 && biasC<biasE);

   double atr=ATR(); if(atr<=0)return; double buf=InpSLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1),o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,2),l2=iLow(_Symbol,PERIOD_CURRENT,2);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1),hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaL=EmaLTF(1),closeH1=iClose(_Symbol,InpHTF,1),emaH=EmaHTF(1);
   if((closeH1>emaH) && RecentBreakUp() && (lo1<=emaL) && (c1>o1)&&(c1>emaL)&&(c1>h2)){
      if(!biasUp){ g_cBias++; }
      else { double sl=MathMin(lo1,l2)-buf; double a2=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=a2-sl; if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenBuy(sl,a2+InpRR*risk); return; } }
   }
   if((closeH1<emaH) && RecentBreakDown() && (hi1>=emaL) && (c1<o1)&&(c1<emaL)&&(c1<l2)){
      if(!biasDn){ g_cBias++; }
      else { double sl=MathMax(hi1,h2)+buf; double b2=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-b2; if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenSell(sl,b2-InpRR*risk); } }
   }
}
//+------------------------------------------------------------------+

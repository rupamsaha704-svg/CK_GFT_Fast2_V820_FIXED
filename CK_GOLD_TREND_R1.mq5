//+------------------------------------------------------------------+
//|  CK_GOLD_TREND_R1.mq5  — FIX09 gold trend + REGIME/TREND filters. |
//|  Adds (toggleable): (1) ADX ranging filter — SKIP trades when the |
//|  market is choppy (ADX below threshold); (2) D1 trend bias — take |
//|  LONG only when Daily trend is up, SHORT only when Daily trend is  |
//|  down. Goal: stop bleeding in ranging markets, trade only with the |
//|  higher-timeframe trend. Everything else = validated FIX09 logic.  |
//|  A/B: set InpUseADX/InpUseD1Bias = false to reproduce the baseline.|
//+------------------------------------------------------------------+
#property copyright "CK GOLD TREND R1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic            = 20260921;
input double InpFixedLot          = 0.09;
input double InpMaxLot           = 0.09;
input double InpRiskPercent      = 2.0;
input double InpRR               = 3.0;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input double InpMaxSpreadPrice   = 0.60;
input ENUM_TIMEFRAMES InpHTF     = PERIOD_H1;
input int    InpTrendEMA         = 200;
input int    InpBreakoutLookback = 20;
input int    InpBreakoutMaxAge   = 12;
input int    InpEntryEMA         = 20;
input int    InpSwingLookback    = 10;
input double InpMaxSL_ATR        = 2.5;
input double InpSLBufferATR      = 0.20;
input bool   InpUseBreakEven     = true;
input double InpBEProgress       = 0.50;
//--- NEW: regime / trend filters (the fix for ranging-market bleed) ---
input bool   InpUseADX           = true;      // skip ranging markets (ADX filter)
input int    InpADXPeriod        = 14;
input double InpADXMin           = 22.0;      // trade only if ADX >= this (trend present)
input bool   InpUseD1Bias        = true;      // trade only WITH the Daily trend
input int    InpD1EMA            = 50;        // Daily trend EMA

int      hEmaHTF,hEmaLTF,hAtr,hADX,hEmaD1;
datetime lastBarTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_oneR_money=0;
int      g_tradesToday=0; bool g_beActivated=false;
datetime g_beTryBar=0;
int      g_cSpread=0, g_cSpreadDiv=0, g_cSubMin=0, g_cReject=0, g_cRange=0, g_cBias=0;
string   GK_DAY, GK_BAL, GK_TRD;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_NO);
   hEmaHTF=iMA(_Symbol,InpHTF,InpTrendEMA,0,MODE_EMA,PRICE_CLOSE);
   hEmaLTF=iMA(_Symbol,PERIOD_CURRENT,InpEntryEMA,0,MODE_EMA,PRICE_CLOSE);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   hADX=iADX(_Symbol,PERIOD_CURRENT,InpADXPeriod);
   hEmaD1=iMA(_Symbol,PERIOD_D1,InpD1EMA,0,MODE_EMA,PRICE_CLOSE);
   if(hEmaHTF==INVALID_HANDLE||hEmaLTF==INVALID_HANDLE||hAtr==INVALID_HANDLE||hADX==INVALID_HANDLE||hEmaD1==INVALID_HANDLE)return(INIT_FAILED);
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_DAY="ckgtr_day_"+scope; GK_BAL="ckgtr_bal_"+scope; GK_TRD="ckgtr_trd_"+scope;
   LoadOrResetDaily();
   PrintFormat("[CK_GOLD_TREND_R1] lot=%.2f ADXfilter=%s(min%.0f) D1bias=%s(ema%d)",
      FixedLot(), (InpUseADX?"ON":"OFF"), InpADXMin, (InpUseD1Bias?"ON":"OFF"), InpD1EMA);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ IndicatorRelease(hEmaHTF); IndicatorRelease(hEmaLTF); IndicatorRelease(hAtr); IndicatorRelease(hADX); IndicatorRelease(hEmaD1); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
double EmaHTF(int s){ double b[]; if(CopyBuffer(hEmaHTF,0,s,1,b)<=0)return(0); return(b[0]); }
double EmaLTF(int s){ double b[]; if(CopyBuffer(hEmaLTF,0,s,1,b)<=0)return(0); return(b[0]); }
double ADXv(){ double b[]; if(CopyBuffer(hADX,0,1,1,b)<=0)return(0); return(b[0]); }   // ADX main, last closed bar
double EmaD1(){ double b[]; if(CopyBuffer(hEmaD1,0,1,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }

bool MarketOpen(){
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   int sec=dt.hour*3600+dt.min*60+dt.sec;
   datetime from,to; bool any=false;
   for(uint i=0;i<10;i++){
      if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)dt.day_of_week,i,from,to)) break;
      any=true;
      if(sec>=(int)from && sec<(int)to) return(true);
   }
   if(!any) return(true);
   return(false);
}
double FixedLot(){
   double lot=InpFixedLot;
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathRound(lot/st)*st;
   if(lot<mn) lot=mn;
   if(lot>InpMaxLot) lot=InpMaxLot;
   if(mx>0 && lot>mx) lot=mx;
   return(lot);
}
void LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0);
   datetime gday=(datetime)GlobalVariableGet(GK_DAY);
   if(gday==today && today>0){ g_dayStart=today; g_dayStartBal=GlobalVariableGet(GK_BAL); g_tradesToday=(int)GlobalVariableGet(GK_TRD); }
   else { g_dayStart=today; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0;
      GlobalVariableSet(GK_DAY,(double)today); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }
   g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0);
}
void NewDay(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0;
   GlobalVariableSet(GK_DAY,(double)g_dayStart); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }
double RealizedRToday(){
   if(g_oneR_money<=0)return(0);
   double pl=0; if(!HistorySelect(g_dayStart,TimeCurrent()))return(0);
   int td=HistoryDealsTotal();
   for(int i=0;i<td;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      pl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)
         +HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_FEE);
   }
   return(pl/g_oneR_money);
}
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
bool RecentBreakUp(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int hi=iHighest(_Symbol,InpHTF,MODE_HIGH,InpBreakoutLookback,s+1); if(hi<0)continue; if(iClose(_Symbol,InpHTF,s)>iHigh(_Symbol,InpHTF,hi))return(true);} return(false); }
bool RecentBreakDown(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int lo=iLowest(_Symbol,InpHTF,MODE_LOW,InpBreakoutLookback,s+1); if(lo<0)continue; if(iClose(_Symbol,InpHTF,s)<iLow(_Symbol,InpHTF,lo))return(true);} return(false); }
void CountIfFilled(bool sent,string tag){
   uint rc=trade.ResultRetcode();
   bool filled = sent && (rc==TRADE_RETCODE_DONE||rc==TRADE_RETCODE_DONE_PARTIAL) && trade.ResultDeal()!=0;
   if(filled){ g_tradesToday++; g_beActivated=false; GlobalVariableSet(GK_TRD,g_tradesToday); }
   else { g_cReject++;
      PrintFormat("[CK_GOLD_TREND_R1] ORDER_FAIL tag=%s sent=%s rc=%u %s",tag,(sent?"true":"false"),rc,trade.ResultRetcodeDescription()); }
}
void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=FixedLot(); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=trade.Buy(lots,_Symbol,0,sl,tp); CountIfFilled(s,"BUY"); }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=FixedLot(); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=trade.Sell(lots,_Symbol,0,sl,tp); CountIfFilled(s,"SELL"); }
void ManageTrade(){
   if(!InpUseBreakEven)return; if(MyPositions()==0){ g_beActivated=false; return; }
   ulong tk=GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_beActivated)return; double prog=0;
   if(!MarketOpen()) return;
   datetime cb=iTime(_Symbol,PERIOD_CURRENT,0);
   if(g_beTryBar==cb) return;
   if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(tp-open<=0)return; prog=(bid-open)/(tp-open); if(prog>=InpBEProgress&&sl<open){ g_beTryBar=cb; if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
   else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(open-tp<=0)return; prog=(open-ask)/(open-tp); if(prog>=InpBEProgress&&sl>open){ g_beTryBar=cb; if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
}
double OnTester(){
   PrintFormat("[CK_GOLD_TREND_R1] rangeSkip=%d biasSkip=%d spreadSkip=%d rejects=%d",g_cRange,g_cBias,g_cSpread,g_cReject);
   int h=FileOpen("ck_gold_trend_r1_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) NewDay();
   ManageTrade();
   if(!IsNewBar())return;
   if(MyPositions()>0)return;
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ g_cSpread++; return; }
   if(!MarketOpen()) return;
   if(!TradingAllowed())return;

   // --- NEW regime filter: skip ranging markets ---
   if(InpUseADX && ADXv() < InpADXMin){ g_cRange++; return; }
   // --- NEW daily trend bias ---
   double d1c=iClose(_Symbol,PERIOD_D1,0), d1e=EmaD1();
   bool d1up = (!InpUseD1Bias) || (d1e>0 && d1c>d1e);
   bool d1dn = (!InpUseD1Bias) || (d1e>0 && d1c<d1e);

   double atr=ATR(); if(atr<=0)return; double buf=InpSLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1),o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,2),l2=iLow(_Symbol,PERIOD_CURRENT,2);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1),hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaL=EmaLTF(1),closeH1=iClose(_Symbol,InpHTF,1),emaH=EmaHTF(1);
   if((closeH1>emaH) && RecentBreakUp() && (lo1<=emaL) && (c1>o1)&&(c1>emaL)&&(c1>h2)){
      if(!d1up){ g_cBias++; }
      else {
         double sl=MathMin(lo1,l2)-buf; double a2=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=a2-sl;
         if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenBuy(sl,a2+InpRR*risk); return; }
      }
   }
   if((closeH1<emaH) && RecentBreakDown() && (hi1>=emaL) && (c1<o1)&&(c1<emaL)&&(c1<l2)){
      if(!d1dn){ g_cBias++; }
      else {
         double sl=MathMax(hi1,h2)+buf; double b2=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-b2;
         if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenSell(sl,b2-InpRR*risk); }
      }
   }
}
//+------------------------------------------------------------------+

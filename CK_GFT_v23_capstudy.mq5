//+------------------------------------------------------------------+
//|  CK_GFT_v23_capstudy.mq5 — INSTRUMENTED clone of v23_live.        |
//|  IDENTICAL trading logic (byte-for-byte decisions) to v23_live.   |
//|  Adds ONLY telemetry: per-trade uncapped vs actual lot, capped    |
//|  flag, intended risk $, actual risk $, profit, exit_R. Writes     |
//|  ck_v23_capstudy.csv in OnTester. NO decision code is changed —   |
//|  this is a measurement build for the MaxLot-0.09 saturation study.|
//+------------------------------------------------------------------+
#property copyright "CK GFT v23 capstudy"
#property version   "23.31c"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic            = 20260716;
input double InpRiskPercent      = 1.7;
input double InpRR               = 3.0;
input double InpMaxLot           = 0.09;
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

int      hEmaHTF,hEmaLTF,hAtr;
datetime lastBarTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_oneR_money=0;
int      g_tradesToday=0; bool g_beActivated=false;
int      g_cSpread=0, g_cSpreadDiv=0, g_cSubMin=0, g_cReject=0;
string   GK_DAY, GK_BAL, GK_TRD;

// ---- telemetry (measurement only; does NOT affect any decision) ----
double   g_lastUncapped=0; bool g_lastCapped=false; double g_lastRiskMoney=0;
#define  MAXT 6000
long     t_pid[MAXT]; datetime t_etime[MAXT]; double t_unc[MAXT]; double t_act[MAXT];
int      t_cap[MAXT]; double t_rm[MAXT]; double t_ard[MAXT]; int t_n=0;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   hEmaHTF=iMA(_Symbol,InpHTF,InpTrendEMA,0,MODE_EMA,PRICE_CLOSE);
   hEmaLTF=iMA(_Symbol,PERIOD_CURRENT,InpEntryEMA,0,MODE_EMA,PRICE_CLOSE);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   if(hEmaHTF==INVALID_HANDLE||hEmaLTF==INVALID_HANDLE||hAtr==INVALID_HANDLE)return(INIT_FAILED);
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_DAY="v23l_day_"+scope; GK_BAL="v23l_bal_"+scope; GK_TRD="v23l_trd_"+scope;
   LoadOrResetDaily();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hEmaHTF!=INVALID_HANDLE)IndicatorRelease(hEmaHTF); if(hEmaLTF!=INVALID_HANDLE)IndicatorRelease(hEmaLTF); if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
double EmaHTF(int s){ double b[]; if(CopyBuffer(hEmaHTF,0,s,1,b)<=0)return(0); return(b[0]); }
double EmaLTF(int s){ double b[]; if(CopyBuffer(hEmaLTF,0,s,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }

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
      pl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_FEE);
   }
   return(pl/g_oneR_money);
}
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }

// IDENTICAL sizing logic; ONLY records uncapped/capped for telemetry (return value unchanged).
double LotForRisk(double riskMoney,double slDist){ if(slDist<=0)return(0); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tv<=0||ts<=0)return(0); double lpl=(slDist/ts)*tv; if(lpl<=0)return(0); double lots=riskMoney/lpl; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); double stepped=MathFloor(lots/st)*st; g_lastUncapped=stepped; g_lastCapped=false; if(stepped<mn){ g_cSubMin++; return(0); } if(stepped>InpMaxLot){ stepped=InpMaxLot; g_lastCapped=true; } return(stepped); }

bool RecentBreakUp(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int hi=iHighest(_Symbol,InpHTF,MODE_HIGH,InpBreakoutLookback,s+1); if(hi<0)continue; if(iClose(_Symbol,InpHTF,s)>iHigh(_Symbol,InpHTF,hi))return(true);} return(false); }
bool RecentBreakDown(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int lo=iLowest(_Symbol,InpHTF,MODE_LOW,InpBreakoutLookback,s+1); if(lo<0)continue; if(iClose(_Symbol,InpHTF,s)<iLow(_Symbol,InpHTF,lo))return(true);} return(false); }

bool CountIfFilled(bool sent,string tag){
   uint rc=trade.ResultRetcode();
   bool filled = sent && (rc==TRADE_RETCODE_DONE||rc==TRADE_RETCODE_DONE_PARTIAL) && trade.ResultDeal()!=0;
   if(filled){ g_tradesToday++; g_beActivated=false; GlobalVariableSet(GK_TRD,g_tradesToday); }
   else { g_cReject++; PrintFormat("[capstudy] ORDER_FAIL tag=%s sent=%s rc=%u %s",tag,(sent?"true":"false"),rc,trade.ResultRetcodeDescription()); }
   return(filled);
}
// telemetry recorder (measurement only)
void RecordEntry(double lots,double slDistPrice){
   if(t_n>=MAXT)return;
   long pid=0; if(PositionSelect(_Symbol)) pid=(long)PositionGetInteger(POSITION_IDENTIFIER);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double ard=(ts>0)? lots*(slDistPrice/ts)*tv : 0;
   t_pid[t_n]=pid; t_etime[t_n]=TimeCurrent(); t_unc[t_n]=g_lastUncapped; t_act[t_n]=lots; t_cap[t_n]=(g_lastCapped?1:0); t_rm[t_n]=g_lastRiskMoney; t_ard[t_n]=ard; t_n++;
}
void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; g_lastRiskMoney=AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0); double lots=LotForRisk(g_lastRiskMoney,risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=trade.Buy(lots,_Symbol,0,sl,tp); if(CountIfFilled(s,"BUY")) RecordEntry(lots,risk); }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; g_lastRiskMoney=AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0); double lots=LotForRisk(g_lastRiskMoney,risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=trade.Sell(lots,_Symbol,0,sl,tp); if(CountIfFilled(s,"SELL")) RecordEntry(lots,risk); }
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
   int capped=0; for(int i=0;i<t_n;i++) capped+=t_cap[i];
   PrintFormat("[capstudy] risk=%.2f%% entries=%d capped=%d (%.1f%%) subMinSkips=%d orderRejects=%d",
      InpRiskPercent,t_n,capped,(t_n>0?100.0*capped/t_n:0),g_cSubMin,g_cReject);
   int h=FileOpen("ck_v23_capstudy.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"entry_time","exit_time","uncapped_lot","actual_lot","was_capped","risk_money","actual_risk_usd","profit","exit_R");
      HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong xk=HistoryDealGetTicket(i); if(xk==0)continue;
         if(HistoryDealGetString(xk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(xk,DEAL_MAGIC)!=InpMagic)continue;
         if(HistoryDealGetInteger(xk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         long posid=(long)HistoryDealGetInteger(xk,DEAL_POSITION_ID);
         datetime xt=(datetime)HistoryDealGetInteger(xk,DEAL_TIME);
         double profit=HistoryDealGetDouble(xk,DEAL_PROFIT)+HistoryDealGetDouble(xk,DEAL_SWAP)+HistoryDealGetDouble(xk,DEAL_COMMISSION)+HistoryDealGetDouble(xk,DEAL_FEE);
         int idx=-1; for(int j=0;j<t_n;j++){ if(t_pid[j]==posid){ idx=j; break; } }
         if(idx<0){ FileWrite(h,"?",TimeToString(xt,TIME_DATE|TIME_MINUTES),"0","0","?","0","0",DoubleToString(profit,2),"?"); continue; }
         double R=(t_ard[idx]>0)? profit/t_ard[idx] : 0;
         FileWrite(h,TimeToString(t_etime[idx],TIME_DATE|TIME_MINUTES),TimeToString(xt,TIME_DATE|TIME_MINUTES),
            DoubleToString(t_unc[idx],2),DoubleToString(t_act[idx],2),IntegerToString(t_cap[idx]),
            DoubleToString(t_rm[idx],2),DoubleToString(t_ard[idx],2),DoubleToString(profit,2),DoubleToString(R,2));
      }
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
   bool newReject=(curPts>maxPts); bool oldReject=(curPts>60);
   if(oldReject!=newReject) g_cSpreadDiv++;
   if(newReject){ g_cSpread++; return; }
   if(!TradingAllowed())return;
   double atr=ATR(); if(atr<=0)return; double buf=InpSLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1),o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,2),l2=iLow(_Symbol,PERIOD_CURRENT,2);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1),hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaL=EmaLTF(1),closeH1=iClose(_Symbol,InpHTF,1),emaH=EmaHTF(1);
   if((closeH1>emaH) && RecentBreakUp() && (lo1<=emaL) && (c1>o1)&&(c1>emaL)&&(c1>h2)){
      double sl=MathMin(lo1,l2)-buf; double a2=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=a2-sl;
      if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenBuy(sl,a2+InpRR*risk); return; }
   }
   if((closeH1<emaH) && RecentBreakDown() && (hi1>=emaL) && (c1<o1)&&(c1<emaL)&&(c1<l2)){
      double sl=MathMax(hi1,h2)+buf; double b2=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-b2;
      if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenSell(sl,b2-InpRR*risk); }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|  CK_GOLD_PRO_OFFSET.mq5 — FIX09 logic + PULLBACK LIMIT ENTRY.      |
//|  Instead of market entry, places a limit at an offset better price |
//|  (BUY = Ask-offset, SELL = Bid+offset) to avoid the initial stop-  |
//|  hunt wick. SL/TP kept at FIX09 structural levels. Pending cancels  |
//|  if unfilled within InpPendingBars. Fixed 0.09 lot. NOT an edit of  |
//|  FIX09 (separate file). Primary declared offset = 4.0 ($4).        |
//+------------------------------------------------------------------+
#property copyright "CK GOLD PRO OFFSET"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic            = 20260716;
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
input double InpEntryOffset      = 4.0;   // pullback offset in price ($). BUY: Ask-offset; SELL: Bid+offset
input int    InpPendingBars      = 3;     // cancel unfilled limit after N bars

int      hEmaHTF,hEmaLTF,hAtr;
datetime lastBarTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_oneR_money=0;
int      g_tradesToday=0; bool g_beActivated=false; datetime g_beTryBar=0;
long     g_lastPosId=-1; datetime g_pendTime=0;
int      g_cSpread=0,g_cReject=0,g_cCancel=0;
string   GK_DAY, GK_BAL, GK_TRD;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hEmaHTF=iMA(_Symbol,InpHTF,InpTrendEMA,0,MODE_EMA,PRICE_CLOSE);
   hEmaLTF=iMA(_Symbol,PERIOD_CURRENT,InpEntryEMA,0,MODE_EMA,PRICE_CLOSE);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   if(hEmaHTF==INVALID_HANDLE||hEmaLTF==INVALID_HANDLE||hAtr==INVALID_HANDLE)return(INIT_FAILED);
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_DAY="ckoff_day_"+scope; GK_BAL="ckoff_bal_"+scope; GK_TRD="ckoff_trd_"+scope;
   LoadOrResetDaily();
   PrintFormat("[OFFSET] offset=%.2f pendingBars=%d fixedLot=%.2f",InpEntryOffset,InpPendingBars,FixedLot());
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hEmaHTF!=INVALID_HANDLE)IndicatorRelease(hEmaHTF); if(hEmaLTF!=INVALID_HANDLE)IndicatorRelease(hEmaLTF); if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
double EmaHTF(int s){ double b[]; if(CopyBuffer(hEmaHTF,0,s,1,b)<=0)return(0); return(b[0]); }
double EmaLTF(int s){ double b[]; if(CopyBuffer(hEmaLTF,0,s,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }
double FixedLot(){ double lot=InpFixedLot; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); if(st>0)lot=MathRound(lot/st)*st; if(lot<mn)lot=mn; if(lot>InpMaxLot)lot=InpMaxLot; if(mx>0&&lot>mx)lot=mx; return(lot); }

void LoadOrResetDaily(){ datetime today=iTime(_Symbol,PERIOD_D1,0); datetime gday=(datetime)GlobalVariableGet(GK_DAY);
   if(gday==today&&today>0){ g_dayStart=today; g_dayStartBal=GlobalVariableGet(GK_BAL); g_tradesToday=(int)GlobalVariableGet(GK_TRD);}
   else { g_dayStart=today; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)today); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0);} g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); }
void NewDay(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)g_dayStart); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }
double RealizedRToday(){ if(g_oneR_money<=0)return(0); double pl=0; if(!HistorySelect(g_dayStart,TimeCurrent()))return(0); int td=HistoryDealsTotal();
   for(int i=0;i<td;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; pl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_FEE);} return(pl/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
long MyPositionId(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol) return((long)PositionGetInteger(POSITION_IDENTIFIER)); } return(-1); }
int MyPendings(){ int c=0; for(int i=OrdersTotal()-1;i>=0;i--){ ulong tk=OrderGetTicket(i); if(tk==0)continue; if(OrderGetInteger(ORDER_MAGIC)!=InpMagic)continue; if(OrderGetString(ORDER_SYMBOL)!=_Symbol)continue; long ty=OrderGetInteger(ORDER_TYPE); if(ty==ORDER_TYPE_BUY_LIMIT||ty==ORDER_TYPE_SELL_LIMIT)c++; } return(c); }
void DeleteMyPendings(){ for(int i=OrdersTotal()-1;i>=0;i--){ ulong tk=OrderGetTicket(i); if(tk==0)continue; if(OrderGetInteger(ORDER_MAGIC)!=InpMagic)continue; if(OrderGetString(ORDER_SYMBOL)!=_Symbol)continue; long ty=OrderGetInteger(ORDER_TYPE); if(ty==ORDER_TYPE_BUY_LIMIT||ty==ORDER_TYPE_SELL_LIMIT) trade.OrderDelete(tk); } }

bool RecentBreakUp(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int hi=iHighest(_Symbol,InpHTF,MODE_HIGH,InpBreakoutLookback,s+1); if(hi<0)continue; if(iClose(_Symbol,InpHTF,s)>iHigh(_Symbol,InpHTF,hi))return(true);} return(false); }
bool RecentBreakDown(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int lo=iLowest(_Symbol,InpHTF,MODE_LOW,InpBreakoutLookback,s+1); if(lo<0)continue; if(iClose(_Symbol,InpHTF,s)<iLow(_Symbol,InpHTF,lo))return(true);} return(false); }

void ManageTrade(){
   if(!InpUseBreakEven)return; if(MyPositions()==0){ g_beActivated=false; return; }
   ulong tk=GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_beActivated)return; datetime cb=iTime(_Symbol,PERIOD_CURRENT,0); if(g_beTryBar==cb)return; double prog=0;
   if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(tp-open<=0)return; prog=(bid-open)/(tp-open); if(prog>=InpBEProgress&&sl<open){ g_beTryBar=cb; if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
   else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(open-tp<=0)return; prog=(open-ask)/(open-tp); if(prog>=InpBEProgress&&sl>open){ g_beTryBar=cb; if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
}
double OnTester(){
   PrintFormat("[OFFSET] offset=%.2f spreadFiltered=%d pendingCancelled=%d orderRejects=%d",InpEntryOffset,g_cSpread,g_cCancel,g_cReject);
   int h=FileOpen("ck_offset_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit"); HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); } FileClose(h); }
   return(0.0);
}
void OnTick(){
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) NewDay();
   // count a newly-filled position (from a limit) once
   long pid=MyPositionId();
   if(pid!=-1 && pid!=g_lastPosId){ g_tradesToday++; GlobalVariableSet(GK_TRD,g_tradesToday); g_lastPosId=pid; g_beActivated=false; }
   ManageTrade();
   if(!IsNewBar())return;
   // cancel stale pending
   if(MyPendings()>0){ if(TimeCurrent()-g_pendTime >= InpPendingBars*PeriodSeconds(PERIOD_CURRENT)){ DeleteMyPendings(); g_cCancel++; } }
   if(MyPositions()>0 || MyPendings()>0) return;   // one order in flight
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD); long maxPts=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ g_cSpread++; return; }
   if(!TradingAllowed())return;
   double atr=ATR(); if(atr<=0)return; double buf=InpSLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1),o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,2),l2=iLow(_Symbol,PERIOD_CURRENT,2);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1),hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaL=EmaLTF(1),closeH1=iClose(_Symbol,InpHTF,1),emaH=EmaHTF(1);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if((closeH1>emaH) && RecentBreakUp() && (lo1<=emaL) && (c1>o1)&&(c1>emaL)&&(c1>h2)){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double sl=MathMin(lo1,l2)-buf; double mrisk=ask-sl;
      if(mrisk>0 && mrisk<=InpMaxSL_ATR*atr){
         double tp=ask+InpRR*mrisk; double limit=ask-InpEntryOffset;
         if(limit>sl){ bool s=trade.BuyLimit(FixedLot(),NormalizeDouble(limit,dg),_Symbol,NormalizeDouble(sl,dg),NormalizeDouble(tp,dg),ORDER_TIME_GTC,0); if(s)g_pendTime=iTime(_Symbol,PERIOD_CURRENT,0); else g_cReject++; }
      }
      return;
   }
   if((closeH1<emaH) && RecentBreakDown() && (hi1>=emaL) && (c1<o1)&&(c1<emaL)&&(c1<l2)){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double sl=MathMax(hi1,h2)+buf; double mrisk=sl-bid;
      if(mrisk>0 && mrisk<=InpMaxSL_ATR*atr){
         double tp=bid-InpRR*mrisk; double limit=bid+InpEntryOffset;
         if(limit<sl){ bool s=trade.SellLimit(FixedLot(),NormalizeDouble(limit,dg),_Symbol,NormalizeDouble(sl,dg),NormalizeDouble(tp,dg),ORDER_TIME_GTC,0); if(s)g_pendTime=iTime(_Symbol,PERIOD_CURRENT,0); else g_cReject++; }
      }
   }
}
//+------------------------------------------------------------------+

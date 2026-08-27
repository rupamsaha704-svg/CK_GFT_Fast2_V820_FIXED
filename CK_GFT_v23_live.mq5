//+------------------------------------------------------------------+
//|  CK_GFT_v23_live.mq5 — EXECUTION-HARDENING revision of v23.       |
//|  Strategy logic (entries, HTF EMA200, breakout, EMA20 pullback,  |
//|  SL construction, MaxSL_ATR 2.5, RR 3.0, MaxLot 0.09, BE@+1.5R,   |
//|  ATR shift-0, 3 trades/day, daily +/-R limits) is UNCHANGED.     |
//|                                                                    |
//|  6 live-safety fixes (boss-frozen scope; v2 = review-hardened):   |
//|   1 Spread: absolute price (Ask-Bid) vs InpMaxSpreadPrice (0.60), |
//|     digit-independent. A/B criterion = spreadDivergence (old raw  |
//|     >60pts rule vs new rule disagree), NOT raw filtered count.    |
//|   2 Order result verified: DONE / DONE_PARTIAL + ResultDeal()!=0  |
//|     before counting (PLACED is for pendings, not our market ord). |
//|   3 SetTypeFillingBySymbol for broker-correct filling.            |
//|   4 Sub-minimum calculated lot -> SKIP (never floor to min).      |
//|   5 Daily state persisted across restart/recompile (GlobalVars),  |
//|     key scoped by account-login + symbol + magic (collision-safe).|
//|   6 Daily realised R from THIS magic+symbol deals only, summing   |
//|     PROFIT+SWAP+COMMISSION+FEE over ALL deals (entry+exit) so it  |
//|     matches baseline balance-delta incl. entry-side costs.        |
//|  Also dumps ck_v23live_regression_detail.csv (position_id,        |
//|  entry/exit time, side, volume, prices, SL, TP, net) for full     |
//|  strategy-identity A/B vs baseline.                               |
//+------------------------------------------------------------------+
#property copyright "CK GFT v23 live"
#property version   "23.31"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic            = 20260716;
input double InpRiskPercent      = 0.5;
input double InpRR               = 3.0;
input double InpMaxLot           = 0.09;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input double InpMaxSpreadPrice   = 0.60;   // FIX1: absolute $ spread (was 60 raw points)
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
// safety counters (logged for A/B divergence tracing)
int      g_cSpread=0, g_cSpreadDiv=0, g_cSubMin=0, g_cReject=0;
string   GK_DAY, GK_BAL, GK_TRD;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);            // FIX3
   hEmaHTF=iMA(_Symbol,InpHTF,InpTrendEMA,0,MODE_EMA,PRICE_CLOSE);
   hEmaLTF=iMA(_Symbol,PERIOD_CURRENT,InpEntryEMA,0,MODE_EMA,PRICE_CLOSE);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   if(hEmaHTF==INVALID_HANDLE||hEmaLTF==INVALID_HANDLE||hAtr==INVALID_HANDLE)return(INIT_FAILED);
   // FIX5: collision-safe key = account-login + symbol + magic
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_DAY="v23l_day_"+scope; GK_BAL="v23l_bal_"+scope; GK_TRD="v23l_trd_"+scope;
   LoadOrResetDaily();
   // FIX1 diagnostic: proves 60*point == InpMaxSpreadPrice on the validated broker
   PrintFormat("[v23live] digits=%d point=%.5f old60Price=%.5f newMaxPrice=%.5f maxSpreadPts=%d (baseline=60)",
      (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS),
      SymbolInfoDouble(_Symbol,SYMBOL_POINT),
      60.0*SymbolInfoDouble(_Symbol,SYMBOL_POINT),
      InpMaxSpreadPrice,
      (int)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT)));
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hEmaHTF!=INVALID_HANDLE)IndicatorRelease(hEmaHTF); if(hEmaLTF!=INVALID_HANDLE)IndicatorRelease(hEmaLTF); if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }   // shift-0 kept (unchanged)
double EmaHTF(int s){ double b[]; if(CopyBuffer(hEmaHTF,0,s,1,b)<=0)return(0); return(b[0]); }
double EmaLTF(int s){ double b[]; if(CopyBuffer(hEmaLTF,0,s,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }

// FIX5: persist daily state across restart/recompile (tester single-run => behaves as normal reset)
void LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0);
   datetime gday=(datetime)GlobalVariableGet(GK_DAY);
   if(gday==today && today>0){
      g_dayStart=today;
      g_dayStartBal=GlobalVariableGet(GK_BAL);
      g_tradesToday=(int)GlobalVariableGet(GK_TRD);
   } else {
      g_dayStart=today; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0;
      GlobalVariableSet(GK_DAY,(double)today); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0);
   }
   g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0);
}
void NewDay(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0;
   GlobalVariableSet(GK_DAY,(double)g_dayStart); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }

// FIX6: daily realised R from THIS magic+symbol deals only (entry+exit, incl FEE) => baseline balance-delta equivalent
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

// FIX4: sub-minimum calculated lot -> skip (return 0), never floor to min
double LotForRisk(double riskMoney,double slDist){ if(slDist<=0)return(0); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tv<=0||ts<=0)return(0); double lpl=(slDist/ts)*tv; if(lpl<=0)return(0); double lots=riskMoney/lpl; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); double stepped=MathFloor(lots/st)*st; if(stepped<mn){ g_cSubMin++; return(0); } if(stepped>InpMaxLot)stepped=InpMaxLot; return(stepped); }

bool RecentBreakUp(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int hi=iHighest(_Symbol,InpHTF,MODE_HIGH,InpBreakoutLookback,s+1); if(hi<0)continue; if(iClose(_Symbol,InpHTF,s)>iHigh(_Symbol,InpHTF,hi))return(true);} return(false); }
bool RecentBreakDown(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int lo=iLowest(_Symbol,InpHTF,MODE_LOW,InpBreakoutLookback,s+1); if(lo<0)continue; if(iClose(_Symbol,InpHTF,s)<iLow(_Symbol,InpHTF,lo))return(true);} return(false); }

// FIX2: verify actual fill (DONE/DONE_PARTIAL + a real deal). PLACED is for pendings, not our market order.
void CountIfFilled(bool sent,string tag){
   uint rc=trade.ResultRetcode();
   bool filled = sent && (rc==TRADE_RETCODE_DONE||rc==TRADE_RETCODE_DONE_PARTIAL) && trade.ResultDeal()!=0;
   if(filled){ g_tradesToday++; g_beActivated=false; GlobalVariableSet(GK_TRD,g_tradesToday); }
   else { g_cReject++; PrintFormat("[v23live] %s NOT filled rc=%u deal=%I64u",tag,rc,trade.ResultDeal()); }
}
void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=trade.Buy(lots,_Symbol,0,sl,tp); CountIfFilled(s,"BUY"); }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=trade.Sell(lots,_Symbol,0,sl,tp); CountIfFilled(s,"SELL"); }
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
   PrintFormat("[v23live] safety triggers: spreadFiltered=%d spreadDivergence=%d subMinSkips=%d orderRejects=%d",
      g_cSpread,g_cSpreadDiv,g_cSubMin,g_cReject);
   // (a) baseline-compatible two-column dump (unchanged format)
   int h=FileOpen("ck_v23live_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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
   // (b) FIX6-review: full strategy-identity detail (entry/exit/side/volume/prices/SL/TP/net)
   int hd=FileOpen("ck_v23live_regression_detail.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(hd!=INVALID_HANDLE){
      FileWrite(hd,"position_id","entry_time","exit_time","side","volume","entry_price","exit_price","sl","tp","net_profit");
      HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal(); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      for(int i=0;i<total;i++){ ulong xk=HistoryDealGetTicket(i); if(xk==0)continue;
         if(HistoryDealGetString(xk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(xk,DEAL_MAGIC)!=InpMagic)continue;
         if(HistoryDealGetInteger(xk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         long posid=(long)HistoryDealGetInteger(xk,DEAL_POSITION_ID);
         datetime xt=(datetime)HistoryDealGetInteger(xk,DEAL_TIME);
         double xprice=HistoryDealGetDouble(xk,DEAL_PRICE);
         double net=HistoryDealGetDouble(xk,DEAL_PROFIT)+HistoryDealGetDouble(xk,DEAL_SWAP)
                   +HistoryDealGetDouble(xk,DEAL_COMMISSION)+HistoryDealGetDouble(xk,DEAL_FEE);
         datetime et=0; double vol=0,eprice=0,sl=0,tp=0; string side="?";
         for(int j=0;j<total;j++){ ulong ik=HistoryDealGetTicket(j); if(ik==0)continue;
            if((long)HistoryDealGetInteger(ik,DEAL_POSITION_ID)!=posid)continue;
            if(HistoryDealGetInteger(ik,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
            et=(datetime)HistoryDealGetInteger(ik,DEAL_TIME);
            vol=HistoryDealGetDouble(ik,DEAL_VOLUME);
            eprice=HistoryDealGetDouble(ik,DEAL_PRICE);
            side=(HistoryDealGetInteger(ik,DEAL_TYPE)==DEAL_TYPE_BUY)?"BUY":"SELL";
            ulong ord=(ulong)HistoryDealGetInteger(ik,DEAL_ORDER);
            if(HistoryOrderSelect(ord)){ sl=HistoryOrderGetDouble(ord,ORDER_SL); tp=HistoryOrderGetDouble(ord,ORDER_TP); }
            break;
         }
         FileWrite(hd,IntegerToString(posid),TimeToString(et,TIME_DATE|TIME_MINUTES),TimeToString(xt,TIME_DATE|TIME_MINUTES),
            side,DoubleToString(vol,2),DoubleToString(eprice,dg),DoubleToString(xprice,dg),
            DoubleToString(sl,dg),DoubleToString(tp,dg),DoubleToString(net,2));
      }
      FileClose(hd);
   }
   return(0.0);
}
void OnTick(){
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) NewDay();
   ManageTrade();
   if(!IsNewBar())return;
   if(MyPositions()>0)return;
   // FIX1: portable spread — derive point-count from the absolute $ threshold, then compare the
   // SAME integer SYMBOL_SPREAD the baseline used. Identical on this broker (0.60/0.01=60pts),
   // correct on 3/5-digit brokers (0.60/0.001=600pts). No float-boundary divergence.
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   bool newReject=(curPts>maxPts);
   bool oldReject=(curPts>60);                                        // baseline v23_ts raw-point rule
   if(oldReject!=newReject) g_cSpreadDiv++;                           // A/B criterion (expect 0 here)
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

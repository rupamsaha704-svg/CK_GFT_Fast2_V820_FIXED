//+------------------------------------------------------------------+
//|                                              CK_POC_VA_v1.mq5     |
//|  CANDIDATE: Volume-Profile POC / Value-Area mean-reversion (XAU). |
//|                                                                    |
//|  HONEST NOTE: MT5 XAUUSD "volume" is TICK volume (approximation), |
//|  not true exchange volume. This is a research approximation, not  |
//|  real order-flow. Testable + backtestable (unlike DOM/footprint). |
//|                                                                    |
//|  Logic (mean-reversion toward high-volume fair price):            |
//|   Build a tick-volume profile over the last InpProfileBars bars.  |
//|   POC = highest-volume price bin. Value Area = smallest band       |
//|   around POC holding InpVAPct% of volume (VAH/VAL).               |
//|   LONG  when close[1] <= VAL and bar is bullish reversal (c>o);    |
//|   SHORT when close[1] >= VAH and bar is bearish reversal (c<o).    |
//|   TP = POC (fair price). SL = beyond signal-bar extreme.          |
//|  Purpose: a strategy that should earn in RANGE regimes (where the |
//|  v23 trend agent bleeds) -> if uncorrelated, cuts portfolio DD.   |
//|  HARD MaxLot 0.09. Dumps time,profit to ck_poc_trades.csv.        |
//+------------------------------------------------------------------+
#property copyright "CK POC ValueArea v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE / RISK ===
input long   InpMagic            = 20261010;
input double InpRiskPercent      = 0.5;
input double InpMaxLot           = 0.09;   // HARD CAP
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input int    InpMaxSpreadPoints  = 60;
//=== SESSION GATE (structural filter; hours pinned, not tuned) ===
input bool   InpUseSession       = true;   // restrict entries to a server-hour window
input int    InpSessStartHour    = 13;     // window start (server hour, inclusive)
input int    InpSessEndHour      = 24;     // window end   (server hour, exclusive)
//=== VOLUME PROFILE ===
input int    InpProfileBars      = 96;     // lookback (M15 96 = ~1 day)
input int    InpBins             = 48;     // price buckets
input double InpVAPct            = 70.0;   // value-area % of volume
input double InpSLBufferATR      = 0.30;
input double InpMaxSL_ATR        = 3.0;
input double InpMinTP_ATR        = 0.5;    // require POC at least this far

int      hAtr;
datetime lastBarTime=0, g_dayStart=0;
double   g_dayStartBal=0, g_oneR_money=0;
int      g_tradesToday=0;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   if(hAtr==INVALID_HANDLE)return(INIT_FAILED);
   ResetDaily(); return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }
double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }
bool InSession(){ if(!InpUseSession) return(true); MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int h=dt.hour;
   if(InpSessStartHour<=InpSessEndHour) return(h>=InpSessStartHour && h<InpSessEndHour);
   return(h>=InpSessStartHour || h<InpSessEndHour); }  // supports wrap-around windows
void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; }
double RealizedRToday(){ if(g_oneR_money<=0)return(0); return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
double LotForRisk(double riskMoney,double slDist){ if(slDist<=0)return(0); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tv<=0||ts<=0)return(0); double lpl=(slDist/ts)*tv; if(lpl<=0)return(0); double lots=riskMoney/lpl; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); lots=MathFloor(lots/st)*st; if(lots<mn)lots=mn; if(lots>InpMaxLot)lots=InpMaxLot; return(lots); }
void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Buy(lots,_Symbol,0,sl,tp)) g_tradesToday++; }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Sell(lots,_Symbol,0,sl,tp)) g_tradesToday++; }

// Build tick-volume profile over bars [1..InpProfileBars]; return POC/VAH/VAL
bool BuildProfile(double &poc,double &vah,double &val)
{
   int N=InpProfileBars;
   double hi[]; double lo[]; long tv[];
   ArraySetAsSeries(hi,true); ArraySetAsSeries(lo,true); ArraySetAsSeries(tv,true);
   if(CopyHigh(_Symbol,PERIOD_CURRENT,1,N,hi)<N) return(false);
   if(CopyLow(_Symbol,PERIOD_CURRENT,1,N,lo)<N) return(false);
   if(CopyTickVolume(_Symbol,PERIOD_CURRENT,1,N,tv)<N) return(false);
   double cl[]; ArraySetAsSeries(cl,true); if(CopyClose(_Symbol,PERIOD_CURRENT,1,N,cl)<N) return(false);
   double top=hi[0], bot=lo[0];
   for(int i=0;i<N;i++){ if(hi[i]>top)top=hi[i]; if(lo[i]<bot)bot=lo[i]; }
   double binw=(top-bot)/InpBins; if(binw<=0) return(false);
   double vol[]; ArrayResize(vol,InpBins); ArrayInitialize(vol,0.0);
   double total=0;
   for(int i=0;i<N;i++){
      double tp=(hi[i]+lo[i]+cl[i])/3.0;
      int b=(int)((tp-bot)/binw); if(b<0)b=0; if(b>=InpBins)b=InpBins-1;
      vol[b]+=(double)tv[i]; total+=(double)tv[i];
   }
   if(total<=0) return(false);
   int pocb=0; double mx=vol[0];
   for(int b=1;b<InpBins;b++){ if(vol[b]>mx){mx=vol[b];pocb=b;} }
   poc=bot+(pocb+0.5)*binw;
   // expand value area from POC until VAPct% covered
   int li=pocb, ri=pocb; double acc=vol[pocb];
   double target=InpVAPct/100.0*total;
   while(acc<target && (li>0 || ri<InpBins-1)){
      double L=(li>0)?vol[li-1]:-1.0;
      double R=(ri<InpBins-1)?vol[ri+1]:-1.0;
      if(R>=L){ ri++; acc+=vol[ri]; } else { li--; acc+=vol[li]; }
   }
   vah=bot+(ri+1)*binw; val=bot+li*binw;
   return(true);
}

double OnTester(){
   int h=FileOpen("ck_poc_sess_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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
   if(!IsNewBar())return;
   if(MyPositions()>0)return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints)return;
   if(!InSession())return;   // structural session gate (entries only inside the pinned window)
   if(!TradingAllowed())return;
   double atr=ATR(); if(atr<=0)return;
   double poc,vah,val; if(!BuildProfile(poc,vah,val))return;
   double buf=InpSLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1),o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double l1=iLow(_Symbol,PERIOD_CURRENT,1),h1=iHigh(_Symbol,PERIOD_CURRENT,1);

   // LONG: below value area low + bullish reversal, target POC above
   if(c1<=val && c1>o1){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=l1-buf; double risk=ask-sl; double tp=poc;
      if(risk>0 && risk<=InpMaxSL_ATR*atr && (tp-ask)>=InpMinTP_ATR*atr){ OpenBuy(sl,tp); return; }
   }
   // SHORT: above value area high + bearish reversal, target POC below
   if(c1>=vah && c1<o1){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=h1+buf; double risk=sl-bid; double tp=poc;
      if(risk>0 && risk<=InpMaxSL_ATR*atr && (bid-tp)>=InpMinTP_ATR*atr){ OpenSell(sl,tp); }
   }
}
//+------------------------------------------------------------------+

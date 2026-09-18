//+------------------------------------------------------------------+
//|  CK_CRYPTO_BOOK_v3.mq5                                            |
//|  UNIFIED daily TIME-SERIES-MOMENTUM book in ONE EA.               |
//|  Trades BTC + ETH + NQ together from a single chart, each with    |
//|  the SAME validated rule as CK_CRYPTO_TSMOM_v2, internally         |
//|  risk-weighted (~70/30 crypto/NQ), inverse-vol sized, vol-target, |
//|  vol-filter, daily rebalance (netting), OnTester -> trades CSV.    |
//|                                                                   |
//|  This is the "v3" packaging of the validated book (Python OOS     |
//|  Sharpe ~0.66, DD ~8%, positive every year 2018-2026). Attach     |
//|  ONCE on any chart; it manages all 3 instruments by symbol.       |
//|  Symbols/weights are inputs (rename to your broker's symbols).    |
//+------------------------------------------------------------------+
#property copyright "CK CRYPTO BOOK v3"
#property version   "3.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic          = 20260913;
input string InpSymbols        = "BTCUSD,ETHUSD,NAS100"; // instruments (comma) - rename to broker's
input string InpWeights        = "1.0,1.0,0.85";         // per-sleeve risk weight (BTC,ETH,NQ ~70/30)
input int    InpL1             = 20;
input int    InpL2             = 60;
input int    InpL3             = 120;
input int    InpL4             = 250;
input int    InpVolWindow      = 60;     // short vol window (sizing)
input double InpTargetVolAnnual= 0.05;   // per-sleeve annual vol target (~10% book over 3)
input double InpMaxLeverage    = 3.0;
input double InpMaxLot         = 100.0;
input bool   InpAllowLong      = true;
input bool   InpAllowShort     = true;
input bool   InpVolFilter      = true;   // cut exposure in high-vol regime
input int    InpVolRefWindow   = 252;    // long vol window (regime baseline)
input double InpVolFilterFloor = 0.5;    // min exposure multiplier in high vol
input double InpDeadBandLots   = 0.0;

ENUM_TIMEFRAMES TF = PERIOD_D1;

string   g_sym[];
double   g_wt[];
datetime g_lastBar[];
int      g_n = 0;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(100);
   trade.LogLevel(LOG_LEVEL_NO);

   string syms[]; string wts[];
   int ns = StringSplit(InpSymbols, (ushort)',', syms);
   int nw = StringSplit(InpWeights, (ushort)',', wts);
   if(ns <= 0){ Print("BOOKv3: no symbols parsed"); return(INIT_FAILED); }

   ArrayResize(g_sym, ns); ArrayResize(g_wt, ns); ArrayResize(g_lastBar, ns); g_n = 0;
   for(int i=0;i<ns;i++)
   {
      string s = syms[i]; StringTrimLeft(s); StringTrimRight(s);
      if(s=="") continue;
      double w = (i<nw)? StringToDouble(wts[i]) : 1.0;
      if(!SymbolSelect(s, true)){ Print("BOOKv3: cannot select ", s, " (rename InpSymbols to broker names)"); continue; }
      trade.SetTypeFillingBySymbol(s);
      g_sym[g_n]=s; g_wt[g_n]=w; g_lastBar[g_n]=0; g_n++;
   }
   ArrayResize(g_sym,g_n); ArrayResize(g_wt,g_n); ArrayResize(g_lastBar,g_n);
   if(g_n==0){ Print("BOOKv3: no valid symbols available on this account"); return(INIT_FAILED); }
   PrintFormat("BOOKv3 init: %d instruments active", g_n);
   return(INIT_SUCCEEDED);
}

double Signal(string sym)
{
   int lbs[4]; lbs[0]=InpL1; lbs[1]=InpL2; lbs[2]=InpL3; lbs[3]=InpL4;
   double c1=iClose(sym,TF,1); if(c1<=0) return(0);
   double s=0; int n=0;
   for(int i=0;i<4;i++){ int L=lbs[i]; if(L<=0) continue; double cL=iClose(sym,TF,1+L); if(cL<=0) continue;
      s += (c1>cL?1.0:(c1<cL?-1.0:0.0)); n++; }
   return(n==0?0.0:s/n);
}

double VolN(string sym,int N)
{
   if(N<5) N=5; double mean=0.0; double r[]; ArrayResize(r,N);
   for(int i=0;i<N;i++){ double c=iClose(sym,TF,1+i), cp=iClose(sym,TF,2+i);
      if(c<=0||cp<=0) return(0); r[i]=c/cp-1.0; mean+=r[i]; }
   mean/=N; double v=0; for(int i=0;i<N;i++) v+=(r[i]-mean)*(r[i]-mean); v/=(N-1);
   return(MathSqrt(v));
}

double MyNetVolume(string sym)
{
   double vol=0;
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic||PositionGetString(POSITION_SYMBOL)!=sym)continue;
      double v=PositionGetDouble(POSITION_VOLUME);
      vol += (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY? v : -v); }
   return(vol);
}

void RebalanceSymbol(string sym,double weight)
{
   int maxL=MathMax(MathMax(InpL1,InpL2),MathMax(InpL3,InpL4));
   if(Bars(sym,TF) < maxL+InpVolRefWindow+5) return;
   double sig=Signal(sym);
   if(!InpAllowLong  && sig>0) sig=0;
   if(!InpAllowShort && sig<0) sig=0;
   double vol=VolN(sym,InpVolWindow); if(vol<=0) return;
   double w=sig*(InpTargetVolAnnual/MathSqrt(252.0)/vol);
   if(InpVolFilter){
      double refv=VolN(sym,InpVolRefWindow);
      double mult=(vol>0 && refv>0)? MathMin(1.0, refv/vol) : 1.0;
      if(mult<InpVolFilterFloor) mult=InpVolFilterFloor;
      w*=mult;
   }
   if(w> InpMaxLeverage) w= InpMaxLeverage;
   if(w<-InpMaxLeverage) w=-InpMaxLeverage;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double price=SymbolInfoDouble(sym,SYMBOL_BID); if(price<=0) return;
   double contract=SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE); if(contract<=0) contract=1.0;
   double step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP); if(step<=0) step=0.01;
   double mn=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double targetLots=w*equity*weight/(price*contract);
   double dir=(targetLots>=0?1.0:-1.0);
   double absL=MathFloor(MathAbs(targetLots)/step)*step;
   if(absL>InpMaxLot) absL=InpMaxLot; if(mx>0 && absL>mx) absL=mx;
   double tgt=dir*absL; if(absL<mn) tgt=0.0;
   double cur=MyNetVolume(sym); double diff=tgt-cur;
   double band=(InpDeadBandLots>0?InpDeadBandLots:step);
   bool flip=(cur>0&&tgt<0)||(cur<0&&tgt>0);
   if(!flip && MathAbs(diff)<band) return;
   if(diff>0)      trade.Buy(NormalizeDouble(diff,2),sym);
   else if(diff<0) trade.Sell(NormalizeDouble(-diff,2),sym);
}

void OnTick()
{
   for(int i=0;i<g_n;i++)
   {
      datetime t=iTime(g_sym[i],TF,0); if(t<=0) continue;
      if(t==g_lastBar[i]) continue;
      g_lastBar[i]=t;
      RebalanceSymbol(g_sym[i], g_wt[i]);
   }
}

double OnTester()
{
   HistorySelect(0,TimeCurrent());
   int total=HistoryDealsTotal(); ulong ids[]; datetime ins[]; int nin=0;
   ArrayResize(ids,total); ArrayResize(ins,total);
   for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
      ids[nin]=(ulong)HistoryDealGetInteger(tk,DEAL_POSITION_ID);
      ins[nin]=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); nin++; }
   int h=FileOpen("ck_crypto_book_trades.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit");
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
         if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue;
         if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         ulong pid=(ulong)HistoryDealGetInteger(tk,DEAL_POSITION_ID); datetime et=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
         for(int j=0;j<nin;j++){ if(ids[j]==pid){ et=ins[j]; break; } }
         double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(et,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h); }
   return(0.0);
}
//+------------------------------------------------------------------+

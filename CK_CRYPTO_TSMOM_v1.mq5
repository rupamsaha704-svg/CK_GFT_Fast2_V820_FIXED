//+------------------------------------------------------------------+
//|  CK_CRYPTO_TSMOM_v1.mq5                                          |
//|  Daily long/short TIME-SERIES MOMENTUM (trend) for crypto.       |
//|  Validated in Python on 9y BTC+ETH: OOS Sharpe ~0.6-0.9, robust  |
//|  to lookback/vol-window/cost, 9/9 years +, genuine long/short.   |
//|  RULE (exactly as validated, no fitting):                        |
//|   signal = average of sign(closeD1[1]/closeD1[1+L]-1) over L set  |
//|   vol    = stdev of last N daily returns                         |
//|   weight = signal * (target_daily_vol / vol)   (inverse-vol)     |
//|   notional = weight * equity ; lots = notional/(price*contract)  |
//|   rebalance once per NEW DAILY BAR (incremental, netting).       |
//|  Run on BTCUSDx (and/or ETHUSDx on a second chart, half risk).   |
//+------------------------------------------------------------------+
#property copyright "CK CRYPTO TSMOM v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic          = 20260907;
input int    InpL1             = 20;     // lookbacks (days). 0 disables one.
input int    InpL2             = 60;
input int    InpL3             = 120;
input int    InpL4             = 250;
input int    InpVolWindow      = 60;     // daily-return vol window
input double InpTargetVolAnnual= 0.10;   // 10% annualized vol target
input double InpMaxLeverage    = 3.0;    // cap notional/equity
input double InpMaxLot         = 100.0;  // hard lot cap
input bool   InpAllowLong      = true;
input bool   InpAllowShort     = true;
input double InpDeadBandLots   = 0.0;    // skip re-trade if |target-current| below this (0=auto=volume step)

ENUM_TIMEFRAMES TF = PERIOD_D1;
datetime g_lastBar = 0;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(100);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_NO);
   return(INIT_SUCCEEDED);
}

double Signal()
{
   int lbs[4]; lbs[0]=InpL1; lbs[1]=InpL2; lbs[2]=InpL3; lbs[3]=InpL4;
   double c1 = iClose(_Symbol, TF, 1);
   if(c1<=0) return(0);
   double s=0; int n=0;
   for(int i=0;i<4;i++){
      int L=lbs[i]; if(L<=0) continue;
      double cL=iClose(_Symbol, TF, 1+L); if(cL<=0) continue;
      s += (c1>cL ? 1.0 : (c1<cL ? -1.0 : 0.0)); n++;
   }
   return(n==0 ? 0.0 : s/n);
}

double DailyVol()
{
   int N=InpVolWindow; if(N<5) N=5;
   double mean=0.0; double r[]; ArrayResize(r,N);
   for(int i=0;i<N;i++){
      double c =iClose(_Symbol, TF, 1+i);
      double cp=iClose(_Symbol, TF, 2+i);
      if(c<=0||cp<=0) return(0);
      r[i]=c/cp-1.0; mean+=r[i];
   }
   mean/=N; double v=0;
   for(int i=0;i<N;i++) v+=(r[i]-mean)*(r[i]-mean);
   v/=(N-1);
   return(MathSqrt(v));
}

double MyNetVolume()
{
   double vol=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      double v=PositionGetDouble(POSITION_VOLUME);
      vol += (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? v : -v);
   }
   return(vol);
}

void CloseAllMine()
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)  continue;
      trade.PositionClose(tk);
   }
}

void OnTick()
{
   datetime t=iTime(_Symbol, TF, 0);
   if(t==g_lastBar) return;                 // act once per new daily bar
   g_lastBar=t;

   int maxL=MathMax(MathMax(InpL1,InpL2),MathMax(InpL3,InpL4));
   if(Bars(_Symbol, TF) < maxL+InpVolWindow+5) return;

   double sig=Signal();
   if(!InpAllowLong  && sig>0) sig=0;
   if(!InpAllowShort && sig<0) sig=0;

   double vol=DailyVol(); if(vol<=0) return;
   double targetDaily=InpTargetVolAnnual/MathSqrt(252.0);
   double w = sig * (targetDaily/vol);
   if(w >  InpMaxLeverage) w= InpMaxLeverage;
   if(w < -InpMaxLeverage) w=-InpMaxLeverage;

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double price   = SymbolInfoDouble(_Symbol, SYMBOL_BID); if(price<=0) return;
   double contract= SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE); if(contract<=0) contract=1.0;
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); if(step<=0) step=0.01;
   double mn      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double targetLots = w*equity/(price*contract);
   double dir = (targetLots>=0 ? 1.0 : -1.0);
   double absL= MathFloor(MathAbs(targetLots)/step)*step;
   if(absL>InpMaxLot) absL=InpMaxLot;
   if(mx>0 && absL>mx) absL=mx;
   double tgt = dir*absL;
   if(absL<mn) tgt=0.0;                       // below min -> flat

   double cur  = MyNetVolume();
   double diff = tgt-cur;
   double band = (InpDeadBandLots>0 ? InpDeadBandLots : step);
   bool flip = (cur>0 && tgt<0) || (cur<0 && tgt>0);
   if(!flip && MathAbs(diff) < band) return;  // skip tiny adjustments

   // incremental adjust (netting): trade only the difference
   if(diff>0)      trade.Buy(NormalizeDouble(diff,2), _Symbol);
   else if(diff<0) trade.Sell(NormalizeDouble(-diff,2), _Symbol);
}

double OnTester()
{
   HistorySelect(0, TimeCurrent());
   int total=HistoryDealsTotal();
   ulong ids[]; datetime ins[]; int nin=0;
   ArrayResize(ids,total); ArrayResize(ins,total);
   for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
      ids[nin]=(ulong)HistoryDealGetInteger(tk,DEAL_POSITION_ID);
      ins[nin]=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); nin++;
   }
   int h=FileOpen("ck_crypto_tsmom_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"time","profit");
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
         if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         ulong pid=(ulong)HistoryDealGetInteger(tk,DEAL_POSITION_ID);
         datetime et=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
         for(int j=0;j<nin;j++){ if(ids[j]==pid){ et=ins[j]; break; } }
         double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(et,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h);
   }
   return(0.0);
}
//+------------------------------------------------------------------+

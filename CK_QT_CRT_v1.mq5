//+------------------------------------------------------------------+
//| CK_QT_CRT_v1.mq5                                                   |
//| Faithful mechanical build of the Quarterly-Theory / CRT / DOL /   |
//| Daily-Bias framework (from the user's 4 decoded PDFs).            |
//| MT5 Strategy Tester is the only judge. Python reads output only.  |
//|                                                                    |
//| CORE = CRT "Power of Three" sweep-reversal (a.k.a. turtle-soup),   |
//| time-gated (killzone), biased by the True Open thermometer,        |
//| optional consolidation filter, DOL (opposite liquidity) target.    |
//| SMT/PSP omitted on XAUUSD (no clean correlated triad) - honest.    |
//|                                                                    |
//| Bearish (mirror for bull): a recent swing HIGH (ERL) is SWEPT by a |
//| closed M15 candle (high>level) that CLOSES back BELOW it, while    |
//| price is ABOVE the True Open (short bias) and inside a killzone.   |
//| -> SELL on the causal break of that candle's LOW; SL = swept HIGH  |
//| + buffer; TP = opposite liquidity (DOL) or fixed RR; RR gate.      |
//+------------------------------------------------------------------+
#property copyright "CK QT/CRT v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//==================== INPUTS (pin ALL — Guard #20) =================
input long   InpMagic            = 20260915;
input double InpFixedLot          = 0.09;
input double InpMaxLot            = 0.09;
//--- CRT sweep-reversal structure ---
input int    InpSwingPivot        = 2;      // pivot bars each side for a swing (ERL liquidity)
input int    InpSwingLookback     = 40;     // M15 bars scanned for the swept level
input double InpSLBufferATR       = 0.20;   // SL buffer beyond the sweep extreme (ATR units)
input int    InpAtrPeriod         = 14;
//--- True Open bias (thermometer) ---
input bool   InpUseTrueOpen       = true;   // require price the correct side of the True Open
//   True Open = the daily open at InpTrueOpenHour (server). Above=short bias, below=long bias.
input int    InpTrueOpenHour      = 0;      // server hour of the daily true open snapshot
//--- Killzone time gate (server time) ---
input bool   InpUseSession        = true;
input int    InpKZStartHour        = 13;    // default: London-NY / NY killzone window
input int    InpKZEndHour          = 22;
//--- Consolidation filter ("past Q must be low-probability") ---
input bool   InpUseConsolidation  = false;  // require pre-sweep range to be compressed
input int    InpConsolLookback     = 8;     // bars before the sweep to measure range
input double InpConsolMaxRangeATR  = 3.0;   // allow only if that range <= x*ATR
//--- TP / RR ---
input int    InpTPMode            = 0;      // 0=opposite liquidity (DOL), 1=fixed RR
input double InpFixedRR            = 2.0;
input double InpMinProjRR          = 1.0;   // reject setups with projected RR below this
//--- risk / housekeeping ---
input int    InpMaxTradesPerDay   = 3;
input double InpMaxSpreadPrice    = 0.60;
input int    InpSetupExpiryBars    = 4;     // armed CRT trigger voids after this many M15 bars

//==================== STATE =======================================
int      hAtr;
datetime lastM15=0, g_dayStart=0;
int      g_tradesToday=0;
int      g_dir=0;            // 0 none, -1 armed sell, +1 armed buy
double   g_trigger=0, g_sl=0, g_tp=0;
datetime g_expireAt=0;
// funnel diagnostics (printed in OnTester)
long g_cSweepBear=0,g_cSweepBull=0,g_cBias=0,g_cConsol=0,g_cRR=0,g_cArmed=0,g_cEntry=0;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hAtr=iATR(_Symbol,PERIOD_M15,InpAtrPeriod);
   if(hAtr==INVALID_HANDLE) return(INIT_FAILED);
   g_dayStart=iTime(_Symbol,PERIOD_D1,0);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr!=INVALID_HANDLE) IndicatorRelease(hAtr); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,1,1,b)<=0) return(0); return(b[0]); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
double FixedLot(){
   double lot=InpFixedLot,mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0)lot=MathRound(lot/st)*st; if(lot<mn)lot=mn; if(lot>InpMaxLot)lot=InpMaxLot; if(mx>0&&lot>mx)lot=mx; return(lot);
}
bool InSession(){
   if(!InpUseSession)return(true);
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int h=dt.hour;
   if(InpKZStartHour<=InpKZEndHour) return(h>=InpKZStartHour && h<InpKZEndHour);
   return(h>=InpKZStartHour || h<InpKZEndHour);
}
// True Open = the open of the day at InpTrueOpenHour (server). Use D1 open when hour=0.
double TrueOpen(){
   if(InpTrueOpenHour<=0) return(iOpen(_Symbol,PERIOD_D1,0));
   // find today's candle at InpTrueOpenHour on H1
   datetime now=TimeCurrent(); MqlDateTime dt; TimeToStruct(now,dt);
   dt.hour=InpTrueOpenHour; dt.min=0; dt.sec=0;
   datetime toT=StructToTime(dt);
   if(toT>now) toT-=86400;
   int sh=iBarShift(_Symbol,PERIOD_H1,toT,false);
   double o=iOpen(_Symbol,PERIOD_H1,sh); if(o>0) return(o);
   return(iOpen(_Symbol,PERIOD_D1,0));
}
bool IsSwingHigh(const double &H[],int s,int piv,int N){ if(s-piv<1||s+piv>N-1)return(false); for(int k=1;k<=piv;k++){ if(!(H[s]>H[s-k])||!(H[s]>H[s+k]))return(false);} return(true); }
bool IsSwingLow(const double &L[],int s,int piv,int N){ if(s-piv<1||s+piv>N-1)return(false); for(int k=1;k<=piv;k++){ if(!(L[s]<L[s-k])||!(L[s]<L[s+k]))return(false);} return(true); }

void OnTick(){
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_tradesToday=0; }
   if(MyPositions()>0){ g_dir=0; return; }

   // act on an armed CRT trigger (causal break fill)
   if(g_dir!=0){
      if(TimeCurrent()>g_expireAt){ g_dir=0; }
      else{
         double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         long spr=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD),mx=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
         if(spr<=mx && InSession() && g_tradesToday<InpMaxTradesPerDay){
            int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
            if(g_dir<0 && bid<g_trigger){ if(trade.Sell(FixedLot(),_Symbol,0,NormalizeDouble(g_sl,dg),NormalizeDouble(g_tp,dg))){g_tradesToday++;g_cEntry++;} g_dir=0; }
            else if(g_dir>0 && ask>g_trigger){ if(trade.Buy(FixedLot(),_Symbol,0,NormalizeDouble(g_sl,dg),NormalizeDouble(g_tp,dg))){g_tradesToday++;g_cEntry++;} g_dir=0; }
         }
      }
   }

   datetime t=iTime(_Symbol,PERIOD_M15,0); if(t==lastM15)return; lastM15=t;
   if(g_dir!=0)return; if(!InSession())return; if(g_tradesToday>=InpMaxTradesPerDay)return;

   int N=InpSwingLookback+InpSwingPivot+3;
   double H[],L[],O[],C[]; ArraySetAsSeries(H,true);ArraySetAsSeries(L,true);ArraySetAsSeries(O,true);ArraySetAsSeries(C,true);
   if(CopyHigh(_Symbol,PERIOD_M15,0,N,H)<N)return; if(CopyLow(_Symbol,PERIOD_M15,0,N,L)<N)return;
   if(CopyOpen(_Symbol,PERIOD_M15,0,N,O)<N)return; if(CopyClose(_Symbol,PERIOD_M15,0,N,C)<N)return;
   double atr=ATR(); if(atr<=0)return;
   double to=TrueOpen();
   double buf=InpSLBufferATR*atr;

   // bar 1 = last closed candle = the CRT sweep candle
   // BEARISH CRT: swept a recent swing HIGH and closed back below it
   int shH=-1; double lvlH=0;
   for(int s=2;s<=N-1-InpSwingPivot;s++){ if(IsSwingHigh(H,s,InpSwingPivot,N)){ shH=s; lvlH=H[s]; break; } }
   if(shH>0 && H[1]>lvlH && C[1]<lvlH){
      g_cSweepBear++;
      bool biasOK = (!InpUseTrueOpen) || (C[1]>to);           // short bias: price above True Open
      if(biasOK){
         g_cBias++;
         bool consolOK=true;
         if(InpUseConsolidation){ double hi=H[2],lo=L[2]; for(int s=2;s<2+InpConsolLookback&&s<N;s++){ if(H[s]>hi)hi=H[s]; if(L[s]<lo)lo=L[s]; } consolOK=((hi-lo)<=InpConsolMaxRangeATR*atr); }
         if(consolOK){
            g_cConsol++;
            double entry=L[1], sl=H[1]+buf;
            // DOL target = nearest opposite (lower) swing low; fallback fixed RR
            double tp=0;
            if(InpTPMode==0){ int slw=-1; for(int s=2;s<=N-1-InpSwingPivot;s++){ if(IsSwingLow(L,s,InpSwingPivot,N)&&L[s]<entry){ slw=s; break; } } tp=(slw>0)?L[slw]:entry-InpFixedRR*(sl-entry); }
            else tp=entry-InpFixedRR*(sl-entry);
            double risk=sl-entry, reward=entry-tp;
            if(risk>0 && reward/risk>=InpMinProjRR){ g_cRR++; g_dir=-1; g_trigger=entry; g_sl=sl; g_tp=tp; g_expireAt=t+(datetime)(InpSetupExpiryBars*15*60); g_cArmed++; return; }
         }
      }
   }
   // BULLISH CRT: swept a recent swing LOW and closed back above it
   int shL=-1; double lvlL=0;
   for(int s=2;s<=N-1-InpSwingPivot;s++){ if(IsSwingLow(L,s,InpSwingPivot,N)){ shL=s; lvlL=L[s]; break; } }
   if(shL>0 && L[1]<lvlL && C[1]>lvlL){
      g_cSweepBull++;
      bool biasOK = (!InpUseTrueOpen) || (C[1]<to);           // long bias: price below True Open
      if(biasOK){
         g_cBias++;
         bool consolOK=true;
         if(InpUseConsolidation){ double hi=H[2],lo=L[2]; for(int s=2;s<2+InpConsolLookback&&s<N;s++){ if(H[s]>hi)hi=H[s]; if(L[s]<lo)lo=L[s]; } consolOK=((hi-lo)<=InpConsolMaxRangeATR*atr); }
         if(consolOK){
            g_cConsol++;
            double entry=H[1], sl=L[1]-buf;
            double tp=0;
            if(InpTPMode==0){ int shw=-1; for(int s=2;s<=N-1-InpSwingPivot;s++){ if(IsSwingHigh(H,s,InpSwingPivot,N)&&H[s]>entry){ shw=s; break; } } tp=(shw>0)?H[shw]:entry+InpFixedRR*(entry-sl); }
            else tp=entry+InpFixedRR*(entry-sl);
            double risk=entry-sl, reward=tp-entry;
            if(risk>0 && reward/risk>=InpMinProjRR){ g_cRR++; g_dir=+1; g_trigger=entry; g_sl=sl; g_tp=tp; g_expireAt=t+(datetime)(InpSetupExpiryBars*15*60); g_cArmed++; }
         }
      }
   }
}

double OnTester(){
   PrintFormat("[QTCRT] funnel sweepBear=%I64d sweepBull=%I64d bias=%I64d consol=%I64d rr=%I64d armed=%I64d entry=%I64d",
      g_cSweepBear,g_cSweepBull,g_cBias,g_cConsol,g_cRR,g_cArmed,g_cEntry);
   int h=FileOpen("ck_qtcrt_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"time","profit");
      HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
         if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue;
         if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
         double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h);
   }
   return(0.0);
}
//+------------------------------------------------------------------+

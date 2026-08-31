//+------------------------------------------------------------------+
//| CK_QM_ICT_FAITHFUL_v1.mq5                                          |
//| Faithful MQL5 build of the QM/ICT XAUUSD setup per                 |
//| SPEC/QM_ICT_STRATEGY_SPEC.md. NEW build (does NOT reuse the old    |
//| simplified CK_QM_ICT_EA). MT5 Strategy Tester is the only judge.   |
//|                                                                    |
//| Bearish causal chain (bullish = exact mirror), closed-bar only:    |
//|   swings(M15,pivot) -> HEAD raids LEFT-SHOULDER (higher high)      |
//|   -> MSS DOWN (M15 body-close < neckline swing low, |c-o|/ATR>=disp)|
//|   -> IDM (inducement high after MSS) CLEARED (if required)         |
//|   -> price returns UP into QM left-shoulder POI zone               |
//|   -> M5 "1 rejection" candle at POI                                |
//|   -> SELL on break of rejection LOW; SL = rejection HIGH + buf     |
//|   -> TP = opposite external liquidity (lower external swing low);  |
//|      require projected RR >= min_projected_rr else NO TRADE.       |
//| SMT (XAU vs XAG) optional (default off; XAG-in-tester uncertain).  |
//+------------------------------------------------------------------+
#property copyright "CK QM/ICT faithful v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//==================== INPUTS (pin ALL — Guard #20) =================
input long   InpMagic            = 20260901;
input double InpFixedLot          = 0.09;   // fixed lot every trade (hard-locked)
input double InpMaxLot            = 0.09;   // ceiling (never exceed)
//--- structure / MSS (LOCKED defs; params exposed per spec §3) ---
input int    InpPivot            = 2;       // swing L/R bars (structure sensitivity)
input double InpDisp             = 0.6;     // MSS displacement = |close-open|/ATR14 (test 0.6/0.8/1.0)
input int    InpAtrPeriod        = 14;      // ATR period (M15) for displacement + SL buffer
input double InpSLBufferATR      = 0.5;     // SL buffer beyond rejection extreme (ATR units)
input double InpMinProjRR        = 1.0;     // reject setups with projected RR below this (test 1.0/1.5)
//--- external liquidity (ERL) ---
input ENUM_TIMEFRAMES InpErlTF   = PERIOD_H1; // ERL source TF (test H1/H4)
input int    InpErlLookback      = 5;       // swings/bars window defining the external range
//--- inducement ---
input bool   InpIdmClearRequired = true;    // A+ = true; experimental variant = false
//--- POI / TP variant switches ---
input int    InpPOIMode          = 0;       // 0=qm base, 1=qm+OB, 2=qm+FVG (confluence)
input int    InpTPMode           = 0;       // 0=full_external, 1=fixed_rr
input double InpFixedRR           = 2.0;    // used only when InpTPMode=1
//--- SMT (XAU vs XAG) ---
input bool   InpUseSMT           = false;   // default OFF (XAGUSD in tester uncertain; spec §5)
input string InpSMTSymbol        = "XAGUSD";
input int    InpSMTCorrWindow    = 20;
input double InpSMTCorrMin       = 0.3;
//--- session (NY) ---
input bool   InpUseSession       = true;
input int    InpSessStartHour    = 9;
input int    InpSessStartMin     = 30;
input int    InpSessEndHour      = 16;
input int    InpSessEndMin       = 0;
//--- risk / housekeeping ---
input int    InpMaxTradesPerDay  = 2;       // NOTE: interacts with session gate (spec §8 warning)
input int    InpLookbackBars     = 500;     // M15 bars scanned for structure
input int    InpSetupExpiryBars  = 40;      // MSS older than this (M15 bars) => setup expired
input double InpMaxSpreadPrice   = 0.60;    // skip entries when spread exceeds this (price units)

//==================== STATE =======================================
int      hAtr15;
datetime lastM15=0, g_dayStart=0;
int      g_tradesToday=0;
// pending trigger after a valid POI + M5 rejection
int      g_dir=0;            // 0 none, -1 bear (sell), +1 bull (buy)
double   g_trigger=0;        // break level (rejection extreme)
double   g_slLevel=0;        // stop level (rejection opposite extreme + buffer)
double   g_tpLevel=0;        // target (opposite external liquidity)
datetime g_setupExpireAt=0;  // time after which pending is void
// diagnostics (chain funnel) — printed in OnTester
long     g_cCtxBear=0,g_cCtxBull=0,g_cMSS=0,g_cRaid=0,g_cIDM=0,g_cPOI=0,g_cConf=0,g_cRej=0,g_cArmed=0,g_cEntry=0,g_cReject=0,g_cRRfail=0,g_cSMTskip=0;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_NO);
   hAtr15=iATR(_Symbol,PERIOD_M15,InpAtrPeriod);
   if(hAtr15==INVALID_HANDLE) return(INIT_FAILED);
   if(InpUseSMT) SymbolSelect(InpSMTSymbol,true); // ensure XAG in Market Watch for tester
   ResetDaily();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr15!=INVALID_HANDLE) IndicatorRelease(hAtr15); }

double ATR15(){ double b[]; if(CopyBuffer(hAtr15,0,1,1,b)<=0) return(0); return(b[0]); }
void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_tradesToday=0; }
int  MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol) c++; } return(c); }

double FixedLot(){
   double lot=InpFixedLot, mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathRound(lot/st)*st;
   if(lot<mn) lot=mn; if(lot>InpMaxLot) lot=InpMaxLot; if(mx>0 && lot>mx) lot=mx;
   return(lot);
}

bool InSession(){
   if(!InpUseSession) return(true);
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   int cur=dt.hour*60+dt.min;
   int a=InpSessStartHour*60+InpSessStartMin, b=InpSessEndHour*60+InpSessEndMin;
   if(a<=b) return(cur>=a && cur<b);
   return(cur>=a || cur<b);
}

//==================== SMT (optional) ==============================
// Bear SMT: XAU higher-high not confirmed by XAG (XAG lower/equal high) near the raid,
// gated by rolling correlation >= corr_min. Returns true if SMT supports the direction
// OR if SMT is disabled. If XAG missing -> treat as unavailable (skip=support off honestly).
bool SMTsupport(int dir){
   if(!InpUseSMT) return(true);
   int n=InpSMTCorrWindow;
   double xa[],xg[]; ArraySetAsSeries(xa,true); ArraySetAsSeries(xg,true);
   if(CopyClose(_Symbol,PERIOD_M15,1,n,xa)<n){ g_cSMTskip++; return(false); }
   if(CopyClose(InpSMTSymbol,PERIOD_M15,1,n,xg)<n){ g_cSMTskip++; return(false); }
   // Pearson correlation
   double ma=0,mg=0; for(int i=0;i<n;i++){ ma+=xa[i]; mg+=xg[i]; } ma/=n; mg/=n;
   double sa=0,sg=0,sag=0;
   for(int i=0;i<n;i++){ double da=xa[i]-ma, dg=xg[i]-mg; sa+=da*da; sg+=dg*dg; sag+=da*dg; }
   if(sa<=0||sg<=0){ g_cSMTskip++; return(false); }
   double corr=sag/MathSqrt(sa*sg);
   if(corr<InpSMTCorrMin){ g_cSMTskip++; return(false); } // correlation too weak -> SMT invalid
   double xaH[],xaL[],xgH[],xgL[]; ArraySetAsSeries(xaH,true);ArraySetAsSeries(xaL,true);ArraySetAsSeries(xgH,true);ArraySetAsSeries(xgL,true);
   int k=InpErlLookback+2;
   if(CopyHigh(_Symbol,PERIOD_M15,1,k,xaH)<k||CopyLow(_Symbol,PERIOD_M15,1,k,xaL)<k) return(false);
   if(CopyHigh(InpSMTSymbol,PERIOD_M15,1,k,xgH)<k||CopyLow(InpSMTSymbol,PERIOD_M15,1,k,xgL)<k) return(false);
   double xauHH=xaH[ArrayMaximum(xaH,0,k)], xauRecent=xaH[0];
   double xagHH=xgH[ArrayMaximum(xgH,0,k)], xagRecent=xgH[0];
   double xauLL=xaL[ArrayMinimum(xaL,0,k)], xagLL=xgL[ArrayMinimum(xgL,0,k)];
   if(dir<0){ // bear: XAU made the higher high recently, XAG did not confirm (its recent high below its window high)
      bool xauMadeHH=(xauRecent>=xauHH-_Point);
      bool xagFailed=(xagRecent<xagHH-_Point);
      return(xauMadeHH && xagFailed);
   } else { // bull mirror on lows
      bool xauMadeLL=(xaL[0]<=xauLL+_Point);
      bool xagFailed=(xgL[0]>xagLL+_Point);
      return(xauMadeLL && xagFailed);
   }
}

//==================== structure helpers (M15) =====================
// series arrays index 1..N are CLOSED bars (0 = forming). Pivot swing needs `pivot` bars each side.
bool IsSwingHigh(const double &H[],int s,int piv,int N){
   if(s-piv<1 || s+piv>N-1) return(false);
   for(int k=1;k<=piv;k++){ if(!(H[s]>H[s-k]) || !(H[s]>H[s+k])) return(false); }
   return(true);
}
bool IsSwingLow(const double &L[],int s,int piv,int N){
   if(s-piv<1 || s+piv>N-1) return(false);
   for(int k=1;k<=piv;k++){ if(!(L[s]<L[s-k]) || !(L[s]<L[s+k])) return(false); }
   return(true);
}
// POI confluence (spec §4): does an Order Block or Fair-Value-Gap intersect the POI zone [zLo,zHi]?
// dir=-1 bear, +1 bull. Mode: 1=OB, 2=FVG, 3=OB or FVG, 0=no requirement (base).
bool HasConfluence(int dir,double zLo,double zHi,const double &H[],const double &L[],const double &O[],const double &C[],int N){
   if(InpPOIMode<=0) return(true);
   bool ob=false, fvg=false;
   int scan=MathMin(N-2,InpLookbackBars);
   // FVG (3-bar imbalance) whose gap zone overlaps the POI
   for(int s=2;s<scan && !fvg;s++){
      if(dir<0){ if(H[s+1]<L[s-1] && L[s-1]>=zLo && H[s+1]<=zHi) fvg=true; }   // bearish gap zone [H[s+1],L[s-1]]
      else     { if(L[s+1]>H[s-1] && L[s+1]>=zLo && H[s-1]<=zHi) fvg=true; }   // bullish gap zone [H[s-1],L[s+1]]
   }
   // Order block: last opposite candle at the zone immediately preceding a displacement candle
   for(int s=1;s<scan && !ob;s++){
      if(dir<0){ if(C[s]>O[s] && H[s]>=zLo && L[s]<=zHi && s-1>=1 && C[s-1]<O[s-1]) ob=true; } // bearish OB = up candle then down displacement
      else     { if(C[s]<O[s] && H[s]>=zLo && L[s]<=zHi && s-1>=1 && C[s-1]>O[s-1]) ob=true; } // bullish OB = down candle then up displacement
   }
   if(InpPOIMode==1) return(ob);
   if(InpPOIMode==2) return(fvg);
   return(ob||fvg); // mode 3
}

// Nearest opposite H1/H4 (erl_tf) confirmed swing key beyond entry (spec §6 alt TP = nearer target).
// dir=-1 bear -> nearest swing LOW below entry; dir=+1 bull -> nearest swing HIGH above entry. 0 if none.
double NearestErlKey(int dir,double entry){
   int piv=2, n=200;
   double eH[],eL[]; ArraySetAsSeries(eH,true); ArraySetAsSeries(eL,true);
   if(CopyHigh(_Symbol,InpErlTF,1,n,eH)<n) return(0);
   if(CopyLow(_Symbol,InpErlTF,1,n,eL)<n) return(0);
   double best=0; bool found=false;
   for(int s=1+piv;s<=n-1-piv;s++){
      if(dir<0){
         bool sw=true; for(int k=1;k<=piv;k++){ if(!(eL[s]<eL[s-k])||!(eL[s]<eL[s+k])){ sw=false; break; } }
         if(sw && eL[s]<entry && (!found || eL[s]>best)){ best=eL[s]; found=true; }   // highest low below entry = nearest
      } else {
         bool sw=true; for(int k=1;k<=piv;k++){ if(!(eH[s]>eH[s-k])||!(eH[s]>eH[s+k])){ sw=false; break; } }
         if(sw && eH[s]>entry && (!found || eH[s]<best)){ best=eH[s]; found=true; }   // lowest high above entry = nearest
      }
   }
   return(found?best:0);
}

//==================== main ========================================
void OnTick(){
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();

   // one position at a time; let SL/TP run (no meddling)
   if(MyPositions()>0){ g_dir=0; return; }

   // 1) act on a pending armed trigger every tick (causal break fill)
   if(g_dir!=0){
      if(TimeCurrent()>g_setupExpireAt){ g_dir=0; }
      else {
         double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         long spr=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
         long maxspr=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
         if(spr<=maxspr && InSession() && g_tradesToday<InpMaxTradesPerDay){
            int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
            if(g_dir<0 && bid<g_trigger){ // SELL on break of rejection low
               double sl=NormalizeDouble(g_slLevel,dg), tp=NormalizeDouble(g_tpLevel,dg);
               if(trade.Sell(FixedLot(),_Symbol,0,sl,tp)){ g_tradesToday++; g_cEntry++; }
               g_dir=0;
            } else if(g_dir>0 && ask>g_trigger){ // BUY on break of rejection high
               double sl=NormalizeDouble(g_slLevel,dg), tp=NormalizeDouble(g_tpLevel,dg);
               if(trade.Buy(FixedLot(),_Symbol,0,sl,tp)){ g_tradesToday++; g_cEntry++; }
               g_dir=0;
            }
         }
      }
   }

   // 2) refresh context only on a new M15 bar
   datetime t15=iTime(_Symbol,PERIOD_M15,0);
   if(t15==lastM15) return;
   lastM15=t15;
   if(g_dir!=0) return;            // already armed, wait for break/expiry
   if(!InSession()) return;
   if(g_tradesToday>=InpMaxTradesPerDay) return;

   int N=InpLookbackBars;
   double H[],L[],O[],C[]; datetime T[];
   ArraySetAsSeries(H,true);ArraySetAsSeries(L,true);ArraySetAsSeries(O,true);ArraySetAsSeries(C,true);ArraySetAsSeries(T,true);
   if(CopyHigh(_Symbol,PERIOD_M15,0,N,H)<N) return;
   if(CopyLow(_Symbol,PERIOD_M15,0,N,L)<N) return;
   if(CopyOpen(_Symbol,PERIOD_M15,0,N,O)<N) return;
   if(CopyClose(_Symbol,PERIOD_M15,0,N,C)<N) return;
   if(CopyTime(_Symbol,PERIOD_M15,0,N,T)<N) return;
   double atr=ATR15(); if(atr<=0) return;

   TryBear(H,L,O,C,T,N,atr);
   if(g_dir==0) TryBull(H,L,O,C,T,N,atr);
}

// ---- bearish setup ----
// Correct temporal order (shift larger = older): LEFT-SHOULDER high -> HEAD (higher high, raids LS)
// -> neckline swing low -> MSS DOWN (recent) -> IDM (more recent) cleared -> retrace UP into POI (now).
void TryBear(const double &H[],const double &L[],const double &O[],const double &C[],const datetime &T[],int N,double atr){
   int piv=InpPivot;
   // 1) MSS DOWN = most recent M15 body-close below the nearest prior confirmed swing low, with displacement
   int shMSS=-1,shNeck=-1; double neckLow=0;
   for(int s=1;s<=InpSetupExpiryBars && s<N-1-piv;s++){
      if(!(C[s]<O[s])) continue;
      double disp=(atr>0)?(O[s]-C[s])/atr:0.0; if(disp<InpDisp) continue;
      int sl=-1; for(int u=s+1;u<=N-1-piv;u++){ if(IsSwingLow(L,u,piv,N)){ sl=u; break; } }
      if(sl<0) continue;
      if(C[s]<L[sl]){ shMSS=s; shNeck=sl; neckLow=L[sl]; break; }   // most recent qualifying MSS
   }
   if(shMSS<0) return;
   g_cMSS++;
   // 2) HEAD = most recent confirmed swing high BEFORE the break (shift > shMSS)
   int shHH=-1; for(int u=shMSS+1;u<=N-1-piv;u++){ if(IsSwingHigh(H,u,piv,N)){ shHH=u; break; } }
   if(shHH<0) return;
   // 3) LEFT SHOULDER = older swing high, LOWER than the head (head raids the shoulder's liquidity)
   int shLS=-1; for(int u=shHH+1;u<=N-1-piv;u++){ if(IsSwingHigh(H,u,piv,N) && H[u]<H[shHH]){ shLS=u; break; } }
   if(shLS<0) return;
   g_cCtxBear++; g_cRaid++;
   // POI = left-shoulder candle zone [L[shLS], H[shLS]]
   double poiHi=H[shLS], poiLo=L[shLS];
   // 4) IDM = minor swing high AFTER the MSS (shift < shMSS) that is CLEARED (price later trades above it)
   if(InpIdmClearRequired){
      int shIDM=-1;
      for(int s=shMSS-1;s>=1+piv;s--){ if(IsSwingHigh(H,s,piv,N)){ shIDM=s; break; } }
      if(shIDM<0) return;                 // no inducement formed yet
      bool cleared=false; for(int s=shIDM-1;s>=1;s--){ if(H[s]>H[shIDM]){ cleared=true; break; } }
      if(!cleared) return;
      g_cIDM++;
   }
   // 5) POI return: recent price retraced UP into the shoulder zone (bar1 high reached >= poiLo)
   if(H[1]<poiLo) return;
   if(C[1]>H[shHH]) return;               // invalidated if price closed back above the head
   g_cPOI++;
   // POI confluence (OB/FVG) per InpPOIMode
   if(!HasConfluence(-1,poiLo,poiHi,H,L,O,C,N)) return;
   g_cConf++;
   // SMT gate (optional)
   if(!SMTsupport(-1)) return;
   // M5 "1 rejection" at POI: most recent CLOSED M5 bar is bearish and tagged the zone
   double m5O[],m5H[],m5L[],m5C[]; ArraySetAsSeries(m5O,true);ArraySetAsSeries(m5H,true);ArraySetAsSeries(m5L,true);ArraySetAsSeries(m5C,true);
   if(CopyOpen(_Symbol,PERIOD_M5,1,3,m5O)<3) return;
   if(CopyHigh(_Symbol,PERIOD_M5,1,3,m5H)<3) return;
   if(CopyLow(_Symbol,PERIOD_M5,1,3,m5L)<3) return;
   if(CopyClose(_Symbol,PERIOD_M5,1,3,m5C)<3) return;
   bool rej=(m5C[0]<m5O[0] && m5H[0]>=poiLo);   // bearish rejection candle tagging the POI
   if(!rej) return;
   g_cRej++;
   // TP = opposite external liquidity = lowest external swing low in the window (below entry)
   double extLow=L[ArrayMinimum(L,1,N-1)];
   double entry=m5L[0];                          // sell on break of rejection LOW
   double sl=m5H[0]+InpSLBufferATR*atr;
   double tp;
   if(InpTPMode==1)      tp=entry-InpFixedRR*(sl-entry);           // fixed_rr
   else if(InpTPMode==2){ double k=NearestErlKey(-1,entry); tp=(k>0)?k:extLow; } // opposite H1/H4 key (nearer), fallback full-external
   else                  tp=extLow;                               // full_external (base)
   double risk=sl-entry, reward=entry-tp;
   if(risk<=0){ return; }
   double rr=(risk>0)?reward/risk:0.0;
   if(rr<InpMinProjRR){ g_cRRfail++; return; }
   // ARM the pending SELL trigger (fill on causal break of rejection low)
   g_dir=-1; g_trigger=entry; g_slLevel=sl; g_tpLevel=tp;
   g_setupExpireAt=T[0]+(datetime)(InpSetupExpiryBars*15*60);
   g_cArmed++;
}

// ---- bullish setup (mirror) ----
void TryBull(const double &H[],const double &L[],const double &O[],const double &C[],const datetime &T[],int N,double atr){
   int piv=InpPivot;
   // 1) MSS UP = most recent M15 body-close above the nearest prior confirmed swing high, with displacement
   int shMSS=-1,shNeck=-1; double neckHigh=0;
   for(int s=1;s<=InpSetupExpiryBars && s<N-1-piv;s++){
      if(!(C[s]>O[s])) continue;
      double disp=(atr>0)?(C[s]-O[s])/atr:0.0; if(disp<InpDisp) continue;
      int sh=-1; for(int u=s+1;u<=N-1-piv;u++){ if(IsSwingHigh(H,u,piv,N)){ sh=u; break; } }
      if(sh<0) continue;
      if(C[s]>H[sh]){ shMSS=s; shNeck=sh; neckHigh=H[sh]; break; }
   }
   if(shMSS<0) return;
   g_cMSS++;
   // 2) HEAD = most recent confirmed swing low BEFORE the break (shift > shMSS)
   int shLL=-1; for(int u=shMSS+1;u<=N-1-piv;u++){ if(IsSwingLow(L,u,piv,N)){ shLL=u; break; } }
   if(shLL<0) return;
   // 3) LEFT SHOULDER = older swing low, HIGHER than the head low (head raids below it)
   int shLSl=-1; for(int u=shLL+1;u<=N-1-piv;u++){ if(IsSwingLow(L,u,piv,N) && L[u]>L[shLL]){ shLSl=u; break; } }
   if(shLSl<0) return;
   g_cCtxBull++; g_cRaid++;
   double poiLo=L[shLSl], poiHi=H[shLSl];
   // 4) IDM = minor swing low after the MSS, cleared (price later trades below it)
   if(InpIdmClearRequired){
      int shIDM=-1;
      for(int s=shMSS-1;s>=1+piv;s--){ if(IsSwingLow(L,s,piv,N)){ shIDM=s; break; } }
      if(shIDM<0) return;
      bool cleared=false; for(int s=shIDM-1;s>=1;s--){ if(L[s]<L[shIDM]){ cleared=true; break; } }
      if(!cleared) return;
      g_cIDM++;
   }
   // 5) POI return: recent price retraced DOWN into the shoulder zone
   if(L[1]>poiHi) return;
   if(C[1]<L[shLL]) return;
   g_cPOI++;
   if(!HasConfluence(+1,poiLo,poiHi,H,L,O,C,N)) return;
   g_cConf++;
   if(!SMTsupport(+1)) return;
   double m5O[],m5H[],m5L[],m5C[]; ArraySetAsSeries(m5O,true);ArraySetAsSeries(m5H,true);ArraySetAsSeries(m5L,true);ArraySetAsSeries(m5C,true);
   if(CopyOpen(_Symbol,PERIOD_M5,1,3,m5O)<3) return;
   if(CopyHigh(_Symbol,PERIOD_M5,1,3,m5H)<3) return;
   if(CopyLow(_Symbol,PERIOD_M5,1,3,m5L)<3) return;
   if(CopyClose(_Symbol,PERIOD_M5,1,3,m5C)<3) return;
   bool rej=(m5C[0]>m5O[0] && m5L[0]<=poiHi);
   if(!rej) return;
   g_cRej++;
   double extHigh=H[ArrayMaximum(H,1,N-1)];
   double entry=m5H[0];
   double sl=m5L[0]-InpSLBufferATR*atr;
   double tp;
   if(InpTPMode==1)      tp=entry+InpFixedRR*(entry-sl);          // fixed_rr
   else if(InpTPMode==2){ double k=NearestErlKey(+1,entry); tp=(k>0)?k:extHigh; } // opposite H1/H4 key (nearer), fallback full-external
   else                  tp=extHigh;                              // full_external (base)
   double risk=entry-sl, reward=tp-entry;
   if(risk<=0){ return; }
   double rr=(risk>0)?reward/risk:0.0;
   if(rr<InpMinProjRR){ g_cRRfail++; return; }
   g_dir=+1; g_trigger=entry; g_slLevel=sl; g_tpLevel=tp;
   g_setupExpireAt=T[0]+(datetime)(InpSetupExpiryBars*15*60);
   g_cArmed++;
}

double OnTester(){
   PrintFormat("[QMF] funnel ctxBear=%I64d ctxBull=%I64d raid=%I64d MSS=%I64d IDM=%I64d POI=%I64d conf=%I64d rej=%I64d armed=%I64d entry=%I64d RRfail=%I64d SMTskip=%I64d",
      g_cCtxBear,g_cCtxBull,g_cRaid,g_cMSS,g_cIDM,g_cPOI,g_cConf,g_cRej,g_cArmed,g_cEntry,g_cRRfail,g_cSMTskip);
   int h=FileOpen("ck_qmf_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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

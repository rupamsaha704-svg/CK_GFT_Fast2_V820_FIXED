//+------------------------------------------------------------------+
//|  CK_GOLD_DTREND.mq5 - GOLD daily LONG-ONLY trend (chop-resilient) |
//|  Validated edge (Python 10yr GC): daily long-only trend does NOT  |
//|  bleed in chop (rides up-drift, sits FLAT in downtrend, no short   |
//|  whipsaw). Engine = EMA-cross (10yr robust) OR KAMA (adaptive,     |
//|  smoother in chop) OR BOTH (confluence).                          |
//|  Long-only: long while bull, FLAT otherwise. Risk-% sizing.        |
//|  GFT guards: static-DD halt (<10%) + daily-loss stop.             |
//|  Signal on InpSigTF (D1 default). A/B engines via InpEngine.      |
//+------------------------------------------------------------------+
#property copyright "CK GOLD DTREND"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic          = 20260930;
input ENUM_TIMEFRAMES InpSigTF = PERIOD_D1;   // signal timeframe (daily edge)
input int    InpEngine         = 0;           // 0=EMA cross, 1=KAMA, 2=BOTH (confluence)
//--- EMA engine ---
input int    InpFastEMA        = 20;
input int    InpSlowEMA        = 100;
//--- KAMA engine (Kaufman adaptive: slow in chop, fast in trend) ---
input int    InpKAMA_ER        = 10;          // efficiency-ratio lookback
input int    InpKAMA_Fast      = 2;
input int    InpKAMA_Slow      = 30;
//--- CHOP stand-down (only trade when the market is actually trending) ---
input bool   InpUseRegime      = true;        // sit FLAT in chop: open trades only when trending
input ENUM_TIMEFRAMES InpRegimeTF = PERIOD_D1;// regime timeframe
input int    InpRegimeADXPeriod= 14;
input double InpADXTrendMin     = 20.0;       // require ADX(RegimeTF) >= this to trade; below = chop = stand down
//--- higher-TF trend confirmation (don't buy against the bigger trend) ---
input bool   InpUseHTFtrend    = true;        // only go long if a HIGHER TF is also bullish (skips counter-trend longs in a decline/chop)
input ENUM_TIMEFRAMES InpHTFtrendTF = PERIOD_D1;
input int    InpHTFtrendEMA    = 100;         // long only if close(HTFtrendTF) > this EMA
//--- Choppiness Index regime filter (stand down when consolidating) ---
input bool   InpUseChop        = true;        // skip trades when Choppiness Index says choppy
input ENUM_TIMEFRAMES InpChopTF = PERIOD_H4;
input int    InpChopPeriod     = 14;
input double InpChopMax        = 61.8;        // trade only if CI < this (low=directional, high>61.8=choppy)
//--- stops / exits ---
input int    InpATRPeriod      = 14;
input double InpSL_ATR         = 3.0;         // disaster stop distance (ATR mult)
input bool   InpUseTrailATR    = true;        // chandelier trail
input double InpTrailATR       = 3.0;
//--- sizing ---
input double InpRiskPercent    = 1.0;         // % of balance risked per trade
input double InpMaxLot         = 0.50;
input double InpMaxRiskPerTradePct = 3.0;     // HARD cap: no trade risks > this % of balance
input bool   InpCapStopToRisk  = true;        // true: TIGHTEN stop so min-lot fits the cap (trades at any price); false: SKIP too-risky trades
input double InpMaxSpreadPrice = 1.00;
//--- GFT prop guards ---
input bool   InpUseDailyLoss   = true;
input double InpDailyLossPct   = 5.0;         // stop for day if day loss >= this % of day-start bal
input bool   InpUseStaticDD    = true;
input double InpStaticDDStopPct= 8.0;         // HALT if equity <= initial*(1-this%)  (< GFT 10% static)

int      hFast,hSlow,hAtr,hADXreg,hHTF;
datetime g_sigBarTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_initBal=0,g_entryHigh=0;
bool     g_halted=false;
string   GK_INIT,GK_DAY,GK_BAL;
int      g_cSpread=0,g_cGuard=0,g_cFlatDown=0,g_nBuy=0,g_nExit=0,g_cRiskSkip=0,g_cChop=0,g_cHTF=0,g_cChopIdx=0;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hFast=iMA(_Symbol,InpSigTF,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   hSlow=iMA(_Symbol,InpSigTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   hAtr =iATR(_Symbol,InpSigTF,InpATRPeriod);
   hADXreg=iADX(_Symbol,InpRegimeTF,InpRegimeADXPeriod);
   hHTF=iMA(_Symbol,InpHTFtrendTF,InpHTFtrendEMA,0,MODE_EMA,PRICE_CLOSE);
   if(hFast==INVALID_HANDLE||hSlow==INVALID_HANDLE||hAtr==INVALID_HANDLE||hADXreg==INVALID_HANDLE||hHTF==INVALID_HANDLE)return(INIT_FAILED);
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_INIT="ckdt_init_"+scope; GK_DAY="ckdt_day_"+scope; GK_BAL="ckdt_bal_"+scope;
   if(GlobalVariableCheck(GK_INIT)) g_initBal=GlobalVariableGet(GK_INIT);
   else { g_initBal=AccountInfoDouble(ACCOUNT_BALANCE); GlobalVariableSet(GK_INIT,g_initBal); }
   LoadOrResetDaily();
   PrintFormat("[DTREND] engine=%d SigTF=%d risk%%=%.2f maxRisk%%=%.1f staticDDstop=%.1f%% dailyLoss=%.1f%% mpp=%.2f contract=%.0f",
               InpEngine,(int)InpSigTF,InpRiskPercent,InpMaxRiskPerTradePct,InpStaticDDStopPct,InpDailyLossPct,
               MoneyPerPricePerLot(),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE));
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ IndicatorRelease(hFast);IndicatorRelease(hSlow);IndicatorRelease(hAtr);IndicatorRelease(hADXreg);IndicatorRelease(hHTF); }
double ADXreg(){ double b[]; if(CopyBuffer(hADXreg,0,1,1,b)<=0)return(0); return(b[0]); }
bool HTFbull(){ if(!InpUseHTFtrend) return(true); double b[]; if(CopyBuffer(hHTF,0,1,1,b)<=0) return(true); double e=b[0]; double c=iClose(_Symbol,InpHTFtrendTF,1); return(e>0 && c>e); }
double ChoppinessIndex(ENUM_TIMEFRAMES tf,int n){
   if(n<2) return(50.0);
   double sumTR=0, hh=-DBL_MAX, ll=DBL_MAX;
   for(int i=1;i<=n;i++){
      double h=iHigh(_Symbol,tf,i), l=iLow(_Symbol,tf,i), pc=iClose(_Symbol,tf,i+1);
      if(h==0||l==0) return(50.0);
      double tr=MathMax(h-l,MathMax(MathAbs(h-pc),MathAbs(l-pc)));
      sumTR+=tr; if(h>hh)hh=h; if(l<ll)ll=l;
   }
   double rng=hh-ll; if(rng<=0||sumTR<=0) return(50.0);
   return(100.0*MathLog10(sumTR/rng)/MathLog10((double)n));
}
bool NotChoppy(){ if(!InpUseChop) return(true); double ci=ChoppinessIndex(InpChopTF,InpChopPeriod); return(ci < InpChopMax); }

double ATRv(){ double b[]; if(CopyBuffer(hAtr,0,1,1,b)<=0)return(0); return(b[0]); }
double Fast1(){ double b[]; if(CopyBuffer(hFast,0,1,1,b)<=0)return(0); return(b[0]); }
double Slow1(){ double b[]; if(CopyBuffer(hSlow,0,1,1,b)<=0)return(0); return(b[0]); }

//--- KAMA on last-closed bar; returns kama value + sets rising flag ---
bool KAMA_bull(){
   int need=InpKAMA_ER+80;
   double cl[]; ArraySetAsSeries(cl,false);
   int got=CopyClose(_Symbol,InpSigTF,1,need,cl);   // closed bars only, [got-1]=most recent closed
   if(got<InpKAMA_ER+5) return(false);
   double fastSC=2.0/(InpKAMA_Fast+1.0), slowSC=2.0/(InpKAMA_Slow+1.0);
   double kama=cl[0]; double kprev=kama;
   for(int i=InpKAMA_ER;i<got;i++){
      double change=MathAbs(cl[i]-cl[i-InpKAMA_ER]);
      double vol=0; for(int j=i-InpKAMA_ER+1;j<=i;j++) vol+=MathAbs(cl[j]-cl[j-1]);
      double er=(vol>0)?change/vol:0.0;
      double sc=MathPow(er*(fastSC-slowSC)+slowSC,2.0);
      kprev=kama;
      kama=kama+sc*(cl[i]-kama);
   }
   return(kama>kprev);   // KAMA rising = bull
}
bool IsBull(){
   bool emaBull=(Fast1()>Slow1() && Slow1()>0);
   if(InpEngine==0) return(emaBull);
   bool kamaBull=KAMA_bull();
   if(InpEngine==1) return(kamaBull);
   return(emaBull && kamaBull);   // 2=BOTH
}
bool IsNewSigBar(){ datetime t=iTime(_Symbol,InpSigTF,0); if(t!=g_sigBarTime){ g_sigBarTime=t; return(true);} return(false); }

void LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0); datetime gday=(datetime)GlobalVariableGet(GK_DAY);
   if(gday==today && today>0){ g_dayStart=today; g_dayStartBal=GlobalVariableGet(GK_BAL); }
   else { g_dayStart=today; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); GlobalVariableSet(GK_DAY,(double)today); GlobalVariableSet(GK_BAL,g_dayStartBal); }
}
void NewDay(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); GlobalVariableSet(GK_DAY,(double)g_dayStart); GlobalVariableSet(GK_BAL,g_dayStartBal); }

int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }

double MoneyPerPricePerLot(){
   // money P&L for a 1.0 price move on 1.0 lot, in account currency.
   // For XAUUSD (quote=USD=deposit ccy) this = contract size (100 oz). tick_value/tick_size
   // can be mis-scaled on some symbols, so prefer contract size and sanity-check.
   double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double byTick=(ts>0)? tv/ts : 0.0;
   if(cs>0) return(cs);
   return(byTick);
}
double CalcLot(double slDist){
   double mpp=MoneyPerPricePerLot(); if(mpp<=0||slDist<=0)return(0);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney=bal*(InpRiskPercent/100.0);
   double maxRisk  =bal*(InpMaxRiskPerTradePct/100.0);
   if(riskMoney>maxRisk) riskMoney=maxRisk;                 // never target more than the hard cap
   double lot=riskMoney/(slDist*mpp);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathFloor(lot/st)*st;
   if(lot<mn){
      // even the minimum lot would risk more than the hard cap -> too risky for this account: SKIP
      if(slDist*mn*mpp > maxRisk) return(0);
      lot=mn;
   }
   if(lot>InpMaxLot) lot=InpMaxLot; if(mx>0&&lot>mx)lot=mx;
   // final safety: if the chosen lot still exceeds the hard cap, skip
   if(slDist*lot*mpp > maxRisk*1.05) return(0);
   return(lot);
}
double EquityDDpctFromInit(){ if(g_initBal<=0)return(0); double eq=AccountInfoDouble(ACCOUNT_EQUITY); return(100.0*(g_initBal-eq)/g_initBal); }
double DayLossPct(){ if(g_dayStartBal<=0)return(0); double eq=AccountInfoDouble(ACCOUNT_EQUITY); return(100.0*(g_dayStartBal-eq)/g_dayStartBal); }

void CloseMyLong(string why){
   ulong tk=GetMyTicket(); if(tk==0)return; if(trade.PositionClose(tk)){ g_nExit++; } 
}
void CloseAll(string why){ CloseMyLong(why); }

void TrailStop(){
   if(!InpUseTrailATR)return; ulong tk=GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   double atr=ATRv(); if(atr<=0)return;
   double px=iClose(_Symbol,InpSigTF,1); double newSL=px-InpTrailATR*atr;
   double sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP),open=PositionGetDouble(POSITION_PRICE_OPEN);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); newSL=NormalizeDouble(newSL,dg);
   if(newSL>sl && newSL<SymbolInfoDouble(_Symbol,SYMBOL_BID)) trade.PositionModify(tk,newSL,tp);
}
void OpenLong(){
   double atr=ATRv(); if(atr<=0)return; double slDist=InpSL_ATR*atr; if(slDist<=0)return;
   double mpp=MoneyPerPricePerLot();
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxRisk=AccountInfoDouble(ACCOUNT_BALANCE)*(InpMaxRiskPerTradePct/100.0);
   double riskAtMin=slDist*mn*mpp;
   if(riskAtMin>maxRisk){
      if(InpCapStopToRisk){ if(mn*mpp>0) slDist=maxRisk/(mn*mpp); }   // tighten stop so min lot fits the cap
      else { g_cRiskSkip++; return; }                                // otherwise skip too-risky trade
   }
   double lot=CalcLot(slDist); if(lot<=0){ g_cRiskSkip++; return; }
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double sl=ask-slDist;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg);
   if(trade.Buy(lot,_Symbol,0,sl,0)){ g_nBuy++; }
   else PrintFormat("[DTREND] BUY_FAIL rc=%u %s",trade.ResultRetcode(),trade.ResultRetcodeDescription());
}
double OnTester(){
   PrintFormat("[DTREND] buys=%d exits=%d flatDown=%d chopADX=%d htfSkip=%d chopIdxSkip=%d guardBlock=%d riskSkip=%d halted=%s",
               g_nBuy,g_nExit,g_cFlatDown,g_cChop,g_cHTF,g_cChopIdx,g_cGuard,g_cRiskSkip,(g_halted?"YES":"no"));
   int h=FileOpen("ck_gold_dtrend_trades.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit"); HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h); }
   return(0.0);
}
void OnTick(){
   // static-DD hard halt (GFT protection)
   if(InpUseStaticDD && !g_halted && EquityDDpctFromInit()>=InpStaticDDStopPct){
      g_halted=true; CloseAll("staticDD"); Print("[DTREND] STATIC-DD HALT hit");
   }
   if(g_halted){ if(MyPositions()>0) CloseAll("halted"); return; }

   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) NewDay();

   // daily-loss stop: flat + no new trades for the day
   bool dayBlocked = (InpUseDailyLoss && DayLossPct()>=InpDailyLossPct);
   if(dayBlocked && MyPositions()>0){ CloseAll("dailyloss"); }

   TrailStop();
   if(!IsNewSigBar())return;

   bool bull=IsBull();
   // exit: not bull -> go flat (long-only never shorts)
   if(MyPositions()>0){ if(!bull){ CloseMyLong("flat"); g_cFlatDown++; } return; }

   // entries
   if(dayBlocked){ g_cGuard++; return; }
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ g_cSpread++; return; }
   if(InpUseRegime && ADXreg() < InpADXTrendMin){ g_cChop++; return; }   // CHOP -> stand down, no new trade
   if(InpUseHTFtrend && !HTFbull()){ g_cHTF++; return; }                 // higher-TF not bullish -> skip counter-trend long
   if(InpUseChop && !NotChoppy()){ g_cChopIdx++; return; }               // Choppiness Index high -> consolidating -> stand down
   if(bull) OpenLong();
}
//+------------------------------------------------------------------+

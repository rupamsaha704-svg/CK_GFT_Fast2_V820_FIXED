//+------------------------------------------------------------------+
//|  CK_GOLD_MEM.mq5 - fade with LOSS MEMORY (learns from mistakes).  |
//|  Base = intraday Bollinger fade in ranging (ADX<max).            |
//|  Diagnosis (Apr20-Sep2): the loss came ENTIRELY from RE-ENTERING  |
//|  the SAME zone that had just lost. So: remember recent losing     |
//|  {price-zone, direction}. If a new signal falls in a recent same- |
//|  direction loss zone -> SKIP it (action 0) or take the OPPOSITE   |
//|  side (action 1 = FLIP). Goal: cut the repeated-SL bleed in chop. |
//|  Risk auto-capped (~%/trade) + GFT static-DD + daily-loss guards. |
//+------------------------------------------------------------------+
#property copyright "CK GOLD MEM"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic          = 20260933;
input ENUM_TIMEFRAMES InpTF    = PERIOD_M15;
input int    InpBBPeriod       = 20;
input double InpBBDev          = 2.0;
input int    InpRSIPeriod      = 2;
input double InpRSIBuy         = 10.0;
input double InpRSISell        = 90.0;
input bool   InpUseRSI         = true;
input int    InpADXPeriod      = 14;
input double InpADXMax         = 25.0;
input bool   InpAllowShort     = true;
input bool   InpReverse        = false;
//--- LOSS MEMORY (the "learn from mistakes" core) ---
input bool   InpUseMem         = true;
input int    InpMemAction      = 0;            // 0 = SKIP repeat-loss zone, 1 = FLIP to opposite side
input double InpMemBandATR     = 1.0;          // "same zone" = within this*ATR of a past loss
input double InpMemHours       = 36.0;         // remember losses for this many hours
input double InpFlipRR         = 1.5;          // TP:SL for a flipped trade
//--- stops / sizing ---
input int    InpATRPeriod      = 14;
input double InpSL_ATR         = 1.5;
input double InpTPmode         = 0;
input int    InpMaxTradesPerDay= 6;
input double InpRiskPercent    = 1.0;
input double InpMaxLot         = 0.50;
input double InpMaxRiskPerTradePct = 3.0;
input bool   InpCapStopToRisk  = true;
input double InpMaxSpreadPrice = 1.00;
//--- GFT guards ---
input bool   InpUseDailyLoss   = true;
input double InpDailyLossPct   = 5.0;
input bool   InpUseStaticDD    = true;
input double InpStaticDDStopPct= 8.0;

int      hBB,hADX,hRSI,hATR;
datetime g_barTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_initBal=0;
bool     g_halted=false;
int      g_tradesToday=0;
string   GK_INIT,GK_DAY,GK_BAL,GK_TRD;
int      g_nBuy=0,g_nSell=0,g_cRange=0,g_cSpread=0,g_cRisk=0;
// --- loss memory ---
#define  MEMSZ 512
double   memPrice[MEMSZ]; int memDir[MEMSZ]; datetime memT[MEMSZ]; int memHead=0,memN=0;
bool     g_hadPos=false; double g_openPrice=0; int g_openDir=0;
int      g_cMemSkip=0,g_cMemFlip=0;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hBB =iBands(_Symbol,InpTF,InpBBPeriod,0,InpBBDev,PRICE_CLOSE);
   hADX=iADX(_Symbol,InpTF,InpADXPeriod);
   hRSI=iRSI(_Symbol,InpTF,InpRSIPeriod,PRICE_CLOSE);
   hATR=iATR(_Symbol,InpTF,InpATRPeriod);
   if(hBB==INVALID_HANDLE||hADX==INVALID_HANDLE||hRSI==INVALID_HANDLE||hATR==INVALID_HANDLE)return(INIT_FAILED);
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_INIT="ckmem_init_"+scope; GK_DAY="ckmem_day_"+scope; GK_BAL="ckmem_bal_"+scope; GK_TRD="ckmem_trd_"+scope;
   if(GlobalVariableCheck(GK_INIT)) g_initBal=GlobalVariableGet(GK_INIT);
   else { g_initBal=AccountInfoDouble(ACCOUNT_BALANCE); GlobalVariableSet(GK_INIT,g_initBal); }
   LoadOrResetDaily();
   PrintFormat("[MEM] useMem=%s action=%d bandATR=%.2f hours=%.0f TF=%d ADXmax=%.0f",
               (InpUseMem?"Y":"N"),InpMemAction,InpMemBandATR,InpMemHours,(int)InpTF,InpADXMax);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ IndicatorRelease(hBB);IndicatorRelease(hADX);IndicatorRelease(hRSI);IndicatorRelease(hATR); }

double BBup(){ double b[]; if(CopyBuffer(hBB,1,1,1,b)<=0)return(0); return(b[0]); }
double BBlo(){ double b[]; if(CopyBuffer(hBB,2,1,1,b)<=0)return(0); return(b[0]); }
double BBmi(){ double b[]; if(CopyBuffer(hBB,0,1,1,b)<=0)return(0); return(b[0]); }
double ADXv(){ double b[]; if(CopyBuffer(hADX,0,1,1,b)<=0)return(0); return(b[0]); }
double RSIv(){ double b[]; if(CopyBuffer(hRSI,0,1,1,b)<=0)return(0); return(b[0]); }
double ATRv(){ double b[]; if(CopyBuffer(hATR,0,1,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,InpTF,0); if(t!=g_barTime){ g_barTime=t; return(true);} return(false); }

void LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0); datetime gday=(datetime)GlobalVariableGet(GK_DAY);
   if(gday==today && today>0){ g_dayStart=today; g_dayStartBal=GlobalVariableGet(GK_BAL); g_tradesToday=(int)GlobalVariableGet(GK_TRD); }
   else { g_dayStart=today; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)today); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }
}
void NewDay(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)g_dayStart); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }

int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
double MoneyPerPricePerLot(){ double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE); double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); double bt=(ts>0)?tv/ts:0.0; if(cs>0)return(cs); return(bt); }
double CalcLot(double slDist){
   double mpp=MoneyPerPricePerLot(); if(mpp<=0||slDist<=0)return(0);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney=bal*(InpRiskPercent/100.0); double maxRisk=bal*(InpMaxRiskPerTradePct/100.0);
   if(riskMoney>maxRisk) riskMoney=maxRisk;
   double lot=riskMoney/(slDist*mpp);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathFloor(lot/st)*st;
   if(lot<mn){ if(slDist*mn*mpp>maxRisk) return(0); lot=mn; }
   if(lot>InpMaxLot) lot=InpMaxLot; if(mx>0&&lot>mx)lot=mx;
   return(lot);
}
double EquityDDpctFromInit(){ if(g_initBal<=0)return(0); return(100.0*(g_initBal-AccountInfoDouble(ACCOUNT_EQUITY))/g_initBal); }
double DayLossPct(){ if(g_dayStartBal<=0)return(0); return(100.0*(g_dayStartBal-AccountInfoDouble(ACCOUNT_EQUITY))/g_dayStartBal); }
void CloseAll(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol) trade.PositionClose(tk); } }

//--- loss memory helpers ---
void PushMem(double price,int dir){
   memPrice[memHead]=price; memDir[memHead]=dir; memT[memHead]=TimeCurrent();
   memHead=(memHead+1)%MEMSZ; if(memN<MEMSZ) memN++;
}
bool RecentLoss(double price,int dir,double atr){
   if(atr<=0) return(false);
   double band=InpMemBandATR*atr; datetime now=TimeCurrent();
   for(int i=0;i<memN;i++){
      if(memDir[i]!=dir) continue;
      if((now-memT[i]) > (long)(InpMemHours*3600)) continue;
      if(MathAbs(price-memPrice[i])<=band) return(true);
   }
   return(false);
}
double LastClosedProfit(){
   if(!HistorySelect(TimeCurrent()-30*24*3600,TimeCurrent()+60)) return(0);
   int total=HistoryDealsTotal();
   for(int i=total-1;i>=0;i--){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=InpMagic)continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
      return(HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION));
   }
   return(0);
}

void OpenTrade(bool isBuy,double tp){
   double atr=ATRv(); if(atr<=0)return; double slDist=InpSL_ATR*atr; if(slDist<=0)return;
   double mpp=MoneyPerPricePerLot(); double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxRisk=AccountInfoDouble(ACCOUNT_BALANCE)*(InpMaxRiskPerTradePct/100.0);
   if(slDist*mn*mpp>maxRisk){ if(InpCapStopToRisk){ if(mn*mpp>0) slDist=maxRisk/(mn*mpp); } else { g_cRisk++; return; } }
   double lot=CalcLot(slDist); if(lot<=0){ g_cRisk++; return; }
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(isBuy){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double sl=NormalizeDouble(ask-slDist,dg); double t=NormalizeDouble(tp,dg); if(t<=ask) t=0; if(trade.Buy(lot,_Symbol,0,sl,t)){ g_nBuy++; g_tradesToday++; GlobalVariableSet(GK_TRD,g_tradesToday); g_openPrice=ask; g_openDir=1; } }
   else       { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double sl=NormalizeDouble(bid+slDist,dg); double t=NormalizeDouble(tp,dg); if(t>=bid) t=0; if(trade.Sell(lot,_Symbol,0,sl,t)){ g_nSell++; g_tradesToday++; GlobalVariableSet(GK_TRD,g_tradesToday); g_openPrice=bid; g_openDir=-1; } }
}
double OnTester(){
   PrintFormat("[MEM] buys=%d sells=%d memSkip=%d memFlip=%d rangeSkip=%d riskSkip=%d halted=%s",
               g_nBuy,g_nSell,g_cMemSkip,g_cMemFlip,g_cRange,g_cRisk,(g_halted?"Y":"n"));
   int h=FileOpen("ck_gold_mem_trades.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit"); HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h); }
   return(0.0);
}
void OnTick(){
   if(InpUseStaticDD && !g_halted && EquityDDpctFromInit()>=InpStaticDDStopPct){ g_halted=true; CloseAll(); Print("[MEM] STATIC-DD HALT"); }
   if(g_halted){ if(MyPositions()>0)CloseAll(); return; }
   // detect our position closing -> if it lost, remember the zone+direction
   int cur=MyPositions();
   if(g_hadPos && cur==0){
      double pl=LastClosedProfit();
      if(pl<0.0 && g_openDir!=0) PushMem(g_openPrice,g_openDir);
      g_openDir=0;
   }
   g_hadPos=(cur>0);

   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) NewDay();
   bool dayBlocked=(InpUseDailyLoss && DayLossPct()>=InpDailyLossPct);
   if(dayBlocked && MyPositions()>0) CloseAll();
   if(!IsNewBar())return;
   if(MyPositions()>0)return;
   if(dayBlocked) return;
   if(g_tradesToday>=InpMaxTradesPerDay) return;
   double adx=ADXv(); if(adx<=0)return;
   if(adx>=InpADXMax){ g_cRange++; return; }
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ g_cSpread++; return; }
   double c1=iClose(_Symbol,InpTF,1); double up=BBup(),lo=BBlo(),mi=BBmi(); if(up<=0||lo<=0||mi<=0)return;
   double rsi=RSIv(); double atr2=ATRv(); double sld=InpSL_ATR*atr2;
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(!InpReverse){
      double tpBuy  = (InpTPmode==0)? mi : up;
      double tpSell = (InpTPmode==0)? mi : lo;
      if(c1<lo && (!InpUseRSI || rsi<=InpRSIBuy)){
         if(InpUseMem && RecentLoss(ask,1,atr2)){
            if(InpMemAction==0){ g_cMemSkip++; return; }
            else { g_cMemFlip++; OpenTrade(false, bid-InpFlipRR*sld); return; }   // FLIP: sell instead
         }
         OpenTrade(true,tpBuy); return;
      }
      if(InpAllowShort && c1>up && (!InpUseRSI || rsi>=InpRSISell)){
         if(InpUseMem && RecentLoss(bid,-1,atr2)){
            if(InpMemAction==0){ g_cMemSkip++; return; }
            else { g_cMemFlip++; OpenTrade(true, ask+InpFlipRR*sld); return; }    // FLIP: buy instead
         }
         OpenTrade(false,tpSell); return;
      }
   } else {
      if(c1>up) { OpenTrade(true, ask+2.0*sld); return; }
      if(InpAllowShort && c1<lo) { OpenTrade(false, bid-2.0*sld); return; }
   }
}
//+------------------------------------------------------------------+

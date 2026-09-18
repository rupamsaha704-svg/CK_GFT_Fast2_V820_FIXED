//+------------------------------------------------------------------+
//|  CK_GOLD_CHOP.mq5 - CHOP-mode: liquidity sweep + reversal candle. |
//|  User's idea: in chop, wait for a SWEEP of a recent swing hi/lo   |
//|  (liquidity grab) then a REVERSAL candle closing back inside      |
//|  (aggression / high-vol) -> fade the sweep back into the range.   |
//|  Management BRAIN: after +BE_R move SL to breakeven; book a       |
//|  PARTIAL at TP1 if lot allows (full TP may not hit); runner to    |
//|  TP_R. Only active when higher-TF ADX < max (chop regime).        |
//|  Risk auto-capped + GFT static-DD/daily guards.                   |
//+------------------------------------------------------------------+
#property copyright "CK GOLD CHOP"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic          = 20260934;
input ENUM_TIMEFRAMES InpTF    = PERIOD_M15;   // entry timeframe
//--- chop regime gate ---
input ENUM_TIMEFRAMES InpRegimeTF = PERIOD_H4;
input int    InpADXPeriod      = 14;
input double InpADXMaxChop     = 25.0;         // trade ONLY when ADX(RegimeTF) < this (chop)
//--- sweep + reversal ---
input int    InpSwingLookback  = 12;           // bars for the prior swing hi/lo that gets swept
input double InpSweepMinATR    = 0.10;         // sweep must exceed the prior extreme by >= this*ATR
input double InpRevBodyATR     = 0.30;         // reversal candle range >= this*ATR (aggression/high-vol)
input bool   InpAllowShort     = true;
input int    InpATRPeriod      = 14;
input double InpSLbufATR       = 0.20;         // SL placed this far beyond the sweep extreme
//--- management brain ---
input double InpTP_R           = 1.5;          // final TP in R (reachable, not greedy)
input double InpBE_R           = 1.0;          // after this many R -> move SL to breakeven
input bool   InpUsePartial     = true;         // book a partial at BE_R if lot >= 2*minlot
input double InpPartialFrac    = 0.5;
input int    InpMaxTradesPerDay= 6;
//--- sizing ---
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

int      hADX,hATR;
datetime g_barTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_initBal=0;
bool     g_halted=false;
int      g_tradesToday=0;
string   GK_INIT,GK_DAY,GK_BAL,GK_TRD;
int      g_nBuy=0,g_nSell=0,g_cRange=0,g_cRisk=0,g_cSpread=0,g_cNoSetup=0;
// managed position state
ulong    g_curTicket=0; double g_entry=0,g_riskP=0; int g_dir=0; bool g_beDone=false,g_partDone=false;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hADX=iADX(_Symbol,InpRegimeTF,InpADXPeriod);
   hATR=iATR(_Symbol,InpTF,InpATRPeriod);
   if(hADX==INVALID_HANDLE||hATR==INVALID_HANDLE)return(INIT_FAILED);
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_INIT="ckchop_init_"+scope; GK_DAY="ckchop_day_"+scope; GK_BAL="ckchop_bal_"+scope; GK_TRD="ckchop_trd_"+scope;
   if(GlobalVariableCheck(GK_INIT)) g_initBal=GlobalVariableGet(GK_INIT);
   else { g_initBal=AccountInfoDouble(ACCOUNT_BALANCE); GlobalVariableSet(GK_INIT,g_initBal); }
   LoadOrResetDaily();
   PrintFormat("[CHOP] regimeTF=%d ADXmaxChop=%.0f swing=%d sweepATR=%.2f revATR=%.2f TP_R=%.1f BE_R=%.1f partial=%s",
               (int)InpRegimeTF,InpADXMaxChop,InpSwingLookback,InpSweepMinATR,InpRevBodyATR,InpTP_R,InpBE_R,(InpUsePartial?"Y":"N"));
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ IndicatorRelease(hADX); IndicatorRelease(hATR); }

double ADXv(){ double b[]; if(CopyBuffer(hADX,0,1,1,b)<=0)return(0); return(b[0]); }
double ATRv(){ double b[]; if(CopyBuffer(hATR,0,1,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,InpTF,0); if(t!=g_barTime){ g_barTime=t; return(true);} return(false); }

void LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0); datetime gday=(datetime)GlobalVariableGet(GK_DAY);
   if(gday==today && today>0){ g_dayStart=today; g_dayStartBal=GlobalVariableGet(GK_BAL); g_tradesToday=(int)GlobalVariableGet(GK_TRD); }
   else { g_dayStart=today; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)today); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }
}
void NewDay(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)g_dayStart); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }

int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
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

void OpenSweep(bool isBuy,double slPrice){
   double atr=ATRv(); if(atr<=0)return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double entry=isBuy?ask:bid; double slDist=MathAbs(entry-slPrice); if(slDist<=0)return;
   double mpp=MoneyPerPricePerLot(); double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxRisk=AccountInfoDouble(ACCOUNT_BALANCE)*(InpMaxRiskPerTradePct/100.0);
   if(slDist*mn*mpp>maxRisk){ if(InpCapStopToRisk){ // tighten SL toward entry to fit the risk cap
         double allow=maxRisk/(mn*mpp); slPrice = isBuy ? entry-allow : entry+allow; slDist=allow; }
      else { g_cRisk++; return; } }
   double lot=CalcLot(slDist); if(lot<=0){ g_cRisk++; return; }
   double tp = isBuy ? entry+InpTP_R*slDist : entry-InpTP_R*slDist;
   slPrice=NormalizeDouble(slPrice,dg); tp=NormalizeDouble(tp,dg);
   bool ok = isBuy ? trade.Buy(lot,_Symbol,0,slPrice,tp) : trade.Sell(lot,_Symbol,0,slPrice,tp);
   if(ok){ if(isBuy)g_nBuy++; else g_nSell++; g_tradesToday++; GlobalVariableSet(GK_TRD,g_tradesToday); }
}

void ManagePosition(){
   ulong tk=GetMyTicket();
   if(tk==0){ g_curTicket=0; return; }
   if(tk!=g_curTicket){ // new position -> capture state
      if(!PositionSelectByTicket(tk))return;
      g_curTicket=tk; g_entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL); g_riskP=MathAbs(g_entry-sl);
      g_dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      g_beDone=false; g_partDone=false; return;
   }
   if(g_riskP<=0)return; if(!PositionSelectByTicket(tk))return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double px=(g_dir>0)?bid:ask;
   double progR=(g_dir>0)?(px-g_entry)/g_riskP:(g_entry-px)/g_riskP;
   // partial at BE_R
   if(InpUsePartial && !g_partDone && progR>=InpBE_R){
      double vol=PositionGetDouble(POSITION_VOLUME);
      double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      double cvol=vol*InpPartialFrac; if(st>0) cvol=MathFloor(cvol/st)*st;
      if(cvol>=mn && (vol-cvol)>=mn){ if(trade.PositionClosePartial(tk,cvol)) g_partDone=true; }
   }
   // breakeven after BE_R
   if(!g_beDone && progR>=InpBE_R){
      double sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      double be=(g_dir>0)?g_entry+2*_Point:g_entry-2*_Point; be=NormalizeDouble(be,dg);
      bool improve=(g_dir>0)?(sl<be):(sl>be);
      if(improve && trade.PositionModify(tk,be,tp)) g_beDone=true;
   }
}
double OnTester(){
   PrintFormat("[CHOP] buys=%d sells=%d rangeSkip=%d riskSkip=%d spreadSkip=%d halted=%s",g_nBuy,g_nSell,g_cRange,g_cRisk,g_cSpread,(g_halted?"Y":"n"));
   int h=FileOpen("ck_gold_chop_trades.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit"); HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h); }
   return(0.0);
}
void OnTick(){
   if(InpUseStaticDD && !g_halted && EquityDDpctFromInit()>=InpStaticDDStopPct){ g_halted=true; CloseAll(); Print("[CHOP] STATIC-DD HALT"); }
   if(g_halted){ if(MyPositions()>0)CloseAll(); return; }
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) NewDay();
   bool dayBlocked=(InpUseDailyLoss && DayLossPct()>=InpDailyLossPct);
   if(dayBlocked && MyPositions()>0) CloseAll();
   ManagePosition();
   if(!IsNewBar())return;
   if(MyPositions()>0)return;
   if(dayBlocked) return;
   if(g_tradesToday>=InpMaxTradesPerDay) return;
   if(ADXv()>=InpADXMaxChop){ g_cRange++; return; }   // only in chop
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ g_cSpread++; return; }
   double atr=ATRv(); if(atr<=0)return;
   double o1=iOpen(_Symbol,InpTF,1),c1=iClose(_Symbol,InpTF,1),h1=iHigh(_Symbol,InpTF,1),l1=iLow(_Symbol,InpTF,1);
   int idxLo=iLowest(_Symbol,InpTF,MODE_LOW,InpSwingLookback,2);
   int idxHi=iHighest(_Symbol,InpTF,MODE_HIGH,InpSwingLookback,2);
   if(idxLo<0||idxHi<0)return;
   double swingLow=iLow(_Symbol,InpTF,idxLo), swingHigh=iHigh(_Symbol,InpTF,idxHi);
   double body=MathAbs(c1-o1), rng=h1-l1;
   // BUY: swept below swingLow then closed back above with a bullish aggressive candle
   if(l1 < swingLow-InpSweepMinATR*atr && c1>swingLow && c1>o1 && rng>=InpRevBodyATR*atr){
      double sl=l1-InpSLbufATR*atr; OpenSweep(true,sl); return;
   }
   // SELL: swept above swingHigh then closed back below with a bearish aggressive candle
   if(InpAllowShort && h1 > swingHigh+InpSweepMinATR*atr && c1<swingHigh && c1<o1 && rng>=InpRevBodyATR*atr){
      double sl=h1+InpSLbufATR*atr; OpenSweep(false,sl); return;
   }
   g_cNoSetup++;
}
//+------------------------------------------------------------------+

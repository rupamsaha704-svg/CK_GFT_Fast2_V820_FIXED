//+------------------------------------------------------------------+
//|  CK_TRAPBOX_DKT_v3.mq5                                            |
//|  Trapbox ENTRY (session first-M15-candle box breakout) kept,      |
//|  but a PRINCIPLED opening-range-breakout EXIT (fixes v1/v2's      |
//|  broken risk:reward that caused the loss despite 73% win):        |
//|    - SL = the OPPOSITE box edge (range-based, volatility-adaptive)|
//|    - TP = entry +/- InpRR * risk    (single pre-registered RR)    |
//|  Risk defined by the box => reward scales with risk (clean R).    |
//|  DISCIPLINE: sealed holdout 2026.07-08 is NOT used here.          |
//|  Risk-based lot, HARD 0.09 cap. OnTester -> ck_trapbox3_trades.csv.|
//+------------------------------------------------------------------+
#property copyright "CK TRAPBOX DKT v3"
#property version   "3.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic            = 20260904;
input double InpRiskPercent      = 0.5;
input double InpMaxLot            = 0.09;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input int    InpMaxSpreadPoints  = 60;
input ENUM_TIMEFRAMES InpBoxTF   = PERIOD_M15;
input int    InpAsiaStart        = 4;
input int    InpLondonStart      = 10;
input int    InpNYStart          = 15;
input int    InpWatchBars        = 20;
input bool   InpTradeAsia        = true;
input bool   InpTradeLondon      = true;
input bool   InpTradeNY          = true;
input bool   InpAllowBuy         = true;
input bool   InpAllowSell        = true;
input double InpRR               = 1.5;      // TP = InpRR * risk (risk = entry->opposite box edge)
input double InpMaxRiskPips      = 300.0;    // skip if risk exceeds this (too-wide box); XAU pip=0.1

datetime lastBarTime=0, g_dayStart=0;
double   g_dayStartBal=0, g_oneR_money=0;
int      g_tradesToday=0;
bool     g_boxSet=false, g_boxTraded=false;
double   g_boxHigh=0, g_boxLow=0;
int      g_watchLeft=0;

double Pip(){ return(0.1); }

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   ResetDaily();
   return(INIT_SUCCEEDED);
}
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }
void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; }
double RealizedRToday(){ if(g_oneR_money<=0)return(0); return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }

double LotForRisk(double riskMoney,double slDist)
{
   if(slDist<=0)return(0);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0)return(0);
   double lpl=(slDist/ts)*tv; if(lpl<=0)return(0);
   double lots=riskMoney/lpl;
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathFloor(lots/st)*st; if(lots<mn)lots=mn; if(lots>InpMaxLot)lots=InpMaxLot;
   return(lots);
}
void OpenTrade(bool isBuy,double sl,double tp)
{
   double px=isBuy?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double risk=isBuy?(px-sl):(sl-px); if(risk<=0)return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   bool ok=isBuy?trade.Buy(lots,_Symbol,0,sl,tp):trade.Sell(lots,_Symbol,0,sl,tp);
   if(ok) g_tradesToday++;
}
bool IsBoxCandle(datetime bt)
{
   MqlDateTime dt; TimeToStruct(bt,dt);
   if(dt.min!=0) return(false);
   if(InpTradeAsia   && dt.hour==InpAsiaStart)   return(true);
   if(InpTradeLondon && dt.hour==InpLondonStart) return(true);
   if(InpTradeNY     && dt.hour==InpNYStart)     return(true);
   return(false);
}
double OnTester()
{
   HistorySelect(0,TimeCurrent());
   int total=HistoryDealsTotal();
   ulong ids[]; datetime ins[]; int nin=0;
   ArrayResize(ids,total); ArrayResize(ins,total);
   for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
      ids[nin]=(ulong)HistoryDealGetInteger(tk,DEAL_POSITION_ID);
      ins[nin]=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); nin++;
   }
   int h=FileOpen("ck_trapbox3_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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
void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();
   if(!IsNewBar()) return;
   datetime bt = iTime(_Symbol,InpBoxTF,1);
   double bhigh = iHigh(_Symbol,InpBoxTF,1), blow = iLow(_Symbol,InpBoxTF,1), bclose = iClose(_Symbol,InpBoxTF,1);

   if(IsBoxCandle(bt)){ g_boxHigh=bhigh; g_boxLow=blow; g_boxSet=true; g_boxTraded=false; g_watchLeft=InpWatchBars; return; }
   if(!g_boxSet) return;
   if(g_watchLeft<=0){ g_boxSet=false; return; }
   g_watchLeft--;
   if(MyPositions()>0 || g_boxTraded) return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return;
   if(!TradingAllowed()) return;

   double pip=Pip();
   // BUY breakout: SL at opposite (low) edge, TP = InpRR * risk
   if(InpAllowBuy && bclose>g_boxHigh){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=g_boxLow; double risk=ask-sl;
      if(risk>0 && (risk/pip)<=InpMaxRiskPips){ OpenTrade(true, sl, ask+InpRR*risk); g_boxTraded=true; }
      return;
   }
   // SELL breakdown: SL at opposite (high) edge
   if(InpAllowSell && bclose<g_boxLow){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=g_boxHigh; double risk=sl-bid;
      if(risk>0 && (risk/pip)<=InpMaxRiskPips){ OpenTrade(false, sl, bid-InpRR*risk); g_boxTraded=true; }
      return;
   }
}
//+------------------------------------------------------------------+

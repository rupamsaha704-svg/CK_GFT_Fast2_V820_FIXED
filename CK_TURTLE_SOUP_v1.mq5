//+------------------------------------------------------------------+
//|  CK_TURTLE_SOUP_v1.mq5                                            |
//|  Objective "Turtle Soup" = liquidity-sweep / false-breakout       |
//|  REVERSAL (the only mechanical kernel from the PDF).              |
//|   - priorHigh/Low = highest/lowest of the last InpLookback bars   |
//|     (ending before the just-closed bar).                          |
//|   - SELL: last bar's HIGH swept ABOVE priorHigh but CLOSED back   |
//|     below it (false breakout up) -> fade short.                   |
//|   - BUY : last bar's LOW swept BELOW priorLow but CLOSED back     |
//|     above it -> fade long.                                        |
//|   - SL beyond the sweep extreme (+ATR buffer); TP = InpRR * risk. |
//|  Pre-registered defaults, no tuning. Risk-based lot, 0.09 cap.    |
//|  Sealed holdout 2026.07-08 NOT used here.                         |
//|  OnTester -> Common\Files\ck_turtle_trades.csv (entry time,profit)|
//+------------------------------------------------------------------+
#property copyright "CK TURTLE SOUP v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic            = 20260905;
input double InpRiskPercent      = 0.5;
input double InpMaxLot            = 0.09;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input int    InpMaxSpreadPoints  = 60;
input int    InpLookback         = 20;    // swing lookback for the liquidity level
input double InpBufferATR        = 0.10;  // SL buffer beyond the sweep extreme (x ATR)
input double InpRR               = 2.0;   // TP = InpRR * risk
input double InpMaxSL_ATR        = 3.0;   // skip if the sweep/stop is wider than this (x ATR)
input bool   InpAllowBuy         = true;
input bool   InpAllowSell        = true;

int      hAtr;
datetime lastBarTime=0, g_dayStart=0;
double   g_dayStartBal=0, g_oneR_money=0;
int      g_tradesToday=0;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   if(hAtr==INVALID_HANDLE) return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
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
   int h=FileOpen("ck_turtle_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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
   if(MyPositions()>0) return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return;
   if(!TradingAllowed()) return;

   double atr=ATR(); if(atr<=0) return;
   double buf=InpBufferATR*atr;

   int hh=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpLookback,2);
   int ll=iLowest (_Symbol,PERIOD_CURRENT,MODE_LOW ,InpLookback,2);
   if(hh<0||ll<0) return;
   double priorHigh=iHigh(_Symbol,PERIOD_CURRENT,hh);
   double priorLow =iLow (_Symbol,PERIOD_CURRENT,ll);

   double h1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double l1=iLow (_Symbol,PERIOD_CURRENT,1);
   double c1=iClose(_Symbol,PERIOD_CURRENT,1);

   // SELL: swept ABOVE priorHigh then closed back BELOW (false breakout up)
   if(InpAllowSell && h1>priorHigh && c1<priorHigh){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=h1+buf; double risk=sl-bid;
      if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenTrade(false, sl, bid-InpRR*risk); return; }
   }
   // BUY: swept BELOW priorLow then closed back ABOVE (false breakout down)
   if(InpAllowBuy && l1<priorLow && c1>priorLow){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=l1-buf; double risk=ask-sl;
      if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenTrade(true, sl, ask+InpRR*risk); return; }
   }
}
//+------------------------------------------------------------------+

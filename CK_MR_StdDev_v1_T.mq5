//+------------------------------------------------------------------+
//|                                          CK_MR_StdDev_v1.mq5      |
//|  STRATEGY #2 (agent-2): Std-Dev / z-score MEAN-REVERSION (XAUUSD).|
//|                                                                    |
//|  Opposite profile to the v23 trend agent: designed to MAKE money  |
//|  in RANGE / choppy regimes where trend bleeds -> diversification  |
//|  that should lower the COMBINED drawdown toward the 9% target.     |
//|                                                                    |
//|  A LONG needs (mirror for SHORT):                                  |
//|   z = (close - SMA(n)) / StdDev(n)  <=  -EntryZ   (over-sold)      |
//|   AND a bullish reversal bar (close>open) = start of the bounce    |
//|  SL: EntrySL_ATR * ATR beyond the signal bar low (tight).          |
//|  TP: the mean (SMA) — the natural mean-reversion target.           |
//|  Risk-based sizing, HARD MaxLot cap 0.09, one position at a time,  |
//|  daily loss/profit/trade gates. Few params (anti-overfit).         |
//|  OnTester dumps per-trade P&L to Common\Files\ck_mr_trades.csv     |
//|  for Vibe quantlib validation (CPCV / Deflated Sharpe / PBO).      |
//+------------------------------------------------------------------+
#property copyright "CK MeanReversion StdDev v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE / RISK ===
input long   InpMagic            = 20260901;
input double InpRiskPercent      = 0.5;
input double InpMaxLot            = 0.09;   // HARD CAP
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input int    InpMaxSpreadPoints  = 60;
//=== MEAN-REVERSION PARAMS ===
input int    InpMAPeriod         = 20;      // SMA / StdDev lookback
input double InpEntryZ           = 2.0;     // enter when |z| >= this
input double InpEntrySL_ATR      = 1.5;     // SL beyond signal bar by this * ATR
input double InpMaxSL_ATR        = 3.0;     // reject too-wide stops
input double InpMinTP_ATR        = 0.5;     // require TP(mean) at least this far (else skip)

int      hAtr, hMA, hStd;
datetime lastBarTime=0, g_dayStart=0;
double   g_dayStartBal=0, g_oneR_money=0;
int      g_tradesToday=0;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   hMA =iMA(_Symbol,PERIOD_CURRENT,InpMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   hStd=iStdDev(_Symbol,PERIOD_CURRENT,InpMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   if(hAtr==INVALID_HANDLE||hMA==INVALID_HANDLE||hStd==INVALID_HANDLE) return(INIT_FAILED);
   ResetDaily(); return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); if(hMA!=INVALID_HANDLE)IndicatorRelease(hMA); if(hStd!=INVALID_HANDLE)IndicatorRelease(hStd); }

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
double MA(int s){ double b[]; if(CopyBuffer(hMA,0,s,1,b)<=0)return(0); return(b[0]); }
double STD(int s){ double b[]; if(CopyBuffer(hStd,0,s,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }

void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; }
double RealizedRToday(){ if(g_oneR_money<=0)return(0); return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }

int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }

double LotForRisk(double riskMoney,double slDist){ if(slDist<=0)return(0); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tv<=0||ts<=0)return(0); double lpl=(slDist/ts)*tv; if(lpl<=0)return(0); double lots=riskMoney/lpl; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); lots=MathFloor(lots/st)*st; if(lots<mn)lots=mn; if(lots>InpMaxLot)lots=InpMaxLot; return(lots); }

void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Buy(lots,_Symbol,0,sl,tp)) g_tradesToday++; }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Sell(lots,_Symbol,0,sl,tp)) g_tradesToday++; }

double OnTester()
{
   // _T variant: log ENTRY time + net profit (time,profit) so the strict pipeline + monthly/hour tools work.
   HistorySelect(0,TimeCurrent());
   int total=HistoryDealsTotal();
   ulong ids[]; datetime ins[]; int nin=0;
   ArrayResize(ids,total); ArrayResize(ins,total);
   for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
      ids[nin]=(ulong)HistoryDealGetInteger(tk,DEAL_POSITION_ID);
      ins[nin]=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
      nin++;
   }
   int h=FileOpen("ck_mrT_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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

   double atr=ATR(); if(atr<=0)return;
   double sma=MA(1), sd=STD(1); if(sd<=0)return;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1), o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double l1=iLow(_Symbol,PERIOD_CURRENT,1), h1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double z=(c1-sma)/sd;

   // LONG: over-sold + bullish reversal bar; TP = mean (SMA)
   if(z<=-InpEntryZ && c1>o1){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=l1-InpEntrySL_ATR*atr; double risk=ask-sl;
      double tp=sma;
      if(risk>0 && risk<=InpMaxSL_ATR*atr && (tp-ask)>=InpMinTP_ATR*atr){ OpenBuy(sl,tp); return; }
   }
   // SHORT: over-bought + bearish reversal bar; TP = mean (SMA)
   if(z>=InpEntryZ && c1<o1){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=h1+InpEntrySL_ATR*atr; double risk=sl-bid;
      double tp=sma;
      if(risk>0 && risk<=InpMaxSL_ATR*atr && (bid-tp)>=InpMinTP_ATR*atr){ OpenSell(sl,tp); }
   }
}
//+------------------------------------------------------------------+

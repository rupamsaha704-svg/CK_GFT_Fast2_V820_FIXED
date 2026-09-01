//+------------------------------------------------------------------+
//|  CK_VDELTA_EMA_v1.mq5                                            |
//|  Tradeable port of "Volume Delta [hapharmonic]" SIGNAL:          |
//|   the indicator's actual signal = EMA(fast) crossing EMA(slow)    |
//|   CONFIRMED by volume (recent up-volume >= down-volume vs volMA). |
//|   (The buy/sell-volume delta bars are display-only.)             |
//|  Entry: confirmed crossover => BUY; crossunder => SELL.           |
//|  Exit : stop-and-reverse on opposite confirmed signal + ATR stop. |
//|  Risk-based lot, HARD 0.09 cap. OnTester -> ck_vdelta_trades.csv. |
//+------------------------------------------------------------------+
#property copyright "CK VDELTA EMA v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic            = 20260903;
input double InpRiskPercent      = 0.5;
input double InpMaxLot            = 0.09;
input int    InpMaxTradesPerDay  = 5;
input double InpDailyLossStopR   = 3.0;
input double InpDailyProfitStopR = 6.0;
input int    InpMaxSpreadPoints  = 60;
input int    InpEmaFast          = 12;
input int    InpEmaSlow          = 26;
input int    InpVolConfLen       = 6;
input bool   InpUseVolConf       = true;
input double InpSL_ATR           = 2.0;     // ATR-multiple safety stop
input double InpMaxSL_ATR        = 4.0;

int      hEmaF,hEmaS,hAtr;
datetime lastBarTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_oneR_money=0;
int      g_tradesToday=0;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hEmaF=iMA(_Symbol,PERIOD_CURRENT,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
   hEmaS=iMA(_Symbol,PERIOD_CURRENT,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
   hAtr =iATR(_Symbol,PERIOD_CURRENT,14);
   if(hEmaF==INVALID_HANDLE||hEmaS==INVALID_HANDLE||hAtr==INVALID_HANDLE)return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hEmaF!=INVALID_HANDLE)IndicatorRelease(hEmaF); if(hEmaS!=INVALID_HANDLE)IndicatorRelease(hEmaS); if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }

double EF(int s){ double b[]; if(CopyBuffer(hEmaF,0,s,1,b)<=0)return(0); return(b[0]); }
double ES(int s){ double b[]; if(CopyBuffer(hEmaS,0,s,1,b)<=0)return(0); return(b[0]); }
double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }
void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; }
double RealizedRToday(){ if(g_oneR_money<=0)return(0); return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(int &dir){ dir=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol){ dir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1; return(1);} } return(0); }
void CloseMine(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol) trade.PositionClose(tk); } }

// recent up-volume vs down-volume relative to its SMA (the indicator's isVolumeConfirmed)
bool VolConfirmed()
{
   if(!InpUseVolConf) return(true);
   long v[]; if(CopyTickVolume(_Symbol,PERIOD_CURRENT,1,InpVolConfLen,v)<=0) return(true);
   double sum=0; for(int i=0;i<InpVolConfLen;i++) sum+=(double)v[i];
   double ma=sum/InpVolConfLen;
   double up=0,dn=0; for(int i=0;i<InpVolConfLen;i++){ if((double)v[i]>ma) up+=(double)v[i]; else if((double)v[i]<ma) dn+=(double)v[i]; }
   return(up>=dn);
}

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
void OpenBuy()
{
   double atr=ATR(); if(atr<=0)return; double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double sl=ask-InpSL_ATR*atr; double risk=ask-sl; if(risk<=0||risk>InpMaxSL_ATR*atr)return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(trade.Buy(lots,_Symbol,0,NormalizeDouble(sl,dg),0)) g_tradesToday++;
}
void OpenSell()
{
   double atr=ATR(); if(atr<=0)return; double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=bid+InpSL_ATR*atr; double risk=sl-bid; if(risk<=0||risk>InpMaxSL_ATR*atr)return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(trade.Sell(lots,_Symbol,0,NormalizeDouble(sl,dg),0)) g_tradesToday++;
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
   int h=FileOpen("ck_vdelta_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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
   double f1=EF(1),s1=ES(1),f2=EF(2),s2=ES(2);
   if(f1==0||s1==0||f2==0||s2==0) return;
   bool crossUp   = (f2<=s2 && f1>s1);
   bool crossDown = (f2>=s2 && f1<s1);
   if(!crossUp && !crossDown) return;
   if(!VolConfirmed()) return;

   int dir; int have=MyPositions(dir);
   if(crossUp){
      if(have && dir<0) CloseMine();          // stop-and-reverse
      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)<=InpMaxSpreadPoints && TradingAllowed()){ int d2; if(MyPositions(d2)==0) OpenBuy(); }
   }
   else if(crossDown){
      if(have && dir>0) CloseMine();
      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)<=InpMaxSpreadPoints && TradingAllowed()){ int d2; if(MyPositions(d2)==0) OpenSell(); }
   }
}
//+------------------------------------------------------------------+

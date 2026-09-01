//+------------------------------------------------------------------+
//|  CK_TREND_ATR_v1.mq5                                             |
//|  Generic, instrument-agnostic TREND follower (complement to the  |
//|  Turtle mean-reversion test). Pre-registered, no tuning.         |
//|   - Entry: close[1] breaks ABOVE Donchian(InpDonchian) high ->buy|
//|            close[1] breaks BELOW Donchian(InpDonchian) low  ->sell|
//|   - Initial SL = InpSLatr * ATR. No fixed TP (ride the trend).   |
//|   - Manage: ATR trailing stop (InpTrailATR) + exit on opposite   |
//|            Donchian(InpExitDonchian) break.                      |
//|   - Risk-based lot, 0.09 cap. One position at a time.            |
//|  OnTester -> Common\Files\ck_trend_trades.csv (entry time,profit)|
//+------------------------------------------------------------------+
#property copyright "CK TREND ATR v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic           = 20260906;
input double InpRiskPercent     = 0.5;
input double InpMaxLot           = 0.09;
input int    InpMaxSpreadPoints  = 60;
input int    InpDonchian         = 20;    // breakout channel lookback
input int    InpExitDonchian     = 10;    // opposite channel for exit
input int    InpATRperiod        = 14;
input double InpSLatr            = 2.0;    // initial SL = x * ATR
input double InpTrailATR         = 3.0;    // trailing stop = x * ATR (0 = off)
input bool   InpAllowBuy         = true;
input bool   InpAllowSell        = true;

int      hAtr;
datetime lastBarTime=0;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,InpATRperiod);
   if(hAtr==INVALID_HANDLE) return(INIT_FAILED);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }

double ATRv(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }
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
void OpenTrade(bool isBuy,double sl)
{
   double px=isBuy?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double risk=isBuy?(px-sl):(sl-px); if(risk<=0)return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg);
   if(isBuy) trade.Buy(lots,_Symbol,0,sl,0); else trade.Sell(lots,_Symbol,0,sl,0);
}

void ManageOpen(double atr)
{
   if(atr<=0) return;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic||PositionGetString(POSITION_SYMBOL)!=_Symbol)continue;
      long   type=PositionGetInteger(POSITION_TYPE);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL=PositionGetDouble(POSITION_SL);
      double tp  =PositionGetDouble(POSITION_TP);
      int    dg  =(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      double stopsLvl=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      double c1=iClose(_Symbol,PERIOD_CURRENT,1);
      int    eh=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpExitDonchian,2);
      int    el=iLowest (_Symbol,PERIOD_CURRENT,MODE_LOW ,InpExitDonchian,2);
      double exitHigh=(eh>=0)?iHigh(_Symbol,PERIOD_CURRENT,eh):0;
      double exitLow =(el>=0)?iLow (_Symbol,PERIOD_CURRENT,el):0;

      if(type==POSITION_TYPE_BUY){
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         if(exitLow>0 && c1<exitLow){ trade.PositionClose(tk); continue; }
         if(InpTrailATR>0){
            double newSL=bid-InpTrailATR*atr;
            if(newSL>curSL && (bid-newSL)>=stopsLvl && newSL<bid)
               trade.PositionModify(tk,NormalizeDouble(newSL,dg),tp);
         }
      } else if(type==POSITION_TYPE_SELL){
         double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         if(exitHigh>0 && c1>exitHigh){ trade.PositionClose(tk); continue; }
         if(InpTrailATR>0){
            double newSL=ask+InpTrailATR*atr;
            if((curSL==0||newSL<curSL) && (newSL-ask)>=stopsLvl && newSL>ask)
               trade.PositionModify(tk,NormalizeDouble(newSL,dg),tp);
         }
      }
   }
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
   int h=FileOpen("ck_trend_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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
   double atr=ATRv();
   if(MyPositions()>0){ if(IsNewBar()) ManageOpen(atr); return; }
   if(!IsNewBar()) return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return;
   if(atr<=0) return;

   int hh=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpDonchian,2);
   int ll=iLowest (_Symbol,PERIOD_CURRENT,MODE_LOW ,InpDonchian,2);
   if(hh<0||ll<0) return;
   double donHigh=iHigh(_Symbol,PERIOD_CURRENT,hh);
   double donLow =iLow (_Symbol,PERIOD_CURRENT,ll);
   double c1=iClose(_Symbol,PERIOD_CURRENT,1);

   if(InpAllowBuy && c1>donHigh){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      OpenTrade(true, ask-InpSLatr*atr); return;
   }
   if(InpAllowSell && c1<donLow){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      OpenTrade(false, bid+InpSLatr*atr); return;
   }
}
//+------------------------------------------------------------------+

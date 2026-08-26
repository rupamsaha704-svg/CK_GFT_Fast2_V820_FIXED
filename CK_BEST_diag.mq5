//+------------------------------------------------------------------+
//|   CK_BEST_diag.mq5 = CK_GFT_BEST_Strategy + trade dump            |
//|   IDENTICAL logic (HA + EMA5>21>50 trend, SL 0.7ATR, trail 6ATR,  |
//|   compounding lot). Adds OnTester dump of "time,profit" to        |
//|   Common\Files\ck_best_trades.csv for Vibe validation + combining |
//|   with v23. Trades M5 internally. Run tester on M5.               |
//+------------------------------------------------------------------+
#property copyright "CK BEST diag"
#property version   "1.00"
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input long   InpMagic          = 20260730;
input double InpSLATR          = 0.7;
input double InpTrailATR       = 6.0;
input double InpBaseLot        = 0.06;
input int    InpMaxPositions   = 1;
input double InpDailyLossPct   = 0.04;
input double InpMaxLot         = 0.08;
input int    InpMaxSpread      = 50;
input int    InpEMAFast        = 5;
input int    InpEMAMid         = 21;
input int    InpEMASlow        = 50;
input int    InpATRPeriod      = 14;

int atrHandle, emaFastHandle, emaMidHandle, emaSlowHandle;
datetime lastBarTime=0, g_dayStart=0;
double g_dayStartBal=0, g_initialBal=0;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetAsyncMode(false); trade.SetMarginMode(); trade.SetTypeFillingBySymbol(_Symbol);
   atrHandle=iATR(_Symbol,PERIOD_M5,InpATRPeriod);
   emaFastHandle=iMA(_Symbol,PERIOD_M5,InpEMAFast,0,MODE_EMA,PRICE_CLOSE);
   emaMidHandle=iMA(_Symbol,PERIOD_M5,InpEMAMid,0,MODE_EMA,PRICE_CLOSE);
   emaSlowHandle=iMA(_Symbol,PERIOD_M5,InpEMASlow,0,MODE_EMA,PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE||emaFastHandle==INVALID_HANDLE||emaMidHandle==INVALID_HANDLE||emaSlowHandle==INVALID_HANDLE)return INIT_FAILED;
   g_initialBal=AccountInfoDouble(ACCOUNT_BALANCE); ResetDaily(); lastBarTime=iTime(_Symbol,PERIOD_M5,0);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){ if(atrHandle!=INVALID_HANDLE)IndicatorRelease(atrHandle); if(emaFastHandle!=INVALID_HANDLE)IndicatorRelease(emaFastHandle); if(emaMidHandle!=INVALID_HANDLE)IndicatorRelease(emaMidHandle); if(emaSlowHandle!=INVALID_HANDLE)IndicatorRelease(emaSlowHandle); }

double GetATR(){ double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(atrHandle,0,1,1,b)!=1)return 0; return b[0]; }
double GetEMAFast(){ double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(emaFastHandle,0,1,1,b)!=1)return 0; return b[0]; }
double GetEMAMid(){ double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(emaMidHandle,0,1,1,b)!=1)return 0; return b[0]; }
double GetEMASlow(){ double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(emaSlowHandle,0,1,1,b)!=1)return 0; return b[0]; }
bool IsHAGreen(){ double o1=iOpen(_Symbol,PERIOD_M5,1),h1=iHigh(_Symbol,PERIOD_M5,1),l1=iLow(_Symbol,PERIOD_M5,1),c1=iClose(_Symbol,PERIOD_M5,1); double o2=iOpen(_Symbol,PERIOD_M5,2),c2=iClose(_Symbol,PERIOD_M5,2),h2=iHigh(_Symbol,PERIOD_M5,2),l2=iLow(_Symbol,PERIOD_M5,2); double ha_c1=(o1+h1+l1+c1)/4; double ha_c2=(o2+h2+l2+c2)/4; double ha_o2=(o2+c2)/2; double ha_o1=(ha_o2+ha_c2)/2; return(ha_c1>ha_o1); }
bool IsHARed(){ double o1=iOpen(_Symbol,PERIOD_M5,1),h1=iHigh(_Symbol,PERIOD_M5,1),l1=iLow(_Symbol,PERIOD_M5,1),c1=iClose(_Symbol,PERIOD_M5,1); double o2=iOpen(_Symbol,PERIOD_M5,2),c2=iClose(_Symbol,PERIOD_M5,2),h2=iHigh(_Symbol,PERIOD_M5,2),l2=iLow(_Symbol,PERIOD_M5,2); double ha_c1=(o1+h1+l1+c1)/4; double ha_c2=(o2+h2+l2+c2)/4; double ha_o2=(o2+c2)/2; double ha_o1=(ha_o2+ha_c2)/2; return(ha_c1<ha_o1); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_M5,0); if(t<=0)return false; if(t!=lastBarTime){lastBarTime=t;return true;} return false; }
void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); }
int MyPositionCount(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return c; }
double CalcLot(double slDist){ if(slDist<=0)return 0; double bal=AccountInfoDouble(ACCOUNT_BALANCE); if(g_initialBal<=0)g_initialBal=bal; double lot=InpBaseLot*(bal/g_initialBal); lot=MathMin(lot,InpMaxLot); double vMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),vStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); if(vStep<=0)vStep=0.01; lot=MathFloor(lot/vStep)*vStep; if(lot<vMin)return 0; return NormalizeDouble(lot,2); }
void ManageTrailingStop(){ double atr=GetATR(); if(atr<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT); double minDist=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue; if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue;
      double curSL=PositionGetDouble(POSITION_SL); long posType=PositionGetInteger(POSITION_TYPE);
      if(posType==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double newSL=NormalizeDouble(bid-InpTrailATR*atr,dg); if(newSL>curSL&&newSL<bid&&(bid-newSL)>=minDist)trade.PositionModify(tk,newSL,0); }
      else if(posType==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double newSL=NormalizeDouble(ask+InpTrailATR*atr,dg); if(newSL<curSL&&newSL>ask&&(newSL-ask)>=minDist)trade.PositionModify(tk,newSL,0); } } }

double OnTester(){
   int h=FileOpen("ck_best_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"time","profit");
      HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
         if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
         double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h);
   }
   return(0.0);
}
void OnTick(){
   datetime ds=iTime(_Symbol,PERIOD_D1,0); if(ds>0&&ds!=g_dayStart)ResetDaily();
   ManageTrailingStop();
   if(!IsNewBar())return;
   double dailyLoss=g_dayStartBal-AccountInfoDouble(ACCOUNT_BALANCE); if(dailyLoss>g_dayStartBal*InpDailyLossPct)return;
   if(MyPositionCount()>=InpMaxPositions)return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpread)return;
   double atr=GetATR(),emaF=GetEMAFast(),emaM=GetEMAMid(),emaS=GetEMASlow();
   if(atr<=0||emaF<=0||emaM<=0||emaS<=0)return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(IsHAGreen()&&emaF>emaM&&emaM>emaS){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double slDist=InpSLATR*atr; double sl=NormalizeDouble(ask-slDist,dg); double lot=CalcLot(slDist); if(lot>0)trade.Buy(lot,_Symbol,0,sl,0,"CK_BEST_BUY"); }
   else if(IsHARed()&&emaF<emaM&&emaM<emaS){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double slDist=InpSLATR*atr; double sl=NormalizeDouble(bid+slDist,dg); double lot=CalcLot(slDist); if(lot>0)trade.Sell(lot,_Symbol,0,sl,0,"CK_BEST_SELL"); }
}
//+------------------------------------------------------------------+

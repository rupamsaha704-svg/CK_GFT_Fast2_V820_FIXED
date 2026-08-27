//+------------------------------------------------------------------+
//|  CK_GFT_v810_diag.mq5 = user's v8.10 "knee" pullback (BUY-only)  |
//|  IDENTICAL logic; adds OnTester dump time,profit -> ck_v810_trades|
//|  for Vibe validation + correlation vs v23.  Test on M15.          |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.10"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic          = 20260715;
input double InpRiskPercent    = 0.35;
input double InpRR             = 2.5;
input bool   InpBreakEvenAt1R  = true;
input int    InpMaxTradesPerDay= 3;
input double InpDailyLossStopR = 1.0;
input double InpDailyProfitStopR=3.0;
input int    InpMaxSpreadPoints= 50;
input bool   InpUseTrend       = true;
input int    InpEMAPeriod      = 21;
input int    InpEMASlow        = 50;
input int    InpKneeMinRun     = 2;
input int    InpValidBars      = 5;
input double InpSLBufferATR    = 0.3;
input double InpMaxLot         = 0.08;

int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime = 0;
datetime g_dayStart  = 0;
double   g_dayStartBal= 0.0;
double   g_oneR_money = 0.0;
int      g_tradesToday= 0;
int      g_dir       = 0;
double   g_trigger   = 0.0;
double   g_kneeLow   = 0.0;
double   g_kneeHigh  = 0.0;
double   g_pendingSL = 0.0;
double   g_pendingTP = 0.0;
int      g_barsLeft  = 0;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   atrHandle = iATR(_Symbol,_Period,14);
   emaFastHandle = iMA(_Symbol,_Period,InpEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol,_Period,InpEMASlow,0,MODE_EMA,PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE || emaFastHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle!=INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle!=INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}
double ATR(){ double b[]; if(CopyBuffer(atrHandle,0,0,1,b)<=0) return(0); return(b[0]); }
double EMAFast(int shift){ double b[]; if(CopyBuffer(emaFastHandle,0,shift,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int shift){ double b[]; if(CopyBuffer(emaSlowHandle,0,shift,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,_Period,0); if(t!=lastBarTime){lastBarTime=t;return(true);} return(false); }
bool IsGreen(int s){ return(iClose(_Symbol,_Period,s)>iOpen(_Symbol,_Period,s)); }
bool IsRed(int s){ return(iClose(_Symbol,_Period,s)<iOpen(_Symbol,_Period,s)); }
void ResetDaily()
{
   g_dayStart = iTime(_Symbol,PERIOD_D1,0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_oneR_money = g_dayStartBal*(InpRiskPercent/100.0);
   g_tradesToday = 0;
}
double RealizedRToday()
{
   if(g_oneR_money<=0) return(0);
   return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money);
}
void Disarm(){ g_dir=0; g_trigger=0; g_kneeLow=0; g_kneeHigh=0; g_barsLeft=0; g_pendingSL=0; g_pendingTP=0; }
bool IsTrendBuy(){ return (EMAFast(1) > EMASlow(1) && iClose(_Symbol,_Period,1) > EMAFast(1)); }
void TryArmSetup()
{
   double atr = ATR();
   if(atr <= 0) return;
   double buf = InpSLBufferATR * atr;
   if(IsRed(1))
   {
      int run=0;
      for(int i=2; i<=12; i++){ if(IsGreen(i)) run++; else break; }
      bool trendOK = (!InpUseTrend) || IsTrendBuy();
      if(run >= InpKneeMinRun && trendOK)
      {
         g_dir = +1;
         g_kneeHigh = iHigh(_Symbol,_Period,1);
         g_kneeLow = iLow(_Symbol,_Period,1);
         g_trigger = g_kneeHigh;
         g_pendingSL = g_kneeLow - buf;
         double oneR = g_trigger - g_pendingSL;
         g_pendingTP = g_trigger + (InpRR * oneR);
         g_barsLeft = InpValidBars;
      }
   }
}
double LotForRisk(double riskMoney, double slDist)
{
   if(slDist <= 0) return(0);
   double tv = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0) return(0);
   double lossPerLot = (slDist/ts) * tv;
   if(lossPerLot <= 0) return(0);
   double lots = riskMoney / lossPerLot;
   double mn = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double st = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots/st) * st;
   if(lots < mn) lots = mn;
   if(lots > InpMaxLot) lots = InpMaxLot;
   return(lots);
}
int MyPositions()
{
   int c = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol) c++;
   }
   return(c);
}
void OpenTrade(int dir)
{
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double sl = g_pendingSL;
   double tp = g_pendingTP;
   double oneR = ask - sl;
   if(oneR <= 0) return;
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent/100.0);
   double lots = LotForRisk(riskMoney, oneR);
   if(lots <= 0) return;
   int dg = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, dg);
   tp = NormalizeDouble(tp, dg);
   trade.Buy(lots, _Symbol, 0, sl, tp);
   g_tradesToday++;
}
void ManageBE()
{
   if(!InpBreakEvenAt1R) return;
   int dg = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double slc = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double be = NormalizeDouble(open, dg);
      double oneR = open - slc;
      if(oneR > 0 && bid >= open + oneR && slc < be)
         trade.PositionModify(tk, be, tp);
   }
}
bool TradingAllowed()
{
   double r = RealizedRToday();
   if(InpDailyProfitStopR > 0 && r >= InpDailyProfitStopR) return(false);
   if(InpDailyLossStopR > 0 && r <= -InpDailyLossStopR) return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}
double OnTester()
{
   int h=FileOpen("ck_v810_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
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
void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0) != g_dayStart) ResetDaily();
   ManageBE();
   if(IsNewBar())
   {
      if(g_dir != 0){ g_barsLeft--; if(g_barsLeft <= 0) Disarm(); }
      if(g_dir == 0 && MyPositions() == 0) TryArmSetup();
   }
   if(g_dir != 0 && MyPositions() == 0)
   {
      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(g_dir > 0 && ask >= g_trigger){ OpenTrade(+1); Disarm(); }
   }
}
//+------------------------------------------------------------------+

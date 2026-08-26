//+------------------------------------------------------------------+
//|                                    CK_GFT_Fast_v23_ROBUST.mq5     |
//|  Robust multi-confirmation breakout-pullback (XAUUSD)            |
//|                                                                    |
//|  A BUY requires ALL of:                                           |
//|   C1 Trend   : HTF close > HTF EMA(trend)                         |
//|   C2 Break   : a recent HTF bar broke the Donchian high          |
//|   C3 Pullback: price retraced to the entry-TF EMA (not extended) |
//|   C4 Trigger : bullish resumption bar closes above entry-TF EMA  |
//|                and breaks the prior bar high                      |
//|  + risk gates: SL <= MaxSL_ATR*ATR, spread, daily limits,        |
//|    one position at a time. SELL is the exact mirror.             |
//|                                                                    |
//|  Risk is fixed % per trade; TP = RR * risk; optional break-even. |
//|  Few parameters by design (anti-overfit). Validate OOS before use.|
//+------------------------------------------------------------------+
#property copyright "CK GFT Robust v23"
#property version   "23.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE / RISK ===
input long   InpMagic            = 20260716;
input double InpRiskPercent      = 0.5;    // % balance risked per trade
input double InpRR               = 3.0;    // reward:risk for TP
input double InpMaxLot           = 0.20;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;    // stop new trades after -2R realised
input double InpDailyProfitStopR = 4.0;    // stop new trades after +4R realised
input int    InpMaxSpreadPoints  = 60;

//=== CONFIRMATION 1: HTF trend ===
input ENUM_TIMEFRAMES InpHTF     = PERIOD_H1;
input int    InpTrendEMA         = 200;

//=== CONFIRMATION 2: HTF structure breakout ===
input int    InpBreakoutLookback = 20;     // HTF Donchian window
input int    InpBreakoutMaxAge   = 12;     // breakout must be within last N HTF bars

//=== CONFIRMATION 3/4: entry-TF pullback + momentum trigger ===
input int    InpEntryEMA         = 20;     // entry-TF EMA (pullback reference)
input int    InpSwingLookback    = 10;     // entry-TF swing for SL

//=== RISK gate + management ===
input double InpMaxSL_ATR        = 2.5;    // skip if SL distance > this * ATR(14)
input double InpSLBufferATR      = 0.20;   // SL buffer beyond swing
input bool   InpUseBreakEven     = true;
input double InpBEProgress       = 0.50;   // move SL to entry at this progress toward TP

//=== HANDLES / STATE ===
int      hEmaHTF, hEmaLTF, hAtr;
datetime lastBarTime = 0;
datetime g_dayStart  = 0;
double   g_dayStartBal = 0.0;
double   g_oneR_money  = 0.0;
int      g_tradesToday = 0;
bool     g_beActivated = false;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   hEmaHTF = iMA(_Symbol, InpHTF,          InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEmaLTF = iMA(_Symbol, PERIOD_CURRENT,  InpEntryEMA, 0, MODE_EMA, PRICE_CLOSE);
   hAtr    = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(hEmaHTF==INVALID_HANDLE || hEmaLTF==INVALID_HANDLE || hAtr==INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(hEmaHTF!=INVALID_HANDLE) IndicatorRelease(hEmaHTF);
   if(hEmaLTF!=INVALID_HANDLE) IndicatorRelease(hEmaLTF);
   if(hAtr   !=INVALID_HANDLE) IndicatorRelease(hAtr);
}

//=== indicator helpers ===
double ATR()
{
   double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0) return(0); return(b[0]);
}
double EmaHTF(int shift)
{
   double b[]; if(CopyBuffer(hEmaHTF,0,shift,1,b)<=0) return(0); return(b[0]);
}
double EmaLTF(int shift)
{
   double b[]; if(CopyBuffer(hEmaLTF,0,shift,1,b)<=0) return(0); return(b[0]);
}
bool IsNewBar()
{
   datetime t = iTime(_Symbol,PERIOD_CURRENT,0);
   if(t != lastBarTime){ lastBarTime=t; return(true); }
   return(false);
}

//=== daily / risk ===
void ResetDaily()
{
   g_dayStart    = iTime(_Symbol,PERIOD_D1,0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_oneR_money  = g_dayStartBal * (InpRiskPercent/100.0);
   g_tradesToday = 0;
}
double RealizedRToday()
{
   if(g_oneR_money<=0) return(0);
   return((AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal) / g_oneR_money);
}
bool TradingAllowed()
{
   double r = RealizedRToday();
   if(InpDailyProfitStopR > 0 && r >=  InpDailyProfitStopR) return(false);
   if(InpDailyLossStopR   > 0 && r <= -InpDailyLossStopR)   return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//=== position helpers ===
int MyPositions()
{
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol) c++;
   }
   return(c);
}
ulong GetMyTicket()
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol) return(tk);
   }
   return(0);
}

//=== lot sizing (fixed % risk) ===
double LotForRisk(double riskMoney, double slDist)
{
   if(slDist<=0) return(0);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0) return(0);
   double lossPerLot=(slDist/ts)*tv;
   if(lossPerLot<=0) return(0);
   double lots=riskMoney/lossPerLot;
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathFloor(lots/st)*st;
   if(lots<mn) lots=mn;
   if(lots>InpMaxLot) lots=InpMaxLot;
   return(lots);
}

//=== HTF Donchian breakout: did a recent HTF bar break the prior Donchian high/low? ===
bool RecentBreakUp()
{
   for(int s=1; s<=InpBreakoutMaxAge; s++)
   {
      int hi = iHighest(_Symbol, InpHTF, MODE_HIGH, InpBreakoutLookback, s+1);
      if(hi<0) continue;
      double priorHigh = iHigh(_Symbol, InpHTF, hi);
      if(iClose(_Symbol, InpHTF, s) > priorHigh) return(true);
   }
   return(false);
}
bool RecentBreakDown()
{
   for(int s=1; s<=InpBreakoutMaxAge; s++)
   {
      int lo = iLowest(_Symbol, InpHTF, MODE_LOW, InpBreakoutLookback, s+1);
      if(lo<0) continue;
      double priorLow = iLow(_Symbol, InpHTF, lo);
      if(iClose(_Symbol, InpHTF, s) < priorLow) return(true);
   }
   return(false);
}

//=== swing low/high on entry TF (for SL) ===
double SwingLow()
{
   int idx=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,InpSwingLookback,1);
   if(idx<0) return(0);
   return(iLow(_Symbol,PERIOD_CURRENT,idx));
}
double SwingHigh()
{
   int idx=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpSwingLookback,1);
   if(idx<0) return(0);
   return(iHigh(_Symbol,PERIOD_CURRENT,idx));
}

//=== open trades ===
void OpenBuy(double sl,double tp)
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double risk=ask-sl; if(risk<=0) return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk);
   if(lots<=0) return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Buy(lots,_Symbol,0,sl,tp)){ g_tradesToday++; g_beActivated=false; }
}
void OpenSell(double sl,double tp)
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double risk=sl-bid; if(risk<=0) return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk);
   if(lots<=0) return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Sell(lots,_Symbol,0,sl,tp)){ g_tradesToday++; g_beActivated=false; }
}

//=== break-even management ===
void ManageTrade()
{
   if(!InpUseBreakEven) return;
   if(MyPositions()==0){ g_beActivated=false; return; }
   ulong tk=GetMyTicket(); if(tk==0) return;
   if(!PositionSelectByTicket(tk)) return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl  =PositionGetDouble(POSITION_SL);
   double tp  =PositionGetDouble(POSITION_TP);
   long   type=PositionGetInteger(POSITION_TYPE);
   int    dg  =(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_beActivated) return;
   double prog=0;
   if(type==POSITION_TYPE_BUY){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(tp-open<=0) return; prog=(bid-open)/(tp-open);
      if(prog>=InpBEProgress && sl<open){ if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp)) g_beActivated=true; }
   } else if(type==POSITION_TYPE_SELL){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(open-tp<=0) return; prog=(open-ask)/(open-tp);
      if(prog>=InpBEProgress && sl>open){ if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp)) g_beActivated=true; }
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();
   ManageTrade();
   if(!IsNewBar()) return;
   if(MyPositions()>0) return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
   if(!TradingAllowed()) return;

   double atr=ATR(); if(atr<=0) return;
   double buf=InpSLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   double o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,2);
   double l2=iLow(_Symbol,PERIOD_CURRENT,2);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1);
   double hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaL=EmaLTF(1);
   double closeH1=iClose(_Symbol,InpHTF,1);
   double emaH=EmaHTF(1);

   //================= BUY =================
   bool c1_trend    = (closeH1 > emaH);                 // C1 HTF uptrend
   bool c2_break    = RecentBreakUp();                  // C2 recent HTF breakout up
   bool c3_pullback = (lo1 <= emaL);                    // C3 pulled back to entry EMA
   bool c4_trigger  = (c1 > o1) && (c1 > emaL) && (c1 > h2); // C4 bullish resumption
   if(c1_trend && c2_break && c3_pullback && c4_trigger)
   {
      double sl = MathMin(lo1,l2) - buf;
      double ask= SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double risk = ask - sl;
      if(risk>0 && risk <= InpMaxSL_ATR*atr)
      {
         double tp = ask + InpRR*risk;
         OpenBuy(sl,tp);
         return;
      }
   }

   //================= SELL =================
   bool s1_trend    = (closeH1 < emaH);
   bool s2_break    = RecentBreakDown();
   bool s3_pullback = (hi1 >= emaL);
   bool s4_trigger  = (c1 < o1) && (c1 < emaL) && (c1 < l2);
   if(s1_trend && s2_break && s3_pullback && s4_trigger)
   {
      double sl = MathMax(hi1,h2) + buf;
      double bid= SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double risk = sl - bid;
      if(risk>0 && risk <= InpMaxSL_ATR*atr)
      {
         double tp = bid - InpRR*risk;
         OpenSell(sl,tp);
      }
   }
}
//+------------------------------------------------------------------+

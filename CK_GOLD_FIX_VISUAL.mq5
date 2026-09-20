//+------------------------------------------------------------------+
//| CK_GOLD_FIX_VISUAL.mq5                                            |
//| Standalone MQL5 version of the Pine "FIX visual" -- the CORE      |
//| breakout sleeve only, for you to backtest & eyeball on M15.       |
//| NOT the full strategy: no DT sleeve, no daily governor, no news   |
//| gate, no DTChop. The real, validated strategy = CK_GOLD_COMBO +   |
//| the .set files. This EA's results will DIFFER from the combo.     |
//| Use: XAUUSD, M15. Strategy Tester shows entries / SL / TP / graph.|
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input double          InpLot       = 0.02;         // fixed lot
input ENUM_TIMEFRAMES InpHTF       = PERIOD_H1;     // higher-TF trend
input int             InpTrendEMA  = 200;           // HTF trend EMA
input int             InpEntryEMA  = 20;            // entry EMA (chart TF)
input int             InpATR       = 14;            // ATR length
input int             InpBreakout  = 20;            // breakout lookback
input int             InpSwing     = 10;            // swing lookback (SL)
input double          InpSLbufATR  = 0.20;          // SL buffer x ATR
input double          InpMaxSLatr  = 2.5;           // max SL x ATR
input double          InpRR        = 3.0;           // reward : risk
input bool            InpLongs     = true;
input bool            InpShorts    = true;
input long            InpMagic     = 20260716;

int hHtfEma=INVALID_HANDLE, hEma=INVALID_HANDLE, hAtr=INVALID_HANDLE;
datetime lastBar=0;

int OnInit()
{
   hHtfEma = iMA(_Symbol, InpHTF,           InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEma    = iMA(_Symbol, PERIOD_CURRENT,   InpEntryEMA, 0, MODE_EMA, PRICE_CLOSE);
   hAtr    = iATR(_Symbol, PERIOD_CURRENT,  InpATR);
   if(hHtfEma==INVALID_HANDLE || hEma==INVALID_HANDLE || hAtr==INVALID_HANDLE)
      return(INIT_FAILED);
   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
}

bool NewBar()
{
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t==lastBar) return(false);
   lastBar = t;  return(true);
}

double Buf(int handle,int shift)
{
   double b[];
   if(CopyBuffer(handle,0,shift,1,b)!=1) return(0.0);
   return(b[0]);
}

bool HasPos()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(PositionSelectByTicket(tk)
         && PositionGetString(POSITION_SYMBOL)==_Symbol
         && PositionGetInteger(POSITION_MAGIC)==InpMagic)
         return(true);
   }
   return(false);
}

void OnTick()
{
   if(!NewBar()) return;
   if(HasPos())  return;

   // signal bar = last closed bar (shift 1)
   double c1=iClose(_Symbol,PERIOD_CURRENT,1), o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1),  hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaE=Buf(hEma,1), atr=Buf(hAtr,1);
   if(atr<=0) return;

   // higher-TF trend (last closed HTF bar)
   double htfC=iClose(_Symbol,InpHTF,1), htfE=Buf(hHtfEma,1);
   bool bull=(htfC>htfE), bear=(htfC<htfE);

   // breakout of the prior N-bar high/low (bars before the signal bar)
   int ih=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpBreakout,2);
   int il=iLowest (_Symbol,PERIOD_CURRENT,MODE_LOW ,InpBreakout,2);
   double priorHigh=(ih>=0)?iHigh(_Symbol,PERIOD_CURRENT,ih):0.0;
   double priorLow =(il>=0)?iLow (_Symbol,PERIOD_CURRENT,il):0.0;
   bool brokeUp=(c1>priorHigh), brokeDn=(priorLow>0 && c1<priorLow);

   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   if(InpLongs && bull && brokeUp && lo1<=emaE && c1>o1 && c1>emaE)
   {
      int isl=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,InpSwing,1);
      double swingLow=(isl>=0)?iLow(_Symbol,PERIOD_CURRENT,isl):lo1;
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=MathMin(swingLow,lo1)-InpSLbufATR*atr;
      double risk=ask-sl;
      if(risk>InpMaxSLatr*atr){ risk=InpMaxSLatr*atr; sl=ask-risk; }
      if(risk>0)
      {
         double tp=ask+InpRR*risk;
         trade.Buy(InpLot,_Symbol,ask,NormalizeDouble(sl,dg),NormalizeDouble(tp,dg),"FIX long");
      }
   }
   else if(InpShorts && bear && brokeDn && hi1>=emaE && c1<o1 && c1<emaE)
   {
      int ish=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,InpSwing,1);
      double swingHigh=(ish>=0)?iHigh(_Symbol,PERIOD_CURRENT,ish):hi1;
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=MathMax(swingHigh,hi1)+InpSLbufATR*atr;
      double risk=sl-bid;
      if(risk>InpMaxSLatr*atr){ risk=InpMaxSLatr*atr; sl=bid+risk; }
      if(risk>0)
      {
         double tp=bid-InpRR*risk;
         trade.Sell(InpLot,_Symbol,bid,NormalizeDouble(sl,dg),NormalizeDouble(tp,dg),"FIX short");
      }
   }
}
//+------------------------------------------------------------------+

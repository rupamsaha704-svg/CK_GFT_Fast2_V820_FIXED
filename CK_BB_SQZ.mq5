//+------------------------------------------------------------------+
//| CK_BB_SQZ.mq5 - Bollinger-Band Squeeze Breakout, XAUUSD M15.      |
//| Edge-search Idea #002 (SPEC/EDGE_SEARCH_AGENT.md, ledger seq201). |
//| PRE-DECLARED RULES (no sweeping):                                 |
//|  - BB(SQ_BBPeriod, SQ_BBStd), ATR(SQ_ATRPeriod)                   |
//|  - Squeeze: over last SQ_SqLookback CLOSED bars ending at bar 2,  |
//|    at least SQ_SqHitsMin have (BB_upper-BB_lower)/ATR < SQ_SqRatio|
//|  - Signal bar = bar shift 1 (just closed):                        |
//|      LONG  if close1 > upper_at_bar1                              |
//|      SHORT if close1 < lower_at_bar1                              |
//|      AND prior squeeze was active                                 |
//|  - Enter at market at bar 0 open.                                 |
//|  - SL = signal bar's opposite extreme +/- SQ_SLBufATR * ATR14     |
//|  - TP = entry +/- SQ_RR * |entry - SL|                            |
//|  - Max SQ_MaxTradesPerDay per server-day; fixed SQ_Lot            |
//| OnTester dumps 2-column time,profit CSV to Common\Files.          |
//+------------------------------------------------------------------+
#property copyright "CK BB Squeeze (edge-search #002)"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade   T;

input long   SQ_Magic          = 20260906;
input int    SQ_BBPeriod       = 20;
input double SQ_BBStd          = 2.0;
input int    SQ_ATRPeriod      = 14;
input int    SQ_SqLookback     = 5;
input int    SQ_SqHitsMin      = 3;
input double SQ_SqRatio        = 1.5;   // BB width / ATR14 threshold for "compressed"
input double SQ_SLBufATR       = 0.15;
input double SQ_RR             = 1.5;
input int    SQ_MaxTradesPerDay= 3;
input double SQ_Lot            = 0.01;
input double SQ_MaxSpreadPrice = 0.60;

//--- state
int      g_hBB  = INVALID_HANDLE;
int      g_hAtr = INVALID_HANDLE;
datetime g_dayStamp    = 0;
int      g_tradesToday = 0;
datetime g_lastBar     = 0;

int OnInit(){
   T.SetExpertMagicNumber(SQ_Magic);
   g_hBB  = iBands(_Symbol, PERIOD_CURRENT, SQ_BBPeriod, 0, SQ_BBStd, PRICE_CLOSE);
   g_hAtr = iATR(_Symbol,  PERIOD_CURRENT, SQ_ATRPeriod);
   if(g_hBB == INVALID_HANDLE || g_hAtr == INVALID_HANDLE) return(INIT_FAILED);
   return(INIT_SUCCEEDED);
}

bool IsNewBar(){
   datetime t = iTime(_Symbol,PERIOD_CURRENT,0);
   if(t == g_lastBar) return(false);
   g_lastBar = t;
   return(true);
}

int MyPositions(){
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==SQ_Magic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) c++;
   }
   return(c);
}

void MaybeNewDay(){
   datetime dtoday = iTime(_Symbol, PERIOD_D1, 0);
   if(dtoday != g_dayStamp){
      g_dayStamp     = dtoday;
      g_tradesToday  = 0;
   }
}

// Copy N BB values starting at shift `startShift` (inclusive, newest first in array).
bool CopyBB(int startShift, int count, double &up[], double &mid[], double &lo[]){
   if(CopyBuffer(g_hBB, 1, startShift, count, up)  <= 0) return(false); // MT5 iBands buffer 1 = UPPER
   if(CopyBuffer(g_hBB, 0, startShift, count, mid) <= 0) return(false); // buffer 0 = MID (basis)
   if(CopyBuffer(g_hBB, 2, startShift, count, lo)  <= 0) return(false); // buffer 2 = LOWER
   return(true);
}

double ATR_at(int shift){
   double b[]; if(CopyBuffer(g_hAtr, 0, shift, 1, b) <= 0) return(0.0); return(b[0]);
}

// Compute the squeeze count over `count` bars ending at oldest first,
// starting shift `startShift` (2 = 5 bars ending at bar 6, most recent bar in the range = bar 2).
int SqueezeHits(int startShift, int count){
   double up[], mid[], lo[]; ArraySetAsSeries(up,false); ArraySetAsSeries(mid,false); ArraySetAsSeries(lo,false);
   if(!CopyBB(startShift, count, up, mid, lo)) return(-1);
   int hits = 0;
   for(int k=0; k<count; k++){
      // The corresponding bar shift for the k-th value depends on CopyBuffer semantics
      // (default non-series: index 0 = oldest, index count-1 = newest). We only need ATR per bar.
      int shift = startShift + (count - 1 - k);
      double atr = ATR_at(shift);
      if(atr <= 0) continue;
      double width = up[k] - lo[k];
      if(width / atr < SQ_SqRatio) hits++;
   }
   return(hits);
}

void OnTick(){
   if(!IsNewBar()) return;
   MaybeNewDay();
   if(g_tradesToday >= SQ_MaxTradesPerDay) return;
   if(MyPositions() > 0) return;

   // Need enough history: BB period + squeeze lookback + 3 buffer bars.
   int minBars = SQ_BBPeriod + SQ_SqLookback + 3;
   if(iBars(_Symbol, PERIOD_CURRENT) < minBars) return;

   // 1) prior squeeze on bars [2 .. 2+SQ_SqLookback-1]
   int hits = SqueezeHits(2, SQ_SqLookback);
   if(hits < 0) return;
   if(hits < SQ_SqHitsMin) return;

   // 2) signal bar = shift 1 (just closed).
   double up1[], mid1[], lo1[];
   if(!CopyBB(1, 1, up1, mid1, lo1)) return;
   double upper = up1[0], lower = lo1[0];
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1  = iHigh (_Symbol, PERIOD_CURRENT, 1);
   double low1   = iLow  (_Symbol, PERIOD_CURRENT, 1);
   double atr    = ATR_at(1);
   if(atr <= 0) return;

   // spread guard
   long curPts = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   long maxPts = (long)MathRound(SQ_MaxSpreadPrice / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   if(curPts > maxPts) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(close1 > upper){
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = low1 - SQ_SLBufATR * atr;
      double risk = ask - sl;
      if(risk <= 0) return;
      double tp  = ask + SQ_RR * risk;
      sl = NormalizeDouble(sl, dg); tp = NormalizeDouble(tp, dg);
      if(T.Buy(SQ_Lot, _Symbol, 0, sl, tp)) g_tradesToday++;
      return;
   }
   if(close1 < lower){
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = high1 + SQ_SLBufATR * atr;
      double risk = sl - bid;
      if(risk <= 0) return;
      double tp  = bid - SQ_RR * risk;
      sl = NormalizeDouble(sl, dg); tp = NormalizeDouble(tp, dg);
      if(T.Sell(SQ_Lot, _Symbol, 0, sl, tp)) g_tradesToday++;
      return;
   }
}

// Dump the trade list Python will read.
double OnTester(){
   int h = FileOpen("ck_bb_sqz_trades.csv",
                    FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h != INVALID_HANDLE){
      FileWrite(h, "time", "profit");
      HistorySelect(0, TimeCurrent());
      int total = HistoryDealsTotal();
      for(int i=0; i<total; i++){
         ulong tk = HistoryDealGetTicket(i); if(tk==0) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         if(HistoryDealGetInteger(tk, DEAL_MAGIC) != SQ_Magic) continue;
         datetime xt = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
         double p = HistoryDealGetDouble(tk, DEAL_PROFIT)
                  + HistoryDealGetDouble(tk, DEAL_SWAP)
                  + HistoryDealGetDouble(tk, DEAL_COMMISSION);
         FileWrite(h, TimeToString(xt, TIME_DATE|TIME_MINUTES),
                      DoubleToString(p, 2));
      }
      FileClose(h);
   }
   return(0.0);
}

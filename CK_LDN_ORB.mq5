//+------------------------------------------------------------------+
//| CK_LDN_ORB.mq5 - Minimal London-Open Range Breakout, XAUUSD M15.  |
//| Edge-search Idea #001 (SPEC/EDGE_SEARCH_AGENT.md, ledger seq197). |
//| PRE-DECLARED RULES (no sweeping):                                 |
//|  - Session (server): [ORB_SessionStart, ORB_SessionEnd)           |
//|  - Range = first ORB_RangeBars M15 bars of the session            |
//|  - Entry (M15 close):                                             |
//|      BUY  if c1 > range_high + ORB_BreakBufATR * ATR14            |
//|      SELL if c1 < range_low  - ORB_BreakBufATR * ATR14            |
//|  - SL = opposite side of range +/- ORB_SLBufATR * ATR14           |
//|  - TP = RR = ORB_RR fixed                                         |
//|  - Max 1 trade / day; fixed lot ORB_Lot                           |
//| OnTester dumps time,profit,magic to Common\Files.                 |
//+------------------------------------------------------------------+
#property copyright "CK LDN ORB (edge-search #001)"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade   T;

input long   ORB_Magic          = 20260905;
input int    ORB_SessionStart   = 7;      // server hour, inclusive (start of range window)
input int    ORB_SessionEnd     = 11;     // server hour, exclusive (no new entries at/after)
input int    ORB_RangeBars      = 1;      // # of M15 bars in the opening range (1 = 07:00-07:15)
input double ORB_BreakBufATR    = 0.10;   // buffer beyond the range to trigger, in ATR14
input double ORB_SLBufATR       = 0.20;   // SL buffer beyond opposite side, in ATR14
input double ORB_RR             = 2.0;    // TP as multiple of SL distance
input int    ORB_ATRPeriod      = 14;
input double ORB_Lot            = 0.01;
input double ORB_MaxSpreadPrice = 0.60;   // skip if spread wider than this (USD/oz)

//--- state
int      g_hAtr = INVALID_HANDLE;
datetime g_dayStamp   = 0;
double   g_rangeHi    = 0.0, g_rangeLo = 0.0;
bool     g_rangeReady = false;
bool     g_tradedToday= false;
datetime g_lastBar    = 0;

int OnInit(){
   T.SetExpertMagicNumber(ORB_Magic);
   g_hAtr = iATR(_Symbol, PERIOD_CURRENT, ORB_ATRPeriod);
   if(g_hAtr == INVALID_HANDLE) return(INIT_FAILED);
   return(INIT_SUCCEEDED);
}

double ATRv(){ double b[]; if(CopyBuffer(g_hAtr,0,1,1,b)<=0) return(0.0); return(b[0]); }

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
      if(PositionGetInteger(POSITION_MAGIC)==ORB_Magic &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) c++;
   }
   return(c);
}

// Reset per-day state at the start of a new server day.
void MaybeNewDay(){
   datetime dtoday = iTime(_Symbol, PERIOD_D1, 0);
   if(dtoday != g_dayStamp){
      g_dayStamp    = dtoday;
      g_rangeHi     = 0.0;
      g_rangeLo     = 0.0;
      g_rangeReady  = false;
      g_tradedToday = false;
   }
}

// Build the opening range from the FIRST ORB_RangeBars M15 bars whose
// server-hour is >= ORB_SessionStart AND < ORB_SessionEnd.
// We use closed bars only (shift 1..N).
void BuildRangeIfPossible(){
   if(g_rangeReady) return;
   MqlDateTime dt;
   double hi = -DBL_MAX, lo = DBL_MAX;
   int found = 0;
   // Walk bars backward from bar 1 (last closed), keep only bars whose
   // datetime hour is in the session and whose DATE equals today's date.
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   for(int i=1; i<=200 && found<ORB_RangeBars; i++){
      datetime bt = iTime(_Symbol, PERIOD_CURRENT, i);
      if(bt < today) break;                     // walked into yesterday
      TimeToStruct(bt, dt);
      if(dt.hour < ORB_SessionStart) continue;  // before session
      if(dt.hour >= ORB_SessionEnd)  continue;  // after session
      // pick the earliest ORB_RangeBars session bars: because we walk newest-first,
      // we must eventually see all of them; collect min/max.
      double bh = iHigh(_Symbol, PERIOD_CURRENT, i);
      double bl = iLow (_Symbol, PERIOD_CURRENT, i);
      if(bh > hi) hi = bh;
      if(bl < lo) lo = bl;
      found++;
   }
   // Ensure we have exactly ORB_RangeBars *earliest* session bars: the walk above
   // takes ALL session bars newest-first up to ORB_RangeBars. To be strict, only
   // arm once bar shift 1 corresponds to bar # ORB_RangeBars of the session
   // (i.e. we are at least ORB_RangeBars bars past session start). Compute the
   // session-bar-index of bar 1.
   datetime bt1 = iTime(_Symbol, PERIOD_CURRENT, 1);
   TimeToStruct(bt1, dt);
   int minutesIntoSession = (dt.hour - ORB_SessionStart)*60 + dt.min;
   int sessionBarIdx      = minutesIntoSession / 15 + 1; // 1-based, 1st bar of session = 1
   if(sessionBarIdx < ORB_RangeBars) return;             // not yet enough range bars
   if(dt.hour < ORB_SessionStart || dt.hour >= ORB_SessionEnd) return;
   if(found <= 0) return;
   g_rangeHi    = hi;
   g_rangeLo    = lo;
   g_rangeReady = true;
}

bool InSession(datetime bt){
   MqlDateTime dt; TimeToStruct(bt, dt);
   return (dt.hour >= ORB_SessionStart && dt.hour < ORB_SessionEnd);
}

int SessionBarIdx(datetime bt){
   MqlDateTime dt; TimeToStruct(bt, dt);
   int minutesIntoSession = (dt.hour - ORB_SessionStart)*60 + dt.min;
   return (minutesIntoSession / 15 + 1);
}

void OnTick(){
   if(!IsNewBar()) return;
   MaybeNewDay();
   if(g_tradedToday) return;
   if(MyPositions() > 0) return;

   // last closed M15 bar
   datetime bt1 = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(!InSession(bt1)) return;
   if(SessionBarIdx(bt1) <= ORB_RangeBars) { BuildRangeIfPossible(); return; }

   BuildRangeIfPossible();
   if(!g_rangeReady) return;

   double atr = ATRv();
   if(atr <= 0) return;

   double c1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   // spread guard
   long curPts = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   long maxPts = (long)MathRound(ORB_MaxSpreadPrice / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   if(curPts > maxPts) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // BUY on close breakout above range high + buffer
   if(c1 > g_rangeHi + ORB_BreakBufATR * atr){
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = g_rangeLo - ORB_SLBufATR * atr;
      double risk = ask - sl;
      if(risk <= 0) return;
      double tp  = ask + ORB_RR * risk;
      sl = NormalizeDouble(sl, dg); tp = NormalizeDouble(tp, dg);
      if(T.Buy(ORB_Lot, _Symbol, 0, sl, tp)){ g_tradedToday = true; }
      return;
   }
   // SELL on close breakdown below range low - buffer
   if(c1 < g_rangeLo - ORB_BreakBufATR * atr){
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = g_rangeHi + ORB_SLBufATR * atr;
      double risk = sl - bid;
      if(risk <= 0) return;
      double tp  = bid - ORB_RR * risk;
      sl = NormalizeDouble(sl, dg); tp = NormalizeDouble(tp, dg);
      if(T.Sell(ORB_Lot, _Symbol, 0, sl, tp)){ g_tradedToday = true; }
      return;
   }
}

// Dump the trade list Python will read.
double OnTester(){
   int h = FileOpen("ck_ldn_orb_trades.csv",
                    FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h != INVALID_HANDLE){
      FileWrite(h, "time", "profit");
      HistorySelect(0, TimeCurrent());
      int total = HistoryDealsTotal();
      for(int i=0; i<total; i++){
         ulong tk = HistoryDealGetTicket(i); if(tk==0) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         if(HistoryDealGetInteger(tk, DEAL_MAGIC) != ORB_Magic) continue;
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

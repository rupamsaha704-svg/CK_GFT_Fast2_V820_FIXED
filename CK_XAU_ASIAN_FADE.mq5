//+------------------------------------------------------------------+
//|  CK_XAU_ASIAN_FADE.mq5                                             |
//|                                                                    |
//|  Mean-reversion candidate: XAUUSD Asian-session range fade.        |
//|                                                                    |
//|  Purpose: earn small consistent profits during flat / choppy market|
//|  months when the trend-following combo (FIX09+DTREND) stands down. |
//|  Target regime: Plan C's losing months (Feb, Apr, Jul, Aug 2026).  |
//|                                                                    |
//|  Rules ARE LOCKED per pre-registration                             |
//|    SPEC/PREREG_ASIAN_RANGE_FADE.md  (ledger seq279 2026-09-21)     |
//|  No parameter here may be tuned to rescue a failing test result.   |
//|  A single failure of any of the six pre-declared pass criteria     |
//|  = REJECT the whole candidate (steering §5 discipline).             |
//|                                                                    |
//|  Session : 22:00-04:00 server time (Asian).                        |
//|  Range   : first 8 M15 bars = 2 hours.                             |
//|  Entry   : M15 wick-rejection at range extreme, wick/body >= 1.5,  |
//|            close INSIDE the range.                                 |
//|  SL      : range extreme + 0.3 * ATR(14) buffer.                   |
//|  TP1 50% : range midpoint (BE lock on TP1 hit).                    |
//|  TP2 50% : opposite range extreme.                                 |
//|  Time    : flatten ALL at 04:00 server, no overnight carry.        |
//|  Risk    : $50 fixed per trade, max lot 0.10, max 3 trades / week. |
//|  Magic   : 20260921 (distinct from FIX09 20260716, DTREND 20260930)|
//+------------------------------------------------------------------+
#property copyright "CK_XAU_ASIAN_FADE - Path B candidate"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>

//====================== INPUTS ======================================
input long   Inp_Magic               = 20260921;

//--- session (server-time hours) ---
input int    Inp_SessionStartHour    = 22;    // Asian open
input int    Inp_SessionEndHour      = 4;     // Asian close (next day; wraps midnight)
input int    Inp_RangeBars           = 8;     // first N M15 bars used for range definition (8 = 2h)

//--- entry ---
input double Inp_WickBodyRatio       = 1.5;   // wick / body >= this to fire
input double Inp_SLBufferATR         = 0.3;   // SL beyond range extreme + this*ATR(M15,14)
input int    Inp_ATRPeriod           = 14;

//--- filters ---
input bool   Inp_UseVolFilter        = true;
input double Inp_VolFilterMult       = 2.0;   // skip if ATR(H1,24) / ATR(D1,10) > this
input bool   Inp_UseNewsGate         = true;
input int    Inp_NewsBlockMin        = 6;
input int    Inp_MaxTradesPerWeek    = 3;

//--- risk / execution ---
input double Inp_RiskUSD             = 50.0;  // fixed $ risked per trade
input double Inp_MaxLot              = 0.10;
input double Inp_MaxSpreadPrice      = 0.60;  // skip if spread > this (price units)

//====================== STATE =======================================
CTrade   trade;
int      hATR_M15    = INVALID_HANDLE;   // M15 ATR for SL buffer
int      hATR_H1_24  = INVALID_HANDLE;   // 24-period H1 ATR = 24h volatility
int      hATR_D1_10  = INVALID_HANDLE;   // 10-period D1 ATR = 10-day baseline

datetime g_lastM15BarTime      = 0;

// current Asian session state
bool     g_inSession           = false;
double   g_rangeHigh           = 0.0;
double   g_rangeLow            = 0.0;
bool     g_rangeFixed          = false;
int      g_sessionBarCount     = 0;

// weekly trade cap (calendar bucket = day_of_year / 7 within the year)
int      g_tradesThisWeek      = 0;
int      g_currentWeekBucket   = -1;
int      g_currentYear         = -1;

// diagnostics
int      g_totalFires          = 0;
int      g_totalSkipsPos       = 0;
int      g_totalSkipsSpread    = 0;
int      g_totalSkipsNews      = 0;
int      g_totalSkipsVol       = 0;
int      g_totalSkipsCap       = 0;
int      g_totalSkipsNoATR     = 0;

//====================== SESSION-BOUNDARY HELPERS ====================
// Session may wrap midnight (start=22, end=04). Handle both wrapping and
// non-wrapping session windows.
bool IsInSession(const datetime t)
{
   MqlDateTime dt; TimeToStruct(t, dt);
   if(Inp_SessionStartHour < Inp_SessionEndHour)
      return(dt.hour >= Inp_SessionStartHour && dt.hour < Inp_SessionEndHour);
   else
      return(dt.hour >= Inp_SessionStartHour || dt.hour < Inp_SessionEndHour);
}

void ResetSessionState()
{
   g_inSession       = false;
   g_rangeHigh       = -DBL_MAX;
   g_rangeLow        =  DBL_MAX;
   g_rangeFixed      = false;
   g_sessionBarCount = 0;
}

void OnSessionOpen(const datetime t)
{
   g_inSession       = true;
   g_rangeHigh       = -DBL_MAX;
   g_rangeLow        =  DBL_MAX;
   g_rangeFixed      = false;
   g_sessionBarCount = 0;
   PrintFormat("[ASIAN_FADE] SESSION_OPEN  %s", TimeToString(t, TIME_DATE|TIME_MINUTES));
}

void OnSessionClose(const datetime t)
{
   // Flatten every one of MY positions - no overnight / weekend carry, per pre-reg §2.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i); if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Inp_Magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)   continue;
      trade.PositionClose(tk);
   }
   PrintFormat("[ASIAN_FADE] SESSION_CLOSE %s (flattened)", TimeToString(t, TIME_DATE|TIME_MINUTES));
   ResetSessionState();
}

//====================== M15 BAR + RANGE MGMT ========================
bool IsNewM15Bar()
{
   datetime t = iTime(_Symbol, PERIOD_M15, 0);
   if(t != g_lastM15BarTime) { g_lastM15BarTime = t; return(true); }
   return(false);
}

// Runs on each new M15 bar close DURING the session. Adds the just-closed
// bar's high/low into the range until the range-bar count is reached, then
// LOCKS the range (bars 9+ do not extend it).
void UpdateRange()
{
   if(g_rangeFixed) return;                                // range is locked
   double h1 = iHigh(_Symbol, PERIOD_M15, 1);
   double l1 = iLow (_Symbol, PERIOD_M15, 1);
   if(h1 > g_rangeHigh) g_rangeHigh = h1;
   if(l1 < g_rangeLow)  g_rangeLow  = l1;
   g_sessionBarCount++;
   if(g_sessionBarCount >= Inp_RangeBars)
   {
      g_rangeFixed = true;
      PrintFormat("[ASIAN_FADE] RANGE_FIXED after %d bars  high=%.2f low=%.2f mid=%.2f width=%.2f",
                  g_sessionBarCount, g_rangeHigh, g_rangeLow,
                  (g_rangeHigh + g_rangeLow) / 2.0, g_rangeHigh - g_rangeLow);
   }
}

//====================== FILTERS =====================================
double GetATRm15()
{
   if(hATR_M15 == INVALID_HANDLE) return(0.0);
   double b[1];
   if(CopyBuffer(hATR_M15, 0, 1, 1, b) < 1) return(0.0);
   return(b[0]);
}

// Volatility filter: skip fade entries if today is unusually volatile
// (24-period H1 ATR > Inp_VolFilterMult * 10-period D1 ATR). Fading a
// genuinely strong trend day is where mean-reversion strategies die.
bool VolFilterPasses()
{
   if(!Inp_UseVolFilter) return(true);
   if(hATR_H1_24 == INVALID_HANDLE || hATR_D1_10 == INVALID_HANDLE) return(true);
   double b24[1], bD[1];
   if(CopyBuffer(hATR_H1_24, 0, 1, 1, b24) < 1) return(true);
   if(CopyBuffer(hATR_D1_10, 0, 1, 1, bD)  < 1) return(true);
   double atr24 = b24[0], atrD = bD[0];
   if(atrD <= 0.0) return(true);
   return((atr24 / atrD) <= Inp_VolFilterMult);
}

bool NewsBlocked()
{
   if(!Inp_UseNewsGate) return(false);
   datetime now = TimeCurrent();
   int win = Inp_NewsBlockMin * 60;
   MqlCalendarValue vals[];
   int n = CalendarValueHistory(vals, now - win, now + win);
   if(n <= 0) return(false);
   for(int i = 0; i < n; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(vals[i].event_id, ev)) continue;
      if(ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
      return(true);
   }
   return(false);
}

bool SpreadOK()
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long   sp = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(pt <= 0.0) return(true);
   long mx = (long)MathRound(Inp_MaxSpreadPrice / pt);
   return(sp <= mx);
}

//====================== WEEKLY CAP ==================================
void UpdateWeeklyBucket()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   int bucket = dt.day_of_year / 7;
   if(dt.year != g_currentYear || bucket != g_currentWeekBucket)
   {
      g_currentYear       = dt.year;
      g_currentWeekBucket = bucket;
      g_tradesThisWeek    = 0;
   }
}

//====================== POSITION HELPERS ============================
int MyPositions()
{
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i); if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol) c++;
   }
   return(c);
}

double ComputeLot(const double slDistancePrice)
{
   if(slDistancePrice <= 0.0) return(0.0);
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contract <= 0.0) contract = 100.0;      // XAUUSD default
   double lossPerLot = slDistancePrice * contract;
   if(lossPerLot <= 0.0) return(0.0);
   double lot = Inp_RiskUSD / lossPerLot;

   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0.0) lot = MathFloor(lot / step) * step;
   if(lot < vmin) lot = vmin;
   if(lot > Inp_MaxLot) lot = Inp_MaxLot;
   if(vmax > 0.0 && lot > vmax) lot = vmax;
   return(lot);
}

//====================== BREAK-EVEN LOCK ============================
// After TP1 hits, one position remains. Move its SL to entry so the
// TP2-runner is a no-loss trade. Fires only when exactly ONE this-magic
// position is open (which is our TP2 leg after TP1 was harvested).
void ManageBreakEven()
{
   if(MyPositions() != 1) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i); if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Inp_Magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)   continue;
      if(!PositionSelectByTicket(tk)) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      long   type = PositionGetInteger(POSITION_TYPE);
      int    dg   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double pt   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(type == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > open + pt && sl < open - pt)
            trade.PositionModify(tk, NormalizeDouble(open, dg), tp);
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask < open - pt && (sl == 0.0 || sl > open + pt))
            trade.PositionModify(tk, NormalizeDouble(open, dg), tp);
      }
   }
}

//====================== ENTRY LOGIC =================================
void TryEnter()
{
   if(!g_rangeFixed) return;
   if(MyPositions() > 0)  { g_totalSkipsPos++;    return; }
   if(!SpreadOK())        { g_totalSkipsSpread++; return; }
   if(NewsBlocked())      { g_totalSkipsNews++;   return; }
   if(!VolFilterPasses()) { g_totalSkipsVol++;    return; }

   UpdateWeeklyBucket();
   if(g_tradesThisWeek >= Inp_MaxTradesPerWeek) { g_totalSkipsCap++; return; }

   // just-closed M15 bar (shift 1)
   double h1 = iHigh (_Symbol, PERIOD_M15, 1);
   double l1 = iLow  (_Symbol, PERIOD_M15, 1);
   double o1 = iOpen (_Symbol, PERIOD_M15, 1);
   double c1 = iClose(_Symbol, PERIOD_M15, 1);
   if(h1 <= 0.0) return;

   double body = MathAbs(c1 - o1);
   if(body <= 0.0) return;                              // doji, no signal

   double upperWick = h1 - MathMax(o1, c1);
   double lowerWick = MathMin(o1, c1) - l1;

   double atr = GetATRm15();
   if(atr <= 0.0) { g_totalSkipsNoATR++; return; }
   double buffer = atr * Inp_SLBufferATR;

   int    dg    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mid   = (g_rangeHigh + g_rangeLow) / 2.0;

   //---- SELL: fade top edge ----------------------------------------
   if(h1 >= g_rangeHigh && c1 < g_rangeHigh && upperWick >= body * Inp_WickBodyRatio)
   {
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl     = NormalizeDouble(g_rangeHigh + buffer, dg);
      double slDist = sl - bid;
      if(slDist <= 0.0) return;

      double tp1 = NormalizeDouble(mid,           dg);
      double tp2 = NormalizeDouble(g_rangeLow,    dg);

      double lot = ComputeLot(slDist);
      if(lot <= 0.0) return;

      // Split for TP1 (50%) and TP2 (50%). If sub-min-lot split isn't
      // possible on this broker, fall back to a single position with TP1.
      double lot1 = NormalizeDouble(lot / 2.0, 2);
      double lot2 = NormalizeDouble(lot - lot1, 2);

      if(lot1 < vmin || lot2 < vmin)
      {
         if(trade.Sell(lot, _Symbol, 0.0, sl, tp1))
         {
            g_totalFires++; g_tradesThisWeek++;
            PrintFormat("[ASIAN_FADE] SELL_single lot=%.2f sl=%.2f tp=%.2f (subminSplit)",
                        lot, sl, tp1);
         }
         return;
      }

      bool ok1 = trade.Sell(lot1, _Symbol, 0.0, sl, tp1);
      bool ok2 = trade.Sell(lot2, _Symbol, 0.0, sl, tp2);
      if(ok1 || ok2)
      {
         g_totalFires++; g_tradesThisWeek++;
         PrintFormat("[ASIAN_FADE] SELL lot1=%.2f tp1=%.2f  lot2=%.2f tp2=%.2f  sl=%.2f  rangeH=%.2f L=%.2f",
                     lot1, tp1, lot2, tp2, sl, g_rangeHigh, g_rangeLow);
      }
      return;
   }

   //---- BUY: fade bottom edge --------------------------------------
   if(l1 <= g_rangeLow && c1 > g_rangeLow && lowerWick >= body * Inp_WickBodyRatio)
   {
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl     = NormalizeDouble(g_rangeLow - buffer, dg);
      double slDist = ask - sl;
      if(slDist <= 0.0) return;

      double tp1 = NormalizeDouble(mid,           dg);
      double tp2 = NormalizeDouble(g_rangeHigh,   dg);

      double lot = ComputeLot(slDist);
      if(lot <= 0.0) return;

      double lot1 = NormalizeDouble(lot / 2.0, 2);
      double lot2 = NormalizeDouble(lot - lot1, 2);

      if(lot1 < vmin || lot2 < vmin)
      {
         if(trade.Buy(lot, _Symbol, 0.0, sl, tp1))
         {
            g_totalFires++; g_tradesThisWeek++;
            PrintFormat("[ASIAN_FADE] BUY_single lot=%.2f sl=%.2f tp=%.2f (subminSplit)",
                        lot, sl, tp1);
         }
         return;
      }

      bool ok1 = trade.Buy(lot1, _Symbol, 0.0, sl, tp1);
      bool ok2 = trade.Buy(lot2, _Symbol, 0.0, sl, tp2);
      if(ok1 || ok2)
      {
         g_totalFires++; g_tradesThisWeek++;
         PrintFormat("[ASIAN_FADE] BUY lot1=%.2f tp1=%.2f  lot2=%.2f tp2=%.2f  sl=%.2f  rangeH=%.2f L=%.2f",
                     lot1, tp1, lot2, tp2, sl, g_rangeHigh, g_rangeLow);
      }
   }
}

//====================== LIFECYCLE ==================================
int OnInit()
{
   trade.SetExpertMagicNumber(Inp_Magic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_NO);

   hATR_M15   = iATR(_Symbol, PERIOD_M15, Inp_ATRPeriod);
   hATR_H1_24 = iATR(_Symbol, PERIOD_H1, 24);
   hATR_D1_10 = iATR(_Symbol, PERIOD_D1, 10);
   if(hATR_M15 == INVALID_HANDLE)   return(INIT_FAILED);
   // The volatility-filter handles are allowed to be invalid: filter fails
   // open in that case (returns true = pass).

   ResetSessionState();
   g_tradesThisWeek    = 0;
   g_currentWeekBucket = -1;
   g_currentYear       = -1;

   PrintFormat("[ASIAN_FADE] init  session=%02d:00-%02d:00 server  rangeBars=%d  wick/body>=%.1f  slBuf=%.1f*ATR  risk=$%.0f  magic=%I64d",
               Inp_SessionStartHour, Inp_SessionEndHour, Inp_RangeBars,
               Inp_WickBodyRatio, Inp_SLBufferATR, Inp_RiskUSD, Inp_Magic);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int r)
{
   if(hATR_M15   != INVALID_HANDLE) IndicatorRelease(hATR_M15);
   if(hATR_H1_24 != INVALID_HANDLE) IndicatorRelease(hATR_H1_24);
   if(hATR_D1_10 != INVALID_HANDLE) IndicatorRelease(hATR_D1_10);
   PrintFormat("[ASIAN_FADE] deinit  fires=%d  skips[pos=%d spread=%d news=%d vol=%d cap=%d noATR=%d]",
               g_totalFires, g_totalSkipsPos, g_totalSkipsSpread,
               g_totalSkipsNews, g_totalSkipsVol, g_totalSkipsCap, g_totalSkipsNoATR);
}

void OnTick()
{
   datetime now = TimeCurrent();
   bool inSess  = IsInSession(now);

   // BE-lock manage FIRST so a mid-tick TP1 fill is followed by SL move on same tick
   ManageBreakEven();

   // session boundary transitions
   if(inSess && !g_inSession)      OnSessionOpen(now);
   else if(!inSess && g_inSession) OnSessionClose(now);

   if(!g_inSession) return;
   if(!IsNewM15Bar()) return;

   UpdateRange();
   TryEnter();
}

//====================== OnTester: emit deals for parity check =======
// Writes ck_xau_asian_fade_deals.csv to MQL5\Common\Files with the same
// schema used by CK_GOLD_COMBO -> loss_visualizer + _compare_plans.py can
// diff both plans directly.
double OnTester()
{
   int h = FileOpen("ck_xau_asian_fade_deals.csv",
                    FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
   if(h != INVALID_HANDLE)
   {
      FileWrite(h, "magic","dir","entry_time","entry_price","exit_time","exit_price","profit","volume","hold_sec");
      HistorySelect(0, TimeCurrent());
      int ndl = HistoryDealsTotal();
      for(int i = 0; i < ndl; i++)
      {
         ulong o = HistoryDealGetTicket(i); if(o == 0) continue;
         if(HistoryDealGetString(o, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(o, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         if(HistoryDealGetInteger(o, DEAL_MAGIC) != Inp_Magic) continue;
         long pid = HistoryDealGetInteger(o, DEAL_POSITION_ID);
         datetime et = 0; double ep = 0.0; long dir = -1;
         for(int j = 0; j < ndl; j++)
         {
            ulong in = HistoryDealGetTicket(j); if(in == 0) continue;
            if(HistoryDealGetInteger(in, DEAL_POSITION_ID) != pid) continue;
            if(HistoryDealGetInteger(in, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            et  = (datetime)HistoryDealGetInteger(in, DEAL_TIME);
            ep  = HistoryDealGetDouble(in, DEAL_PRICE);
            dir = HistoryDealGetInteger(in, DEAL_TYPE);
            break;
         }
         datetime xt = (datetime)HistoryDealGetInteger(o, DEAL_TIME);
         double   xp = HistoryDealGetDouble(o, DEAL_PRICE);
         double   p  = HistoryDealGetDouble(o, DEAL_PROFIT) +
                       HistoryDealGetDouble(o, DEAL_SWAP)   +
                       HistoryDealGetDouble(o, DEAL_COMMISSION);
         string   ds = (dir == DEAL_TYPE_BUY) ? "buy" : ((dir == DEAL_TYPE_SELL) ? "sell" : "na");
         double   vol = HistoryDealGetDouble(o, DEAL_VOLUME);
         long     hs  = (long)(xt - et);
         FileWrite(h, IntegerToString(Inp_Magic), ds,
                   TimeToString(et, TIME_DATE|TIME_MINUTES),
                   DoubleToString(ep, 2),
                   TimeToString(xt, TIME_DATE|TIME_MINUTES),
                   DoubleToString(xp, 2),
                   DoubleToString(p,  2),
                   DoubleToString(vol,2),
                   IntegerToString(hs));
      }
      FileClose(h);
   }
   return(0.0);
}

//+------------------------------------------------------------------+

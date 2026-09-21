//+------------------------------------------------------------------+
//|  CK_GOLD_DONCHIAN.mq5 - Classic 20-bar Donchian breakout on XAU  |
//|                                                                    |
//|  Pre-registered per SPEC/PREREG_DONCHIAN_20.md, ledger seq287.    |
//|                                                                    |
//|  HYPOTHESIS: Gold's only durable edge is TREND (steering §5,      |
//|  reinforced by 16 prior REJECTs of mean-reversion patterns). A    |
//|  pure Donchian breakout captures every trend, symmetric long/short|
//|  no pullback wait, no trend filter. If this passes the same 8     |
//|  pass bars as prior candidates, it's a differentiated 2nd or 3rd  |
//|  EA for the multi-account plan (SPEC/MULTI_ACCOUNT_PLAN.md).      |
//|                                                                    |
//|  METHOD (LOCKED per pre-reg):                                     |
//|   Entry (evaluated at M15 bar close):                             |
//|     LONG  = close[1] > highest(close, 20, shift=2)                |
//|     SHORT = close[1] < lowest (close, 20, shift=2)                |
//|     Enter at next bar open (market order at first tick after      |
//|     new M15 bar starts).                                          |
//|   SL = entry ± 2.0 * ATR14(M15) opposite direction.               |
//|   TP = entry ± 3.0 * R where R = entry-to-SL distance.            |
//|   Fixed 0.02 lot, max 3 trades/day, force close 22:30 server.     |
//|   No overnight, no Friday-after-20, news gate ±6 min, spread ≤60. |
//+------------------------------------------------------------------+
#property copyright "CK GOLD DONCHIAN 20-bar breakout"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//====================== INPUTS =====================================
input long   Inp_Magic              = 20260921003;
input double Inp_FixedLot           = 0.02;
input int    Inp_MaxTradesPerDay    = 3;
input int    Inp_MaxSpreadPoints    = 60;

input int    Inp_BreakoutLookback   = 20;      // 20-bar Donchian
input int    Inp_ATRPeriod          = 14;
input double Inp_SL_ATR             = 2.0;     // SL = entry - 2*ATR
input double Inp_TP_Rmultiple       = 3.0;     // TP = entry + 3R

input int    Inp_SessionStartHour   = 8;
input int    Inp_SessionEndHour     = 22;
input int    Inp_ForceCloseHour     = 22;
input int    Inp_ForceCloseMinute   = 30;
input bool   Inp_BlockFridayEvening = true;
input int    Inp_FridayBlockHour    = 20;
input bool   Inp_UseNewsGate        = true;
input int    Inp_NewsBlockMin       = 6;

//====================== STATE ======================================
datetime  g_last_m15_bar_time = 0;
int       g_atr_handle        = INVALID_HANDLE;
int       g_today_ymd         = 0;
int       g_trades_today      = 0;

int OnInit(){
   trade.SetExpertMagicNumber(Inp_Magic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_NO);
   g_atr_handle = iATR(_Symbol, PERIOD_M15, Inp_ATRPeriod);
   if(g_atr_handle == INVALID_HANDLE){
      Print("ATR handle FAILED");
      return(INIT_FAILED);
   }
   g_today_ymd    = 0;   // force first-day reset
   g_trades_today = 0;
   PrintFormat("CK_GOLD_DONCHIAN init OK  magic=%I64d  lot=%.2f  lookback=%d  SL=%.1fATR  TP=%.1fR",
               Inp_Magic, Inp_FixedLot, Inp_BreakoutLookback, Inp_SL_ATR, Inp_TP_Rmultiple);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

//====================== HELPERS ====================================
double ATR_M15(){
   double b[]; ArraySetAsSeries(b, true);
   if(CopyBuffer(g_atr_handle, 0, 0, 1, b) <= 0) return(0);
   return(b[0]);
}

bool IsNewM15Bar(){
   datetime t = iTime(_Symbol, PERIOD_M15, 0);
   if(t != g_last_m15_bar_time){ g_last_m15_bar_time = t; return(true); }
   return(false);
}

bool SpreadOK(){
   long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return(sp <= Inp_MaxSpreadPoints);
}

bool WithinSession(){
   MqlDateTime mt; TimeToStruct(TimeCurrent(), mt);
   if(mt.hour < Inp_SessionStartHour) return(false);
   if(mt.hour > Inp_SessionEndHour)   return(false);
   if(mt.hour == Inp_SessionEndHour && mt.min > 0) return(false);
   return(true);
}

bool FridayEveningBlocked(){
   if(!Inp_BlockFridayEvening) return(false);
   MqlDateTime mt; TimeToStruct(TimeCurrent(), mt);
   if(mt.day_of_week == 5 && mt.hour >= Inp_FridayBlockHour) return(true);
   return(false);
}

bool IsForceCloseTime(){
   MqlDateTime mt; TimeToStruct(TimeCurrent(), mt);
   if(mt.hour > Inp_ForceCloseHour) return(true);
   if(mt.hour == Inp_ForceCloseHour && mt.min >= Inp_ForceCloseMinute) return(true);
   return(false);
}

bool IsNewsBlocked(){
   if(!Inp_UseNewsGate) return(false);
   datetime now = TimeCurrent();
   int win = Inp_NewsBlockMin * 60;
   MqlCalendarValue vals[];
   int n = CalendarValueHistory(vals, now-win, now+win);
   if(n <= 0) return(false);
   for(int i = 0; i < n; i++){
      MqlCalendarEvent ev;
      if(!CalendarEventById(vals[i].event_id, ev)) continue;
      if(ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
      return(true);
   }
   return(false);
}

int MyPositions(){
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong tk = PositionGetTicket(i); if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Inp_Magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      c++;
   }
   return(c);
}

void CloseAllMyPositions(){
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong tk = PositionGetTicket(i); if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Inp_Magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      trade.PositionClose(tk);
   }
}

//====================== BREAKOUT CHECK =============================
// Returns 1 = LONG signal, -1 = SHORT signal, 0 = none
// Evaluated at close of just-closed M15 bar (bar index 1).
int CheckBreakout(){
   int lb = Inp_BreakoutLookback;
   // Reference: highest CLOSE of bars 2 to (2 + lb - 1)  (lb bars starting at bar 2)
   double closes[]; ArraySetAsSeries(closes, false);
   if(CopyClose(_Symbol, PERIOD_M15, 2, lb, closes) < lb) return(0);

   double c1 = iClose(_Symbol, PERIOD_M15, 1);   // just-closed bar
   double ref_hi = closes[0];
   double ref_lo = closes[0];
   for(int i = 1; i < lb; i++){
      if(closes[i] > ref_hi) ref_hi = closes[i];
      if(closes[i] < ref_lo) ref_lo = closes[i];
   }
   if(c1 > ref_hi) return(1);
   if(c1 < ref_lo) return(-1);
   return(0);
}

//====================== TRADE ENTRY ================================
void OpenTrade(int direction){
   if(MyPositions() > 0) return;
   if(g_trades_today >= Inp_MaxTradesPerDay) return;
   if(!WithinSession()) return;
   if(FridayEveningBlocked()) return;
   if(IsNewsBlocked()) return;
   if(!SpreadOK()) return;

   double atr = ATR_M15();
   if(atr <= 0) return;

   double sl_dist = Inp_SL_ATR * atr;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double entry_px, sl_px, tp_px;
   if(direction > 0){
      entry_px = ask;
      sl_px    = entry_px - sl_dist;
      tp_px    = entry_px + Inp_TP_Rmultiple * sl_dist;
   } else {
      entry_px = bid;
      sl_px    = entry_px + sl_dist;
      tp_px    = entry_px - Inp_TP_Rmultiple * sl_dist;
   }

   double lots = Inp_FixedLot;
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / st) * st;
   if(lots < mn) lots = mn;

   sl_px = NormalizeDouble(sl_px, dg);
   tp_px = NormalizeDouble(tp_px, dg);

   bool ok = false;
   if(direction > 0) ok = trade.Buy (lots, _Symbol, 0, sl_px, tp_px, "DONCHIAN_L");
   else              ok = trade.Sell(lots, _Symbol, 0, sl_px, tp_px, "DONCHIAN_S");

   if(ok){
      g_trades_today++;
      PrintFormat("[DONCHIAN] %s  entry=%.2f  sl=%.2f  tp=%.2f  atr=%.2f  today=%d",
                  direction > 0 ? "LONG" : "SHORT", entry_px, sl_px, tp_px, atr, g_trades_today);
   }
}

void ForceCloseIfCutoff(){
   if(IsForceCloseTime() && MyPositions() > 0){
      CloseAllMyPositions();
   }
}

//====================== ONTESTER CSV ===============================
double OnTester(){
   int h = FileOpen("ck_gold_donchian_deals.csv",
                    FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h != INVALID_HANDLE){
      FileWrite(h, "time_close", "type", "volume", "price_open", "price_close",
                   "sl", "tp", "profit", "swap", "commission", "comment");
      HistorySelect(0, TimeCurrent());
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++){
         ulong tk = HistoryDealGetTicket(i); if(tk == 0) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(tk, DEAL_MAGIC) != Inp_Magic) continue;
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         datetime xt = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
         long     dt = HistoryDealGetInteger(tk, DEAL_TYPE);
         double   vol= HistoryDealGetDouble (tk, DEAL_VOLUME);
         double   px = HistoryDealGetDouble (tk, DEAL_PRICE);
         double   pf = HistoryDealGetDouble (tk, DEAL_PROFIT);
         double   sw = HistoryDealGetDouble (tk, DEAL_SWAP);
         double   cm = HistoryDealGetDouble (tk, DEAL_COMMISSION);
         double   sl = HistoryDealGetDouble (tk, DEAL_SL);
         double   tp = HistoryDealGetDouble (tk, DEAL_TP);
         string   cm_s = HistoryDealGetString(tk, DEAL_COMMENT);
         long     pos_id = HistoryDealGetInteger(tk, DEAL_POSITION_ID);
         double   open_px = 0;
         for(int j = i - 1; j >= 0; j--){
            ulong tk2 = HistoryDealGetTicket(j); if(tk2 == 0) continue;
            if(HistoryDealGetInteger(tk2, DEAL_POSITION_ID) != pos_id) continue;
            if(HistoryDealGetInteger(tk2, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            open_px = HistoryDealGetDouble(tk2, DEAL_PRICE);
            break;
         }
         string type_str = (dt == DEAL_TYPE_BUY) ? "SELL_close" : "BUY_close";
         FileWrite(h,
                   TimeToString(xt, TIME_DATE|TIME_MINUTES),
                   type_str,
                   DoubleToString(vol, 2),
                   DoubleToString(open_px, 2),
                   DoubleToString(px, 2),
                   DoubleToString(sl, 2),
                   DoubleToString(tp, 2),
                   DoubleToString(pf, 2),
                   DoubleToString(sw, 2),
                   DoubleToString(cm, 2),
                   cm_s);
      }
      FileClose(h);
      PrintFormat("[DONCHIAN] OnTester: deals CSV written to Common\\Files\\ck_gold_donchian_deals.csv");
   } else {
      PrintFormat("[DONCHIAN] OnTester: FileOpen FAILED err=%d", GetLastError());
   }
   return(0.0);
}

//====================== MAIN =======================================
void OnTick(){
   ForceCloseIfCutoff();

   if(!IsNewM15Bar()) return;

   // Daily counter reset based on M15 bar's date
   MqlDateTime mt; TimeToStruct(iTime(_Symbol, PERIOD_M15, 0), mt);
   int today_ymd = mt.year * 10000 + mt.mon * 100 + mt.day;
   if(today_ymd != g_today_ymd){
      g_today_ymd = today_ymd;
      g_trades_today = 0;
   }

   // Evaluate breakout on just-closed bar (bar 1)
   int signal = CheckBreakout();
   if(signal == 0) return;

   OpenTrade(signal);
}
//+------------------------------------------------------------------+

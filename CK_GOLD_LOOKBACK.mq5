//+------------------------------------------------------------------+
//|  CK_GOLD_LOOKBACK.mq5 - Keshav Jindal Gold LookBack strategy      |
//|                                                                    |
//|  HYPOTHESIS: Low-Volume Nodes (LVN) in yesterday's M30 volume     |
//|  profile mark zones where the market moved through fast because   |
//|  it did not agree on fair value. When price re-enters an LVN      |
//|  the next day, it should PUNCH THROUGH (continuation), not fade.  |
//|                                                                    |
//|  This is CONTINUATION-through-LVN, NOT mean-reversion at a level. |
//|  Structurally different from 14+ prior mean-reversion rejects on  |
//|  gold (seq95, 102, 107, 120, 141, 144, 155, 157, 158, 165, 232,   |
//|  272, 274, 280). Same directional-flow family as FIX09 (the only  |
//|  surviving edge on gold per steering §5).                         |
//|                                                                    |
//|  SOURCE: @premium_piips Instagram video by Keshav Jindal,         |
//|  transcript relayed by user 2026-09-21. Setup-decoder formalized. |
//|  Pre-registration: SPEC/PREREG_GOLD_LOOKBACK.md, ledger seq281.   |
//|                                                                    |
//|  METHOD (LOCKED per pre-reg):                                     |
//|   1. Daily 00:00 server: build FRVP from previous day's M30 bars  |
//|      in server-window 13:00 -> 23:30 (=IST 15:30 -> 02:00).       |
//|   2. 40 bins over [low, high] of that window. Volume = tick vol.  |
//|   3. LVN bin = local min AND vol <= 25% of max bin.               |
//|   4. Zone = contiguous LVN bins. Min height max(0.30*ATR, $3).    |
//|      Min depth = avg vol <= 40% of max bin. Keep top-4 deepest.   |
//|   5. On M5 today: state machine per zone.                         |
//|      IDLE -> INSIDE (bar overlaps zone, entry_side recorded)      |
//|             -> TOUCHED_50 (wick reaches midpoint)                 |
//|                 -> ARMED (bar close beyond OPPOSITE boundary)     |
//|                     -> TAKEN (market order, direction=exit dir)   |
//|   6. SL = 0.30 * ATR14(M5) beyond zone far-side.                  |
//|   7. TP = nearest remaining zone in direction, or 2R fallback.    |
//|   8. Fixed 0.02 lot, max 2 trades/day, force-close 23:30,         |
//|      news gate +-6min, no overnight, no weekend, spread <60pt.    |
//|                                                                    |
//|  HOW TO TEST (Strategy Tester):                                   |
//|    Symbol=XAUUSD  Timeframe=M5 (entry TF)                         |
//|    Deposit=6000  Leverage=1:100  Model=1min OHLC first            |
//|    Window: 2025-10-01 -> 2026-09-17                               |
//|    NO input changes - all locked per pre-reg.                     |
//+------------------------------------------------------------------+
#property copyright "CK GOLD LOOKBACK (Keshav Jindal FRVP LVN continuation)"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//====================== CORE / RISK ================================
input long   Inp_Magic              = 20260921002;  // distinct from FIX09 / DT / others
input double Inp_FixedLot           = 0.02;         // pinned per pre-reg for Plan-C comparability
input int    Inp_MaxTradesPerDay    = 2;
input int    Inp_MaxSpreadPoints    = 60;

//====================== FRVP SCAN ==================================
input int    Inp_ScanStartHour      = 13;   // yesterday, server GMT+3 (= IST 15:30)
input int    Inp_ScanEndHour        = 23;   // yesterday
input int    Inp_ScanEndMinute      = 30;   // 23:30
input int    Inp_Bins               = 40;
input double Inp_LVNPctOfMax        = 30.0; // bin qualifies if vol <= this% of max (v2: no local-min requirement)
input double Inp_MinZoneHeightATR   = 0.30; // min zone height = max(this*ATR, MinZoneHeightUSD)
input double Inp_MinZoneHeightUSD   = 3.0;  // absolute floor in $
input double Inp_ZoneDepthAvgPct    = 40.0; // avg vol in zone <= this% of max bin
input int    Inp_TopK               = 4;    // keep only deepest 4 zones

//====================== ENTRY LOGIC =============================
input ENUM_TIMEFRAMES Inp_EntryTF   = PERIOD_M5;  // v12: switch to PERIOD_M15 for less noise, fewer trades
input int    Inp_ATRPeriodM5        = 14;
input double Inp_SLBufferATR        = 0.30; // SL = 0.30 * ATR beyond zone far-side
input double Inp_R_Multiple_Fallback= 2.0;  // TP fallback if no next zone
input int    Inp_MaxBarsPerZone     = 20;   // expire zone if not ARMED within N bars of INSIDE

//====================== SESSION / GUARDS ===========================
input int    Inp_SessionStartHour   = 13;   // no entries before this server hour
input int    Inp_SessionEndHour     = 23;   // no entries after this server hour
input int    Inp_ForceCloseHour     = 23;   // flat all positions at this hour:min
input int    Inp_ForceCloseMinute   = 30;
input bool   Inp_BlockFridayEvening = true;
input int    Inp_FridayBlockHour    = 20;
input bool   Inp_UseForceClose      = true;    // v11: set false to let SL/TP run naturally (overnight OK on FN)

//====================== v14 DAILY GOVERNOR =========================
input bool   Inp_UseDailyBudget     = false;   // v14: pre-trade skip if today loss + this SL would breach budget
input double Inp_DailyLossBudget    = 150.0;   // max $ loss allowed per day (FN $6k = $300 hard, $150 safe buffer)
input bool   Inp_UseNewsGate        = true;
input int    Inp_NewsBlockMin       = 6;

//====================== TREND FILTER (v7) ==========================
input bool   Inp_UseTrendFilter     = false;         // v7: align with gold's trend edge
input ENUM_TIMEFRAMES Inp_TrendEMATF = PERIOD_H1;    // H1 EMA for trend direction
input int    Inp_TrendEMAPeriod     = 200;           // 200-period EMA (classic trend filter)

//====================== INTERNAL STATE =============================
enum ZoneState { ST_IDLE, ST_INSIDE, ST_TOUCHED50, ST_ARMED, ST_TAKEN, ST_EXPIRED };
enum EntrySide { SIDE_NONE, SIDE_TOP, SIDE_BOTTOM };

struct Zone {
   double    upper;         // zone upper price boundary
   double    lower;         // zone lower price boundary
   double    mid;           // midpoint
   double    depth_pct;     // avg vol / max vol (lower = deeper LVN)
   ZoneState state;
   EntrySide entry_side;    // from which side price entered
   int       bars_since_inside;
   datetime  entered_at;    // for diagnostics
};

Zone      g_zones[];
int       g_num_zones          = 0;
datetime  g_last_scan_day      = 0;
datetime  g_last_m5_bar_time   = 0;
datetime  g_last_m30_bar_time  = 0;
int       g_atrM5_handle       = INVALID_HANDLE;
int       g_atrM30_handle      = INVALID_HANDLE;
int       g_trendEMA_handle    = INVALID_HANDLE;   // v7 trend filter
int       g_today_ymd          = 0;   // YYYYMMDD int of current day - tracked via TimeCurrent, robust to D1 bar edge cases
datetime  g_day_start          = 0;   // today's 00:00 server
int       g_trades_today       = 0;
double    g_day_start_balance  = 0;   // v14: balance snapshot at daily rollover (for daily budget check)
int       g_arm_pending_idx    = -1;  // zone index that ARMED this bar, execute next tick

//===================================================================
int OnInit(){
   trade.SetExpertMagicNumber(Inp_Magic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_NO);
   ArrayResize(g_zones, Inp_TopK);
   g_atrM5_handle  = iATR(_Symbol, Inp_EntryTF,  Inp_ATRPeriodM5);
   g_atrM30_handle = iATR(_Symbol, PERIOD_M30, 14);
   if(g_atrM5_handle == INVALID_HANDLE || g_atrM30_handle == INVALID_HANDLE){
      Print("ATR handle init FAILED");
      return(INIT_FAILED);
   }
   if(Inp_UseTrendFilter){
      g_trendEMA_handle = iMA(_Symbol, Inp_TrendEMATF, Inp_TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_trendEMA_handle == INVALID_HANDLE){
         Print("Trend EMA handle init FAILED");
         return(INIT_FAILED);
      }
   }
   // Sentinel: force OnTick's day-rollover check to fire on first tick
   g_today_ymd       = 0;
   g_day_start       = 0;
   g_trades_today    = 0;
   g_arm_pending_idx = -1;
   PrintFormat("CK_GOLD_LOOKBACK init OK  magic=%I64d  lot=%.2f  bins=%d  topK=%d",
               Inp_Magic, Inp_FixedLot, Inp_Bins, Inp_TopK);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   if(g_atrM5_handle  != INVALID_HANDLE) IndicatorRelease(g_atrM5_handle);
   if(g_atrM30_handle != INVALID_HANDLE) IndicatorRelease(g_atrM30_handle);
   if(g_trendEMA_handle != INVALID_HANDLE) IndicatorRelease(g_trendEMA_handle);
}

// v7 trend filter: check if signal direction aligns with H1 EMA200 trend
bool TrendAlignedForDirection(bool is_long){
   if(!Inp_UseTrendFilter) return(true);   // filter off, always pass
   if(g_trendEMA_handle == INVALID_HANDLE) return(true);
   double buf[]; ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_trendEMA_handle, 0, 0, 1, buf) <= 0) return(true);
   double ema = buf[0];
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(is_long)  return(bid > ema);   // LONG only in uptrend (price above EMA)
   else         return(bid < ema);   // SHORT only in downtrend
}

//===================================================================
// HELPERS
//===================================================================
double ATR_M5(){
   double b[]; ArraySetAsSeries(b, true);
   if(CopyBuffer(g_atrM5_handle, 0, 0, 1, b) <= 0) return(0);
   return(b[0]);
}
double ATR_M30(){
   double b[]; ArraySetAsSeries(b, true);
   if(CopyBuffer(g_atrM30_handle, 0, 0, 1, b) <= 0) return(0);
   return(b[0]);
}

bool IsNewM5Bar(){
   datetime t = iTime(_Symbol, Inp_EntryTF, 0);
   if(t != g_last_m5_bar_time){ g_last_m5_bar_time = t; return(true); }
   return(false);
}

bool IsNewDay(){
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_last_scan_day){ g_last_scan_day = today; return(true); }
   return(false);
}

void ResetDaily(){
   MqlDateTime mt; TimeToStruct(TimeCurrent(), mt);
   mt.hour = 0; mt.min = 0; mt.sec = 0;
   g_day_start    = StructToTime(mt);
   g_trades_today = 0;
   g_arm_pending_idx = -1;
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

// News gate: block +-N min around high-impact events. Silent if calendar unavailable.
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

//===================================================================
// FRVP BUILD - runs daily at 00:00 server, scans YESTERDAY 13:00 -> 23:30
//===================================================================
bool RebuildZones(){
   g_num_zones = 0;
   for(int z = 0; z < Inp_TopK; z++){
      g_zones[z].state = ST_IDLE;
      g_zones[z].entry_side = SIDE_NONE;
   }

   if(g_day_start == 0) return(false);

   // Count-based fetch: last 22 M30 bars strictly before today 00:00 server.
   // On Mon (post-weekend), this returns Fri's session bars automatically since
   // Sat/Sun have no M30 bars - which is what a human trader following the strategy
   // would do (use last complete trading session).
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, PERIOD_M30, g_day_start - 1, 22, rates);
   int expected_min = 18; // 10.5h theoretical = 21 M30, allow up to 3-bar slack
   if(copied < expected_min){
      PrintFormat("[LOOKBACK] Rebuild skipped: only %d M30 bars found before %s (need %d)",
                  copied,
                  TimeToString(g_day_start, TIME_DATE|TIME_MINUTES),
                  expected_min);
      return(false);
   }
   // Filter: keep only bars whose open time is in the Inp_ScanStart..Inp_ScanEnd window
   // of the same trading session (measured from the LATEST bar's date).
   // This preserves the pre-reg intent (13:00-23:30 window) while being robust to weekends.
   MqlDateTime last_mt; TimeToStruct(rates[copied - 1].time, last_mt);
   int session_ymd = last_mt.year * 10000 + last_mt.mon * 100 + last_mt.day;
   int keep = 0;
   MqlRates filtered[]; ArrayResize(filtered, copied);
   for(int i = 0; i < copied; i++){
      MqlDateTime bt; TimeToStruct(rates[i].time, bt);
      int ymd = bt.year * 10000 + bt.mon * 100 + bt.day;
      if(ymd != session_ymd) continue;                                // different day, skip
      int hm = bt.hour * 60 + bt.min;
      int win_start = Inp_ScanStartHour * 60;
      int win_end   = Inp_ScanEndHour * 60 + Inp_ScanEndMinute;
      if(hm < win_start || hm > win_end) continue;                    // outside 13:00-23:30
      filtered[keep++] = rates[i];
   }
   if(keep < expected_min){
      PrintFormat("[LOOKBACK] Rebuild skipped: after session filter only %d bars in %04d-%02d-%02d %02d:00-%02d:%02d (need %d)",
                  keep, last_mt.year, last_mt.mon, last_mt.day,
                  Inp_ScanStartHour, Inp_ScanEndHour, Inp_ScanEndMinute,
                  expected_min);
      return(false);
   }
   ArrayResize(rates, keep);
   for(int i = 0; i < keep; i++) rates[i] = filtered[i];
   copied = keep;

   // Build price grid
   double lo = rates[0].low;
   double hi = rates[0].high;
   for(int i = 1; i < copied; i++){
      if(rates[i].high > hi) hi = rates[i].high;
      if(rates[i].low  < lo) lo = rates[i].low;
   }
   if(hi <= lo) return(false);
   double binw = (hi - lo) / (double)Inp_Bins;
   if(binw <= 0) return(false);

   // Aggregate tick-volume into bins by typical price
   double vol[]; ArrayResize(vol, Inp_Bins); ArrayInitialize(vol, 0.0);
   for(int i = 0; i < copied; i++){
      double tp = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      int    b  = (int)((tp - lo) / binw);
      if(b < 0) b = 0;
      if(b >= Inp_Bins) b = Inp_Bins - 1;
      vol[b] += (double)rates[i].tick_volume;
   }

   // Find max bin volume for normalization
   double vmax = vol[0];
   for(int b = 1; b < Inp_Bins; b++) if(vol[b] > vmax) vmax = vol[b];
   if(vmax <= 0){
      PrintFormat("[LOOKBACK] Rebuild: vmax=0 - abnormal, skipping");
      return(false);
   }

   double lvn_thresh = vmax * (Inp_LVNPctOfMax / 100.0);
   double depth_thresh = vmax * (Inp_ZoneDepthAvgPct / 100.0);

   // v2 LVN rule: bin qualifies if vol <= threshold (drop local-min requirement).
   // This is the seq283 pre-registered change from seq281.
   bool is_lvn[]; ArrayResize(is_lvn, Inp_Bins); ArrayInitialize(is_lvn, false);
   for(int b = 0; b < Inp_Bins; b++){
      is_lvn[b] = (vol[b] <= lvn_thresh);
   }

   // Collapse contiguous LVN bins into candidate zones
   double atr30 = ATR_M30();
   double min_height = MathMax(Inp_MinZoneHeightATR * atr30, Inp_MinZoneHeightUSD);

   Zone   candidates[];
   int    n_cand = 0;
   ArrayResize(candidates, Inp_Bins);

   int b = 0;
   while(b < Inp_Bins){
      if(!is_lvn[b]){ b++; continue; }
      int start = b;
      double sum_v = vol[b];
      int    cnt   = 1;
      while(b + 1 < Inp_Bins && is_lvn[b + 1]){
         b++;
         sum_v += vol[b];
         cnt++;
      }
      int end = b;
      double zone_low  = lo + (double)start * binw;
      double zone_high = lo + (double)(end + 1) * binw;
      double avg_v     = sum_v / (double)cnt;
      double depth     = (vmax > 0) ? (avg_v / vmax) : 1.0;

      if((zone_high - zone_low) >= min_height && avg_v <= depth_thresh){
         candidates[n_cand].upper      = zone_high;
         candidates[n_cand].lower      = zone_low;
         candidates[n_cand].mid        = (zone_high + zone_low) * 0.5;
         candidates[n_cand].depth_pct  = depth;
         candidates[n_cand].state      = ST_IDLE;
         candidates[n_cand].entry_side = SIDE_NONE;
         candidates[n_cand].bars_since_inside = 0;
         n_cand++;
      }
      b++;
   }
   if(n_cand == 0){
      MqlDateTime dt; TimeToStruct(rates[0].time, dt);
      PrintFormat("[LOOKBACK] Rebuild: 0 LVN candidates for %04d-%02d-%02d (vmax=%.0f lvn_thresh=%.0f depth_thresh=%.0f binw=%.2f)",
                  dt.year, dt.mon, dt.day, vmax, lvn_thresh, depth_thresh, binw);
      return(false);
   }

   // Sort candidates by depth_pct ascending (deepest = smallest ratio first)
   for(int i = 0; i < n_cand - 1; i++){
      for(int j = i + 1; j < n_cand; j++){
         if(candidates[j].depth_pct < candidates[i].depth_pct){
            Zone tmp = candidates[i]; candidates[i] = candidates[j]; candidates[j] = tmp;
         }
      }
   }

   // Keep top-K
   int k = MathMin(n_cand, Inp_TopK);
   for(int i = 0; i < k; i++) g_zones[i] = candidates[i];
   g_num_zones = k;

   PrintFormat("[LOOKBACK] Zones rebuilt: %d found, %d kept. session %s (%d bars)  hi=%.2f lo=%.2f vmax=%.0f",
               n_cand, k,
               TimeToString(rates[0].time, TIME_DATE|TIME_MINUTES),
               copied,
               hi, lo, vmax);
   for(int i = 0; i < k; i++){
      PrintFormat("  Zone[%d]: [%.2f, %.2f]  mid=%.2f  depth=%.1f%%",
                  i, g_zones[i].lower, g_zones[i].upper, g_zones[i].mid,
                  g_zones[i].depth_pct * 100.0);
   }
   return(true);
}

//===================================================================
// STATE MACHINE PER ZONE (M5 bar close)
//===================================================================
// For each new entry-TF bar close, advance each zone through the state machine.
void ProcessZones(){
   double c1 = iClose(_Symbol, Inp_EntryTF, 1);
   double o1 = iOpen (_Symbol, Inp_EntryTF, 1);
   double h1 = iHigh (_Symbol, Inp_EntryTF, 1);
   double l1 = iLow  (_Symbol, Inp_EntryTF, 1);
   double c2 = iClose(_Symbol, Inp_EntryTF, 2);   // bar prior to the just-closed one

   for(int z = 0; z < g_num_zones; z++){
      Zone zn = g_zones[z];
      if(zn.state == ST_TAKEN || zn.state == ST_EXPIRED) continue;

      bool bar_overlaps_zone = (h1 >= zn.lower && l1 <= zn.upper);

      //---- IDLE -> INSIDE : bar enters zone from outside ----
      if(zn.state == ST_IDLE){
         if(bar_overlaps_zone && (c2 > zn.upper || c2 < zn.lower)){
            zn.entry_side = (c2 > zn.upper) ? SIDE_TOP : SIDE_BOTTOM;
            zn.state = ST_INSIDE;
            zn.bars_since_inside = 0;
            zn.entered_at = iTime(_Symbol, Inp_EntryTF, 1);
         }
         g_zones[z] = zn;
         continue;
      }

      //---- INSIDE / TOUCHED50 : dwell counter + expiry ----
      if(zn.state == ST_INSIDE || zn.state == ST_TOUCHED50){
         zn.bars_since_inside++;
         if(zn.bars_since_inside > Inp_MaxBarsPerZone){
            zn.state = ST_EXPIRED;
            g_zones[z] = zn;
            continue;
         }
      }

      //---- INSIDE -> TOUCHED50 : wick reaches midpoint ----
      if(zn.state == ST_INSIDE){
         bool touched = false;
         if(zn.entry_side == SIDE_TOP    && l1 <= zn.mid) touched = true;
         if(zn.entry_side == SIDE_BOTTOM && h1 >= zn.mid) touched = true;
         if(touched) zn.state = ST_TOUCHED50;

         // Rejection back through entry boundary WITHOUT touching mid -> reset
         if(!touched){
            if(zn.entry_side == SIDE_TOP    && c1 > zn.upper){ zn.state = ST_IDLE; zn.entry_side = SIDE_NONE; }
            if(zn.entry_side == SIDE_BOTTOM && c1 < zn.lower){ zn.state = ST_IDLE; zn.entry_side = SIDE_NONE; }
         }
      }

      //---- TOUCHED50 -> ARMED : close beyond OPPOSITE boundary (correct continuation) ----
      if(zn.state == ST_TOUCHED50){
         // TOP entry -> continuation is SHORT -> need close BELOW zone.lower
         if(zn.entry_side == SIDE_TOP && c1 < zn.lower){
            zn.state = ST_ARMED;
            g_arm_pending_idx = z;  // execute at next OnTick
         }
         // BOTTOM entry -> continuation is LONG -> need close ABOVE zone.upper
         else if(zn.entry_side == SIDE_BOTTOM && c1 > zn.upper){
            zn.state = ST_ARMED;
            g_arm_pending_idx = z;
         }
         // Rejection back through entry side (bounce off, no continuation) -> reset to IDLE
         else if(zn.entry_side == SIDE_TOP    && c1 > zn.upper){
            zn.state = ST_IDLE; zn.entry_side = SIDE_NONE;
         }
         else if(zn.entry_side == SIDE_BOTTOM && c1 < zn.lower){
            zn.state = ST_IDLE; zn.entry_side = SIDE_NONE;
         }
      }
      g_zones[z] = zn;
   }
}

//===================================================================
// TRADE ENTRY - execute ARMED zone
//===================================================================
double NextZoneInDirection(int this_zone_idx, bool is_long, double ref_price){
   // Find nearest OTHER zone whose midpoint is IN direction of trade
   // For LONG: need mid > ref_price, find smallest such mid
   // For SHORT: need mid < ref_price, find largest such mid
   double best = 0;
   bool   found = false;
   for(int z = 0; z < g_num_zones; z++){
      if(z == this_zone_idx) continue;
      if(g_zones[z].state == ST_TAKEN) continue;   // already used
      double m = g_zones[z].mid;
      if(is_long){
         if(m > ref_price && (!found || m < best)){ best = m; found = true; }
      } else {
         if(m < ref_price && (!found || m > best)){ best = m; found = true; }
      }
   }
   if(!found) return(0);
   return(best);
}

void ExecuteArmedZone(int z){
   if(z < 0 || z >= g_num_zones) return;
   if(g_zones[z].state != ST_ARMED) return;
   if(MyPositions() > 0){ g_zones[z].state = ST_EXPIRED; return; }
   if(g_trades_today >= Inp_MaxTradesPerDay){ g_zones[z].state = ST_EXPIRED; return; }
   if(FridayEveningBlocked()){ g_zones[z].state = ST_EXPIRED; return; }
   if(!WithinSession()){ g_zones[z].state = ST_EXPIRED; return; }
   if(IsNewsBlocked()){ g_zones[z].state = ST_EXPIRED; return; }
   if(!SpreadOK()) return;   // spread might improve on next tick, don't expire

   bool is_long = (g_zones[z].entry_side == SIDE_BOTTOM);

   // v14 daily budget check - pre-trade governor
   if(Inp_UseDailyBudget){
      double today_realized = AccountInfoDouble(ACCOUNT_BALANCE) - g_day_start_balance;
      double atr5 = ATR_M5();
      double sl_dist_price = Inp_SLBufferATR * atr5;
      // Add zone half-width as approximate "distance to SL from entry"
      double zone_half = (g_zones[z].upper - g_zones[z].lower) * 0.5;
      double sl_dist_total = sl_dist_price + zone_half;
      double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      if(contract <= 0) contract = 100.0;
      double worst_case_loss = sl_dist_total * contract * Inp_FixedLot;   // negative outcome
      double projected_day_pnl = today_realized - worst_case_loss;
      if(projected_day_pnl < -Inp_DailyLossBudget){
         PrintFormat("[LOOKBACK] DAILY_BUDGET_BLOCK today_pnl=%.2f worst_case=%.2f projected=%.2f budget=%.2f",
                     today_realized, -worst_case_loss, projected_day_pnl, -Inp_DailyLossBudget);
         g_zones[z].state = ST_EXPIRED;
         return;
      }
   }

   // v7 trend filter: skip counter-trend entries when filter enabled
   if(!TrendAlignedForDirection(is_long)){
      g_zones[z].state = ST_EXPIRED;
      if(Inp_UseTrendFilter){
         PrintFormat("[LOOKBACK] TREND_BLOCKED zone[%d] direction=%s (H1 EMA200 misaligned)",
                     z, is_long ? "LONG" : "SHORT");
      }
      return;
   }
   double atr5 = ATR_M5();
   if(atr5 <= 0){ g_zones[z].state = ST_EXPIRED; return; }
   double buf = Inp_SLBufferATR * atr5;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double entry_px, sl_px, tp_px;
   if(is_long){
      entry_px = ask;
      sl_px    = g_zones[z].lower - buf;
      double risk = entry_px - sl_px;
      if(risk <= 0){ g_zones[z].state = ST_EXPIRED; return; }
      double next_zone_mid = NextZoneInDirection(z, true, entry_px);
      tp_px = (next_zone_mid > 0) ? next_zone_mid : (entry_px + Inp_R_Multiple_Fallback * risk);
   } else {
      entry_px = bid;
      sl_px    = g_zones[z].upper + buf;
      double risk = sl_px - entry_px;
      if(risk <= 0){ g_zones[z].state = ST_EXPIRED; return; }
      double next_zone_mid = NextZoneInDirection(z, false, entry_px);
      tp_px = (next_zone_mid > 0) ? next_zone_mid : (entry_px - Inp_R_Multiple_Fallback * risk);
   }

   double lots = Inp_FixedLot;
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / st) * st;
   if(lots < mn) lots = mn;

   sl_px = NormalizeDouble(sl_px, dg);
   tp_px = NormalizeDouble(tp_px, dg);

   bool ok = false;
   if(is_long)  ok = trade.Buy (lots, _Symbol, 0, sl_px, tp_px, "LOOKBACK_L");
   else         ok = trade.Sell(lots, _Symbol, 0, sl_px, tp_px, "LOOKBACK_S");

   if(ok){
      g_trades_today++;
      g_zones[z].state = ST_TAKEN;
      PrintFormat("[LOOKBACK] %s zone[%d] [%.2f,%.2f] entry=%.2f sl=%.2f tp=%.2f  today=%d",
                  is_long ? "LONG" : "SHORT", z,
                  g_zones[z].lower, g_zones[z].upper, entry_px, sl_px, tp_px,
                  g_trades_today);
   } else {
      g_zones[z].state = ST_EXPIRED;
   }
}

//===================================================================
// SESSION FORCE-CLOSE
//===================================================================
void ForceCloseIfCutoff(){
   if(!Inp_UseForceClose) return;   // v11: bypass force close, let SL/TP handle exits
   if(IsForceCloseTime() && MyPositions() > 0){
      CloseAllMyPositions();
   }
}

//===================================================================
// OnTester - write deals CSV to Common\Files for external analysis
//===================================================================
double OnTester(){
   int h = FileOpen("ck_gold_lookback_deals.csv",
                    FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h != INVALID_HANDLE){
      FileWrite(h, "time_close", "type", "volume", "price_open", "price_close",
                   "sl", "tp", "profit", "swap", "commission", "comment");
      HistorySelect(0, TimeCurrent());
      int total = HistoryDealsTotal();
      // We reconstruct closed trades: match DEAL_ENTRY_OUT with its DEAL_ENTRY_IN via position id
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
         // Find matching entry price via position id
         long     pos_id = HistoryDealGetInteger(tk, DEAL_POSITION_ID);
         double   open_px = 0;
         for(int j = i - 1; j >= 0; j--){
            ulong tk2 = HistoryDealGetTicket(j); if(tk2 == 0) continue;
            if(HistoryDealGetInteger(tk2, DEAL_POSITION_ID) != pos_id) continue;
            if(HistoryDealGetInteger(tk2, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            open_px = HistoryDealGetDouble(tk2, DEAL_PRICE);
            break;
         }
         string type_str = (dt == DEAL_TYPE_BUY) ? "SELL_close" : "BUY_close"; // OUT is opposite
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
      PrintFormat("[LOOKBACK] OnTester: deals CSV written to Common\\Files\\ck_gold_lookback_deals.csv");
   } else {
      PrintFormat("[LOOKBACK] OnTester: FileOpen FAILED err=%d", GetLastError());
   }
   return(0.0);
}

//===================================================================
// MAIN
//===================================================================
void OnTick(){
   // Session-end force close - runs every tick (in case position needs urgent close)
   ForceCloseIfCutoff();

   // Execute pending ARMED (queued from previous M5 close)
   if(g_arm_pending_idx >= 0){
      ExecuteArmedZone(g_arm_pending_idx);
      g_arm_pending_idx = -1;
   }

   // Everything else (daily rollover, state machine) fires only on NEW M5 BAR
   // to avoid missing OnTick invocations on quiet ticks in Model 1 tester.
   if(!IsNewM5Bar()) return;

   // Daily rollover check based on the NEW entry-TF bar's time (not TimeCurrent).
   datetime m5_open = iTime(_Symbol, Inp_EntryTF, 0);
   MqlDateTime mt; TimeToStruct(m5_open, mt);
   int today_ymd = mt.year * 10000 + mt.mon * 100 + mt.day;
   if(today_ymd != g_today_ymd){
      g_today_ymd = today_ymd;
      // Update g_day_start using the M5 bar's date at 00:00
      mt.hour = 0; mt.min = 0; mt.sec = 0;
      g_day_start = StructToTime(mt);
      g_trades_today = 0;
      g_arm_pending_idx = -1;
      g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);   // v14 daily budget baseline
      RebuildZones();
   }

   if(g_num_zones == 0) return;
   ProcessZones();
}
//+------------------------------------------------------------------+

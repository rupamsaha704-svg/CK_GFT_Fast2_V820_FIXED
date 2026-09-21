//+------------------------------------------------------------------+
//|  CK_QM_NATIVE_v1.mq5                                              |
//|                                                                   |
//|  Native MQL5 rewrite of the QM/ICT liquidity-reversal engine that |
//|  currently ships as CK_QM_SignalPlayer.mq5 + a Python signal      |
//|  producer.  Reference:  v1_lab/qm_state_machine.py (Python) and   |
//|  the MT5 real-tick baseline of +$2,296 = +38.27%/yr on            |
//|  FundedNext $6k, PF 1.49, 88 deals from 105 signals, min bal      |
//|  $5,674, 1 daily-line touch (steering §5a; ledger seq270-274).    |
//|                                                                   |
//|  Build plan:  SPEC/QM_MQL5_REWRITE_PLAN.md   (7 blocks, ~25h)     |
//|                                                                   |
//|  THIS FILE  = BLOCK 1: setup queue struct + array.                |
//|  Blocks 2-7 add:  M15 structure detection  ->  ERL/POI/IDM        |
//|  computation  ->  M15 queue-advance (POI return, IDM clear)  ->   |
//|  M5 confirmation + order fire  ->  session/daily-cap/RR gates ->  |
//|  trade logger + parity check vs the signal-player baseline.       |
//|                                                                   |
//|  Ship-config (for later blocks):  erl_tf=H4 + dedupe, the winner  |
//|  variant confirmed by MT5 real ticks.  Do NOT re-tune during port.|
//|                                                                   |
//|  Steering §5:  MT5 real-tick Model 4 = truth.                     |
//|  Steering §7:  QM safe-risk = $75/trade on $6k funded.            |
//+------------------------------------------------------------------+
#property copyright "CK QM Native rewrite"
#property version   "1.00"
#property strict
#property description "Block 1 - setup queue foundation. Does not trade."

#include <Trade\Trade.mqh>

//==================== INPUTS ========================================
input group  "=== identity ==="
input long   InpMagic              = 20260921;   // order magic (blocks 5+)
input string InpComment            = "CK_QM_NATIVE_v1";

input group  "=== structure (LOCKED to Python DEFAULT_CONFIG) ==="
input int    InpPivot              = 2;          // swing L/R bars
input double InpDispATR            = 0.6;        // MSS displacement (|c-o|/ATR14)
input int    InpAtrPeriod          = 14;         // ATR period (M15)

input group  "=== ERL / POI / IDM (LOCKED to winner variant erl_h4) ==="
input ENUM_TIMEFRAMES InpErlTF     = PERIOD_H4;  // WINNER: H4 (not the Python default H1)
input int    InpErlLookback        = 5;
input bool   InpIdmClearRequired   = true;

input group  "=== risk gates (used by blocks 5-6) ==="
input double InpMinProjRR          = 1.0;        // reject setups with projected RR below this
input int    InpMaxTradesPerDay    = 2;
input double InpRiskPerTradeUSD    = 75.0;       // steering §7 safe-risk on FN $6k funded
input double InpMaxSpreadPrice     = 0.60;       // skip entries when spread exceeds this

input group  "=== queue guards (this block) ==="
input int    InpSetupExpiryM15Bars = 96;         // 24h of M15 -> expire if no POI return
input bool   InpQueueDebug         = true;       // Experts-log every queue transition

//==================== BLOCK 1: SETUP QUEUE =========================
// Everything below is Block 1's deliverable.  Blocks 2..7 will call these
// helpers; nothing here fires an order.
//
// A QM setup is a candidate trade that has been DETECTED at MSS-shift time
// (Blocks 2+3) but has not yet FIRED.  It sits in the queue and advances
// through states as new bars close.  The Python reference walks all MSS
// events in one batch pass; here we stream and stage them in fixed slots
// because MQL5 is bar-by-bar in live.
//===================================================================

#define MAX_QM_SETUPS  16   // ceiling on concurrent pending setups (see plan)

//---- states, in causal order ---------------------------------------
enum ENUM_QM_STATE
{
   QM_STATE_NONE             = 0,   // slot free / never used
   QM_STATE_WAIT_POI_RETURN  = 1,   // MSS+ERL+IDM detected; waiting for price to return to POI
   QM_STATE_WAIT_M5_CONFIRM  = 2,   // POI touched; watching M5 for the "1 rejection" confirmation
   QM_STATE_ENTERED          = 3,   // order fired; MT5 owns the exit
   QM_STATE_DEAD             = 4    // expired / invalidated; GC will reclaim to NONE
};

//---- direction -----------------------------------------------------
enum ENUM_QM_DIR
{
   QM_DIR_BEAR = -1,
   QM_DIR_BULL =  1
};

//---- the setup record ---------------------------------------------
struct QMSetup
{
   // slot identity ---------------------------------------------------
   bool             active;             // false == the slot is free (state==NONE)
   int              slot_id;            // 0..MAX_QM_SETUPS-1, filled at init
   long             magic;              // per-setup magic (InpMagic + slot_id) so we can pair orders
   ENUM_QM_STATE    state;

   // detected structure (frozen at add-time) -------------------------
   ENUM_QM_DIR      direction;          // BEAR / BULL
   datetime         mss_shift_time;     // close time of the M15 MSS bar
   int              mss_shift_index;    // M15 index at add-time (for diagnostics only)
   double           mss_disp;           // displacement value that triggered

   // POI zone (Quasimodo left-shoulder return zone) ------------------
   double           poi_top;            // upper price of the POI band
   double           poi_bottom;         // lower price of the POI band
   int              poi_head_index;     // head bar (raid extreme) - used for invalidation
   double           poi_head_price;     // head extreme (bear: high, bull: low)

   // external target (ERL raid opposite side, used for TP) ----------
   double           external_target;    // TP anchor from erl_levels() on H4

   // IDM (inducement) -----------------------------------------------
   double           idm_level;          // price level to be "cleared" (swept) before POI return
   ENUM_QM_DIR      idm_side;           // side that needs sweeping (opposite of setup direction)
   bool             idm_cleared;        // set once cleared, or immediately if !InpIdmClearRequired

   // POI-return + M5-confirm progress -------------------------------
   datetime         poi_return_time;    // set on first M15 close whose range touches POI
   int              m5_confirm_bars;    // bars scanned in WAIT_M5_CONFIRM (bounded search)

   // context frozen at add-time (for buffer sizing later) ------------
   double           atr_at_shift;       // ATR(14) M15 at the shift bar

   // bookkeeping -----------------------------------------------------
   datetime         added_at;           // wallclock time when added
   datetime         expires_at;         // added_at + InpSetupExpiryM15Bars * 15min
   string           expire_reason;      // filled at DEAD transition
};

//---- the fixed-size queue -----------------------------------------
QMSetup   g_qm_setups[MAX_QM_SETUPS];
int       g_qm_next_slot_hint = 0;      // round-robin hint so we don't always start at 0
long      g_qm_added_total    = 0;      // lifetime counter for diagnostics
long      g_qm_entered_total  = 0;
long      g_qm_expired_total  = 0;

//---- state-name helper (Experts-log readable) ---------------------
string QM_StateName(ENUM_QM_STATE s)
{
   switch(s)
   {
      case QM_STATE_NONE:            return "NONE";
      case QM_STATE_WAIT_POI_RETURN: return "WAIT_POI_RETURN";
      case QM_STATE_WAIT_M5_CONFIRM: return "WAIT_M5_CONFIRM";
      case QM_STATE_ENTERED:         return "ENTERED";
      case QM_STATE_DEAD:            return "DEAD";
   }
   return "UNKNOWN";
}

string QM_DirName(ENUM_QM_DIR d)
{
   return (d == QM_DIR_BEAR) ? "BEAR" : (d == QM_DIR_BULL) ? "BULL" : "?";
}

//---- zero one slot to the empty / NONE default --------------------
void QM_ClearSlot(const int idx)
{
   if(idx < 0 || idx >= MAX_QM_SETUPS) return;
   QMSetup empty;
   ZeroMemory(empty);
   empty.slot_id       = idx;
   empty.state         = QM_STATE_NONE;
   empty.active        = false;
   empty.expire_reason = "";
   g_qm_setups[idx] = empty;
}

//---- Init: zero the entire queue ---------------------------------
void QM_Init()
{
   for(int i = 0; i < MAX_QM_SETUPS; i++) QM_ClearSlot(i);
   g_qm_next_slot_hint = 0;
   g_qm_added_total    = 0;
   g_qm_entered_total  = 0;
   g_qm_expired_total  = 0;
   PrintFormat("[QM_NATIVE] queue init %d slots  MODE=SETUP_ONLY  (Block 1 - does not trade)",
               MAX_QM_SETUPS);
}

//---- find a free slot (state == NONE), returning its index or -1 --
int QM_FindFreeSlot()
{
   // round-robin scan starting at g_qm_next_slot_hint for cache-friendliness
   // when many setups age together.
   for(int step = 0; step < MAX_QM_SETUPS; step++)
   {
      const int i = (g_qm_next_slot_hint + step) % MAX_QM_SETUPS;
      if(g_qm_setups[i].state == QM_STATE_NONE)
      {
         g_qm_next_slot_hint = (i + 1) % MAX_QM_SETUPS;
         return i;
      }
   }
   return -1;
}

//---- count slots in a given state (diagnostic) --------------------
int QM_CountByState(const ENUM_QM_STATE want)
{
   int n = 0;
   for(int i = 0; i < MAX_QM_SETUPS; i++)
      if(g_qm_setups[i].state == want) n++;
   return n;
}

int QM_CountActive()
{
   // "active" = anything not NONE and not DEAD
   int n = 0;
   for(int i = 0; i < MAX_QM_SETUPS; i++)
      if(g_qm_setups[i].state != QM_STATE_NONE && g_qm_setups[i].state != QM_STATE_DEAD)
         n++;
   return n;
}

//---- add a setup: return slot index or -1 if the queue is full ----
// Blocks 2+3 populate the structural fields after this call returns.
// This helper only reserves a slot and stamps the identity / add-time.
int QM_AddSetup(const ENUM_QM_DIR      direction,
                const datetime         mss_shift_time,
                const int              mss_shift_index,
                const double           mss_disp,
                const double           poi_top,
                const double           poi_bottom,
                const int              poi_head_index,
                const double           poi_head_price,
                const double           external_target,
                const double           idm_level,
                const ENUM_QM_DIR      idm_side,
                const double           atr_at_shift)
{
   const int idx = QM_FindFreeSlot();
   if(idx < 0)
   {
      // Queue full - real trouble. Do NOT silently overwrite; make it visible.
      if(InpQueueDebug)
         PrintFormat("[QM_NATIVE] ADD FAIL - queue full  dir=%s shift=%s  active=%d",
                     QM_DirName(direction),
                     TimeToString(mss_shift_time, TIME_DATE|TIME_MINUTES),
                     QM_CountActive());
      return -1;
   }

   QMSetup s;
   ZeroMemory(s);
   s.active           = true;
   s.slot_id          = idx;
   s.magic            = InpMagic + (long)idx;
   s.state            = QM_STATE_WAIT_POI_RETURN;
   s.direction        = direction;
   s.mss_shift_time   = mss_shift_time;
   s.mss_shift_index  = mss_shift_index;
   s.mss_disp         = mss_disp;
   s.poi_top          = poi_top;
   s.poi_bottom       = poi_bottom;
   s.poi_head_index   = poi_head_index;
   s.poi_head_price   = poi_head_price;
   s.external_target  = external_target;
   s.idm_level        = idm_level;
   s.idm_side         = idm_side;
   s.idm_cleared      = !InpIdmClearRequired;   // if clear not required, treat as pre-cleared
   s.poi_return_time  = 0;
   s.m5_confirm_bars  = 0;
   s.atr_at_shift     = atr_at_shift;
   s.added_at         = TimeCurrent();
   s.expires_at       = mss_shift_time + (datetime)(InpSetupExpiryM15Bars * 15 * 60);
   s.expire_reason    = "";
   g_qm_setups[idx]   = s;
   g_qm_added_total++;

   if(InpQueueDebug)
      PrintFormat("[QM_NATIVE] ADD  slot=%d magic=%I64d dir=%s shift=%s poi=[%.2f..%.2f] head=%.2f ERL=%.2f IDM=%.2f  atr=%.2f  expires=%s",
                  idx, s.magic, QM_DirName(direction),
                  TimeToString(mss_shift_time, TIME_DATE|TIME_MINUTES),
                  poi_bottom, poi_top, poi_head_price, external_target, idm_level,
                  atr_at_shift,
                  TimeToString(s.expires_at, TIME_DATE|TIME_MINUTES));
   return idx;
}

//---- mark a slot DEAD with a reason string; GC will reclaim to NONE
void QM_ExpireSetup(const int idx, const string reason)
{
   if(idx < 0 || idx >= MAX_QM_SETUPS) return;
   if(g_qm_setups[idx].state == QM_STATE_NONE) return;   // already free
   if(g_qm_setups[idx].state == QM_STATE_DEAD) return;   // already dead

   g_qm_setups[idx].state         = QM_STATE_DEAD;
   g_qm_setups[idx].expire_reason = reason;
   g_qm_expired_total++;

   if(InpQueueDebug)
      PrintFormat("[QM_NATIVE] EXPIRE slot=%d dir=%s state=DEAD  reason=%s",
                  idx, QM_DirName(g_qm_setups[idx].direction), reason);
}

//---- mark a slot ENTERED (Block 5 will call this once an order is placed)
void QM_MarkEntered(const int idx)
{
   if(idx < 0 || idx >= MAX_QM_SETUPS) return;
   if(g_qm_setups[idx].state == QM_STATE_NONE) return;
   g_qm_setups[idx].state = QM_STATE_ENTERED;
   g_qm_entered_total++;
   if(InpQueueDebug)
      PrintFormat("[QM_NATIVE] ENTER  slot=%d dir=%s",
                  idx, QM_DirName(g_qm_setups[idx].direction));
}

//---- reclaim DEAD slots back to NONE so the queue can reuse them --
void QM_GC()
{
   int reclaimed = 0;
   for(int i = 0; i < MAX_QM_SETUPS; i++)
   {
      if(g_qm_setups[i].state == QM_STATE_DEAD || g_qm_setups[i].state == QM_STATE_ENTERED)
      {
         // ENTERED is also reclaimable at GC time: the order was placed and MT5
         // owns the exit; we don't need the setup record any longer.
         QM_ClearSlot(i);
         reclaimed++;
      }
   }
   if(InpQueueDebug && reclaimed > 0)
      PrintFormat("[QM_NATIVE] GC reclaimed %d slot(s); active=%d added=%I64d entered=%I64d expired=%I64d",
                  reclaimed, QM_CountActive(),
                  g_qm_added_total, g_qm_entered_total, g_qm_expired_total);
}

//---- pretty-print the queue (call from OnDeinit or on demand) -----
void QM_DumpQueue()
{
   const int active = QM_CountActive();
   PrintFormat("[QM_NATIVE] queue dump: active=%d WAIT_POI=%d WAIT_M5=%d ENTERED=%d DEAD=%d  |  lifetime added=%I64d entered=%I64d expired=%I64d",
               active,
               QM_CountByState(QM_STATE_WAIT_POI_RETURN),
               QM_CountByState(QM_STATE_WAIT_M5_CONFIRM),
               QM_CountByState(QM_STATE_ENTERED),
               QM_CountByState(QM_STATE_DEAD),
               g_qm_added_total, g_qm_entered_total, g_qm_expired_total);
   for(int i = 0; i < MAX_QM_SETUPS; i++)
   {
      const QMSetup s = g_qm_setups[i];
      if(s.state == QM_STATE_NONE) continue;
      PrintFormat("  slot=%d state=%s dir=%s shift=%s poi=[%.2f..%.2f] head=%.2f ERL=%.2f  poi_ret=%s reason=%s",
                  i, QM_StateName(s.state), QM_DirName(s.direction),
                  TimeToString(s.mss_shift_time, TIME_DATE|TIME_MINUTES),
                  s.poi_bottom, s.poi_top, s.poi_head_price, s.external_target,
                  (s.poi_return_time == 0 ? "-" :
                     TimeToString(s.poi_return_time, TIME_DATE|TIME_MINUTES)),
                  (s.expire_reason == "" ? "-" : s.expire_reason));
   }
}

//---- expire everything that has passed its wait deadline ----------
// Called on each new M15 bar from Block 4. Kept in Block 1 because it
// only touches queue mechanics, not structural detection.
int QM_ExpireOverdue(const datetime now_bar_time)
{
   int expired = 0;
   for(int i = 0; i < MAX_QM_SETUPS; i++)
   {
      QMSetup s = g_qm_setups[i];
      if(s.state != QM_STATE_WAIT_POI_RETURN && s.state != QM_STATE_WAIT_M5_CONFIRM) continue;
      if(now_bar_time >= s.expires_at)
      {
         QM_ExpireSetup(i, StringFormat("timeout_%s", QM_StateName(s.state)));
         expired++;
      }
   }
   return expired;
}

//==================== END BLOCK 1 ==================================


//==================== BLOCK 2: M15 STRUCTURE DETECTION =============
// On every closed M15 bar:
//   1) confirm a NEW swing at shift (pivot+1) if its two pivot-bar
//      wings are both smaller (swing high) or both larger (swing low)
//      than the checked bar's high/low.  This is the streaming
//      equivalent of qm_detect.py's detect_swings() with a fixed
//      pivot-bars-per-side rule.
//   2) evaluate an MSS on the just-closed bar (shift 1): a body close
//      beyond the MOST RECENT confirmed swing in the required
//      direction, with |close-open|/ATR14 >= InpDispATR.
//      This mirrors qm_detect.py's detect_mss().
//
// Block 2 is DETECT-only.  It stores swings + prints per-bar
// diagnostics; it does NOT create QMSetup queue entries yet.  Block 3
// (ERL + POI + IDM computation) will call QM_OnMSSDetected() to
// actually pair the shift with the auxiliary structure and enqueue.
//===================================================================

#define QM_SWING_RING       64        // rolling history of confirmed swings
#define QM_ATR_MIN_BARS     20        // require at least this many closed M15 bars before evaluating

//---- swing record ---------------------------------------------------
struct QMSwing
{
   datetime time;                   // close-time of the swing bar
   double   price;                  // swing high / low value
   int      shift_at_confirm;       // M15 shift at confirmation moment (diagnostics)
};

QMSwing  g_swingHighs[QM_SWING_RING];
QMSwing  g_swingLows [QM_SWING_RING];
int      g_shTop = -1;               // index of most-recently-written swing high (ring)
int      g_slTop = -1;               // index of most-recently-written swing low  (ring)
long     g_shWritten = 0;            // lifetime swing-high count
long     g_slWritten = 0;            // lifetime swing-low  count

//---- MSS event counters (diagnostics + block 7 comparison target) --
long     g_mssBearCount = 0;
long     g_mssBullCount = 0;
long     g_barsSeen     = 0;

//---- M15 bar tracking ----------------------------------------------
datetime g_lastM15Time  = 0;
int      g_hATR_M15     = INVALID_HANDLE;

//---- ATR reader ----------------------------------------------------
// Returns ATR value on M15 at shift 1 (the just-closed bar). Returns
// 0.0 if the buffer isn't ready yet (early history).
double QM_M15_ATR_shift1()
{
   if(g_hATR_M15 == INVALID_HANDLE) return(0.0);
   double b[1];
   if(CopyBuffer(g_hATR_M15, 0, 1, 1, b) < 1) return(0.0);
   return(b[0]);
}

//---- swing storage helpers -----------------------------------------
void QM_AddSwingHigh(const datetime t, const double p, const int shift_at_confirm)
{
   g_shTop = (g_shTop + 1) % QM_SWING_RING;
   g_swingHighs[g_shTop].time  = t;
   g_swingHighs[g_shTop].price = p;
   g_swingHighs[g_shTop].shift_at_confirm = shift_at_confirm;
   g_shWritten++;
}

void QM_AddSwingLow(const datetime t, const double p, const int shift_at_confirm)
{
   g_slTop = (g_slTop + 1) % QM_SWING_RING;
   g_swingLows[g_slTop].time  = t;
   g_swingLows[g_slTop].price = p;
   g_swingLows[g_slTop].shift_at_confirm = shift_at_confirm;
   g_slWritten++;
}

// Look up the most recent CONFIRMED swing high whose time is strictly
// before the given cutoff time. Returns true + fills out if found.
bool QM_MostRecentSwingHighBefore(const datetime cutoff, QMSwing &out)
{
   if(g_shWritten == 0) return(false);
   // Walk backwards from g_shTop
   int limit = (int)MathMin((long)QM_SWING_RING, g_shWritten);
   for(int step = 0; step < limit; step++)
   {
      int idx = (g_shTop - step + QM_SWING_RING) % QM_SWING_RING;
      if(g_swingHighs[idx].time < cutoff)
      {
         out = g_swingHighs[idx];
         return(true);
      }
   }
   return(false);
}

bool QM_MostRecentSwingLowBefore(const datetime cutoff, QMSwing &out)
{
   if(g_slWritten == 0) return(false);
   int limit = (int)MathMin((long)QM_SWING_RING, g_slWritten);
   for(int step = 0; step < limit; step++)
   {
      int idx = (g_slTop - step + QM_SWING_RING) % QM_SWING_RING;
      if(g_swingLows[idx].time < cutoff)
      {
         out = g_swingLows[idx];
         return(true);
      }
   }
   return(false);
}

//---- streaming swing detector --------------------------------------
// Called on each new closed M15 bar. Checks whether the bar at shift
// (pivot+1) is a fresh swing high / low based on strict comparisons
// on both wings. Same-price ties do not create a new swing (mirrors
// qm_detect.py behaviour for gold's typical strict-swing conventions).
void QM_DetectSwings()
{
   const int p = InpPivot;
   const int checkShift = p + 1;

   // Need at least (2*p + 2) bars of history to evaluate the wings + check-bar
   const int minBars = 2 * p + 2;
   if(Bars(_Symbol, PERIOD_M15) < minBars) return;

   const double checkH = iHigh(_Symbol, PERIOD_M15, checkShift);
   const double checkL = iLow (_Symbol, PERIOD_M15, checkShift);
   const datetime checkT = iTime(_Symbol, PERIOD_M15, checkShift);
   if(checkH <= 0.0 || checkT == 0) return;

   // swing high test
   bool isHigh = true;
   for(int k = 1; k <= p; k++)
   {
      double lH = iHigh(_Symbol, PERIOD_M15, checkShift + k); // older neighbour
      double rH = iHigh(_Symbol, PERIOD_M15, checkShift - k); // newer neighbour
      if(lH >= checkH || rH >= checkH) { isHigh = false; break; }
   }
   if(isHigh) QM_AddSwingHigh(checkT, checkH, checkShift);

   // swing low test
   bool isLow = true;
   for(int k = 1; k <= p; k++)
   {
      double lL = iLow(_Symbol, PERIOD_M15, checkShift + k);
      double rL = iLow(_Symbol, PERIOD_M15, checkShift - k);
      if(lL <= checkL || rL <= checkL) { isLow = false; break; }
   }
   if(isLow) QM_AddSwingLow(checkT, checkL, checkShift);
}

//---- MSS detector on the just-closed M15 bar (shift 1) ------------
// Returns:
//   0 = no shift on this bar
//  -1 = bearish MSS (close body-breaks below most-recent confirmed swing low)
//  +1 = bullish MSS (close body-breaks above most-recent confirmed swing high)
// Displacement gate is |close-open|/ATR14 >= InpDispATR (LOCKED per
// steering §5 default; do NOT tune during the port).
int QM_DetectMSS(double &disp_out, datetime &shift_time_out, double &close_out, QMSwing &brokenSwing_out)
{
   disp_out = 0.0;
   shift_time_out = 0;
   close_out = 0.0;
   ZeroMemory(brokenSwing_out);

   const double o1 = iOpen (_Symbol, PERIOD_M15, 1);
   const double c1 = iClose(_Symbol, PERIOD_M15, 1);
   const datetime t1 = iTime(_Symbol, PERIOD_M15, 1);
   if(t1 == 0 || o1 <= 0.0 || c1 <= 0.0) return(0);

   double atr = QM_M15_ATR_shift1();
   if(atr <= 0.0) return(0);

   double disp = MathAbs(c1 - o1) / atr;
   disp_out       = disp;
   shift_time_out = t1;
   close_out      = c1;

   if(disp < InpDispATR) return(0);   // displacement gate fails

   // Bearish MSS: close is BELOW the most recent confirmed swing low BEFORE this bar
   QMSwing recentLow;
   if(QM_MostRecentSwingLowBefore(t1, recentLow) && c1 < recentLow.price)
   {
      brokenSwing_out = recentLow;
      return(-1);
   }
   // Bullish MSS: close is ABOVE the most recent confirmed swing high BEFORE this bar
   QMSwing recentHigh;
   if(QM_MostRecentSwingHighBefore(t1, recentHigh) && c1 > recentHigh.price)
   {
      brokenSwing_out = recentHigh;
      return(+1);
   }
   return(0);
}

//---- MSS event hook forward declaration (real body is in Block 3) --
// Block 3 gives this the real ERL+POI+IDM computation and the
// QM_AddSetup() enqueue call.
void QM_OnMSSDetected(const int direction,
                      const datetime shift_time,
                      const double close_price,
                      const double disp,
                      const QMSwing &brokenSwing);

//---- new-M15-bar dispatcher (called from OnTick) -------------------
void QM_OnNewM15Bar()
{
   g_barsSeen++;

   // 1) confirm any new swing at shift (pivot + 1)
   QM_DetectSwings();

   // 2) evaluate MSS on the just-closed bar (shift 1)
   double   disp = 0.0;
   datetime st   = 0;
   double   cx   = 0.0;
   QMSwing  brk;
   int mss = QM_DetectMSS(disp, st, cx, brk);

   // per-bar debug (short line so it survives long backtests without
   // flooding the Experts tab too badly)
   if(InpQueueDebug)
   {
      string shiftLabel = (mss == 0) ? "none" : ((mss < 0) ? "bear" : "bull");
      PrintFormat("[QM_NATIVE] bar t=%s close=%.2f disp=%.2f shift=%s  swings[h=%I64d l=%I64d]",
                  TimeToString(st, TIME_DATE|TIME_MINUTES), cx, disp, shiftLabel,
                  g_shWritten, g_slWritten);
   }

   if(mss != 0)
   {
      if(mss < 0) g_mssBearCount++; else g_mssBullCount++;
      QM_OnMSSDetected(mss, st, cx, disp, brk);
   }
}

//==================== END BLOCK 2 ==================================


//==================== BLOCK 3: ERL + POI + IDM ======================
// When Block 2 detects an MSS on the just-closed M15 bar, Block 3
// resolves the auxiliary structure and enqueues a QMSetup via
// QM_AddSetup(). The mapping:
//   - IDM (inducement)  = most recent confirmed opposite-side M15
//                         swing at/before the MSS bar (block 2's ring).
//                         idm_detect.py find_idm_for_shift equivalent.
//   - POI zone          = left-shoulder QM band. LS = swing high (bear)
//                         or low (bull) with LS.price < HEAD.price
//                         (bear) / LS.price > HEAD.price (bull),
//                         and HEAD is the swing directly before the
//                         MSS neckline that raids LS liquidity.
//                         Zone = LS-bar body-to-wick supply/demand band.
//                         poi_zone.py detect_poi 'qm' variant.
//   - ERL target        = extreme of last N H4 swings on the OPPOSITE
//                         side of the shift. Winner variant erl_h4
//                         from the multi-TF sweep (steering §5a).
//                         erl_detect.py erl_levels equivalent, TF=H4,
//                         pivot=2, lookback=5.
//
// Everything below is DETERMINISTIC and CAUSAL. No parameter is
// tuned during the port; every value matches the Python DEFAULT_CONFIG
// or the erl_h4 variant. If Block 7 parity check reveals a gap, we
// FIX the port, not the parameters.
//===================================================================

#define QM_ERL_LOOKBACK      5     // per steering winner variant erl_h4
#define QM_H4_SWING_RING     32    // rolling history of confirmed H4 swings (per side)

//---- H4 swing tracker (mirrors the M15 tracker in Block 2) ---------
QMSwing  g_h4SwingHighs[QM_H4_SWING_RING];
QMSwing  g_h4SwingLows [QM_H4_SWING_RING];
int      g_h4ShTop = -1;
int      g_h4SlTop = -1;
long     g_h4ShWritten = 0;
long     g_h4SlWritten = 0;
datetime g_lastH4Time  = 0;

void QM_H4_AddSwingHigh(const datetime t, const double p)
{
   g_h4ShTop = (g_h4ShTop + 1) % QM_H4_SWING_RING;
   g_h4SwingHighs[g_h4ShTop].time  = t;
   g_h4SwingHighs[g_h4ShTop].price = p;
   g_h4SwingHighs[g_h4ShTop].shift_at_confirm = -1;   // shift meaningless on H4 ring
   g_h4ShWritten++;
}
void QM_H4_AddSwingLow(const datetime t, const double p)
{
   g_h4SlTop = (g_h4SlTop + 1) % QM_H4_SWING_RING;
   g_h4SwingLows[g_h4SlTop].time  = t;
   g_h4SwingLows[g_h4SlTop].price = p;
   g_h4SwingLows[g_h4SlTop].shift_at_confirm = -1;
   g_h4SlWritten++;
}

// On each new closed H4 bar, check whether the bar at H4-shift (pivot+1)
// is a confirmed swing. Uses the same InpPivot as M15 so the two swing
// rules are consistent.
void QM_H4_DetectSwings()
{
   const int p = InpPivot;
   const int checkShift = p + 1;
   const int minBars = 2 * p + 2;
   if(Bars(_Symbol, PERIOD_H4) < minBars) return;

   const double h  = iHigh(_Symbol, PERIOD_H4, checkShift);
   const double l  = iLow (_Symbol, PERIOD_H4, checkShift);
   const datetime t = iTime(_Symbol, PERIOD_H4, checkShift);
   if(h <= 0.0 || t == 0) return;

   // swing high?
   bool isHigh = true;
   for(int k = 1; k <= p; k++)
   {
      double lH = iHigh(_Symbol, PERIOD_H4, checkShift + k);
      double rH = iHigh(_Symbol, PERIOD_H4, checkShift - k);
      if(lH >= h || rH >= h) { isHigh = false; break; }
   }
   if(isHigh) QM_H4_AddSwingHigh(t, h);

   // swing low?
   bool isLow = true;
   for(int k = 1; k <= p; k++)
   {
      double lL = iLow(_Symbol, PERIOD_H4, checkShift + k);
      double rL = iLow(_Symbol, PERIOD_H4, checkShift - k);
      if(lL <= l || rL <= l) { isLow = false; break; }
   }
   if(isLow) QM_H4_AddSwingLow(t, l);
}

// Called from OnTick on H4 new-bar detection.
void QM_OnNewH4Bar()
{
   QM_H4_DetectSwings();
   if(InpQueueDebug)
   {
      PrintFormat("[QM_NATIVE] H4_BAR  swingsH=%I64d swingsL=%I64d",
                  g_h4ShWritten, g_h4SlWritten);
   }
}

//---- ERL computation: extreme of last N H4 swings on opposite side --
// For a BEAR MSS the setup goes DOWN toward external LOWER liquidity =
// lowest of the last LOOKBACK confirmed H4 swing LOWS. Mirror for BULL.
// Returns 0.0 if we don't have enough H4 swings yet (early history).
double QM_ComputeERL(const ENUM_QM_DIR direction)
{
   int n_needed = QM_ERL_LOOKBACK;
   if(direction == QM_DIR_BEAR)
   {
      // lowest of last N swing lows
      int have = (int)MathMin((long)QM_H4_SWING_RING, g_h4SlWritten);
      if(have < 1) return(0.0);
      int count = MathMin(have, n_needed);
      double lowest = DBL_MAX;
      for(int step = 0; step < count; step++)
      {
         int idx = (g_h4SlTop - step + QM_H4_SWING_RING) % QM_H4_SWING_RING;
         if(g_h4SwingLows[idx].price < lowest) lowest = g_h4SwingLows[idx].price;
      }
      return(lowest == DBL_MAX ? 0.0 : lowest);
   }
   else
   {
      // highest of last N swing highs
      int have = (int)MathMin((long)QM_H4_SWING_RING, g_h4ShWritten);
      if(have < 1) return(0.0);
      int count = MathMin(have, n_needed);
      double highest = -DBL_MAX;
      for(int step = 0; step < count; step++)
      {
         int idx = (g_h4ShTop - step + QM_H4_SWING_RING) % QM_H4_SWING_RING;
         if(g_h4SwingHighs[idx].price > highest) highest = g_h4SwingHighs[idx].price;
      }
      return(highest == -DBL_MAX ? 0.0 : highest);
   }
}

//---- QM structure finder: identify LS + HEAD from M15 swing ring ---
// For a bearish MSS whose broken swing (neckline) is at time neck_t:
//   HEAD  = most recent M15 swing HIGH with time strictly before neck_t
//   LS    = most recent M15 swing HIGH with time strictly before HEAD.time
//           and price < HEAD.price  (so HEAD raids LS's buy-side liquidity)
// If either is missing or LS is not lower than HEAD, no valid QM structure.
// Returns true + fills out on success.
bool QM_FindQMStructure_Bear(const datetime neck_t, QMSwing &headOut, QMSwing &lsOut)
{
   ZeroMemory(headOut);
   ZeroMemory(lsOut);
   if(g_shWritten < 2) return(false);

   int limit = (int)MathMin((long)QM_SWING_RING, g_shWritten);
   // find HEAD: most recent swing HIGH with time < neck_t
   int headFoundStep = -1;
   for(int step = 0; step < limit; step++)
   {
      int idx = (g_shTop - step + QM_SWING_RING) % QM_SWING_RING;
      if(g_swingHighs[idx].time < neck_t)
      {
         headOut = g_swingHighs[idx];
         headFoundStep = step;
         break;
      }
   }
   if(headFoundStep < 0) return(false);

   // find LS: walk further back for a swing HIGH strictly before HEAD.time
   // with LS.price < HEAD.price
   for(int step = headFoundStep + 1; step < limit; step++)
   {
      int idx = (g_shTop - step + QM_SWING_RING) % QM_SWING_RING;
      if(g_swingHighs[idx].time < headOut.time &&
         g_swingHighs[idx].price < headOut.price)
      {
         lsOut = g_swingHighs[idx];
         return(true);
      }
   }
   return(false);
}

// Bullish mirror: LS + HEAD are swing LOWS; HEAD.price < LS.price.
bool QM_FindQMStructure_Bull(const datetime neck_t, QMSwing &headOut, QMSwing &lsOut)
{
   ZeroMemory(headOut);
   ZeroMemory(lsOut);
   if(g_slWritten < 2) return(false);

   int limit = (int)MathMin((long)QM_SWING_RING, g_slWritten);
   int headFoundStep = -1;
   for(int step = 0; step < limit; step++)
   {
      int idx = (g_slTop - step + QM_SWING_RING) % QM_SWING_RING;
      if(g_swingLows[idx].time < neck_t)
      {
         headOut = g_swingLows[idx];
         headFoundStep = step;
         break;
      }
   }
   if(headFoundStep < 0) return(false);

   for(int step = headFoundStep + 1; step < limit; step++)
   {
      int idx = (g_slTop - step + QM_SWING_RING) % QM_SWING_RING;
      if(g_swingLows[idx].time < headOut.time &&
         g_swingLows[idx].price > headOut.price)
      {
         lsOut = g_swingLows[idx];
         return(true);
      }
   }
   return(false);
}

//---- POI zone from LS candle -------------------------------------
// The LS candle's body-to-wick band:
//   bear POI = [min(open,close), high] of the LS bar (supply above)
//   bull POI = [low, max(open,close)] of the LS bar (demand below)
// LS is identified by its close time (ls_time). We convert that to a
// bar shift on M15 and read the OHLC from there.
bool QM_ComputePOI(const ENUM_QM_DIR direction,
                   const datetime ls_time,
                   double &poi_top_out,
                   double &poi_bottom_out,
                   int &head_bar_shift_out,
                   double &head_price_out)
{
   poi_top_out = 0.0;
   poi_bottom_out = 0.0;
   head_bar_shift_out = -1;
   head_price_out = 0.0;

   int shift = iBarShift(_Symbol, PERIOD_M15, ls_time, false);
   if(shift < 0) return(false);

   double o = iOpen (_Symbol, PERIOD_M15, shift);
   double c = iClose(_Symbol, PERIOD_M15, shift);
   double h = iHigh (_Symbol, PERIOD_M15, shift);
   double l = iLow  (_Symbol, PERIOD_M15, shift);
   if(o <= 0.0 || c <= 0.0) return(false);

   if(direction == QM_DIR_BEAR)
   {
      poi_bottom_out = MathMin(o, c);
      poi_top_out    = h;
      head_price_out = h;   // will be overwritten by caller with HEAD's price
   }
   else
   {
      poi_bottom_out = l;
      poi_top_out    = MathMax(o, c);
      head_price_out = l;
   }
   head_bar_shift_out = shift;   // provisional; caller sets to actual HEAD shift below
   return(true);
}

//---- IDM identifier: most recent opposite-side M15 swing before MSS
// bear MSS: IDM = most recent swing HIGH with time < mss_time (buy-side
//           liquidity above, to be cleared before POI return continues).
// bull MSS: mirror with swing LOW.
// Returns (level, side, ok).
bool QM_ComputeIDM(const ENUM_QM_DIR direction,
                   const datetime mss_time,
                   double &idm_level_out,
                   ENUM_QM_DIR &idm_side_out)
{
   idm_level_out = 0.0;
   idm_side_out  = QM_DIR_BEAR;

   QMSwing found;
   if(direction == QM_DIR_BEAR)
   {
      if(!QM_MostRecentSwingHighBefore(mss_time, found)) return(false);
      idm_level_out = found.price;
      idm_side_out  = QM_DIR_BULL;   // side to be SWEPT is the opposite of setup dir
   }
   else
   {
      if(!QM_MostRecentSwingLowBefore(mss_time, found)) return(false);
      idm_level_out = found.price;
      idm_side_out  = QM_DIR_BEAR;
   }
   return(true);
}

//---- MSS event hook -- REAL BODY (replaces the Block 2 stub) -------
// Called by Block 2's QM_OnNewM15Bar when an MSS is detected on the
// just-closed bar. Resolves the structural pairing and enqueues the
// setup for later state advancement (WAIT_POI_RETURN by default).
void QM_OnMSSDetected(const int direction,
                      const datetime shift_time,
                      const double close_price,
                      const double disp,
                      const QMSwing &brokenSwing)
{
   const ENUM_QM_DIR dir = (direction < 0) ? QM_DIR_BEAR : QM_DIR_BULL;

   // 1) find the QM structure (LS + HEAD) using the broken swing as the
   //    neckline anchor. Fail early if no valid QM shape can be built.
   QMSwing head, ls;
   bool haveQM = (dir == QM_DIR_BEAR)
                 ? QM_FindQMStructure_Bear(brokenSwing.time, head, ls)
                 : QM_FindQMStructure_Bull(brokenSwing.time, head, ls);
   if(!haveQM)
   {
      if(InpQueueDebug)
         PrintFormat("[QM_NATIVE] MSS_DROPPED  reason=no_qm_structure  dir=%s  bar=%s  neck=%.2f@%s",
                     QM_DirName(dir),
                     TimeToString(shift_time, TIME_DATE|TIME_MINUTES),
                     brokenSwing.price,
                     TimeToString(brokenSwing.time, TIME_DATE|TIME_MINUTES));
      return;
   }

   // 2) POI zone from LS candle.
   double poi_top = 0.0, poi_bot = 0.0, head_price_from_poi = 0.0;
   int head_bar_shift = -1;
   if(!QM_ComputePOI(dir, ls.time, poi_top, poi_bot, head_bar_shift, head_price_from_poi))
   {
      if(InpQueueDebug)
         PrintFormat("[QM_NATIVE] MSS_DROPPED  reason=poi_lookup_failed  dir=%s  ls=%.2f@%s",
                     QM_DirName(dir), ls.price,
                     TimeToString(ls.time, TIME_DATE|TIME_MINUTES));
      return;
   }

   // 3) IDM level from the M15 swing ring.
   double idm_level = 0.0;
   ENUM_QM_DIR idm_side = QM_DIR_BEAR;
   if(!QM_ComputeIDM(dir, shift_time, idm_level, idm_side))
   {
      if(InpQueueDebug)
         PrintFormat("[QM_NATIVE] MSS_DROPPED  reason=no_idm  dir=%s",  QM_DirName(dir));
      return;
   }

   // 4) External target from H4 ERL (winner variant erl_h4).
   double erl_target = QM_ComputeERL(dir);
   if(erl_target <= 0.0)
   {
      if(InpQueueDebug)
         PrintFormat("[QM_NATIVE] MSS_DROPPED  reason=erl_not_ready  dir=%s (H4 swings h=%I64d l=%I64d)",
                     QM_DirName(dir), g_h4ShWritten, g_h4SlWritten);
      return;
   }

   // 5) Enqueue.
   const int shift_idx = 0;   // M15 shift bookkeeping; useful for diagnostics only
   const double atr    = QM_M15_ATR_shift1();
   const int slot = QM_AddSetup(
                       dir,
                       shift_time,
                       shift_idx,
                       disp,
                       poi_top,
                       poi_bot,
                       head_bar_shift,
                       head.price,
                       erl_target,
                       idm_level,
                       idm_side,
                       atr);
   if(slot < 0)
   {
      // queue full; QM_AddSetup already logged. Nothing to do.
      return;
   }

   if(InpQueueDebug)
      PrintFormat("[QM_NATIVE] MSS_ENQUEUED slot=%d dir=%s  ls=%.2f@%s  head=%.2f@%s  neck=%.2f  poi=[%.2f..%.2f]  IDM=%.2f  ERL=%.2f  atr=%.2f",
                  slot, QM_DirName(dir),
                  ls.price,   TimeToString(ls.time,   TIME_DATE|TIME_MINUTES),
                  head.price, TimeToString(head.time, TIME_DATE|TIME_MINUTES),
                  brokenSwing.price, poi_bot, poi_top, idm_level, erl_target, atr);
}

//==================== END BLOCK 3 ==================================
// Block 4 (queue advance on M15 close: POI return + IDM clear) will
// iterate g_qm_setups[] on each new M15 bar and transition slots from
// WAIT_POI_RETURN to WAIT_M5_CONFIRM. Block 5 then fires the trade on
// the M5 confirmation candle.
//===================================================================


//==================== EA LIFECYCLE ================================
int OnInit()
{
   QM_Init();

   // Block 2 setup: ATR M15 handle for the displacement gate.
   g_hATR_M15 = iATR(_Symbol, PERIOD_M15, InpAtrPeriod);
   if(g_hATR_M15 == INVALID_HANDLE)
   {
      Print("[QM_NATIVE] init FAIL - could not create iATR(M15,", InpAtrPeriod, ") handle");
      return(INIT_FAILED);
   }
   g_lastM15Time  = 0;
   g_shTop        = -1;
   g_slTop        = -1;
   g_shWritten    = 0;
   g_slWritten    = 0;
   g_mssBearCount = 0;
   g_mssBullCount = 0;
   g_barsSeen     = 0;

   // Block 3: reset H4 swing tracker state.
   g_lastH4Time   = 0;
   g_h4ShTop      = -1;
   g_h4SlTop      = -1;
   g_h4ShWritten  = 0;
   g_h4SlWritten  = 0;

   // Block 1 sanity: prove we can add + expire + GC end-to-end.
   // Runs once at startup and leaves the queue empty.
   const int probe = QM_AddSetup(
                        QM_DIR_BEAR,
                        TimeCurrent(),
                        0,
                        0.75,
                        3450.0, 3440.0,    // fake POI band for the probe
                        0,
                        3455.0,            // fake head
                        3410.0,            // fake ERL target
                        3452.0,            // fake IDM level
                        QM_DIR_BULL,       // clear opposite side
                        1.20);             // fake ATR
   if(probe >= 0)
   {
      QM_ExpireSetup(probe, "block1_probe");
      QM_GC();
   }
   QM_DumpQueue();
   Print("[QM_NATIVE] Block 2 armed - M15 structure detector live (pivot=", InpPivot,
         "  disp>=", DoubleToString(InpDispATR, 2), "  ATR(M15,", InpAtrPeriod, "))");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("[QM_NATIVE] deinit reason=", reason);
   PrintFormat("[QM_NATIVE] Block 2 stats: barsSeen=%I64d  swingH=%I64d  swingL=%I64d  MSS_bear=%I64d  MSS_bull=%I64d",
               g_barsSeen, g_shWritten, g_slWritten, g_mssBearCount, g_mssBullCount);
   PrintFormat("[QM_NATIVE] Block 3 stats: H4_swingH=%I64d  H4_swingL=%I64d  queue_added=%I64d  entered=%I64d  expired=%I64d",
               g_h4ShWritten, g_h4SlWritten,
               g_qm_added_total, g_qm_entered_total, g_qm_expired_total);
   if(g_hATR_M15 != INVALID_HANDLE) IndicatorRelease(g_hATR_M15);
   QM_DumpQueue();
}

void OnTick()
{
   // Block 3: new-H4-bar detection (fires 4x/day) - update H4 swing ring.
   datetime curH4 = iTime(_Symbol, PERIOD_H4, 0);
   if(curH4 != g_lastH4Time && curH4 != 0)
   {
      if(g_lastH4Time != 0) QM_OnNewH4Bar();
      g_lastH4Time = curH4;
   }

   // Block 2: new-M15-bar detection: on the first tick after a bar closes,
   // iTime(shift=0) returns the NEW forming bar's open time - different
   // from the previous open time we cached.
   datetime cur = iTime(_Symbol, PERIOD_M15, 0);
   if(cur != g_lastM15Time && cur != 0)
   {
      // exclude the very first init tick (g_lastM15Time == 0 seed).
      if(g_lastM15Time != 0) QM_OnNewM15Bar();
      g_lastM15Time = cur;
   }
}

//==================== END OF FILE ==================================

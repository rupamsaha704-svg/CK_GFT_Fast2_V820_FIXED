//+------------------------------------------------------------------+
//| CK_QM_ICT_EA.mq5                                                  |
//|                                                                   |
//| A NEW, distinct XAUUSD Expert Advisor implementing the            |
//| Quasimodo / ICT structure model that was built and validated in   |
//| Python (v1_lab/qm_state_machine.py) for this project. It is       |
//| structurally and functionally DIFFERENT from the trend/breakout   |
//| EAs in this repo (CK_GOLD_PRO_FIX09, XAU_Smart_EA, etc.): those    |
//| are EMA/breakout systems; THIS one trades a liquidity-driven       |
//| reversal chain:                                                   |
//|                                                                   |
//|   ERL raid -> M15 MSS (body-close + displacement) -> IDM formed    |
//|   -> IDM cleared -> price returns to the QM/POI (left-shoulder)    |
//|   zone -> HTF EMA trend-bias agrees -> M5 bearish/bullish          |
//|   confirmation -> ENTRY. SL beyond the head; TP = opposite         |
//|   external liquidity. Fixed 0.09 lot. XAUUSD only.                |
//|                                                                   |
//| VALIDATION NOTE (honest): the deterministic Python engine found    |
//| this setup PROMISING but selective (the EMA-bias variant showed    |
//| OOS PF ~1.7 with low drawdown across a plateau of EMA 150-300, but |
//| only ~50 trades/4yr, i.e. NOT yet certifiable on history). This EA |
//| exists to run a FORWARD DEMO to gather live evidence. Do NOT trade |
//| it live until the demo forward test supports it.                  |
//|                                                                   |
//| The order-execution plumbing (CTrade, fixed-lot clamp, spread      |
//| guard, OnTester CSV dump) is reused from the proven FIX09 EA; the  |
//| STRATEGY logic below is entirely new.                             |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//==================== INPUTS =======================================
input long   InpMagic            = 20260730;   // magic number (distinct)
input double InpFixedLot          = 0.09;      // EXACT lot every trade (hard-locked)
input double InpMaxLot            = 0.09;      // safety ceiling (never exceed)

input int    InpPivot            = 2;          // swing pivot (L/R bars) — LOCKED structural def
input double InpDispATR           = 0.6;       // MSS displacement gate (body/ATR14)
input int    InpAtrPeriod         = 14;        // ATR period (M15)
input bool   InpUseEmaBias        = true;      // HTF EMA trend-bias filter (validated improvement)
input int    InpEmaPeriod         = 200;       // EMA period on M15 (plateau 150-300; 200=representative)
input double InpSLBufferATR       = 0.5;       // stop buffer beyond head, in ATR
input double InpMinRR             = 1.0;        // reject setups with projected RR below this
input int    InpErlLookback       = 5;          // swings defining the external range (ERL/target)
input int    InpMaxTradesPerDay   = 2;          // daily entry cap
input int    InpLookbackBars      = 500;        // M15 bars scanned for structure
input int    InpSetupExpiryBars   = 40;         // an armed setup expires after this many M15 bars

input bool   InpUseSession        = true;       // restrict entries to a server-time window
input int    InpSessStartHour     = 13;         // session start (SERVER hour) — set to your broker's NY open
input int    InpSessEndHour       = 22;         // session end   (SERVER hour) — verify vs your broker/NY

input double InpMaxSpreadPrice    = 0.60;       // skip entries when spread exceeds this (price units)

//==================== GLOBAL STATE =================================
int      g_atrHandle = INVALID_HANDLE;
int      g_emaHandle = INVALID_HANDLE;
datetime g_lastBarTime = 0;

// armed-setup state (single active setup, mirrors the Python per-shift chain)
bool     g_armed        = false;
int      g_dir          = 0;      // -1 bear, +1 bull
double   g_poiLow       = 0.0;    // POI (left-shoulder) zone
double   g_poiHigh      = 0.0;
double   g_headPrice    = 0.0;    // the raided head extreme (for SL)
double   g_idmLevel     = 0.0;    // inducement level that must be cleared
bool     g_idmCleared   = false;
double   g_extTarget    = 0.0;    // opposite external liquidity (TP)
datetime g_armTime      = 0;      // when the setup was armed (for expiry)
datetime g_lastShiftTime= 0;      // dedupe: last MSS shift already processed

int      g_tradesToday  = 0;
int      g_curDay       = -1;

//==================== UTIL: fixed lot (0.09 hard cap) =============
double FixedLot()
{
   double lot = InpFixedLot;
   double mn  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double st  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(st > 0) lot = MathRound(lot / st) * st;
   if(lot < mn) lot = mn;
   if(lot > InpMaxLot) lot = InpMaxLot;   // hard 0.09 cap
   if(lot > mx) lot = mx;
   return(lot);
}

int MyPositions()
{
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         c++;
   }
   return(c);
}

//==================== INIT ========================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_NO);

   g_atrHandle = iATR(_Symbol, PERIOD_M15, InpAtrPeriod);
   g_emaHandle = iMA(_Symbol, PERIOD_M15, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_atrHandle == INVALID_HANDLE || g_emaHandle == INVALID_HANDLE)
   {
      Print("CK_QM_ICT: indicator handle creation failed");
      return(INIT_FAILED);
   }
   PrintFormat("CK_QM_ICT_EA init: lot=%.2f pivot=%d dispATR=%.2f emaBias=%s ema=%d minRR=%.2f",
               FixedLot(), InpPivot, InpDispATR, (InpUseEmaBias ? "on" : "off"), InpEmaPeriod, InpMinRR);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_emaHandle != INVALID_HANDLE) IndicatorRelease(g_emaHandle);
}

//==================== SWING DETECTION =============================
// Chronological arrays (index increases with time). A swing high at i needs
// high[i] strictly greater than the `pivot` bars on each side; mirror for lows.
bool IsSwingHigh(const double &h[], int i, int pivot, int n)
{
   if(i < pivot || i > n - 1 - pivot) return(false);
   for(int k = 1; k <= pivot; k++)
      if(!(h[i] > h[i-k] && h[i] > h[i+k])) return(false);
   return(true);
}
bool IsSwingLow(const double &l[], int i, int pivot, int n)
{
   if(i < pivot || i > n - 1 - pivot) return(false);
   for(int k = 1; k <= pivot; k++)
      if(!(l[i] < l[i-k] && l[i] < l[i+k])) return(false);
   return(true);
}

// most recent confirmed swing low index strictly before bar `before` (confirmed => pivot bars to its right)
int LastSwingLow(const double &l[], int before, int pivot, int n)
{
   for(int i = before - pivot; i >= pivot; i--)
      if(IsSwingLow(l, i, pivot, n)) return(i);
   return(-1);
}
int LastSwingHigh(const double &h[], int before, int pivot, int n)
{
   for(int i = before - pivot; i >= pivot; i--)
      if(IsSwingHigh(h, i, pivot, n)) return(i);
   return(-1);
}

//==================== SESSION FILTER ==============================
bool SessionOK(datetime t)
{
   if(!InpUseSession) return(true);
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int hr = dt.hour;
   if(InpSessStartHour <= InpSessEndHour)
      return(hr >= InpSessStartHour && hr < InpSessEndHour);
   // wrap-around window
   return(hr >= InpSessStartHour || hr < InpSessEndHour);
}

//==================== ARM A NEW SETUP =============================
// Scan the window for the most recent bearish/bullish MSS and, if a valid QM
// structure precedes it, arm the setup (POI, head, IDM, external target).
void TryArmSetup(const double &o[], const double &h[], const double &l[], const double &c[],
                 const datetime &tm[], int n, double atr)
{
   // find the most recent MSS (scan from newest closed bar backward)
   for(int i = n - 1; i >= InpPivot + 2; i--)
   {
      if(tm[i] <= g_lastShiftTime) break;   // already processed older shifts
      double body = MathAbs(c[i] - o[i]);
      if(atr <= 0) return;
      double disp = body / atr;
      if(disp < InpDispATR) continue;

      // bearish MSS: body close below the most recent confirmed swing low before i
      int slIdx = LastSwingLow(l, i, InpPivot, n);
      if(slIdx >= 0 && c[i] < l[slIdx] && (o[i] > c[i]))
      {
         // HEAD = the swing high between the neck (slIdx) and the shift (the raided liquidity)
         int headIdx = -1; double headHi = -1e18;
         for(int j = slIdx; j < i; j++)
            if(IsSwingHigh(h, j, InpPivot, n) && h[j] > headHi) { headHi = h[j]; headIdx = j; }
         // LEFT SHOULDER / POI = the swing high BEFORE the neck low (the QM return zone)
         int lsIdx = LastSwingHigh(h, slIdx, InpPivot, n);
         if(headIdx < 0 || lsIdx < 0) continue;

         // POI zone around the left shoulder: [ls swing low-ish .. ls high]. Use the LS candle range.
         g_poiHigh = h[lsIdx];
         g_poiLow  = MathMin(o[lsIdx], c[lsIdx]);
         g_headPrice = headHi;
         // IDM = inducement = the MSS/break-bar HIGH. It sits BELOW the head, so it is swept during
         // the retrace up toward the POI WITHOUT contradicting the head-broken invalidation.
         g_idmLevel = h[i];
         // external target = lowest low over the ERL lookback window before the shift
         double ext = l[i]; int cnt = 0;
         for(int j = i; j >= 0 && cnt < InpErlLookback * (2 * InpPivot + 1); j--, cnt++)
            if(l[j] < ext) ext = l[j];
         g_extTarget = ext;

         g_dir = -1; g_armed = true; g_idmCleared = false;
         g_armTime = tm[i]; g_lastShiftTime = tm[i];
         return;
      }

      // bullish MSS (mirror)
      int shIdx = LastSwingHigh(h, i, InpPivot, n);
      if(shIdx >= 0 && c[i] > h[shIdx] && (c[i] > o[i]))
      {
         int headIdx = -1; double headLo = 1e18;
         for(int j = shIdx; j < i; j++)
            if(IsSwingLow(l, j, InpPivot, n) && l[j] < headLo) { headLo = l[j]; headIdx = j; }
         int lsIdx = LastSwingLow(l, shIdx, InpPivot, n);
         if(headIdx < 0 || lsIdx < 0) continue;
         g_poiLow  = l[lsIdx];
         g_poiHigh = MathMax(o[lsIdx], c[lsIdx]);
         g_headPrice = headLo;
         g_idmLevel = l[i];   // inducement = MSS/break-bar LOW (above the head, swept on retrace down)
         double ext = h[i]; int cnt = 0;
         for(int j = i; j >= 0 && cnt < InpErlLookback * (2 * InpPivot + 1); j--, cnt++)
            if(h[j] > ext) ext = h[j];
         g_extTarget = ext;
         g_dir = +1; g_armed = true; g_idmCleared = false;
         g_armTime = tm[i]; g_lastShiftTime = tm[i];
         return;
      }
   }
}

//==================== M5 CONFIRMATION =============================
bool M5Confirms(int dir)
{
   double o5 = iOpen(_Symbol, PERIOD_M5, 1);
   double c5 = iClose(_Symbol, PERIOD_M5, 1);
   if(o5 == 0 || c5 == 0) return(false);
   if(dir < 0) return(c5 < o5);   // bearish close
   return(c5 > o5);               // bullish close
}

//==================== ORDER HELPERS ===============================
void OpenSell(double sl, double tp)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sl - bid <= 0) return;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   trade.Sell(FixedLot(), _Symbol, 0.0, NormalizeDouble(sl, dg), NormalizeDouble(tp, dg));
}
void OpenBuy(double sl, double tp)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask - sl <= 0) return;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   trade.Buy(FixedLot(), _Symbol, 0.0, NormalizeDouble(sl, dg), NormalizeDouble(tp, dg));
}

bool SpreadOK()
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long   sp = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   long   mx = (long)MathRound(InpMaxSpreadPrice / pt);
   return(sp <= mx);
}

//==================== MAIN: per new M15 bar =======================
void OnNewBar()
{
   // reset daily trade counter
   MqlDateTime dtn; TimeToStruct(TimeCurrent(), dtn);
   if(dtn.day != g_curDay) { g_curDay = dtn.day; g_tradesToday = 0; }

   if(MyPositions() > 0) return;              // one setup at a time; let SL/TP manage the trade

   int n = InpLookbackBars;
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int got = CopyRates(_Symbol, PERIOD_M15, 1, n, r);   // closed bars only (shift 1)
   if(got < InpEmaPeriod + 5) return;
   n = got;

   double o[], h[], l[], c[]; datetime tm[];
   ArrayResize(o, n); ArrayResize(h, n); ArrayResize(l, n); ArrayResize(c, n); ArrayResize(tm, n);
   for(int i = 0; i < n; i++)
   { o[i]=r[i].open; h[i]=r[i].high; l[i]=r[i].low; c[i]=r[i].close; tm[i]=r[i].time; }

   double atrBuf[1], emaBuf[1];
   if(CopyBuffer(g_atrHandle, 0, 1, 1, atrBuf) < 1) return;
   double atr = atrBuf[0];
   double ema = 0.0;
   if(InpUseEmaBias) { if(CopyBuffer(g_emaHandle, 0, 1, 1, emaBuf) < 1) return; ema = emaBuf[0]; }

   int last = n - 1;                          // most recent CLOSED M15 bar

   // 1) if not armed, try to arm a fresh setup from the latest structure
   if(!g_armed) TryArmSetup(o, h, l, c, tm, n, atr);
   if(!g_armed) return;

   // 2) expiry / invalidation
   if(tm[last] - g_armTime > (datetime)InpSetupExpiryBars * 15 * 60) { g_armed = false; return; }
   if(g_dir < 0 && h[last] > g_headPrice) { g_armed = false; return; }   // head broken => thesis dead
   if(g_dir > 0 && l[last] < g_headPrice) { g_armed = false; return; }

   // 3) IDM must be cleared (price raids the inducement) before the POI return
   if(!g_idmCleared)
   {
      if(g_dir < 0 && h[last] >= g_idmLevel) g_idmCleared = true;
      if(g_dir > 0 && l[last] <= g_idmLevel) g_idmCleared = true;
      if(!g_idmCleared) return;
   }

   // 4) price must RETURN into the POI zone on this bar
   bool inPOI = (h[last] >= g_poiLow && l[last] <= g_poiHigh);
   if(!inPOI) return;

   // 5) EMA trend-bias must agree (validated improvement): bear below EMA, bull above
   if(InpUseEmaBias)
   {
      if(g_dir < 0 && !(c[last] < ema)) return;
      if(g_dir > 0 && !(c[last] > ema)) return;
   }

   // 6) M5 confirmation + session + spread + daily cap
   if(!M5Confirms(g_dir)) return;
   if(!SessionOK(tm[last])) return;
   if(g_tradesToday >= InpMaxTradesPerDay) return;
   if(!SpreadOK()) return;

   // 7) place SL beyond head + ATR buffer; TP = opposite external liquidity; RR gate
   double buf = atr * InpSLBufferATR;
   if(g_dir < 0)
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = MathMax(g_poiHigh, g_headPrice) + buf;
      double tp = g_extTarget;
      double risk = sl - entry, reward = entry - tp;
      if(risk > 0 && reward / risk >= InpMinRR) { OpenSell(sl, tp); g_tradesToday++; }
   }
   else
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = MathMin(g_poiLow, g_headPrice) - buf;
      double tp = g_extTarget;
      double risk = entry - sl, reward = tp - entry;
      if(risk > 0 && reward / risk >= InpMinRR) { OpenBuy(sl, tp); g_tradesToday++; }
   }
   g_armed = false;   // consume the setup after an entry attempt
}

//==================== TICK ========================================
void OnTick()
{
   datetime bt = iTime(_Symbol, PERIOD_M15, 0);
   if(bt == g_lastBarTime) return;   // act once per new M15 bar
   g_lastBarTime = bt;
   OnNewBar();
}

//==================== OnTester: dump closed trades ================
double OnTester()
{
   int h = FileOpen("ck_qm_ict_trades.csv", FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h != INVALID_HANDLE)
   {
      FileWrite(h, "time", "profit");
      HistorySelect(0, TimeCurrent());
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         datetime xt = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         double p = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                  + HistoryDealGetDouble(ticket, DEAL_SWAP)
                  + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         FileWrite(h, TimeToString(xt, TIME_DATE | TIME_MINUTES), DoubleToString(p, 2));
      }
      FileClose(h);
   }
   return(0.0);
}
//+------------------------------------------------------------------+

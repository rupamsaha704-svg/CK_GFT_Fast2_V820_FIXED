//+------------------------------------------------------------------+
//| CK_QM_SignalPlayer.mq5                                          |
//|                                                                  |
//| Reads a Python-decided signal CSV (datetime, direction, entry,   |
//| sl, tp) and executes each signal in MT5 as a MARKET order at     |
//| the exact signal time. Purpose: measure Python's SIGNAL edge     |
//| under MT5's REAL-TICK execution (spread + slippage + swap +      |
//| commission). Steering §5: MT5 = truth.                          |
//|                                                                  |
//| Signal CSV format (in <terminal>/MQL5/Files/ or Common/Files/):  |
//|   datetime,direction,entry_price,sl_price,tp_price               |
//|   2025.08.01 12:15,SELL,3294.69,3302.10,3268.17                  |
//|                                                                  |
//| Lot sizing: risk-based -- lot = InpRiskUSD / (SL_dist * contract)|
//| Cap at InpMaxLot for safety.                                     |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//==================== INPUTS ======================================
input string InpSignalFile     = "signals_erl_h4.csv";  // in MQL5/Files/ (relative)
input long   InpMagic          = 20260921;
input double InpRiskUSD        = 85.0;         // risk per trade in $ (FN $6k funded-safe)
input double InpMaxLot         = 0.20;         // safety cap
input double InpMinLot         = 0.01;         // min lot allowed
input int    InpMaxConcurrent  = 2;            // max concurrent open positions (FN 3% rule buffer)
input int    InpToleranceMin   = 20;           // fire signal within +this many minutes of its time
input double InpMaxSpreadPrice = 0.60;         // skip if spread > this (price units)
input bool   InpUseCommonFiles = false;        // true = Common/Files/, false = terminal MQL5/Files/

// -------- H2 (ledger seq271): ATR-based trailing exit --------
input bool   InpUseTrail       = false;        // true = enable trailing SL update (H2 variant)
input double InpTrailStartATR  = 1.5;          // start trailing after price moves this many ATR in favor
input double InpTrailATRDist   = 2.0;          // keep SL this many ATR behind current price
input int    InpTrailATRPeriod = 14;           // ATR lookback (on M5 execution TF)

//==================== SIGNAL STRUCTURE ===========================
struct Signal
{
   datetime dt;
   int      dir;       // +1 = BUY, -1 = SELL
   double   entry;
   double   sl;
   double   tp;
   bool     fired;
};

Signal g_signals[];
int    g_nSignals = 0;
int    g_firedCount = 0;
int    g_atrM5Handle = INVALID_HANDLE;   // ATR(14) on M5 execution TF (for trailing)
int    g_trailUpdates = 0;                // count of SL trail updates

//==================== LOAD SIGNALS ================================
bool LoadSignals()
{
   int flags = FILE_READ | FILE_CSV | FILE_ANSI;
   if(InpUseCommonFiles) flags |= FILE_COMMON;
   int h = FileOpen(InpSignalFile, flags, ',');
   if(h == INVALID_HANDLE)
   {
      PrintFormat("CK_QM_SignalPlayer: could not open '%s' (err %d). Copy CSV to MQL5/Files/.",
                  InpSignalFile, GetLastError());
      return false;
   }

   // skip header row: datetime,direction,entry_price,sl_price,tp_price
   for(int i = 0; i < 5; i++) FileReadString(h);

   ArrayResize(g_signals, 0);
   g_nSignals = 0;
   int lineNo = 1;
   while(!FileIsEnding(h))
   {
      string dt_str = FileReadString(h);
      if(StringLen(dt_str) < 5) break;
      string dir_str = FileReadString(h);
      string entry_str = FileReadString(h);
      string sl_str = FileReadString(h);
      string tp_str = FileReadString(h);

      Signal s;
      s.dt    = StringToTime(dt_str);
      s.dir   = (dir_str == "BUY") ? +1 : -1;
      s.entry = StringToDouble(entry_str);
      s.sl    = StringToDouble(sl_str);
      s.tp    = StringToDouble(tp_str);
      s.fired = false;

      ArrayResize(g_signals, g_nSignals + 1);
      g_signals[g_nSignals++] = s;
      lineNo++;
   }
   FileClose(h);

   PrintFormat("CK_QM_SignalPlayer: loaded %d signals from '%s'", g_nSignals, InpSignalFile);
   if(g_nSignals > 0)
   {
      PrintFormat("  first: %s %s @ %.2f sl=%.2f tp=%.2f",
                  TimeToString(g_signals[0].dt, TIME_DATE|TIME_MINUTES),
                  (g_signals[0].dir==+1?"BUY":"SELL"),
                  g_signals[0].entry, g_signals[0].sl, g_signals[0].tp);
      PrintFormat("  last : %s %s @ %.2f sl=%.2f tp=%.2f",
                  TimeToString(g_signals[g_nSignals-1].dt, TIME_DATE|TIME_MINUTES),
                  (g_signals[g_nSignals-1].dir==+1?"BUY":"SELL"),
                  g_signals[g_nSignals-1].entry, g_signals[g_nSignals-1].sl, g_signals[g_nSignals-1].tp);
   }
   return (g_nSignals > 0);
}

//==================== INIT =======================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_NO);

   if(!LoadSignals())
   {
      Print("CK_QM_SignalPlayer: init failed (no signals).");
      return INIT_FAILED;
   }

   // ATR M5 handle for trailing (H2 variant)
   if(InpUseTrail)
   {
      g_atrM5Handle = iATR(_Symbol, PERIOD_M5, InpTrailATRPeriod);
      if(g_atrM5Handle == INVALID_HANDLE)
      {
         Print("CK_QM_SignalPlayer: ATR M5 handle failed; trailing disabled");
      }
   }

   PrintFormat("CK_QM_SignalPlayer init OK. risk=$%.0f max_lot=%.2f max_conc=%d tol=%dmin trail=%s",
               InpRiskUSD, InpMaxLot, InpMaxConcurrent, InpToleranceMin,
               (InpUseTrail ? "ON" : "off"));
   if(InpUseTrail)
      PrintFormat("  trail: start=%.1f*ATR favor, dist=%.1f*ATR behind price, ATR(M5,%d)",
                  InpTrailStartATR, InpTrailATRDist, InpTrailATRPeriod);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atrM5Handle != INVALID_HANDLE) IndicatorRelease(g_atrM5Handle);
   PrintFormat("CK_QM_SignalPlayer deinit: fired %d/%d signals, trail_updates=%d, reason=%d",
               g_firedCount, g_nSignals, g_trailUpdates, reason);
}

// -------- H2: trailing SL update --------
// For each open position, once price moved InpTrailStartATR*ATR in favor, keep SL
// InpTrailATRDist*ATR behind the current bid/ask. Only tighten (long: raise SL; short: lower SL).
void UpdateTrailingSL()
{
   if(!InpUseTrail || g_atrM5Handle == INVALID_HANDLE) return;
   double atrBuf[1];
   if(CopyBuffer(g_atrM5Handle, 0, 1, 1, atrBuf) < 1) return;   // read the last CLOSED M5 ATR (shift 1)
   double atr = atrBuf[0];
   if(atr <= 0.0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol) continue;

      long   ptype   = PositionGetInteger(POSITION_TYPE);
      double entry   = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL   = PositionGetDouble(POSITION_SL);
      double curTP   = PositionGetDouble(POSITION_TP);

      if(ptype == POSITION_TYPE_BUY)
      {
         double favor = bid - entry;                // unrealized favor in price units
         if(favor < InpTrailStartATR * atr) continue;  // not yet activated
         double newSL = NormalizeDouble(bid - InpTrailATRDist * atr, dg);
         if(newSL > curSL + _Point)               // only raise, meaningful move
         {
            if(trade.PositionModify(ticket, newSL, curTP))
            {
               g_trailUpdates++;
            }
         }
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         double favor = entry - ask;
         if(favor < InpTrailStartATR * atr) continue;
         double newSL = NormalizeDouble(ask + InpTrailATRDist * atr, dg);
         if(newSL < curSL - _Point || curSL == 0.0)
         {
            if(trade.PositionModify(ticket, newSL, curTP))
            {
               g_trailUpdates++;
            }
         }
      }
   }
}

//==================== HELPERS =====================================
int MyOpenPositions()
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
   return c;
}

// Compute lot size from risk in USD and SL distance in price units.
// contract_size for XAUUSD is 100 (oz), so 1 lot * 1 price point = $100.
double ComputeLot(double entry, double sl)
{
   double dist = MathAbs(entry - sl);
   if(dist <= 0.0) return 0.0;
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contract <= 0.0) contract = 100.0;
   double dollarPerLot = dist * contract;   // loss on 1 lot if SL hits
   if(dollarPerLot <= 0.0) return 0.0;
   double lot = InpRiskUSD / dollarPerLot;

   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step > 0.0) lot = MathFloor(lot / step) * step;
   if(lot < vmin) lot = vmin;
   if(lot < InpMinLot) lot = InpMinLot;
   if(lot > InpMaxLot) lot = InpMaxLot;
   if(lot > vmax) lot = vmax;
   return lot;
}

bool SpreadOK()
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long   sp = (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(pt <= 0.0) return true;
   long   mx = (long)MathRound(InpMaxSpreadPrice / pt);
   return (sp <= mx);
}

//==================== TICK ========================================
void OnTick()
{
   // 1. update trailing SL on any open positions (H2 variant)
   UpdateTrailingSL();

   // 2. signal firing loop
   datetime now = TimeCurrent();
   for(int i = 0; i < g_nSignals; i++)
   {
      if(g_signals[i].fired) continue;
      if(g_signals[i].dt > now) break;   // signals sorted chronologically

      // tolerance window: if we missed the signal by more than InpToleranceMin, skip forever
      if(now - g_signals[i].dt > (datetime)(InpToleranceMin * 60))
      {
         g_signals[i].fired = true;
         PrintFormat("  SKIP #%d (missed by >%d min): %s %s @ %.2f",
                     i+1, InpToleranceMin,
                     TimeToString(g_signals[i].dt, TIME_DATE|TIME_MINUTES),
                     (g_signals[i].dir==+1?"BUY":"SELL"),
                     g_signals[i].entry);
         continue;
      }

      // concurrent cap
      if(MyOpenPositions() >= InpMaxConcurrent) return;
      if(!SpreadOK()) return;

      double lot = ComputeLot(g_signals[i].entry, g_signals[i].sl);
      if(lot < InpMinLot)
      {
         g_signals[i].fired = true;
         PrintFormat("  SKIP #%d (lot below min): dist=%.2f", i+1,
                     MathAbs(g_signals[i].entry - g_signals[i].sl));
         continue;
      }

      int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double sl_n = NormalizeDouble(g_signals[i].sl, dg);
      double tp_n = NormalizeDouble(g_signals[i].tp, dg);

      bool ok = false;
      if(g_signals[i].dir == +1)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask - sl_n <= 0.0) { g_signals[i].fired = true; continue; }
         ok = trade.Buy(lot, _Symbol, 0.0, sl_n, tp_n);
      }
      else
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(sl_n - bid <= 0.0) { g_signals[i].fired = true; continue; }
         ok = trade.Sell(lot, _Symbol, 0.0, sl_n, tp_n);
      }

      if(ok)
      {
         g_signals[i].fired = true;
         g_firedCount++;
         PrintFormat("  FIRE #%d %s @ %s lot=%.2f entry_ref=%.2f sl=%.2f tp=%.2f",
                     i+1,
                     (g_signals[i].dir==+1?"BUY":"SELL"),
                     TimeToString(now, TIME_DATE|TIME_MINUTES),
                     lot,
                     g_signals[i].entry, g_signals[i].sl, g_signals[i].tp);
      }
      else
      {
         PrintFormat("  FAILED #%d %s: err %d", i+1,
                     (g_signals[i].dir==+1?"BUY":"SELL"), GetLastError());
      }
   }
}

//==================== ONTESTER: dump closed deals =================
double OnTester()
{
   int h = FileOpen("qm_signalplayer_deals.csv",
                    FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(h != INVALID_HANDLE)
   {
      FileWrite(h, "close_time", "type", "volume", "price", "sl", "tp", "profit", "swap", "commission", "comment");
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
         string tp   = (HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "SELL_close" : "BUY_close";
         double vol  = HistoryDealGetDouble(ticket, DEAL_VOLUME);
         double px   = HistoryDealGetDouble(ticket, DEAL_PRICE);
         double sl   = HistoryDealGetDouble(ticket, DEAL_SL);
         double tpx  = HistoryDealGetDouble(ticket, DEAL_TP);
         double p    = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         double sw   = HistoryDealGetDouble(ticket, DEAL_SWAP);
         double cm   = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         string cmt  = HistoryDealGetString(ticket, DEAL_COMMENT);
         FileWrite(h,
            TimeToString(xt, TIME_DATE|TIME_MINUTES),
            tp, DoubleToString(vol, 2),
            DoubleToString(px, _Digits),
            DoubleToString(sl, _Digits),
            DoubleToString(tpx, _Digits),
            DoubleToString(p, 2),
            DoubleToString(sw, 2),
            DoubleToString(cm, 2),
            cmt);
      }
      FileClose(h);
   }
   return(0.0);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                            CK_GFT_LIR_V1.mq5    |
//|                                                      CK GFT Fast |
//|  Liquidity Injection Retest (LIR) Strategy V1.0                  |
//|  Institutional-grade entry: Sweep → Injection → Retest → Target  |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//============================================================
// INPUTS
//============================================================
input long   InpMagic              = 20260728;
input double InpRiskDefault        = 0.35;     // Default risk %
input double InpRiskReduced        = 0.25;     // Reduced risk for lower score
input double InpFallbackRR         = 2.0;      // Fallback RR if no liquidity target
input int    InpMaxTradesPerDay    = 3;
input double InpDailyLossStopR     = 1.5;
input double InpDailyProfitStopR   = 5.0;
input int    InpMaxSpreadPoints    = 50;
input int    InpDeviationPoints    = 30;
input double InpMaxLot             = 0.10;
input bool   InpAllowFridayEntries = false;
input bool   InpAllowSells         = true;
input bool   InpVerboseLogs        = true;

// Sweep parameters
input double InpSweepMinDepthATR   = 0.05;    // Min sweep depth as ATR fraction
input double InpSweepMaxDepthATR   = 0.30;    // Max sweep depth
input double InpSweepMaxRangeATR   = 2.0;     // Max candle range for sweep
input double InpMinWickRatio       = 0.40;    // Min wick ratio for rejection

// Injection proxy
input double InpVolMultiplier      = 1.50;    // Tick vol must be >= this × median
input double InpSpreadMultMax      = 1.25;    // Spread must be <= this × median
input double InpCloseLocMin        = 0.65;    // Close location minimum for buy

// Structure & Entry
input int    InpConfirmWaitBars    = 3;       // Max bars to wait for confirmation
input double InpConfirmBodyMin     = 0.50;    // Min body ratio for confirmation candle
input double InpEntryRetracement   = 0.50;    // 50% body retracement
input int    InpEntryValidBars     = 3;       // Pending entry valid for N bars

// SL parameters
input double InpSLMinATR           = 0.80;    // Min SL distance as ATR
input double InpSLMaxATR           = 2.50;    // Max SL distance as ATR
input double InpSLBufferATR        = 0.10;    // SL safety buffer

// Target parameters
input double InpTargetMinRR        = 1.40;    // Min target RR
input double InpTargetMaxRR        = 3.00;    // Max target RR
input double InpTargetBufferATR    = 0.10;    // Buffer before liquidity

// Stop management
input int    InpFailExitBars       = 4;       // Failure exit check bars
input double InpFailExitThreshold  = 0.50;    // Must reach 0.5R or exit
input double InpBEActivateR        = 1.0;     // Activate BE after 1R (candle close, not wick)
input int    InpBEOffsetPoints     = 10;      // BE offset for cost recovery

// Score
input int    InpMinScore           = 65;      // Minimum score to trade

// M15 context
input bool   InpUseM15Context      = true;
input int    InpM15EMAFast         = 21;
input int    InpM15EMASlow         = 50;

const double HARD_MAX_LOT = 0.10;

//============================================================
// INDICATOR HANDLES
//============================================================
int atrHandle, m15EmaFastHandle, m15EmaSlowHandle;

//============================================================
// LIQUIDITY LEVELS
//============================================================
struct LiqLevel
{
   double price;
   bool   isHigh;       // true=high (sell target / buy sweep), false=low
   int    strength;     // stacked = higher strength
   bool   touched;      // already swept
   string source;       // "PDH","PDL","AsiaH","AsiaL","SwingH","SwingL" etc
};

LiqLevel g_levels[];
int g_levelCount = 0;

//============================================================
// STATE
//============================================================
datetime lastBarTime = 0;
datetime g_dayStart = 0;
double g_dayStartBal = 0;
double g_oneRMoney = 0;
int g_tradesToday = 0;

// Setup states
enum SETUP_PHASE { PHASE_IDLE, PHASE_SWEPT, PHASE_CONFIRMED, PHASE_PENDING };
SETUP_PHASE g_phase = PHASE_IDLE;
int g_setupDir = 0;         // +1 buy, -1 sell
double g_sweepLevel = 0;    // The liquidity level that was swept
double g_sweepExtreme = 0;  // The actual sweep low/high
double g_confirmHigh = 0;
double g_confirmLow = 0;
double g_confirmBodyHigh = 0;
double g_confirmBodyLow = 0;
double g_entryPrice = 0;
double g_entrySL = 0;
double g_entryTP = 0;
int g_phaseBarCount = 0;
int g_injectionScore = 0;
datetime g_setupBarTime = 0;

// Position tracking
int g_posBarCount = 0;
double g_posEntry = 0;
double g_posOneR = 0;
bool g_beMoved = false;

// Diagnostics
int g_diagSweeps = 0;
int g_diagConfirmed = 0;
int g_diagEntries = 0;
int g_diagFails = 0;
int g_diagScoreReject = 0;
int g_diagNoTarget = 0;

//============================================================
// INITIALIZATION
//============================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetAsyncMode(false);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   atrHandle = iATR(_Symbol, PERIOD_M5, 14);
   m15EmaFastHandle = iMA(_Symbol, PERIOD_M15, InpM15EMAFast, 0, MODE_EMA, PRICE_CLOSE);
   m15EmaSlowHandle = iMA(_Symbol, PERIOD_M15, InpM15EMASlow, 0, MODE_EMA, PRICE_CLOSE);
   
   if(atrHandle==INVALID_HANDLE || m15EmaFastHandle==INVALID_HANDLE || m15EmaSlowHandle==INVALID_HANDLE)
      return INIT_FAILED;
   
   ResetDaily();
   lastBarTime = iTime(_Symbol, PERIOD_M5, 0);
   BuildLiquidityMap();
   
   if(InpVerboseLogs)
      PrintFormat("CK_LIR|INIT|V1.0|risk=%.2f%%|lot_cap=%.2f|friday=%s", InpRiskDefault, InpMaxLot, InpAllowFridayEntries?"ON":"OFF");
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(m15EmaFastHandle!=INVALID_HANDLE) IndicatorRelease(m15EmaFastHandle);
   if(m15EmaSlowHandle!=INVALID_HANDLE) IndicatorRelease(m15EmaSlowHandle);
   
   PrintFormat("CK_LIR|DIAG|sweeps=%d|confirmed=%d|entries=%d|fails=%d|score_reject=%d|no_target=%d",
      g_diagSweeps, g_diagConfirmed, g_diagEntries, g_diagFails, g_diagScoreReject, g_diagNoTarget);
}

//============================================================
// HELPERS
//============================================================
double ATR14()
{
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(atrHandle,0,1,1,b)!=1) return 0;
   return b[0];
}

double M15EmaFast()
{
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(m15EmaFastHandle,0,0,1,b)!=1) return 0;
   return b[0];
}

double M15EmaSlow()
{
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(m15EmaSlowHandle,0,0,1,b)!=1) return 0;
   return b[0];
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t<=0) return false;
   if(t!=lastBarTime){lastBarTime=t; return true;}
   return false;
}

void ResetDaily()
{
   datetime ds = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStart = (ds>0 ? ds : TimeCurrent());
   double pnl=0; int entries=0;
   if(HistorySelect(g_dayStart, TimeCurrent()))
   {
      for(int i=0; i<HistoryDealsTotal(); i++)
      {
         ulong tk=HistoryDealGetTicket(i); if(tk==0) continue;
         pnl += HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_SWAP);
         if(HistoryDealGetString(tk,DEAL_SYMBOL)==_Symbol && HistoryDealGetInteger(tk,DEAL_MAGIC)==InpMagic)
         {
            ENUM_DEAL_ENTRY de=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk,DEAL_ENTRY);
            if(de==DEAL_ENTRY_IN||de==DEAL_ENTRY_INOUT) entries++;
         }
      }
   }
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartBal = bal-pnl; if(g_dayStartBal<=0) g_dayStartBal=bal;
   g_oneRMoney = g_dayStartBal*(InpRiskDefault/100.0);
   g_tradesToday = entries;
}

double RealizedR()
{
   if(g_oneRMoney<=0) return 0;
   return (AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneRMoney;
}

bool TradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   MqlDateTime dt={}; TimeToStruct(TimeCurrent(),dt);
   if(dt.day_of_week==0||dt.day_of_week==6) return false;
   if(!InpAllowFridayEntries && dt.day_of_week==5) return false;
   double r=RealizedR();
   if(InpDailyProfitStopR>0 && r>=InpDailyProfitStopR) return false;
   if(InpDailyLossStopR>0 && r<=-InpDailyLossStopR) return false;
   if(g_tradesToday>=InpMaxTradesPerDay) return false;
   return true;
}

ulong MyTicket()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagic) return tk;
   }
   return 0;
}

bool HasPosition(){return MyTicket()!=0;}

double GetTickSize()
{
   double ts=0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,ts)||ts<=0)
      ts=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   return ts;
}

double PriceFloor(double p){double ts=GetTickSize();int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);if(ts<=0)return NormalizeDouble(p,dg);return NormalizeDouble(MathFloor((p/ts)+1e-10)*ts,dg);}
double PriceCeil(double p){double ts=GetTickSize();int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);if(ts<=0)return NormalizeDouble(p,dg);return NormalizeDouble(MathCeil((p/ts)-1e-10)*ts,dg);}

double CalcLots(double riskMoney, double slDist)
{
   if(riskMoney<=0||slDist<=0) return 0;
   double tv=0,ts=0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,tv)||tv<=0)
      SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE,tv);
   SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,ts);
   if(tv<=0||ts<=0) return 0;
   double lossPerLot=(slDist/ts)*tv;
   if(lossPerLot<=0) return 0;
   double raw=riskMoney/lossPerLot;
   double vMin=0,vMax=0,vStep=0;
   SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN,vMin);
   SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX,vMax);
   SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP,vStep);
   if(vMin<=0||vMax<=0||vStep<=0) return 0;
   double lots=MathFloor(raw/vStep)*vStep;
   lots=MathMin(lots,MathMin(vMax,MathMin(InpMaxLot,HARD_MAX_LOT)));
   if(lots<vMin) return 0; // Never force minimum
   int volDg=2; for(int d=0;d<=8;d++) if(MathAbs(NormalizeDouble(vStep,d)-vStep)<1e-12){volDg=d;break;}
   return NormalizeDouble(lots,volDg);
}

//============================================================
// LIQUIDITY MAP
//============================================================
void BuildLiquidityMap()
{
   g_levelCount = 0;
   ArrayResize(g_levels, 20);
   
   // Previous Day High/Low
   double pdh = iHigh(_Symbol, PERIOD_D1, 1);
   double pdl = iLow(_Symbol, PERIOD_D1, 1);
   if(pdh>0) AddLevel(pdh, true, "PDH");
   if(pdl>0) AddLevel(pdl, false, "PDL");
   
   // Previous Week High/Low
   double pwh = iHigh(_Symbol, PERIOD_W1, 1);
   double pwl = iLow(_Symbol, PERIOD_W1, 1);
   if(pwh>0) AddLevel(pwh, true, "PWH");
   if(pwl>0) AddLevel(pwl, false, "PWL");
   
   // Asia session High/Low (approx 00:00-08:00 server)
   MqlDateTime dt={}; TimeToStruct(TimeCurrent(), dt);
   datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(todayStart > 0 && dt.hour >= 8)
   {
      // Find Asia range from today's first bars
      MqlRates asiaRates[];
      ArraySetAsSeries(asiaRates, true);
      int asiaBars = (int)(8*12); // 8 hours × 12 bars per hour on M5
      int copied = CopyRates(_Symbol, PERIOD_M5, todayStart, asiaBars, asiaRates);
      if(copied > 0)
      {
         double asiaH=0, asiaL=999999;
         for(int i=0; i<copied; i++)
         {
            if(asiaRates[i].high > asiaH) asiaH = asiaRates[i].high;
            if(asiaRates[i].low < asiaL) asiaL = asiaRates[i].low;
         }
         if(asiaH>0) AddLevel(asiaH, true, "AsiaH");
         if(asiaL<999999) AddLevel(asiaL, false, "AsiaL");
      }
   }
   
   // M5 Swing High/Low (last 50 bars, simple pivot detection)
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 50, r)==50)
   {
      for(int i=2; i<48; i++)
      {
         if(r[i].high > r[i-1].high && r[i].high > r[i-2].high &&
            r[i].high > r[i+1].high && r[i].high > r[i+2].high)
            AddLevel(r[i].high, true, "SwH5");
         if(r[i].low < r[i-1].low && r[i].low < r[i-2].low &&
            r[i].low < r[i+1].low && r[i].low < r[i+2].low)
            AddLevel(r[i].low, false, "SwL5");
      }
   }
   
   // M15 Swing High/Low
   MqlRates r15[]; ArraySetAsSeries(r15, true);
   if(CopyRates(_Symbol, PERIOD_M15, 1, 30, r15)==30)
   {
      for(int i=2; i<28; i++)
      {
         if(r15[i].high > r15[i-1].high && r15[i].high > r15[i+1].high &&
            r15[i].high > r15[i+2].high)
            AddLevel(r15[i].high, true, "SwH15");
         if(r15[i].low < r15[i-1].low && r15[i].low < r15[i+1].low &&
            r15[i].low < r15[i+2].low)
            AddLevel(r15[i].low, false, "SwL15");
      }
   }
   
   // Mark stacked levels
   double atr = ATR14();
   if(atr > 0)
   {
      for(int i=0; i<g_levelCount; i++)
      {
         for(int j=i+1; j<g_levelCount; j++)
         {
            if(MathAbs(g_levels[i].price - g_levels[j].price) < 0.20*atr)
            {
               g_levels[i].strength += 5;
               g_levels[j].strength += 5;
            }
         }
      }
   }
}

void AddLevel(double price, bool isHigh, string src)
{
   if(g_levelCount >= ArraySize(g_levels))
      ArrayResize(g_levels, g_levelCount+10);
   g_levels[g_levelCount].price = price;
   g_levels[g_levelCount].isHigh = isHigh;
   g_levels[g_levelCount].strength = 10;
   g_levels[g_levelCount].touched = false;
   g_levels[g_levelCount].source = src;
   g_levelCount++;
}

// Find nearest untouched liquidity in direction
double FindNextLiquidity(double fromPrice, int dir, double &levelPrice)
{
   levelPrice = 0;
   double bestDist = 999999;
   
   for(int i=0; i<g_levelCount; i++)
   {
      if(g_levels[i].touched) continue;
      double lp = g_levels[i].price;
      
      if(dir > 0 && lp > fromPrice) // Buy: look for highs above
      {
         double dist = lp - fromPrice;
         if(dist < bestDist) { bestDist = dist; levelPrice = lp; }
      }
      else if(dir < 0 && lp < fromPrice) // Sell: look for lows below
      {
         double dist = fromPrice - lp;
         if(dist < bestDist) { bestDist = dist; levelPrice = lp; }
      }
   }
   return levelPrice;
}

// Find nearest liquidity for sweep detection
double FindNearestLiqBelow(double price)
{
   double best=0;
   for(int i=0; i<g_levelCount; i++)
   {
      if(g_levels[i].isHigh) continue; // Only lows for buy sweep
      if(g_levels[i].price < price && g_levels[i].price > best)
         best = g_levels[i].price;
   }
   return best;
}

double FindNearestLiqAbove(double price)
{
   double best=999999;
   for(int i=0; i<g_levelCount; i++)
   {
      if(!g_levels[i].isHigh) continue; // Only highs for sell sweep
      if(g_levels[i].price > price && g_levels[i].price < best)
         best = g_levels[i].price;
   }
   return best;
}

//============================================================
// TICK VOLUME MEDIAN
//============================================================
double MedianTickVol(int period)
{
   long vols[];
   ArrayResize(vols, period);
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M5, 2, period, r)!=period) return 1;
   double sorted[];
   ArrayResize(sorted, period);
   for(int i=0; i<period; i++) sorted[i] = (double)r[i].tick_volume;
   ArraySort(sorted);
   return sorted[period/2];
}

double MedianSpread(int period)
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M5, 2, period, r)!=period) return 1;
   double sorted[];
   ArrayResize(sorted, period);
   for(int i=0; i<period; i++) sorted[i] = (double)r[i].spread;
   ArraySort(sorted);
   return sorted[period/2];
}

//============================================================
// SWEEP DETECTION
//============================================================
void CheckForSweep()
{
   if(g_phase != PHASE_IDLE) return;
   
   double atr = ATR14(); if(atr<=0) return;
   
   MqlRates bar[]; ArraySetAsSeries(bar, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, bar)!=1) return;
   
   double range = bar[0].high - bar[0].low;
   if(range <= 0 || range > InpSweepMaxRangeATR * atr) return;
   
   // === BULLISH SWEEP (sweep low, close above) ===
   double liqBelow = FindNearestLiqBelow(bar[0].open);
   if(liqBelow > 0 && bar[0].low < liqBelow)
   {
      double sweepDepth = liqBelow - bar[0].low;
      double depthATR = sweepDepth / atr;
      
      if(depthATR >= InpSweepMinDepthATR && depthATR <= InpSweepMaxDepthATR)
      {
         // Close must be above level
         if(bar[0].close > liqBelow)
         {
            // Lower wick check
            double lowerWick = MathMin(bar[0].open, bar[0].close) - bar[0].low;
            double wickRatio = lowerWick / range;
            
            if(wickRatio >= InpMinWickRatio)
            {
               // Check injection proxy (2 of 3)
               int injCount = 0;
               double medVol = MedianTickVol(20);
               double medSpread = MedianSpread(20);
               
               if((double)bar[0].tick_volume >= InpVolMultiplier * medVol) injCount++;
               if((double)bar[0].spread <= InpSpreadMultMax * medSpread) injCount++;
               double closeLoc = (bar[0].close - bar[0].low) / range;
               if(closeLoc >= InpCloseLocMin) injCount++;
               
               if(injCount >= 2)
               {
                  // BULLISH SWEEP CONFIRMED!
                  g_phase = PHASE_SWEPT;
                  g_setupDir = +1;
                  g_sweepLevel = liqBelow;
                  g_sweepExtreme = bar[0].low;
                  g_phaseBarCount = 0;
                  g_injectionScore = CalcScore(true, depthATR, wickRatio, injCount, closeLoc);
                  g_setupBarTime = bar[0].time;
                  g_diagSweeps++;
                  
                  if(InpVerboseLogs)
                     PrintFormat("CK_LIR|SWEEP_BUY|level=%.2f|low=%.2f|depth=%.3fATR|wick=%.0f%%|score=%d",
                        liqBelow, bar[0].low, depthATR, wickRatio*100, g_injectionScore);
               }
            }
         }
      }
   }
   
   // === BEARISH SWEEP (sweep high, close below) ===
   if(g_phase==PHASE_IDLE && InpAllowSells)
   {
      double liqAbove = FindNearestLiqAbove(bar[0].open);
      if(liqAbove > 0 && bar[0].high > liqAbove)
      {
         double sweepDepth = bar[0].high - liqAbove;
         double depthATR = sweepDepth / atr;
         
         if(depthATR >= InpSweepMinDepthATR && depthATR <= InpSweepMaxDepthATR)
         {
            if(bar[0].close < liqAbove)
            {
               double upperWick = bar[0].high - MathMax(bar[0].open, bar[0].close);
               double wickRatio = upperWick / range;
               
               if(wickRatio >= InpMinWickRatio)
               {
                  int injCount = 0;
                  double medVol = MedianTickVol(20);
                  double medSpread = MedianSpread(20);
                  
                  if((double)bar[0].tick_volume >= InpVolMultiplier * medVol) injCount++;
                  if((double)bar[0].spread <= InpSpreadMultMax * medSpread) injCount++;
                  double closeLoc = (bar[0].high - bar[0].close) / range;
                  if(closeLoc >= InpCloseLocMin) injCount++;
                  
                  if(injCount >= 2)
                  {
                     g_phase = PHASE_SWEPT;
                     g_setupDir = -1;
                     g_sweepLevel = liqAbove;
                     g_sweepExtreme = bar[0].high;
                     g_phaseBarCount = 0;
                     g_injectionScore = CalcScore(false, depthATR, wickRatio, injCount, closeLoc);
                     g_setupBarTime = bar[0].time;
                     g_diagSweeps++;
                     
                     if(InpVerboseLogs)
                        PrintFormat("CK_LIR|SWEEP_SELL|level=%.2f|high=%.2f|depth=%.3fATR|score=%d",
                           liqAbove, bar[0].high, depthATR, g_injectionScore);
                  }
               }
            }
         }
      }
   }
}

//============================================================
// INJECTION QUALITY SCORE
//============================================================
int CalcScore(bool isBuy, double depthATR, double wickRatio, int injCount, double closeLoc)
{
   int score = 0;
   
   // Sweep depth quality (0-10)
   if(depthATR >= 0.10 && depthATR <= 0.20) score += 10;
   else score += 5;
   
   // Wick rejection (0-10)
   if(wickRatio >= 0.60) score += 10;
   else if(wickRatio >= 0.50) score += 7;
   else score += 4;
   
   // Tick volume injection (0-15)
   if(injCount >= 3) score += 15;
   else if(injCount >= 2) score += 10;
   
   // Close location (0-10)
   if(closeLoc >= 0.75) score += 10;
   else if(closeLoc >= 0.65) score += 7;
   else score += 4;
   
   // Spread quality (0-10)
   score += 7; // Assume normal unless flagged
   
   // Stacked level (0-15)
   for(int i=0; i<g_levelCount; i++)
   {
      if(MathAbs(g_levels[i].price - g_sweepLevel) < 0.01)
      {
         if(g_levels[i].strength > 10) score += 15;
         else score += 8;
         break;
      }
   }
   
   // M15 alignment (0-10)
   if(InpUseM15Context)
   {
      double f = M15EmaFast(), s = M15EmaSlow();
      if(f>0 && s>0)
      {
         if(isBuy && f > s) score += 10;
         else if(!isBuy && f < s) score += 10;
         else score += 3;
      }
   }
   else score += 5;
   
   // Clear target (0-5) - check later
   score += 5;
   
   return score;
}

//============================================================
// MICRO STRUCTURE CONFIRMATION
//============================================================
void CheckConfirmation()
{
   if(g_phase != PHASE_SWEPT) return;
   
   g_phaseBarCount++;
   if(g_phaseBarCount > InpConfirmWaitBars)
   {
      ResetSetup();
      return;
   }
   
   MqlRates bars[]; ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 4, bars)!=4) return;
   
   MqlRates cur = bars[0]; // Last completed bar
   double range = cur.high - cur.low;
   if(range <= 0) return;
   double body = MathAbs(cur.close - cur.open);
   double bodyRatio = body / range;
   
   if(g_setupDir > 0) // Buy confirmation
   {
      // Need bullish candle closing above recent micro swing high
      if(cur.close <= cur.open) return; // Must be bullish
      if(bodyRatio < InpConfirmBodyMin) return;
      if(cur.close <= g_sweepLevel) return; // Must close above sweep level
      
      // Check it didn't break sweep low
      if(cur.low < g_sweepExtreme) { ResetSetup(); return; }
      
      // Check micro swing high break (high of last 2-3 bars)
      double microHigh = MathMax(bars[1].high, bars[2].high);
      if(cur.close <= microHigh) return; // Not yet broken micro high
      
      // CONFIRMED!
      g_phase = PHASE_CONFIRMED;
      g_confirmBodyHigh = MathMax(cur.open, cur.close);
      g_confirmBodyLow = MathMin(cur.open, cur.close);
      g_confirmHigh = cur.high;
      g_confirmLow = cur.low;
      g_diagConfirmed++;
      
      // Calculate entry, SL, TP
      CalcEntryBuy();
   }
   else if(g_setupDir < 0) // Sell confirmation
   {
      if(cur.close >= cur.open) return; // Must be bearish
      if(bodyRatio < InpConfirmBodyMin) return;
      if(cur.close >= g_sweepLevel) return;
      if(cur.high > g_sweepExtreme) { ResetSetup(); return; }
      
      double microLow = MathMin(bars[1].low, bars[2].low);
      if(cur.close >= microLow) return;
      
      g_phase = PHASE_CONFIRMED;
      g_confirmBodyHigh = MathMax(cur.open, cur.close);
      g_confirmBodyLow = MathMin(cur.open, cur.close);
      g_confirmHigh = cur.high;
      g_confirmLow = cur.low;
      g_diagConfirmed++;
      
      CalcEntrySell();
   }
}

//============================================================
// ENTRY CALCULATION
//============================================================
void CalcEntryBuy()
{
   double atr = ATR14(); if(atr<=0) { ResetSetup(); return; }
   double bodySize = g_confirmBodyHigh - g_confirmBodyLow;
   
   // Entry = 50% body retracement
   g_entryPrice = PriceCeil(g_confirmBodyHigh - (InpEntryRetracement * bodySize));
   
   // Entry must be above sweep level
   if(g_entryPrice <= g_sweepLevel) g_entryPrice = PriceCeil(g_sweepLevel + 0.05*atr);
   
   // SL = sweep extreme - buffer
   double buffer = MathMax(InpSLBufferATR*atr, 1.5*SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   double minStopDist = (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   buffer = MathMax(buffer, minStopDist);
   
   g_entrySL = PriceFloor(g_sweepExtreme - buffer);
   
   double slDist = g_entryPrice - g_entrySL;
   if(slDist < InpSLMinATR*atr || slDist > InpSLMaxATR*atr) { ResetSetup(); return; }
   
   // Target: next liquidity above
   double nextLiq = 0;
   FindNextLiquidity(g_entryPrice, +1, nextLiq);
   
   if(nextLiq > 0)
   {
      double targetBuf = MathMax(InpTargetBufferATR*atr, 2*SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
      g_entryTP = PriceFloor(nextLiq - targetBuf);
      double tpDist = g_entryTP - g_entryPrice;
      double rr = tpDist / slDist;
      
      if(rr < InpTargetMinRR)
      {
         // Try fallback RR
         g_entryTP = PriceCeil(g_entryPrice + InpFallbackRR*slDist);
      }
      else if(rr > InpTargetMaxRR)
      {
         g_entryTP = PriceCeil(g_entryPrice + InpTargetMaxRR*slDist);
      }
   }
   else
   {
      g_entryTP = PriceCeil(g_entryPrice + InpFallbackRR*slDist);
      g_diagNoTarget++;
   }
   
   // Score check
   if(g_injectionScore < InpMinScore) { g_diagScoreReject++; ResetSetup(); return; }
   
   // M15 strong opposition check
   if(InpUseM15Context)
   {
      double f=M15EmaFast(), s=M15EmaSlow();
      if(f>0 && s>0 && f<s) // M15 bearish
      {
         // Check if strongly bearish (both slopes down)
         // Simplified: if score already low, reject
         if(g_injectionScore < 70) { ResetSetup(); return; }
      }
   }
   
   g_phase = PHASE_PENDING;
   g_phaseBarCount = 0;
   
   if(InpVerboseLogs)
      PrintFormat("CK_LIR|PENDING_BUY|entry=%.2f|sl=%.2f|tp=%.2f|score=%d|RR=%.2f",
         g_entryPrice, g_entrySL, g_entryTP, g_injectionScore, (g_entryTP-g_entryPrice)/(g_entryPrice-g_entrySL));
}

void CalcEntrySell()
{
   double atr = ATR14(); if(atr<=0) { ResetSetup(); return; }
   double bodySize = g_confirmBodyHigh - g_confirmBodyLow;
   
   g_entryPrice = PriceFloor(g_confirmBodyLow + (InpEntryRetracement * bodySize));
   if(g_entryPrice >= g_sweepLevel) g_entryPrice = PriceFloor(g_sweepLevel - 0.05*atr);
   
   double buffer = MathMax(InpSLBufferATR*atr, 1.5*SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   double minStopDist = (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   buffer = MathMax(buffer, minStopDist);
   
   g_entrySL = PriceCeil(g_sweepExtreme + buffer);
   
   double slDist = g_entrySL - g_entryPrice;
   if(slDist < InpSLMinATR*atr || slDist > InpSLMaxATR*atr) { ResetSetup(); return; }
   
   double nextLiq = 0;
   FindNextLiquidity(g_entryPrice, -1, nextLiq);
   
   if(nextLiq > 0)
   {
      double targetBuf = MathMax(InpTargetBufferATR*atr, 2*SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*SymbolInfoDouble(_Symbol,SYMBOL_POINT));
      g_entryTP = PriceCeil(nextLiq + targetBuf);
      double tpDist = g_entryPrice - g_entryTP;
      double rr = tpDist / slDist;
      if(rr < InpTargetMinRR) g_entryTP = PriceFloor(g_entryPrice - InpFallbackRR*slDist);
      else if(rr > InpTargetMaxRR) g_entryTP = PriceFloor(g_entryPrice - InpTargetMaxRR*slDist);
   }
   else
   {
      g_entryTP = PriceFloor(g_entryPrice - InpFallbackRR*slDist);
      g_diagNoTarget++;
   }
   
   if(g_injectionScore < InpMinScore) { g_diagScoreReject++; ResetSetup(); return; }
   
   if(InpUseM15Context)
   {
      double f=M15EmaFast(), s=M15EmaSlow();
      if(f>0 && s>0 && f>s && g_injectionScore<70) { ResetSetup(); return; }
   }
   
   g_phase = PHASE_PENDING;
   g_phaseBarCount = 0;
   
   if(InpVerboseLogs)
      PrintFormat("CK_LIR|PENDING_SELL|entry=%.2f|sl=%.2f|tp=%.2f|score=%d", g_entryPrice, g_entrySL, g_entryTP, g_injectionScore);
}

//============================================================
// PENDING ENTRY CHECK
//============================================================
void CheckPendingEntry()
{
   if(g_phase != PHASE_PENDING) return;
   if(!TradingAllowed()) { ResetSetup(); return; }
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
   
   g_phaseBarCount++;
   if(g_phaseBarCount > InpEntryValidBars) { ResetSetup(); return; }
   
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick)) return;
   
   // Check cancellation conditions
   MqlRates lastBar[]; ArraySetAsSeries(lastBar,true);
   if(CopyRates(_Symbol,PERIOD_M5,1,1,lastBar)==1)
   {
      if(g_setupDir>0 && lastBar[0].close < g_sweepExtreme) { ResetSetup(); return; }
      if(g_setupDir<0 && lastBar[0].close > g_sweepExtreme) { ResetSetup(); return; }
   }
   
   if(g_setupDir > 0) // Buy limit
   {
      if(tick.ask <= g_entryPrice) ExecuteBuy();
   }
   else if(g_setupDir < 0) // Sell limit
   {
      if(tick.bid >= g_entryPrice) ExecuteSell();
   }
}

//============================================================
// EXECUTE TRADES
//============================================================
void ExecuteBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double slDist = ask - g_entrySL; if(slDist<=0) { ResetSetup(); return; }
   
   double riskPct = (g_injectionScore >= 75) ? InpRiskDefault : InpRiskReduced;
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * (riskPct/100.0);
   double lots = CalcLots(riskMoney, slDist);
   if(lots<=0) { ResetSetup(); return; }
   
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double sl=NormalizeDouble(g_entrySL,dg);
   double tp=NormalizeDouble(g_entryTP,dg);
   
   ResetLastError();
   bool sent = trade.Buy(lots, _Symbol, 0, sl, tp, "CK_LIR_BUY");
   if(!sent || trade.ResultRetcode()!=TRADE_RETCODE_DONE) { g_diagFails++; return; }
   
   // Verify position
   ulong posTicket = MyTicket();
   if(posTicket==0) { g_diagFails++; ResetSetup(); return; }
   if(!PositionSelectByTicket(posTicket)) { g_diagFails++; ResetSetup(); return; }
   
   g_posEntry = PositionGetDouble(POSITION_PRICE_OPEN);
   g_posOneR = g_posEntry - sl;
   g_posBarCount = 0;
   g_beMoved = false;
   g_tradesToday++;
   g_diagEntries++;
   
   // Correct TP from actual fill
   double actualRisk = g_posEntry - sl;
   if(actualRisk > 0)
   {
      double corrTP = PriceCeil(g_posEntry + (g_entryTP - g_entryPrice) + (g_posEntry - g_entryPrice));
      // Simplified: keep original TP as it was calculated from intended entry
   }
   
   if(InpVerboseLogs)
      PrintFormat("CK_LIR|FILLED_BUY|ticket=%I64u|lots=%.2f|fill=%.2f|sl=%.2f|tp=%.2f|score=%d",
         posTicket, lots, g_posEntry, sl, tp, g_injectionScore);
   
   ResetSetup();
}

void ExecuteSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDist = g_entrySL - bid; if(slDist<=0) { ResetSetup(); return; }
   
   double riskPct = (g_injectionScore >= 75) ? InpRiskDefault : InpRiskReduced;
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * (riskPct/100.0);
   double lots = CalcLots(riskMoney, slDist);
   if(lots<=0) { ResetSetup(); return; }
   
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double sl=NormalizeDouble(g_entrySL,dg);
   double tp=NormalizeDouble(g_entryTP,dg);
   
   ResetLastError();
   bool sent = trade.Sell(lots, _Symbol, 0, sl, tp, "CK_LIR_SELL");
   if(!sent || trade.ResultRetcode()!=TRADE_RETCODE_DONE) { g_diagFails++; return; }
   
   ulong posTicket = MyTicket();
   if(posTicket==0) { g_diagFails++; ResetSetup(); return; }
   if(!PositionSelectByTicket(posTicket)) { g_diagFails++; ResetSetup(); return; }
   
   g_posEntry = PositionGetDouble(POSITION_PRICE_OPEN);
   g_posOneR = sl - g_posEntry;
   g_posBarCount = 0;
   g_beMoved = false;
   g_tradesToday++;
   g_diagEntries++;
   
   if(InpVerboseLogs)
      PrintFormat("CK_LIR|FILLED_SELL|ticket=%I64u|lots=%.2f|fill=%.2f|sl=%.2f|tp=%.2f|score=%d",
         posTicket, lots, g_posEntry, sl, tp, g_injectionScore);
   
   ResetSetup();
}

//============================================================
// POSITION MANAGEMENT
//============================================================
void ManagePosition()
{
   ulong tk = MyTicket(); if(tk==0) return;
   if(!PositionSelectByTicket(tk)) return;
   
   long posType = PositionGetInteger(POSITION_TYPE);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick)) return;
   
   g_posBarCount++;
   
   // Failure exit check
   if(g_posBarCount >= InpFailExitBars && !g_beMoved)
   {
      double progress = 0;
      if(posType==POSITION_TYPE_BUY) progress = (tick.bid - open) / MathMax(g_posOneR, 0.01);
      else progress = (open - tick.ask) / MathMax(g_posOneR, 0.01);
      
      if(progress < InpFailExitThreshold)
      {
         // Failed injection - close
         trade.PositionClose(tk);
         if(InpVerboseLogs) PrintFormat("CK_LIR|FAIL_EXIT|progress=%.2fR", progress);
         return;
      }
   }
   
   // Break-even management (candle close above 1R, not just wick)
   if(!g_beMoved && g_posOneR > 0)
   {
      MqlRates lastBar[]; ArraySetAsSeries(lastBar,true);
      if(CopyRates(_Symbol,PERIOD_M5,1,1,lastBar)==1)
      {
         bool beCondition = false;
         if(posType==POSITION_TYPE_BUY && lastBar[0].close >= open + (InpBEActivateR * g_posOneR))
            beCondition = true;
         if(posType==POSITION_TYPE_SELL && lastBar[0].close <= open - (InpBEActivateR * g_posOneR))
            beCondition = true;
         
         if(beCondition)
         {
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double bePrice = 0;
            
            if(posType==POSITION_TYPE_BUY)
               bePrice = PriceFloor(open + InpBEOffsetPoints*point);
            else
               bePrice = PriceCeil(open - InpBEOffsetPoints*point);
            
            // Validate
            double modDist = MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*point;
            
            bool valid = false;
            if(posType==POSITION_TYPE_BUY && bePrice<tick.bid && (tick.bid-bePrice)>=modDist && bePrice>curSL)
               valid = true;
            if(posType==POSITION_TYPE_SELL && bePrice>tick.ask && (bePrice-tick.ask)>=modDist && bePrice<curSL)
               valid = true;
            
            if(valid)
            {
               if(trade.PositionModify(tk, bePrice, tp))
               {
                  g_beMoved = true;
                  if(InpVerboseLogs) PrintFormat("CK_LIR|BE_MOVED|new_sl=%.2f", bePrice);
               }
            }
         }
      }
   }
}

//============================================================
// RESET
//============================================================
void ResetSetup()
{
   g_phase = PHASE_IDLE;
   g_setupDir = 0;
   g_sweepLevel = 0;
   g_sweepExtreme = 0;
   g_entryPrice = 0;
   g_entrySL = 0;
   g_entryTP = 0;
   g_phaseBarCount = 0;
   g_injectionScore = 0;
   g_setupBarTime = 0;
}

//============================================================
// MAIN TICK
//============================================================
void OnTick()
{
   datetime ds = iTime(_Symbol, PERIOD_D1, 0);
   if(ds>0 && ds!=g_dayStart)
   {
      ResetDaily();
      BuildLiquidityMap();
   }
   
   // Manage existing position
   ManagePosition();
   
   // Check pending entry on every tick
   if(g_phase == PHASE_PENDING && !HasPosition())
      CheckPendingEntry();
   
   if(!IsNewBar()) return;
   
   // Rebuild liquidity map every 12 bars (1 hour)
   static int mapCounter = 0;
   mapCounter++;
   if(mapCounter >= 12) { BuildLiquidityMap(); mapCounter = 0; }
   
   // Setup logic on new bar
   if(!HasPosition())
   {
      if(g_phase == PHASE_IDLE)
         CheckForSweep();
      else if(g_phase == PHASE_SWEPT)
         CheckConfirmation();
   }
}
//+------------------------------------------------------------------+

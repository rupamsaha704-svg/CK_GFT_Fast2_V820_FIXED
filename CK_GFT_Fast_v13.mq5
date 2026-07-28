//+------------------------------------------------------------------+
//|                                             CK_GFT_Fast_v13.mq5  |
//|  Base: v10 — Fixed with real trade-by-trade data                  |
//|                                                                    |
//|  Fix #1: Whitelist UTC 02:00-03:59 ONLY (real edge both periods)  |
//|  Fix #2: RR 2.5 → 2.0 (avg win $216→$100, TP not reaching)       |
//|  Fix #3: Monday 0.5x risk (forward -$144, 27% WR)                |
//|  Fix #4: Full Friday skip (backtest -$391, not just cutoff)       |
//|  Fix #5: TP calculated from actual Ask, not from trigger          |
//|  Fix #6: Force close positions when outside allowed window        |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast v13"
#property version   "13.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE (unchanged) ===
input long   InpMagic            = 20260715;
input double InpRiskPercent      = 0.35;
input double InpRR               = 2.0;       // FIX #2: was 2.5 — TP not reaching in forward
input bool   InpBreakEvenAt1R    = true;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 1.0;
input double InpDailyProfitStopR = 3.0;
input int    InpMaxSpreadPoints  = 50;
input bool   InpUseTrend         = true;
input int    InpEMAPeriod        = 21;
input int    InpEMASlow          = 50;
input int    InpKneeMinRun       = 2;
input int    InpValidBars        = 5;
input double InpSLBufferATR      = 0.3;
input double InpMaxLot           = 0.08;

//=== TIME FILTER — WHITELIST (FIX #1) ===
input int    InpGMTOffset        = 3;     // MetaQuotes Demo = 3
input int    InpAllowStartUTC    = 2;     // Allow from UTC 02:00
input int    InpAllowEndUTC      = 4;     // Allow until UTC 03:59 (exclusive = 4)
// Result: ONLY 02:xx and 03:xx UTC — confirmed edge in both backtest and forward

//=== WEEKDAY FILTERS (FIX #4) ===
input bool   InpSkipMonday       = false; // Keep Monday, but use 0.5x risk
input bool   InpSkipThursday     = true;  // 21% WR
input bool   InpSkipFriday       = true;  // FIX #4: full skip (was cutoff) — BT -$391

//=== MONDAY RISK MULTIPLIER (FIX #3) ===
input double InpMondayRiskMult   = 0.5;   // Forward Monday 27% WR, -$144 → half risk

//=== FORCE CLOSE OUTSIDE WINDOW (FIX #6) ===
input bool   InpForceCloseOutside = true; // Close open positions outside allowed window

//=== HANDLES ===
int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime  = 0;
datetime g_dayStart   = 0;
double   g_dayStartBal= 0.0;
double   g_oneR_money = 0.0;
int      g_tradesToday= 0;
int      g_dir        = 0;
double   g_trigger    = 0.0;
double   g_kneeLow    = 0.0;
double   g_kneeHigh   = 0.0;
double   g_pendingSL  = 0.0;
int      g_barsLeft   = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   atrHandle     = iATR(_Symbol, _Period, 14);
   emaFastHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, _Period, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE || emaFastHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle     != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//+------------------------------------------------------------------+
//| Indicator helpers                                                  |
//+------------------------------------------------------------------+
double ATR()
{
   double b[]; if(CopyBuffer(atrHandle,0,0,1,b)<=0) return(0); return(b[0]);
}
double EMAFast(int shift)
{
   double b[]; if(CopyBuffer(emaFastHandle,0,shift,1,b)<=0) return(0); return(b[0]);
}
double EMASlow(int shift)
{
   double b[]; if(CopyBuffer(emaSlowHandle,0,shift,1,b)<=0) return(0); return(b[0]);
}
bool IsNewBar()
{
   datetime t = iTime(_Symbol,_Period,0);
   if(t != lastBarTime){ lastBarTime=t; return(true); }
   return(false);
}
bool IsGreen(int s){ return(iClose(_Symbol,_Period,s) > iOpen(_Symbol,_Period,s)); }
bool IsRed(int s)  { return(iClose(_Symbol,_Period,s) < iOpen(_Symbol,_Period,s)); }

//+------------------------------------------------------------------+
//| Time helpers                                                       |
//+------------------------------------------------------------------+
int GetUTCHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int utc = dt.hour - InpGMTOffset;
   if(utc < 0)   utc += 24;
   if(utc >= 24) utc -= 24;
   return(utc);
}

int GetServerDayOfWeek()
{
   // Use server day directly — avoids midnight UTC boundary bugs
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return(dt.day_of_week);   // 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
}

//+------------------------------------------------------------------+
//| FIX #1: Whitelist time filter — ONLY UTC 02:00-03:59              |
//+------------------------------------------------------------------+
bool InAllowedWindow()
{
   int h = GetUTCHour();
   // Handles normal (non-overnight) range: 2 < 4, so simple check
   return(h >= InpAllowStartUTC && h < InpAllowEndUTC);
}

bool WeekdayAllowed()
{
   int d = GetServerDayOfWeek();
   if(d == 0 || d == 6)              return(false);   // Weekend
   if(d == 1 && InpSkipMonday)       return(false);
   if(d == 4 && InpSkipThursday)     return(false);
   if(d == 5 && InpSkipFriday)       return(false);
   return(true);
}

bool TimeFilterAllowsTrade()
{
   return(InAllowedWindow() && WeekdayAllowed());
}

//+------------------------------------------------------------------+
//| FIX #3: Monday risk multiplier                                    |
//+------------------------------------------------------------------+
double EffectiveRisk()
{
   int d = GetServerDayOfWeek();
   if(d == 1 && !InpSkipMonday)
      return(InpRiskPercent * InpMondayRiskMult);
   return(InpRiskPercent);
}

//+------------------------------------------------------------------+
//| Daily reset                                                        |
//+------------------------------------------------------------------+
void ResetDaily()
{
   g_dayStart    = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_oneR_money  = g_dayStartBal * (InpRiskPercent / 100.0);
   g_tradesToday = 0;
}

double RealizedRToday()
{
   if(g_oneR_money <= 0) return(0);
   return((AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal) / g_oneR_money);
}

void Disarm()
{
   g_dir=0; g_trigger=0; g_kneeLow=0; g_kneeHigh=0;
   g_barsLeft=0; g_pendingSL=0;
}

bool IsTrendBuy()
{
   return(EMAFast(1) > EMASlow(1) && iClose(_Symbol,_Period,1) > EMAFast(1));
}

//+------------------------------------------------------------------+
//| Try to arm a setup                                                 |
//+------------------------------------------------------------------+
void TryArmSetup()
{
   double atr = ATR();
   if(atr <= 0) return;
   double buf = InpSLBufferATR * atr;

   if(IsRed(1))
   {
      int run = 0;
      for(int i=2; i<=12; i++){ if(IsGreen(i)) run++; else break; }
      bool trendOK = (!InpUseTrend) || IsTrendBuy();
      if(run >= InpKneeMinRun && trendOK)
      {
         g_dir       = +1;
         g_kneeHigh  = iHigh(_Symbol, _Period, 1);
         g_kneeLow   = iLow(_Symbol,  _Period, 1);
         g_trigger   = g_kneeHigh;
         g_pendingSL = g_kneeLow - buf;
         g_barsLeft  = InpValidBars;
         // NOTE: TP is NOT stored here — calculated from actual Ask at entry (FIX #5)
      }
   }
}

//+------------------------------------------------------------------+
//| Lot sizing                                                         |
//+------------------------------------------------------------------+
double LotForRisk(double riskMoney, double slDist)
{
   if(slDist <= 0) return(0);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0) return(0);
   double lossPerLot = (slDist / ts) * tv;
   if(lossPerLot <= 0) return(0);
   double lots = riskMoney / lossPerLot;
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / st) * st;
   if(lots < mn) lots = mn;
   if(lots > InpMaxLot) lots = InpMaxLot;
   return(lots);
}

//+------------------------------------------------------------------+
//| Count my positions                                                 |
//+------------------------------------------------------------------+
int MyPositions()
{
   int c = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL)  == _Symbol) c++;
   }
   return(c);
}

//+------------------------------------------------------------------+
//| FIX #6: Close all my positions                                     |
//+------------------------------------------------------------------+
void CloseAll()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol) continue;
      trade.PositionClose(tk);
   }
}

//+------------------------------------------------------------------+
//| FIX #5: Open trade — TP from actual Ask, not from trigger         |
//+------------------------------------------------------------------+
void OpenTrade()
{
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl   = g_pendingSL;
   double oneR = ask - sl;
   if(oneR <= 0) return;

   // TP from ACTUAL entry, not from trigger — fixes avg win collapse
   double tp = ask + (InpRR * oneR);

   // FIX #3: Use effective risk (Monday = 0.5x)
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (EffectiveRisk() / 100.0);
   double lots = LotForRisk(riskMoney, oneR);
   if(lots <= 0) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, dg);
   tp = NormalizeDouble(tp, dg);

   if(trade.Buy(lots, _Symbol, 0, sl, tp))
      g_tradesToday++;
}

//+------------------------------------------------------------------+
//| Break-even management                                              |
//+------------------------------------------------------------------+
void ManageBE()
{
   if(!InpBreakEvenAt1R) return;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol) continue;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double slc  = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double be   = NormalizeDouble(open, dg);
      double oneR = open - slc;
      if(oneR > 0 && bid >= open + oneR && slc < be)
         trade.PositionModify(tk, be, tp);
   }
}

//+------------------------------------------------------------------+
//| Daily limits                                                       |
//+------------------------------------------------------------------+
bool TradingAllowed()
{
   double r = RealizedRToday();
   if(InpDailyProfitStopR > 0 && r >=  InpDailyProfitStopR) return(false);
   if(InpDailyLossStopR   > 0 && r <= -InpDailyLossStopR)   return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Daily reset
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart) ResetDaily();

   // Break-even check every tick
   ManageBE();

   // FIX #6: Force close if outside allowed window
   if(InpForceCloseOutside && !TimeFilterAllowsTrade() && MyPositions() > 0)
   {
      CloseAll();
      Disarm();
      return;
   }

   // New bar logic
   if(IsNewBar())
   {
      if(g_dir != 0)
      {
         g_barsLeft--;
         if(g_barsLeft <= 0) Disarm();
      }
      // Arm setup only inside allowed window
      if(g_dir == 0 && MyPositions() == 0 && TimeFilterAllowsTrade())
         TryArmSetup();
   }

   // Entry trigger check (every tick)
   if(g_dir != 0 && MyPositions() == 0)
   {
      if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      if(!TimeFilterAllowsTrade()){ Disarm(); return; }

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_dir > 0 && ask >= g_trigger)
      {
         OpenTrade();
         Disarm();
      }
   }
}
//+------------------------------------------------------------------+

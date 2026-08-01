//+------------------------------------------------------------------+
//|                                             CK_GFT_Fast_v14.mq5  |
//|  Base: v13 (all real-data fixes) + PARTIAL TAKE PROFIT           |
//|                                                                    |
//|  NEW in v14:                                                       |
//|   - At 25% of TP distance → close 25% of position                 |
//|   - At 60% of TP distance → close another 25% (total 50% closed)  |
//|   - Remaining 50% → runs to full TP (or BE if activated)          |
//|                                                                    |
//|  All v13 fixes retained:                                           |
//|   - Whitelist UTC 02:00-03:59                                     |
//|   - RR 2.0                                                         |
//|   - Monday 0.5x risk                                               |
//|   - Thursday + Friday skip                                         |
//|   - TP from actual Ask                                             |
//|   - Force close outside window                                     |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast v14"
#property version   "14.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE ===
input long   InpMagic            = 20260715;
input double InpRiskPercent      = 0.35;
input double InpRR               = 2.0;
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

//=== TIME FILTER — WHITELIST ===
input int    InpGMTOffset        = 3;
input int    InpAllowStartUTC    = 2;
input int    InpAllowEndUTC      = 4;

//=== WEEKDAY FILTERS ===
input bool   InpSkipMonday       = false;
input bool   InpSkipThursday     = true;
input bool   InpSkipFriday       = true;
input double InpMondayRiskMult   = 0.5;

//=== FORCE CLOSE ===
input bool   InpForceCloseOutside = true;

//=== PARTIAL TAKE PROFIT (NEW in v14) ===
input bool   InpUsePartialTP     = true;   // Enable partial profit booking
input double InpTP1Progress      = 0.25;   // Book 25% when price reaches 25% of TP distance
input double InpTP1CloseRatio    = 0.25;   // Close 25% of initial position at TP1
input double InpTP2Progress      = 0.60;   // Book another 25% when price reaches 60%
input double InpTP2CloseRatio    = 0.25;   // Close 25% of initial position at TP2

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

//=== PARTIAL TP STATE ===
ulong    g_activeTicket   = 0;    // Ticket of current position
double   g_initialLots    = 0.0;  // Initial lot size (for partial calculation)
int      g_partialsDone   = 0;    // 0=none, 1=TP1 done, 2=TP2 done

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
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return(dt.day_of_week);
}

bool InAllowedWindow()
{
   int h = GetUTCHour();
   return(h >= InpAllowStartUTC && h < InpAllowEndUTC);
}

bool WeekdayAllowed()
{
   int d = GetServerDayOfWeek();
   if(d == 0 || d == 6)          return(false);
   if(d == 1 && InpSkipMonday)   return(false);
   if(d == 4 && InpSkipThursday) return(false);
   if(d == 5 && InpSkipFriday)   return(false);
   return(true);
}

bool TimeFilterAllowsTrade()
{
   return(InAllowedWindow() && WeekdayAllowed());
}

double EffectiveRisk()
{
   int d = GetServerDayOfWeek();
   if(d == 1 && !InpSkipMonday)
      return(InpRiskPercent * InpMondayRiskMult);
   return(InpRiskPercent);
}

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

//=== Reset partial state when position closes ===
void ResetPartialState()
{
   g_activeTicket = 0;
   g_initialLots  = 0.0;
   g_partialsDone = 0;
}

bool IsTrendBuy()
{
   return(EMAFast(1) > EMASlow(1) && iClose(_Symbol,_Period,1) > EMAFast(1));
}

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
      }
   }
}

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

//=== Normalize volume for partial close ===
double NormalizePartialVolume(double vol)
{
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double normalized = MathFloor(vol / st) * st;
   if(normalized < mn) return(0);  // Cannot close less than min lot
   return(normalized);
}

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

ulong GetMyTicket()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL)  == _Symbol)
         return(tk);
   }
   return(0);
}

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
   ResetPartialState();
}

//+------------------------------------------------------------------+
void OpenTrade()
{
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl   = g_pendingSL;
   double oneR = ask - sl;
   if(oneR <= 0) return;

   double tp = ask + (InpRR * oneR);

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (EffectiveRisk() / 100.0);
   double lots = LotForRisk(riskMoney, oneR);
   if(lots <= 0) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, dg);
   tp = NormalizeDouble(tp, dg);

   if(trade.Buy(lots, _Symbol, 0, sl, tp))
   {
      g_tradesToday++;

      // NEW v14: Track initial lot for partial TP calculations
      g_initialLots  = lots;
      g_partialsDone = 0;
      g_activeTicket = trade.ResultDeal();  // May be 0 in tester, will re-fetch

      Print("BUY opened. Initial lots=", lots, " Entry=", ask, " SL=", sl, " TP=", tp);
   }
}

//+------------------------------------------------------------------+
//| NEW v14: Manage Partial Take Profits                              |
//+------------------------------------------------------------------+
void ManagePartialTP()
{
   if(!InpUsePartialTP) return;
   if(g_partialsDone >= 2) return;
   if(MyPositions() == 0)
   {
      ResetPartialState();
      return;
   }

   // Get current position
   ulong ticket = GetMyTicket();
   if(ticket == 0) return;

   if(!PositionSelectByTicket(ticket)) return;

   double open      = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp        = PositionGetDouble(POSITION_TP);
   double currentVol= PositionGetDouble(POSITION_VOLUME);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double totalDist = tp - open;
   if(totalDist <= 0) return;

   double progress = (bid - open) / totalDist;
   if(progress <= 0) return;

   // If g_initialLots is 0 (EA restarted mid-trade), initialize from current
   if(g_initialLots <= 0)
      g_initialLots = currentVol;

   // === TP1: 25% progress → close 25% of initial ===
   if(g_partialsDone == 0 && progress >= InpTP1Progress)
   {
      double volToClose = NormalizePartialVolume(g_initialLots * InpTP1CloseRatio);

      if(volToClose > 0 && currentVol > volToClose)
      {
         // Ensure remaining is >= min lot
         double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(currentVol - volToClose >= mn)
         {
            if(trade.PositionClosePartial(ticket, volToClose))
            {
               g_partialsDone = 1;
               Print(">>> TP1 hit at ", (int)(progress*100), "% — closed ", volToClose, " lots. Remaining: ", currentVol - volToClose);
            }
         }
         else
         {
            // Skip TP1, mark as done so we can try TP2
            g_partialsDone = 1;
            Print(">>> TP1 skipped: remaining would be below min lot");
         }
      }
      else
      {
         // Can't close useful amount (initial too small), skip
         g_partialsDone = 1;
         Print(">>> TP1 skipped: volume too small to partial close");
      }
   }

   // === TP2: 60% progress → close another 25% of initial ===
   if(g_partialsDone == 1 && progress >= InpTP2Progress)
   {
      double volToClose = NormalizePartialVolume(g_initialLots * InpTP2CloseRatio);

      if(volToClose > 0 && currentVol > volToClose)
      {
         double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(currentVol - volToClose >= mn)
         {
            if(trade.PositionClosePartial(ticket, volToClose))
            {
               g_partialsDone = 2;
               Print(">>> TP2 hit at ", (int)(progress*100), "% — closed ", volToClose, " lots. Remaining: ", currentVol - volToClose);
            }
         }
         else
         {
            g_partialsDone = 2;
            Print(">>> TP2 skipped: remaining would be below min lot");
         }
      }
      else
      {
         g_partialsDone = 2;
         Print(">>> TP2 skipped: volume too small");
      }
   }
}

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

bool TradingAllowed()
{
   double r = RealizedRToday();
   if(InpDailyProfitStopR > 0 && r >=  InpDailyProfitStopR) return(false);
   if(InpDailyLossStopR   > 0 && r <= -InpDailyLossStopR)   return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart) ResetDaily();

   ManageBE();
   ManagePartialTP();   // NEW v14

   // Clear partial state if no position exists
   if(MyPositions() == 0 && g_activeTicket != 0)
      ResetPartialState();

   // Force close outside window
   if(InpForceCloseOutside && !TimeFilterAllowsTrade() && MyPositions() > 0)
   {
      CloseAll();
      Disarm();
      return;
   }

   if(IsNewBar())
   {
      if(g_dir != 0){ g_barsLeft--; if(g_barsLeft <= 0) Disarm(); }
      if(g_dir == 0 && MyPositions() == 0 && TimeFilterAllowsTrade())
         TryArmSetup();
   }

   if(g_dir != 0 && MyPositions() == 0)
   {
      if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      if(!TimeFilterAllowsTrade()){ Disarm(); return; }
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_dir > 0 && ask >= g_trigger){ OpenTrade(); Disarm(); }
   }
}
//+------------------------------------------------------------------+

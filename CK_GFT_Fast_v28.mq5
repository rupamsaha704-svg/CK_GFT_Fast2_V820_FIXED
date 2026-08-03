//+------------------------------------------------------------------+
//|                                             CK_GFT_Fast_v22.mq5  |
//|  Base: v17 logic (Buy+Sell, RR3, partial TP, BE@65%)             |
//|  Defaults locked to user's OPTIMIZED inputs (screenshot)          |
//|                                                                    |
//|  Optimized values baked in as defaults:                            |
//|   InpRiskPercent    = 0.53                                        |
//|   InpRR             = 3.0                                         |
//|   InpDailyLossStopR = 0.9                                         |
//|   InpDailyProfitStopR=3.4                                         |
//|   InpEMAPeriod      = 17                                          |
//|   InpEMASlow        = 51                                          |
//|   InpValidBars      = 8                                           |
//|   InpSLBufferATR    = 0.29                                        |
//|   (rest same as v17)                                              |
//|                                                                    |
//|  Logic unchanged from v17:                                         |
//|   BUY:  Green run + Red knee + uptrend, break above knee high     |
//|   SELL: Red run + Green knee + downtrend, break below knee low    |
//|   Partial TP1 @10%, TP2 @60%, BE (to entry) @65%                 |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast v28"
#property version   "28.00"
//  v28 adds GFT prop-firm compliance guards:
//   - Min 2-min holding time before EA-initiated closes (no scalping flag)
//   - Daily equity drawdown safety stop (4%, under GFT 5% hard limit)
//   - Overall static loss floor hard stop (10% -> $4500 on $5k)
//   - Max loss per trade default lowered to 150 (safe margin vs $250 daily)
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE (defaults = user's optimized values) ===
input long   InpMagic            = 20260715;
input double InpRiskPercent      = 0.53;   // optimized
input double InpRR               = 3.0;
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 0.9;    // optimized
input double InpDailyProfitStopR = 3.4;    // optimized
input int    InpMaxSpreadPoints  = 50;
input bool   InpUseTrend         = true;
input int    InpEMAPeriod        = 17;     // optimized (was 21)
input int    InpEMASlow          = 51;     // optimized (was 50)
input int    InpKneeMinRun       = 2;
input int    InpValidBars        = 8;      // optimized (was 5)
input double InpSLBufferATR      = 0.29;   // optimized (was 0.3)
input double InpMaxLot           = 0.09;

//=== SELL SIDE ===
input bool   InpAllowBuy         = true;   // Enable buy trades
input bool   InpAllowSell        = true;   // Enable sell trades

//=== RISK MANAGEMENT (v23: TP1 only @10% default, TP2 removed) ===
input bool   InpUsePartialTP1    = false;  // v25: TP1 REMOVED (close ratio was 0.00)
input double InpTP1Progress      = 0.10;
input double InpTP1CloseRatio    = 0.0;    // 0.00 -> removed
input bool   InpUsePartialTP2    = true;   // v25: TP2 ACTIVE
input double InpTP2Progress      = 0.60;   // at 60% of TP distance
input double InpTP2CloseRatio    = 0.22;   // close 22%

input bool   InpUseBreakEven     = true;
input double InpBEProgress       = 0.65;

//=== MAX LOSS PER TRADE (v26 - ONLY new addition) ===
input double InpMaxLossPerTrade  = 150.0;  // Force-close a trade if its loss exceeds this ($). GFT-safe (was 230)

//=== GFT PROP-FIRM COMPLIANCE (v28) ===
input int    InpMinHoldSeconds   = 120;    // 2-min rule: EA won't close a trade before this many seconds
input bool   InpUseDailyDDStop   = true;   // Equity-based daily drawdown safety halt
input double InpDailyDDStopPct   = 4.0;    // Halt day if equity drops this % from day-start (GFT hard=5%)
input bool   InpUseOverallFloor  = true;   // Overall static loss floor hard stop
input double InpOverallFloorPct  = 10.0;   // GFT static max loss (%) from initial balance -> $4500 on $5k

//=== HANDLES / STATE ===
int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime  = 0;
datetime g_dayStart   = 0;
double   g_dayStartBal= 0.0;
double   g_oneR_money = 0.0;
int      g_tradesToday= 0;
int      g_dir        = 0;       // +1 = buy, -1 = sell
double   g_trigger    = 0.0;
double   g_kneeLow    = 0.0;
double   g_kneeHigh   = 0.0;
double   g_pendingSL  = 0.0;
double   g_pendingTP  = 0.0;
int      g_barsLeft   = 0;

//=== Trade state ===
ulong    g_activeTicket  = 0;
double   g_initialLots   = 0.0;
int      g_partialsDone  = 0;
bool     g_beActivated   = false;
bool     g_maxLossHitToday = false;   // v27: blocks trading for rest of day after max-loss hit
double   g_startBalance    = 0.0;     // v28: initial account balance (for overall floor)
bool     g_haltAll         = false;   // v28: permanent halt after overall floor breach
bool     g_dailyDDHit      = false;   // v28: daily equity DD safety halt (resets next day)

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   g_startBalance = AccountInfoDouble(ACCOUNT_BALANCE);   // v28: capture initial balance once
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

void ResetDaily()
{
   g_dayStart    = iTime(_Symbol,PERIOD_D1,0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_oneR_money  = g_dayStartBal * (InpRiskPercent/100.0);
   g_tradesToday = 0;
   g_maxLossHitToday = false;   // v27: reset each new day
   g_dailyDDHit  = false;       // v28: reset daily DD halt each new day
}

//+------------------------------------------------------------------+
//| v28: Position age in seconds (for 2-min hold rule)               |
//+------------------------------------------------------------------+
long PositionAgeSeconds(ulong tk)
{
   if(!PositionSelectByTicket(tk)) return(0);
   datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   return((long)(TimeCurrent() - opened));
}

double RealizedRToday()
{
   if(g_oneR_money<=0) return(0);
   return((AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal) / g_oneR_money);
}

void Disarm()
{
   g_dir=0; g_trigger=0; g_kneeLow=0; g_kneeHigh=0;
   g_barsLeft=0; g_pendingSL=0; g_pendingTP=0;
}

void ResetTradeState()
{
   g_activeTicket = 0;
   g_initialLots  = 0.0;
   g_partialsDone = 0;
   g_beActivated  = false;
}

//=== Trend checks ===
bool IsTrendBuy()
{
   return(EMAFast(1) > EMASlow(1) && iClose(_Symbol,_Period,1) > EMAFast(1));
}

bool IsTrendSell()
{
   return(EMAFast(1) < EMASlow(1) && iClose(_Symbol,_Period,1) < EMAFast(1));
}

//+------------------------------------------------------------------+
//| TryArmSetup — BUY + SELL (v17)                                     |
//+------------------------------------------------------------------+
void TryArmSetup()
{
   double atr = ATR();
   if(atr <= 0) return;
   double buf = InpSLBufferATR * atr;

   //=== BUY SETUP: Red knee after green run ===
   if(InpAllowBuy && IsRed(1))
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
         double oneR = g_trigger - g_pendingSL;
         g_pendingTP = g_trigger + (InpRR * oneR);
         g_barsLeft  = InpValidBars;
         return;
      }
   }

   //=== SELL SETUP: Green knee after red run (NEW v17) ===
   if(InpAllowSell && IsGreen(1))
   {
      int run = 0;
      for(int i=2; i<=12; i++){ if(IsRed(i)) run++; else break; }
      bool trendOK = (!InpUseTrend) || IsTrendSell();
      if(run >= InpKneeMinRun && trendOK)
      {
         g_dir       = -1;
         g_kneeHigh  = iHigh(_Symbol, _Period, 1);
         g_kneeLow   = iLow(_Symbol,  _Period, 1);
         g_trigger   = g_kneeLow;                 // Break below knee LOW
         g_pendingSL = g_kneeHigh + buf;          // SL above knee HIGH
         double oneR = g_pendingSL - g_trigger;
         g_pendingTP = g_trigger - (InpRR * oneR);
         g_barsLeft  = InpValidBars;
      }
   }
}

//=== Lot sizing ===
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

double NormalizePartialVolume(double vol)
{
   double st = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double n  = MathFloor(vol / st) * st;
   if(n < mn) return(0);
   return(n);
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

//+------------------------------------------------------------------+
//| OpenBuy / OpenSell (v17)                                           |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl   = g_pendingSL;
   double tp   = g_pendingTP;
   double oneR = ask - sl;
   if(oneR <= 0) return;

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent/100.0);
   double lots = LotForRisk(riskMoney, oneR);
   if(lots <= 0) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, dg);
   tp = NormalizeDouble(tp, dg);

   if(trade.Buy(lots, _Symbol, 0, sl, tp))
   {
      g_tradesToday++;
      g_initialLots  = lots;
      g_partialsDone = 0;
      g_beActivated  = false;
   }
}

void OpenSell()
{
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl   = g_pendingSL;
   double tp   = g_pendingTP;
   double oneR = sl - bid;
   if(oneR <= 0) return;

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent/100.0);
   double lots = LotForRisk(riskMoney, oneR);
   if(lots <= 0) return;

   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, dg);
   tp = NormalizeDouble(tp, dg);

   if(trade.Sell(lots, _Symbol, 0, sl, tp))
   {
      g_tradesToday++;
      g_initialLots  = lots;
      g_partialsDone = 0;
      g_beActivated  = false;
   }
}

//+------------------------------------------------------------------+
//| ManageTrade — Handles both BUY and SELL positions                 |
//+------------------------------------------------------------------+
void ManageTrade()
{
   if(MyPositions() == 0)
   {
      ResetTradeState();
      return;
   }

   ulong ticket = GetMyTicket();
   if(ticket == 0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double open       = PositionGetDouble(POSITION_PRICE_OPEN);
   double slc        = PositionGetDouble(POSITION_SL);
   double tp         = PositionGetDouble(POSITION_TP);
   double currentVol = PositionGetDouble(POSITION_VOLUME);
   long   type       = PositionGetInteger(POSITION_TYPE);
   int    dg         = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double progress = 0.0;
   double totalDist = 0.0;

   if(type == POSITION_TYPE_BUY)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      totalDist = tp - open;
      if(totalDist <= 0) return;
      progress = (bid - open) / totalDist;
   }
   else if(type == POSITION_TYPE_SELL)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      totalDist = open - tp;
      if(totalDist <= 0) return;
      progress = (open - ask) / totalDist;
   }
   else return;

   if(g_initialLots <= 0) g_initialLots = currentVol;

   double mnLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   // v28: 2-min rule — EA won't partial-close before min hold time
   bool holdOK = (PositionAgeSeconds(ticket) >= InpMinHoldSeconds);

   //=== TP1 at 10% progress (close 40%) ===
   if(holdOK && InpUsePartialTP1 && g_partialsDone == 0 && progress >= InpTP1Progress)
   {
      double volToClose = NormalizePartialVolume(g_initialLots * InpTP1CloseRatio);
      if(volToClose > 0 && currentVol > volToClose && (currentVol - volToClose) >= mnLot)
      {
         if(trade.PositionClosePartial(ticket, volToClose))
         {
            g_partialsDone = 1;
            Print(">>> TP1 @ ", (int)(progress*100), "% - closed ", volToClose);
         }
      }
      else
      {
         g_partialsDone = 1;
      }
   }

   //=== TP2 at 60% progress ===
   if(holdOK && InpUsePartialTP2 && g_partialsDone == 1 && progress >= InpTP2Progress)
   {
      double volToClose = NormalizePartialVolume(g_initialLots * InpTP2CloseRatio);
      if(volToClose > 0 && currentVol > volToClose && (currentVol - volToClose) >= mnLot)
      {
         if(trade.PositionClosePartial(ticket, volToClose))
         {
            g_partialsDone = 2;
            Print(">>> TP2 @ ", (int)(progress*100), "% - closed ", volToClose);
         }
      }
      else
      {
         g_partialsDone = 2;
      }
   }

   //=== BE at 65% progress ===
   if(InpUseBreakEven && !g_beActivated && progress >= InpBEProgress)
   {
      double be = NormalizeDouble(open, dg);

      if(type == POSITION_TYPE_BUY && slc < be)
      {
         if(trade.PositionModify(ticket, be, tp))
         {
            g_beActivated = true;
            Print(">>> BE (BUY) @ ", (int)(progress*100), "% - SL to ", be);
         }
      }
      else if(type == POSITION_TYPE_SELL && slc > be)
      {
         if(trade.PositionModify(ticket, be, tp))
         {
            g_beActivated = true;
            Print(">>> BE (SELL) @ ", (int)(progress*100), "% - SL to ", be);
         }
      }
      else
      {
         g_beActivated = true;
      }
   }
}

bool TradingAllowed()
{
   if(g_haltAll)         return(false);   // v28: overall floor breached, permanent halt
   if(g_dailyDDHit)      return(false);   // v28: daily equity DD halt for today
   if(g_maxLossHitToday) return(false);   // v27: no more trades today after max-loss hit
   double r = RealizedRToday();
   if(InpDailyProfitStopR > 0 && r >=  InpDailyProfitStopR) return(false);
   if(InpDailyLossStopR   > 0 && r <= -InpDailyLossStopR)   return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| v28: Overall static loss floor — hard stop, close all + halt EA  |
//+------------------------------------------------------------------+
bool OverallFloorGuard()
{
   if(!InpUseOverallFloor || g_startBalance <= 0) return(false);
   double floor  = g_startBalance * (1.0 - InpOverallFloorPct/100.0);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= floor)
   {
      if(MyPositions() > 0){ ulong tk=GetMyTicket(); if(tk>0) trade.PositionClose(tk); }
      ResetTradeState();
      g_haltAll = true;
      Print(">>> OVERALL FLOOR BREACHED: equity ", equity, " <= floor ", floor, " - EA HALTED");
      return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| v28: Daily equity drawdown safety halt (under GFT 5% hard limit) |
//+------------------------------------------------------------------+
bool DailyDDGuard()
{
   if(!InpUseDailyDDStop || g_dailyDDHit) return(g_dailyDDHit);
   double dayFloor = g_dayStartBal * (1.0 - InpDailyDDStopPct/100.0);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= dayFloor)
   {
      if(MyPositions() > 0){ ulong tk=GetMyTicket(); if(tk>0) trade.PositionClose(tk); }
      ResetTradeState();
      g_dailyDDHit = true;
      Print(">>> DAILY DD HALT: equity ", equity, " <= day floor ", dayFloor, " - stopped for today");
      return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| v26: Max loss per trade guard — force close if loss > InpMaxLoss  |
//+------------------------------------------------------------------+
bool MaxLossGuard()
{
   if(InpMaxLossPerTrade <= 0) return(false);
   if(MyPositions() == 0) return(false);
   ulong tk = GetMyTicket();
   if(tk == 0) return(false);
   if(!PositionSelectByTicket(tk)) return(false);
   double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   if(pl <= -InpMaxLossPerTrade)
   {
      // v28: respect 2-min hold before EA-initiated close (SL still protects if triggered)
      if(PositionAgeSeconds(tk) < InpMinHoldSeconds) return(false);
      trade.PositionClose(tk);
      ResetTradeState();
      g_maxLossHitToday = true;   // v27: stop trading for rest of the day
      Print(">>> MAX LOSS GUARD: closed trade at ", pl, " (cap ", InpMaxLossPerTrade, ") - trading stopped for today");
      return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart) ResetDaily();

   // v28: hard safety guards FIRST (overall floor, then daily DD)
   if(OverallFloorGuard()) return;
   if(DailyDDGuard())      return;

   // v26: check max-loss-per-trade
   if(MaxLossGuard()) return;

   ManageTrade();

   if(IsNewBar())
   {
      if(g_dir != 0){ g_barsLeft--; if(g_barsLeft <= 0) Disarm(); }
      if(g_dir == 0 && MyPositions() == 0) TryArmSetup();
   }

   if(g_dir != 0 && MyPositions() == 0)
   {
      if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(g_dir > 0 && ask >= g_trigger)     { OpenBuy();  Disarm(); }
      else if(g_dir < 0 && bid <= g_trigger){ OpenSell(); Disarm(); }
   }
}
//+------------------------------------------------------------------+

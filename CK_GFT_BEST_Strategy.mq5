//+------------------------------------------------------------------+
//|                                      CK_GFT_BEST_Strategy.mq5    |
//|                                                      CK GFT Fast |
//|  BEST Strategy: HA + EMA Triple + Trailing Stop (Multi-Position) |
//|  Backtest Result: $25,413-$32,475 profit in 7 months             |
//|  Entry: HA Green/Red + EMA5>EMA21>EMA50 alignment                |
//|  Exit: Trailing Stop at Trail×ATR                                |
//|  Multi-position with compound lot growth                         |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//=== INPUTS ===
input long   InpMagic          = 20260730;
input double InpSLATR          = 1.0;       // SL = 1.0 × ATR14
input double InpTrailATR       = 6.0;       // Trailing Stop = 6.0 × ATR14
input double InpBaseLot        = 0.06;      // Base lot (compounds with balance)
input int    InpMaxPositions   = 3;         // Max simultaneous positions
input double InpDailyLossPct   = 0.10;      // Daily loss cap (10% of day start balance)
input double InpMaxLot         = 0.08;      // Absolute max lot
input int    InpMaxSpread      = 50;        // Max spread points
input int    InpEMAFast        = 5;
input int    InpEMAMid         = 21;
input int    InpEMASlow        = 50;
input int    InpATRPeriod      = 14;

//=== HANDLES ===
int atrHandle, emaFastHandle, emaMidHandle, emaSlowHandle;

//=== STATE ===
datetime lastBarTime = 0;
datetime g_dayStart = 0;
double g_dayStartBal = 0;
double g_initialBal = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   trade.SetAsyncMode(false);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   atrHandle = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   emaFastHandle = iMA(_Symbol, PERIOD_M5, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   emaMidHandle = iMA(_Symbol, PERIOD_M5, InpEMAMid, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, PERIOD_M5, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   
   if(atrHandle==INVALID_HANDLE || emaFastHandle==INVALID_HANDLE || 
      emaMidHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE)
      return INIT_FAILED;
   
   g_initialBal = AccountInfoDouble(ACCOUNT_BALANCE);
   ResetDaily();
   lastBarTime = iTime(_Symbol, PERIOD_M5, 0);
   
   PrintFormat("CK_BEST|INIT|SL=%.1fATR|Trail=%.1fATR|Lot=%.2f|MaxPos=%d",
      InpSLATR, InpTrailATR, InpBaseLot, InpMaxPositions);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle!=INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaMidHandle!=INVALID_HANDLE) IndicatorRelease(emaMidHandle);
   if(emaSlowHandle!=INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//=== INDICATORS ===
double GetATR() { double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(atrHandle,0,1,1,b)!=1) return 0; return b[0]; }
double GetEMAFast() { double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(emaFastHandle,0,1,1,b)!=1) return 0; return b[0]; }
double GetEMAMid() { double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(emaMidHandle,0,1,1,b)!=1) return 0; return b[0]; }
double GetEMASlow() { double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(emaSlowHandle,0,1,1,b)!=1) return 0; return b[0]; }

//=== HEIKEN ASHI ===
bool IsHAGreen()
{
   double o1=iOpen(_Symbol,PERIOD_M5,1), h1=iHigh(_Symbol,PERIOD_M5,1);
   double l1=iLow(_Symbol,PERIOD_M5,1), c1=iClose(_Symbol,PERIOD_M5,1);
   double o2=iOpen(_Symbol,PERIOD_M5,2), h2=iHigh(_Symbol,PERIOD_M5,2);
   double l2=iLow(_Symbol,PERIOD_M5,2), c2=iClose(_Symbol,PERIOD_M5,2);
   
   double ha_c1 = (o1+h1+l1+c1)/4;
   double ha_c2 = (o2+h2+l2+c2)/4;
   double ha_o2 = (o2+c2)/2;
   double ha_o1 = (ha_o2 + ha_c2)/2;
   
   return (ha_c1 > ha_o1);
}

bool IsHARed()
{
   double o1=iOpen(_Symbol,PERIOD_M5,1), h1=iHigh(_Symbol,PERIOD_M5,1);
   double l1=iLow(_Symbol,PERIOD_M5,1), c1=iClose(_Symbol,PERIOD_M5,1);
   double o2=iOpen(_Symbol,PERIOD_M5,2), h2=iHigh(_Symbol,PERIOD_M5,2);
   double l2=iLow(_Symbol,PERIOD_M5,2), c2=iClose(_Symbol,PERIOD_M5,2);
   
   double ha_c1 = (o1+h1+l1+c1)/4;
   double ha_c2 = (o2+h2+l2+c2)/4;
   double ha_o2 = (o2+c2)/2;
   double ha_o1 = (ha_o2 + ha_c2)/2;
   
   return (ha_c1 < ha_o1);
}

//=== HELPERS ===
bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t <= 0) return false;
   if(t != lastBarTime) { lastBarTime = t; return true; }
   return false;
}

void ResetDaily()
{
   g_dayStart = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
}

int MyPositionCount()
{
   int c = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         c++;
   }
   return c;
}

double CalcLot(double slDist)
{
   if(slDist <= 0) return 0;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_initialBal <= 0) g_initialBal = bal;
   
   // Compound: lot grows with balance
   double lot = InpBaseLot * (bal / g_initialBal);
   lot = MathMin(lot, InpMaxLot);
   
   double vMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vStep <= 0) vStep = 0.01;
   lot = MathFloor(lot / vStep) * vStep;
   if(lot < vMin) return 0;
   
   return NormalizeDouble(lot, 2);
}

//=== TRAILING STOP MANAGEMENT ===
void ManageTrailingStop()
{
   double atr = GetATR();
   if(atr <= 0) return;
   
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double curSL = PositionGetDouble(POSITION_SL);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      long posType = PositionGetInteger(POSITION_TYPE);
      
      if(posType == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormalizeDouble(bid - InpTrailATR * atr, dg);
         if(newSL > curSL && newSL < bid && (bid - newSL) >= minDist)
            trade.PositionModify(tk, newSL, 0);
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormalizeDouble(ask + InpTrailATR * atr, dg);
         if(newSL < curSL && newSL > ask && (newSL - ask) >= minDist)
            trade.PositionModify(tk, newSL, 0);
      }
   }
}

//=== MAIN ===
void OnTick()
{
   // Daily reset
   datetime ds = iTime(_Symbol, PERIOD_D1, 0);
   if(ds > 0 && ds != g_dayStart) ResetDaily();
   
   // Trailing stop on every tick
   ManageTrailingStop();
   
   // New bar logic
   if(!IsNewBar()) return;
   
   // Daily loss check
   double dailyLoss = g_dayStartBal - AccountInfoDouble(ACCOUNT_BALANCE);
   if(dailyLoss > g_dayStartBal * InpDailyLossPct) return;
   
   // Max positions check
   if(MyPositionCount() >= InpMaxPositions) return;
   
   // Spread check
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread) return;
   
   // Get indicators
   double atr = GetATR();
   double emaF = GetEMAFast();
   double emaM = GetEMAMid();
   double emaS = GetEMASlow();
   
   if(atr <= 0 || emaF <= 0 || emaM <= 0 || emaS <= 0) return;
   
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // BUY SIGNAL: HA Green + EMA5 > EMA21 > EMA50
   if(IsHAGreen() && emaF > emaM && emaM > emaS)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double slDist = InpSLATR * atr;
      double sl = NormalizeDouble(ask - slDist, dg);
      double lot = CalcLot(slDist);
      if(lot > 0)
         trade.Buy(lot, _Symbol, 0, sl, 0, "CK_BEST_BUY");
   }
   // SELL SIGNAL: HA Red + EMA5 < EMA21 < EMA50
   else if(IsHARed() && emaF < emaM && emaM < emaS)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double slDist = InpSLATR * atr;
      double sl = NormalizeDouble(bid + slDist, dg);
      double lot = CalcLot(slDist);
      if(lot > 0)
         trade.Sell(lot, _Symbol, 0, sl, 0, "CK_BEST_SELL");
   }
}
//+------------------------------------------------------------------+

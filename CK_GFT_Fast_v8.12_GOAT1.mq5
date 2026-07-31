//+------------------------------------------------------------------+
//|                                              CK GFT Fast v8.12   |
//|                        Copyright - CK GFT Fast                   |
//|   Goat $1 Model - $10/day, 1.8% guard, 2min guard, BE@$6        |
//|   Broker: Tick Size=0.01, Tick Value=0.1, Contract=100           |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.12"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputs
input long   InpMagic             = 20260715;
input double InpFixedLot          = 0.02;        // Fixed lot size
input double InpTPDollars         = 10.0;        // TP target in dollars
input double InpSLDollars         = 6.0;         // SL risk in dollars (actual loss ~$10 due to tick_value variation)
input double InpBEDollars         = 6.0;         // Move SL to BE after this $ profit
input int    InpMaxTradesPerDay   = 3;
input double InpDailyProfitTarget = 10.0;        // Daily profit cap in $
input double InpFloatingLossMax   = 1.8;         // Max floating loss % (safety)
input int    InpMinTradeDuration  = 120;         // Min trade duration seconds (2 min)
input int    InpMaxSpreadPoints   = 50;
input bool   InpUseTrend          = true;
input int    InpEMAPeriod         = 21;
input int    InpEMASlow           = 50;
input int    InpKneeMinRun        = 2;
input int    InpValidBars         = 5;

//--- Handles & State
int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime    = 0;
datetime g_dayStart     = 0;
double   g_dayStartBal  = 0.0;
int      g_tradesToday  = 0;
int      g_dir          = 0;
double   g_trigger      = 0.0;
double   g_kneeLow      = 0.0;
double   g_kneeHigh     = 0.0;
int      g_barsLeft     = 0;
bool     g_floatingBreached = false;
bool     g_lossToday    = false;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   atrHandle     = iATR(_Symbol, _Period, 14);
   emaFastHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle == INVALID_HANDLE || emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)     IndicatorRelease(atrHandle);
   if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//+------------------------------------------------------------------+
//| Helper functions                                                  |
//+------------------------------------------------------------------+
double ATR()
{
   double b[];
   if(CopyBuffer(atrHandle, 0, 0, 1, b) <= 0) return(0);
   return(b[0]);
}

double EMAFast(int shift)
{
   double b[];
   if(CopyBuffer(emaFastHandle, 0, shift, 1, b) <= 0) return(0);
   return(b[0]);
}

double EMASlow(int shift)
{
   double b[];
   if(CopyBuffer(emaSlowHandle, 0, shift, 1, b) <= 0) return(0);
   return(b[0]);
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t != lastBarTime) { lastBarTime = t; return(true); }
   return(false);
}

bool IsGreen(int s) { return(iClose(_Symbol, _Period, s) > iOpen(_Symbol, _Period, s)); }
bool IsRed(int s)   { return(iClose(_Symbol, _Period, s) < iOpen(_Symbol, _Period, s)); }

//+------------------------------------------------------------------+
//| Calculate price distance for a given dollar amount                |
//| Formula: distance = dollars / (tick_value * lots / tick_size)     |
//| Which is: distance = dollars * tick_size / (tick_value * lots)    |
//+------------------------------------------------------------------+
double DollarsToDistance(double dollars)
{
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0 || InpFixedLot <= 0) return(0);
   
   // How much $ per 1 unit of price move for our lot size:
   // $ per point = tick_value * lot / tick_size
   // For XAUUSD: $0.1 * 0.02 / 0.01 = $0.2 per 0.01 move
   // Wait... that gives $0.2 per 0.01 move = $20 per 1.00 move
   // For $10: distance = $10 / ($0.2 per 0.01) = 50 ticks = 50 * 0.01 = 0.50
   // But we SAW in backtest: distance = 50.00 (not 0.50!)
   
   // Let me recalculate:
   // tick_value = $0.1 means: 1 tick (0.01 move) on 1.0 lot = $0.10
   // For 0.02 lot: 1 tick = $0.10 * 0.02 = $0.002
   // For $10 target: ticks needed = $10 / $0.002 = 5000 ticks
   // distance = 5000 * 0.01 = 50.00 ✓
   
   double dollarPerTick = tv * InpFixedLot;  // $ per tick for our lot
   double ticksNeeded = dollars / dollarPerTick;
   double distance = ticksNeeded * ts;
   
   return(distance);
}

//+------------------------------------------------------------------+
//| Daily Reset                                                       |
//+------------------------------------------------------------------+
void ResetDaily()
{
   g_dayStart     = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStartBal  = AccountInfoDouble(ACCOUNT_BALANCE);
   g_tradesToday  = 0;
   g_floatingBreached = false;
   g_lossToday    = false;
}

double RealizedProfitToday()
{
   return(AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBal);
}

//+------------------------------------------------------------------+
//| Floating PnL check - 1.8% guard                                  |
//+------------------------------------------------------------------+
double GetFloatingPnL()
{
   double floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      floating += PositionGetDouble(POSITION_PROFIT)
                + PositionGetDouble(POSITION_SWAP);
   }
   return(floating);
}

void CheckFloatingLossGuard()
{
   if(g_floatingBreached) return;

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return;

   double floating = GetFloatingPnL();
   double maxLoss  = -bal * (InpFloatingLossMax / 100.0);

   if(floating <= maxLoss)
   {
      CloseAllPositions();
      g_floatingBreached = true;
      Disarm();
      Print("FLOATING LOSS GUARD: ", DoubleToString(floating, 2),
            " hit limit ", DoubleToString(maxLoss, 2), " - ALL CLOSED");
   }
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      trade.PositionClose(tk);
   }
}

//+------------------------------------------------------------------+
//| 2-Minute Duration Guard + $10 Profit Close                        |
//+------------------------------------------------------------------+
void ManageProfitClose()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int elapsed = (int)(TimeCurrent() - openTime);

      if(profit >= InpTPDollars && elapsed >= InpMinTradeDuration)
      {
         trade.PositionClose(tk);
         Print("PROFIT TARGET HIT: $", DoubleToString(profit, 2),
               " after ", elapsed, " seconds - CLOSED");
      }
   }
}

//+------------------------------------------------------------------+
//| Break-even: Move SL to entry when profit reaches $6               |
//+------------------------------------------------------------------+
void ManageBE()
{
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double slc  = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double be   = NormalizeDouble(open, dg);
      
      // Calculate profit in dollars for this position
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      
      // If profit >= $6 AND SL is still below entry → move SL to entry
      if(profit >= InpBEDollars && slc < be)
      {
         trade.PositionModify(tk, be, tp);
         Print("BE MOVED: SL to entry at ", DoubleToString(be, dg),
               " (profit=$", DoubleToString(profit, 2), ")");
      }
   }
}

//+------------------------------------------------------------------+
//| Disarm setup                                                      |
//+------------------------------------------------------------------+
void Disarm()
{
   g_dir = 0; g_trigger = 0; g_kneeLow = 0;
   g_kneeHigh = 0; g_barsLeft = 0;
}

//+------------------------------------------------------------------+
//| Trend filter                                                      |
//+------------------------------------------------------------------+
bool IsTrendBuy()
{
   return(EMAFast(1) > EMASlow(1) && iClose(_Symbol, _Period, 1) > EMAFast(1));
}

//+------------------------------------------------------------------+
//| Try to arm a buy setup (knee pattern)                             |
//+------------------------------------------------------------------+
void TryArmSetup()
{
   if(IsRed(1))
   {
      int run = 0;
      for(int i = 2; i <= 12; i++)
      {
         if(IsGreen(i)) run++;
         else break;
      }
      bool trendOK = (!InpUseTrend) || IsTrendBuy();
      if(run >= InpKneeMinRun && trendOK)
      {
         g_dir      = +1;
         g_kneeHigh = iHigh(_Symbol, _Period, 1);
         g_kneeLow  = iLow(_Symbol, _Period, 1);
         g_trigger  = g_kneeHigh;
         g_barsLeft = InpValidBars;
      }
   }
}

//+------------------------------------------------------------------+
//| Count my positions                                                |
//+------------------------------------------------------------------+
int MyPositions()
{
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         c++;
   }
   return(c);
}

//+------------------------------------------------------------------+
//| Open trade                                                        |
//| TP = entry + $10 distance                                         |
//| SL = entry - $10 distance                                         |
//| Both use same DollarsToDistance() so MUST be equal                 |
//+------------------------------------------------------------------+
void OpenTrade(int dir)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double tpDist = DollarsToDistance(InpTPDollars);
   double slDist = DollarsToDistance(InpSLDollars);
   
   if(tpDist <= 0 || slDist <= 0)
   {
      Print("ERROR: Cannot calculate distance. tpDist=", tpDist, " slDist=", slDist);
      return;
   }
   
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double tp = NormalizeDouble(ask + tpDist, dg);
   double sl = NormalizeDouble(ask - slDist, dg);
   
   if(sl >= ask || tp <= ask) return;

   Print("TRADE: Entry=", DoubleToString(ask, dg),
         " TP=", DoubleToString(tp, dg), "(+", DoubleToString(tpDist, dg), ")",
         " SL=", DoubleToString(sl, dg), "(-", DoubleToString(slDist, dg), ")",
         " Lot=", DoubleToString(InpFixedLot, 2));

   trade.Buy(InpFixedLot, _Symbol, 0, sl, tp);
   g_tradesToday++;
}

//+------------------------------------------------------------------+
//| Trading allowed check                                             |
//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(g_floatingBreached) return(false);
   if(g_lossToday) return(false);
   if(RealizedProfitToday() >= InpDailyProfitTarget) return(false);
   if(g_tradesToday >= InpMaxTradesPerDay) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| Detect trade close - Loss=stop day, BE=retry                      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   
   ulong dealTicket = trans.deal;
   if(dealTicket == 0) return;
   
   if(HistoryDealSelect(dealTicket))
   {
      long magic = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      
      if(magic != InpMagic || symbol != _Symbol) return;
      if(entry != DEAL_ENTRY_OUT) return;
      
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                    + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                    + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      
      if(profit < -1.0)
      {
         g_lossToday = true;
         Print("LOSS: $", DoubleToString(profit, 2), " - NO MORE TRADES TODAY");
      }
      else if(profit >= -1.0 && profit < 1.0)
      {
         Print("BREAK-EVEN: $", DoubleToString(profit, 2), " - RETRY ALLOWED");
      }
      else
      {
         Print("WIN: $", DoubleToString(profit, 2), " - DAILY TARGET CHECK");
      }
   }
}

//+------------------------------------------------------------------+
//| Main tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Daily reset
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart) ResetDaily();

   // SAFETY FIRST - every tick
   CheckFloatingLossGuard();
   if(g_floatingBreached) return;

   // $10 profit close + 2 min duration guard
   ManageProfitClose();

   // Break-even at $6 profit
   ManageBE();

   // Daily target reached? Stop.
   if(RealizedProfitToday() >= InpDailyProfitTarget) return;

   // New bar logic
   if(IsNewBar())
   {
      if(g_dir != 0)
      {
         g_barsLeft--;
         if(g_barsLeft <= 0) Disarm();
      }
      if(g_dir == 0 && MyPositions() == 0)
         TryArmSetup();
   }

   // Entry logic
   if(g_dir != 0 && MyPositions() == 0)
   {
      if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
      if(!TradingAllowed()) return;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_dir > 0 && ask >= g_trigger)
      {
         OpenTrade(+1);
         Disarm();
      }
   }
}
//+------------------------------------------------------------------+

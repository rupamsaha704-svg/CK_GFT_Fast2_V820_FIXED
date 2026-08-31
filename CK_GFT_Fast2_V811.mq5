//+------------------------------------------------------------------+
//|                                         CK_GFT_Fast2_V811.mq5    |
//|                                                      CK GFT Fast |
//|  V8.11 — Defect-fixed release                                   |
//|  Fixes: Actual-fill TP, Min-volume reject, Friday filter,       |
//|         Completed-candle ATR, Trade-result safety, BE reporting  |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.11"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//============================================================
// INPUTS
//============================================================
input long   InpMagic                = 20260715;
input double InpRiskPercent          = 0.35;
input double InpRR                   = 2.5;

input bool   InpBreakEvenAt1R        = true;
input int    InpBreakEvenOffsetPoints= 0;      // FIX 6: Cost-adjusted BE offset

input int    InpMaxTradesPerDay      = 3;
input double InpDailyLossStopR       = 1.0;
input double InpDailyProfitStopR     = 3.0;

input int    InpMaxSpreadPoints      = 50;
input int    InpDeviationPoints      = 30;

input bool   InpUseTrend             = true;
input int    InpEMAPeriod            = 21;
input int    InpEMASlow              = 50;

input int    InpKneeMinRun           = 2;
input int    InpValidBars            = 5;
input double InpSLBufferATR          = 0.30;

input double InpMaxLot               = 0.08;

input bool   InpAllowFridayEntries   = false;  // FIX 3: Friday filter
input bool   InpDisableWeekendEntries= true;
input bool   InpRequireM5Chart       = true;
input bool   InpVerboseLogs          = true;

const double HARD_MAX_LOT = 0.08;

//============================================================
// DIAGNOSTICS (FIX 7)
//============================================================
int g_diagFridayBlock        = 0;
int g_diagVolumeBelowMin     = 0;
int g_diagTradeSendFail      = 0;
int g_diagRetcodeFail        = 0;
int g_diagPosNotFound        = 0;
int g_diagTPRecalcFail       = 0;
int g_diagTPBelowEntry       = 0;
int g_diagATRCopyFail        = 0;
int g_diagBEModifyFail       = 0;
int g_diagSuccessfulEntries  = 0;

//============================================================
// GLOBAL STATE
//============================================================
int atrHandle     = INVALID_HANDLE;
int emaFastHandle = INVALID_HANDLE;
int emaSlowHandle = INVALID_HANDLE;

datetime lastBarTime           = 0;
datetime g_dayStart            = 0;
datetime g_setupTime           = 0;
datetime g_lastTradedSetupTime = 0;

double g_dayStartBalance = 0.0;
double g_oneRMoney       = 0.0;
double g_trigger         = 0.0;
double g_pendingSL       = 0.0;

int g_tradesToday = 0;
int g_direction   = 0;
int g_barsLeft    = 0;

//============================================================
// LOGGING
//============================================================
void LogMsg(const string tag, const string text)
{
   if(InpVerboseLogs)
      PrintFormat("CK_V811|%s|%s", tag, text);
}

bool IsRetcodeSuccess()
{
   uint rc = trade.ResultRetcode();
   return (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL || rc==TRADE_RETCODE_PLACED || rc==TRADE_RETCODE_NO_CHANGES);
}

//============================================================
// PRICE HELPERS
//============================================================
double GetTickSize()
{
   double ts=0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,ts)||ts<=0)
      ts=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   return ts;
}

double PriceFloor(double price)
{
   double ts=GetTickSize(); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(ts<=0) return NormalizeDouble(price,dg);
   return NormalizeDouble(MathFloor((price/ts)+1e-10)*ts, dg);
}

double PriceCeil(double price)
{
   double ts=GetTickSize(); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(ts<=0) return NormalizeDouble(price,dg);
   return NormalizeDouble(MathCeil((price/ts)-1e-10)*ts, dg);
}

//============================================================
// FIX 2: VOLUME — NEVER force minimum upward
//============================================================
double CalcVolume(double riskMoney, double entryPrice, double stopPrice)
{
   if(riskMoney<=0||entryPrice<=stopPrice||stopPrice<=0) return 0;
   
   double oneLotLoss=0;
   bool calc=OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,1.0,entryPrice,stopPrice,oneLotLoss);
   double lossPerLot=(calc?MathAbs(oneLotLoss):0);
   
   if(!calc||lossPerLot<=0)
   {
      double tv=0,ts=0;
      if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,tv)||tv<=0)
         SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE,tv);
      SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,ts);
      if(tv<=0||ts<=0) return 0;
      lossPerLot=((entryPrice-stopPrice)/ts)*tv;
   }
   if(lossPerLot<=0) return 0;
   
   double rawLots = riskMoney/lossPerLot;
   
   double volMin=0,volMax=0,volStep=0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN,volMin)||
      !SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX,volMax)||
      !SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP,volStep)||
      volMin<=0||volMax<=0||volStep<=0) return 0;
   
   // Floor to step
   double lots = MathFloor(rawLots/volStep)*volStep;
   // Cap
   lots = MathMin(lots, MathMin(volMax, MathMin(InpMaxLot, HARD_MAX_LOT)));
   
   // FIX 2: REJECT if below minimum — NEVER force up
   if(lots < volMin - 1e-10)
   {
      g_diagVolumeBelowMin++;
      LogMsg("REJECT", StringFormat("volume_below_min|raw=%.6f|rounded=%.4f|min=%.4f|risk$=%.2f", rawLots, lots, volMin, riskMoney));
      return 0;
   }
   
   // Normalize
   int volDg=0;
   for(int d=0;d<=8;d++) if(MathAbs(NormalizeDouble(volStep,d)-volStep)<1e-12){volDg=d;break;}
   lots = NormalizeDouble(lots, volDg);
   
   LogMsg("RISK", StringFormat("budget=%.2f|loss1lot=%.2f|raw=%.6f|final=%.4f", riskMoney, lossPerLot, rawLots, lots));
   return lots;
}

//============================================================
// FIX 4: ATR from COMPLETED candle (shift 1)
//============================================================
double ATRCompleted()
{
   double b[];
   ArraySetAsSeries(b,true);
   if(CopyBuffer(atrHandle,0,1,1,b)!=1)
   {
      g_diagATRCopyFail++;
      return 0;
   }
   return b[0];
}

double EMAFast1()
{
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(emaFastHandle,0,1,1,b)!=1) return 0;
   return b[0];
}

double EMASlow1()
{
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(emaSlowHandle,0,1,1,b)!=1) return 0;
   return b[0];
}

//============================================================
// HELPERS
//============================================================
bool IsNewBar()
{
   datetime t=iTime(_Symbol,_Period,0);
   if(t<=0) return false;
   if(t!=lastBarTime){lastBarTime=t;return true;}
   return false;
}

void ResetDaily()
{
   datetime ds=iTime(_Symbol,PERIOD_D1,0);
   g_dayStart=(ds>0?ds:TimeCurrent());
   double pnl=0; int entries=0;
   if(HistorySelect(g_dayStart,TimeCurrent()))
   {
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong tk=HistoryDealGetTicket(i); if(tk==0) continue;
         pnl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_SWAP);
         if(HistoryDealGetString(tk,DEAL_SYMBOL)==_Symbol && HistoryDealGetInteger(tk,DEAL_MAGIC)==InpMagic)
         {
            ENUM_DEAL_ENTRY de=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk,DEAL_ENTRY);
            if(de==DEAL_ENTRY_IN||de==DEAL_ENTRY_INOUT) entries++;
         }
      }
   }
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartBalance=bal-pnl; if(g_dayStartBalance<=0) g_dayStartBalance=bal;
   g_oneRMoney=g_dayStartBalance*(InpRiskPercent/100.0);
   g_tradesToday=entries;
}

double RealizedR()
{
   if(g_oneRMoney<=0) return 0;
   return (AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBalance)/g_oneRMoney;
}

void Disarm(){g_direction=0;g_trigger=0;g_pendingSL=0;g_barsLeft=0;g_setupTime=0;}

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

//============================================================
// FIX 3: FRIDAY + WEEKEND FILTER
//============================================================
bool EntryDayAllowed()
{
   MqlDateTime dt={};
   TimeToStruct(TimeCurrent(),dt);
   if(InpDisableWeekendEntries && (dt.day_of_week==0||dt.day_of_week==6)) return false;
   if(!InpAllowFridayEntries && dt.day_of_week==5)
   {
      g_diagFridayBlock++;
      return false;
   }
   return true;
}

//============================================================
// TRADING ALLOWED
//============================================================
bool TradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED)||!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) return false;
   if(!EntryDayAllowed()) return false;
   double r=RealizedR();
   if(InpDailyProfitStopR>0 && r>=InpDailyProfitStopR) return false;
   if(InpDailyLossStopR>0 && r<=-InpDailyLossStopR) return false;
   if(g_tradesToday>=InpMaxTradesPerDay) return false;
   return true;
}

//============================================================
// TREND FILTER
//============================================================
bool TrendOK()
{
   if(!InpUseTrend) return true;
   double f=EMAFast1(), s=EMASlow1(); if(f==0||s==0) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,_Period,1,1,r)!=1) return false;
   return (f>s && r[0].close>f);
}

//============================================================
// SETUP ARM
//============================================================
void TryArm()
{
   double atr=ATRCompleted(); if(atr<=0) return;
   MqlRates rates[]; ArraySetAsSeries(rates,true);
   if(CopyRates(_Symbol,_Period,1,12,rates)!=12) return;
   
   MqlRates knee=rates[0];
   if(knee.time==g_lastTradedSetupTime) return;
   if(knee.close>=knee.open) return; // must be bearish
   
   int run=0;
   for(int i=1;i<12;i++){if(rates[i].close>rates[i].open)run++;else break;}
   if(run<InpKneeMinRun) return;
   if(!TrendOK()) return;
   
   double buf=InpSLBufferATR*atr;
   double trigger=PriceCeil(knee.high);
   double sl=PriceFloor(knee.low-buf);
   if(trigger<=sl) return;
   
   g_direction=1; g_trigger=trigger; g_pendingSL=sl; g_barsLeft=InpValidBars; g_setupTime=knee.time;
   LogMsg("SETUP", StringFormat("trigger=%.*f|sl=%.*f|run=%d|atr=%.2f", _Digits,trigger,_Digits,sl,run,atr));
}

//============================================================
// FIX 1 & 5: OPEN BUY — Actual fill TP + result safety
//============================================================
bool OpenBuy()
{
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick)||tick.ask<=0) return false;
   
   double sl=PriceFloor(g_pendingSL);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   
   // Conservative entry for lot calc (includes max slippage)
   double conservEntry=tick.ask+(InpDeviationPoints*point);
   double riskMoney=AccountInfoDouble(ACCOUNT_EQUITY)*(InpRiskPercent/100.0);
   double lots=CalcVolume(riskMoney, conservEntry, sl);
   if(lots<=0) return false;
   
   // Provisional TP (will be corrected after fill)
   double provRisk=tick.ask-sl; if(provRisk<=0) return false;
   double provTP=PriceCeil(tick.ask+(InpRR*provRisk));
   
   // Validate stops
   double minDist=MathMax(0.0,(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point);
   if((tick.bid-sl)<minDist||(provTP-tick.bid)<minDist) return false;
   
   // Send order
   ResetLastError();
   bool sent=trade.Buy(lots,_Symbol,0.0,sl,provTP,"CK_V811");
   
   if(!sent)
   {
      g_diagTradeSendFail++;
      LogMsg("FAIL","trade.Buy returned false");
      return false;
   }
   
   if(!IsRetcodeSuccess())
   {
      g_diagRetcodeFail++;
      LogMsg("FAIL",StringFormat("retcode=%u|%s",trade.ResultRetcode(),trade.ResultRetcodeDescription()));
      return false;
   }
   
   if(trade.ResultDeal()==0)
   {
      g_diagRetcodeFail++;
      return false;
   }
   
   // FIX 5: Confirm position exists
   ulong posTicket=MyTicket();
   if(posTicket==0)
   {
      g_diagPosNotFound++;
      LogMsg("FAIL","position_not_found_after_fill");
      return false;
   }
   
   // Get actual fill price
   if(!PositionSelectByTicket(posTicket)) { g_diagPosNotFound++; return false; }
   double actualFill=PositionGetDouble(POSITION_PRICE_OPEN);
   if(actualFill<=0) actualFill=trade.ResultPrice();
   if(actualFill<=sl) { trade.PositionClose(posTicket); return false; }
   
   // FIX 1: Correct TP from ACTUAL fill
   double actualRisk=actualFill-sl;
   double correctTP=PriceCeil(actualFill+(InpRR*actualRisk));
   
   // Validate corrected TP
   if(correctTP<=actualFill)
   {
      g_diagTPBelowEntry++;
      LogMsg("FAIL","corrected_TP_below_entry");
      trade.PositionClose(posTicket);
      return false;
   }
   
   // Check freeze/stops for modify
   double modDist=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*point;
   MqlTick tick2={}; SymbolInfoTick(_Symbol,tick2);
   if((correctTP-tick2.bid)<modDist || (tick2.bid-sl)<modDist)
   {
      g_diagTPRecalcFail++;
      LogMsg("FAIL","TP_modify_distance_violation");
      trade.PositionClose(posTicket);
      return false;
   }
   
   // Modify with correct TP
   ResetLastError();
   bool mod=trade.PositionModify(posTicket, sl, correctTP);
   if(!mod||!IsRetcodeSuccess())
   {
      g_diagTPRecalcFail++;
      LogMsg("FAIL",StringFormat("TP_modify_failed|rc=%u",trade.ResultRetcode()));
      trade.PositionClose(posTicket);
      return false;
   }
   
   // FIX 5: Only count after confirmed success
   g_tradesToday++;
   g_diagSuccessfulEntries++;
   g_lastTradedSetupTime=g_setupTime;
   
   LogMsg("ENTRY",StringFormat("ticket=%I64u|lots=%.2f|fill=%.*f|sl=%.*f|tp=%.*f|risk=%.2f",
      posTicket,lots,_Digits,actualFill,_Digits,sl,_Digits,correctTP,actualRisk));
   
   return true;
}

//============================================================
// FIX 6: BREAK-EVEN with offset
//============================================================
void ManageBE()
{
   if(!InpBreakEvenAt1R) return;
   ulong tk=MyTicket(); if(tk==0) return;
   if(!PositionSelectByTicket(tk)) return;
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=POSITION_TYPE_BUY) return;
   
   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   if(open<=0||tp<=open||InpRR<=0) return;
   
   double initRisk=(tp-open)/InpRR;
   if(initRisk<=0) return;
   
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick)) return;
   if(tick.bid < open+initRisk) return; // Not yet 1R
   
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double beStop=PriceFloor(open+(InpBreakEvenOffsetPoints*point));
   
   if(curSL >= beStop-(GetTickSize()*0.5)) return; // Already at or above BE
   
   // Validate
   double modDist=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*point;
   if(beStop<=0||beStop>=tick.bid||(tick.bid-beStop)<modDist) return;
   
   ResetLastError();
   bool mod=trade.PositionModify(tk,beStop,tp);
   if(!mod||!IsRetcodeSuccess())
   {
      g_diagBEModifyFail++;
      return;
   }
   LogMsg("BE",StringFormat("ticket=%I64u|new_sl=%.*f",tk,_Digits,beStop));
}

//============================================================
// INIT / DEINIT
//============================================================
int OnInit()
{
   if(InpRequireM5Chart && _Period!=PERIOD_M5) return INIT_PARAMETERS_INCORRECT;
   if(InpRiskPercent<=0||InpRR<=0||InpMaxLot<=0||InpMaxLot>HARD_MAX_LOT||InpValidBars<=0||InpKneeMinRun<=0) return INIT_PARAMETERS_INCORRECT;
   
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetAsyncMode(false);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   atrHandle=iATR(_Symbol,_Period,14);
   emaFastHandle=iMA(_Symbol,_Period,InpEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   emaSlowHandle=iMA(_Symbol,_Period,InpEMASlow,0,MODE_EMA,PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE||emaFastHandle==INVALID_HANDLE||emaSlowHandle==INVALID_HANDLE) return INIT_FAILED;
   
   ResetDaily();
   lastBarTime=iTime(_Symbol,_Period,0);
   LogMsg("INIT",StringFormat("V8.11|risk=%.2f%%|RR=%.1f|lot=%.2f|friday=%s",InpRiskPercent,InpRR,InpMaxLot,(InpAllowFridayEntries?"ON":"OFF")));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle!=INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle!=INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
   
   // Print diagnostics
   PrintFormat("CK_V811|DIAG|entries=%d|friday_block=%d|vol_reject=%d|send_fail=%d|rc_fail=%d|pos_notfound=%d|tp_recalc_fail=%d|tp_below=%d|atr_fail=%d|be_fail=%d",
      g_diagSuccessfulEntries,g_diagFridayBlock,g_diagVolumeBelowMin,g_diagTradeSendFail,g_diagRetcodeFail,g_diagPosNotFound,g_diagTPRecalcFail,g_diagTPBelowEntry,g_diagATRCopyFail,g_diagBEModifyFail);
}

//============================================================
// MAIN TICK
//============================================================
void OnTick()
{
   datetime ds=iTime(_Symbol,PERIOD_D1,0);
   if(ds>0 && ds!=g_dayStart) ResetDaily();
   
   ManageBE();
   
   if(IsNewBar())
   {
      if(g_direction!=0)
      {
         g_barsLeft--;
         if(g_barsLeft<=0) Disarm();
      }
      if(g_direction==0 && !HasPosition())
         TryArm();
   }
   
   // Trigger check
   if(g_direction==0 || HasPosition()) return;
   
   long spread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spread<0||spread>InpMaxSpreadPoints) return;
   if(!TradingAllowed()) return;
   
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick)) return;
   
   if(g_direction>0 && tick.ask>=g_trigger)
   {
      // FIX 5: Only disarm on success or permanent failure
      bool opened=OpenBuy();
      if(opened)
         Disarm();
      else
      {
         // Check if it's a permanent rejection (not transient)
         uint rc=trade.ResultRetcode();
         if(rc==TRADE_RETCODE_INVALID_STOPS||rc==TRADE_RETCODE_INVALID_VOLUME||rc==TRADE_RETCODE_NO_MONEY)
            Disarm(); // Permanent — don't retry
         // Otherwise keep armed for next tick (transient failure)
      }
   }
}
//+------------------------------------------------------------------+

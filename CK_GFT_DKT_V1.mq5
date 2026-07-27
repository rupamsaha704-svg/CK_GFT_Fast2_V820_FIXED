//+------------------------------------------------------------------+
//|                                             CK_GFT_DKT_V1.mq5   |
//|                                                      CK GFT Fast |
//|  DKT Operator Strategy V1.0                                      |
//|  Based on: PDH/PDL/Asia Liquidity Zones + H-A-R-I Model         |
//|  Combined with V20 Knee Breakout (proven $4,456 base)            |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//============================================================
// INPUTS
//============================================================
input long   InpMagic              = 20260729;
input double InpRiskPercent        = 0.70;
input double InpRR                 = 2.5;       // DKT: Min 1:2, aim 1:3 — trying 2.5
input bool   InpBreakEvenAt1R     = true;
input int    InpMaxTradesPerDay    = 2;         // DKT: Max 2 trades/day
input double InpDailyLossStopR     = 1.5;
input double InpDailyProfitStopR   = 5.0;
input int    InpMaxSpreadPoints    = 50;
input int    InpDeviationPoints    = 30;
input double InpMaxLot             = 0.08;

// DKT SESSION TIMING (UTC for MT5 server — adjust if needed)
// IST = UTC + 5:30. DKT times converted:
// Asia: 5:30 AM IST = 00:00 UTC, 6:30 AM IST = 01:00 UTC
// London: 2:15 PM IST = 08:45 UTC, PreNY 5:30 PM IST = 12:00 UTC
// NY: 6:33 PM IST = 13:03 UTC, 9:45 PM IST = 16:15 UTC
input int    InpServerUTCOffset    = 0;         // Server time offset from UTC (0 for most)
input bool   InpUseSessionFilter   = true;
input bool   InpThursdayLondonOff  = true;      // DKT: Thursday London = NO TRADE
input bool   InpFridayTightRisk    = true;      // DKT: Friday tight, close before end
input bool   InpAllowFriday        = true;      // Allow Friday but tight

// KNEE BREAKOUT (from V20 — proven)
input bool   InpUseKnee            = true;
input int    InpEMAPeriod          = 21;
input int    InpEMASlow            = 50;
input int    InpKneeMinRunBuy      = 2;
input double InpMinBodyRatioBuy    = 0.60;
input int    InpKneeMinRunSell     = 3;
input double InpMinBodyRatioSell   = 0.70;
input int    InpValidBars          = 5;
input double InpSLBufferATR        = 0.3;
input double InpMinSLPoints        = 5.0;

// LIQUIDITY ZONE FILTER (DKT concept)
input bool   InpUseLiqFilter       = true;      // Only trade near PDH/PDL/Asia zones
input double InpLiqZoneATR         = 1.5;       // Price must be within 1.5 ATR of a zone

const double HARD_MAX_LOT = 0.08;

//============================================================
// GLOBALS
//============================================================
int atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime=0, g_dayStart=0;
double g_dayStartBal=0, g_oneRMoney=0;
int g_tradesToday=0;

// Setup state
int g_dir=0;
double g_trigger=0, g_pendingSL=0, g_pendingTP=0, g_oneR=0;
int g_barsLeft=0;

// Liquidity levels
double g_pdh=0, g_pdl=0, g_asiaH=0, g_asiaL=0, g_pwh=0, g_pwl=0;

//============================================================
// INIT / DEINIT
//============================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetAsyncMode(false);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   atrHandle=iATR(_Symbol,PERIOD_M5,14);
   emaFastHandle=iMA(_Symbol,PERIOD_M5,InpEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   emaSlowHandle=iMA(_Symbol,PERIOD_M5,InpEMASlow,0,MODE_EMA,PRICE_CLOSE);
   
   if(atrHandle==INVALID_HANDLE||emaFastHandle==INVALID_HANDLE||emaSlowHandle==INVALID_HANDLE)
      return INIT_FAILED;
   
   ResetDaily();
   BuildLevels();
   lastBarTime=iTime(_Symbol,PERIOD_M5,0);
   
   PrintFormat("CK_DKT|INIT|V1.0|RR=%.1f|max_trades=%d|lot=%.2f",InpRR,InpMaxTradesPerDay,InpMaxLot);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle!=INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle!=INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//============================================================
// INDICATORS
//============================================================
double ATR14(){double b[];ArraySetAsSeries(b,true);if(CopyBuffer(atrHandle,0,1,1,b)!=1)return 0;return b[0];}
double EMAFast(int s){double b[];ArraySetAsSeries(b,true);if(CopyBuffer(emaFastHandle,0,s,1,b)!=1)return 0;return b[0];}
double EMASlow(int s){double b[];ArraySetAsSeries(b,true);if(CopyBuffer(emaSlowHandle,0,s,1,b)!=1)return 0;return b[0];}

//============================================================
// HELPERS
//============================================================
bool IsNewBar(){datetime t=iTime(_Symbol,PERIOD_M5,0);if(t<=0)return false;if(t!=lastBarTime){lastBarTime=t;return true;}return false;}
bool IsGreen(int s){return iClose(_Symbol,PERIOD_M5,s)>iOpen(_Symbol,PERIOD_M5,s);}
bool IsRed(int s){return iClose(_Symbol,PERIOD_M5,s)<iOpen(_Symbol,PERIOD_M5,s);}

void ResetDaily()
{
   datetime ds=iTime(_Symbol,PERIOD_D1,0);
   g_dayStart=(ds>0?ds:TimeCurrent());
   double pnl=0;int entries=0;
   if(HistorySelect(g_dayStart,TimeCurrent()))
   {
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong tk=HistoryDealGetTicket(i);if(tk==0)continue;
         pnl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_SWAP);
         if(HistoryDealGetString(tk,DEAL_SYMBOL)==_Symbol&&HistoryDealGetInteger(tk,DEAL_MAGIC)==InpMagic)
         {
            ENUM_DEAL_ENTRY de=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk,DEAL_ENTRY);
            if(de==DEAL_ENTRY_IN||de==DEAL_ENTRY_INOUT) entries++;
         }
      }
   }
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartBal=bal-pnl;if(g_dayStartBal<=0)g_dayStartBal=bal;
   g_oneRMoney=g_dayStartBal*(InpRiskPercent/100.0);
   g_tradesToday=entries;
}

double RealizedR(){if(g_oneRMoney<=0)return 0;return(AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneRMoney;}
void Disarm(){g_dir=0;g_trigger=0;g_pendingSL=0;g_pendingTP=0;g_barsLeft=0;g_oneR=0;}

ulong MyTicket()
{
   for(int i=PositionsTotal()-1;i>=0;i--){ulong tk=PositionGetTicket(i);if(tk==0)continue;if(PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==InpMagic)return tk;}
   return 0;
}
bool HasPos(){return MyTicket()!=0;}

double CalcLots(double riskMoney,double slDist)
{
   if(riskMoney<=0||slDist<=0)return 0;
   double tv=0,ts=0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS,tv)||tv<=0)SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE,tv);
   SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,ts);
   if(tv<=0||ts<=0)return 0;
   double lossPerLot=(slDist/ts)*tv;if(lossPerLot<=0)return 0;
   double raw=riskMoney/lossPerLot;
   double vMin=0,vMax=0,vStep=0;
   SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN,vMin);SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX,vMax);SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP,vStep);
   if(vMin<=0||vMax<=0||vStep<=0)return 0;
   double lots=MathFloor(raw/vStep)*vStep;
   lots=MathMin(lots,MathMin(vMax,MathMin(InpMaxLot,HARD_MAX_LOT)));
   if(lots<vMin)return 0;
   int vd=2;for(int d=0;d<=8;d++)if(MathAbs(NormalizeDouble(vStep,d)-vStep)<1e-12){vd=d;break;}
   return NormalizeDouble(lots,vd);
}

//============================================================
// DKT SESSION FILTER
//============================================================
bool SessionAllowed()
{
   if(!InpUseSessionFilter) return true;
   
   MqlDateTime dt={};
   TimeToStruct(TimeCurrent(),dt);
   int hour=dt.hour;
   int minute=dt.min;
   int dow=dt.day_of_week; // 0=Sun,1=Mon...5=Fri,6=Sat
   
   // Weekend
   if(dow==0||dow==6) return false;
   
   // Thursday London session OFF (DKT rule)
   if(InpThursdayLondonOff && dow==4 && hour>=8 && hour<13) return false;
   
   // Friday tight risk (allow but fewer trades)
   // Close before 17:45 UTC (11:15 PM IST)
   if(dow==5 && hour>=17) return false;
   
   // DKT Algorithm windows (UTC times):
   // Asia: 00:00-01:00
   // London: 08:45-12:00
   // NY: 13:00-16:15
   
   bool inAsia = (hour==0);
   bool inLondon = (hour>=8 && hour<12) || (hour==12 && minute==0);
   bool inPreNY = (hour==12);
   bool inNY = (hour>=13 && hour<17);
   
   // Allow all these windows
   return (inAsia || inLondon || inPreNY || inNY);
}

//============================================================
// DKT LIQUIDITY LEVELS
//============================================================
void BuildLevels()
{
   g_pdh=iHigh(_Symbol,PERIOD_D1,1);
   g_pdl=iLow(_Symbol,PERIOD_D1,1);
   g_pwh=iHigh(_Symbol,PERIOD_W1,1);
   g_pwl=iLow(_Symbol,PERIOD_W1,1);
   
   // Asia session H/L (first 8 hours of day)
   datetime dayStart=iTime(_Symbol,PERIOD_D1,0);
   if(dayStart>0)
   {
      MqlRates r[];ArraySetAsSeries(r,false);
      int copied=CopyRates(_Symbol,PERIOD_M5,dayStart,96,r); // 8 hours × 12
      if(copied>0)
      {
         g_asiaH=0;g_asiaL=999999;
         for(int i=0;i<MathMin(copied,96);i++)
         {
            if(r[i].high>g_asiaH)g_asiaH=r[i].high;
            if(r[i].low<g_asiaL)g_asiaL=r[i].low;
         }
         if(g_asiaL>900000)g_asiaL=0;
      }
   }
}

// DKT: Price must be near a key liquidity zone to trade
bool NearLiquidityZone()
{
   if(!InpUseLiqFilter) return true;
   
   double atr=ATR14();if(atr<=0)return true;
   double price=iClose(_Symbol,PERIOD_M5,1);
   double threshold=InpLiqZoneATR*atr;
   
   if(g_pdh>0 && MathAbs(price-g_pdh)<threshold) return true;
   if(g_pdl>0 && MathAbs(price-g_pdl)<threshold) return true;
   if(g_asiaH>0 && MathAbs(price-g_asiaH)<threshold) return true;
   if(g_asiaL>0 && MathAbs(price-g_asiaL)<threshold) return true;
   if(g_pwh>0 && MathAbs(price-g_pwh)<threshold) return true;
   if(g_pwl>0 && MathAbs(price-g_pwl)<threshold) return true;
   
   return false;
}

//============================================================
// TRADING ALLOWED
//============================================================
bool TradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)||!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   if(!SessionAllowed()) return false;
   double r=RealizedR();
   if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR) return false;
   if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR) return false;
   if(g_tradesToday>=InpMaxTradesPerDay) return false;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return false;
   return true;
}

//============================================================
// TREND FILTER (V20 proven)
//============================================================
bool TrendBuy(){return(EMAFast(1)>EMASlow(1)&&iClose(_Symbol,PERIOD_M5,1)>EMAFast(1));}
bool TrendSell(){return(EMAFast(1)<EMASlow(1)&&iClose(_Symbol,PERIOD_M5,1)<EMAFast(1));}

bool StrongCandle(int shift,double minRatio)
{
   double o=iOpen(_Symbol,PERIOD_M5,shift),c=iClose(_Symbol,PERIOD_M5,shift);
   double h=iHigh(_Symbol,PERIOD_M5,shift),l=iLow(_Symbol,PERIOD_M5,shift);
   double range=h-l;if(range<=0)return false;
   return(MathAbs(c-o)/range>=minRatio);
}

//============================================================
// SETUP ARM (V20 Knee + DKT Liquidity Filter)
//============================================================
void TryArm()
{
   if(!InpUseKnee) return;
   double atr=ATR14();if(atr<=0)return;
   double buf=InpSLBufferATR*atr;
   
   // DKT: Only trade near key liquidity zones
   if(!NearLiquidityZone()) return;
   
   MqlRates rates[];ArraySetAsSeries(rates,true);
   if(CopyRates(_Symbol,PERIOD_M5,1,12,rates)!=12) return;
   
   // BUY SETUP
   if(IsRed(1))
   {
      int run=0;for(int i=2;i<=12;i++){if(IsGreen(i))run++;else break;}
      if(run>=InpKneeMinRunBuy && TrendBuy() && StrongCandle(2,InpMinBodyRatioBuy))
      {
         g_dir=+1;
         double kneeHigh=iHigh(_Symbol,PERIOD_M5,1);
         double kneeLow=iLow(_Symbol,PERIOD_M5,1);
         g_trigger=kneeHigh;
         g_pendingSL=kneeLow-buf;
         g_oneR=g_trigger-g_pendingSL;
         if(g_oneR>=InpMinSLPoints){g_pendingTP=g_trigger+(InpRR*g_oneR);g_barsLeft=InpValidBars;return;}
         else Disarm();
      }
   }
   
   // SELL SETUP
   if(g_dir==0 && IsGreen(1))
   {
      int run=0;for(int i=2;i<=12;i++){if(IsRed(i))run++;else break;}
      if(run>=InpKneeMinRunSell && TrendSell() && StrongCandle(2,InpMinBodyRatioSell))
      {
         g_dir=-1;
         double kneeHigh=iHigh(_Symbol,PERIOD_M5,1);
         double kneeLow=iLow(_Symbol,PERIOD_M5,1);
         g_trigger=kneeLow;
         g_pendingSL=kneeHigh+buf;
         g_oneR=g_pendingSL-g_trigger;
         if(g_oneR>=InpMinSLPoints){g_pendingTP=g_trigger-(InpRR*g_oneR);g_barsLeft=InpValidBars;return;}
         else Disarm();
      }
   }
}

//============================================================
// OPEN TRADES
//============================================================
void OpenBuy()
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double sl=g_pendingSL,tp=g_pendingTP;
   double oneR=ask-sl;if(oneR<=0)return;
   
   double riskPct=InpRiskPercent;
   MqlDateTime dt={};TimeToStruct(TimeCurrent(),dt);
   if(InpFridayTightRisk&&dt.day_of_week==5) riskPct=InpRiskPercent*0.5; // Friday half risk
   
   double riskMoney=AccountInfoDouble(ACCOUNT_EQUITY)*(riskPct/100.0);
   double lots=CalcLots(riskMoney,oneR);if(lots<=0)return;
   
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg);tp=NormalizeDouble(tp,dg);
   
   ResetLastError();
   if(trade.Buy(lots,_Symbol,0,sl,tp,"CK_DKT_BUY"))
   {
      if(trade.ResultRetcode()==TRADE_RETCODE_DONE||trade.ResultRetcode()==TRADE_RETCODE_DONE_PARTIAL)
         g_tradesToday++;
   }
}

void OpenSell()
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=g_pendingSL,tp=g_pendingTP;
   double oneR=sl-bid;if(oneR<=0)return;
   
   double riskPct=InpRiskPercent;
   MqlDateTime dt={};TimeToStruct(TimeCurrent(),dt);
   if(InpFridayTightRisk&&dt.day_of_week==5) riskPct=InpRiskPercent*0.5;
   
   double riskMoney=AccountInfoDouble(ACCOUNT_EQUITY)*(riskPct/100.0);
   double lots=CalcLots(riskMoney,oneR);if(lots<=0)return;
   
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   sl=NormalizeDouble(sl,dg);tp=NormalizeDouble(tp,dg);
   
   ResetLastError();
   if(trade.Sell(lots,_Symbol,0,sl,tp,"CK_DKT_SELL"))
   {
      if(trade.ResultRetcode()==TRADE_RETCODE_DONE||trade.ResultRetcode()==TRADE_RETCODE_DONE_PARTIAL)
         g_tradesToday++;
   }
}

//============================================================
// BREAK-EVEN
//============================================================
void ManageBE()
{
   if(!InpBreakEvenAt1R) return;
   ulong tk=MyTicket();if(tk==0)return;
   if(!PositionSelectByTicket(tk))return;
   
   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   long posType=PositionGetInteger(POSITION_TYPE);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double be=NormalizeDouble(open,dg);
   
   if(posType==POSITION_TYPE_BUY)
   {
      double oneR=open-curSL;if(oneR<=0)return;
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(bid>=open+oneR && curSL<be)
         trade.PositionModify(tk,be,tp);
   }
   else if(posType==POSITION_TYPE_SELL)
   {
      double oneR=curSL-open;if(oneR<=0)return;
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(ask<=open-oneR && curSL>be)
         trade.PositionModify(tk,be,tp);
   }
}

//============================================================
// MAIN TICK
//============================================================
void OnTick()
{
   datetime ds=iTime(_Symbol,PERIOD_D1,0);
   if(ds>0&&ds!=g_dayStart){ResetDaily();BuildLevels();}
   
   ManageBE();
   
   if(IsNewBar())
   {
      if(g_dir!=0){g_barsLeft--;if(g_barsLeft<=0)Disarm();}
      if(g_dir==0&&!HasPos()&&TradingAllowed()) TryArm();
   }
   
   if(g_dir==0||HasPos()) return;
   if(!TradingAllowed()) return;
   
   MqlTick tick={};if(!SymbolInfoTick(_Symbol,tick))return;
   
   if(g_dir>0&&tick.ask>=g_trigger){OpenBuy();Disarm();}
   else if(g_dir<0&&tick.bid<=g_trigger){OpenSell();Disarm();}
}
//+------------------------------------------------------------------+

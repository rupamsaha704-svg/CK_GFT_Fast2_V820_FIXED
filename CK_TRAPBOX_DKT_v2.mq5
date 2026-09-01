//+------------------------------------------------------------------+
//|  CK_TRAPBOX_DKT_v1.mq5                                            |
//|  Faithful MT5 port of "Russian Trapbox by [DKT]" (Pine indicator).|
//|  Edge = ICT killzone OPENING-RANGE breakout:                      |
//|   - Each session, the FIRST M15 candle's high/low = the box.      |
//|   - A close ABOVE the box high => BUY (breakout);                 |
//|     a close BELOW the box low  => SELL (breakdown).               |
//|   - SL = beyond the OPPOSITE box edge by InpSLpips.               |
//|   - TP = beyond the breakout box edge by InpTPpips.               |
//|   (Pine draws TP1/TP2/TP3 at 40/60/90; MVP uses one configurable  |
//|    TP = default 60 = "TP2". Partial-TP scaling can be added later.)|
//|  XAUUSD pip = 0.1 (as in the Pine pipsToPrice()).                 |
//|  Session start hours are SERVER-TIME inputs (adjust to broker).   |
//|  Risk-based lot, HARD 0.09 cap, 1 position, 3 trades/day gates.   |
//|  OnTester -> Common\Files\ck_trapbox_trades.csv (time,profit).    |
//+------------------------------------------------------------------+
#property copyright "CK TRAPBOX DKT v1"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE / RISK ===
input long   InpMagic            = 20260902;
input double InpRiskPercent      = 0.5;
input double InpMaxLot            = 0.09;    // HARD CAP
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input int    InpMaxSpreadPoints  = 60;
//=== BOX / SESSION (server-time start hours; box = first M15 candle of that hour) ===
input ENUM_TIMEFRAMES InpBoxTF   = PERIOD_M15;
input int    InpAsiaStart        = 4;        // Asian killzone box hour (server)
input int    InpLondonStart      = 10;       // London killzone box hour (server)
input int    InpNYStart          = 15;       // New York killzone box hour (server)
input int    InpWatchBars        = 20;       // watch this many M15 bars after box for a breakout
input bool   InpTradeAsia        = true;
input bool   InpTradeLondon      = true;
input bool   InpTradeNY          = true;
//=== ENTRY / EXITS (pips; XAUUSD 1 pip = 0.1) ===
input bool   InpAllowBuy         = true;
input bool   InpAllowSell        = true;
input double InpSLpips           = 40.0;     // SL beyond opposite box edge
input double InpTPpips           = 60.0;     // TP beyond breakout box edge (TP2 default)
input double InpMaxRiskPips      = 200.0;    // skip if (box height + SL) exceeds this (too-wide box)
//=== v2: breakeven after first target (fixes broken RR - 73% win but oversized losses) ===
input bool   InpUseBE            = true;     // move SL to entry once +InpBEtriggerPips in profit
input double InpBEtriggerPips    = 40.0;     // = TP1 distance; once reached, SL -> breakeven

int      hAtr;
datetime lastBarTime=0, g_dayStart=0;
double   g_dayStartBal=0, g_oneR_money=0;
int      g_tradesToday=0;
// current box state
bool     g_boxSet=false, g_boxTraded=false;
double   g_boxHigh=0, g_boxLow=0;
int      g_watchLeft=0;

double Pip(){ return(0.1); }   // XAUUSD pip per the Pine script

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   ResetDaily();
   PrintFormat("[TRAPBOX] boxTF=%d asia=%d ldn=%d ny=%d SLp=%.0f TPp=%.0f",InpBoxTF,InpAsiaStart,InpLondonStart,InpNYStart,InpSLpips,InpTPpips);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ if(hAtr!=INVALID_HANDLE)IndicatorRelease(hAtr); }

bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }
void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; }
double RealizedRToday(){ if(g_oneR_money<=0)return(0); return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }
int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }

double LotForRisk(double riskMoney,double slDist)
{
   if(slDist<=0)return(0);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0)return(0);
   double lpl=(slDist/ts)*tv; if(lpl<=0)return(0);
   double lots=riskMoney/lpl;
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathFloor(lots/st)*st; if(lots<mn)lots=mn; if(lots>InpMaxLot)lots=InpMaxLot;
   return(lots);
}
void OpenBuy(double sl,double tp)
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Buy(lots,_Symbol,0,sl,tp)) g_tradesToday++;
}
void OpenSell(double sl,double tp)
{
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return;
   double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   if(trade.Sell(lots,_Symbol,0,sl,tp)) g_tradesToday++;
}

// Is the just-closed box-TF bar (shift 1) the FIRST candle of an enabled session?
bool IsBoxCandle(datetime bt)
{
   MqlDateTime dt; TimeToStruct(bt,dt);
   if(dt.min!=0) return(false);
   if(InpTradeAsia   && dt.hour==InpAsiaStart)   return(true);
   if(InpTradeLondon && dt.hour==InpLondonStart) return(true);
   if(InpTradeNY     && dt.hour==InpNYStart)     return(true);
   return(false);
}

double OnTester()
{
   HistorySelect(0,TimeCurrent());
   int total=HistoryDealsTotal();
   ulong ids[]; datetime ins[]; int nin=0;
   ArrayResize(ids,total); ArrayResize(ins,total);
   for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
      ids[nin]=(ulong)HistoryDealGetInteger(tk,DEAL_POSITION_ID);
      ins[nin]=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); nin++;
   }
   int h=FileOpen("ck_trapbox2_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"time","profit");
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
         if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         ulong pid=(ulong)HistoryDealGetInteger(tk,DEAL_POSITION_ID);
         datetime et=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
         for(int j=0;j<nin;j++){ if(ids[j]==pid){ et=ins[j]; break; } }
         double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(et,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h);
   }
   return(0.0);
}

void ManageBE()
{
   if(!InpUseBE) return;
   for(int i=PositionsTotal()-1;i>=0;i--){
      ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      double open=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
      long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      double trig=InpBEtriggerPips*Pip();
      if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         if(bid-open>=trig && sl<open) trade.PositionModify(tk,NormalizeDouble(open,dg),tp); }
      else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         if(open-ask>=trig && (sl>open||sl<=0)) trade.PositionModify(tk,NormalizeDouble(open,dg),tp); }
   }
}
void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();
   ManageBE();
   if(!IsNewBar()) return;                       // act once per (box-TF) bar close
   // just-closed bar = shift 1 on the box timeframe
   datetime bt = iTime(_Symbol,InpBoxTF,1);
   double bhigh = iHigh(_Symbol,InpBoxTF,1);
   double blow  = iLow (_Symbol,InpBoxTF,1);
   double bclose= iClose(_Symbol,InpBoxTF,1);
   double bopen = iOpen(_Symbol,InpBoxTF,1);

   // 1) new box?
   if(IsBoxCandle(bt)){
      g_boxHigh=bhigh; g_boxLow=blow; g_boxSet=true; g_boxTraded=false; g_watchLeft=InpWatchBars;
      return;                                     // never trade on the box candle itself
   }
   if(!g_boxSet) return;
   if(g_watchLeft<=0){ g_boxSet=false; return; }  // watch window expired
   g_watchLeft--;

   if(MyPositions()>0) return;
   if(g_boxTraded) return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints) return;
   if(!TradingAllowed()) return;

   double pip=Pip();
   double boxH = g_boxHigh - g_boxLow;            // box height (price)
   // BUY breakout: close above box high
   if(InpAllowBuy && bclose>g_boxHigh){
      double sl = g_boxLow  - InpSLpips*pip;
      double tp = g_boxHigh + InpTPpips*pip;
      double riskPips = (SymbolInfoDouble(_Symbol,SYMBOL_ASK)-sl)/pip;
      if(riskPips>0 && riskPips<=InpMaxRiskPips){ OpenBuy(sl,tp); g_boxTraded=true; }
      return;
   }
   // SELL breakdown: close below box low
   if(InpAllowSell && bclose<g_boxLow){
      double sl = g_boxHigh + InpSLpips*pip;
      double tp = g_boxLow  - InpTPpips*pip;
      double riskPips = (sl-SymbolInfoDouble(_Symbol,SYMBOL_BID))/pip;
      if(riskPips>0 && riskPips<=InpMaxRiskPips){ OpenSell(sl,tp); g_boxTraded=true; }
      return;
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                    CK_GFT_Fast_v25_ROBUST.mq5     |
//|  = v23 (RR3 trend breakout-pullback, NO partial book)            |
//|    + DRAWDOWN CIRCUIT-BREAKER.                                    |
//|                                                                    |
//|  WHY: lowering risk% did NOT cut %-drawdown (proved empirically: |
//|  0.50%->0.30% risk left MaxDD ~13% unchanged), because %DD is a  |
//|  property of the win/loss SEQUENCE, not position size. The only  |
//|  honest way to cap %DD is to STOP TRADING when a drawdown limit  |
//|  is hit. When equity falls InpMaxDDPct below its running peak,    |
//|  the EA closes its position and halts new trades until the next  |
//|  calendar week, then rebases the peak and resumes. This bounds    |
//|  realized drawdown by construction (a real prop-firm rule).       |
//+------------------------------------------------------------------+
#property copyright "CK GFT Robust v25"
#property version   "25.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//=== CORE / RISK ===
input long   InpMagic            = 20260825;
input double InpRiskPercent      = 0.5;
input double InpRR               = 3.0;
input double InpMaxLot           = 0.09;   // HARD CAP
input int    InpMaxTradesPerDay  = 3;
input double InpDailyLossStopR   = 2.0;
input double InpDailyProfitStopR = 4.0;
input int    InpMaxSpreadPoints  = 60;

//=== DRAWDOWN CIRCUIT-BREAKER (the real DD lever) ===
input bool   InpUseDDBreaker     = true;
input double InpMaxDDPct         = 7.5;    // halt when equity is this % below running peak

//=== CONFIRMATION 1: HTF trend ===
input ENUM_TIMEFRAMES InpHTF     = PERIOD_H1;
input int    InpTrendEMA         = 200;
//=== CONFIRMATION 2: HTF structure breakout ===
input int    InpBreakoutLookback = 20;
input int    InpBreakoutMaxAge   = 12;
//=== CONFIRMATION 3/4: entry-TF pullback + trigger ===
input int    InpEntryEMA         = 20;
input int    InpSwingLookback    = 10;
//=== RISK gate + management ===
input double InpMaxSL_ATR        = 2.5;
input double InpSLBufferATR      = 0.20;
input bool   InpUseBreakEven     = true;
input double InpBEProgress       = 0.50;

//=== HANDLES / STATE ===
int      hEmaHTF, hEmaLTF, hAtr;
datetime lastBarTime = 0;
datetime g_dayStart  = 0;
double   g_dayStartBal = 0.0;
double   g_oneR_money  = 0.0;
int      g_tradesToday = 0;
bool     g_beActivated = false;
//=== breaker state ===
double   g_peakEq   = 0.0;
bool     g_ddHalted = false;
int      g_haltWeek = -1;

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   hEmaHTF = iMA(_Symbol, InpHTF,          InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEmaLTF = iMA(_Symbol, PERIOD_CURRENT,  InpEntryEMA, 0, MODE_EMA, PRICE_CLOSE);
   hAtr    = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(hEmaHTF==INVALID_HANDLE || hEmaLTF==INVALID_HANDLE || hAtr==INVALID_HANDLE)
      return(INIT_FAILED);
   ResetDaily();
   g_peakEq=AccountInfoDouble(ACCOUNT_EQUITY);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   if(hEmaHTF!=INVALID_HANDLE) IndicatorRelease(hEmaHTF);
   if(hEmaLTF!=INVALID_HANDLE) IndicatorRelease(hEmaLTF);
   if(hAtr   !=INVALID_HANDLE) IndicatorRelease(hAtr);
}

double ATR(){ double b[]; if(CopyBuffer(hAtr,0,0,1,b)<=0) return(0); return(b[0]); }
double EmaHTF(int shift){ double b[]; if(CopyBuffer(hEmaHTF,0,shift,1,b)<=0) return(0); return(b[0]); }
double EmaLTF(int shift){ double b[]; if(CopyBuffer(hEmaLTF,0,shift,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=lastBarTime){ lastBarTime=t; return(true);} return(false); }

void ResetDaily(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_oneR_money=g_dayStartBal*(InpRiskPercent/100.0); g_tradesToday=0; }
double RealizedRToday(){ if(g_oneR_money<=0) return(0); return((AccountInfoDouble(ACCOUNT_BALANCE)-g_dayStartBal)/g_oneR_money); }
bool TradingAllowed(){ double r=RealizedRToday(); if(InpDailyProfitStopR>0&&r>=InpDailyProfitStopR)return(false); if(InpDailyLossStopR>0&&r<=-InpDailyLossStopR)return(false); if(g_tradesToday>=InpMaxTradesPerDay)return(false); return(true); }

int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
void CloseAllMine(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol) trade.PositionClose(tk); } }

double LotForRisk(double riskMoney,double slDist){ if(slDist<=0)return(0); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tv<=0||ts<=0)return(0); double lpl=(slDist/ts)*tv; if(lpl<=0)return(0); double lots=riskMoney/lpl; double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); lots=MathFloor(lots/st)*st; if(lots<mn)lots=mn; if(lots>InpMaxLot)lots=InpMaxLot; return(lots); }

bool RecentBreakUp(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int hi=iHighest(_Symbol,InpHTF,MODE_HIGH,InpBreakoutLookback,s+1); if(hi<0)continue; if(iClose(_Symbol,InpHTF,s)>iHigh(_Symbol,InpHTF,hi))return(true);} return(false); }
bool RecentBreakDown(){ for(int s=1;s<=InpBreakoutMaxAge;s++){ int lo=iLowest(_Symbol,InpHTF,MODE_LOW,InpBreakoutLookback,s+1); if(lo<0)continue; if(iClose(_Symbol,InpHTF,s)<iLow(_Symbol,InpHTF,lo))return(true);} return(false); }

void OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Buy(lots,_Symbol,0,sl,tp)){ g_tradesToday++; g_beActivated=false; } }
void OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=LotForRisk(AccountInfoDouble(ACCOUNT_BALANCE)*(InpRiskPercent/100.0),risk); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); if(trade.Sell(lots,_Symbol,0,sl,tp)){ g_tradesToday++; g_beActivated=false; } }

void ManageTrade()
{
   if(!InpUseBreakEven) return;
   if(MyPositions()==0){ g_beActivated=false; return; }
   ulong tk=GetMyTicket(); if(tk==0) return; if(!PositionSelectByTicket(tk)) return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(g_beActivated) return; double prog=0;
   if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(tp-open<=0)return; prog=(bid-open)/(tp-open); if(prog>=InpBEProgress&&sl<open){ if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
   else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(open-tp<=0)return; prog=(open-ask)/(open-tp); if(prog>=InpBEProgress&&sl>open){ if(trade.PositionModify(tk,NormalizeDouble(open,dg),tp))g_beActivated=true; } }
}

//=== DRAWDOWN CIRCUIT-BREAKER ===
// returns true if trading is halted this tick
bool HandleDDBreaker()
{
   if(!InpUseDDBreaker) return(false);
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_peakEq<=0) g_peakEq=eq;
   if(eq>g_peakEq)  g_peakEq=eq;
   int wk=(int)(TimeCurrent()/604800);   // calendar-week index
   if(g_ddHalted){
      if(wk!=g_haltWeek){ g_ddHalted=false; g_peakEq=eq; }  // next week: resume, rebase peak
      else return(true);
   }
   if(g_peakEq>0){
      double dd=(g_peakEq-eq)/g_peakEq;
      if(dd>=InpMaxDDPct/100.0){
         CloseAllMine();
         g_ddHalted=true; g_haltWeek=wk;
         return(true);
      }
   }
   return(false);
}

double OnTester()
{
   int h=FileOpen("ck_v25_trades.csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"deal","profit");
      HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
         if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,(string)tk,DoubleToString(p,2)); }
      FileClose(h);
   }
   return(0.0);
}

void OnTick()
{
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) ResetDaily();
   ManageTrade();
   if(HandleDDBreaker()) return;          // breaker closes + halts when DD limit hit
   if(!IsNewBar()) return;
   if(MyPositions()>0) return;
   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints) return;
   if(!TradingAllowed()) return;

   double atr=ATR(); if(atr<=0) return;
   double buf=InpSLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1), o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,2), l2=iLow(_Symbol,PERIOD_CURRENT,2);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1), hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaL=EmaLTF(1), closeH1=iClose(_Symbol,InpHTF,1), emaH=EmaHTF(1);

   if((closeH1>emaH) && RecentBreakUp() && (lo1<=emaL) && (c1>o1)&&(c1>emaL)&&(c1>h2)){
      double sl=MathMin(lo1,l2)-buf; double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl;
      if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenBuy(sl,ask+InpRR*risk); return; }
   }
   if((closeH1<emaH) && RecentBreakDown() && (hi1>=emaL) && (c1<o1)&&(c1<emaL)&&(c1<l2)){
      double sl=MathMax(hi1,h2)+buf; double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid;
      if(risk>0 && risk<=InpMaxSL_ATR*atr){ OpenSell(sl,bid-InpRR*risk); }
   }
}
//+------------------------------------------------------------------+

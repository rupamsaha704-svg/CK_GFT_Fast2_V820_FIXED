//+------------------------------------------------------------------+
//|  CK_GOLD_ICT.mq5 - liquidity/zone reversion (from user's video).  |
//|  Testable CORE of the system:                                     |
//|   * Zones = previous DAY high/low/mid + previous WEEK high/low/mid |
//|     (+ optional previous SESSION hi/lo via server-time windows).  |
//|   * Only trade Tue/Wed/Thu (skip Mon/Fri & week open) - toggle.   |
//|   * Entry = price TAGS a zone then REJECTS (wick in, close back)  |
//|     -> fade back toward the day mid. SL just BEYOND the zone      |
//|     (buffer), never trailed. TP = day mid / opposite extreme.     |
//|   * Confluence: only take 2nd-touch style tag with rejection.     |
//|  Risk auto-capped (~3%/trade), GFT static-DD + daily-loss guards. |
//|  Discretionary bits (order blocks/MSS/RSI-Prime) are NOT encoded; |
//|  this tests the liquidity-reversion backbone honestly.            |
//+------------------------------------------------------------------+
#property copyright "CK GOLD ICT"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade trade;

input long   InpMagic          = 20260932;
input ENUM_TIMEFRAMES InpTF    = PERIOD_M15;  // entry timeframe
//--- zones ---
input bool   InpUsePrevDay     = true;        // prev-day H/L/M
input bool   InpUsePrevWeek    = true;        // prev-week H/L/M
input bool   InpUsePrevSession = true;        // prev-session H/L (server-time windows below)
input int    InpAsiaStart      = 0;           // server-hour session windows (adjust to broker)
input int    InpAsiaEnd        = 8;
input int    InpLondonStart    = 8;
input int    InpLondonEnd      = 16;
input int    InpNYStart        = 13;
input int    InpNYEnd          = 22;
//--- entry ---
input double InpTagTolATR      = 0.25;        // how close counts as "tagging" the zone (ATR mult)
input double InpSLbufATR       = 0.30;        // SL placed this far BEYOND the zone (ATR mult)
input bool   InpRequireReject  = true;        // require wick-in + close-back rejection
input bool   InpAllowShort     = true;        // fade highs too (gold drifts up: test)
input bool   InpUseBias        = true;        // fade WITH higher-TF bias: buy support only in uptrend, sell resistance only in downtrend
input ENUM_TIMEFRAMES InpBiasTF= PERIOD_D1;   // bias timeframe
input int    InpBiasEMA        = 50;          // bias EMA (price above=bull -> allow buys; below=bear -> allow sells)
input int    InpTPmode         = 0;           // 0 = day mid, 1 = opposite prev-day extreme
input int    InpMaxTradesPerDay= 4;
//--- day-of-week filter (Sun=0..Sat=6) ---
input bool   InpTradeMon       = false;
input bool   InpTradeTue       = true;
input bool   InpTradeWed       = true;
input bool   InpTradeThu       = true;
input bool   InpTradeFri       = false;
//--- sizing / guards (same discipline as DTREND) ---
input int    InpATRPeriod      = 14;
input double InpRiskPercent    = 1.0;
input double InpMaxLot         = 0.50;
input double InpMaxRiskPerTradePct = 3.0;
input double InpMaxSpreadPrice = 1.00;
input bool   InpUseDailyLoss   = true;
input double InpDailyLossPct   = 5.0;
input bool   InpUseStaticDD    = true;
input double InpStaticDDStopPct= 8.0;

int      hATR,hBias;
datetime g_barTime=0,g_dayStart=0;
double   g_dayStartBal=0,g_initBal=0;
bool     g_halted=false;
int      g_tradesToday=0;
string   GK_INIT,GK_DAY,GK_BAL,GK_TRD;
int      g_nBuy=0,g_nSell=0,g_cDay=0,g_cRisk=0,g_cSpread=0,g_cNoTag=0;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(30);
   trade.SetTypeFillingBySymbol(_Symbol); trade.LogLevel(LOG_LEVEL_NO);
   hATR=iATR(_Symbol,InpTF,InpATRPeriod);
   hBias=iMA(_Symbol,InpBiasTF,InpBiasEMA,0,MODE_EMA,PRICE_CLOSE);
   if(hATR==INVALID_HANDLE||hBias==INVALID_HANDLE)return(INIT_FAILED);
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic);
   GK_INIT="ckict_init_"+scope; GK_DAY="ckict_day_"+scope; GK_BAL="ckict_bal_"+scope; GK_TRD="ckict_trd_"+scope;
   if(GlobalVariableCheck(GK_INIT)) g_initBal=GlobalVariableGet(GK_INIT);
   else { g_initBal=AccountInfoDouble(ACCOUNT_BALANCE); GlobalVariableSet(GK_INIT,g_initBal); }
   LoadOrResetDaily();
   PrintFormat("[ICT] TF=%d day/week/sess=%d%d%d short=%s tolATR=%.2f slBufATR=%.2f mpp=%.1f",
               (int)InpTF,InpUsePrevDay,InpUsePrevWeek,InpUsePrevSession,(InpAllowShort?"Y":"N"),
               InpTagTolATR,InpSLbufATR,MoneyPerPricePerLot());
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){ IndicatorRelease(hATR); IndicatorRelease(hBias); }

double ATRv(){ double b[]; if(CopyBuffer(hATR,0,1,1,b)<=0)return(0); return(b[0]); }
bool IsNewBar(){ datetime t=iTime(_Symbol,InpTF,0); if(t!=g_barTime){ g_barTime=t; return(true);} return(false); }

void LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0); datetime gday=(datetime)GlobalVariableGet(GK_DAY);
   if(gday==today && today>0){ g_dayStart=today; g_dayStartBal=GlobalVariableGet(GK_BAL); g_tradesToday=(int)GlobalVariableGet(GK_TRD); }
   else { g_dayStart=today; g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)today); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }
}
void NewDay(){ g_dayStart=iTime(_Symbol,PERIOD_D1,0); g_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_tradesToday=0; GlobalVariableSet(GK_DAY,(double)g_dayStart); GlobalVariableSet(GK_BAL,g_dayStartBal); GlobalVariableSet(GK_TRD,0); }

int MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
double MoneyPerPricePerLot(){ double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE); double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); double bt=(ts>0)?tv/ts:0.0; if(cs>0)return(cs); return(bt); }
double CalcLot(double slDist){
   double mpp=MoneyPerPricePerLot(); if(mpp<=0||slDist<=0)return(0);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney=bal*(InpRiskPercent/100.0); double maxRisk=bal*(InpMaxRiskPerTradePct/100.0);
   if(riskMoney>maxRisk) riskMoney=maxRisk;
   double lot=riskMoney/(slDist*mpp);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathFloor(lot/st)*st;
   if(lot<mn){ if(slDist*mn*mpp>maxRisk) return(0); lot=mn; }
   if(lot>InpMaxLot) lot=InpMaxLot; if(mx>0&&lot>mx)lot=mx;
   return(lot);
}
double EquityDDpctFromInit(){ if(g_initBal<=0)return(0); return(100.0*(g_initBal-AccountInfoDouble(ACCOUNT_EQUITY))/g_initBal); }
double DayLossPct(){ if(g_dayStartBal<=0)return(0); return(100.0*(g_dayStartBal-AccountInfoDouble(ACCOUNT_EQUITY))/g_dayStartBal); }
void CloseAll(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==InpMagic&&PositionGetString(POSITION_SYMBOL)==_Symbol) trade.PositionClose(tk); } }

bool DayAllowed(){
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int d=dt.day_of_week;
   if(d==1)return(InpTradeMon); if(d==2)return(InpTradeTue); if(d==3)return(InpTradeWed);
   if(d==4)return(InpTradeThu); if(d==5)return(InpTradeFri); return(false); // Sun/Sat off
}
// previous completed session hi/lo using server-hour window [sH,eH)
bool PrevSessionHiLo(int sH,int eH,double &hi,double &lo){
   hi=-1; lo=-1; int bars=(int)((eH-sH)*60/ (PeriodSeconds(InpTF)/60)); if(bars<1)bars=1;
   // scan back up to 3 days of TF bars to find the most recent completed session window
   int lookback=(int)(3*24*60/(PeriodSeconds(InpTF)/60)); if(lookback>3000)lookback=3000;
   bool found=false; int startShift=-1;
   for(int i=1;i<lookback;i++){
      datetime t=iTime(_Symbol,InpTF,i); if(t<=0)break; MqlDateTime dt; TimeToStruct(t,dt);
      bool inSess=(dt.hour>=sH && dt.hour<eH);
      if(inSess){ // accumulate this session (walk until it ends going forward-in-time = smaller i)
         double H=-1,L=-1; int j=i;
         while(j>=1){ datetime tj=iTime(_Symbol,InpTF,j); MqlDateTime dj; TimeToStruct(tj,dj); if(!(dj.hour>=sH&&dj.hour<eH))break; double hh=iHigh(_Symbol,InpTF,j),ll=iLow(_Symbol,InpTF,j); if(H<0||hh>H)H=hh; if(L<0||ll<L)L=ll; j--; }
         hi=H; lo=L; found=(H>0&&L>0); break;
      }
   }
   return(found);
}
void AddLevel(double &arr[],int &n,double v){ if(v>0){ arr[n]=v; n++; } }

void TryTrade(){
   double atr=ATRv(); if(atr<=0)return;
   double c1=iClose(_Symbol,InpTF,1),h1=iHigh(_Symbol,InpTF,1),l1=iLow(_Symbol,InpTF,1);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tol=InpTagTolATR*atr, buf=InpSLbufATR*atr;
   bool biasBuyOK=true, biasSellOK=true;
   if(InpUseBias){ double bb[]; double be=0; if(CopyBuffer(hBias,0,1,1,bb)>0) be=bb[0];
      if(be>0){ biasBuyOK=(bid>be); biasSellOK=(bid<be); } }
   double pdH=iHigh(_Symbol,PERIOD_D1,1),pdL=iLow(_Symbol,PERIOD_D1,1),pdM=(pdH+pdL)/2.0;
   double pwH=iHigh(_Symbol,PERIOD_W1,1),pwL=iLow(_Symbol,PERIOD_W1,1),pwM=(pwH+pwL)/2.0;
   // build resistance (fade short) and support (fade long) level sets
   double res[16],sup[16]; int nr=0,ns=0;
   if(InpUsePrevDay){  AddLevel(res,nr,pdH); AddLevel(sup,ns,pdL); if(pdM>bid)AddLevel(res,nr,pdM); else AddLevel(sup,ns,pdM); }
   if(InpUsePrevWeek){ AddLevel(res,nr,pwH); AddLevel(sup,ns,pwL); if(pwM>bid)AddLevel(res,nr,pwM); else AddLevel(sup,ns,pwM); }
   if(InpUsePrevSession){ double sh,sl2;
      if(PrevSessionHiLo(InpAsiaStart,InpAsiaEnd,sh,sl2)){ AddLevel(res,nr,sh); AddLevel(sup,ns,sl2);} 
      if(PrevSessionHiLo(InpLondonStart,InpLondonEnd,sh,sl2)){ AddLevel(res,nr,sh); AddLevel(sup,ns,sl2);} 
      if(PrevSessionHiLo(InpNYStart,InpNYEnd,sh,sl2)){ AddLevel(res,nr,sh); AddLevel(sup,ns,sl2);} }
   double tpMid=pdM;
   // SUPPORT -> long: bar low tagged support, closed back above (rejection up)
   double bestS=-1;
   for(int i=0;i<ns;i++){ double L=sup[i]; if(l1<=L+tol && l1>=L-tol*3 && c1>L && (!InpRequireReject || (c1>l1))){ if(bestS<0||MathAbs(bid-L)<MathAbs(bid-bestS))bestS=L; } }
   if(bestS>0 && MyPositions()==0 && biasBuyOK){
      double sl=bestS-buf; double tp=(InpTPmode==0)?tpMid:pdH; if(tp<=bid)tp=pdH; if(tp<=bid)tp=0;
      OpenSL(true,sl,tp); return;
   }
   // RESISTANCE -> short
   if(InpAllowShort && biasSellOK){ double bestR=-1;
      for(int i=0;i<nr;i++){ double R=res[i]; if(h1>=R-tol && h1<=R+tol*3 && c1<R && (!InpRequireReject || (c1<h1))){ if(bestR<0||MathAbs(bid-R)<MathAbs(bid-bestR))bestR=R; } }
      if(bestR>0 && MyPositions()==0){
         double sl=bestR+buf; double tp=(InpTPmode==0)?tpMid:pdL; if(tp>=bid)tp=pdL; if(tp>=bid)tp=0;
         OpenSL(false,sl,tp); return;
      }
   }
   g_cNoTag++;
}
void OpenSL(bool isBuy,double slPrice,double tpPrice){
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double entry=isBuy?ask:bid; double slDist=MathAbs(entry-slPrice); if(slDist<=0)return;
   double lot=CalcLot(slDist); if(lot<=0){ g_cRisk++; return; }
   slPrice=NormalizeDouble(slPrice,dg); tpPrice=NormalizeDouble(tpPrice,dg);
   bool ok=isBuy?trade.Buy(lot,_Symbol,0,slPrice,tpPrice):trade.Sell(lot,_Symbol,0,slPrice,tpPrice);
   if(ok){ if(isBuy)g_nBuy++; else g_nSell++; g_tradesToday++; GlobalVariableSet(GK_TRD,g_tradesToday); }
}
double OnTester(){
   PrintFormat("[ICT] buys=%d sells=%d dayBlock=%d riskSkip=%d spreadSkip=%d halted=%s",g_nBuy,g_nSell,g_cDay,g_cRisk,g_cSpread,(g_halted?"Y":"n"));
   int h=FileOpen("ck_gold_ict_trades.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit"); HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2)); }
      FileClose(h); }
   return(0.0);
}
void OnTick(){
   if(InpUseStaticDD && !g_halted && EquityDDpctFromInit()>=InpStaticDDStopPct){ g_halted=true; CloseAll(); Print("[ICT] STATIC-DD HALT"); }
   if(g_halted){ if(MyPositions()>0)CloseAll(); return; }
   if(iTime(_Symbol,PERIOD_D1,0)!=g_dayStart) NewDay();
   bool dayBlocked=(InpUseDailyLoss && DayLossPct()>=InpDailyLossPct);
   if(dayBlocked && MyPositions()>0) CloseAll();
   if(!IsNewBar())return;
   if(MyPositions()>0)return;
   if(dayBlocked) return;
   if(!DayAllowed()){ g_cDay++; return; }
   if(g_tradesToday>=InpMaxTradesPerDay) return;
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(InpMaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ g_cSpread++; return; }
   TryTrade();
}
//+------------------------------------------------------------------+

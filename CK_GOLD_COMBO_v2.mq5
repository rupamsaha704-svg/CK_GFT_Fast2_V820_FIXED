//+------------------------------------------------------------------+
//|  CK_GOLD_COMBO_v2.mq5 - FIX09 + DTREND + DONCHIAN on ONE account. |
//|  Runs THREE validated strategies side-by-side, each with own      |
//|  magic number so positions never collide:                         |
//|    * FIX09    (magic 20260716): H1 EMA200 + M15 pullback breakout |
//|    * DTREND   (magic 20260930): H4 EMA20/100 LONG-ONLY + ATR trail|
//|    * DONCHIAN (magic 20260921003): 20-bar M15 close breakout,     |
//|      fixed lot, 2 ATR SL, 3R TP. Symmetric long/short.            |
//|  Master guard: static DD + daily governor + 3% funded risk cap    |
//|  (max concurrent 1 in Funded), all applied across ALL 3 sleeves.  |
//|                                                                    |
//|  DIVERSIFICATION: Donchian corr -0.026 with Plan C (FIX09+DTREND) |
//|  profits in 5 of 6 Plan C losing months. Combined 61%/yr vs 37%.  |
//|                                                                    |
//|  HOW TO TEST (Strategy Tester):                                   |
//|    Symbol=XAUUSD  Timeframe=M15                                   |
//|    Deposit=6000  Leverage=1:100  Model=1min OHLC (fast) or real   |
//|    ticks. All three strategies share the $6000; margin is real.   |
//+------------------------------------------------------------------+
#property copyright "CK GOLD COMBO v2 (FIX09 + DTREND + DONCHIAN)"
#property version   "2.00"
#property strict
#include <Trade\Trade.mqh>
CTrade tf;   // FIX09 trader
CTrade td;   // DTREND trader
CTrade dn;   // DONCHIAN trader

//====================== MASTER (whole-account) =====================
input bool   Combo_EnableFIX09    = true;
input bool   Combo_EnableDTREND   = true;
input bool   Combo_EnableDonchian = true;   // v2: 3rd sleeve
input bool   Combo_UseStaticDD    = true;   // halt EVERYTHING if account equity falls this % below start
input double Combo_StaticDDStopPct= 8.0;    // < GFT 10% static
input bool   Combo_UseDailyLoss   = true;   // reactive backstop: flatten + no new trades if account day-loss hits this % (of day-start balance)
input double Combo_DailyLossPct   = 4.5;    // reactive flatten level (buffer under the 5% hard daily line)
input string Combo_BlockEntryHours= "99";   // server-time hours to BLOCK NEW ENTRIES (running trades keep running). "99" = block none. (hour-block proved unhelpful; governor used instead)
//--- IXU-style NO-WEEKEND-HOLDING rule: close ALL + block new entries from Friday HH:00 server through the weekend. Default OFF (FundedNext allows weekend holds). ---
input bool   Combo_WeekendFlat    = false;  // true = flatten everything before the weekend + no entries Fri>=HH/Sat/Sun (IXU); false = weekend holds OK (FundedNext)
input int    Combo_WeekendFlatHour= 20;     // Friday server hour to flatten before the weekend (used only if Combo_WeekendFlat=true)
//--- pre-trade PREDICTIVE daily-loss governor + per-trade risk cap (never breach the 5% daily / one dead-account rule) ---
input bool   Combo_UsePredictiveDaily = true;  // before a NEW entry, block it if it could push today's loss past the buffered daily cap
input double Combo_DailyBufferPct      = 4.0;   // buffered daily cap (% of day-start balance); 1% under the 5% hard line
input bool   Combo_UsePerTradeCap      = true;  // cap the worst-case SL risk of any single trade
input double Combo_PerTradeMaxRiskPct  = 3.0;   // (EVAL) a single trade's worst-case SL loss may not exceed this % of day-start balance
//--- seq220 daily REFERENCE basis: some firms fix the daily loss to a % of the INITIAL balance (e.g. FundedNext "5% of initial"), not the day-start balance. When true, the daily governor (reactive flatten + predictive block + per-trade cap) measures the day's loss as a % of the fixed INITIAL balance, so on a grown account the $ cap stays at 5%-of-initial instead of growing with day-start. false = day-start basis (GFT/FTMO style, unchanged). ---
input bool   Combo_DailyRefInitial     = false;  // false = daily % of day-start balance (GFT/FTMO); true = daily % of INITIAL balance (FundedNext-style fixed daily cap)
//--- STAGE switch (the "chip"): 0 = EVAL (Step1/2, no Goat Guard), 1 = FUNDED (Goat Guard 2% of INITIAL applies) ---
input int    Combo_Stage               = 0;     // 0=Eval (pass fast) | 1=Funded (Goat-Guard-safe, tighter, lower return)
//--- seq276 EVAL combined floating loss cap: prevents overnight multi-position disasters like Sep 2 (−$497). Looser than funded 1.2%, but tight enough to avoid daily-line breach. ---
input double Combo_EvalFloatFlatPct    = 3.5;   // EVAL: flatten ALL if combined FLOATING loss reaches this % of INITIAL (buffer under 5% daily line)
input double Combo_FundedFloatFlatPct  = 1.2;   // FUNDED: flatten ALL if combined FLOATING loss reaches this % of INITIAL (real-tick-confirmed buffer under Goat Guard 2%)
input double Combo_FundedPerTradePct   = 0.6;   // FUNDED: max worst-case SL risk of one trade (% of INITIAL) - leaves room for real-tick slippage
input double Combo_FundedFixLot        = 0.01;  // FUNDED: FIX09 min lot (real-tick worst trade -$53 << Goat Guard $100)
input double Combo_FundedRiskPct       = 0.5;   // FUNDED: DTREND risk % per trade
input long   Combo_FundedLogin         = 0;     // AUTO-SWITCH: if >0 and this account's login == this number -> Funded (Goat Guard) mode automatically. 0 = use Combo_Stage manually.
input double Combo_FundedMaxSLpts      = 0;     // FUNDED: skip a trade if its SL distance > this many points. NOTE: cannot stop real-tick GAPS through the SL; only small lot (0.01) is gap-safe on $5k. 0 = off (default).
//--- seq188 GAP-BUDGETED DTREND sizing (funded): size DTREND by worst-case-incl-gap dollar budget instead of risk%, to concentrate the $-budget on the wide-stop sleeve ---
input bool   Combo_FundedGapSizing     = false; // FUNDED: size DTREND by gap budget. seq188 REFUTED: with $50 gap + 0.01 lot step this floors to 0.01 (no gain) -> default OFF, keep validated risk% path (seq182 real-tick +11%). Kept for future fractional-lot brokers.
input double Combo_FundedGapUsd        = 50.0;  // FUNDED: assumed worst adverse GAP beyond the SL (USD/oz) baked into the DTREND size budget
input double Combo_FundedTradeBudgetUsd= 80.0;  // FUNDED: max worst-case loss (incl. the assumed gap) for ONE DTREND trade (USD) - buffer under $85 pass line and $100 Goat Guard
//--- seq208 MARGIN CEILING (COMPLIANCE, not an experiment -> default ON) ---
// GFT support 2026-09-15: "There are no lot size restrictions. You are not allowed to use more than
// 80% of available margin." Our eval lot of 0.09 needs ~90% of a $5k account at gold ~5000, so the
// shipped eval config BREACHED this rule. Margin is read from MT5's own OrderCalcMargin(), so the
// BROKER's real rate applies and nothing is assumed - this also survives moving to GFT's server,
// whose margin rate we were never told.
input double Combo_MaxMarginPct   = 60.0;  // clamp lot so margin used stays under this % of equity (firm limit 80% -> 20pt buffer)

//--- seq204 GOAT GUARD concurrent-position cap (COMPLIANCE -> default ON in funded) ---
// FIX09 and DTREND each cap themselves at one position but do NOT know about each other, so two
// can be open at once. Goat Guard measures the COMBINED floating loss of ALL open positions, and
// two 0.01-lot positions gapping adversely together is about -$106, past the $100 threshold. The
// 1.2% float-flatten cannot stop it because a gap moves in a single tick (proven seq184/seq185).
input int    Combo_FundedMaxOpenTotal = 1; // FUNDED: max open positions across BOTH sleeves (0 = off)

//--- rule 6b NEWS WINDOW gate (EXPECTANCY question -> default OFF, must be A/B'd) ---
// GFT confirmed: any trade opened OR closed - including automatically by SL/TP/pending - within
// 5 min either side of a high-impact release is capped at 1% of initial ($50), excess removed.
// Applies in BOTH evaluation and funded. Payoff in the window is asymmetric (capped upside, full
// downside), so blocking is plausibly good - but that is an edge claim, so it stays OFF until an
// A/B measures it. Not a breach either way.
input bool   Combo_UseNewsGate    = false; // block NEW entries near high-impact news (A/B lever)
input int    Combo_NewsBlockMin   = 6;     // minutes either side of the release to block (5 + 1 buffer)

//--- MULTI-TIMEFRAME alignment "chip": only trade WITH the higher-TF consensus (blocks counter-trend fades -> higher win rate) ---
input bool   Combo_UseMTF        = true;  // require multi-timeframe trend agreement before entering
input int    Combo_MTF_EMA       = 50;    // per-TF trend EMA: close>EMA = bull, close<EMA = bear
input int    Combo_MTF_MinScore  = 2;     // ladder M15,H1,H4,D1 -> score -4..+4; BUY needs >=+this, SELL <=-this, DTREND long >=+this

//====================== FIX09 inputs (FIX_) ========================
input long   FIX_Magic            = 20260716;
input double FIX_FixedLot          = 0.09;
input double FIX_MaxLot           = 0.09;
input double FIX_RiskPercent      = 2.0;    // daily +/-R reference only (not lot size)
input double FIX_RR               = 3.0;
input int    FIX_MaxTradesPerDay  = 3;
input double FIX_DailyLossStopR   = 2.0;
input double FIX_DailyProfitStopR = 4.0;
input double FIX_MaxSpreadPrice   = 0.60;
input ENUM_TIMEFRAMES FIX_HTF     = PERIOD_H1;
input int    FIX_TrendEMA         = 200;
input int    FIX_BreakoutLookback = 20;
input int    FIX_BreakoutMaxAge   = 12;
input int    FIX_EntryEMA         = 20;
input int    FIX_SwingLookback    = 10;
input double FIX_MaxSL_ATR        = 2.5;
input double FIX_SLBufferATR      = 0.20;
input bool   FIX_UseBreakEven     = true;
input double FIX_BEProgress       = 0.50;
//--- seq190 PROFIT-LOCK (R-ratchet give-back trail): once a trade reaches +1R, trail SL to lock (peakR-GiveBack)*R, ratchet-only. Converts the ~17.5% break-even give-back cluster into locked wins. Gap-neutral (acts only after +1R; initial stop/lot/gap unchanged). Overrides the one-shot BE when on. ---
input bool   FIX_UseProfitLock    = false;  // FUNDED expectancy lever: replace one-shot BE with a ratcheting profit-lock trail (A/B: off=control one-shot BE, on=treatment)
input double FIX_ProfitLockGiveBackR = 1.0; // give-back budget G (in R): locked SL = entry +/- (peakR - G)*R once peakR>=1.0R. Single pre-declared param, NOT to be swept.
//--- seq192 CHIP C: exit-on-reversal (harvest profit, do NOT trail SL). Arm after peakR>=ArmR; close AT MARKET only when price retraces > GiveBackFrac of peak profit AND the current M15 bar closes against the trade. Runners that keep going never trigger -> 3R TP survives. Gap/Goat-Guard safe (acts only in profit, closes early). Overrides one-shot BE when on. ---
input bool   FIX_UseReversalExit    = false; // FUNDED: close a FIX09 trade in profit on a genuine adverse reversal (A/B: off=control one-shot BE, on=treatment). Distinct from profit-lock (no SL trailing).
input double FIX_ReversalExitArmR    = 1.0;  // arm only after favorable excursion reaches this many R. Single pre-declared param, NOT swept.
input double FIX_ReversalExitGiveBackFrac = 0.5; // trigger if price gives back more than this fraction of the peak profit AND the M15 bar closes against us. Single pre-declared param, NOT swept.
//--- seq194 CHIP A: entry ROOM filter (entry-side). Reject a FIX09 entry unless the breakout bar actually TRAVELLED past the level it broke by >= RoomATR*ATR (not just tagged it). Targets the premature-entry-at-local-extreme / MFE~0 loss bucket. Pure entry gate: never touches SL/TP/lot/exit -> gap & Goat-Guard neutral, cannot cut runners. ---
input bool   FIX_UseEntryRoom     = false;  // FUNDED entry-quality lever: require the signal bar to have cleared the broken level by a buffer (A/B: off=control, on=treatment)
input double FIX_EntryRoomATR     = 0.5;    // required travel past the broken level, in ATR. Single pre-declared param, NOT swept.

//====================== DTREND inputs (DT_) ========================
input long   DT_Magic          = 20260930;
input ENUM_TIMEFRAMES DT_SigTF = PERIOD_H4;
input int    DT_Engine         = 0;         // 0=EMA cross,1=KAMA,2=BOTH
input int    DT_FastEMA        = 20;
input int    DT_SlowEMA        = 100;
input int    DT_KAMA_ER        = 10;
input int    DT_KAMA_Fast      = 2;
input int    DT_KAMA_Slow      = 30;
input bool   DT_UseRegime      = true;
input ENUM_TIMEFRAMES DT_RegimeTF = PERIOD_H4;
input int    DT_RegimeADXPeriod= 14;
input double DT_ADXTrendMin    = 20.0;
input bool   DT_UseHTFtrend    = true;
input ENUM_TIMEFRAMES DT_HTFtrendTF = PERIOD_D1;
input int    DT_HTFtrendEMA    = 50;
input bool   DT_UseChop        = false;
input ENUM_TIMEFRAMES DT_ChopTF = PERIOD_H4;
input int    DT_ChopPeriod     = 14;
input double DT_ChopMax        = 61.8;
input int    DT_ATRPeriod      = 14;
input double DT_SL_ATR         = 2.0;
input bool   DT_UseTrailATR    = true;
input double DT_TrailATR       = 3.0;
input double DT_RiskPercent    = 2.5;
input double DT_MaxLot         = 0.50;
input double DT_MaxRiskPerTradePct = 5.0;
input bool   DT_CapStopToRisk  = true;
input double DT_MaxSpreadPrice = 1.00;
//--- seq215 IDEA-104 STDV TARGET overlay (LumiTraders STANDARD DEVIATION PROJECTIONS; gold interest band 2.25-2.5 STDV) ---
// Faithful form B of the pre-registered idea (ledger seq213): replace the ATR runner-trail with a
// measured-move target = swingLow + DT_StdvMult * (swingHigh-swingLow) of the last H4 swing leg.
// A/B lever: off = current ATR-trail runner (control), on = STDV measured target (treatment). If no
// valid swing exists (or the target is already below price) that trade keeps the ATR trail, so the
// proven runner behaviour is never silently lost.
input bool   DT_UseStdvTP      = false;  // on = project a measured STDV target and use it as the DTREND TP (replaces the trail for that trade)
input double DT_StdvMult       = 2.5;    // gold band 2.25-2.5; single pre-declared value (2.5 = most runner room), NOT to be swept
input int    DT_StdvSwingDepth = 5;      // fractal half-width for swing-pivot detection on DT_SigTF
input int    DT_StdvLookback   = 60;     // DT_SigTF bars back to find the last swing (manipulation) leg

//====================== DONCHIAN inputs (DN_) ======================
// v2: 3rd sleeve - classic Turtle 20-bar close breakout on M15, symmetric long/short.
// Diversifier: profits in 5/6 of Plan C (FIX09+DTREND) losing months. Corr with PC -0.026.
input long   DN_Magic              = 20260903;   // distinct from FIX_Magic + DT_Magic (NOTE: kept < 2^31 to avoid int32 overflow in MT5 tester)
input double DN_FixedLot           = 0.02;
input int    DN_MaxTradesPerDay    = 3;
input int    DN_BreakoutLookback   = 20;             // 20-bar Donchian close
input int    DN_ATRPeriod          = 14;
input double DN_SL_ATR             = 2.0;            // SL = entry -/+ 2*ATR
input double DN_TP_Rmultiple       = 3.0;            // TP = entry +/- 3R
input double DN_MaxSpreadPrice     = 0.60;
input int    DN_SessionStartHour   = 8;              // entries 08:00-22:00 server
input int    DN_SessionEndHour     = 22;
input bool   DN_BlockFridayEvening = true;
input int    DN_FridayBlockHour    = 20;

//====================== shared / master state ======================
double   g_initBal=0, g_comboDayStartBal=0;
datetime g_comboDayStart=0;
bool     g_comboHalted=false;
bool     g_dailyFlattenedToday=false;   // v2 BUG FIX: after master daily flatten, block ALL new entries rest of day (prevents Sep-02-style compounding)
bool     g_funded=false;            // resolved in OnInit: is Funded (Goat Guard) mode active on this account?
bool     g_blockHour[24];
int      g_hMTF[4];                 // MTF EMA handles (M15,H1,H4,D1)
ENUM_TIMEFRAMES g_mtftf[4];         // MTF ladder timeframes (set in OnInit)

//====================== FIX09 state (F_) ===========================
int      F_hEmaHTF,F_hEmaLTF,F_hAtr;
datetime F_lastBarTime=0,F_dayStart=0;
double   F_dayStartBal=0,F_oneR_money=0;
int      F_tradesToday=0; bool F_beActivated=false; datetime F_beTryBar=0;
double   F_peakR=0;                  // seq190/192: highest favorable R reached by the current FIX09 position (reset on fill / when flat)
int      F_cSpread=0,F_cReject=0;
int      F_nRevExit=0;               // seq192 chip C: count of trades harvested by the reversal-exit
string   FGK_DAY,FGK_BAL,FGK_TRD;

//====================== DTREND state (D_) ==========================
int      D_hFast,D_hSlow,D_hAtr,D_hADXreg,D_hHTF;
datetime D_sigBarTime=0;
int      D_nBuy=0,D_nExit=0,D_cFlatDown=0,D_cChop=0,D_cHTF=0,D_cSpread=0,D_cRiskSkip=0;
int      D_cStdvNoTgt=0,D_nStdvTP=0;   // seq215: trades with no valid STDV target (kept trailing) / trades given a measured STDV target

//====================== DONCHIAN state (DN_) =======================
int      DN_hAtr = INVALID_HANDLE;
datetime DN_lastBarTime = 0;
int      DN_tradesToday = 0;
int      DN_todayYmd = 0;
int      DN_nBuy = 0, DN_nSell = 0, DN_cRiskSkip = 0, DN_cSpread = 0, DN_cSession = 0;

//===================================================================
//  FIX09 functions
//===================================================================
double F_ATR(){ double b[]; if(CopyBuffer(F_hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
double F_EmaHTF(int s){ double b[]; if(CopyBuffer(F_hEmaHTF,0,s,1,b)<=0)return(0); return(b[0]); }
double F_EmaLTF(int s){ double b[]; if(CopyBuffer(F_hEmaLTF,0,s,1,b)<=0)return(0); return(b[0]); }
bool F_IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=F_lastBarTime){ F_lastBarTime=t; return(true);} return(false); }
bool F_MarketOpen(){
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int sec=dt.hour*3600+dt.min*60+dt.sec;
   datetime from,to; bool any=false;
   for(uint i=0;i<10;i++){ if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)dt.day_of_week,i,from,to)) break; any=true; if(sec>=(int)from && sec<(int)to) return(true); }
   if(!any) return(true); return(false);
}
double F_FixedLot(){
   double lot=(g_funded? Combo_FundedFixLot : FIX_FixedLot);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathRound(lot/st)*st;
   if(lot<mn) lot=mn; if(lot>FIX_MaxLot) lot=FIX_MaxLot; if(mx>0 && lot>mx) lot=mx;
   lot=G_ClampLotToMargin(lot);   // seq208: never exceed the GFT margin ceiling
   return(lot);
}
void F_LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0); datetime gday=(datetime)GlobalVariableGet(FGK_DAY);
   if(gday==today && today>0){ F_dayStart=today; F_dayStartBal=GlobalVariableGet(FGK_BAL); F_tradesToday=(int)GlobalVariableGet(FGK_TRD); }
   else { F_dayStart=today; F_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); F_tradesToday=0;
      GlobalVariableSet(FGK_DAY,(double)today); GlobalVariableSet(FGK_BAL,F_dayStartBal); GlobalVariableSet(FGK_TRD,0); }
   F_oneR_money=F_dayStartBal*(FIX_RiskPercent/100.0);
}
void F_NewDay(){ F_dayStart=iTime(_Symbol,PERIOD_D1,0); F_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); F_oneR_money=F_dayStartBal*(FIX_RiskPercent/100.0); F_tradesToday=0;
   GlobalVariableSet(FGK_DAY,(double)F_dayStart); GlobalVariableSet(FGK_BAL,F_dayStartBal); GlobalVariableSet(FGK_TRD,0); }
double F_RealizedRToday(){
   if(F_oneR_money<=0)return(0); double pl=0; if(!HistorySelect(F_dayStart,TimeCurrent()))return(0);
   int tdl=HistoryDealsTotal();
   for(int i=0;i<tdl;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=FIX_Magic)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      pl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_FEE); }
   return(pl/F_oneR_money);
}
bool F_TradingAllowed(){ double r=F_RealizedRToday(); if(FIX_DailyProfitStopR>0&&r>=FIX_DailyProfitStopR)return(false); if(FIX_DailyLossStopR>0&&r<=-FIX_DailyLossStopR)return(false); if(F_tradesToday>=FIX_MaxTradesPerDay)return(false); return(true); }
int F_MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==FIX_Magic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong F_GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==FIX_Magic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
bool F_RecentBreakUp(){ for(int s=1;s<=FIX_BreakoutMaxAge;s++){ int hi=iHighest(_Symbol,FIX_HTF,MODE_HIGH,FIX_BreakoutLookback,s+1); if(hi<0)continue; if(iClose(_Symbol,FIX_HTF,s)>iHigh(_Symbol,FIX_HTF,hi))return(true);} return(false); }
bool F_RecentBreakDown(){ for(int s=1;s<=FIX_BreakoutMaxAge;s++){ int lo=iLowest(_Symbol,FIX_HTF,MODE_LOW,FIX_BreakoutLookback,s+1); if(lo<0)continue; if(iClose(_Symbol,FIX_HTF,s)<iLow(_Symbol,FIX_HTF,lo))return(true);} return(false); }
void F_CountIfFilled(bool sent){
   uint rc=tf.ResultRetcode(); bool filled = sent && (rc==TRADE_RETCODE_DONE||rc==TRADE_RETCODE_DONE_PARTIAL) && tf.ResultDeal()!=0;
   if(filled){ F_tradesToday++; F_beActivated=false; F_peakR=0; GlobalVariableSet(FGK_TRD,F_tradesToday); } else { F_cReject++; }
}
void F_OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=F_FixedLot(); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=tf.Buy(lots,_Symbol,0,sl,tp); F_CountIfFilled(s); }
void F_OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=F_FixedLot(); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=tf.Sell(lots,_Symbol,0,sl,tp); F_CountIfFilled(s); }
void F_ProfitLockManage(){
   // seq190: ratcheting give-back trail. Once peakR>=1.0R, lock SL = entry +/- (peakR - G)*R; move only in the profit direction (ratchet). TP kept. Acts only in profit -> initial stop/lot/gap unchanged (gap-neutral).
   ulong tk=F_GetMyTicket(); if(tk==0){ F_peakR=0; return; } if(!PositionSelectByTicket(tk))return; if(!F_MarketOpen())return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double R=MathAbs(tp-open)/((FIX_RR>0)?FIX_RR:1.0); if(R<=0)return;
   if(type==POSITION_TYPE_BUY){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double curR=(bid-open)/R; if(curR>F_peakR)F_peakR=curR;
      if(F_peakR>=1.0){ double newSL=NormalizeDouble(open+(F_peakR-FIX_ProfitLockGiveBackR)*R,dg);
         if(newSL>sl+point*0.5 && newSL<bid) tf.PositionModify(tk,newSL,tp); }
   } else if(type==POSITION_TYPE_SELL){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double curR=(open-ask)/R; if(curR>F_peakR)F_peakR=curR;
      if(F_peakR>=1.0){ double newSL=NormalizeDouble(open-(F_peakR-FIX_ProfitLockGiveBackR)*R,dg);
         if((sl==0.0||newSL<sl-point*0.5) && newSL>ask) tf.PositionModify(tk,newSL,tp); }
   }
}
void F_ReversalExitManage(){
   // seq192 chip C: harvest profit on a genuine adverse reversal. Track peakR; arm after peakR>=ArmR. Close at MARKET only if current profit retraced > GiveBackFrac of the peak profit AND the just-closed M15 bar closed against the trade. Never trails the SL, so runners that keep advancing (peak keeps making new highs, no give-back) never trigger.
   ulong tk=F_GetMyTicket(); if(tk==0){ F_peakR=0; return; } if(!PositionSelectByTicket(tk))return; if(!F_MarketOpen())return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE);
   double R=MathAbs(tp-open)/((FIX_RR>0)?FIX_RR:1.0); if(R<=0)return;
   // favorable excursion in R, using current price
   double curR;
   if(type==POSITION_TYPE_BUY)  curR=(SymbolInfoDouble(_Symbol,SYMBOL_BID)-open)/R;
   else                         curR=(open-SymbolInfoDouble(_Symbol,SYMBOL_ASK))/R;
   if(curR>F_peakR) F_peakR=curR;
   if(F_peakR<FIX_ReversalExitArmR) return;                 // not armed yet
   if(curR<=0) return;                                      // only ever close while still in profit
   // give-back: how much of the peak profit has been surrendered
   if(curR > F_peakR*(1.0-FIX_ReversalExitGiveBackFrac)) return;   // still holding most of the peak -> keep running
   // confirm with a closed M15 bar against the trade (act once per bar)
   datetime cb=iTime(_Symbol,PERIOD_CURRENT,0); if(F_beTryBar==cb) return;
   double o1=iOpen(_Symbol,PERIOD_CURRENT,1), c1=iClose(_Symbol,PERIOD_CURRENT,1);
   bool barAgainst=(type==POSITION_TYPE_BUY)? (c1<o1) : (c1>o1);
   if(!barAgainst) return;
   F_beTryBar=cb; if(tf.PositionClose(tk)){ F_nRevExit++; }
}
void F_ManageTrade(){
   if(F_MyPositions()==0){ F_beActivated=false; F_peakR=0; return; }
   if(FIX_UseReversalExit){ F_ReversalExitManage(); return; } // seq192 chip C: harvest-on-reversal overrides one-shot BE
   if(FIX_UseProfitLock){ F_ProfitLockManage(); return; }   // seq190 treatment: ratchet lock overrides the one-shot BE
   if(!FIX_UseBreakEven)return;
   ulong tk=F_GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(F_beActivated)return; if(!F_MarketOpen())return; datetime cb=iTime(_Symbol,PERIOD_CURRENT,0); if(F_beTryBar==cb)return; double prog=0;
   if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(tp-open<=0)return; prog=(bid-open)/(tp-open); if(prog>=FIX_BEProgress&&sl<open){ F_beTryBar=cb; if(tf.PositionModify(tk,NormalizeDouble(open,dg),tp))F_beActivated=true; } }
   else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(open-tp<=0)return; prog=(open-ask)/(open-tp); if(prog>=FIX_BEProgress&&sl>open){ F_beTryBar=cb; if(tf.PositionModify(tk,NormalizeDouble(open,dg),tp))F_beActivated=true; } }
}
void F_Tick(){
   if(iTime(_Symbol,PERIOD_D1,0)!=F_dayStart) F_NewDay();
   F_ManageTrade();
   if(!F_IsNewBar())return;
   if(F_MyPositions()>0)return;
   if(G_OpenSlotBlocked()){ F_cReject++; return; }   // seq204: DTREND already holds the only allowed slot
   if(G_NewsBlocked()){ F_cReject++; return; }       // rule 6b: high-impact release inside the window
   if(G_EntryHourBlocked())return;   // blocked hour: NO new entry (any running FIX09 trade was already managed above)
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(FIX_MaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ F_cSpread++; return; }
   if(!F_MarketOpen()) return;
   if(!F_TradingAllowed())return;
   double atr=F_ATR(); if(atr<=0)return; double buf=FIX_SLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1),o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,2),l2=iLow(_Symbol,PERIOD_CURRENT,2);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1),hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaL=F_EmaLTF(1),closeH1=iClose(_Symbol,FIX_HTF,1),emaH=F_EmaHTF(1);
   if((closeH1>emaH) && F_RecentBreakUp() && (lo1<=emaL) && (c1>o1)&&(c1>emaL)&&(c1>h2)){
      if(FIX_UseEntryRoom && (c1-h2) < FIX_EntryRoomATR*atr){ F_cReject++; return; }   // seq194 chip A: breakout bar must have TRAVELLED past the broken high, not just tagged it
      double sl=MathMin(lo1,l2)-buf; double a2=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=a2-sl;
      if(risk>0 && risk<=FIX_MaxSL_ATR*atr){
         if(g_funded && Combo_FundedMaxSLpts>0 && risk>Combo_FundedMaxSLpts){ F_cReject++; return; }   // FUNDED: SL too wide -> skip (avoids big losses / stop-hunts on volatile days)
         if(Combo_UseMTF && G_MTFScore() < Combo_MTF_MinScore){ F_cReject++; return; }   // MTF: only BUY with the higher-TF uptrend
         if(G_RiskBlocksEntry(risk*G_MPP()*F_FixedLot())){ F_cReject++; return; }
         F_OpenBuy(sl,a2+FIX_RR*risk); return; } }
   if((closeH1<emaH) && F_RecentBreakDown() && (hi1>=emaL) && (c1<o1)&&(c1<emaL)&&(c1<l2)){
      if(FIX_UseEntryRoom && (l2-c1) < FIX_EntryRoomATR*atr){ F_cReject++; return; }   // seq194 chip A: breakdown bar must have TRAVELLED past the broken low, not just tagged it
      double sl=MathMax(hi1,h2)+buf; double b2=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-b2;
      if(risk>0 && risk<=FIX_MaxSL_ATR*atr){
         if(g_funded && Combo_FundedMaxSLpts>0 && risk>Combo_FundedMaxSLpts){ F_cReject++; return; }   // FUNDED: SL too wide -> skip
         if(Combo_UseMTF && G_MTFScore() > -Combo_MTF_MinScore){ F_cReject++; return; }   // MTF: only SELL with the higher-TF downtrend
         if(G_RiskBlocksEntry(risk*G_MPP()*F_FixedLot())){ F_cReject++; return; }
         F_OpenSell(sl,b2-FIX_RR*risk); } }
}

//===================================================================
//  DTREND functions
//===================================================================
double D_ADXreg(){ double b[]; if(CopyBuffer(D_hADXreg,0,1,1,b)<=0)return(0); return(b[0]); }
bool D_HTFbull(){ if(!DT_UseHTFtrend) return(true); double b[]; if(CopyBuffer(D_hHTF,0,1,1,b)<=0) return(true); double e=b[0]; double c=iClose(_Symbol,DT_HTFtrendTF,1); return(e>0 && c>e); }
double D_ChoppinessIndex(ENUM_TIMEFRAMES tfx,int n){
   if(n<2) return(50.0); double sumTR=0, hh=-DBL_MAX, ll=DBL_MAX;
   for(int i=1;i<=n;i++){ double h=iHigh(_Symbol,tfx,i), l=iLow(_Symbol,tfx,i), pc=iClose(_Symbol,tfx,i+1); if(h==0||l==0) return(50.0);
      double tr=MathMax(h-l,MathMax(MathAbs(h-pc),MathAbs(l-pc))); sumTR+=tr; if(h>hh)hh=h; if(l<ll)ll=l; }
   double rng=hh-ll; if(rng<=0||sumTR<=0) return(50.0); return(100.0*MathLog10(sumTR/rng)/MathLog10((double)n));
}
bool D_NotChoppy(){ if(!DT_UseChop) return(true); double ci=D_ChoppinessIndex(DT_ChopTF,DT_ChopPeriod); return(ci < DT_ChopMax); }
double D_ATRv(){ double b[]; if(CopyBuffer(D_hAtr,0,1,1,b)<=0)return(0); return(b[0]); }
double D_Fast1(){ double b[]; if(CopyBuffer(D_hFast,0,1,1,b)<=0)return(0); return(b[0]); }
double D_Slow1(){ double b[]; if(CopyBuffer(D_hSlow,0,1,1,b)<=0)return(0); return(b[0]); }
bool D_KAMA_bull(){
   int need=DT_KAMA_ER+80; double cl[]; ArraySetAsSeries(cl,false);
   int got=CopyClose(_Symbol,DT_SigTF,1,need,cl); if(got<DT_KAMA_ER+5) return(false);
   double fastSC=2.0/(DT_KAMA_Fast+1.0), slowSC=2.0/(DT_KAMA_Slow+1.0); double kama=cl[0]; double kprev=kama;
   for(int i=DT_KAMA_ER;i<got;i++){ double change=MathAbs(cl[i]-cl[i-DT_KAMA_ER]); double vol=0; for(int j=i-DT_KAMA_ER+1;j<=i;j++) vol+=MathAbs(cl[j]-cl[j-1]);
      double er=(vol>0)?change/vol:0.0; double sc=MathPow(er*(fastSC-slowSC)+slowSC,2.0); kprev=kama; kama=kama+sc*(cl[i]-kama); }
   return(kama>kprev);
}
bool D_IsBull(){ bool emaBull=(D_Fast1()>D_Slow1() && D_Slow1()>0); if(DT_Engine==0) return(emaBull); bool kamaBull=D_KAMA_bull(); if(DT_Engine==1) return(kamaBull); return(emaBull && kamaBull); }
bool D_IsNewSigBar(){ datetime t=iTime(_Symbol,DT_SigTF,0); if(t!=D_sigBarTime){ D_sigBarTime=t; return(true);} return(false); }
int D_MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==DT_Magic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong D_GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==DT_Magic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
double D_MoneyPerPricePerLot(){ double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE); double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); double byTick=(ts>0)? tv/ts : 0.0; if(cs>0) return(cs); return(byTick); }
double D_CalcLot(double slDist){
   double mpp=D_MoneyPerPricePerLot(); if(mpp<=0||slDist<=0)return(0);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); double maxRisk=bal*(DT_MaxRiskPerTradePct/100.0);
   double lot;
   if(g_funded && Combo_FundedGapSizing){
      // seq188: gap-budgeted sizing -> worst-case (SL distance + assumed gap) * lot * mpp <= budget. Wide stop => gap is a small fraction => more size for the same $ risk.
      double denom=(slDist+Combo_FundedGapUsd)*mpp; if(denom<=0) return(0);
      lot=Combo_FundedTradeBudgetUsd/denom;
   } else {
      double rp=(g_funded? Combo_FundedRiskPct : DT_RiskPercent); double riskMoney=bal*(rp/100.0);
      if(riskMoney>maxRisk) riskMoney=maxRisk; lot=riskMoney/(slDist*mpp);
   }
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathFloor(lot/st)*st;
   if(lot<mn){ if(slDist*mn*mpp > maxRisk) return(0); lot=mn; }
   if(lot>DT_MaxLot) lot=DT_MaxLot; if(mx>0&&lot>mx)lot=mx;
   if(slDist*lot*mpp > maxRisk*1.05) return(0);
   lot=G_ClampLotToMargin(lot);   // seq208: never exceed the GFT margin ceiling
   return(lot);
}
void D_CloseMyLong(){ ulong tk=D_GetMyTicket(); if(tk==0)return; if(td.PositionClose(tk)){ D_nExit++; } }
// seq215 IDEA-104: measured-move STDV target for a LONG DTREND entry. Faithful to LumiTraders
// "STANDARD DEVIATION PROJECTIONS": take the last swing leg on DT_SigTF (the manipulation leg,
// swingLow->swingHigh) and project DT_StdvMult x its length up from the swing low. 1 STDV = the leg
// itself (reaches swingHigh), 2.5 STDV sits 1.5 legs above it - the author's gold interest band.
// Returns 0 if no valid swing is found or the projected target is not above the ask (never a TP
// below price; that trade then keeps the proven ATR runner-trail).
double D_StdvTargetLong(double ask){
   int L=DT_StdvSwingDepth; if(L<1) L=1;
   int look=DT_StdvLookback; if(look<L*2+2) look=L*2+2;
   int need=look+L+2;
   double hi[],lo[]; ArraySetAsSeries(hi,true); ArraySetAsSeries(lo,true);
   if(CopyHigh(_Symbol,DT_SigTF,1,need,hi)<need) return(0);
   if(CopyLow(_Symbol,DT_SigTF,1,need,lo)<need) return(0);
   int lowIdx=-1;
   for(int i=L; i<=look && i+L<need; i++){
      bool piv=true;
      for(int k=1;k<=L && piv;k++){ if(lo[i]>lo[i-k] || lo[i]>lo[i+k]) piv=false; }
      if(piv){ lowIdx=i; break; }
   }
   if(lowIdx<1) return(0);
   double swingLow=lo[lowIdx];
   double swingHigh=-DBL_MAX;
   for(int i=lowIdx-1;i>=1;i--){ if(hi[i]>swingHigh) swingHigh=hi[i]; }
   if(swingHigh<=swingLow) return(0);
   double leg=swingHigh-swingLow; if(leg<=0) return(0);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double tp=NormalizeDouble(swingLow+DT_StdvMult*leg,dg);
   if(tp<=ask) return(0);
   return(tp);
}
void D_TrailStop(){
   if(!DT_UseTrailATR)return; ulong tk=D_GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   if(DT_UseStdvTP && PositionGetDouble(POSITION_TP)>0) return;   // seq215: a measured STDV target is set -> let it work, no ATR trail
   double atr=D_ATRv(); if(atr<=0)return; double px=iClose(_Symbol,DT_SigTF,1); double newSL=px-DT_TrailATR*atr;
   double sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); newSL=NormalizeDouble(newSL,dg);
   if(newSL>sl && newSL<SymbolInfoDouble(_Symbol,SYMBOL_BID)) td.PositionModify(tk,newSL,tp);
}
void D_OpenLong(){
   if(Combo_UseMTF && G_MTFScore() < Combo_MTF_MinScore){ D_cRiskSkip++; return; }   // MTF: only go long with the higher-TF uptrend
   double atr=D_ATRv(); if(atr<=0)return; double slDist=DT_SL_ATR*atr; if(slDist<=0)return;
   if(g_funded && Combo_FundedMaxSLpts>0 && slDist>Combo_FundedMaxSLpts){ D_cRiskSkip++; return; }   // FUNDED: SL too wide -> skip (avoids combined Goat-Guard stacking)
   double mpp=D_MoneyPerPricePerLot(); double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxRisk=AccountInfoDouble(ACCOUNT_BALANCE)*(DT_MaxRiskPerTradePct/100.0); double riskAtMin=slDist*mn*mpp;
   if(riskAtMin>maxRisk){ if(DT_CapStopToRisk){ if(mn*mpp>0) slDist=maxRisk/(mn*mpp); } else { D_cRiskSkip++; return; } }
   double lot=D_CalcLot(slDist); if(lot<=0){ D_cRiskSkip++; return; }
   if(G_RiskBlocksEntry(slDist*D_MoneyPerPricePerLot()*lot)){ D_cRiskSkip++; return; }
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double sl=ask-slDist; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg);
   double tp=0.0;
   if(DT_UseStdvTP){ tp=D_StdvTargetLong(ask); if(tp>0) D_nStdvTP++; else D_cStdvNoTgt++; }   // seq215: measured STDV target (0 -> keep the runner trail)
   if(td.Buy(lot,_Symbol,0,sl,tp)){ D_nBuy++; }
}
void D_Tick(){
   D_TrailStop();
   if(!D_IsNewSigBar())return;
   bool bull=D_IsBull();
   if(D_MyPositions()>0){ if(!bull){ D_CloseMyLong(); D_cFlatDown++; } return; }
   if(G_OpenSlotBlocked()){ D_cRiskSkip++; return; }   // seq204: FIX09 already holds the only allowed slot
   if(G_NewsBlocked()){ D_cRiskSkip++; return; }       // rule 6b: high-impact release inside the window
   if(G_EntryHourBlocked())return;   // blocked hour: NO new entry (running DTREND trade + trail already handled above)
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(DT_MaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ D_cSpread++; return; }
   if(DT_UseRegime && D_ADXreg() < DT_ADXTrendMin){ D_cChop++; return; }
   if(DT_UseHTFtrend && !D_HTFbull()){ D_cHTF++; return; }
   if(DT_UseChop && !D_NotChoppy()){ return; }
   if(bull) D_OpenLong();
}

//===================================================================
//  DONCHIAN functions (v2 3rd sleeve)
//===================================================================
double DN_ATR(){ double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(DN_hAtr,0,0,1,b)<=0) return(0); return(b[0]); }
bool DN_IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_M15,0); if(t!=DN_lastBarTime){ DN_lastBarTime=t; return(true);} return(false); }
int DN_MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==DN_Magic && PositionGetString(POSITION_SYMBOL)==_Symbol) c++; } return(c); }

bool DN_WithinSession(){
   MqlDateTime mt; TimeToStruct(TimeCurrent(),mt);
   if(mt.hour < DN_SessionStartHour) return(false);
   if(mt.hour > DN_SessionEndHour) return(false);
   if(mt.hour == DN_SessionEndHour && mt.min > 0) return(false);
   return(true);
}
bool DN_FridayEveningBlocked(){
   if(!DN_BlockFridayEvening) return(false);
   MqlDateTime mt; TimeToStruct(TimeCurrent(),mt);
   if(mt.day_of_week==5 && mt.hour>=DN_FridayBlockHour) return(true);
   return(false);
}

// Returns 1 = LONG signal, -1 = SHORT signal, 0 = none. Evaluates on M15 bar close (bar 1).
int DN_CheckBreakout(){
   int lb=DN_BreakoutLookback;
   double closes[]; ArraySetAsSeries(closes,false);
   if(CopyClose(_Symbol,PERIOD_M15,2,lb,closes)<lb) return(0);
   double c1=iClose(_Symbol,PERIOD_M15,1);
   double ref_hi=closes[0], ref_lo=closes[0];
   for(int i=1;i<lb;i++){ if(closes[i]>ref_hi) ref_hi=closes[i]; if(closes[i]<ref_lo) ref_lo=closes[i]; }
   if(c1>ref_hi) return(1);
   if(c1<ref_lo) return(-1);
   return(0);
}

double DN_FixedLotAdjusted(){
   double lot=DN_FixedLot;
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathFloor(lot/st)*st;
   if(lot<mn) lot=mn; if(mx>0 && lot>mx) lot=mx;
   lot=G_ClampLotToMargin(lot);
   return(lot);
}

void DN_OpenTrade(int direction){
   if(DN_MyPositions()>0) return;
   if(DN_tradesToday>=DN_MaxTradesPerDay) return;
   if(!DN_WithinSession()){ DN_cSession++; return; }
   if(DN_FridayEveningBlocked()){ DN_cSession++; return; }
   if(G_OpenSlotBlocked()){ DN_cRiskSkip++; return; }   // 3% funded rule via master guard
   if(G_NewsBlocked()){ DN_cRiskSkip++; return; }
   // v2 BUG FIX #2: honor Combo_BlockEntryHours (FIX09 and DTREND already do; Donchian was missing this).
   // Root cause of Sep-02-2026 −$497 breach: Sep-1 21:45 Donchian SELL stacked on Sep-1 18:00 FIX09 SELL;
   // extending block-hours to include evening now prevents the late-day stack that carried into next day.
   if(G_EntryHourBlocked()){ DN_cSession++; return; }
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(DN_MaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ DN_cSpread++; return; }

   double atr=DN_ATR(); if(atr<=0) return;
   double sl_dist=DN_SL_ATR*atr;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   double entry_px, sl_px, tp_px;
   if(direction>0){ entry_px=ask; sl_px=entry_px-sl_dist; tp_px=entry_px+DN_TP_Rmultiple*sl_dist; }
   else            { entry_px=bid; sl_px=entry_px+sl_dist; tp_px=entry_px-DN_TP_Rmultiple*sl_dist; }

   double lot=DN_FixedLotAdjusted(); if(lot<=0){ DN_cRiskSkip++; return; }
   // per-trade + predictive daily governor via master guard
   if(G_RiskBlocksEntry(sl_dist*G_MPP()*lot)){ DN_cRiskSkip++; return; }

   sl_px=NormalizeDouble(sl_px,dg);
   tp_px=NormalizeDouble(tp_px,dg);

   bool ok=false;
   if(direction>0) ok=dn.Buy(lot,_Symbol,0,sl_px,tp_px,"DONCHIAN_L");
   else            ok=dn.Sell(lot,_Symbol,0,sl_px,tp_px,"DONCHIAN_S");

   if(ok){ DN_tradesToday++; if(direction>0) DN_nBuy++; else DN_nSell++; }
}

void DN_Tick(){
   if(!DN_IsNewBar()) return;
   // Daily reset based on M15 bar's date
   MqlDateTime mt; TimeToStruct(iTime(_Symbol,PERIOD_M15,0),mt);
   int today_ymd=mt.year*10000 + mt.mon*100 + mt.day;
   if(today_ymd != DN_todayYmd){ DN_todayYmd=today_ymd; DN_tradesToday=0; }
   // Signal check
   int signal=DN_CheckBreakout();
   if(signal==0) return;
   DN_OpenTrade(signal);
}

//===================================================================
//  Master account guard
//===================================================================
double G_EquityDDfromInit(){ if(g_initBal<=0)return(0); double eq=AccountInfoDouble(ACCOUNT_EQUITY); return(100.0*(g_initBal-eq)/g_initBal); }
double G_DailyRef(){ return((Combo_DailyRefInitial && g_initBal>0) ? g_initBal : g_comboDayStartBal); }   // seq220: daily-loss % reference (INITIAL vs day-start). Loss is always the drop from day-start; only the % denominator changes.
double G_DayLossPct(){ double ref=G_DailyRef(); if(ref<=0)return(0); double eq=AccountInfoDouble(ACCOUNT_EQUITY); return(100.0*(g_comboDayStartBal-eq)/ref); }
void G_CloseAllBoth(){
   // v2: renamed conceptually to CloseAllThree - now includes Donchian
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; long mg=PositionGetInteger(POSITION_MAGIC);
      if(mg==FIX_Magic){ tf.PositionClose(tk); }
      else if(mg==DT_Magic){ td.PositionClose(tk); }
      else if(mg==DN_Magic){ dn.PositionClose(tk); } }
}
void G_NewComboDay(){ g_comboDayStart=iTime(_Symbol,PERIOD_D1,0); g_comboDayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); g_dailyFlattenedToday=false; }   // v2: reset flatten lockout on new day
void G_ParseBlockHours(){
   for(int i=0;i<24;i++) g_blockHour[i]=false;
   string parts[]; int n=StringSplit(Combo_BlockEntryHours,',',parts);
   for(int i=0;i<n;i++){ string s=parts[i]; StringTrimLeft(s); StringTrimRight(s); if(StringLen(s)==0)continue; int h=(int)StringToInteger(s); if(h>=0 && h<24) g_blockHour[h]=true; }
}
bool G_EntryHourBlocked(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); return(g_blockHour[dt.hour]); }
double G_MPP(){ double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); if(cs>0)return(cs); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); return(ts>0? tv/ts : 0.0); }
// Block a NEW entry if its worst-case SL loss would (a) exceed the per-trade cap, or
// (b) push today's loss past the buffered daily cap. Running trades are NOT touched.
// seq276b: also considers COMBINED SL risk of existing open positions to prevent multi-position disasters.
bool G_RiskBlocksEntry(double riskMoney){
   // v2 BUG FIX: after master daily flatten fires, no new entries the rest of the day
   // (regardless of what any single sleeve's own counters say - the master is authoritative)
   if(g_dailyFlattenedToday) return(true);
   double ref=G_DailyRef(); if(ref<=0) ref=(g_comboDayStartBal>0? g_comboDayStartBal : g_initBal);   // seq220: initial vs day-start daily reference
   if(ref<=0 || riskMoney<=0) return(false);
   if(g_funded){
      // FUNDED: per-trade cap referenced to INITIAL (Goat Guard is measured on initial)
      if(g_initBal>0 && riskMoney > Combo_FundedPerTradePct/100.0*g_initBal) return(true);
   } else if(Combo_UsePerTradeCap && riskMoney > Combo_PerTradeMaxRiskPct/100.0*ref) return(true);
   if(Combo_UsePredictiveDaily){
      double usedToday=MathMax(0.0, g_comboDayStartBal-AccountInfoDouble(ACCOUNT_EQUITY));
      // seq276b: include existing open positions' SL risk in the combined check
      double existingSLRisk = G_OpenSLRisk();
      if(usedToday + existingSLRisk + riskMoney > Combo_DailyBufferPct/100.0*ref) return(true);
   }
   return(false);
}
// MULTI-TIMEFRAME alignment: +1 per bull TF, -1 per bear TF across the ladder (range -4..+4).
// Uses last CLOSED bar: close > EMA = bull. Higher score = stronger multi-TF uptrend agreement.
int G_MTFScore(){
   int sc=0;
   for(int i=0;i<4;i++){ double b[]; if(CopyBuffer(g_hMTF[i],0,1,1,b)<=0) continue; double ema=b[0]; if(ema<=0) continue; double c=iClose(_Symbol,g_mtftf[i],1); if(c<=0) continue; sc += (c>ema? 1 : -1); }
   return(sc);
}
// v2: total open positions across ALL THREE sleeves. FN 3% funded rule sums them.
int G_MyOpenTotal(){
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; long mg=PositionGetInteger(POSITION_MAGIC);
      if(mg==FIX_Magic || mg==DT_Magic || mg==DN_Magic) c++; }
   return(c);
}
bool G_OpenSlotBlocked(){
   if(!g_funded) return(false);
   if(Combo_FundedMaxOpenTotal<=0) return(false);
   return(G_MyOpenTotal() >= Combo_FundedMaxOpenTotal);
}

// seq208: clamp a proposed lot so margin used stays inside Combo_MaxMarginPct of equity.
// Uses MT5's OrderCalcMargin so the BROKER's own margin rate applies - we never assume one. Margin
// already consumed by open positions is subtracted, because the firm's ceiling is on total usage.
// Returns 0 when even the minimum lot cannot fit, in which case callers must skip the trade
// (F_OpenBuy/F_OpenSell and D_OpenLong all already bail on lot<=0).
double G_ClampLotToMargin(double lot){
   if(Combo_MaxMarginPct<=0 || lot<=0) return(lot);
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0) return(lot);
   double used=AccountInfoDouble(ACCOUNT_MARGIN);
   double budget=eq*(Combo_MaxMarginPct/100.0)-used;
   if(budget<=0) return(0.0);
   double px=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(px<=0) return(lot);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st<=0) st=0.01; if(mn<=0) mn=0.01;
   double need=0.0;
   for(int guard=0; guard<1000; guard++){
      if(lot<mn-1e-9) return(0.0);
      if(!OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,lot,px,need)) return(lot); // cannot compute -> do not silently shrink
      if(need<=budget) return(NormalizeDouble(lot,2));
      lot=NormalizeDouble(lot-st,2);
   }
   return(0.0);
}

// rule 6b: is a high-impact release inside the block window? Uses the MQL5 economic calendar.
// If the calendar is unavailable (some tester/terminal setups), this returns false and the gate
// simply does nothing - it never blocks on absent data, and never pretends the check happened.
bool G_NewsBlocked(){
   if(!Combo_UseNewsGate) return(false);
   datetime now=TimeCurrent();
   int win=Combo_NewsBlockMin*60;
   MqlCalendarValue vals[];
   int n=CalendarValueHistory(vals,now-win,now+win);
   if(n<=0) return(false);
   for(int i=0;i<n;i++){
      MqlCalendarEvent ev;
      if(!CalendarEventById(vals[i].event_id,ev)) continue;
      if(ev.importance!=CALENDAR_IMPORTANCE_HIGH) continue;
      return(true);
   }
   return(false);
}

// v2: combined FLOATING PnL of all THREE sleeves' open positions - used by FUNDED 3% pre-empt
double G_MyFloatingPnL(){
   double s=0;
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; long mg=PositionGetInteger(POSITION_MAGIC);
      if(mg!=FIX_Magic && mg!=DT_Magic && mg!=DN_Magic)continue; s+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP); }
   return(s);
}

// seq276b: combined worst-case SL risk of all open positions. Used to block new entries that would
// create multi-position overnight disasters like Sep 2 (−$497 from two concurrent SL hits).
double G_OpenSLRisk(){
   double mpp = G_MPP(); if(mpp <= 0) return(0);
   double totalRisk = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--){
      ulong tk = PositionGetTicket(i); if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(mg != FIX_Magic && mg != DT_Magic && mg != DN_Magic) continue;
      double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0) continue;  // no SL = skip (shouldn't happen)
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot = PositionGetDouble(POSITION_VOLUME);
      long posType = PositionGetInteger(POSITION_TYPE);
      double slDist = 0;
      if(posType == POSITION_TYPE_BUY)  slDist = openPrice - sl;
      else if(posType == POSITION_TYPE_SELL) slDist = sl - openPrice;
      if(slDist > 0) totalRisk += slDist * lot * mpp;
   }
   return(totalRisk);
}

//===================================================================
int OnInit(){
   tf.SetExpertMagicNumber(FIX_Magic); tf.SetDeviationInPoints(30); tf.SetTypeFillingBySymbol(_Symbol); tf.LogLevel(LOG_LEVEL_NO);
   td.SetExpertMagicNumber(DT_Magic);  td.SetDeviationInPoints(30); td.SetTypeFillingBySymbol(_Symbol); td.LogLevel(LOG_LEVEL_NO);
   dn.SetExpertMagicNumber(DN_Magic);  dn.SetDeviationInPoints(30); dn.SetTypeFillingBySymbol(_Symbol); dn.LogLevel(LOG_LEVEL_NO);
   // FIX09 handles
   F_hEmaHTF=iMA(_Symbol,FIX_HTF,FIX_TrendEMA,0,MODE_EMA,PRICE_CLOSE);
   F_hEmaLTF=iMA(_Symbol,PERIOD_CURRENT,FIX_EntryEMA,0,MODE_EMA,PRICE_CLOSE);
   F_hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   // DTREND handles
   D_hFast=iMA(_Symbol,DT_SigTF,DT_FastEMA,0,MODE_EMA,PRICE_CLOSE);
   D_hSlow=iMA(_Symbol,DT_SigTF,DT_SlowEMA,0,MODE_EMA,PRICE_CLOSE);
   D_hAtr =iATR(_Symbol,DT_SigTF,DT_ATRPeriod);
   D_hADXreg=iADX(_Symbol,DT_RegimeTF,DT_RegimeADXPeriod);
   D_hHTF=iMA(_Symbol,DT_HTFtrendTF,DT_HTFtrendEMA,0,MODE_EMA,PRICE_CLOSE);
   // DONCHIAN handle (M15 ATR for SL/TP)
   DN_hAtr=iATR(_Symbol,PERIOD_M15,DN_ATRPeriod);
   if(F_hEmaHTF==INVALID_HANDLE||F_hEmaLTF==INVALID_HANDLE||F_hAtr==INVALID_HANDLE||
      D_hFast==INVALID_HANDLE||D_hSlow==INVALID_HANDLE||D_hAtr==INVALID_HANDLE||D_hADXreg==INVALID_HANDLE||D_hHTF==INVALID_HANDLE||
      DN_hAtr==INVALID_HANDLE)
      return(INIT_FAILED);
   // MTF ladder handles (M15,H1,H4,D1) - EMA(Combo_MTF_EMA) on close
   g_mtftf[0]=PERIOD_M15; g_mtftf[1]=PERIOD_H1; g_mtftf[2]=PERIOD_H4; g_mtftf[3]=PERIOD_D1;
   for(int i=0;i<4;i++){ g_hMTF[i]=iMA(_Symbol,g_mtftf[i],Combo_MTF_EMA,0,MODE_EMA,PRICE_CLOSE); if(g_hMTF[i]==INVALID_HANDLE) return(INIT_FAILED); }
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol;
   FGK_DAY="ckcombo_fday_"+scope; FGK_BAL="ckcombo_fbal_"+scope; FGK_TRD="ckcombo_ftrd_"+scope;
   g_initBal=AccountInfoDouble(ACCOUNT_BALANCE);
   g_comboDayStart=iTime(_Symbol,PERIOD_D1,0); g_comboDayStartBal=g_initBal;
   F_LoadOrResetDaily();
   G_ParseBlockHours();
   g_funded = (Combo_Stage==1) || (Combo_FundedLogin>0 && AccountInfoInteger(ACCOUNT_LOGIN)==Combo_FundedLogin);
   PrintFormat("[COMBO_v2] init bal=%.2f login=%s MODE=%s  FIX09=%s DTREND=%s DONCHIAN=%s  staticDDstop=%.1f%% dailyLoss=%.1f%%",
               g_initBal,IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),(g_funded?"FUNDED":"EVAL"),
               (Combo_EnableFIX09?"on":"off"),(Combo_EnableDTREND?"on":"off"),(Combo_EnableDonchian?"on":"off"),
               Combo_StaticDDStopPct,Combo_DailyLossPct);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){
   IndicatorRelease(F_hEmaHTF);IndicatorRelease(F_hEmaLTF);IndicatorRelease(F_hAtr);
   IndicatorRelease(D_hFast);IndicatorRelease(D_hSlow);IndicatorRelease(D_hAtr);IndicatorRelease(D_hADXreg);IndicatorRelease(D_hHTF);
   if(DN_hAtr!=INVALID_HANDLE) IndicatorRelease(DN_hAtr);
}
void OnTick(){
   // 1) master account-level static-DD halt (whole account, GFT protection)
   if(Combo_UseStaticDD && !g_comboHalted && G_EquityDDfromInit()>=Combo_StaticDDStopPct){
      g_comboHalted=true; G_CloseAllBoth(); Print("[COMBO] MASTER STATIC-DD HALT");
   }
   if(g_comboHalted){ G_CloseAllBoth(); return; }
   // 1b) EVAL mode: pre-empt daily breach (5% of INITIAL) by flattening at combined floating loss cap (seq276 fix for Sep 2 −$497 disaster)
   if(!g_funded && g_initBal>0 && Combo_EvalFloatFlatPct>0 && G_MyFloatingPnL() <= -Combo_EvalFloatFlatPct/100.0*g_initBal){ G_CloseAllBoth(); Print("[COMBO] EVAL FLOAT CAP HIT - flatten all"); return; }
   // 1c) FUNDED only: pre-empt Goat Guard (2% of INITIAL combined FLOATING loss) by flattening at a buffer
   if(g_funded && g_initBal>0 && G_MyFloatingPnL() <= -Combo_FundedFloatFlatPct/100.0*g_initBal){ G_CloseAllBoth(); return; }
   // 2) combo day roll + daily-loss stop (whole account)
   if(iTime(_Symbol,PERIOD_D1,0)!=g_comboDayStart) G_NewComboDay();
   if(Combo_UseDailyLoss && G_DayLossPct()>=Combo_DailyLossPct){
      G_CloseAllBoth();
      g_dailyFlattenedToday=true;   // v2 BUG FIX: mark lockout so no re-entry rest of day
      return;
   }
   // 2b) IXU NO-WEEKEND-HOLDING: never hold over the weekend (close all + block entries Fri>=HH, all Sat, all Sun). day_of_week: 0=Sun,5=Fri,6=Sat
   if(Combo_WeekendFlat){
      MqlDateTime wkdt; TimeToStruct(TimeCurrent(),wkdt);
      if(wkdt.day_of_week==6 || wkdt.day_of_week==0 || (wkdt.day_of_week==5 && wkdt.hour>=Combo_WeekendFlatHour)){ G_CloseAllBoth(); return; }
   }
   // 3) run all three strategies
   if(Combo_EnableFIX09)   F_Tick();
   if(Combo_EnableDTREND)  D_Tick();
   if(Combo_EnableDonchian) DN_Tick();
}
double OnTester(){
   PrintFormat("[COMBO_v2] DTREND buys=%d exits=%d flatDown=%d chopADX=%d htfSkip=%d stdvTP=%d stdvNoTgt=%d | FIX09 rejects=%d | DONCHIAN buys=%d sells=%d riskSkip=%d spread=%d session=%d",
               D_nBuy,D_nExit,D_cFlatDown,D_cChop,D_cHTF,D_nStdvTP,D_cStdvNoTgt,F_cReject,
               DN_nBuy,DN_nSell,DN_cRiskSkip,DN_cSpread,DN_cSession);
   int h=FileOpen("ck_gold_combo_v2_trades.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit","magic"); HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         long mg=HistoryDealGetInteger(tk,DEAL_MAGIC); if(mg!=FIX_Magic && mg!=DT_Magic && mg!=DN_Magic)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2),IntegerToString(mg)); }
      FileClose(h); }
   // --- enriched per-trade deals (entry+exit paired by position id) for the loss visualizer ---
   int h2=FileOpen("ck_gold_combo_v2_deals.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h2!=INVALID_HANDLE){
      // entry_time/exit_time keep MINUTE formatting on purpose: tools/loss_visualizer.py parses
      // them with an exact "%Y.%m.%d %H:%M" format and would silently drop every row if changed.
      // hold_sec is written instead as EXACT integer seconds from the raw datetimes, which is what
      // the GFT 2-minute rule needs (rulebook rule 4); mae/mfe give the floating excursions that
      // Goat Guard (rule 3) is measured on.
      FileWrite(h2,"magic","dir","entry_time","entry_price","exit_time","exit_price","profit","volume","hold_sec","mae","mfe");
      HistorySelect(0,TimeCurrent()); int ndl=HistoryDealsTotal();
      for(int i=0;i<ndl;i++){ ulong o=HistoryDealGetTicket(i); if(o==0)continue;
         if(HistoryDealGetString(o,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(o,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         long mg=HistoryDealGetInteger(o,DEAL_MAGIC); if(mg!=FIX_Magic && mg!=DT_Magic && mg!=DN_Magic)continue;
         long pid=HistoryDealGetInteger(o,DEAL_POSITION_ID);
         datetime et=0; double ep=0; long dir=-1;
         for(int j=0;j<ndl;j++){ ulong in=HistoryDealGetTicket(j); if(in==0)continue;
            if(HistoryDealGetInteger(in,DEAL_POSITION_ID)!=pid)continue;
            if(HistoryDealGetInteger(in,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
            et=(datetime)HistoryDealGetInteger(in,DEAL_TIME); ep=HistoryDealGetDouble(in,DEAL_PRICE); dir=HistoryDealGetInteger(in,DEAL_TYPE); break; }
         datetime xt=(datetime)HistoryDealGetInteger(o,DEAL_TIME); double xp=HistoryDealGetDouble(o,DEAL_PRICE);
         double p=HistoryDealGetDouble(o,DEAL_PROFIT)+HistoryDealGetDouble(o,DEAL_SWAP)+HistoryDealGetDouble(o,DEAL_COMMISSION);
         string ds=(dir==DEAL_TYPE_BUY)?"buy":((dir==DEAL_TYPE_SELL)?"sell":"na");
         double vol=HistoryDealGetDouble(o,DEAL_VOLUME);
         long hold_sec=(long)(xt-et);
         // MAE/MFE from M1 bars spanning the hold. Price-excursion based (excludes swap and
         // commission), in account currency: distance * volume * contract size.
         double mae=0.0,mfe=0.0; MqlRates rt[];
         int nb=(et>0 && xt>=et)?CopyRates(_Symbol,PERIOD_M1,et,xt,rt):0;
         if(nb>0){
            double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
            double worst=0.0,best=0.0;
            for(int b=0;b<nb;b++){
               double adverse=(dir==DEAL_TYPE_BUY)?(ep-rt[b].low):(rt[b].high-ep);
               double favor  =(dir==DEAL_TYPE_BUY)?(rt[b].high-ep):(ep-rt[b].low);
               if(adverse>worst) worst=adverse;
               if(favor>best)    best=favor; }
            mae=worst*vol*cs; mfe=best*vol*cs; }
         FileWrite(h2,IntegerToString(mg),ds,TimeToString(et,TIME_DATE|TIME_MINUTES),DoubleToString(ep,2),TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(xp,2),DoubleToString(p,2),DoubleToString(vol,2),IntegerToString(hold_sec),DoubleToString(mae,2),DoubleToString(mfe,2)); }
      FileClose(h2); }
   return(0.0);
}
//+------------------------------------------------------------------+

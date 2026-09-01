========================================================================
  XAUUSD STRATEGIES - MT5 SOURCE CODE (ranked)
========================================================================
Both are MQL5 Expert Advisors for MetaTrader 5. The compiled .ex5 are already
in your MT5 Experts folder; these .mq5 are the source (open in MetaEditor, F7 to compile).

Test truth used everywhere: MetaTrader 5 Strategy Tester, "Every tick based on real ticks",
deposit $5,000, leverage 1:10. No real money was traded.

------------------------------------------------------------------------
  #1  1_CK_GFT_Fast_v17.mq5   --  WORKS IN CURRENT MARKET  (status: demo-forward)
------------------------------------------------------------------------
Symbol: XAUUSD    Timeframe: M5    Model: Every tick based on real ticks
Result (untuned DEFAULTS, $5,000):
  - Current 6 months : +$2,175   PF 1.39   DD 11.4%   (416 fills)
  - Last 12 months   : +$5,808   PF 1.49   DD  9.2%   (951 fills)
  - Survives cost stress to ~$3 per fill (still +$927, PF 1.15)

USE THESE EXACT (DEFAULT) INPUTS - do NOT use the over-optimized values:
  InpRiskPercent      = 0.35
  InpRR               = 3.0
  InpMaxTradesPerDay  = 3
  InpDailyLossStopR   = 1.0
  InpDailyProfitStopR = 3.0
  InpMaxSpreadPoints  = 50
  InpUseTrend         = true
  InpEMAPeriod        = 21
  InpEMASlow          = 50
  InpKneeMinRun       = 2
  InpValidBars        = 5
  InpSLBufferATR      = 0.3
  InpMaxLot           = 0.09
  InpAllowBuy         = true
  InpAllowSell        = true
  InpUsePartialTP     = true
  InpTP1Progress      = 0.10
  InpTP1CloseRatio    = 0.25
  InpTP2Progress      = 0.60
  InpTP2CloseRatio    = 0.25
  InpUseBreakEven     = true
  InpBEProgress       = 0.65

Notes / honest caveats:
  * It is a high-frequency scalper (~950 fills/year) -> real spread/slippage matters a lot.
    Use a LOW-SPREAD, low-commission account.
  * Thin per-trade edge (~$5-7). Give it a clean data feed.
  * NEXT STEP = run it on a DEMO account for a few weeks (demo-forward) and check that live
    fills match this backtest BEFORE risking any real money.

------------------------------------------------------------------------
  #2  2_CK_GOLD_PRO_FIX09.mq5   --  TREND-ONLY  (do not deploy in current regime)
------------------------------------------------------------------------
Symbol: XAUUSD    Timeframe: M15   Model: Every tick based on real ticks
Result ($5,000, fixed 0.09 lot):
  - Last 12 months   : +$8,740   PF 1.37   DD 23.2%   (291 trades)
  - Trend half only  : +$11,968  PF 2.23   DD  9.7%   (excellent in a trend)
  - Current 6 months : -$1,661   PF 0.29   (only 8 trades - account MARGIN-LOCKS on $5k)

USE THESE EXACT INPUTS:
  InpFixedLot         = 0.09
  InpMaxLot           = 0.09
  InpRiskPercent      = 2.0
  InpRR               = 3.0
  InpMaxTradesPerDay  = 3
  InpDailyLossStopR   = 2.0
  InpDailyProfitStopR = 4.0
  InpMaxSpreadPrice   = 0.60
  InpHTF              = PERIOD_H1
  InpTrendEMA         = 200
  InpBreakoutLookback = 20
  InpBreakoutMaxAge   = 12
  InpEntryEMA         = 20
  InpSwingLookback    = 10
  InpMaxSL_ATR        = 2.5
  InpSLBufferATR      = 0.20
  InpUseBreakEven     = true
  InpBEProgress       = 0.50

Notes / honest caveats:
  * Genuinely strong in a strong gold trend, but LOSES in the current range regime.
  * On $5,000 with a fixed 0.09 lot it hits the gold margin limit and locks up after a few
    losses. If you ever use it: only in a CONFIRMED trend and on a BIGGER account (or smaller lot).

------------------------------------------------------------------------
Disclaimer: historical simulation only, not a promise of future results; leveraged gold is
high-risk. Validate on demo-forward before any real capital.
========================================================================

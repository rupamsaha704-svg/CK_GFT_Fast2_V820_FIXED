========================================================================
  XAUUSD ALGO STRATEGY - VALIDATION PACKAGE (for review)
========================================================================

WHAT THIS IS
  A rigorous MetaTrader 5 validation of gold (XAUUSD) trading strategies.
  MT5 Strategy Tester (real ticks) is the only source of truth; every input
  is fixed; every run is recorded in a tamper-evident hash-chained ledger.
  No real money was traded.

HEADLINE
  6 strategies were tested honestly.
  * 5 were REJECTED (they only worked in a past regime or in an over-optimized backtest).
  * 1 PASSED honest validation: the in-house "v17" scalper - profitable in the CURRENT
    market (+44% over the last 6 months) and it survives transaction-cost + forward tests.
  v17 now proceeds to DEMO-FORWARD (weeks on a live demo) before any real capital.
  Net effect: disciplined testing avoided losing money on false edges and surfaced one
  genuine candidate.

WHAT'S INSIDE
  Reports/
    1_Validation_Report.pdf   - full report: method, scoreboard, v17, FIX09, verdict, engine
    2_Ranked_Results.pdf       - MT5-style ranked results (#1 v17, #2 FIX09) + rejected list
  Strategies/
    1_CK_GFT_Fast_v17.mq5      - #1 (works now, M5)     <- use DEFAULT inputs (see README)
    2_CK_GOLD_PRO_FIX09.mq5    - #2 (trend-only, M15)
    README.txt                 - exact input settings + honest caveats for both EAs

WHERE TO START
  Open Reports/1_Validation_Report.pdf first.

DISCLAIMER
  Historical simulation only, not a promise of future results. Leveraged gold is high-risk.
  v17 must pass demo-forward before any real allocation.
========================================================================

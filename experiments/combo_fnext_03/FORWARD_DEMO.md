# FORWARD-DEMO PROTOCOL - FundedNext Stellar 2-Step ($5k), config combo_fnext_03

Purpose: confirm the config behaves on the REAL FundedNext feed (1:15 gold leverage, real spread/slippage/swap,
server GMT+2/+3, daily reset 00:00) as it did in the Model-1 backtest (+75.3%/yr, 0 breaches) BEFORE any real money.
Real money stays BLOCKED until this passes AND the human approves.

## A. Setup (do once)
1. Get a FundedNext Stellar 2-Step account (challenge or free trial). Account size < $50,000 (EA is only allowed under $50k).
2. Use the **MT5** platform (NOT Match-Trader - EA is banned there). Log in with FundedNext's MT5 server + login + password.
3. Put CK_GOLD_COMBO.mq5 in MQL5/Experts, compile in MetaEditor (must be 0 errors / 0 warnings).
4. Open **XAUUSD**, timeframe **M15**. Drag CK_GOLD_COMBO onto the chart.
5. In the EA Inputs tab click **Load** and load `CK_GOLD_COMBO_FundedNext.set`. (Combo_Stage=0, Combo_DailyRefInitial=true, FIX 0.03.)
6. Tick "Allow Algo Trading" in the dialog + the terminal's Algo Trading toolbar button. Confirm the smiley face + a
   "[COMBO] init ... MODE=EVAL" line in the Experts log.
7. Run on a **stable VPS / single IP** (FundedNext's single-IP/VPS rule; also keeps the EA live 24/5).

## B. Pre-declared PASS / FAIL bar (lock BEFORE running - do not move)
Minimum window: at least 2 weeks AND at least ~15 closed trades (ideally through Phase-1 completion).
PASS (all must hold):
  1. NO daily-loss breach - intraday EQUITY never falls 5% of initial below the day's start (never below ~$4,750 in a day);
     our governor should flatten near 4.5% (~-$225). Zero days at/over 5%.
  2. NO static breach - equity never below $4,500.
  3. Margin used stays under 60% (the clamp holds at 1:15 leverage; no margin-call / stop-out).
  4. EA executes correctly - entries/exits fire as designed, no repeated errors in Experts/Journal.
  5. Edge not broken by real costs - forward win-rate within ~10 percentage points of the backtest (~28%), and net
     expectancy not systematically negative (spread/slippage/1:15 leverage not eating the edge). Short-window variance in
     the RETURN is expected and OK; the hard bar is rule-compliance (1-4) + the edge not being clearly destroyed.
FAIL / STOP -> fix before proceeding:
  - any daily or static breach, margin stop-out, EA execution errors, or a clear systematic loss on the real feed.

## C. Monitor (quick daily check)
- Dashboard: balance, equity, daily-loss remaining, max-loss remaining. Note any day that gets within ~1% of the daily line.
- Experts/Journal log: no errors; "[COMBO]" prints look normal.
- The EA writes `ck_gold_combo_deals.csv` and `ck_gold_combo_trades.csv` to the MT5 Common\Files folder.

## D. What to send back (for verification against the backtest)
1. After ~2 weeks: the `ck_gold_combo_deals.csv` (or an MT5 History export / statement).
2. A screenshot of the FundedNext dashboard (balance / equity / daily-DD / max-DD).
3. Any day the daily or static line got close, with the date.
-> I re-run gft_compliance.py + the deals analysis on your forward data and compare to the backtest: same rule-safety?
   same edge? If yes and you approve -> green-light. If not -> we diagnose and adjust before real money.

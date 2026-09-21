# FORWARD-DEMO PROTOCOL — FundedNext Stellar 2-Step **$6,000**, config combo_fnext_03

Purpose: confirm the config behaves on the REAL FundedNext feed (1:15 gold leverage, real
spread/slippage/swap, server GMT+2/+3, daily reset 00:00) as it did in the MT5 real-tick
backtest before any real money. Real money stays BLOCKED until this passes AND the human
approves.

Ship-ready config is FIX **0.02** lot (not 0.03; see steering §6 — the 3% funded risk rule
+ the 5% daily including floating make 0.02 the safe ceiling on $6k). `Combo_Stage=0` for
Eval; switch to `Combo_Stage=1` only after the account moves to Funded and after the
funded-side 3%-risk rework is verified per steering §6/§7.

Historic Model-1 backtest number (0.02 lot, last-1y, $5k): net +$3,308, worst realized day
-$143.71, 0 daily/0 static breach. MT5 real-tick truth (JOURNAL_FundedNext.md, ledger
seq255): 270 trades, +$2,240 on $5k basis (~+37% on $6k basis), PF 1.35, win 25.6%,
1 daily-line touch on 2026-03-23 that the governor caught. Use these as expectation
anchors — NOT as pass/fail bars (short-window forward variance is normal).

## A. Setup (do once)

1. **Get the account.** FundedNext Stellar 2-Step **$6,000** (challenge). Account size stays
   **below $50,000** the entire time — EA is only allowed under $50k, and identical trades
   across accounts are forbidden, so no cloning.
2. **Platform: MT5** (NOT Match-Trader — EA is banned there). Log in with the FundedNext MT5
   server + login + password from the client area.
3. **Install the EA.** Run `install_combo_fnext.ps1` from this folder (or manually: copy
   `CK_GOLD_COMBO.mq5` to `MQL5\Experts\`, copy `CK_GOLD_COMBO_FundedNext.set` to
   `MQL5\Presets\`, compile in MetaEditor to 0 errors / 0 warnings).
4. **Attach.** Open **XAUUSD**, timeframe **M15**. Drag `CK_GOLD_COMBO` from Navigator onto
   the chart.
5. **Load the preset.** In the EA Inputs tab click **Load** and pick
   `CK_GOLD_COMBO_FundedNext.set`. Confirm `Combo_Stage=0`, `Combo_DailyRefInitial=true`,
   `FIX_FixedLot=0.02`, `Combo_BlockEntryHours=0,1`.
6. **Enable trading.** Tick "Allow Algo Trading" in the input dialog AND the terminal's
   Algo Trading toolbar button. Confirm the smiley face and a
   `[COMBO] init … MODE=EVAL` line in the Experts log.
7. **VPS.** Run on a stable VPS with a single IP (FundedNext's single-IP/VPS rule; also
   keeps the EA live 24/5). See `VPS_SETUP.md` in this folder.

## B. Pre-declared PASS / FAIL bar — lock BEFORE running, do not move

Minimum window: **at least 2 weeks AND at least ~15 closed trades** (ideally through the
Step-1 profit target of +$480 = +8% on $6k).

PASS — all must hold:

1. **NO daily-loss breach.** Intraday equity never falls 5% of initial below the day's
   start; on $6k that is the **$300 daily line** = equity must not touch **$5,700 measured
   from the day-start balance**. Because `Combo_DailyRefInitial=true`, the EA also caps
   day-loss vs the initial $6k (safer). Our governor flattens near 4.5% (~-$270). Zero
   days at or over 5%.
2. **NO static breach.** Equity **never below $5,400** (the 10% static floor on $6k).
3. **Margin used stays under 60%.** The `Combo_MaxMarginPct=60.0` clamp holds at 1:15
   gold leverage; no margin-call / stop-out.
4. **EA executes correctly.** Entries / exits fire as designed, no repeated errors in the
   Experts or Journal tabs.
5. **Edge not broken by real costs.** Forward win-rate within about ±10 percentage points of
   the MT5-real-tick backtest (~25.6%); net expectancy not systematically negative
   (spread/slippage/1:15 leverage not eating the edge). Short-window variance in the
   RETURN is expected and fine; the hard bar is rule-compliance (1–4) + the edge not
   being clearly destroyed.

FAIL / STOP — fix before proceeding:

- Any daily breach ($300 line) or static breach ($5,400 floor).
- Any margin stop-out.
- Repeated EA execution errors.
- Clear systematic loss on the real feed (edge dead).

## C. Monitor — quick daily check

- **Dashboard:** balance, equity, daily-loss remaining, max-loss remaining. Note any day
  that gets within ~1% ($60) of the daily line.
- **Experts / Journal log:** no errors; `[COMBO]` prints look normal.
- **EA output:** the EA writes `ck_gold_combo_deals.csv` and `ck_gold_combo_trades.csv` to
  the MT5 **Common\Files** folder (path in `VPS_SETUP.md`).

See `DEPLOY_CHECKLIST.md` in this folder for the day-by-day / week-by-week checklist.

## D. What to send back for verification against the backtest

1. After ~2 weeks: `ck_gold_combo_deals.csv` (or an MT5 History export / statement).
2. A screenshot of the FundedNext dashboard (balance / equity / daily-DD / max-DD).
3. Any day the daily or static line got close, with the date.

Then I re-run `tools/gft_compliance.py` and the deals analysis on the forward data and
compare it to the backtest: same rule-safety? Same edge shape? If yes and you approve, we
green-light real money. If not, we diagnose and adjust BEFORE real money.

# FORWARD-DEMO PROTOCOL — Plan Q (QM signal-player) on FundedNext Stellar 2-Step **$6,000**

Purpose: confirm the QM erl_h4 + dedupe signal-player behaves on the REAL FundedNext feed
(1:15 gold leverage, real spread / slippage / swap, server GMT+2/+3, daily reset 00:00) as
it did in the MT5 real-tick backtest before any real money. Real money stays BLOCKED until
this passes AND the human approves.

Ship-config: `InpRiskUSD = 75` (NOT 85). `InpMaxConcurrent = 2`. `InpUseTrail = false`.
`InpUseCommonFiles = true`. `InpToleranceMin = 20`. See `install_qm_signalplayer.ps1` for
the full preset.

## 0. Non-negotiable pre-flight (before ANY forward-demo)

**A. Risk parameter check.** The **$85** reference risk breaches FN compliance:
- 2026-03-23 realized loss -$314.66 = 5.24% intraday, **over the $300 daily line**.
- Min running balance $5,353.50, **below the $5,400 static floor**.

At **$75** risk (scale factor 75/85 = 0.882) the same trades project to:
- Worst day ~-$277.53 → $22.47 buffer below the $300 daily line.
- Min balance ~$5,429.56 → $29.56 buffer above the $5,400 static floor.

**Both buffers are thin.** Combo (Plan C) has $50 daily buffer and $514 static buffer at
0.02 lot. If any live variance widens the loss beyond backtest, Plan Q's buffer is
consumed first.

**B. Re-verify at $75.** Run one Model 4 real-tick backtest with `InpRiskUSD = 75` before
starting any forward-demo. The pre-declared bar:
- 0 days at or over -$300 realized.
- Min balance stays > $5,400 through the full window.
- Deals within ±5 of the $85 baseline's 88 deals (some sizing skips are OK).
- Net within ±10% of the $75-scaled projection ($2,061).

If any of these fail, ABORT — do not deploy Plan Q. Switch to Plan C.

**C. Signal-file freshness.** The `_signals_erl_h4.csv` in the repo ends 2026-07-27. Every
signal older than 20 minutes from now is auto-skipped by the EA. Regenerate the CSV with
fresh M15/M5 data before the demo starts. See `QM_VPS_SETUP.md` section "Signal
regeneration workflow".

## A. Setup (do once)

1. **Get the account.** FundedNext Stellar 2-Step **$6,000** (challenge). Account size
   stays **below $50,000** the entire time — EA banned above $50k.
2. **Platform: MT5** (NOT Match-Trader — EA banned there).
3. **Install the EA.** Run `install_qm_signalplayer.ps1` from this folder (or manually:
   copy `CK_QM_SignalPlayer.mq5` to `MQL5\Experts\`, copy the signals CSV to
   `MQL5\Common\Files\signals_erl_h4.csv`, compile in MetaEditor to 0/0).
4. **Regenerate signals with FRESH data.** From MT5 export XAUUSD M15 + M5 to CSV, run
   the Python engine (`_multi_tf_test.py` → `_export_signals_for_mt5.py`), copy the
   resulting `_signals_erl_h4.csv` to `MQL5\Common\Files\signals_erl_h4.csv`. Details in
   `QM_VPS_SETUP.md`.
5. **Attach.** Open XAUUSD chart, timeframe M15. Drag `CK_QM_SignalPlayer` on.
6. **Set inputs** exactly per `install_qm_signalplayer.ps1` output. Key values:
   `InpRiskUSD=75`, `InpUseTrail=false`, `InpMaxConcurrent=2`,
   `InpUseCommonFiles=true`, `InpSignalFile=signals_erl_h4.csv`.
7. **Enable trading.** Tick "Allow Algo Trading" in dialog + toolbar. Confirm Experts
   tab: `CK_QM_SignalPlayer: loaded N signals from 'signals_erl_h4.csv'`.
8. **VPS.** Run on a stable VPS with a single IP. See `QM_VPS_SETUP.md`.

## B. Pre-declared PASS / FAIL bar — lock BEFORE running, do not move

Minimum window: **at least 3 weeks AND at least ~10 closed deals** (QM fires about
88 / 12mo ≈ 7-8 deals per month, slower than combo's 22-23).

PASS — all must hold:

1. **NO daily-loss breach.** Intraday equity never falls 5% of initial below the day's
   start. On $6k that is the **$300 daily line**. Because Plan Q's backtest buffer is
   only $22 at $75 risk, ANY day within $30 of the line is a warning.
2. **NO static breach.** Equity never below **$5,400** (10% static floor on $6k).
3. **EA executes correctly.** Signal-file loads on init (Experts log confirms). No
   repeated errors. Concurrent open positions never exceeds 2.
4. **Signal-file stayed fresh.** If a scheduled Python re-run failed and the file went
   stale (all signals more than 20 min old), the EA would silently stop firing. Weekly
   check: signal-file's newest timestamp is within a few days of "now".
5. **Edge intact.** Win-rate within ±10 pts of the backtest 22.7%. Net not systematically
   negative on the real feed. Short-window variance is OK; a clear systematic loss is
   not.

FAIL / STOP — fix before proceeding:

- Any daily breach ($300 line) or static breach ($5,400 floor).
- Any margin stop-out.
- Repeated EA errors. Signal file failing to reload (see §C on the live-refresh gap).
- Clear systematic loss on the real feed.

## C. Known live-mode limitation — the signal-file refresh gap

`CK_QM_SignalPlayer.mq5` calls `LoadSignals()` **only in OnInit()**. A live-running EA
does NOT re-read the CSV during a session. Practical implications:

- The forward-demo can run for a few weeks off a single CSV as long as that CSV covers
  the demo period with signals that have `dt` timestamps within the tolerance window.
- Beyond that, either:
  - **Option A — daily restart** (simplest, chosen by default for the forward-demo):
    once per day at 03:00 server time (post-settlement, no trades typically), Python
    regenerates the CSV, then the EA is manually removed + re-attached (or the MT5
    terminal restarted). Miss period ≈ 30 seconds.
  - **Option B — patch the EA** to `OnTimer(60)` re-read the CSV, keep the "fired"
    flags on existing signals, and add new signals to the in-memory array. ~30 line
    change to the EA. Not done for the initial forward-demo; if Plan Q graduates to
    live, this patch is a prerequisite.
  - **Option C — full native rewrite** (`CK_QM_NATIVE_v1.mq5`, `SPEC/QM_MQL5_REWRITE_PLAN.md`)
    eliminates the Python + CSV entirely. Blocks 2–7 = ~22h. This is the clean long-term
    answer.

The forward-demo uses Option A. If Plan Q passes the forward-demo, Option B or C must be
in place before any funded stage.

## D. Monitor — quick daily check

- **Dashboard:** balance, equity, daily-loss remaining, max-loss remaining. Note any day
  within ~1% ($60) of the daily line — Plan Q's backtest buffer is only $22 so alarms
  should trip earlier.
- **Experts / Journal log:** no errors; the `FIRE` / `SKIP` lines show correctly.
- **Signal file:** confirm the newest timestamp is within a few days of now.
- **EA output:** `qm_signalplayer_deals.csv` in `MQL5\Common\Files\` grows as deals close.

See `QM_DEPLOY_CHECKLIST.md` in this folder for the day-by-day / week-by-week checklist.

## E. What to send back for verification against the backtest

1. After ~3 weeks: `qm_signalplayer_deals.csv` (or MT5 History export / statement).
2. Screenshot of the FundedNext dashboard (balance / equity / daily-DD / max-DD).
3. Any day the daily or static line got close, with the date.
4. Any signal-file staleness incidents.

Then I re-run `_compare_plans.py` (Plan Q side) on the forward data and compare it to the
backtest: same rule-safety? Same edge shape? If yes and you approve, green-light real
money. If not, diagnose or switch to Plan C.

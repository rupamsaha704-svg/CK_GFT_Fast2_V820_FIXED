# DEPLOY CHECKLIST — Plan Q on FundedNext Stellar 2-Step $6,000

Pair this with `QM_FORWARD_DEMO.md` (protocol / PASS-FAIL bar) and `QM_VPS_SETUP.md`
(how to run 24/5 with a Python signal-refresh workflow). This file is the day-by-day
discipline sheet.

Plan Q's ops load is heavier than Plan C's because a Python engine + a signal CSV +
manual EA restart cadence live outside the EA. Every line below acknowledges that.

---

## PRE-FLIGHT — the day you buy the challenge (before AutoTrading goes ON)

- [ ] FundedNext Stellar 2-Step **$6,000** account purchased and MT5 login received.
- [ ] Platform is MT5 (NOT Match-Trader). Match-Trader is EA-banned.
- [ ] Account size stays **< $50k** entire life of the EA (steering §7).
- [ ] VPS provisioned per `QM_VPS_SETUP.md` (independent forex VPS with Python 3.14).
- [ ] Repo cloned or copied to the VPS. Path documented.
- [ ] Python 3.14 installed on the VPS. `python --version` reports 3.14.x.
- [ ] Fresh XAUUSD M15 + M5 exports pulled from MT5, saved to the repo folder.
- [ ] `python _multi_tf_test.py --erl-tf H4 --dedupe` produced a fresh signal CSV
  covering "now" with signal `dt` timestamps in the near future or within tolerance.
- [ ] Signal CSV copied to `MQL5\Common\Files\signals_erl_h4.csv`.
- [ ] `install_qm_signalplayer.ps1` ran end-to-end. `.ex5` present in `MQL5\Experts\`.
- [ ] **$75-risk MT5 real-tick backtest re-run** (per `QM_FORWARD_DEMO.md` §0-B):
  - [ ] 0 daily-line breaches.
  - [ ] Min balance stays > $5,400.
  - [ ] Deal count within ±5 of 88.
  - [ ] Net within ±10% of $2,061 scaled projection.
- [ ] XAUUSD M15 chart open. EA dragged on. Preset loaded via Inputs → Load.
- [ ] Inputs sanity-check:
  - [ ] `InpSignalFile      = signals_erl_h4.csv`
  - [ ] `InpUseCommonFiles  = true`
  - [ ] `InpRiskUSD         = 75`    (NOT 85 — 85 breaches)
  - [ ] `InpMaxLot          = 0.20`
  - [ ] `InpMinLot          = 0.01`
  - [ ] `InpMaxConcurrent   = 2`
  - [ ] `InpToleranceMin    = 20`
  - [ ] `InpMaxSpreadPrice  = 0.60`
  - [ ] `InpUseTrail        = false`  (H2 rejected in ledger seq272 — leave OFF)
- [ ] "Allow Algo Trading" ticked in the input dialog.
- [ ] Global AutoTrading toolbar button green.
- [ ] Experts tab shows: `CK_QM_SignalPlayer: loaded N signals from 'signals_erl_h4.csv'`.
- [ ] Note today's date + starting balance in a personal log. Zero position open.
- [ ] Phone push notifications from MT5 mobile app tied to the terminal.

If ANY box is unticked, do NOT go live. Fix first.

---

## DAILY — 5 minutes, ideally around the FN daily rollover (00:00 server time)

- [ ] FN dashboard: **daily-loss remaining ≥ $60** (Plan Q's backtest daily buffer is
  only $22; any day within $60 of the line is a warning, close positions manually if
  needed).
- [ ] FN dashboard: **balance ≥ $5,460** (Plan Q's backtest static buffer is only $30;
  anything within $60 above the $5,400 floor is a warning).
- [ ] Terminal is on, EA on the XAUUSD M15 chart, no error toasts.
- [ ] Experts log: skim last 24 hours. No `INVALID`, `disabled`, `retcode=` errors.
- [ ] Journal log: no persistent "connection lost".
- [ ] VPS clock in sync (`w32tm /resync` if drift).
- [ ] Open positions ≤ 2 (the cap).
- [ ] **Signal-file age**: check the timestamp on `signals_erl_h4.csv`. If older than
  7 days, run the weekly regeneration (see below).

Green day → tick everything, done.
Red → screenshot dashboard, pause new entries via AutoTrading toolbar, message back.

---

## WEEKLY — 30 minutes, Sunday before markets reopen

- [ ] Trade count pace: QM fires ~7-8 deals/mo, so target ~1.5-2 deals/week. Under-pace
  is not a fail; over-pace means good.
- [ ] Copy `qm_signalplayer_deals.csv` from `MQL5\Common\Files\` off the VPS. Save
  timestamped: `qm_deals_2026wkNN.csv`.
- [ ] Run `_compare_plans.py` on the forward data → confirm 0 daily / 0 static breach.
  Compare running win-rate to the backtest 22.7% (±10 pts is fine).
- [ ] **Signal-file regeneration** (steering-required Sunday task):
  1. In MT5 on the VPS, export fresh XAUUSD M15 + M5 CSVs.
  2. Run `python _multi_tf_test.py --erl-tf H4 --dedupe` in the repo folder.
  3. Run `python _export_signals_for_mt5.py --input _signals_erl_h4.csv --output _signals_erl_h4.txt`.
  4. Copy the new CSV to `MQL5\Common\Files\signals_erl_h4.csv`.
  5. Right-click chart → Expert Advisors → Remove; drag EA back on; verify Experts log
     shows the new `loaded N signals` line with a bigger N.
- [ ] Screenshot FN dashboard. Save timestamped.
- [ ] Note in personal log: net P/L, biggest drawdown day, any Experts errors, any FN
  notifications, any signal-file staleness incidents, deals fired vs skipped ratio.

At 3-week mark: bundle deals + dashboard + notes, hand back. Re-verify against backtest,
then green-light or diagnose.

---

## EMERGENCY — what to do if the EA misbehaves

Small trouble (a single skipped entry, one error):
1. Note timestamp + exact log line.
2. Watch for pattern; single events happen.

Big trouble (repeated errors, wrong-side entry, runaway trade, near-daily-line):
1. **Turn OFF the global AutoTrading toolbar button.** New entries stop.
2. If a position is bleeding toward the daily line, close it MANUALLY. Rule-compliance
   over profit.
3. Screenshot Experts / Journal logs, positions, dashboard.
4. Send back before restarting.

Kill switch = AutoTrading toolbar button. Keep mouse close.

**Plan-Q-specific emergency:**
- **Signal-file stale** (all signals older than 20 min from now): EA prints nothing but
  keeps running. Not dangerous (no wrong trades), but no new fires. Regenerate + restart
  EA to recover.
- **Python engine failed during scheduled regeneration**: the old CSV stays; the EA
  keeps trying to fire from stale signals; all skipped by tolerance. Not dangerous.
  Re-run Python manually.

---

## STOP CONDITIONS — turn OFF and message back immediately

- [ ] Any daily-line breach (≥ 5% intraday loss).
- [ ] Any static-floor breach (equity below $5,400).
- [ ] Any margin-call / stop-out.
- [ ] EA silent for > 4 hours during liquid session with no fill and no error.
- [ ] FN client-area notification about a rule concern.
- [ ] Signal-file stayed stale for > 72 hours despite scheduled regeneration.
- [ ] Any doubt at all — pause is free, breach is permanent.

---

## Comparison to Plan C at a glance

| | Plan C (combo) | Plan Q (this kit) |
|---|---|---|
| Take-80 income projection | ~Rs 17,345/mo (Eval); ~Rs 13,900 (Funded after rework) | ~Rs 15,229/mo (safe $75 risk) |
| MT5-real-tick deals | 270 in 11.5 mo | 88 in 11.8 mo |
| PF | 1.422 | 1.492 (higher) |
| Win rate | 25.6% | 22.7% |
| FN daily buffer | $50 ($6k, 0.02 lot) | $22 (at $75 risk) |
| FN static buffer | $514 | $30 |
| Ops load | single .ex5 autopilot | Python + CSV + weekly restart |
| Live-refresh gap | none | present; workaround = daily/weekly restart |
| Recommendation | default | on explicit user preference |

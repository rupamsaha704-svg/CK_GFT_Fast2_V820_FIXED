# DEPLOY CHECKLIST — combo_fnext_03 on FundedNext Stellar 2-Step $6,000

Pair this file with `FORWARD_DEMO.md` (protocol / PASS-FAIL bar) and `VPS_SETUP.md`
(how to run 24/5). This one is the day-by-day discipline sheet.

Print it, or keep it open in a second monitor. Tick each item.

---

## PRE-FLIGHT — the day you buy the challenge (before AutoTrading goes ON)

- [ ] FundedNext Stellar 2-Step **$6,000** account purchased and MT5 login received.
- [ ] Platform is MT5 (NOT Match-Trader). Match-Trader is EA-banned.
- [ ] Account size stays **< $50k** entire life of the EA (steering §7).
- [ ] VPS provisioned per `VPS_SETUP.md` OR home PC OK'd (no auto-reboots scheduled).
- [ ] Repo cloned or copied to the VPS at the same paths as the dev PC.
- [ ] `install_combo_fnext.ps1` ran end-to-end. `.ex5` present in `MQL5\Experts\`.
- [ ] `CK_GOLD_COMBO_FundedNext.set` present in `MQL5\Presets\`.
- [ ] XAUUSD M15 chart open. EA dragged on. Preset **Load**ed.
- [ ] Inputs sanity-check (from preset):
  - [ ] `Combo_Stage = 0`
  - [ ] `Combo_DailyRefInitial = true`
  - [ ] `Combo_BlockEntryHours = 0,1`
  - [ ] `FIX_FixedLot = 0.02`  (NOT 0.03; 0.03 breaches on $6k)
  - [ ] `FIX_MaxLot = 0.02`
  - [ ] `Combo_UseNewsGate = true`
  - [ ] `Combo_StaticDDStopPct = 8.0`
  - [ ] `Combo_DailyLossPct = 4.5`
  - [ ] `Combo_UsePredictiveDaily = true`
  - [ ] `Combo_DailyBufferPct = 3.5`
  - [ ] `Combo_MaxMarginPct = 60.0`
- [ ] "Allow Algo Trading" ticked in the input dialog.
- [ ] Global AutoTrading toolbar button green (smiley face on chart).
- [ ] Experts tab shows one line like: `[COMBO] init bal=6000.00 login=... MODE=EVAL`.
- [ ] Note today's date and starting balance in a personal log. Zero position open.
- [ ] Phone push notifications from MT5 mobile app tied to the terminal.

If ANY box is unticked, do NOT go live. Fix first.

---

## DAILY — 5 minutes, ideally at the FundedNext daily rollover (00:00 server time)

- [ ] FundedNext dashboard: **daily-loss remaining ≥ $60** (i.e. no closer than 1% to
  the $300 hard line). If it is closer, note the date and close positions manually if
  the governor hasn't already.
- [ ] FundedNext dashboard: **balance ≥ $5,520** (i.e. no closer than 2% above the
  $5,400 static floor). Static halt at 8% should trigger long before this.
- [ ] Terminal is on, smiley face on the XAUUSD M15 chart, no error toasts.
- [ ] Experts log: skim last 24 hours, no repeated errors, no `INVALID`, `disabled`,
  or `retcode=` failure lines.
- [ ] Journal log: no "connection lost" persisting more than a few minutes.
- [ ] VPS clock in sync (drift < 5 s) — if drift, sync via `w32tm /resync`.
- [ ] Open positions ≤ 2 (FIX + DT combo maxes at 2; more means a bug).

Green day → tick everything, done.
Any red → open the Journal, screenshot the dashboard, and pause new entries by turning
off AutoTrading. Fix root cause before re-enabling.

---

## WEEKLY — 15 minutes, Sunday before markets reopen

- [ ] Trade count so far ≥ pace for the 2-week minimum (target ~15 closed trades by
  day 14). Under-pace is not a fail; over-pace means good.
- [ ] Copy `ck_gold_combo_deals.csv` from `MQL5\Common\Files\` off the VPS to the dev PC.
  Save it timestamped: `deals_2026wkNN.csv`.
- [ ] Copy `ck_gold_combo_trades.csv` the same way.
- [ ] Run `tools\gft_compliance.py` (or the FundedNext-adapted version) on the deals
  file → confirm 0 daily / 0 static / 0 3%-risk breach.
- [ ] Compare running win-rate to the MT5-real-tick backtest (~25.6%). Within ±10 pts?
  ✓ edge intact. Outside ±10 pts and losing? Flag.
- [ ] Screenshot the FundedNext dashboard (balance / equity / daily-DD / max-DD /
  profit-target progress). Save it timestamped.
- [ ] Note in the personal log: net P/L for the week, biggest drawdown day, any
  Experts-log oddities, any FundedNext account notifications received.

At 2-week mark: bundle deals + dashboard screenshots + notes, hand them back to me. I
re-verify against the backtest and against every FundedNext rule. Pass → green-light
for real money. Fail → diagnose and adjust BEFORE any more risk.

---

## EMERGENCY — what to do if the EA misbehaves

Small trouble (a single skipped entry, one error in Experts):
1. Note the timestamp and the exact log line.
2. Continue watching for pattern; single events happen (spread spikes, tick gaps).

Big trouble (repeated errors, wrong-side entry, runaway trade, near-daily-line):
1. **Turn OFF the global AutoTrading button.** New entries stop.
2. If a position is bleeding toward the daily line, close it MANUALLY from the trade
   context menu. Rule-compliance > profit; the account survives, the trade doesn't.
3. Screenshot everything: Experts log, Journal log, positions, dashboard.
4. Send it back before restarting AutoTrading.
5. The governor should catch most of these first — its whole job is to keep us off
   the hard line. Manual close is the belt-and-suspenders backstop.

Kill switch is always the AutoTrading toolbar button. Keep the mouse close.

---

## STOP CONDITIONS — turn OFF and message back immediately

- [ ] Any daily-line breach (>= 5% intraday loss).
- [ ] Any static-floor breach (equity below $5,400).
- [ ] Any margin-call / stop-out.
- [ ] EA silent for >4 hours during liquid session with no fill and no error (may mean
  the terminal died or lost feed).
- [ ] FundedNext client-area notification about a rule concern.
- [ ] Any doubt at all — pause is free, breach is permanent.

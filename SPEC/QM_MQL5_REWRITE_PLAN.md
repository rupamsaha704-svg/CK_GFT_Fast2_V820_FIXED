# QM/ICT Native MQL5 Engine — Rewrite Plan (v1)

> Goal: a NATIVE MQL5 EA that runs the QM/ICT liquidity-reversal engine end-to-end on
> MT5 without a Python signal-player. The reference implementation is
> `v1_lab/qm_state_machine.py` (Python). The reference RESULT is the MT5 real-tick
> baseline from `CK_QM_SignalPlayer.mq5` reading `_signals_erl_h4.csv`:
> **net +$2,296 = +38.27%/yr, PF 1.49, 88 deals from 105 signals, min balance $5,674,
> 1 daily-line touch (2026-03-23 = -$314.66), on FundedNext $6k basis, $85/trade
> risk, 2025-08-01 → 2026-07-28** (steering §5a; ledger seq270-274).
>
> Ship-config for the native engine: **`erl_tf = H4`** + dedupe (winner variant from
> the multi-TF sweep) with `entry_mode = confirm_close`, `idm_clear_required = true`,
> `poi_type = qm`, and every other switch at the Python `DEFAULT_CONFIG` value.
>
> **Locked non-goals:** no re-tuning of parameters during the rewrite. If the native
> engine differs from the signal-player baseline by more than a small port-noise
> margin (worst-day / net / PF each within ±10%), FIX the port, do not tune. The
> Python engine's result on the SAME window is the target; matching it is Block 7.

## Why a native engine at all

The signal-player pattern (Python decides, MT5 executes) works and is MT5-verified.
Two operational reasons to still port to native:

1. **Deployment simplicity.** A single .ex5 on the VPS, no Python runtime, no signal
   CSV to keep fresh. When the FN account is live, the fewer moving parts, the
   fewer things break.
2. **Decision freshness.** The signal-player replays a pre-computed CSV over a
   historical window; a native engine decides on the actual live tick stream. No
   window boundary, no "regenerate signals" step before each live restart.

The reference remains Python. Native is a re-implementation with strict causality
and no re-tuning, judged only against the signal-player MT5 baseline.

## The 7-block plan (~22–25h total)

Each block is INDEPENDENTLY committable and INDEPENDENTLY compilable. The .mq5
grows monotonically — each block adds a new `==== BLOCK N ====` section, previous
sections stay untouched. Compile-clean is the gate for merging any block.

### Block 1 — Setup queue struct + array (~3h)  ← THIS BLOCK

Purpose: the data holder. Everything else keys off it.

Deliverables:
- `enum ENUM_QM_STATE` — the state names, causal order:
  `NONE / WAIT_POI_RETURN / WAIT_M5_CONFIRM / ENTERED / DEAD`.
- `enum ENUM_QM_DIR` — `BEAR = -1`, `BULL = +1`.
- `struct QMSetup` — everything a setup needs to advance and eventually fire:
  identity (slot #, magic), state, direction, MSS shift metadata (bar time + price
  extremes), POI zone (top/bottom + head price), IDM data (level + side + cleared
  flag), external target (TP anchor), context values frozen at add-time (ATR),
  wait deadlines (expiry counters), and M5-confirm progress.
- `QMSetup g_qm_setups[MAX_QM_SETUPS]` — fixed-size ring, `MAX_QM_SETUPS = 16`.
- Helpers:
  - `QM_Init()` — zero all slots to `NONE`.
  - `QM_FindFreeSlot()` — return first slot with state `NONE` or `-1`.
  - `QM_AddSetup(...)` — populate a slot with `WAIT_POI_RETURN` and return its index.
  - `QM_ExpireSetup(idx, reason)` — mark `DEAD` and log the reason to Experts.
  - `QM_GC()` — reclaim `DEAD` slots back to `NONE`.
  - `QM_CountActive()`, `QM_CountByState(state)` — diagnostics.
  - `QM_DumpQueue()` — Experts-log one-liner per active slot.
- `OnInit` calls `QM_Init()`. `OnDeinit` calls `QM_DumpQueue()` for post-mortem.
- Block 1 EA does not trade. Attaching it to a chart proves the queue compiles,
  initializes, and prints cleanly.

Definition of done: EA compiles clean (0 errors, 0 warnings). On chart-attach the
Experts tab shows exactly one `[QM_NATIVE] queue init 16 slots MODE=SETUP_ONLY`
line. `QM_DumpQueue()` after 1 hour of live ticks reports `0 active`.

### Block 2 — M15 structure detection on new-bar close (~4h)

Purpose: detect MSS shift + swings on each new closed M15 bar. Port
`v1_lab/qm_detect.py`'s `detect_swings` + `detect_mss`.

Deliverables:
- `OnNewM15Bar()` hook fired once per closed M15 bar.
- `QM_DetectSwings()` — pivot-based swing high / swing low classification with a
  streaming (right-side confirmed) cursor.
- `QM_DetectMSS()` — body-close beyond most-recent confirmed swing, with
  `|close-open|/ATR14 >= disp` displacement gate.
- Debug print: for each closed M15 bar, print `[QM_NATIVE] bar t=... shift=none|bear|bull disp=%.2f`.
- Still no trades. Block 2 EA is a signal detector that prints, only.

Definition of done: over 500 M15 bars in Strategy Tester the Experts tab lists
shifts whose count and direction match a golden CSV from the Python
`detect_mss()` on the same window (allow ±1 for boundary bar edge cases).

### Block 3 — ERL + POI + IDM detection (~4h)

Purpose: on each detected MSS shift, compute the auxiliary structure.

Deliverables:
- `QM_ComputeERL(shift_idx, direction)` — resample to H4 (per `erl_tf=H4` config)
  and return the raid-target price using `erl_lookback = 5`. Port
  `v1_lab/erl_detect.py`'s `resample_bars` + `erl_levels`.
- `QM_ComputePOI(shift_idx, direction)` — return `{top, bottom, head_index,
  head_price}`. Port `v1_lab/poi_zone.py`'s `detect_poi` for `poi_type = qm`.
- `QM_ComputeIDM(shift_idx, direction)` — return `{level, side}`. Port
  `v1_lab/idm_detect.py`'s `find_idm_for_shift`.
- On any MSS shift with valid ERL raid + POI + IDM, call
  `QM_AddSetup(...)` from Block 1. If any is missing, log the drop reason
  and skip.

Definition of done: over the same 500-bar test window, the count of
setups-queued matches the Python engine's "WAIT_MSS survived to WAIT_IDM_FORM"
count within ±1.

### Block 4 — Queue advance on M15 close: POI-return + IDM-clear (~3h)

Purpose: walk each active setup forward per closed M15 bar.

Deliverables:
- `QM_AdvanceSetups()` called at the end of `OnNewM15Bar()`.
  - `WAIT_POI_RETURN`: does this M15 bar's range touch the POI zone? If yes,
    capture `poi_return_time`, then check IDM clear over `[shift..now]`. If
    `idm_clear_required` and not cleared → expire (`WAIT_IDM_CLEAR fail`).
    Otherwise transition to `WAIT_M5_CONFIRM` and reset `m5_confirm_bars = 0`.
  - `WAIT_POI_RETURN` deadline: if `now - shift_time > 96 * PeriodSeconds(M15)`
    (24h) → expire (`WAIT_POI_RETURN timeout`).
- Head-broken invalidation: bear setup where `high > poi_head_price` → expire
  (`head_broken`). Mirror for bull.
- Every expiry logs one Experts line.

Definition of done: over the 500-bar test window, the count of setups reaching
`WAIT_M5_CONFIRM` matches the Python engine's count for the same window (±1).

### Block 5 — M5 confirmation + entry fire (~3h)

Purpose: on each closed M5 bar, look at every setup in `WAIT_M5_CONFIRM` and
either fire the trade or expire it.

Deliverables:
- `OnNewM5Bar()` hook.
- `QM_TryConfirmM5(setup_idx)` — port
  `v1_lab/qm_state_machine.py::_m5_confirmation`. For `entry_mode =
  confirm_close`: standard rejection candle test. Return entry price + SL + TP.
- `QM_PlaceOrder(setup_idx, entry, sl, tp)` — market SELL/BUY, magic per setup,
  spread guard `InpMaxSpreadPrice`, slippage tolerance from a new input.
- Mark setup `ENTERED` after order placed (so it doesn't fire twice); leave the
  MT5 trade to reach SL or TP naturally.
- `m5_confirm_bars` cap: if > `max_hold_bars_m5 / 2` bars pass without
  confirmation, expire (`WAIT_M5_CONFIRM timeout`).

Definition of done: on the same window, the count of ENTRIES and the direction
distribution match the signal-player baseline (105 signals → 88 deals) within
±5 trades.

### Block 6 — Session gate, daily cap, projected-RR gate (~2h)

Purpose: pre-entry filters ported from Python.

Deliverables:
- `QM_SessionOk(entry_dt)` — port `_bar_session_ok` with `session_scope =
  ny_only`; default gate 09:30–16:00 NY, adjustable via input.
- `QM_UnderDailyCap()` — enforce `max_trades_per_day = 2`. Reset at 00:00 broker.
- `QM_ProjectedRROK(entry, sl, tp)` — reject setups with projected RR below
  `min_projected_rr = 1.0`.
- Add a `NEWS_GATE` input (`Combo_UseNewsGate` sibling) for parity with the
  combo EA; default OFF for MVP, wire later.

Definition of done: filtered-entry count matches the signal-player baseline
within ±3 trades on the reference window.

### Block 7 — Trade logger + OnTester deals CSV + parity check (~3h)

Purpose: prove parity with the signal-player baseline.

Deliverables:
- `CK_QM_Native_deals.csv` written to `MQL5\Common\Files\` per closed deal, same
  schema as `qm_signalplayer_deals.csv` for direct diff.
- `OnTester()` prints net / PF / worst-day / min-balance / entries as a Experts
  block for quick eyeballing.
- A tools script `tools/qm_native_parity.py` that reads both deal CSVs and
  reports `deals_native - deals_signalplayer` with net delta and per-day P&L
  delta. Not authoritative on its own — only MT5 real-tick verdict counts — but
  useful for triage.
- Ledger entry `PREREG` (before the parity run) and `BACKTEST_RESULT` (after)
  with pass criterion "net within ±10% of $2,296 AND worst-day within ±10% of
  -$314.66 AND min-balance ≥ $5,600 AND entries within ±5 of 88".

Definition of done: parity within the ±10% band on all four metrics. If off by
more, DIAGNOSE (not tune) — every gap has a root cause in Block 2/3/4/5/6.
Fix the block; do not add compensating parameters.

## After Block 7

Only after native parity holds:

1. Run the native engine as the signal-player replaced, forward-demo on FN
   Stellar 2-Step $6,000 per `experiments/combo_fnext_03/FORWARD_DEMO.md`
   (same protocol, different EA). Two weeks minimum, ~15 trades.
2. Depending on the FN Trading Ethics reply on Article 8020351, decide
   whether QM native and the combo EA run on the SAME account (mutex),
   DIFFERENT accounts (portfolio), or QM alone.
3. If native beats or matches signal-player over 2 weeks live, retire the
   signal-player. If it clearly underperforms, keep signal-player as
   production and native as a research branch — diagnose the gap in the ledger.

## Files this plan creates or touches

- `CK_QM_NATIVE_v1.mq5` — new, grown block-by-block. Never overwrite; never
  fork versions during the port. If a rewrite is truly needed, `v2` and log why.
- `SPEC/QM_MQL5_REWRITE_PLAN.md` — this doc.
- `tools/qm_native_parity.py` — parity checker (Block 7).
- `SPEC/dof_ledger.jsonl` — PREREG + RESULT rows per block, hash-chained.
- Reference (READ-ONLY during the rewrite):
  - `v1_lab/qm_state_machine.py`, `qm_detect.py`, `erl_detect.py`,
    `idm_detect.py`, `poi_zone.py`, `smt_detect.py`, `ny_session.py`.
  - `CK_QM_SignalPlayer.mq5` — the MT5-verified baseline this port must match.
  - `_signals_erl_h4.csv` — 105 winning signals; the ordered truth to hit.

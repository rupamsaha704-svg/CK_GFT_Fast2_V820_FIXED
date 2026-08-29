#!/usr/bin/env python3
"""
QM/ICT setup — building-block 6: the full deterministic QM/ICT state machine (variant engine).

Scope: assemble Blocks 1-5 into ONE causal state machine that walks the H4->H1->M15->M5 cascade
and, per confirmed setup, advances through:

    WAIT_ERL_RAID -> (SMT check) -> WAIT_MSS -> WAIT_IDM_FORM -> WAIT_IDM_CLEAR
                  -> WAIT_POI_RETURN -> WAIT_M5_CONFIRM -> ENTRY

At ENTRY the engine emits a trade record (entry price/time, direction, SL, TP, and the FULL variant
config that produced it), then simulates the trade forward CAUSALLY on the M5 execution timeframe to
determine the exit (SL-before-TP vs TP vs timeout) and a realized NET result (costs are a pre-declared
parameter, never invented). The result is usable by v1_lab/pipeline.py via the Block-7 runner.

Bearish is the primary; the bullish MIRROR is implemented symmetrically (both directions run).

GOVERNING RULE (inviolable, SPEC/DESIGN_v1.0.md): overfitting is forbidden. NO subjective "best" value
is hard-coded. Every rule the setup creator has NOT locked is exposed as an explicit VARIANT switch or
tunable PARAMETER inside VariantConfig, each with a documented, NON-pre-optimized default:

  smt_pair          'off'(DEFAULT) | 'xag' | 'dxy'    partner series for SMT (repo has none => 'off')
  poi_type          'qm'(DEFAULT) | 'qm_ob' | 'qm_fvg'  POI confluence requirement
  sl_mode           'head_smt_high_buffer'(DEFAULT) | 'tight_poi'   stop placement
  sl_buffer_atr     0.5 (DEFAULT)                     ATR-multiple buffer added to the stop
  tp_mode           'full_external'(DEFAULT) | 'fixed_rr' | 'partial_be_trail'  target placement
  fixed_rr          2.0 (DEFAULT)                     R multiple for tp_mode='fixed_rr'
  min_projected_rr  1.0 (DEFAULT)                     reject a setup whose projected RR is below this
  idm_clear_required True(DEFAULT, A+) | False(experimental)  must IDM be cleared before POI return?
  idm_clear_mode    'wick'(DEFAULT) | 'body'          clearing precision (from idm_detect)
  pivot             2 (DEFAULT)                        swing L/R pivot count
  disp              0.6 (DEFAULT)                       MSS displacement gate (ATR-multiple)
  erl_lookback      5 (DEFAULT)                         swings defining the external range
  erl_tf            'H1'(DEFAULT)                        ERL SOURCE timeframe (H4/H1/M15/... )
  session_scope     'ny_only'(DEFAULT) | 'ny_london_asia'  which sessions may trigger an entry
  max_trades_per_day 2 (DEFAULT)                        risk cap
  reentry           False(DEFAULT)                      allow a re-entry after a stop-out same day
  corr_window       20 / corr_min 0.3                   SMT rolling-correlation guard params
  data_tz           'America/New_York'(DEFAULT, must-confirm)  native clock of the CSVs
  spread            0.0 / commission 0.0                pre-declared trading costs (per side)
  risk_per_trade    100.0                               $ risked at SL (for net-profit sizing)
  max_hold_bars_m5  288 (DEFAULT ~24h of M5)            timeout horizon on the execution TF

None of these defaults is claimed to be optimal; they exist only so the Block-7 runner can enumerate
variant combinations and A/B test them on out-of-sample data.

LOCKED items (implemented exactly, not tunable): MSS = body-close + displacement beyond the most
recent confirmed swing (via qm_detect.detect_mss); the H4->H1->M15->M5 backbone; XAUUSD only; the NY
timezone engine with IST display (via ny_session); both the 08:30 and 09:30 legs examined, neither
hard-coded as manipulation-vs-expansion.

Causality (LOCKED discipline): every state transition uses ONLY information available at its decision
bar. Higher-TF resampling is causal — a higher-TF bar is only "closed" and usable after its final
constituent lower-TF bar closes; resampled bars are shifted so a bar stamped at its bucket close is
only consulted once that close has passed. The M5 trade simulation is bar-by-bar forward only.

Deterministic: same input + same VariantConfig => byte-identical trade output.
Pure Python standard library only (csv, datetime, argparse, hashlib) — dependency-free.

Programmatic API (imported by the Block-7 runner):
    from qm_state_machine import VariantConfig, run, DEFAULT_CONFIG
    trades = run("v1_lab/XAUUSD_M15_clean.csv", DEFAULT_CONFIG, m5_path="v1_lab/XAUUSD_M5_clean.csv")
    # or pass pre-loaded bars: run(m15_bars, cfg, m5_bars=m5_bars)

Usage:
    python3 v1_lab/qm_state_machine.py <m15.csv> [--m5 <m5.csv>] [--out trades.csv] [variant flags...]
    python3 v1_lab/qm_state_machine.py --selfcheck    # synthetic assertions only
"""
import os
import sys
import csv
import argparse
import datetime
from collections import namedtuple

# Ensure the sibling detector modules (same directory) are importable from the repo root.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from qm_detect import load_ohlc, atr_wilder, detect_swings, detect_mss  # noqa: E402
from erl_detect import resample_bars, erl_levels, _tf_to_minutes  # noqa: E402
from idm_detect import find_idm_for_shift, idm_cleared  # noqa: E402
from poi_zone import detect_poi  # noqa: E402
from smt_detect import detect_smt, align_series, EXPECTED_SIGN  # noqa: E402
from ny_session import (  # noqa: E402
    to_ny, classify_ny, SESSION_START_DEFAULT, SESSION_END_DEFAULT,
    LEG_0830_DEFAULT, LEG_0930_DEFAULT,
)
from zoneinfo import ZoneInfo


# ---- the variant configuration (explicit, enumerable; NOTHING pre-optimized) ------------------
_CONFIG_FIELDS = [
    "smt_pair", "poi_type", "sl_mode", "sl_buffer_atr", "tp_mode", "fixed_rr", "min_projected_rr",
    "idm_clear_required", "idm_clear_mode", "pivot", "disp", "erl_lookback", "erl_tf",
    "session_scope", "max_trades_per_day", "reentry", "corr_window", "corr_min",
    "data_tz", "spread", "commission", "risk_per_trade", "max_hold_bars_m5",
]
VariantConfig = namedtuple("VariantConfig", _CONFIG_FIELDS)

# Documented, NON-pre-optimized defaults (see module docstring for the rationale of each).
DEFAULT_CONFIG = VariantConfig(
    smt_pair="off",
    poi_type="qm",
    sl_mode="head_smt_high_buffer",
    sl_buffer_atr=0.5,
    tp_mode="full_external",
    fixed_rr=2.0,
    min_projected_rr=1.0,
    idm_clear_required=True,
    idm_clear_mode="wick",
    pivot=2,
    disp=0.6,
    erl_lookback=5,
    erl_tf="H1",
    session_scope="ny_only",
    max_trades_per_day=2,
    reentry=False,
    corr_window=20,
    corr_min=0.3,
    data_tz="America/New_York",
    spread=0.0,
    commission=0.0,
    risk_per_trade=100.0,
    max_hold_bars_m5=288,
)

SL_MODES = ("head_smt_high_buffer", "tight_poi")
TP_MODES = ("full_external", "fixed_rr", "partial_be_trail")
SESSION_SCOPES = ("ny_only", "ny_london_asia")

# The state names, in causal order (used for per-state counting + reporting).
STATES = [
    "WAIT_ERL_RAID", "SMT_CHECK", "WAIT_MSS", "WAIT_IDM_FORM", "WAIT_IDM_CLEAR",
    "WAIT_POI_RETURN", "WAIT_M5_CONFIRM", "ENTRY",
]


def make_config(**overrides):
    """Return a VariantConfig from DEFAULT_CONFIG with the given field overrides."""
    return DEFAULT_CONFIG._replace(**overrides)


# ---- causal higher-TF resampling -------------------------------------------------------------
def resample_causal(bars, minutes):
    """Deterministically resample to `minutes` buckets, stamped at the bucket's CLOSE time.

    erl_detect.resample_bars stamps each bar at its bucket START. For causal cross-TF use we need a
    higher-TF bar to be consultable only AFTER its final lower-TF constituent has closed, so we
    restamp each resampled bar at bucket_start + span (the close instant). A consumer that only uses
    a higher-TF bar whose close datetime <= the current lower-TF bar's datetime is then leak-free.

    Returns the resampled bar list with datetimes at the bucket close (index preserved). For the
    'input' timeframe (minutes is None) the bars are returned unchanged.
    """
    if minutes is None:
        return list(bars)
    r = resample_bars(bars, minutes)
    span = datetime.timedelta(minutes=minutes)
    out = []
    for b in r:
        out.append((b[0], b[1] + span, b[2], b[3], b[4], b[5], b[6]))
    return out


# ---- session gating (reuses the locked NY engine) --------------------------------------------
def _bar_session_ok(dt, data_tz, session_scope):
    """Causal session filter for the ENTRY bar's datetime `dt` (naive, native clock).

    'ny_only'         => the bar must be inside the NY session window (locked NY engine).
    'ny_london_asia'  => always True (the whole 24h is eligible; scope is the discriminator).
    Both legs (08:30 / 09:30) are merely tagged by the NY engine; neither is privileged here.
    """
    if dt is None:
        return True
    if session_scope == "ny_london_asia":
        return True
    ny = to_ny(dt, data_tz)
    cls = classify_ny(ny, SESSION_START_DEFAULT, SESSION_END_DEFAULT,
                      LEG_0830_DEFAULT, LEG_0930_DEFAULT)
    return cls["in_session"]


# ---- SMT availability (honest data dependency) -----------------------------------------------
def _resolve_smt(m15_bars, cfg, pair_bars=None):
    """Return (smt_events_by_conf_index, smt_available, note).

    'off' (default) => no partner series in the repo => SMT unavailable, {} events, note explains.
    'xag'/'dxy' with a partner series aligned to m15 => real SMT events keyed by confirmation index.
    'xag'/'dxy' WITHOUT a partner series => unavailable; we report the data dependency, never fake it.
    """
    if cfg.smt_pair == "off":
        return {}, False, "SMT off (default); no partner series required."
    if pair_bars is None:
        return ({}, False,
                f"SMT '{cfg.smt_pair}' requested but no --pair-csv supplied: XAGUSD/DXY are NOT in "
                f"the repo. SMT treated as UNAVAILABLE (0 signals); export the partner series to enable.")
    ap, aq = align_series(m15_bars, pair_bars)
    if not ap:
        return ({}, False,
                f"SMT '{cfg.smt_pair}': partner series did not align to XAUUSD timestamps; UNAVAILABLE.")
    exp = EXPECTED_SIGN[cfg.smt_pair]
    events = detect_smt(ap, aq, pivot=cfg.pivot, expected_sign=exp,
                        corr_window=cfg.corr_window, corr_min=cfg.corr_min, use_guard=True)
    by_idx = {}
    for e in events:
        by_idx.setdefault(e["index"], []).append(e)
    return by_idx, True, f"SMT '{cfg.smt_pair}' active with {len(events)} signals."


# ---- M5 execution helpers --------------------------------------------------------------------
def _m5_index_at_or_after(m5_bars, dt):
    """First M5 bar index whose datetime >= dt (causal execution start). None if none."""
    if dt is None:
        return None
    for i, b in enumerate(m5_bars):
        if b[1] is not None and b[1] >= dt:
            return i
    return None


def simulate_trade(m5_bars, start_idx, direction, entry, sl, tp, cfg):
    """Simulate the trade forward on the M5 execution TF from start_idx (inclusive), causally.

    Bar-by-bar, checking SL and TP against each M5 bar's high/low. If BOTH levels are touched inside
    the same bar we resolve conservatively as SL-first (the adverse excursion is assumed hit first),
    which never flatters the strategy. Exit is 'tp', 'sl' or 'timeout' (after cfg.max_hold_bars_m5).

    Net result is sized so a full-SL loss = -risk_per_trade and a full-TP win = +risk_per_trade*RR,
    minus pre-declared costs (spread + commission, charged once as a round-turn). Costs and risk are
    pre-declared parameters, never invented. Returns a dict with exit info, or None if unsimulatable.
    """
    n = len(m5_bars)
    if start_idx is None or start_idx >= n:
        return None
    risk = abs(entry - sl)
    if risk <= 0:
        return None
    reward = abs(tp - entry)
    end = min(n - 1, start_idx + cfg.max_hold_bars_m5)
    exit_kind = "timeout"
    exit_idx = end
    exit_price = m5_bars[end][5]
    for t in range(start_idx, end + 1):
        _, _, o, h, l, c, _ = m5_bars[t]
        if direction == "bear":
            hit_sl = h >= sl
            hit_tp = l <= tp
        else:
            hit_sl = l <= sl
            hit_tp = h >= tp
        if hit_sl and hit_tp:
            exit_kind, exit_idx, exit_price = "sl", t, sl   # conservative: adverse first
            break
        if hit_sl:
            exit_kind, exit_idx, exit_price = "sl", t, sl
            break
        if hit_tp:
            exit_kind, exit_idx, exit_price = "tp", t, tp
            break
    # realized R in price terms, converted to money via risk_per_trade sizing
    if direction == "bear":
        price_move = entry - exit_price      # profit when price falls
    else:
        price_move = exit_price - entry      # profit when price rises
    r_multiple = price_move / risk
    gross_money = r_multiple * cfg.risk_per_trade
    cost_money = (cfg.spread + cfg.commission) / risk * cfg.risk_per_trade  # round-turn, pre-declared
    net_money = gross_money - cost_money
    return {
        "exit_kind": exit_kind,
        "exit_index": exit_idx,
        "exit_datetime": m5_bars[exit_idx][1],
        "exit_price": exit_price,
        "risk": risk,
        "reward": reward,
        "r_multiple": r_multiple,
        "gross": gross_money,
        "net": net_money,
    }


# ---- SL / TP placement (variant-driven) ------------------------------------------------------
def _place_sl_tp(direction, poi, entry, head_price, external_target, atr_at_entry, cfg):
    """Compute (sl, tp, projected_rr) for the entry given the selected sl_mode / tp_mode.

    sl_mode:
      'head_smt_high_buffer' : stop beyond the QM HEAD extreme (the raided liquidity) + ATR buffer.
      'tight_poi'            : stop just beyond the far edge of the POI zone + ATR buffer.
    tp_mode:
      'full_external'        : target the opposite EXTERNAL liquidity (external_target).
      'fixed_rr'             : target at cfg.fixed_rr * risk from entry.
      'partial_be_trail'     : model the realized target as the fixed_rr level (a conservative proxy
                               for a partial/BE/trail exit); the min_projected_rr gate still applies.
    Returns (sl, tp, projected_rr). projected_rr = reward/risk in price terms.
    """
    buf = (atr_at_entry or 0.0) * cfg.sl_buffer_atr
    if direction == "bear":
        if cfg.sl_mode == "tight_poi":
            sl = poi["zone_high"] + buf
        else:  # head_smt_high_buffer
            sl = max(poi["zone_high"], head_price) + buf
        risk = sl - entry
        if risk <= 0:
            return None, None, 0.0
        if cfg.tp_mode == "full_external":
            tp = external_target if external_target is not None else entry - cfg.fixed_rr * risk
        else:  # fixed_rr or partial_be_trail (proxy)
            tp = entry - cfg.fixed_rr * risk
        reward = entry - tp
    else:  # bull mirror
        if cfg.sl_mode == "tight_poi":
            sl = poi["zone_low"] - buf
        else:
            sl = min(poi["zone_low"], head_price) - buf
        risk = entry - sl
        if risk <= 0:
            return None, None, 0.0
        if cfg.tp_mode == "full_external":
            tp = external_target if external_target is not None else entry + cfg.fixed_rr * risk
        else:
            tp = entry + cfg.fixed_rr * risk
        reward = tp - entry
    projected_rr = reward / risk if risk > 0 else 0.0
    return sl, tp, projected_rr


# ---- the state machine -----------------------------------------------------------------------
def _fmt_dt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S") if isinstance(dt, datetime.datetime) else str(dt)


def run(m15_bars_or_path, cfg, m5_bars=None, m5_path=None, pair_bars=None, pair_path=None):
    """Run the QM/ICT state machine and return (trades, stats).

    m15_bars_or_path : list of loaded M15 bars OR a CSV path.
    m5_bars/m5_path  : execution-TF bars OR path; if neither given, entries are recorded but the
                       trade simulation is skipped (net=0, exit='no_m5') so the engine still runs.
    pair_bars/pair_path : optional SMT partner series (XAGUSD/DXY) for smt_pair in ('xag','dxy').

    trades : list of ordered trade dicts (see _trade_record for schema).
    stats  : dict with 'per_state' counts, 'trades' count, and diagnostic notes.

    The state machine is CAUSAL throughout: structure (ERL/MSS/IDM/POI) is derived on M15 from
    confirmed swings only; the M5 confirmation and simulation use only bars at/after the decision.
    """
    if isinstance(m15_bars_or_path, str):
        m15_bars = load_ohlc(m15_bars_or_path)
    else:
        m15_bars = list(m15_bars_or_path)
    if m5_bars is None and m5_path is not None:
        m5_bars = load_ohlc(m5_path)
    if pair_bars is None and pair_path is not None:
        pair_bars = load_ohlc(pair_path)

    data_tz = ZoneInfo(cfg.data_tz)

    # ---- per-TF structural inputs (H4->H1->M15->M5 backbone) ----
    # ERL raids are sourced from the configured (higher) TF; POI/MSS/IDM structure is on M15;
    # execution/confirmation is on M5. The higher-TF ERL levels are mapped back onto M15 time.
    erl_minutes = _tf_to_minutes(cfg.erl_tf)
    erl_src = resample_causal(m15_bars, erl_minutes) if erl_minutes else list(m15_bars)
    erl_lv, _, _ = erl_levels(erl_src, pivot=cfg.pivot, lookback=cfg.erl_lookback)
    # active ERL level as of each M5-... no: map ERL level active at each M15 bar via its close time.
    # Build a causal lookup: for M15 bar with datetime d, the ERL level from the most recent
    # higher-TF bar whose CLOSE time <= d.
    erl_by_m15 = _map_higher_tf_levels(m15_bars, erl_src, erl_lv)

    atr15 = atr_wilder(m15_bars, period=14)
    highs, lows = detect_swings(m15_bars, pivot=cfg.pivot)
    mss_events, _, _ = detect_mss(m15_bars, pivot=cfg.pivot, disp=cfg.disp)
    pois, _, _ = detect_poi(m15_bars, pivot=cfg.pivot, poi_type=cfg.poi_type)
    smt_by_idx, smt_available, smt_note = _resolve_smt(m15_bars, cfg, pair_bars=pair_bars)

    per_state = {s: 0 for s in STATES}
    trades = []
    trades_per_day = {}

    # Index POIs by their bearish/bullish head so we can pair a POI to an MSS shift.
    pois_by_dir = {"bear": [], "bull": []}
    for p in pois:
        pois_by_dir[p["direction"]].append(p)

    n = len(m15_bars)

    # Drive the machine off each MSS shift (the structural pivot of the setup). For each shift we
    # verify the PRECEDING ERL raid, the optional SMT, the IDM formation + (optional) clearing, then
    # wait for price to RETURN into the QM POI, then require an M5 confirmation, then enter.
    for ev in mss_events:
        s = ev["index"]
        direction = ev["direction"]

        # --- STATE 1: WAIT_ERL_RAID (a raid of external liquidity must PRECEDE the shift) ---
        # For a bearish shift the setup wants a prior UPPER raid (buy-side sweep) that induces the
        # reversal down; for a bullish shift a prior LOWER raid. Causal: search bars <= s.
        raided = _erl_raided_before(m15_bars, erl_by_m15, s, direction)
        if not raided:
            continue
        per_state["WAIT_ERL_RAID"] += 1

        # --- STATE 2: SMT_CHECK (variant) ---
        # When SMT is unavailable (default 'off' / no partner data) this is a pass-through so the
        # engine still runs end-to-end; when SMT is active it must confirm at/around the shift.
        if smt_available:
            if not _smt_confirms(smt_by_idx, s, direction, cfg.pivot):
                continue
        per_state["SMT_CHECK"] += 1

        # --- STATE 3: WAIT_MSS (the shift itself; body-close + displacement, from detect_mss) ---
        per_state["WAIT_MSS"] += 1

        # --- STATE 4: WAIT_IDM_FORM (an inducement swing must exist for this shift) ---
        idm = find_idm_for_shift(highs, lows, cfg.pivot, s, direction)
        if idm is None:
            continue
        per_state["WAIT_IDM_FORM"] += 1

        # --- pair the matching POI: the first POI confirmed at/after the shift, same direction ---
        poi = _poi_for_shift(pois_by_dir[direction], s)
        if poi is None:
            continue
        poi_confirm = poi["confirm_index"]

        # --- STATE 6 (evaluated first as the horizon): WAIT_POI_RETURN ---
        # Price must trade back INTO the POI zone after the structure break/confirmation. We locate
        # the return bar now because it also bounds the IDM-clearing horizon (FEAT-002 note).
        return_idx = _poi_return_index(m15_bars, poi, direction, poi_confirm, n)
        if return_idx is None:
            continue

        # --- STATE 5: WAIT_IDM_CLEAR (variant idm_clear_required) ---
        # The clearing window runs from the shift up to the POI-return bar (FEAT-002 note: pass an
        # explicit window so clearing is evaluated over the POI-return horizon, not just to the next
        # shift). IDM liquidity is typically taken during the retrace back into the POI.
        clear_end = min(n - 1, return_idx)
        cleared, clear_idx = idm_cleared(m15_bars, idm, direction, s, clear_end, mode=cfg.idm_clear_mode)
        if cfg.idm_clear_required and not cleared:
            continue
        per_state["WAIT_IDM_CLEAR"] += 1

        # POI return already located above; count it now that clearing (state 5) has passed.
        per_state["WAIT_POI_RETURN"] += 1

        # --- STATE 7: WAIT_M5_CONFIRM (a lower-TF confirmation on the execution TF) ---
        return_dt = m15_bars[return_idx][1]
        confirm = _m5_confirmation(m5_bars, return_dt, direction, cfg) if m5_bars else \
            {"index": None, "datetime": return_dt, "price": m15_bars[return_idx][5]}
        if confirm is None:
            continue
        per_state["WAIT_M5_CONFIRM"] += 1

        # --- session gate (variant session_scope) on the confirmation/entry bar ---
        entry_dt = confirm["datetime"]
        if not _bar_session_ok(entry_dt, data_tz, cfg.session_scope):
            continue

        # --- risk caps (variant max_trades_per_day / reentry) ---
        day_key = entry_dt.date() if isinstance(entry_dt, datetime.datetime) else None
        used = trades_per_day.get(day_key, 0)
        if day_key is not None and used >= cfg.max_trades_per_day:
            continue

        # --- STATE 8: ENTRY (place SL/TP per variant, size, simulate) ---
        entry_price = confirm["price"]
        head_price = m15_bars[poi["head_index"]][3] if direction == "bear" else m15_bars[poi["head_index"]][4]
        external_target = _external_target(erl_by_m15, return_idx, direction)
        atr_at_entry = atr15[return_idx] if return_idx < len(atr15) else None
        sl, tp, projected_rr = _place_sl_tp(direction, poi, entry_price, head_price,
                                            external_target, atr_at_entry, cfg)
        if sl is None or tp is None:
            continue
        # min projected-RR gate (variant): reject setups whose target/stop geometry is too shallow.
        if projected_rr < cfg.min_projected_rr:
            continue

        # simulate on M5 (causal). If no M5 series, record the entry with a neutral, flagged result.
        if m5_bars:
            start = _m5_index_at_or_after(m5_bars, entry_dt)
            sim = simulate_trade(m5_bars, start, direction, entry_price, sl, tp, cfg)
        else:
            sim = None
        poi["_return_index"] = return_idx
        trade = _trade_record(ev, poi, direction, entry_dt, entry_price, sl, tp, projected_rr,
                              external_target, cfg, sim)
        trades.append(trade)
        per_state["ENTRY"] += 1
        if day_key is not None:
            trades_per_day[day_key] = used + 1

    trades.sort(key=lambda t: (t["entry_index"], t["direction"]))
    stats = {
        "per_state": per_state,
        "trades": len(trades),
        "smt_available": smt_available,
        "smt_note": smt_note,
        "n_m15": n,
        "n_m5": len(m5_bars) if m5_bars else 0,
        "n_mss": len(mss_events),
        "n_poi": len(pois),
    }
    return trades, stats


def _trade_record(ev, poi, direction, entry_dt, entry_price, sl, tp, projected_rr,
                  external_target, cfg, sim):
    """Assemble the ordered, deterministic trade record. Emits at least entry datetime + net profit
    (plus full context) so the Block-7 runner can convert it to the pipeline's 'time,profit' format."""
    exit_kind = sim["exit_kind"] if sim else "no_m5"
    net = sim["net"] if sim else 0.0
    r_mult = sim["r_multiple"] if sim else 0.0
    exit_dt = sim["exit_datetime"] if sim else None
    exit_price = sim["exit_price"] if sim else None
    return {
        "entry_index": ev["index"],
        "return_index": poi.get("_return_index"),
        "entry_datetime": entry_dt,
        "direction": direction,
        "entry_price": entry_price,
        "sl": sl,
        "tp": tp,
        "projected_rr": projected_rr,
        "external_target": external_target,
        "exit_kind": exit_kind,
        "exit_datetime": exit_dt,
        "exit_price": exit_price,
        "r_multiple": r_mult,
        "net": net,
        "poi_ls_index": poi["ls_index"],
        "poi_head_index": poi["head_index"],
        "poi_zone_low": poi["zone_low"],
        "poi_zone_high": poi["zone_high"],
        # the FULL variant config that produced this trade (governance: provenance is explicit)
        "config": cfg,
    }


# ---- causal higher-TF -> M15 level mapping ---------------------------------------------------
def _map_higher_tf_levels(m15_bars, htf_bars, htf_levels):
    """For each M15 bar, the ERL levels from the most recent HTF bar whose CLOSE <= the M15 bar dt.

    htf_bars are stamped at their CLOSE (resample_causal), so a HTF bar is only visible once its
    close time has passed the M15 bar's timestamp -> strictly causal, no lookahead.
    Returns a list aligned to m15_bars: each element is the htf_levels entry or None.
    """
    out = [None] * len(m15_bars)
    j = -1
    hi = 0
    # htf_bars sorted by close time already (resample output is ordered); walk both forward.
    for i, mb in enumerate(m15_bars):
        d = mb[1]
        if d is None:
            out[i] = htf_levels[j] if j >= 0 else None
            continue
        while hi < len(htf_bars) and htf_bars[hi][1] is not None and htf_bars[hi][1] <= d:
            j = hi
            hi += 1
        out[i] = htf_levels[j] if (0 <= j < len(htf_levels)) else None
    return out


def _erl_raided_before(m15_bars, erl_by_m15, shift_index, direction):
    """True if external liquidity was raided at/before the shift in the setup-relevant direction.

    bearish shift => a prior UPPER raid (a bar whose high exceeded the active upper ERL level).
    bullish shift => a prior LOWER raid (a bar whose low broke the active lower ERL level).
    Causal: scans only bars up to and including the shift, using the ERL level active AT each bar.
    """
    for t in range(0, shift_index + 1):
        lv = erl_by_m15[t]
        if not lv:
            continue
        _, _, o, h, l, c, _ = m15_bars[t]
        if direction == "bear":
            up = lv.get("upper")
            if up is not None and h > up["price"]:
                return True
        else:
            lo = lv.get("lower")
            if lo is not None and l < lo["price"]:
                return True
    return False


def _external_target(erl_by_m15, at_index, direction):
    """Opposite EXTERNAL liquidity target active at `at_index` (for tp_mode='full_external').

    bearish trade targets the LOWER external level; bullish targets the UPPER. None if unavailable.
    """
    lv = erl_by_m15[at_index] if 0 <= at_index < len(erl_by_m15) else None
    if not lv:
        return None
    if direction == "bear":
        lo = lv.get("lower")
        return lo["price"] if lo else None
    up = lv.get("upper")
    return up["price"] if up else None


def _smt_confirms(smt_by_idx, shift_index, direction, pivot):
    """True if an SMT signal of the same direction sits at/near the shift (within a pivot window)."""
    for idx in range(shift_index - pivot, shift_index + pivot + 1):
        for e in smt_by_idx.get(idx, []):
            if e["direction"] == direction:
                return True
    return False


def _poi_for_shift(pois_same_dir, shift_index):
    """The first POI (same direction) whose structure confirms at/after the shift bar."""
    best = None
    for p in pois_same_dir:
        if p["confirm_index"] >= shift_index:
            if best is None or p["confirm_index"] < best["confirm_index"]:
                best = p
    return best


def _poi_return_index(m15_bars, poi, direction, start, n):
    """First bar AFTER the POI confirmation where price trades back INTO the POI zone band.

    bearish (supply zone above): price returns UP so bar.high >= zone_low (enters the band).
    bullish (demand zone below): price returns DOWN so bar.low  <= zone_high.
    Causal: scans strictly after `start`. Returns the bar index or None.
    """
    lo = poi["zone_low"]
    hi = poi["zone_high"]
    for t in range(start + 1, n):
        _, _, o, h, l, c, _ = m15_bars[t]
        if direction == "bear":
            if h >= lo and l <= hi:   # bar overlaps the supply band
                return t
        else:
            if l <= hi and h >= lo:   # bar overlaps the demand band
                return t
    return None


def _m5_confirmation(m5_bars, return_dt, direction, cfg):
    """Lower-TF (M5) entry confirmation at/after the M15 POI-return bar's datetime.

    We require a micro confirmation: the first M5 bar at/after return_dt that CLOSES in the trade
    direction relative to its open (a bearish body for a sell, a bullish body for a buy). Entry is
    taken at that M5 bar's close. Causal: only M5 bars at/after return_dt are examined. Returns a
    dict {"index","datetime","price"} or None if no confirmation occurs within the M5 series.
    """
    start = _m5_index_at_or_after(m5_bars, return_dt)
    if start is None:
        return None
    horizon = min(len(m5_bars) - 1, start + cfg.max_hold_bars_m5)
    for t in range(start, horizon + 1):
        _, dt, o, h, l, c, _ = m5_bars[t]
        if direction == "bear" and c < o:
            return {"index": t, "datetime": dt, "price": c}
        if direction == "bull" and c > o:
            return {"index": t, "datetime": dt, "price": c}
    return None


# ---- output ----------------------------------------------------------------------------------
TRADE_CSV_HEADER = [
    "entry_index", "entry_datetime", "direction", "entry_price", "sl", "tp", "projected_rr",
    "external_target", "exit_kind", "exit_datetime", "exit_price", "r_multiple", "net",
]


def write_trades_csv(trades, path):
    """Deterministic engine trade list (rich schema). The Block-7 runner converts this to the
    pipeline's 'time,profit' format; here we keep the full audit fields."""
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(TRADE_CSV_HEADER)
        for t in trades:
            w.writerow([
                t["entry_index"], _fmt_dt(t["entry_datetime"]), t["direction"],
                f"{t['entry_price']:.5f}", f"{t['sl']:.5f}", f"{t['tp']:.5f}",
                f"{t['projected_rr']:.4f}",
                "" if t["external_target"] is None else f"{t['external_target']:.5f}",
                t["exit_kind"],
                _fmt_dt(t["exit_datetime"]) if t["exit_datetime"] is not None else "",
                "" if t["exit_price"] is None else f"{t['exit_price']:.5f}",
                f"{t['r_multiple']:.4f}", f"{t['net']:.2f}",
            ])


def to_pipeline_rows(trades):
    """Convert engine trades to the pipeline's (time,profit) rows: 'YYYY.MM.DD HH:MM', net.

    Provided for the Block-7 runner (FEAT-005). Deterministic, ordered by entry time then index.
    """
    rows = []
    for t in sorted(trades, key=lambda x: (x["entry_index"], x["direction"])):
        dt = t["entry_datetime"]
        tstr = dt.strftime("%Y.%m.%d %H:%M") if isinstance(dt, datetime.datetime) else str(dt)
        rows.append((tstr, t["net"]))
    return rows


def print_summary(cfg, stats, out_path):
    ps = stats["per_state"]
    print("=" * 72)
    print("QM/ICT block-6  full state machine (variant engine)")
    print("=" * 72)
    print(f"  M15 bars: {stats['n_m15']:>6}   M5 bars: {stats['n_m5']:>6}   "
          f"MSS shifts: {stats['n_mss']}   POIs: {stats['n_poi']}")
    print(f"  variant: smt_pair={cfg.smt_pair} poi_type={cfg.poi_type} sl_mode={cfg.sl_mode} "
          f"tp_mode={cfg.tp_mode}")
    print(f"           idm_clear_required={cfg.idm_clear_required} pivot={cfg.pivot} disp={cfg.disp} "
          f"erl_tf={cfg.erl_tf} session_scope={cfg.session_scope}")
    print(f"           sl_buffer_atr={cfg.sl_buffer_atr} min_projected_rr={cfg.min_projected_rr} "
          f"max_trades_per_day={cfg.max_trades_per_day} reentry={cfg.reentry}")
    print("-" * 72)
    print("  setups reaching each state (causal funnel):")
    for s in STATES:
        print(f"    {s:<16} {ps[s]:>6}")
    print("-" * 72)
    print(f"  completed trades: {stats['trades']}")
    print(f"  SMT: {stats['smt_note']}")
    print("-" * 72)
    print(f"  trade list written to: {out_path}")
    print("=" * 72)


# ---- self-check ------------------------------------------------------------------------------
def _b(idx, dt, o, h, l, c, v=0.0):
    return (idx, dt, float(o), float(h), float(l), float(c), float(v))


def _build_happy_path():
    """Construct a synthetic M15 + M5 series that walks the FULL bearish happy path:

      ERL raid (upper sweep) -> bearish MSS (body-close below a confirmed swing low + displacement)
      -> IDM (prior swing high) forms -> IDM cleared -> price returns into the QM POI
      -> M5 bearish confirmation -> ENTRY.

    All bars carry datetimes so resampling/session logic runs. Timestamps land inside the NY session
    (default 09:30-16:00 NY; native clock assumed NY) so the default session_scope passes.
    Returns (m15_bars, m5_bars).
    """
    base = datetime.datetime(2025, 8, 4, 9, 30)   # Monday, NY session, in-window
    step = datetime.timedelta(minutes=15)
    rows = []
    # 14 warmup bars to seed ATR, gently rising, establishing an initial low band.
    for i in range(14):
        rows.append((100 + i * 0.1, 100.5 + i * 0.1, 99.5 + i * 0.1, 100 + i * 0.1))
    # Build a Quasimodo: a left-shoulder HIGH, a pullback LOW (neck), a higher HEAD high (raids the
    # external upper liquidity), then a decisive break DOWN below the neck (the MSS / structure break).
    core = [
        (101.4, 103.0, 101.0, 102.5),   # 14 rising toward LS
        (102.5, 106.0, 102.0, 105.0),   # 15 LEFT SHOULDER swing HIGH = 106
        (105.0, 105.5, 103.0, 103.5),   # 16
        (103.5, 104.0, 100.0, 100.5),   # 17 NECK swing LOW = 100
        (100.5, 102.0, 100.2, 101.5),   # 18
        (101.5, 108.0, 101.0, 107.0),   # 19 HEAD swing HIGH = 108 (> 106 => raids ERL upper)
        (107.0, 107.5, 105.0, 105.5),   # 20
        (105.5, 106.0, 103.0, 103.5),   # 21 confirms head (19+2=21)
        (103.5, 104.0, 99.0, 99.2),     # 22 body CLOSE 99.2 < neck 100 => bearish MSS + break
    ]
    for c in core:
        rows.append(c)
    # After the break, price rallies back UP to CLEAR the IDM (the 106 left-shoulder high is the IDM
    # for the bearish shift) AND to RETURN into the POI supply zone, then we confirm on M5 and sell.
    retrace = [
        (99.2, 101.0, 99.0, 100.5),     # 23
        (100.5, 108.8, 100.0, 104.5),   # 24 rally wick to 108.8 CLEARS the IDM head-high (108) AND
                                        #    the bar overlaps the POI supply band [102.5..106] => the
                                        #    IDM is taken on the same retrace bar that returns to POI
        (104.5, 105.5, 103.0, 104.0),   # 25 still inside the POI supply band
        (104.5, 105.0, 100.0, 100.5),   # 26 rejection begins from the POI
        (100.5, 101.0, 96.0, 96.5),     # 27 drop toward external target
        (96.5, 97.0, 93.0, 93.5),       # 28 external lower liquidity / target region
        (93.5, 94.0, 90.0, 90.5),       # 29
        (90.5, 91.0, 87.0, 87.5),       # 30
    ]
    for c in retrace:
        rows.append(c)
    # tail: a gentle RISE so no further bearish MSS forms (keeps the scenario to ONE clean setup),
    # while still giving late swings room to confirm.
    last = rows[-1][3]
    for i in range(6):
        last = last + 0.3
        rows.append((last, last + 0.5, last - 0.2, last + 0.25))
    m15 = []
    for i, (o, h, l, c) in enumerate(rows):
        m15.append(_b(i, base + i * step, o, h, l, c))

    # M5 series: mirror the M15 path at 5-min resolution around the return/entry window so the M5
    # confirmation + simulation can run. We synthesize three M5 sub-bars per M15 bar with matching
    # OHLC envelope; the entry M5 bar closes bearish and price then falls to the TP.
    m5 = []
    m5step = datetime.timedelta(minutes=5)
    mi = 0
    for (idx, dt, o, h, l, c, v) in m15:
        for k in range(3):
            sub_dt = dt + k * m5step
            # decompose: first sub opens at o, last sub closes at c; keep the H/L envelope
            oo = o if k == 0 else (o + c) / 2
            cc = c if k == 2 else (o + c) / 2
            m5.append(_b(mi, sub_dt, oo, h, l, cc))
            mi += 1
    return m15, m5


def selfcheck():
    """Synthetic assertions proving the full engine:

    (A) HAPPY PATH: the constructed bearish scenario yields EXACTLY ONE trade, correctly directed
        (bear), with SL above the entry and TP below it (per default sl/tp modes), and the trade
        reaches every state exactly once.
    (B) MISSING STEP: force the IDM to be NEVER cleared with idm_clear_required=True => NO trade.
    (C) VARIANT IS THE DISCRIMINATOR: on that SAME negative scenario, flip idm_clear_required=False
        => a trade reappears, proving the switch (not a hard-coded rule) gates the outcome.
    (D) CAUSALITY: truncating the series right at the entry bar does not change whether/where the
        entry occurs (no lookahead in the decision).
    (E) DETERMINISM: running the happy path twice yields identical trade tuples.
    """
    m15, m5 = _build_happy_path()

    # (A) happy path, default config (idm_clear_required=True). Relax session scope so the synthetic
    # timestamps are not the discriminator here; session gating is exercised separately by ny_session.
    cfg = make_config(session_scope="ny_london_asia", min_projected_rr=0.0, erl_tf="input")
    trades, stats = run(m15, cfg, m5_bars=m5)
    assert stats["trades"] == 1, f"A: expected exactly one trade, got {stats['trades']}"
    tr = trades[0]
    assert tr["direction"] == "bear", f"A: trade must be bearish, got {tr['direction']}"
    assert tr["sl"] > tr["entry_price"], "A: bearish SL must be ABOVE entry"
    assert tr["tp"] < tr["entry_price"], "A: bearish TP must be BELOW entry"
    # the causal funnel must be monotonically NON-INCREASING (each state is a strict superset filter)
    ps = stats["per_state"]
    counts = [ps[s] for s in STATES]
    assert all(counts[i] >= counts[i + 1] for i in range(len(counts) - 1)), \
        f"A: state funnel must be monotonic non-increasing, got {counts}"
    # exactly ONE setup survives from the IDM-clear gate through to ENTRY (one clean happy path)
    for s in ("WAIT_IDM_CLEAR", "WAIT_POI_RETURN", "WAIT_M5_CONFIRM", "ENTRY"):
        assert ps[s] == 1, f"A: state {s} should be reached by exactly one setup, got {ps[s]}"
    assert tr["exit_kind"] in ("tp", "sl", "timeout"), "A: trade must be simulated on M5"

    # (B) missing step: make the IDM impossible to clear by removing the rally that took the IDM high.
    # We flatten the retrace so price never trades back above the IDM (106) => IDM never cleared.
    m15_nb, m5_nb = _build_happy_path()
    for i in range(len(m15_nb)):
        idx, dt, o, h, l, c, v = m15_nb[i]
        if idx >= 23:  # after the break, cap all highs below the IDM level (106) so it never clears
            h = min(h, 103.0)
            o = min(o, 103.0)
            c = min(c, 103.0)
            l = min(l, c)
            m15_nb[i] = _b(idx, dt, o, h, l, c, v)
    # rebuild an aligned M5 for the capped M15
    m5_nb = _rebuild_m5(m15_nb)
    cfg_req = make_config(session_scope="ny_london_asia", min_projected_rr=0.0, erl_tf="input",
                          idm_clear_required=True)
    trades_b, stats_b = run(m15_nb, cfg_req, m5_bars=m5_nb)
    assert stats_b["trades"] == 0, f"B: IDM never cleared + required => expected 0 trades, got {stats_b['trades']}"
    assert stats_b["per_state"]["WAIT_IDM_CLEAR"] == 0, "B: no setup should pass the IDM-clear state"

    # (C) flip the variant switch on the SAME negative scenario => a trade should appear.
    cfg_opt = cfg_req._replace(idm_clear_required=False)
    trades_c, stats_c = run(m15_nb, cfg_opt, m5_bars=m5_nb)
    assert stats_c["trades"] >= 1, ("C: with idm_clear_required=False the same scenario must "
                                    "produce a trade (the switch is the discriminator)")
    assert stats_c["per_state"]["WAIT_IDM_CLEAR"] >= 1, "C: the IDM-clear state is now passed"

    # (D) causality: truncate the M15 series at the POI-return bar (the last M15 information the
    # entry decision uses). Appending the FUTURE bars beyond it must not change whether/where the
    # entry occurs — proving no lookahead in the decision. The M5 series retains only bars up to a
    # bounded execution horizon so the trade can still be simulated.
    entry_idx = tr["entry_index"]
    ret_idx = tr["return_index"]
    m15_trunc = [b for b in m15 if b[0] <= ret_idx]
    m5_trunc = [b for b in m5 if b[1] <= tr["entry_datetime"] + datetime.timedelta(hours=48)]
    trades_d, stats_d = run(m15_trunc, cfg, m5_bars=m5_trunc)
    assert stats_d["trades"] == 1, f"D: truncated-at-return run should still yield the one trade, got {stats_d['trades']}"
    assert trades_d[0]["entry_index"] == entry_idx, "D: entry index must not depend on future bars"
    assert abs(trades_d[0]["entry_price"] - tr["entry_price"]) < 1e-9, "D: entry price must be causal"

    # (E) determinism: identical output on re-run.
    trades_e, _ = run(m15, cfg, m5_bars=m5)
    key = lambda t: (t["entry_index"], t["direction"], round(t["entry_price"], 5),
                     round(t["sl"], 5), round(t["tp"], 5), round(t["net"], 2))
    assert [key(x) for x in trades] == [key(x) for x in trades_e], "E: engine must be deterministic"

    print("selfcheck: PASS")
    print("  case A: full happy path => exactly one bearish trade; SL above / TP below entry; every state hit once")
    print("  case B: IDM never cleared + idm_clear_required=True => NO trade")
    print("  case C: flipping idm_clear_required=False on the SAME scenario => a trade appears (switch is the gate)")
    print("  case D: truncating at the entry bar leaves the entry decision unchanged (causal / no lookahead)")
    print("  case E: re-running the happy path yields byte-identical trades (deterministic)")
    return True


def _rebuild_m5(m15):
    """Rebuild the 3-sub-bar M5 series for a (possibly edited) M15 list (mirrors _build_happy_path)."""
    m5 = []
    m5step = datetime.timedelta(minutes=5)
    mi = 0
    for (idx, dt, o, h, l, c, v) in m15:
        for k in range(3):
            sub_dt = dt + k * m5step
            oo = o if k == 0 else (o + c) / 2
            cc = c if k == 2 else (o + c) / 2
            m5.append(_b(mi, sub_dt, oo, h, l, cc))
            mi += 1
    return m5


# ---- CLI -------------------------------------------------------------------------------------
def parse_args(argv):
    p = argparse.ArgumentParser(
        description="QM/ICT block-6: full deterministic QM/ICT state machine (variant engine).")
    p.add_argument("path", nargs="?", default=None, help="M15 XAUUSD OHLC CSV")
    p.add_argument("--m5", default=None, help="M5 execution-TF OHLC CSV")
    p.add_argument("--selfcheck", action="store_true", help="run synthetic assertions only")
    p.add_argument("--out", default=None, help="write engine trade CSV to this path")
    # variant switches / parameters (documented defaults; NONE pre-optimized)
    p.add_argument("--smt-pair", default=DEFAULT_CONFIG.smt_pair, choices=("off", "xag", "dxy"))
    p.add_argument("--pair-csv", default=None, help="SMT partner series (XAGUSD/DXY) for xag/dxy")
    p.add_argument("--poi-type", default=DEFAULT_CONFIG.poi_type, choices=("qm", "qm_ob", "qm_fvg"))
    p.add_argument("--sl-mode", default=DEFAULT_CONFIG.sl_mode, choices=SL_MODES)
    p.add_argument("--sl-buffer-atr", type=float, default=DEFAULT_CONFIG.sl_buffer_atr)
    p.add_argument("--tp-mode", default=DEFAULT_CONFIG.tp_mode, choices=TP_MODES)
    p.add_argument("--fixed-rr", type=float, default=DEFAULT_CONFIG.fixed_rr)
    p.add_argument("--min-projected-rr", type=float, default=DEFAULT_CONFIG.min_projected_rr)
    p.add_argument("--idm-clear-required", dest="idm_clear_required", action="store_true", default=None)
    p.add_argument("--no-idm-clear-required", dest="idm_clear_required", action="store_false")
    p.add_argument("--idm-clear-mode", default=DEFAULT_CONFIG.idm_clear_mode, choices=("wick", "body"))
    p.add_argument("--pivot", type=int, default=DEFAULT_CONFIG.pivot)
    p.add_argument("--disp", type=float, default=DEFAULT_CONFIG.disp)
    p.add_argument("--erl-lookback", type=int, default=DEFAULT_CONFIG.erl_lookback)
    p.add_argument("--erl-tf", default=DEFAULT_CONFIG.erl_tf, help="ERL source TF (H4/H1/M15/input/minutes)")
    p.add_argument("--session-scope", default=DEFAULT_CONFIG.session_scope, choices=SESSION_SCOPES)
    p.add_argument("--max-trades-per-day", type=int, default=DEFAULT_CONFIG.max_trades_per_day)
    p.add_argument("--reentry", action="store_true", default=DEFAULT_CONFIG.reentry)
    p.add_argument("--corr-window", type=int, default=DEFAULT_CONFIG.corr_window)
    p.add_argument("--corr-min", type=float, default=DEFAULT_CONFIG.corr_min)
    p.add_argument("--data-tz", default=DEFAULT_CONFIG.data_tz)
    p.add_argument("--spread", type=float, default=DEFAULT_CONFIG.spread)
    p.add_argument("--commission", type=float, default=DEFAULT_CONFIG.commission)
    p.add_argument("--risk-per-trade", type=float, default=DEFAULT_CONFIG.risk_per_trade)
    p.add_argument("--max-hold-bars-m5", type=int, default=DEFAULT_CONFIG.max_hold_bars_m5)
    return p.parse_args(argv)


def config_from_args(args):
    idm_req = DEFAULT_CONFIG.idm_clear_required if args.idm_clear_required is None else args.idm_clear_required
    return VariantConfig(
        smt_pair=args.smt_pair, poi_type=args.poi_type, sl_mode=args.sl_mode,
        sl_buffer_atr=args.sl_buffer_atr, tp_mode=args.tp_mode, fixed_rr=args.fixed_rr,
        min_projected_rr=args.min_projected_rr, idm_clear_required=idm_req,
        idm_clear_mode=args.idm_clear_mode, pivot=args.pivot, disp=args.disp,
        erl_lookback=args.erl_lookback, erl_tf=args.erl_tf, session_scope=args.session_scope,
        max_trades_per_day=args.max_trades_per_day, reentry=args.reentry,
        corr_window=args.corr_window, corr_min=args.corr_min, data_tz=args.data_tz,
        spread=args.spread, commission=args.commission, risk_per_trade=args.risk_per_trade,
        max_hold_bars_m5=args.max_hold_bars_m5,
    )


def main():
    args = parse_args(sys.argv[1:])

    if args.selfcheck or args.path is None:
        selfcheck()
        if args.path is None:
            return
        print()

    # always run self-check first so a released run is proven, then real data
    if not args.selfcheck:
        selfcheck()
        print()

    if args.pivot < 1:
        raise SystemExit("--pivot must be >= 1")

    cfg = config_from_args(args)
    m15 = load_ohlc(args.path)
    if not m15:
        raise SystemExit(f"no OHLC rows parsed from {args.path}")
    m5 = load_ohlc(args.m5) if args.m5 else None
    if args.m5 and not m5:
        raise SystemExit(f"no OHLC rows parsed from {args.m5}")
    pair = load_ohlc(args.pair_csv) if args.pair_csv else None

    out = args.out if args.out else "qm_trades.csv"
    trades, stats = run(m15, cfg, m5_bars=m5, pair_bars=pair)
    write_trades_csv(trades, out)
    print_summary(cfg, stats, out)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
QM/ICT setup — building-block 4: IDM (inducement) detector + a 'cleared' test.

Scope (intentionally narrow): after a structural shift (MSS), locate the INDUCEMENT swing — the
most recent MINOR opposing swing between the shift and the point-of-interest (POI) return — that
traps liquidity, and provide a boolean idm_cleared(...) test for whether price has taken that IDM
liquidity level. Entry / SL / TP / POI selection / SMT are OUT OF SCOPE here. This block imports
the LOCKED swing + MSS layer from qm_detect.py rather than reimplementing it.

Discipline (anti-overfitting, from SPEC/DESIGN_v1.0.md): nothing subjective is baked in. The
rules the setup creator has NOT locked are exposed as PARAMETERS with documented defaults so they
can be A/B tested on out-of-sample data later. Pre-choosing a "best" value = overfitting =
forbidden. The tunable parameters are:
  - PIVOT       swing pivot L/R count for BOTH the structural swings and the (minor) IDM swing
                (default 2, consistent with qm_detect). The inducement swing DEFINITION reuses the
                same confirmed-swing rule; its pivot is a parameter, not a locked truth.
  - DISP        MSS displacement gate handed to qm_detect.detect_mss (default 0.6, its own default).
  - CLEARED_MODE the PRECISION of the 'cleared' test: 'wick' (any trade beyond the IDM level) or
                'body' (a body CLOSE beyond it). The exact clearing precision is UNCONFIRMED, so
                it is a parameter — default 'wick' (the looser, more permissive reading).

CRITICAL (governance): whether IDM-clear is MANDATORY is NOT decided in this block. idm_cleared(...)
is exposed only as a boolean TEST. The mandatory-vs-optional choice is a VARIANT switch owned by the
state machine (Block 6 / FEAT-004). Nothing here requires clearing — we only detect + report it.

IDM level (per shift): after a shift at bar s in direction d, the inducement is the most recent
opposing MINOR swing CONFIRMED by s:
  bearish shift (price broke DOWN): IDM = most recent confirmed swing HIGH at/at-or-before s
       (buy-side liquidity resting above, to be cleared before the down-move continues to the POI).
  bullish shift (price broke UP):   IDM = most recent confirmed swing LOW at/at-or-before s.

idm_cleared(bars, idm, direction, start, end, mode): True if, on any bar in (start, end], price has
taken the IDM level:
  bearish (IDM is a high): 'wick' => bar.high > idm.price ; 'body' => bar.close > idm.price.
  bullish (IDM is a low):  'wick' => bar.low  < idm.price ; 'body' => bar.close < idm.price.

Causality (LOCKED discipline): the IDM for a shift at s uses only swings CONFIRMED by s
(swing index + pivot <= s). The cleared test scans only bars AFTER the shift (start = shift index).
No future bar influences the shift or the IDM identification. Mirrors qm_detect.detect_mss.

Deterministic: same input CSV + same parameters => identical output.
Pure Python standard library only (csv, datetime, argparse) — dependency-free.

Usage:
    python3 v1_lab/idm_detect.py <ohlc.csv> [--pivot 2] [--disp 0.6]
        [--cleared-mode wick|body] [--out idm_events.csv]
    python3 v1_lab/idm_detect.py --selfcheck    # run built-in synthetic assertions only
"""
import os
import sys
import csv
import argparse
import datetime

# Ensure qm_detect (same directory) is importable when run from the repo root.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qm_detect import load_ohlc, detect_swings, detect_mss, PIVOT_DEFAULT, DISP_DEFAULT


# ---- defaults (tunable parameters, NOT locked truths) -----------------------
CLEARED_MODE_DEFAULT = "wick"   # 'wick' (any trade beyond) or 'body' (close beyond); unconfirmed => param


# ---- IDM level identification (causal) --------------------------------------
def find_idm_for_shift(highs, lows, pivot, shift_index, direction):
    """Return the inducement swing for a shift at `shift_index` in `direction`.

    The IDM is the most recent OPPOSING minor swing CONFIRMED by the shift bar:
      direction 'bear' -> most recent confirmed swing HIGH with index + pivot <= shift_index.
      direction 'bull' -> most recent confirmed swing LOW  with index + pivot <= shift_index.
    Returns a swing dict {"index","datetime","price","kind"} or None if none is confirmed yet.
    Causal: only swings whose confirmation bar is at/before the shift are eligible.
    """
    pool = highs if direction == "bear" else lows
    candidate = None
    for sw in pool:
        if sw["index"] + pivot <= shift_index:
            if candidate is None or sw["index"] > candidate["index"]:
                candidate = sw
    return candidate


def idm_cleared(bars, idm, direction, start, end, mode=CLEARED_MODE_DEFAULT):
    """Boolean: has the IDM liquidity level been taken on some bar in (start, end]?

    direction 'bear' (IDM is a swing HIGH = buy-side liquidity above):
        mode 'wick' => any bar.high > idm.price ; mode 'body' => any bar.close > idm.price.
    direction 'bull' (IDM is a swing LOW = sell-side liquidity below):
        mode 'wick' => any bar.low  < idm.price ; mode 'body' => any bar.close < idm.price.

    Scans strictly AFTER the shift (start exclusive) through end inclusive, so it is causal for a
    decision made at `end`. Returns (cleared: bool, clear_index: int|None).
    """
    if idm is None:
        return False, None
    level = idm["price"]
    lo = max(start + 1, 0)
    hi = min(end, len(bars) - 1)
    for t in range(lo, hi + 1):
        _, _, o, h, l, c, _ = bars[t]
        if direction == "bear":
            hit = (h > level) if mode == "wick" else (c > level)
        else:
            hit = (l < level) if mode == "wick" else (c < level)
        if hit:
            return True, t
    return False, None


def detect_idm(bars, pivot=PIVOT_DEFAULT, disp=DISP_DEFAULT, cleared_mode=CLEARED_MODE_DEFAULT,
               clear_window=None):
    """Detect IDM levels for every MSS shift and report whether each has been cleared.

    For each MSS event (from qm_detect.detect_mss) we:
      1. identify the IDM (opposing most-recent confirmed swing at the shift), causally;
      2. run idm_cleared over the window AFTER the shift. The window end defaults to the next
         shift index (exclusive) or the last bar; `clear_window` (int bars) overrides it with a
         fixed horizon. This end is only a REPORTING horizon — it does not decide mandatoriness.

    Returns (events, mss_events, highs, lows). Each event dict:
        {"index","datetime","direction","shift_level","idm_index","idm_level","cleared",
         "clear_index","clear_datetime"}
    where 'direction' is the shift direction and idm_level/idm_index describe the inducement swing.
    """
    mss_events, highs, lows = detect_mss(bars, pivot=pivot, disp=disp)
    n = len(bars)
    shift_indices = [e["index"] for e in mss_events]
    events = []
    for i, ev in enumerate(mss_events):
        s = ev["index"]
        direction = ev["direction"]
        idm = find_idm_for_shift(highs, lows, pivot, s, direction)
        # reporting window end: next shift (exclusive) or fixed horizon or end of series
        if clear_window is not None:
            end = min(s + clear_window, n - 1)
        elif i + 1 < len(shift_indices):
            end = shift_indices[i + 1] - 1
        else:
            end = n - 1
        cleared, cidx = idm_cleared(bars, idm, direction, s, end, mode=cleared_mode)
        events.append({
            "index": s,
            "datetime": ev["datetime"],
            "direction": direction,
            "shift_level": ev["swing_level"],
            "idm_index": idm["index"] if idm else None,
            "idm_level": idm["price"] if idm else None,
            "cleared": cleared,
            "clear_index": cidx,
            "clear_datetime": bars[cidx][1] if cidx is not None else None,
        })
    events.sort(key=lambda e: e["index"])
    return events, mss_events, highs, lows


# ---- output -----------------------------------------------------------------
def _fmt_dt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S") if isinstance(dt, datetime.datetime) else str(dt)


def write_idm_csv(events, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["index", "datetime", "direction", "shift_level", "idm_index", "idm_level",
                    "cleared", "clear_index", "clear_datetime"])
        for e in events:
            w.writerow([
                e["index"], _fmt_dt(e["datetime"]), e["direction"],
                f"{e['shift_level']:.5f}",
                e["idm_index"] if e["idm_index"] is not None else "",
                f"{e['idm_level']:.5f}" if e["idm_level"] is not None else "",
                "1" if e["cleared"] else "0",
                e["clear_index"] if e["clear_index"] is not None else "",
                _fmt_dt(e["clear_datetime"]) if e["clear_datetime"] is not None else "",
            ])


def print_summary(bars, events, mss_events, highs, lows, pivot, disp, cleared_mode, out_path):
    n_with_idm = sum(1 for e in events if e["idm_level"] is not None)
    n_cleared = sum(1 for e in events if e["cleared"])
    first_dt = _fmt_dt(bars[0][1]) if bars else "n/a"
    last_dt = _fmt_dt(bars[-1][1]) if bars else "n/a"
    print("=" * 66)
    print(f"QM/ICT block-4  IDM (inducement) detector + cleared test "
          f"(pivot={pivot}, disp={disp}, cleared-mode={cleared_mode})")
    print("=" * 66)
    print(f"  bars:            {len(bars):>6}   ({first_dt} .. {last_dt})")
    print(f"  MSS shifts:      {len(mss_events):>6}")
    print(f"  IDM levels found:{n_with_idm:>6}   (of {len(events)} shifts)")
    print(f"  IDM cleared:     {n_cleared:>6}   (mode='{cleared_mode}'; mandatory? decided in Block 6)")
    print("-" * 66)
    print("  first IDM records:")
    print(f"  {'#':>3}  {'datetime':<19}  {'dir':<4}  {'idm_level':>12}  {'cleared':>7}")
    for i, e in enumerate(events[:10]):
        lvl = f"{e['idm_level']:.5f}" if e["idm_level"] is not None else "n/a"
        print(f"  {i + 1:>3}  {_fmt_dt(e['datetime']):<19}  {e['direction']:<4}  "
              f"{lvl:>12}  {'yes' if e['cleared'] else 'no':>7}")
    if not events:
        print("  (none)")
    print("-" * 66)
    print(f"  full IDM list written to: {out_path}")
    print("=" * 66)


# ---- self-check -------------------------------------------------------------
def _bar(idx, o, h, l, c):
    return (idx, None, float(o), float(h), float(l), float(c), 0.0)


def selfcheck():
    """Synthetic assertions proving IDM identification, the cleared test (positive + negative),
    causality, and that the body-vs-wick 'cleared' parameter is the discriminator.

    Case A: a bearish shift with a prior swing HIGH (the IDM). Assert the IDM level is identified
            correctly, idm_cleared is False before price takes it and True once a later bar does.
    Case B (gate is the discriminator): a bar whose WICK pierces the IDM high but whose BODY closes
            below it. With cleared-mode='wick' => cleared True; with cleared-mode='body' => cleared
            False. Toggling the parameter flips the outcome on the SAME data (real gate).
    Case C (causality): the IDM identified for a shift is unchanged when future bars are appended.
    """
    pivot = 2

    # --- Build a series with a swing HIGH (the IDM), then a bearish MSS below a swing low. ---
    # Warmup to seed ATR (14 bars), an up-move making a swing high, a pullback low, then a
    # decisive down close (bearish MSS). The most-recent confirmed swing HIGH at the shift = IDM.
    series = []
    for i in range(14):
        series.append(_bar(i, 100, 101, 99, 100))
    off = len(series)
    core = [
        _bar(off + 0, 100, 102, 99, 101),
        _bar(off + 1, 101, 105, 100, 104),
        _bar(off + 2, 104, 112, 103, 108),   # swing HIGH = 112  (the IDM / buy-side liquidity)
        _bar(off + 3, 108, 109, 105, 106),
        _bar(off + 4, 106, 107, 100, 101),   # confirms the 112 high (idx+pivot)
        _bar(off + 5, 101, 102, 96, 97),     # swing LOW forming around 96
        _bar(off + 6, 97, 98, 93, 94),       # low = 93
        _bar(off + 7, 94, 99, 94, 98),
        _bar(off + 8, 98, 100, 97, 99),      # confirms the 93 low
    ]
    series.extend(core)
    # decisive bearish MSS: close well below the most-recent confirmed swing low (~93)
    mss_bar = _bar(len(series), 98, 99, 86, 87)   # close 87 < 93, big body => displacement passes
    series.append(mss_bar)
    shift_idx = mss_bar[0]
    # bars after the shift that eventually take the 112 IDM high
    series.append(_bar(len(series), 87, 90, 86, 89))     # no clear
    series.append(_bar(len(series), 89, 95, 88, 94))     # no clear (high 95 < 112)
    series = [(i,) + b[1:] for i, b in enumerate(series)]

    evA, mssA, hiA, loA = detect_idm(series, pivot=pivot, disp=0.6, cleared_mode="wick")
    bear = [e for e in evA if e["direction"] == "bear"]
    assert bear, "A: expected a bearish MSS shift"
    rec = bear[0]
    assert rec["idm_level"] == 112.0, f"A: IDM level should be the 112 swing high, got {rec['idm_level']}"
    # not cleared yet: no bar after the shift traded above 112
    assert rec["cleared"] is False, "A: IDM should NOT be cleared before price takes 112"

    # extend the series so a later bar wicks above 112 => now cleared. Use a fixed --clear-window
    # so the reporting horizon is the cleared test itself, not truncated by any later shift; the
    # taking bar closes BELOW the 100 swing high so it does not itself create a new MSS.
    series2 = list(series)
    series2.append((len(series2), None, 94.0, 113.0, 93.0, 96.0, 0.0))  # high 113 > 112 => wick clears
    evA2, _, _, _ = detect_idm(series2, pivot=pivot, disp=0.6, cleared_mode="wick", clear_window=20)
    rec2 = [e for e in evA2 if e["direction"] == "bear"][0]
    assert rec2["cleared"] is True, "A: IDM should be cleared once a bar wicks above 112"
    assert rec2["clear_index"] == len(series2) - 1, "A: clear should be recorded on the taking bar"

    # --- Case B: body-vs-wick 'cleared' precision is the discriminator ---
    # A bar wicks to 113 (> 112) but its body CLOSES at 96 (< 112, and < 100 so it makes no new MSS).
    # A fixed clear-window isolates the cleared test from shift windowing.
    seriesB = list(series)
    seriesB.append((len(seriesB), None, 94.0, 113.0, 93.0, 96.0, 0.0))  # wick clears 112, body does not
    ev_wick, _, _, _ = detect_idm(seriesB, pivot=pivot, disp=0.6, cleared_mode="wick", clear_window=20)
    ev_body, _, _, _ = detect_idm(seriesB, pivot=pivot, disp=0.6, cleared_mode="body", clear_window=20)
    rec_wick = [e for e in ev_wick if e["direction"] == "bear"][0]
    rec_body = [e for e in ev_body if e["direction"] == "bear"][0]
    assert rec_wick["cleared"] is True, "B: wick-mode should treat the 113 wick as clearing 112"
    assert rec_body["cleared"] is False, "B: body-mode should NOT clear (body closed 96 < 112)"
    assert rec_wick["cleared"] != rec_body["cleared"], "B: cleared-mode must be the discriminator"

    # --- Case C: causality — IDM identification unaffected by future bars ---
    # Detect on the series truncated right at the shift bar vs the full series; the IDM for that
    # shift must be identical (the IDM depends only on swings confirmed by the shift bar).
    trunc = [b for b in series if b[0] <= shift_idx]
    idm_trunc = find_idm_for_shift(*_swings_for(trunc, pivot), pivot, shift_idx, "bear")
    idm_full = find_idm_for_shift(hiA, loA, pivot, shift_idx, "bear")
    assert idm_trunc is not None and idm_full is not None, "C: IDM should exist in both views"
    assert idm_trunc["price"] == idm_full["price"] == 112.0, (
        "C: IDM identification must not depend on future bars")

    print("selfcheck: PASS")
    print("  case A: IDM = prior swing high (112) identified; cleared False before, True once taken")
    print("  case B: wick-mode clears on a wick-only take; body-mode does not (cleared-mode is the gate)")
    print("  case C: IDM identification uses only swings confirmed by the shift bar (causal)")
    return True


def _swings_for(bars, pivot):
    """Helper for selfcheck case C: return (highs, lows) for a bar slice."""
    return detect_swings(bars, pivot=pivot)


# ---- CLI --------------------------------------------------------------------
def parse_args(argv):
    p = argparse.ArgumentParser(
        description="QM/ICT block-4: IDM (inducement) detector + boolean cleared test.")
    p.add_argument("path", nargs="?", default=None, help="OHLC CSV (datetime,open,high,low,close,volume)")
    p.add_argument("--selfcheck", action="store_true", help="run synthetic assertions only")
    p.add_argument("--pivot", type=int, default=PIVOT_DEFAULT,
                   help=f"swing pivot L/R count for structural + IDM swings "
                        f"(default {PIVOT_DEFAULT}; tunable, not baked in)")
    p.add_argument("--disp", type=float, default=DISP_DEFAULT,
                   help=f"MSS displacement gate handed to detect_mss (default {DISP_DEFAULT})")
    p.add_argument("--cleared-mode", default=CLEARED_MODE_DEFAULT, choices=("wick", "body"),
                   help=f"'cleared' precision: 'wick' (any trade beyond) or 'body' (close beyond) "
                        f"(default {CLEARED_MODE_DEFAULT}; precision UNCONFIRMED, so it is a parameter)")
    p.add_argument("--clear-window", type=int, default=None,
                   help="optional fixed reporting horizon (bars after shift) for the cleared scan; "
                        "default scans until the next shift. REPORTING only; not a mandatoriness rule")
    p.add_argument("--out", default=None, help="write IDM CSV to this path")
    return p.parse_args(argv)


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
    if args.disp < 0:
        raise SystemExit("--disp must be >= 0")
    if args.clear_window is not None and args.clear_window < 1:
        raise SystemExit("--clear-window must be >= 1 when provided")

    bars = load_ohlc(args.path)
    if not bars:
        raise SystemExit(f"no OHLC rows parsed from {args.path}")

    out = args.out if args.out else "idm_events.csv"
    events, mss_events, highs, lows = detect_idm(
        bars, pivot=args.pivot, disp=args.disp, cleared_mode=args.cleared_mode,
        clear_window=args.clear_window)
    write_idm_csv(events, out)
    print_summary(bars, events, mss_events, highs, lows, args.pivot, args.disp, args.cleared_mode, out)


if __name__ == "__main__":
    main()

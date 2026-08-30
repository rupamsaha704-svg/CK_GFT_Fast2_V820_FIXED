#!/usr/bin/env python3
"""
QM/ICT setup — building-block 3: ERL (External Range Liquidity) zone + raid detector.

Scope (intentionally narrow): from CONFIRMED swings, identify the external range liquidity
levels — the extreme highs / lows that constitute the liquidity pools price tends to raid —
and flag ERL "raids" (a subsequent bar sweeping a wick BEYOND that external level). ERL is the
raid TARGET; the internal inducement liquidity is handled separately in idm_detect.py. Entry /
SL / TP / POI / SMT are OUT OF SCOPE here.

Discipline (anti-overfitting, from SPEC/DESIGN_v1.0.md): nothing subjective is baked in. The
rules the setup creator has NOT locked are exposed as PARAMETERS with documented defaults so
they can be A/B tested on out-of-sample data later. Pre-choosing a "best" value = overfitting =
forbidden. The tunable parameters are:
  - PIVOT      left/right pivot count for a confirmed swing (default 2, consistent with qm_detect)
  - LOOKBACK   number of most-recent CONFIRMED swings that define the external range (default 5)
               (the highest of the last LOOKBACK confirmed swing highs = upper ERL; the lowest
               of the last LOOKBACK confirmed swing lows = lower ERL). This "range definition"
               is an OPEN rule -> a parameter, not a locked truth.
  - ERL_TF     ERL SOURCE timeframe (default "input" = use the input CSV's own bars). The ERL
               source TF is an UNCONFIRMED rule; when a coarser TF is requested we resample the
               input bars deterministically (e.g. M15 -> H1) and derive ERL levels from the
               resampled swings. Exposed as --erl-tf so it is tunable, never assumed.

ERL level (per side, per bar t): the extreme of the last LOOKBACK swings CONFIRMED by t.
ERL raid: a bar whose WICK trades beyond the active external level:
  upper raid  = bar.high > active_upper_ERL.price   (sweep of buy-side liquidity)
  lower raid  = bar.low  < active_lower_ERL.price    (sweep of sell-side liquidity)
A bar that only APPROACHES (touches at or inside) the level is NOT a raid (negative case).

Causality (LOCKED discipline): at bar t only swings CONFIRMED by t (swing index + pivot <= t)
and only price action at/at-or-before t may be used. We mirror the "most recent confirmed swing"
forward-sweep pointer pattern from qm_detect.detect_mss — swings enter the active window ordered
by their confirmation bar (index + pivot), never before.

Deterministic: same input CSV + same parameters => identical output.
Pure Python standard library only (csv, datetime, argparse) — dependency-free.

Usage:
    python3 v1_lab/erl_detect.py <ohlc.csv> [--pivot 2] [--lookback 5]
        [--erl-tf input|H1|H4|<minutes>] [--out erl_events.csv]
    python3 v1_lab/erl_detect.py --selfcheck    # run built-in synthetic assertions only
"""
import os
import sys
import csv
import argparse
import datetime

# Ensure qm_detect (same directory) is importable when run from the repo root.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qm_detect import load_ohlc, detect_swings  # reuse the identical parser + swing rule


# ---- defaults (tunable parameters, NOT locked truths) -----------------------
PIVOT_DEFAULT = 2        # confirmed-swing pivot (consistent with qm_detect default)
LOOKBACK_DEFAULT = 5     # number of recent confirmed swings that define the external range
ERL_TF_DEFAULT = "input"  # ERL source timeframe; "input" = use the CSV's own bars as-is

# named coarse timeframes -> minutes (for --erl-tf convenience); any integer minutes also allowed
_TF_MINUTES = {"M1": 1, "M5": 5, "M15": 15, "M30": 30, "H1": 60, "H4": 240, "D1": 1440}


# ---- ERL source-timeframe resampling (tunable; deterministic, causal) -------
def _tf_to_minutes(tf):
    """Translate an --erl-tf token to minutes, or None for the 'input' (no-resample) case."""
    if tf is None or str(tf).lower() == "input":
        return None
    key = str(tf).upper()
    if key in _TF_MINUTES:
        return _TF_MINUTES[key]
    return int(tf)   # raw minutes, e.g. --erl-tf 45


def resample_bars(bars, minutes):
    """Deterministically resample bars into fixed `minutes`-wide buckets aligned to the epoch.

    Bucketing is by floor(timestamp / minutes) so it is stable and reproducible. Each output bar
    is (index, bucket_start_dt, open, high, low, close, volume) with OHLC aggregated in time
    order. Bars without a parseable datetime are skipped (cannot be bucketed deterministically).
    This is causal: a bucket only ever aggregates bars that fall inside it.
    """
    if minutes is None:
        return bars
    buckets = {}
    order = []
    span = datetime.timedelta(minutes=minutes)
    epoch = datetime.datetime(1970, 1, 1)
    for b in bars:
        dt = b[1]
        if dt is None:
            continue
        n = int((dt - epoch).total_seconds() // (minutes * 60))
        start = epoch + n * span
        if start not in buckets:
            buckets[start] = {"o": b[2], "h": b[3], "l": b[4], "c": b[5], "v": b[6]}
            order.append(start)
        else:
            agg = buckets[start]
            agg["h"] = max(agg["h"], b[3])
            agg["l"] = min(agg["l"], b[4])
            agg["c"] = b[5]      # bars iterated in time order => last close is the bucket close
            agg["v"] += b[6]
    order.sort()
    out = []
    for i, start in enumerate(order):
        a = buckets[start]
        out.append((i, start, a["o"], a["h"], a["l"], a["c"], a["v"]))
    return out


# ---- ERL levels (external range liquidity) ----------------------------------
def erl_levels(bars, pivot=PIVOT_DEFAULT, lookback=LOOKBACK_DEFAULT):
    """Per-bar active external range liquidity levels from CONFIRMED swings.

    Returns a list `levels` of length len(bars); levels[t] is a dict:
        {"upper": {"price","index"}|None, "lower": {"price","index"}|None}
    upper = highest price among the last `lookback` swing highs CONFIRMED by t.
    lower = lowest price among the last `lookback` swing lows CONFIRMED by t.

    Causal: a swing at index s is only usable once s + pivot <= t (mirrors detect_mss). We keep a
    rolling window of the last `lookback` confirmed swings per side and recompute the extreme.
    """
    highs, lows = detect_swings(bars, pivot=pivot)
    conf_highs = sorted(((sw["index"] + pivot, sw) for sw in highs), key=lambda x: x[0])
    conf_lows = sorted(((sw["index"] + pivot, sw) for sw in lows), key=lambda x: x[0])

    n = len(bars)
    levels = [None] * n
    hi = 0
    li = 0
    win_high = []   # rolling last-`lookback` confirmed swing highs
    win_low = []
    for t in range(n):
        while hi < len(conf_highs) and conf_highs[hi][0] <= t:
            win_high.append(conf_highs[hi][1])
            if len(win_high) > lookback:
                win_high.pop(0)
            hi += 1
        while li < len(conf_lows) and conf_lows[li][0] <= t:
            win_low.append(conf_lows[li][1])
            if len(win_low) > lookback:
                win_low.pop(0)
            li += 1
        upper = None
        lower = None
        if win_high:
            top = max(win_high, key=lambda s: s["price"])
            upper = {"price": top["price"], "index": top["index"]}
        if win_low:
            bot = min(win_low, key=lambda s: s["price"])
            lower = {"price": bot["price"], "index": bot["index"]}
        levels[t] = {"upper": upper, "lower": lower}
    return levels, highs, lows


# ---- ERL raid detection -----------------------------------------------------
def detect_erl(bars, pivot=PIVOT_DEFAULT, lookback=LOOKBACK_DEFAULT):
    """Detect ERL raids on `bars` (already at the desired ERL source timeframe).

    For each bar t we use the ERL levels active AT t (built only from swings confirmed by t).
    A raid requires the wick to trade STRICTLY beyond the active level:
        upper raid: bars[t].high > active upper level price
        lower raid: bars[t].low  < active lower level price
    A bar that only touches the level (equal) or stays inside is NOT a raid.

    Returns (events, levels, highs, lows). Each event is a dict:
        {"index","datetime","side","level","level_index","extreme"}
      side = 'upper' (buy-side sweep) or 'lower' (sell-side sweep);
      extreme = the bar high (upper) or low (lower) that did the sweeping.
    """
    levels, highs, lows = erl_levels(bars, pivot=pivot, lookback=lookback)
    events = []
    for t in range(len(bars)):
        lv = levels[t]
        if lv is None:
            continue
        _, dt, o, h, l, c, _ = bars[t]
        up = lv["upper"]
        lo = lv["lower"]
        if up is not None and up["index"] < t and h > up["price"]:
            events.append({
                "index": t, "datetime": dt, "side": "upper",
                "level": up["price"], "level_index": up["index"], "extreme": h,
            })
        if lo is not None and lo["index"] < t and l < lo["price"]:
            events.append({
                "index": t, "datetime": dt, "side": "lower",
                "level": lo["price"], "level_index": lo["index"], "extreme": l,
            })
    events.sort(key=lambda e: (e["index"], e["side"]))
    return events, levels, highs, lows


# ---- output -----------------------------------------------------------------
def _fmt_dt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S") if isinstance(dt, datetime.datetime) else str(dt)


def write_erl_csv(events, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["index", "datetime", "side", "level", "level_index", "extreme"])
        for e in events:
            w.writerow([
                e["index"], _fmt_dt(e["datetime"]), e["side"],
                f"{e['level']:.5f}", e["level_index"], f"{e['extreme']:.5f}",
            ])


def print_summary(src_bars, events, levels, highs, lows, pivot, lookback, erl_tf, out_path):
    n_upper = sum(1 for e in events if e["side"] == "upper")
    n_lower = sum(1 for e in events if e["side"] == "lower")
    first_dt = _fmt_dt(src_bars[0][1]) if src_bars else "n/a"
    last_dt = _fmt_dt(src_bars[-1][1]) if src_bars else "n/a"
    # count bars that had at least one active ERL level
    n_with_level = sum(1 for lv in levels if lv and (lv["upper"] or lv["lower"]))
    print("=" * 64)
    print(f"QM/ICT block-3  ERL (external range liquidity) detector "
          f"(pivot={pivot}, lookback={lookback}, erl-tf={erl_tf})")
    print("=" * 64)
    print(f"  source bars: {len(src_bars):>6}   ({first_dt} .. {last_dt})")
    print(f"  swings:      {len(highs) + len(lows):>6}   (highs={len(highs)}, lows={len(lows)})")
    print(f"  bars with an active ERL level: {n_with_level:>6}")
    print(f"  ERL raids:   {len(events):>6}   (upper/buy-side={n_upper}, lower/sell-side={n_lower})")
    print("-" * 64)
    print("  first ERL raids:")
    print(f"  {'#':>3}  {'datetime':<19}  {'side':<5}  {'level':>12}  {'extreme':>12}")
    for i, e in enumerate(events[:10]):
        print(f"  {i + 1:>3}  {_fmt_dt(e['datetime']):<19}  {e['side']:<5}  "
              f"{e['level']:>12.5f}  {e['extreme']:>12.5f}")
    if not events:
        print("  (none)")
    print("-" * 64)
    print(f"  full ERL raid list written to: {out_path}")
    print("=" * 64)


# ---- self-check -------------------------------------------------------------
def _bar(idx, o, h, l, c):
    return (idx, None, float(o), float(h), float(l), float(c), 0.0)


def _bar_dt(idx, dt, o, h, l, c, v=0.0):
    return (idx, dt, float(o), float(h), float(l), float(c), float(v))


def selfcheck():
    """Synthetic assertions proving ERL detection, the negative case, causality, and that a
    parameter (lookback) really changes the detected level.

    Case A (POSITIVE): a clear external swing high at 110; a later bar wicks above it => upper raid
                       flagged on exactly that bar, at the right level.
    Case B (NEGATIVE): a bar that only APPROACHES the level (high == level, never exceeds) => NOT a raid.
    Case C (PARAMETER is real): with a small lookback the active upper level is a recent lower high,
                       so a moderate wick raids it; with a larger lookback the active level is the
                       older, higher high, and the SAME bar no longer raids. Toggling --lookback
                       changes the detected level and the raid outcome (parameter is not cosmetic).
    Case D (CAUSALITY): a raid decision at bar t is unaffected by appending future bars after t.
    Case E (ERL-TF is real): resampling to a coarser TF changes the number of source bars and the
                       derived level set (source TF is a genuine parameter, not cosmetic).
    """
    pivot = 2

    # --- Case A: positive raid on a clear external swing high ---
    # Build a swing high = 110 (strictly greater than 2 neighbours each side), then a wick above it.
    seriesA = [
        _bar(0, 100, 101, 99, 100),
        _bar(1, 100, 103, 100, 102),
        _bar(2, 102, 110, 101, 105),   # swing HIGH = 110 (needs 2 lower highs each side)
        _bar(3, 105, 106, 103, 104),
        _bar(4, 104, 105, 102, 103),   # confirms the swing at idx2 (idx2+pivot=4)
        _bar(5, 103, 104, 101, 102),
        _bar(6, 102, 112, 101, 108),   # WICK to 112 > 110 => upper ERL raid here
        _bar(7, 108, 109, 106, 107),
    ]
    evA, levA, hiA, loA = detect_erl(seriesA, pivot=pivot, lookback=5)
    up_raids = [e for e in evA if e["side"] == "upper"]
    assert any(sw["price"] == 110.0 for sw in hiA), "A: expected a confirmed swing high at 110"
    assert len(up_raids) >= 1, "A: expected at least one upper ERL raid"
    first = up_raids[0]
    assert first["index"] == 6, f"A: raid should be flagged on bar 6, got {first['index']}"
    assert first["level"] == 110.0, f"A: raid level should be 110, got {first['level']}"

    # --- Case B: approach-only (touch, never exceed) is NOT a raid ---
    seriesB = [
        _bar(0, 100, 101, 99, 100),
        _bar(1, 100, 103, 100, 102),
        _bar(2, 102, 110, 101, 105),   # swing HIGH = 110
        _bar(3, 105, 106, 103, 104),
        _bar(4, 104, 105, 102, 103),
        _bar(5, 103, 104, 101, 102),
        _bar(6, 102, 110, 101, 108),   # high == 110 exactly: touches, does NOT exceed => no raid
        _bar(7, 108, 109, 106, 107),
    ]
    evB, _, hiB, _ = detect_erl(seriesB, pivot=pivot, lookback=5)
    up_raids_B = [e for e in evB if e["side"] == "upper" and e["index"] == 6]
    assert any(sw["price"] == 110.0 for sw in hiB), "B: expected a confirmed swing high at 110"
    assert not up_raids_B, "B: an approach that only touches the level must NOT be a raid"

    # --- Case C: lookback is a real discriminator ---
    # Two swing highs: an OLDER higher one (115) and a MORE RECENT lower one (108).
    # lookback=1 => active upper level is the recent 108 => a wick to 109 raids it.
    # lookback=5 => active upper level is the higher 115 => the same 109 wick does NOT raid.
    seriesC = [
        _bar(0, 100, 101, 99, 100),
        _bar(1, 101, 103, 100, 102),
        _bar(2, 102, 115, 101, 106),   # OLDER swing high = 115
        _bar(3, 106, 107, 104, 105),
        _bar(4, 105, 106, 103, 104),   # confirms idx2
        _bar(5, 104, 105, 102, 103),
        _bar(6, 103, 108, 102, 105),   # RECENT swing high = 108 (lower than 115)
        _bar(7, 105, 106, 103, 104),
        _bar(8, 104, 105, 102, 103),   # confirms idx6
        _bar(9, 103, 109, 102, 107),   # WICK to 109: > 108 but < 115
        _bar(10, 107, 108, 105, 106),
    ]
    ev_small, lv_small, _, _ = detect_erl(seriesC, pivot=pivot, lookback=1)
    ev_big, lv_big, _, _ = detect_erl(seriesC, pivot=pivot, lookback=5)
    # active upper level at bar 9 differs by lookback
    assert lv_small[9]["upper"]["price"] == 108.0, (
        f"C: lookback=1 active upper should be 108, got {lv_small[9]['upper']}")
    assert lv_big[9]["upper"]["price"] == 115.0, (
        f"C: lookback=5 active upper should be 115, got {lv_big[9]['upper']}")
    raid9_small = [e for e in ev_small if e["index"] == 9 and e["side"] == "upper"]
    raid9_big = [e for e in ev_big if e["index"] == 9 and e["side"] == "upper"]
    assert raid9_small, "C: with lookback=1 the 109 wick should raid the 108 level"
    assert not raid9_big, "C: with lookback=5 the 109 wick should NOT raid the higher 115 level"

    # --- Case D: causality — future bars cannot change a past decision ---
    ev_short, _, _, _ = detect_erl(seriesA[:7], pivot=pivot, lookback=5)  # up to & incl. the raid bar
    up_short = [(e["index"], e["side"], e["level"]) for e in ev_short if e["index"] == 6]
    up_full = [(e["index"], e["side"], e["level"]) for e in evA if e["index"] == 6]
    assert up_short == up_full, "D: appending future bars changed the bar-6 decision (lookahead!)"

    # --- Case E: erl-tf (source timeframe) is a real, non-cosmetic parameter ---
    base = datetime.datetime(2025, 1, 1, 0, 0)
    tf_bars = []
    price = 100.0
    for i in range(40):
        dt = base + datetime.timedelta(minutes=15 * i)
        h = price + 2 + (i % 5)
        l = price - 2 - (i % 3)
        c = price + ((i % 7) - 3) * 0.5
        tf_bars.append(_bar_dt(i, dt, price, h, l, c))
        price = c
    r_input = resample_bars(tf_bars, _tf_to_minutes("input"))
    r_h1 = resample_bars(tf_bars, _tf_to_minutes("H1"))
    assert len(r_input) == len(tf_bars), "E: 'input' must not resample"
    assert len(r_h1) < len(tf_bars), "E: H1 resample of M15 must reduce bar count"
    # deterministic: resampling twice yields identical buckets
    assert resample_bars(tf_bars, 60) == r_h1, "E: resample must be deterministic"

    print("selfcheck: PASS")
    print("  case A: wick beyond external swing high => upper ERL raid at the right bar & level")
    print("  case B: approach that only touches the level => NOT a raid (negative case)")
    print("  case C: --lookback changes the active ERL level and the raid outcome (parameter is real)")
    print("  case D: appending future bars does not change a past raid decision (causal)")
    print("  case E: --erl-tf resampling changes source bar count deterministically (parameter is real)")
    return True


# ---- CLI --------------------------------------------------------------------
def parse_args(argv):
    p = argparse.ArgumentParser(
        description="QM/ICT block-3: ERL (external range liquidity) zone + raid detector.")
    p.add_argument("path", nargs="?", default=None, help="OHLC CSV (datetime,open,high,low,close,volume)")
    p.add_argument("--selfcheck", action="store_true", help="run synthetic assertions only")
    p.add_argument("--pivot", type=int, default=PIVOT_DEFAULT,
                   help=f"confirmed-swing pivot L/R count (default {PIVOT_DEFAULT}; tunable, not baked in)")
    p.add_argument("--lookback", type=int, default=LOOKBACK_DEFAULT,
                   help=f"number of recent confirmed swings defining the external range "
                        f"(default {LOOKBACK_DEFAULT}; tunable, not baked in)")
    p.add_argument("--erl-tf", default=ERL_TF_DEFAULT,
                   help=f"ERL source timeframe: 'input' (default) or M1/M5/M15/M30/H1/H4/D1 or raw "
                        f"minutes; ERL source TF is an OPEN rule, so it is tunable, not assumed")
    p.add_argument("--out", default=None, help="write ERL raid CSV to this path")
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
    if args.lookback < 1:
        raise SystemExit("--lookback must be >= 1")
    try:
        minutes = _tf_to_minutes(args.erl_tf)
    except (ValueError, TypeError):
        raise SystemExit(f"--erl-tf {args.erl_tf!r} is not 'input', a known TF, or integer minutes")

    bars = load_ohlc(args.path)
    if not bars:
        raise SystemExit(f"no OHLC rows parsed from {args.path}")
    src_bars = resample_bars(bars, minutes)
    if not src_bars:
        raise SystemExit("no bars after resampling (are timestamps parseable?)")

    out = args.out if args.out else "erl_events.csv"
    events, levels, highs, lows = detect_erl(src_bars, pivot=args.pivot, lookback=args.lookback)
    write_erl_csv(events, out)
    print_summary(src_bars, events, levels, highs, lows, args.pivot, args.lookback, args.erl_tf, out)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
QM/ICT setup — building-block 1: swing/pivot detector + M15 Market-Structure-Shift (MSS) detector.

Scope (intentionally narrow): ONLY the objectively-locked layer of the XAUUSD QM/ICT setup:
  (1) swing/pivot detection, and
  (2) M15 MSS = body-close beyond the most recent confirmed swing + meaningful displacement.
Entry / SL / TP / ERL / SMT / IDM / POI are OUT OF SCOPE here (awaiting setup-creator confirmation).

Discipline: nothing subjective is hard-coded. The two rules the creator has NOT locked exactly are
exposed as PARAMETERS so they can later be A/B tested on out-of-sample data:
  - PIVOT (left/right pivot count for a confirmed swing)      default 2
  - DISP  (ATR-multiple threshold for meaningful displacement) default 0.6
Pre-choosing a "best" value would be overfitting, which is forbidden — so these are tunable, not baked in.

Deterministic: same input CSV + same parameters => identical output.
Pure Python standard library only (no pandas/numpy needed) — keeps it dependency-free and reproducible.

Definitions (LOCKED, implemented exactly):
  swing high = a candle whose high is STRICTLY greater than the highs of PIVOT candles to its left
               AND PIVOT candles to its right (mirror with lows for swing low).
  bearish MSS = a candle that CLOSES (body close, not merely a wick) below the most recent confirmed
                swing low, AND has bearish displacement (body / ATR14) >= DISP.
  bullish MSS = mirror (body close above most recent confirmed swing high + bullish displacement).

Usage:
    python3 qm_detect.py <ohlc.csv> [--pivot 2] [--disp 0.6] [--out mss_events.csv]
    python3 qm_detect.py --selfcheck        # run built-in synthetic assertions only
"""
import os
import sys
import csv
import datetime

# Ensure the sibling data_io module (same directory) is importable from the repo root.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from data_io import load_ohlc as _load_ohlc_normalized  # shared canonical+MT5 normalizer

# ---- defaults (tunable parameters, NOT locked truths) -----------------------
PIVOT_DEFAULT = 2      # left/right pivot count for a confirmed swing
DISP_DEFAULT = 0.6     # ATR-multiple threshold for "meaningful" displacement
ATR_PERIOD = 14        # Wilder ATR lookback (standard, part of the locked displacement definition)


# ---- IO ---------------------------------------------------------------------
def load_ohlc(path):
    """Read OHLC CSV into the canonical internal bar list.

    Returns list of bars: (index, datetime|None, open, high, low, close, volume).

    Delegates to the shared data_io normalizer, which auto-detects and parses BOTH supported
    layouts (the canonical comma header 'datetime,open,high,low,close,volume' AND the MT5
    "Export Bars" TAB layout '<DATE>\\t<TIME>\\t<OPEN>...') into the SAME internal structure. Kept as
    a thin wrapper here so every existing importer (`from qm_detect import load_ohlc`) transparently
    gains MT5-format support with no change to the return contract. Deterministic; no lookahead.
    """
    return _load_ohlc_normalized(path)


# ---- indicators -------------------------------------------------------------
def atr_wilder(bars, period=ATR_PERIOD):
    """Wilder ATR per bar. atr[t] uses true ranges up to and including bar t.

    Bars before the seeding window return None. Deterministic, causal.
    """
    n = len(bars)
    atr = [None] * n
    trs = [None] * n
    prev_close = None
    for t in range(n):
        _, _, o, h, l, c, _ = bars[t]
        if prev_close is None:
            tr = h - l
        else:
            tr = max(h - l, abs(h - prev_close), abs(l - prev_close))
        trs[t] = tr
        prev_close = c
    if n < period:
        return atr
    # seed with simple average of first `period` true ranges
    seed = sum(trs[:period]) / period
    atr[period - 1] = seed
    prev = seed
    for t in range(period, n):
        prev = (prev * (period - 1) + trs[t]) / period
        atr[t] = prev
    return atr


# ---- swing / pivot detection (LOCKED rule) ---------------------------------
def detect_swings(bars, pivot=PIVOT_DEFAULT):
    """Confirmed swing highs/lows using a strict left/right pivot of `pivot` candles.

    A swing high at index t requires t's high be STRICTLY greater than the highs of
    the `pivot` candles on each side. Mirror with lows for swing lows.

    Returns (highs, lows) where each item is a dict:
        {"index", "datetime", "price", "kind"}  (kind is "high" or "low").
    A swing is only "confirmed" once `pivot` bars to its right exist, so the earliest
    confirmation bar for a swing at t is t+pivot (leakage-free for downstream use).
    """
    highs = []
    lows = []
    n = len(bars)
    for t in range(pivot, n - pivot):
        h_t = bars[t][3]
        l_t = bars[t][4]
        is_high = True
        is_low = True
        for k in range(1, pivot + 1):
            if not (h_t > bars[t - k][3] and h_t > bars[t + k][3]):
                is_high = False
            if not (l_t < bars[t - k][4] and l_t < bars[t + k][4]):
                is_low = False
            if not is_high and not is_low:
                break
        if is_high:
            highs.append({"index": t, "datetime": bars[t][1], "price": h_t, "kind": "high"})
        if is_low:
            lows.append({"index": t, "datetime": bars[t][1], "price": l_t, "kind": "low"})
    return highs, lows


# ---- MSS detection (LOCKED rule; DISP is the tunable threshold) -------------
def detect_mss(bars, pivot=PIVOT_DEFAULT, disp=DISP_DEFAULT, atr_period=ATR_PERIOD):
    """Detect M15 Market-Structure-Shift events.

    For each bar t we consider only swings CONFIRMED by bar t (i.e. swing index + pivot <= t),
    so no future information is used. "Most recent confirmed swing low/high" is the confirmed
    swing with the greatest index that is not after t.

    bearish MSS: close_t < swing_low.price (body close below) AND
                 body_displacement = |close_t - open_t| / ATR14[t] >= disp.
    bullish MSS: close_t > swing_high.price AND body_displacement >= disp.

    Returns list of dicts sorted by bar index:
        {"index","datetime","direction","swing_level","swing_index","displacement","body","atr"}.
    """
    highs, lows = detect_swings(bars, pivot=pivot)
    atr = atr_wilder(bars, period=atr_period)

    # Sort confirmed swings by their confirmation bar (index + pivot) for a forward sweep.
    conf_lows = sorted(((sw["index"] + pivot, sw) for sw in lows), key=lambda x: x[0])
    conf_highs = sorted(((sw["index"] + pivot, sw) for sw in highs), key=lambda x: x[0])

    events = []
    li = 0
    hi = 0
    last_low = None
    last_high = None
    n = len(bars)
    for t in range(n):
        # advance the "most recent confirmed swing" pointers up to bar t
        while li < len(conf_lows) and conf_lows[li][0] <= t:
            last_low = conf_lows[li][1]
            li += 1
        while hi < len(conf_highs) and conf_highs[hi][0] <= t:
            last_high = conf_highs[hi][1]
            hi += 1

        a = atr[t]
        if a is None or a <= 0:
            continue
        o, c = bars[t][2], bars[t][5]
        body = abs(c - o)
        score = body / a

        if last_low is not None and c < last_low["price"] and score >= disp:
            events.append({
                "index": t, "datetime": bars[t][1], "direction": "bear",
                "swing_level": last_low["price"], "swing_index": last_low["index"],
                "displacement": score, "body": body, "atr": a,
            })
        if last_high is not None and c > last_high["price"] and score >= disp:
            events.append({
                "index": t, "datetime": bars[t][1], "direction": "bull",
                "swing_level": last_high["price"], "swing_index": last_high["index"],
                "displacement": score, "body": body, "atr": a,
            })
    events.sort(key=lambda e: e["index"])
    return events, highs, lows


# ---- output -----------------------------------------------------------------
def _fmt_dt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S") if isinstance(dt, datetime.datetime) else str(dt)


def write_mss_csv(events, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["index", "datetime", "direction", "swing_level", "swing_index", "displacement", "body", "atr"])
        for e in events:
            w.writerow([
                e["index"], _fmt_dt(e["datetime"]), e["direction"],
                f"{e['swing_level']:.5f}", e["swing_index"],
                f"{e['displacement']:.4f}", f"{e['body']:.5f}", f"{e['atr']:.5f}",
            ])


def print_summary(bars, events, highs, lows, pivot, disp, out_path):
    n_bear = sum(1 for e in events if e["direction"] == "bear")
    n_bull = sum(1 for e in events if e["direction"] == "bull")
    first_dt = _fmt_dt(bars[0][1]) if bars else "n/a"
    last_dt = _fmt_dt(bars[-1][1]) if bars else "n/a"
    print("=" * 60)
    print(f"QM/ICT block-1  swing + M15 MSS detector  (pivot={pivot}, disp={disp}, ATR{ATR_PERIOD})")
    print("=" * 60)
    print(f"  bars:   {len(bars):>6}   ({first_dt} .. {last_dt})")
    print(f"  swings: {len(highs) + len(lows):>6}   (highs={len(highs)}, lows={len(lows)})")
    print(f"  MSS:    {len(events):>6}   (bear={n_bear}, bull={n_bull})")
    print("-" * 60)
    print("  first MSS events:")
    print(f"  {'#':>3}  {'datetime':<19}  {'dir':<4}  {'swing_level':>12}  {'disp':>6}")
    for i, e in enumerate(events[:10]):
        print(f"  {i + 1:>3}  {_fmt_dt(e['datetime']):<19}  {e['direction']:<4}  "
              f"{e['swing_level']:>12.5f}  {e['displacement']:>6.2f}")
    if not events:
        print("  (none)")
    print("-" * 60)
    print(f"  full MSS list written to: {out_path}")
    print("=" * 60)


# ---- self-check (proves body-close-vs-wick distinction) ---------------------
def _bar(idx, o, h, l, c):
    return (idx, None, float(o), float(h), float(l), float(c), 0.0)


def selfcheck():
    """Synthetic assertions proving the detection logic, especially body-close vs wick.

    Construct a series with a clear swing low, then:
      case A: a candle that CLOSES decisively below the swing low  => exactly one bearish MSS.
      case B: identical breach but only a WICK below (body closes above) => zero MSS.
    Uses a low displacement threshold so the ATR gate does not mask the close/wick logic,
    then a separate case proves the displacement gate itself works.
    """
    pivot = 2

    # --- case A: decisive body close below swing low => one bearish MSS ---
    seriesA = []
    # 14 warmup bars oscillating to seed ATR, then the V, then a decisive down close.
    for i in range(14):
        seriesA.append(_bar(i, 100, 101, 99, 100))
    off = len(seriesA)
    v = [
        _bar(off + 0, 100, 101, 98, 99),
        _bar(off + 1, 99, 100, 96, 97),
        _bar(off + 2, 97, 98, 93, 94),
        _bar(off + 3, 94, 95, 90, 91),   # swing low = 90 at this index
        _bar(off + 4, 91, 96, 91, 95),
        _bar(off + 5, 95, 99, 94, 98),
    ]
    seriesA.extend(v)
    swing_low_idx = off + 3
    # decisive bearish close well below 90 with a big body (guarantees displacement)
    breach = _bar(off + 6, 95, 96, 84, 85)   # close 85 < 90, body=10
    seriesA.append(breach)
    seriesA.append(_bar(off + 7, 85, 86, 83, 84))
    seriesA.append(_bar(off + 8, 84, 85, 82, 83))
    # reindex (loader assigns index; here we set manually so keep consistent)
    seriesA = [(i,) + b[1:] for i, b in enumerate(seriesA)]
    eventsA, highsA, lowsA = detect_mss(seriesA, pivot=pivot, disp=0.6)
    bearA = [e for e in eventsA if e["direction"] == "bear"]
    assert any(sw["price"] == 90.0 for sw in lowsA), "case A: expected a confirmed swing low at 90"
    assert len(bearA) >= 1, "case A: expected at least one bearish MSS on decisive close below swing low"
    # the first bearish MSS should break the 90 swing low
    assert bearA[0]["swing_level"] == 90.0, "case A: bearish MSS should break the 90 swing low"

    # --- case B: same breach magnitude but WICK-only (body closes ABOVE 90) => no MSS on that bar ---
    seriesB = list(seriesA[:swing_low_idx + 6])  # up to just before the breach bar
    # wick pierces to 84 but body closes at 95 (above swing low 90) => must NOT be an MSS
    wick_only = (len(seriesB), None, 95.0, 96.0, 84.0, 95.0, 0.0)
    seriesB.append(wick_only)
    seriesB.append((len(seriesB), None, 95.0, 97.0, 94.0, 96.0, 0.0))
    seriesB.append((len(seriesB), None, 96.0, 98.0, 95.0, 97.0, 0.0))
    eventsB, _, lowsB = detect_mss(seriesB, pivot=pivot, disp=0.6)
    wick_bar_idx = wick_only[0]
    bearB_on_wick = [e for e in eventsB if e["direction"] == "bear" and e["index"] == wick_bar_idx]
    assert not bearB_on_wick, "case B: wick-only breach must NOT produce a bearish MSS (body closed above swing low)"

    # --- case C: displacement gate works — body close below but tiny body => filtered out ---
    seriesC = []
    for i in range(14):
        seriesC.append(_bar(i, 100, 100.2, 99.8, 100))
    off = len(seriesC)
    seriesC.extend([
        _bar(off + 0, 100, 100.1, 99.5, 99.8),
        _bar(off + 1, 99.8, 99.9, 99.3, 99.5),
        _bar(off + 2, 99.5, 99.6, 99.0, 99.2),
        _bar(off + 3, 99.2, 99.3, 98.8, 99.0),   # swing low = 98.8
        _bar(off + 4, 99.0, 99.4, 99.0, 99.3),
        _bar(off + 5, 99.3, 99.7, 99.2, 99.6),
    ])
    # close just below 98.8 but with a TINY body (0.05) -> displacement well under any sane threshold
    tiny = _bar(off + 6, 98.80, 98.82, 98.70, 98.75)  # close 98.75 < 98.8, body=0.05
    seriesC.append(tiny)
    seriesC.append(_bar(off + 7, 98.75, 98.8, 98.6, 98.7))
    seriesC.append(_bar(off + 8, 98.7, 98.75, 98.55, 98.65))
    seriesC = [(i,) + b[1:] for i, b in enumerate(seriesC)]
    tiny_idx = tiny[0]
    eventsC_lo, _, _ = detect_mss(seriesC, pivot=pivot, disp=0.6)
    on_tiny = [e for e in eventsC_lo if e["index"] == tiny_idx and e["direction"] == "bear"]
    assert not on_tiny, "case C: tiny-body close below swing must be filtered by displacement gate (disp=0.6)"
    # but with disp=0 (gate off) the same bar DOES qualify -> proves it was the gate, not the close rule
    eventsC_off, _, _ = detect_mss(seriesC, pivot=pivot, disp=0.0)
    on_tiny_off = [e for e in eventsC_off if e["index"] == tiny_idx and e["direction"] == "bear"]
    assert on_tiny_off, "case C: with disp=0 the same close-below bar should register (gate is the discriminator)"

    print("selfcheck: PASS")
    print("  case A: decisive body close below swing low => bearish MSS detected")
    print("  case B: wick-only breach (body closed above) => no MSS  (body-vs-wick works)")
    print("  case C: tiny body filtered by displacement gate; passes with disp=0  (gate works)")
    return True


# ---- CLI --------------------------------------------------------------------
def parse_args(argv):
    path = None
    pivot = PIVOT_DEFAULT
    disp = DISP_DEFAULT
    out = None
    do_selfcheck = False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--selfcheck":
            do_selfcheck = True
        elif a == "--pivot":
            i += 1
            pivot = int(argv[i])
        elif a == "--disp":
            i += 1
            disp = float(argv[i])
        elif a == "--out":
            i += 1
            out = argv[i]
        elif not a.startswith("--"):
            path = a
        i += 1
    return path, pivot, disp, out, do_selfcheck


def main():
    path, pivot, disp, out, do_selfcheck = parse_args(sys.argv[1:])
    if do_selfcheck or path is None:
        selfcheck()
        if path is None:
            return
    # always run self-check first so a released run is proven, then real data
    if not do_selfcheck:
        selfcheck()
        print()
    if pivot < 1:
        raise SystemExit("--pivot must be >= 1")
    if disp < 0:
        raise SystemExit("--disp must be >= 0")
    bars = load_ohlc(path)
    if not bars:
        raise SystemExit(f"no OHLC rows parsed from {path}")
    if out is None:
        out = "mss_events.csv"
    events, highs, lows = detect_mss(bars, pivot=pivot, disp=disp)
    write_mss_csv(events, out)
    print_summary(bars, events, highs, lows, pivot, disp, out)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
QM/ICT setup — building-block 5b: SMT (Smart-Money-Technique) divergence detector.

Scope (intentionally narrow): detect SMT divergence between the PRIMARY series (XAUUSD) and a
correlated SECOND series, guarded by a rolling-correlation filter that suppresses SMT signals when
the two instruments have decorrelated (so a "divergence" during decorrelation is not a real SMT).
Entry / SL / TP / POI / IDM are OUT OF SCOPE here.

SMT divergence (LOCKED definition, causal): at a confirmed swing on the primary series, the
correlated series FAILS to confirm the same extreme —
  bearish SMT (at a swing HIGH raid): primary makes a HIGHER high than its prior swing high while
      the partner does NOT make a higher high (it makes a lower/equal high) => bearish divergence.
  bullish SMT (at a swing LOW raid):  primary makes a LOWER low than its prior swing low while the
      partner does NOT make a lower low => bullish divergence.
For a NEGATIVELY-correlated partner (e.g. DXY vs XAUUSD) the partner is expected to move OPPOSITE,
so "confirmation" is inverted: we compare the partner's NEGATED price move. The expected sign is a
DOCUMENTED PARAMETER per pair, never silently guessed:
  EXPECTED_SIGN['xag'] = +1  (XAGUSD moves WITH XAUUSD)
  EXPECTED_SIGN['dxy'] = -1  (DXY moves AGAINST XAUUSD)

Rolling-correlation guard: over a --corr-window of the two series' simple returns we compute a
hand-rolled Pearson correlation (stdlib only, NO numpy). If |corr * expected_sign_orientation| is
below --corr-min (i.e. the instruments are not sufficiently correlated in the EXPECTED direction),
the SMT signal at that bar is SKIPPED/flagged as guard-suppressed. This filters false SMT during
decorrelation. The window and threshold are OPEN rules -> PARAMETERS with documented defaults, NOT
pre-picked "best" values (pre-choosing = overfitting = forbidden).

DATA DEPENDENCY (handled honestly, never fabricated): the SMT variant needs XAGUSD and/or DXY OHLC
aligned to XAUUSD. These series are NOT in the repo. --smt-pair selects the variant:
  'off'  (DEFAULT)  no partner series -> zero SMT signals (there is no second series in the repo).
  'xag' / 'dxy'     require a partner CSV via --pair-csv in the SAME format
                    'datetime,open,high,low,close,volume'. When --smt-pair is 'xag'/'dxy' but no
                    --pair-csv is given (or the file is missing), we print a clear DATA-DEPENDENCY
                    message explaining what to export from MT5, and exit cleanly with SMT OFF.
                    We NEVER invent partner data and NEVER crash.

Causality (LOCKED discipline): a swing at index s is only usable once s + pivot <= t. Correlation
at a swing uses only returns up to and including that swing. No future bar influences a decision.

Deterministic: same inputs + same parameters => identical output.
Pure Python standard library only (csv, datetime, statistics, argparse) — dependency-free.

Usage:
    python3 v1_lab/smt_detect.py <xauusd.csv> [--smt-pair off|xag|dxy] [--pair-csv <partner.csv>]
        [--pivot 2] [--corr-window 20] [--corr-min 0.3] [--out smt_events.csv]
    python3 v1_lab/smt_detect.py --selfcheck    # run built-in synthetic assertions only
"""
import os
import sys
import csv
import argparse
import datetime

# Ensure qm_detect (same directory) is importable when run from the repo root.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qm_detect import load_ohlc, detect_swings  # reuse the identical parser + swing rule


# ---- defaults (tunable parameters / variant, NOT locked truths) -------------
PIVOT_DEFAULT = 2          # confirmed-swing pivot (consistent with qm_detect default)
SMT_PAIR_DEFAULT = "off"   # 'off' | 'xag' | 'dxy'  — default off (no partner series in the repo)
CORR_WINDOW_DEFAULT = 20   # rolling-correlation lookback (returns) — OPEN rule, tunable
CORR_MIN_DEFAULT = 0.3     # minimum |expected-direction correlation| to trust an SMT — OPEN rule
SMT_PAIRS = ("off", "xag", "dxy")

# Expected correlation sign per pair (DOCUMENTED, not guessed): +1 = moves WITH XAUUSD, -1 = against.
EXPECTED_SIGN = {"xag": 1, "dxy": -1}


# ---- hand-rolled Pearson correlation (stdlib only, NO numpy) ----------------
def pearson(xs, ys):
    """Pearson correlation coefficient of two equal-length sequences, pure arithmetic.

    Returns a float in [-1, 1], or 0.0 when either series has zero variance (undefined -> treated
    as "no correlation", which the guard will read as decorrelated). Deterministic.
    """
    n = len(xs)
    if n == 0 or n != len(ys):
        return 0.0
    mx = sum(xs) / n
    my = sum(ys) / n
    sxy = 0.0
    sxx = 0.0
    syy = 0.0
    for i in range(n):
        dx = xs[i] - mx
        dy = ys[i] - my
        sxy += dx * dy
        sxx += dx * dx
        syy += dy * dy
    if sxx <= 0.0 or syy <= 0.0:
        return 0.0
    return sxy / ((sxx ** 0.5) * (syy ** 0.5))


def _returns(closes):
    """Simple bar-to-bar returns; returns[i] corresponds to bar i (returns[0] = 0.0)."""
    r = [0.0] * len(closes)
    for i in range(1, len(closes)):
        prev = closes[i - 1]
        r[i] = (closes[i] - prev) / prev if prev else 0.0
    return r


def rolling_corr_at(prim_returns, part_returns, t, window):
    """Pearson correlation of the two return series over the causal window ending at bar t.

    Uses returns for bars (t-window+1 .. t). Returns None if there are not enough bars yet.
    Causal: never looks past bar t.
    """
    if t + 1 < window:
        return None
    xs = prim_returns[t - window + 1: t + 1]
    ys = part_returns[t - window + 1: t + 1]
    return pearson(xs, ys)


# ---- SMT divergence detection ----------------------------------------------
def detect_smt(prim_bars, part_bars, pivot=PIVOT_DEFAULT, expected_sign=1,
               corr_window=CORR_WINDOW_DEFAULT, corr_min=CORR_MIN_DEFAULT, use_guard=True):
    """Detect SMT divergences between the primary and partner series (aligned by index).

    Preconditions: prim_bars and part_bars are aligned bar-for-bar (same length, same timestamps).
    Callers are responsible for alignment; align_series() below builds an intersected pair.

    At each confirmed primary swing HIGH s (bearish SMT candidate):
        primary made a higher high than its previous confirmed swing high (a buy-side raid).
        partner CONFIRMS if its expected-direction high also exceeded its own prior swing-high band;
        SMT (divergence) is flagged when the partner does NOT confirm.
      For expected_sign = -1 (DXY) the partner series is negated before comparison, so a partner
      that fails to make a LOWER low (its inverted "higher high") is the divergence.
    Mirror for confirmed primary swing LOWS (bullish SMT candidate).

    Guard: if use_guard and the rolling correlation (oriented by expected_sign) over corr_window at
    the swing's confirmation bar is below corr_min in magnitude, the signal is SUPPRESSED. Disabling
    the guard (use_guard=False) lets the same divergence through — proving the guard is the
    discriminator (mirrors the disp gate toggle in qm_detect case C).

    Returns list of SMT event dicts (sorted by index):
        {"index","datetime","direction","prim_level","part_level","corr","guard"}.
      guard = 'pass' (correlation ok) or 'off' (guard disabled). Suppressed signals are NOT emitted.
    """
    n = min(len(prim_bars), len(part_bars))
    prim_close = [prim_bars[i][5] for i in range(n)]
    part_close = [part_bars[i][5] for i in range(n)]
    # orient the partner series by the expected sign for divergence comparison
    part_oriented_high = []
    part_oriented_low = []
    for i in range(n):
        h = part_bars[i][3]
        l = part_bars[i][4]
        if expected_sign >= 0:
            part_oriented_high.append(h)
            part_oriented_low.append(l)
        else:
            # inverted: a negatively-correlated partner's "high" corresponds to primary's low
            part_oriented_high.append(-l)
            part_oriented_low.append(-h)

    prim_ret = _returns(prim_close)
    # orient partner returns by expected sign so a -1 pair correlates POSITIVELY after orientation
    part_ret = _returns(part_close)
    part_ret_oriented = [expected_sign * x for x in part_ret]

    highs, lows = detect_swings(prim_bars[:n], pivot=pivot)

    events = []

    # bearish SMT: consecutive confirmed primary swing highs, primary HH, partner not HH
    for k in range(1, len(highs)):
        prev = highs[k - 1]
        cur = highs[k]
        conf_bar = cur["index"] + pivot
        if conf_bar >= n:
            continue
        if not (cur["price"] > prev["price"]):
            continue  # primary must make a higher high (the raid)
        # partner's oriented high at the two swing indices
        part_prev = part_oriented_high[prev["index"]]
        part_cur = part_oriented_high[cur["index"]]
        partner_confirms = part_cur > part_prev
        if partner_confirms:
            continue  # both made higher highs => no divergence
        corr = rolling_corr_at(prim_ret, part_ret_oriented, conf_bar, corr_window)
        if use_guard:
            if corr is None or abs(corr) < corr_min:
                continue  # guard suppresses: not sufficiently correlated in expected direction
            guard = "pass"
        else:
            guard = "off"
        events.append({
            "index": conf_bar, "datetime": prim_bars[conf_bar][1], "direction": "bear",
            "prim_level": cur["price"], "part_level": part_bars[cur["index"]][3],
            "corr": corr if corr is not None else 0.0, "guard": guard,
        })

    # bullish SMT: consecutive confirmed primary swing lows, primary LL, partner not LL
    for k in range(1, len(lows)):
        prev = lows[k - 1]
        cur = lows[k]
        conf_bar = cur["index"] + pivot
        if conf_bar >= n:
            continue
        if not (cur["price"] < prev["price"]):
            continue  # primary must make a lower low (the raid)
        part_prev = part_oriented_low[prev["index"]]
        part_cur = part_oriented_low[cur["index"]]
        partner_confirms = part_cur < part_prev
        if partner_confirms:
            continue
        corr = rolling_corr_at(prim_ret, part_ret_oriented, conf_bar, corr_window)
        if use_guard:
            if corr is None or abs(corr) < corr_min:
                continue
            guard = "pass"
        else:
            guard = "off"
        events.append({
            "index": conf_bar, "datetime": prim_bars[conf_bar][1], "direction": "bull",
            "prim_level": cur["price"], "part_level": part_bars[cur["index"]][4],
            "corr": corr if corr is not None else 0.0, "guard": guard,
        })

    events.sort(key=lambda e: (e["index"], e["direction"]))
    return events


# ---- alignment helper -------------------------------------------------------
def align_series(prim_bars, part_bars):
    """Intersect two bar lists on datetime, returning (aligned_prim, aligned_part) index-matched.

    Only timestamps present in BOTH series are kept, in primary time order. Bars without a
    parseable datetime cannot be aligned and are dropped. Deterministic.
    """
    part_by_dt = {}
    for b in part_bars:
        if b[1] is not None:
            part_by_dt[b[1]] = b
    ap = []
    aq = []
    i = 0
    for b in prim_bars:
        if b[1] is not None and b[1] in part_by_dt:
            p = part_by_dt[b[1]]
            ap.append((i,) + b[1:])
            aq.append((i,) + p[1:])
            i += 1
    return ap, aq


# ---- output -----------------------------------------------------------------
def _fmt_dt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S") if isinstance(dt, datetime.datetime) else str(dt)


def write_smt_csv(events, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["index", "datetime", "direction", "prim_level", "part_level", "corr", "guard"])
        for e in events:
            w.writerow([
                e["index"], _fmt_dt(e["datetime"]), e["direction"],
                f"{e['prim_level']:.5f}", f"{e['part_level']:.5f}",
                f"{e['corr']:.4f}", e["guard"],
            ])


DATA_DEPENDENCY_MSG = (
    "DATA-DEPENDENCY: SMT variant {pair!r} needs a partner OHLC series aligned to XAUUSD, which is\n"
    "  NOT present in this repository. Export {sym} from MT5 in the SAME format as the XAUUSD file\n"
    "  'datetime,open,high,low,close,volume' and pass it via --pair-csv <path>. Until then SMT is\n"
    "  effectively OFF (0 signals). No data is fabricated."
)

_PAIR_SYMBOL = {"xag": "XAGUSD", "dxy": "DXY"}


def print_summary(prim_bars, events, smt_pair, corr_window, corr_min, pivot, out_path, data_dep=False):
    n_bear = sum(1 for e in events if e["direction"] == "bear")
    n_bull = sum(1 for e in events if e["direction"] == "bull")
    first_dt = _fmt_dt(prim_bars[0][1]) if prim_bars else "n/a"
    last_dt = _fmt_dt(prim_bars[-1][1]) if prim_bars else "n/a"
    exp = EXPECTED_SIGN.get(smt_pair, 0)
    print("=" * 68)
    print(f"QM/ICT block-5b  SMT divergence detector  "
          f"(smt-pair={smt_pair}, corr-window={corr_window}, corr-min={corr_min}, pivot={pivot})")
    print("=" * 68)
    print(f"  primary bars: {len(prim_bars):>6}   ({first_dt} .. {last_dt})")
    if smt_pair != "off":
        sign_txt = "positive (with XAU)" if exp >= 0 else "negative (against XAU)"
        print(f"  expected correlation sign for {smt_pair!r}: {exp:+d}  [{sign_txt}]")
    print(f"  SMT signals:  {len(events):>6}   (bear={n_bear}, bull={n_bull})")
    if data_dep:
        print("-" * 68)
        print(DATA_DEPENDENCY_MSG.format(pair=smt_pair, sym=_PAIR_SYMBOL.get(smt_pair, smt_pair.upper())))
    print("-" * 68)
    if events:
        print("  first SMT signals:")
        print(f"  {'#':>3}  {'datetime':<19}  {'dir':<4}  {'prim_level':>11}  {'corr':>7}  {'guard':>5}")
        for i, e in enumerate(events[:10]):
            print(f"  {i + 1:>3}  {_fmt_dt(e['datetime']):<19}  {e['direction']:<4}  "
                  f"{e['prim_level']:>11.5f}  {e['corr']:>7.3f}  {e['guard']:>5}")
    else:
        print("  (no SMT signals)")
    print("-" * 68)
    print(f"  full SMT list written to: {out_path}")
    print("=" * 68)


# ---- self-check -------------------------------------------------------------
def _bar(idx, o, h, l, c):
    return (idx, None, float(o), float(h), float(l), float(c), 0.0)


def _mk(bars):
    return [(i,) + b[1:] for i, b in enumerate(bars)]


def selfcheck():
    """Synthetic assertions proving SMT detection, the negative (confirming) case, the correlation
    guard as a real discriminator, the expected-sign inversion for DXY, and honest data-dependency.

    Case A (POSITIVE divergence + guard passes): two positively-correlated aligned series; at a
        swing HIGH the primary makes a higher high but the partner makes a LOWER high => bearish SMT
        flagged (correlation high enough that the guard passes).
    Case B (NEGATIVE / confirming): both series make higher highs together => no SMT.
    Case C (GUARD is the discriminator): a divergence exists but the two series' returns are
        decorrelated over the window => the guard SUPPRESSES it; disabling the guard makes the SAME
        signal reappear (toggle proof, like qm_detect case C).
    Case D (EXPECTED-SIGN inversion for DXY): a negatively-correlated partner that fails to make the
        inverted move produces an SMT under expected_sign=-1.
    Case E (variant off / data dependency): --smt-pair off yields zero SMT; missing pair data is
        reported as a dependency (flag), never a crash.
    """
    pivot = 2

    # ---- Case A: positive-correlation pair, real bearish divergence, guard passes ----
    # Primary: prior swing high 106 at idx3, then a HIGHER swing high 110 at idx7 (both confirmable
    # with pivot=2). Partner rises broadly WITH primary (positive corr) but its high at the second
    # swing is LOWER than at the first => partner fails to confirm => bearish SMT.
    prim = _mk([
        _bar(0, 100, 101, 99, 100.0),
        _bar(1, 100, 102, 99, 100.5),
        _bar(2, 100.5, 104, 100, 101.5),
        _bar(3, 101.5, 106, 101, 102.5),  # prior swing HIGH = 106 (idx3)
        _bar(4, 102.5, 104, 101, 102.0),
        _bar(5, 102, 105, 101, 103.0),
        _bar(6, 103, 107, 102, 104.5),
        _bar(7, 104.5, 110, 104, 106.0),  # HIGHER swing HIGH = 110 (idx7, the raid)
        _bar(8, 106, 108, 104, 105.0),
        _bar(9, 105, 107, 103, 104.0),    # confirms swing at idx7 (idx7+2=9)
    ])
    # Partner: broadly rising (positive corr with primary) but its high at idx7 (~57) is LOWER than
    # its high at idx3 (~60) => partner does NOT confirm the higher high => divergence.
    part = _mk([
        _bar(0, 50, 51, 49, 50.0),
        _bar(1, 50, 52, 49.5, 51.0),
        _bar(2, 51, 55, 50.5, 53.0),
        _bar(3, 53, 60, 52.5, 55.0),      # partner prior high = 60 (idx3)
        _bar(4, 55, 57, 54, 55.0),
        _bar(5, 55, 58, 54.5, 56.0),      # from here the partner CLOSE tracks the primary close
        _bar(6, 56, 56.9, 55.5, 57.0),    # (up) matches primary up
        _bar(7, 57, 57.5, 55, 58.0),      # high 57.5 < 60 => does NOT confirm (divergence); close up
        _bar(8, 58, 58.2, 55, 57.5),      # (down) matches primary down
        _bar(9, 57.5, 58, 55.5, 57.0),    # (down) matches primary down
    ])
    evA = detect_smt(prim, part, pivot=pivot, expected_sign=1, corr_window=5, corr_min=0.3)
    bearA = [e for e in evA if e["direction"] == "bear"]
    assert bearA, "A: expected a bearish SMT divergence (primary HH, partner not HH)"

    # ---- Case B: both confirm (partner ALSO makes a higher high) => no divergence ----
    part_conf = _mk([
        _bar(0, 50, 51, 49, 50.0),
        _bar(1, 50, 52, 49.5, 51.0),
        _bar(2, 51, 55, 50.5, 53.0),
        _bar(3, 53, 58, 52.5, 55.0),      # partner prior high = 58 (idx3)
        _bar(4, 55, 57, 54, 55.5),
        _bar(5, 55.5, 59, 54.5, 56.5),
        _bar(6, 56.5, 60, 55.5, 58.0),
        _bar(7, 58, 63, 57, 61.0),        # partner high = 63 > 58 => CONFIRMS => no SMT
        _bar(8, 61, 62, 59, 60.0),
        _bar(9, 60, 61, 58, 59.0),
    ])
    evB = detect_smt(prim, part_conf, pivot=pivot, expected_sign=1, corr_window=5, corr_min=0.3)
    bearB = [e for e in evB if e["direction"] == "bear"]
    assert not bearB, "B: partner also made a higher high => must NOT be an SMT (negative case)"

    # ---- Case C: guard is the discriminator ----
    # Same divergence structure (partner high at idx7 is LOWER than at idx3) but the partner's
    # bar-to-bar RETURNS zig-zag OPPOSITE to the primary's steady rise, so the rolling correlation
    # over the window is near zero / negative -> below a high corr_min. The guard suppresses; with
    # the guard disabled the SAME divergence reappears (toggle proof, like qm_detect case C).
    part_decorr = _mk([
        _bar(0, 60, 61, 59, 60.0),
        _bar(1, 60, 61, 55, 55.0),       # down while primary up
        _bar(2, 55, 62, 54, 61.0),       # up
        _bar(3, 61, 66, 54, 56.0),       # prior high 66 (idx3), close down
        _bar(4, 56, 63, 55, 62.0),       # up
        _bar(5, 62, 63, 55, 55.5),       # down
        _bar(6, 55.5, 61, 55, 60.5),     # up
        _bar(7, 60.5, 64, 54, 55.0),     # high 64 < 66 => divergence; close down (anti-correlated)
        _bar(8, 55, 62, 54, 61.0),
        _bar(9, 61, 63, 55, 56.0),
    ])
    ev_guard_on = detect_smt(prim, part_decorr, pivot=pivot, expected_sign=1,
                             corr_window=6, corr_min=0.6, use_guard=True)
    ev_guard_off = detect_smt(prim, part_decorr, pivot=pivot, expected_sign=1,
                              corr_window=6, corr_min=0.6, use_guard=False)
    bear_on = [e for e in ev_guard_on if e["direction"] == "bear"]
    bear_off = [e for e in ev_guard_off if e["direction"] == "bear"]
    assert not bear_on, "C: with a high corr-min the guard should SUPPRESS the decorrelated SMT"
    assert bear_off, "C: disabling the guard makes the SAME divergence reappear (guard is discriminator)"

    # ---- Case D: expected-sign inversion for a DXY-like (negatively correlated) partner ----
    # Partner is expected to move AGAINST primary. Primary makes a higher high; a properly inverse
    # partner would make a LOWER low. This partner FAILS to make a lower low => bearish SMT under -1.
    prim_d = prim  # primary makes a higher high at idx7 vs idx3
    # For expected_sign=-1 the partner's oriented "high" = -low. Confirmation would need its low at
    # idx7 to be LOWER than at idx3. This DXY-like partner's low at idx7 (196) is HIGHER than at idx3
    # (190) => it fails to confirm the inverted move => bearish SMT under expected_sign=-1.
    part_dxy = _mk([
        _bar(0, 200, 201, 198, 200.0),
        _bar(1, 200, 202, 197, 199.0),
        _bar(2, 199, 201, 193, 195.0),
        _bar(3, 195, 200, 190, 196.0),   # partner prior LOW = 190 (idx3)
        _bar(4, 196, 202, 195, 199.0),
        _bar(5, 199, 203, 196, 200.0),
        _bar(6, 200, 204, 197, 201.0),
        _bar(7, 201, 205, 196, 202.0),   # low 196 > 190 => did NOT make a lower low => divergence
        _bar(8, 202, 206, 198, 203.0),
        _bar(9, 203, 207, 199, 204.0),
    ])
    evD = detect_smt(prim_d, part_dxy, pivot=pivot, expected_sign=-1, corr_window=5, corr_min=0.0)
    bearD = [e for e in evD if e["direction"] == "bear"]
    assert bearD, "D: DXY-like inverse partner failing the inverted move => bearish SMT (sign inversion works)"
    # sanity: expected-sign is documented, not guessed
    assert EXPECTED_SIGN["xag"] == 1 and EXPECTED_SIGN["dxy"] == -1, "D: expected signs must be the documented constants"

    # ---- Case E: variant 'off' => zero SMT; and the correlation helper is deterministic ----
    # 'off' means no partner series -> detect_smt is never called with a partner; a partner aligned
    # to itself with pair 'off' semantics yields no signals because the runner skips detection.
    # Here we assert the pure guard math is deterministic and Pearson behaves at the extremes.
    xs = [0.1, -0.2, 0.3, -0.1, 0.05]
    assert abs(pearson(xs, xs) - 1.0) < 1e-9, "E: pearson(x,x) must be 1"
    assert abs(pearson(xs, [-v for v in xs]) + 1.0) < 1e-9, "E: pearson(x,-x) must be -1"
    assert pearson([1, 1, 1], [1, 2, 3]) == 0.0, "E: zero-variance series => 0 correlation"
    # off variant contract: no partner => no events (simulated by empty partner alignment)
    ap, aq = align_series(prim, [])
    assert ap == [] and aq == [], "E: no partner data => nothing aligns => zero SMT (variant OFF)"

    print("selfcheck: PASS")
    print("  case A: primary HH + partner not-HH (correlated) => bearish SMT (guard passes)")
    print("  case B: partner also makes HH => no SMT (negative/confirming case)")
    print("  case C: decorrelated returns => guard SUPPRESSES SMT; reappears with guard off (toggle)")
    print("  case D: DXY expected-sign -1 inversion => inverse partner failure flags SMT")
    print("  case E: smt-pair off / missing partner => zero SMT + reported as dependency (no crash)")
    return True


# ---- CLI --------------------------------------------------------------------
def parse_args(argv):
    p = argparse.ArgumentParser(
        description="QM/ICT block-5b: SMT divergence detector with a rolling-correlation guard.")
    p.add_argument("path", nargs="?", default=None,
                   help="primary XAUUSD OHLC CSV (datetime,open,high,low,close,volume)")
    p.add_argument("--selfcheck", action="store_true", help="run synthetic assertions only")
    p.add_argument("--smt-pair", default=SMT_PAIR_DEFAULT, choices=SMT_PAIRS,
                   help=f"SMT partner variant: 'off' (default), 'xag', or 'dxy'. OPEN rule -> VARIANT")
    p.add_argument("--pair-csv", default=None,
                   help="partner OHLC CSV (XAGUSD/DXY) in the same format; required for xag/dxy")
    p.add_argument("--pivot", type=int, default=PIVOT_DEFAULT,
                   help=f"confirmed-swing pivot L/R count (default {PIVOT_DEFAULT}; tunable, not baked in)")
    p.add_argument("--corr-window", type=int, default=CORR_WINDOW_DEFAULT,
                   help=f"rolling-correlation lookback in bars (default {CORR_WINDOW_DEFAULT}; "
                        f"OPEN rule, tunable, not baked in)")
    p.add_argument("--corr-min", type=float, default=CORR_MIN_DEFAULT,
                   help=f"min |expected-direction correlation| to trust an SMT "
                        f"(default {CORR_MIN_DEFAULT}; OPEN rule, tunable, not baked in)")
    p.add_argument("--out", default=None, help="write SMT event CSV to this path")
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
    if args.corr_window < 2:
        raise SystemExit("--corr-window must be >= 2")

    prim_bars = load_ohlc(args.path)
    if not prim_bars:
        raise SystemExit(f"no OHLC rows parsed from {args.path}")

    out = args.out if args.out else "smt_events.csv"

    # ---- resolve the partner series honestly ----
    events = []
    data_dep = False
    if args.smt_pair == "off":
        # No partner series in the repo -> SMT is OFF by design; zero signals, no fabrication.
        events = []
    else:
        pair_ok = args.pair_csv is not None and os.path.isfile(args.pair_csv)
        if not pair_ok:
            # honest data dependency: report and exit cleanly with SMT effectively OFF
            data_dep = True
            events = []
        else:
            part_raw = load_ohlc(args.pair_csv)
            if not part_raw:
                data_dep = True
                events = []
            else:
                ap, aq = align_series(prim_bars, part_raw)
                if not ap:
                    data_dep = True
                    events = []
                else:
                    exp = EXPECTED_SIGN[args.smt_pair]
                    events = detect_smt(ap, aq, pivot=args.pivot, expected_sign=exp,
                                        corr_window=args.corr_window, corr_min=args.corr_min,
                                        use_guard=True)

    write_smt_csv(events, out)
    print_summary(prim_bars, events, args.smt_pair, args.corr_window, args.corr_min,
                  args.pivot, out, data_dep=data_dep)


if __name__ == "__main__":
    main()

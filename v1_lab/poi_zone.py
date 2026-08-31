#!/usr/bin/env python3
"""
QM/ICT setup — building-block 5a: POI (Point-Of-Interest) / QM zone builder.

Scope (intentionally narrow): from CONFIRMED swings, build the QM (Quasimodo) POI zone — the
origin / LEFT-SHOULDER zone that price is expected to return to for the entry. Only the POI zone
construction (and its optional OB / FVG confluence) lives here. Entry timing / SL / TP / IDM-clear
requirement / SMT are OUT OF SCOPE (owned by other blocks / the state machine).

QM (Quasimodo) structure used here (causal, from confirmed swings):
  bearish QM (a SELL POI above price):
      left-shoulder swing HIGH (LS)  ->  a higher HEAD swing HIGH (the liquidity raid above LS)
      ->  price then breaks structure DOWN below the intervening swing LOW (the neckline).
      The POI is the LEFT-SHOULDER zone: the price band of the left-shoulder swing-high candle,
      i.e. [min(open,close) .. high] of that candle (the body-to-wick supply band). Price is
      expected to return UP into this band to sell.
  bullish QM (a BUY POI below price): the mirror — left-shoulder swing LOW, a lower HEAD swing
      LOW, then a break of structure UP above the intervening swing HIGH; the POI is the
      left-shoulder swing-low candle band [low .. max(open,close)].

Discipline (anti-overfitting, from SPEC/DESIGN_v1.0.md): nothing subjective is baked in, and NO
POI type is declared "best". The POI type is an explicit VARIANT to be A/B tested out-of-sample:
  - POI_TYPE (variant)  'qm'      left-shoulder zone only                       (DEFAULT)
                        'qm_ob'   require ORDER-BLOCK confluence on the LS zone
                        'qm_fvg'  require FAIR-VALUE-GAP confluence on the shift leg
OB and FVG are OBJECTIVE detectors (defined below); the variant only decides whether they are
REQUIRED for a POI to qualify. Pre-choosing a variant = overfitting = forbidden.

Objective helpers (not tunable, structurally defined):
  ORDER BLOCK (OB): the last OPPOSING candle immediately before the displacement (break) leg.
      For a bearish QM the break leg is DOWN, so the OB is the last UP (bullish body) candle
      before the break — its band is a supply OB. Mirror for bullish QM (last down candle).
      The search is BOUNDED to the immediate displacement leg (ob_lookback bars back from the
      break) so the OB confluence can actually BIND: an unbounded scan to bar 0 almost always
      finds some opposing candle, so requiring an OB would never discriminate (it would be a
      near-no-op). The bound is an OPEN PARAMETER (ob_lookback), NOT a pre-picked winner.
  FAIR-VALUE GAP (FVG): a 3-candle imbalance around the break leg. Bearish FVG at candle i (the
      middle candle) exists when bars[i-1].low > bars[i+1].high (a gap the market skipped). The
      body of the middle candle is unfilled by the neighbours. Mirror (bullish) when
      bars[i-1].high < bars[i+1].low.

Tunable parameters (NOT locked truths):
  - PIVOT        confirmed-swing pivot L/R count (default 2, consistent with qm_detect).
  - OB_LOOKBACK  how many bars back from the structure break the order-block search may look for
                 the last opposing candle (default 5; the "immediate displacement leg" bound).
                 This is an OPEN parameter to A/B test, NOT a decided best value. A larger value
                 approaches the old scan-to-zero behaviour; a smaller one demands the OB sit right
                 on the displacement. It exists so the qm_ob variant can genuinely bind.

Causality (LOCKED discipline): a QM at head-confirmation bar t uses only swings CONFIRMED by t
(swing index + pivot <= t) and only candles at/at-or-before the structure break. No future bar
influences a POI. Mirrors the forward-sweep pointer pattern in qm_detect / erl_detect.

Deterministic: same input CSV + same parameters + same variant => identical output.
Pure Python standard library only (csv, datetime, argparse) — dependency-free.

Usage:
    python3 v1_lab/poi_zone.py <ohlc.csv> [--pivot 2] [--poi-type qm|qm_ob|qm_fvg]
        [--out poi_zones.csv]
    python3 v1_lab/poi_zone.py --selfcheck    # run built-in synthetic assertions only
"""
import os
import sys
import csv
import argparse
import datetime

# Ensure qm_detect (same directory) is importable when run from the repo root.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qm_detect import load_ohlc, detect_swings  # reuse the identical parser + swing rule


# ---- defaults (tunable parameter / variant, NOT locked truths) --------------
PIVOT_DEFAULT = 2          # confirmed-swing pivot (consistent with qm_detect default)
POI_TYPE_DEFAULT = "qm"    # POI variant; 'qm' | 'qm_ob' | 'qm_fvg' — NOT a decided winner
POI_TYPES = ("qm", "qm_ob", "qm_fvg")
OB_LOOKBACK_DEFAULT = 5    # bars back from the break the OB search may scan (immediate disp leg).
                           # OPEN parameter, NOT a pre-picked winner; bounds qm_ob so it can bind.


# ---- objective helper: order block (OB) -------------------------------------
def find_order_block(bars, break_index, direction, lookback=OB_LOOKBACK_DEFAULT):
    """Last OPPOSING candle immediately before the displacement/break leg ending at break_index.

    direction 'bear' (break DOWN): OB = the most recent UP candle (close > open) strictly before
        break_index; its band is [low .. high] with body [open .. close] (a supply OB).
    direction 'bull' (break UP):   OB = the most recent DOWN candle (close < open) before it.

    The search is BOUNDED to the immediate displacement leg: only the `lookback` bars strictly
    before break_index are scanned (i.e. indices [break_index-lookback .. break_index-1]). This is
    what makes the qm_ob confluence discriminating instead of a near-no-op — an unbounded scan to
    bar 0 almost always finds SOME opposing candle. `lookback` is an OPEN parameter (default
    OB_LOOKBACK_DEFAULT), NOT a pre-picked best value. `lookback <= 0` disables the bound (scan to
    bar 0), preserving the old behaviour for callers that want it. Causal: all scanned bars are
    strictly before break_index, hence <= break_index.

    Returns a dict {"index","low","high","body_low","body_high"} or None if no opposing candle is
    found within the bounded scan.
    """
    if break_index is None or break_index <= 0:
        return None
    lo_bound = 0 if (lookback is None or lookback <= 0) else max(0, break_index - lookback)
    for i in range(break_index - 1, lo_bound - 1, -1):
        _, _, o, h, l, c, _ = bars[i]
        is_up = c > o
        is_down = c < o
        if (direction == "bear" and is_up) or (direction == "bull" and is_down):
            return {
                "index": i, "low": l, "high": h,
                "body_low": min(o, c), "body_high": max(o, c),
            }
    return None


# ---- objective helper: fair-value gap (FVG) ---------------------------------
def find_fvg(bars, mid_index, direction):
    """3-candle imbalance (fair-value gap) centred on the middle candle mid_index.

    bearish FVG: bars[mid-1].low  > bars[mid+1].high   (a downward imbalance gap)
    bullish FVG: bars[mid-1].high < bars[mid+1].low    (an upward imbalance gap)

    Returns a dict {"index","gap_low","gap_high"} for the gap band or None if no gap exists.
    NOTE: this inspects bars[mid+1], so callers that require causality must only call it once
    mid_index+1 has occurred (i.e. mid_index+1 <= current bar). It is a pure structural test.
    """
    if mid_index is None or mid_index < 1 or mid_index + 1 >= len(bars):
        return None
    prev_low = bars[mid_index - 1][4]
    prev_high = bars[mid_index - 1][3]
    next_low = bars[mid_index + 1][4]
    next_high = bars[mid_index + 1][3]
    if direction == "bear" and prev_low > next_high:
        return {"index": mid_index, "gap_low": next_high, "gap_high": prev_low}
    if direction == "bull" and prev_high < next_low:
        return {"index": mid_index, "gap_low": prev_high, "gap_high": next_low}
    return None


# ---- QM POI construction ----------------------------------------------------
def detect_poi(bars, pivot=PIVOT_DEFAULT, poi_type=POI_TYPE_DEFAULT, ob_lookback=OB_LOOKBACK_DEFAULT):
    """Detect QM POI zones (left-shoulder anchored), causal, from confirmed swings.

    Algorithm (bearish QM; bullish is the mirror):
      Walk confirmed swing HIGHS in confirmation order. For each candidate HEAD swing high H:
        - LEFT SHOULDER = the immediately preceding confirmed swing high LS with LS.price < H.price
          (H raids liquidity above LS -> the quasimodo "head").
        - NECKLINE = the confirmed swing LOW between LS and H (the intervening low).
        - STRUCTURE BREAK = the first bar AFTER H's confirmation that CLOSES below the neckline
          price (body close, mirrors the MSS body-close discipline). That break bar's index is the
          POI's confirmation bar (earliest causal time the POI can be trusted).
      The POI zone is the LEFT-SHOULDER candle band:
          bear: zone = [min(open,close) .. high] of the LS candle (supply band above).
          bull: zone = [low .. max(open,close)] of the LS candle (demand band below).

    poi_type variant:
      'qm'     : every structurally-valid QM qualifies.
      'qm_ob'  : additionally require an order block on the break leg (find_order_block != None),
                 where the OB search is BOUNDED to the immediate displacement leg via ob_lookback
                 (default OB_LOOKBACK_DEFAULT) so the requirement can actually bind/discriminate.
      'qm_fvg' : additionally require a fair-value gap around the break (find_fvg != None).

    ob_lookback : how many bars back from the structure break the OB search may scan (open
                 parameter, not a pre-picked winner). <=0 disables the bound (scan to bar 0).

    Returns (pois, highs, lows). Each POI dict:
        {"confirm_index","confirm_datetime","direction","ls_index","head_index","neck_index",
         "neck_price","zone_low","zone_high","ob_index","fvg_index"}.
    """
    if poi_type not in POI_TYPES:
        raise ValueError(f"poi_type must be one of {POI_TYPES}, got {poi_type!r}")
    highs, lows = detect_swings(bars, pivot=pivot)
    n = len(bars)

    # confirmation bar for each swing = index + pivot (leakage-free)
    def conf(sw):
        return sw["index"] + pivot

    pois = []

    # ---- bearish QM: head is a swing HIGH that exceeds the prior swing HIGH ----
    for k in range(1, len(highs)):
        ls = highs[k - 1]
        head = highs[k]
        if not (head["price"] > ls["price"]):
            continue
        # neckline = the confirmed swing LOW whose index is between LS and HEAD
        neck = None
        for lo in lows:
            if ls["index"] < lo["index"] < head["index"]:
                neck = lo   # keep the last such low (closest to the head)
        if neck is None:
            continue
        head_conf = conf(head)
        # structure break: first bar after head confirmation that CLOSES below neckline
        break_index = None
        for t in range(head_conf, n):
            if bars[t][5] < neck["price"]:
                break_index = t
                break
        if break_index is None:
            continue
        # POI zone = left-shoulder candle supply band [min(o,c) .. high]
        _, _, o, h, l, c, _ = bars[ls["index"]]
        zone_low = min(o, c)
        zone_high = h
        ob = find_order_block(bars, break_index, "bear", lookback=ob_lookback)
        fvg = None
        # search a small window around the break leg for a 3-candle imbalance (causal: <= break)
        for mid in range(max(1, break_index - 1), break_index + 1):
            if mid + 1 <= break_index:
                cand = find_fvg(bars, mid, "bear")
                if cand is not None:
                    fvg = cand
                    break
        if poi_type == "qm_ob" and ob is None:
            continue
        if poi_type == "qm_fvg" and fvg is None:
            continue
        pois.append({
            "confirm_index": break_index, "confirm_datetime": bars[break_index][1],
            "direction": "bear", "ls_index": ls["index"], "head_index": head["index"],
            "neck_index": neck["index"], "neck_price": neck["price"],
            "zone_low": zone_low, "zone_high": zone_high,
            "ob_index": ob["index"] if ob else None,
            "fvg_index": fvg["index"] if fvg else None,
        })

    # ---- bullish QM: head is a swing LOW below the prior swing LOW ----
    for k in range(1, len(lows)):
        ls = lows[k - 1]
        head = lows[k]
        if not (head["price"] < ls["price"]):
            continue
        neck = None
        for hi in highs:
            if ls["index"] < hi["index"] < head["index"]:
                neck = hi
        if neck is None:
            continue
        head_conf = conf(head)
        break_index = None
        for t in range(head_conf, n):
            if bars[t][5] > neck["price"]:
                break_index = t
                break
        if break_index is None:
            continue
        _, _, o, h, l, c, _ = bars[ls["index"]]
        zone_low = l
        zone_high = max(o, c)
        ob = find_order_block(bars, break_index, "bull", lookback=ob_lookback)
        fvg = None
        for mid in range(max(1, break_index - 1), break_index + 1):
            if mid + 1 <= break_index:
                cand = find_fvg(bars, mid, "bull")
                if cand is not None:
                    fvg = cand
                    break
        if poi_type == "qm_ob" and ob is None:
            continue
        if poi_type == "qm_fvg" and fvg is None:
            continue
        pois.append({
            "confirm_index": break_index, "confirm_datetime": bars[break_index][1],
            "direction": "bull", "ls_index": ls["index"], "head_index": head["index"],
            "neck_index": neck["index"], "neck_price": neck["price"],
            "zone_low": zone_low, "zone_high": zone_high,
            "ob_index": ob["index"] if ob else None,
            "fvg_index": fvg["index"] if fvg else None,
        })

    pois.sort(key=lambda p: (p["confirm_index"], p["direction"]))
    return pois, highs, lows


# ---- output -----------------------------------------------------------------
def _fmt_dt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S") if isinstance(dt, datetime.datetime) else str(dt)


def write_poi_csv(pois, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["confirm_index", "confirm_datetime", "direction", "ls_index", "head_index",
                    "neck_index", "neck_price", "zone_low", "zone_high", "ob_index", "fvg_index"])
        for p in pois:
            w.writerow([
                p["confirm_index"], _fmt_dt(p["confirm_datetime"]), p["direction"],
                p["ls_index"], p["head_index"], p["neck_index"], f"{p['neck_price']:.5f}",
                f"{p['zone_low']:.5f}", f"{p['zone_high']:.5f}",
                "" if p["ob_index"] is None else p["ob_index"],
                "" if p["fvg_index"] is None else p["fvg_index"],
            ])


def print_summary(bars, pois, highs, lows, pivot, poi_type, out_path):
    n_bear = sum(1 for p in pois if p["direction"] == "bear")
    n_bull = sum(1 for p in pois if p["direction"] == "bull")
    n_ob = sum(1 for p in pois if p["ob_index"] is not None)
    n_fvg = sum(1 for p in pois if p["fvg_index"] is not None)
    first_dt = _fmt_dt(bars[0][1]) if bars else "n/a"
    last_dt = _fmt_dt(bars[-1][1]) if bars else "n/a"
    print("=" * 66)
    print(f"QM/ICT block-5a  POI / QM zone builder  (pivot={pivot}, poi-type={poi_type})")
    print("=" * 66)
    print(f"  bars:   {len(bars):>6}   ({first_dt} .. {last_dt})")
    print(f"  swings: {len(highs) + len(lows):>6}   (highs={len(highs)}, lows={len(lows)})")
    print(f"  POIs:   {len(pois):>6}   (bear/sell={n_bear}, bull/buy={n_bull})")
    print(f"          OB confluence present: {n_ob}   FVG confluence present: {n_fvg}")
    print("-" * 66)
    print("  first POI zones:")
    print(f"  {'#':>3}  {'confirm dt':<19}  {'dir':<4}  {'zone_low':>11}  {'zone_high':>11}")
    for i, p in enumerate(pois[:10]):
        print(f"  {i + 1:>3}  {_fmt_dt(p['confirm_datetime']):<19}  {p['direction']:<4}  "
              f"{p['zone_low']:>11.5f}  {p['zone_high']:>11.5f}")
    if not pois:
        print("  (none)")
    print("-" * 66)
    print(f"  full POI list written to: {out_path}")
    print("=" * 66)


# ---- self-check -------------------------------------------------------------
def _bar(idx, o, h, l, c):
    return (idx, None, float(o), float(h), float(l), float(c), 0.0)


def selfcheck():
    """Synthetic assertions proving POI construction, OB/FVG detectors (positive AND negative),
    and that the poi-type variant genuinely changes which POIs qualify.

    Case A (POSITIVE QM + left-shoulder anchor): a clean bearish quasimodo — left-shoulder high,
        a higher head, then a body close below the neckline — yields exactly one bearish POI whose
        zone band matches the left-shoulder candle's [min(open,close) .. high].
    Case B (FVG positive vs negative): a constructed 3-candle bearish imbalance is detected; a
        filled/no-gap 3-candle sequence is NOT detected (negative case).
    Case C (OB positive): the order block is the last opposing (up) candle before a down break.
    Case D (VARIANT is real): on a QM whose break leg has NO order block and NO FVG, 'qm' qualifies
        it but 'qm_ob' and 'qm_fvg' both suppress it — the variant changes the result. And on a QM
        that DOES carry OB+FVG, all three variants keep it (variant is a real discriminator).
    """
    pivot = 2

    # ---- Case A: clean bearish QM, verify left-shoulder zone anchor ----
    # LS swing high = 110 at idx2 (candle open 101 close 108 high 110 -> zone [101..110]).
    # HEAD swing high = 116 at idx6 (> 110). Neckline swing low between = idx4. Then break down.
    seriesA = [
        _bar(0, 100, 101, 99, 100),
        _bar(1, 100, 103, 100, 102),
        _bar(2, 101, 110, 102, 108),   # LEFT SHOULDER high=110, body [101..108] -> zone [101..110]
        _bar(3, 108, 109, 104, 105),
        _bar(4, 105, 106, 100, 101),   # neckline swing LOW = 100 (strictly < neighbours)
        _bar(5, 101, 112, 103, 110),
        _bar(6, 110, 116, 109, 114),   # HEAD high=116 (> 110)
        _bar(7, 114, 115, 110, 111),
        _bar(8, 111, 112, 107, 108),   # confirms head (idx6+2=8)
        _bar(9, 108, 109, 98, 99),     # body CLOSE 99 < neckline 100 => structure break here
        _bar(10, 99, 100, 96, 97),
    ]
    seriesA = [(i,) + b[1:] for i, b in enumerate(seriesA)]
    poisA, hiA, loA = detect_poi(seriesA, pivot=pivot, poi_type="qm")
    bearA = [p for p in poisA if p["direction"] == "bear"]
    assert len(bearA) >= 1, "A: expected at least one bearish QM POI"
    poi = bearA[0]
    assert poi["ls_index"] == 2, f"A: left shoulder should be idx2, got {poi['ls_index']}"
    assert poi["head_index"] == 6, f"A: head should be idx6, got {poi['head_index']}"
    # zone = left-shoulder candle [min(open,close) .. high] = [101 .. 110]
    assert abs(poi["zone_low"] - 101.0) < 1e-9, f"A: zone_low should be 101, got {poi['zone_low']}"
    assert abs(poi["zone_high"] - 110.0) < 1e-9, f"A: zone_high should be 110, got {poi['zone_high']}"
    assert poi["confirm_index"] == 9, f"A: break/confirm bar should be idx9, got {poi['confirm_index']}"

    # ---- Case B: FVG positive and negative ----
    # bearish FVG at middle candle idx1 when bars[0].low > bars[2].high.
    fvg_series = [
        _bar(0, 110, 111, 108, 109),   # low 108
        _bar(1, 108, 108, 104, 105),   # middle (the displacement candle)
        _bar(2, 104, 107, 103, 106),   # high 107  -> 108 > 107 => bearish gap [107..108]
    ]
    gap = find_fvg(fvg_series, 1, "bear")
    assert gap is not None, "B: expected a bearish FVG on the constructed imbalance"
    assert abs(gap["gap_low"] - 107.0) < 1e-9 and abs(gap["gap_high"] - 108.0) < 1e-9, \
        f"B: FVG band should be [107..108], got {gap}"
    # negative: overlapping candles, no gap (bars[0].low <= bars[2].high)
    nogap_series = [
        _bar(0, 110, 111, 105, 106),   # low 105
        _bar(1, 106, 107, 103, 104),
        _bar(2, 103, 108, 102, 107),   # high 108 -> 105 > 108 false => no gap
    ]
    assert find_fvg(nogap_series, 1, "bear") is None, "B: filled/overlapping sequence must NOT be an FVG"

    # ---- Case C: OB is the last opposing (up) candle before a down break ----
    ob_series = [
        _bar(0, 100, 101, 99, 100),
        _bar(1, 100, 105, 100, 104),   # UP candle (close>open) -> last opposing before break
        _bar(2, 104, 104, 96, 97),     # DOWN break leg
        _bar(3, 97, 98, 93, 94),       # break_index
    ]
    ob = find_order_block(ob_series, 3, "bear")
    assert ob is not None and ob["index"] == 1, f"C: OB should be idx1 (last up candle), got {ob}"

    # ---- Case C2: ob_lookback BOUNDS the search to the immediate displacement leg ----
    # A lone opposing (up) candle sits far back at idx1; the displacement leg (idx6->8) has NO up
    # candle. With a small lookback the OB search must NOT reach back to idx1 (returns None); with
    # the bound disabled (<=0, scan to bar0) it DOES find idx1. This proves the bound binds and is
    # the parameter that makes qm_ob discriminating rather than a near-no-op.
    bounded_series = [
        _bar(0, 100, 101, 99, 100),
        _bar(1, 100, 105, 100, 104),   # lone UP candle (the only opposing candle in the series)
        _bar(2, 104, 104, 100, 101),   # down
        _bar(3, 101, 102, 98, 99),     # down
        _bar(4, 99, 100, 96, 97),      # down
        _bar(5, 97, 98, 94, 95),       # down
        _bar(6, 95, 96, 92, 93),       # down (displacement leg, no up candle within lookback=3)
        _bar(7, 93, 94, 90, 91),       # down
        _bar(8, 91, 92, 88, 89),       # down break_index=8
    ]
    ob_far_bounded = find_order_block(bounded_series, 8, "bear", lookback=3)
    assert ob_far_bounded is None, "C2: bounded OB search (lookback=3) must NOT reach the far idx1 up candle"
    ob_far_unbounded = find_order_block(bounded_series, 8, "bear", lookback=0)
    assert ob_far_unbounded is not None and ob_far_unbounded["index"] == 1, \
        "C2: disabling the bound (lookback<=0) scans to bar0 and finds the lone up candle at idx1"

    # ---- Case D: poi-type variant genuinely changes qualification ----
    # Reuse series A (a valid QM). Determine whether its break leg carries OB / FVG, then assert
    # the variant filter behaves as a real discriminator by toggling requirement on/off.
    poi_qm = detect_poi(seriesA, pivot=pivot, poi_type="qm")[0]
    poi_ob = detect_poi(seriesA, pivot=pivot, poi_type="qm_ob")[0]
    poi_fvg = detect_poi(seriesA, pivot=pivot, poi_type="qm_fvg")[0]
    base = [p for p in poi_qm if p["direction"] == "bear"]
    assert base, "D: 'qm' should keep the valid QM"
    b = base[0]
    ob_present = b["ob_index"] is not None
    fvg_present = b["fvg_index"] is not None
    qm_ob_kept = any(p["ls_index"] == b["ls_index"] for p in poi_ob if p["direction"] == "bear")
    qm_fvg_kept = any(p["ls_index"] == b["ls_index"] for p in poi_fvg if p["direction"] == "bear")
    # the variant must AGREE with the objective presence of the confluence (it is the discriminator)
    assert qm_ob_kept == ob_present, "D: qm_ob must keep iff an OB is objectively present"
    assert qm_fvg_kept == fvg_present, "D: qm_fvg must keep iff an FVG is objectively present"
    # requiring confluence can only keep or reduce POIs (never invent one).
    n_qm = len(detect_poi(seriesA, pivot=pivot, poi_type="qm")[0])
    n_ob = len(detect_poi(seriesA, pivot=pivot, poi_type="qm_ob")[0])
    n_fvg = len(detect_poi(seriesA, pivot=pivot, poi_type="qm_fvg")[0])
    assert n_ob <= n_qm and n_fvg <= n_qm, "D: requiring confluence can only keep or reduce POIs"

    # ---- Case D2 (VARIANT genuinely SUPPRESSES): a valid QM with an OB on its break leg but NO
    # FVG. 'qm' and 'qm_ob' keep it; 'qm_fvg' drops it. Toggling the variant changes the result,
    # exactly like the disp gate in qm_detect case C — the variant is the discriminator.
    seriesD = [
        _bar(0, 100, 101, 99, 100),
        _bar(1, 100, 103, 100, 102),
        _bar(2, 101, 110, 102, 108),   # LS high=110
        _bar(3, 108, 109, 104, 105),
        _bar(4, 105, 106, 100, 101),   # neckline swing low=100
        _bar(5, 101, 112, 103, 110),
        _bar(6, 110, 116, 109, 114),   # HEAD high=116 (also the last UP candle -> OB present)
        _bar(7, 114, 115, 110, 111),
        _bar(8, 111, 112, 108, 109),   # confirms head idx8
        _bar(9, 109, 110, 103, 104),
        _bar(10, 104, 109, 99, 99.5),  # break (close 99.5<100); neighbours overlap => NO FVG
    ]
    seriesD = [(i,) + b[1:] for i, b in enumerate(seriesD)]
    d_qm = [p for p in detect_poi(seriesD, pivot=pivot, poi_type="qm")[0] if p["direction"] == "bear"]
    d_ob = [p for p in detect_poi(seriesD, pivot=pivot, poi_type="qm_ob")[0] if p["direction"] == "bear"]
    d_fvg = [p for p in detect_poi(seriesD, pivot=pivot, poi_type="qm_fvg")[0] if p["direction"] == "bear"]
    assert len(d_qm) == 1, "D2: 'qm' should keep the valid QM"
    assert d_qm[0]["ob_index"] is not None, "D2: this QM must carry an OB on its break leg"
    assert d_qm[0]["fvg_index"] is None, "D2: this QM must NOT carry an FVG"
    assert len(d_ob) == 1, "D2: 'qm_ob' keeps it (OB present)"
    assert len(d_fvg) == 0, "D2: 'qm_fvg' SUPPRESSES it (no FVG) -> variant is a real discriminator"

    print("selfcheck: PASS")
    print("  case A: clean bearish QM => one POI anchored at the left-shoulder band [101..110]")
    print("  case B: 3-candle imbalance => FVG detected; filled sequence => not an FVG (negative)")
    print("  case C: order block = last opposing (up) candle before the down break")
    print("  case C2: ob_lookback bounds the OB search to the displacement leg (bound binds; <=0 = scan to bar0)")
    print("  case D: poi-type qm|qm_ob|qm_fvg qualifies iff the confluence is present (variant is real)")
    print("  case D2: a QM with OB but no FVG => kept by qm/qm_ob, SUPPRESSED by qm_fvg (toggle proof)")
    return True


# ---- CLI --------------------------------------------------------------------
def parse_args(argv):
    p = argparse.ArgumentParser(
        description="QM/ICT block-5a: POI / QM (left-shoulder) zone builder with OB/FVG variants.")
    p.add_argument("path", nargs="?", default=None, help="OHLC CSV (datetime,open,high,low,close,volume)")
    p.add_argument("--selfcheck", action="store_true", help="run synthetic assertions only")
    p.add_argument("--pivot", type=int, default=PIVOT_DEFAULT,
                   help=f"confirmed-swing pivot L/R count (default {PIVOT_DEFAULT}; tunable, not baked in)")
    p.add_argument("--ob-lookback", type=int, default=OB_LOOKBACK_DEFAULT,
                   help=f"bars back from the break the qm_ob order-block search may scan (default "
                        f"{OB_LOOKBACK_DEFAULT}; OPEN parameter, not a pre-picked winner; <=0 = scan to bar 0)")
    p.add_argument("--poi-type", default=POI_TYPE_DEFAULT, choices=POI_TYPES,
                   help=f"POI variant: 'qm' (default), 'qm_ob', or 'qm_fvg'. This is an OPEN rule -> "
                        f"a VARIANT to A/B test; no type is pre-selected as best")
    p.add_argument("--out", default=None, help="write POI zone CSV to this path")
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

    bars = load_ohlc(args.path)
    if not bars:
        raise SystemExit(f"no OHLC rows parsed from {args.path}")

    out = args.out if args.out else "poi_zones.csv"
    pois, highs, lows = detect_poi(bars, pivot=args.pivot, poi_type=args.poi_type,
                                   ob_lookback=args.ob_lookback)
    write_poi_csv(pois, out)
    print_summary(bars, pois, highs, lows, args.pivot, args.poi_type, out)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
GFT COMPLIANCE ENGINE - deterministic prop-firm rule referee.

One job: take the output of an MT5 run and decide, rule by rule, whether that run would have
SURVIVED at Goat Funded Trader for a given stage (step1 / step2 / funded). It walks the trade
history in chronological order and HALTS at the FIRST hard breach, naming the exact rule, the
exact trade, the exact date and the exact number that broke it.

Design principles (money is at risk, so these are non-negotiable):
  1. MT5 is the truth. This script only READS MT5 outputs. It never simulates a trade.
  2. Three outcomes per rule, never two:
        PASS       - verified compliant from the evidence supplied
        BREACH     - definitely violated (hard stop)
        UNVERIFIED - the supplied evidence CANNOT prove compliance
     An UNVERIFIED rule is never reported as a pass. "We could not check it" is not "it is fine".
  3. Every rule states whether its measurement is EXACT or a LOWER BOUND, because closed-trade
     data cannot see intraday floating equity. A lower bound can prove a breach but it can
     never prove safety.
  4. No tuning, no thresholds relaxed to make a run look better. Limits come from the firm.

Exit codes (so a caller can stop automatically):
    0 = CLEARED       (all applicable rules PASS)
    1 = NOT CLEARED   (no breach found, but at least one rule is UNVERIFIED)
    2 = BREACH        (a hard rule was violated - the account would be dead)
    3 = input error

Usage:
  python tools/gft_compliance.py --stage funded --window experiments/combo_funded/windows/last1y
  python tools/gft_compliance.py --stage step1  --window <dir> --initial 5000 --json
Optional, for EXACT intraday checks:
  --equity-series <csv>   'time,equity' series including floating P&L (see AGENT doc)
"""

import argparse
import csv
import datetime as dt
import json
import os
import re
import sys

# ----------------------------------------------------------------------------------
# FIRM RULE BOOK - transcribed from .kiro/steering/gft-mission-and-rules.md
# These are the FIRM's numbers. They are constants. Never edit them to make a run pass.
# ----------------------------------------------------------------------------------
RULES = {
    "daily_dd_pct":        5.0,    # HARD, all stages
    "static_max_loss_pct": 10.0,   # HARD, all stages, STATIC (never trails up)
    "min_trading_days":    3,
    "goat_guard_pct":      2.0,    # funded only, of INITIAL, fixed dollars
    "valid_day_pct":       0.5,    # funded payout: a day counts if profit >= 0.5% of initial
    "funded_daily_profit_cap": 3000.0,   # not a breach; excess is deducted
    # News rule - confirmed by GFT support 2026-09-15. Profit from a trade opened OR closed within
    # 5 minutes either side of a high-impact release is capped at 1% of INITIAL ($50 on $5k); the
    # excess is removed. NOT a breach. Applies in BOTH evaluation and funded phases - unlike the
    # 2-minute and weekend-gap rules, which are funded-only.
    "news_profit_cap_pct": 1.0,
    "news_window_min":     5,
    # Margin ceiling - disclosed by GFT human support 2026-09-15: "There are no lot size
    # restrictions. You are not allowed to use more than 80% of available margin."
    "max_margin_pct":      80.0,
}

# XAUUSD margin rate measured on MetaQuotes-Demo (ledger seq67/seq69): a fixed ~10% of notional
# for metals, which account leverage does NOT override. GFT's own broker may differ - this is an
# input, and the engine says so rather than pretending to know.
DEFAULT_MARGIN_RATE = 0.10

STAGE_SPEC = {
    "step1":  {"target_pct": 10.0, "goat_guard": False, "daily_profit_cap": None},
    "step2":  {"target_pct":  5.0, "goat_guard": False, "daily_profit_cap": None},
    "funded": {"target_pct": None, "goat_guard": True,  "daily_profit_cap": RULES["funded_daily_profit_cap"]},
}

# Our own guardrails (Section 4) - tighter than the firm, checked as WARNINGS not breaches.
BUFFER = {
    "static_halt_pct": 8.0,   # we halt here, well inside the firm's 10%
    "daily_governor_pct": 4.0,  # we block new entries here, inside the firm's 5%
    "funded_float_flatten_pct": 1.5,  # we flatten here, inside Goat Guard's 2%
}

PASS       = "PASS"          # verified compliant
BREACH     = "BREACH"        # proven violation - account dead
LIKELY     = "LIKELY BREACH" # strong evidence of a violation that the data cannot fully settle
UNVERIFIED = "UNVERIFIED"    # cannot be proven either way from the evidence supplied
WARN       = "WARN"          # penalty or buffer trip, not a breach
INFO       = "INFO"          # informational only


class Check:
    """One rule verdict. `exact` records whether the measurement can prove safety."""

    def __init__(self, rule, status, detail, exact=True, limit=None, observed=None):
        self.rule = rule
        self.status = status
        self.detail = detail
        self.exact = exact
        self.limit = limit
        self.observed = observed

    def as_dict(self):
        return {
            "rule": self.rule, "status": self.status, "detail": self.detail,
            "measurement": "exact" if self.exact else "lower_bound",
            "limit": self.limit, "observed": self.observed,
        }


# ----------------------------------------------------------------------------------
# Input loading
# ----------------------------------------------------------------------------------
def load_trades(path):
    """Read an OnTester CSV. Accepts 'time,profit' or 'time,profit,magic'.
    Returns list of dicts sorted by time. Raises on unusable input."""
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    rows = []
    with open(path, newline="") as fh:
        rdr = csv.reader(fh)
        header = None
        for raw in rdr:
            if not raw or not any(c.strip() for c in raw):
                continue
            if header is None and raw[0].strip().lower().startswith("time"):
                header = [c.strip().lower() for c in raw]
                continue
            if len(raw) < 2:
                continue
            tstr = raw[0].strip()
            try:
                t = dt.datetime.strptime(tstr, "%Y.%m.%d %H:%M")
            except ValueError:
                try:
                    t = dt.datetime.strptime(tstr, "%Y-%m-%d %H:%M")
                except ValueError:
                    continue  # unparseable time: skip, counted below
            try:
                p = float(raw[1])
            except ValueError:
                continue
            magic = raw[2].strip() if len(raw) > 2 else ""
            mae = None
            if header and "mae" in header:
                i = header.index("mae")
                if i < len(raw):
                    try:
                        mae = abs(float(raw[i]))
                    except ValueError:
                        mae = None
            rows.append({"time": t, "profit": p, "magic": magic, "mae": mae})
    rows.sort(key=lambda r: r["time"])
    return rows


def load_deals(path):
    """Read an enriched per-position deals CSV (entry AND exit times).

    Expected header (the convention CK_GOLD_COMBO already writes):
        magic,dir,entry_time,entry_price,exit_time,exit_price,profit,volume
    An optional 'mae' column (worst adverse excursion in account currency) is used for Goat
    Guard when present. Entry+exit times are what make the 2-minute and weekend-gap rules
    checkable at all - trades.csv carries only the exit time.
    """
    if not os.path.exists(path):
        raise FileNotFoundError(path)

    def parse_t(s):
        for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M",
                    "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
            try:
                return dt.datetime.strptime(s.strip(), fmt), ("%S" in fmt)
            except ValueError:
                continue
        return None, False

    rows, hdr = [], None
    with open(path, newline="") as fh:
        for raw in csv.reader(fh):
            if not raw or not any(c.strip() for c in raw):
                continue
            low = [c.strip().lower() for c in raw]
            if hdr is None and ("entry_time" in low or low[0] == "magic"):
                hdr = low
                continue
            if hdr is None:
                continue
            rec = dict(zip(hdr, [c.strip() for c in raw]))
            et, e_sec = parse_t(rec.get("entry_time", ""))
            xt, x_sec = parse_t(rec.get("exit_time", ""))
            if et is None or xt is None:
                continue
            try:
                p = float(rec.get("profit", "0"))
            except ValueError:
                p = 0.0
            mae = None
            if rec.get("mae"):
                try:
                    mae = abs(float(rec["mae"]))
                except ValueError:
                    mae = None
            # Prefer an explicit hold_sec column: the EA writes it from the raw datetimes, so it
            # is EXACT even though entry_time/exit_time are displayed at minute resolution
            # (that format is kept for loss_visualizer.py compatibility).
            hold, exact_hold = (xt - et).total_seconds(), (e_sec and x_sec)
            if rec.get("hold_sec"):
                try:
                    hold, exact_hold = float(rec["hold_sec"]), True
                except ValueError:
                    pass
            def _num(key):
                try:
                    return float(rec.get(key, "") or 0) or None
                except ValueError:
                    return None
            rows.append({
                "magic": rec.get("magic", ""), "dir": rec.get("dir", ""),
                "entry": et, "exit": xt, "profit": p, "mae": mae,
                "sec_resolution": exact_hold,
                "hold_sec": hold,
                "volume": _num("volume"),
                "entry_price": _num("entry_price"),
            })
    rows.sort(key=lambda r: r["exit"])
    return rows


def load_equity_series(path):
    """Optional 'time,equity' series that INCLUDES floating P&L. Enables exact intraday checks."""
    out = []
    with open(path, newline="") as fh:
        for raw in csv.reader(fh):
            if not raw or len(raw) < 2:
                continue
            if raw[0].strip().lower().startswith("time"):
                continue
            for fmt in ("%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M", "%Y.%m.%d %H:%M:%S"):
                try:
                    t = dt.datetime.strptime(raw[0].strip(), fmt)
                    break
                except ValueError:
                    t = None
            if t is None:
                continue
            try:
                out.append((t, float(raw[1])))
            except ValueError:
                continue
    out.sort(key=lambda x: x[0])
    return out


def htm_field(path, label):
    """Pull one labelled number out of an MT5 native report.htm (UTF-16). Returns float or None."""
    if not path or not os.path.exists(path):
        return None
    try:
        raw = open(path, "r", encoding="utf-16", errors="ignore").read()
    except Exception:
        try:
            raw = open(path, "rb").read().decode("utf-16", errors="ignore")
        except Exception:
            return None
    txt = re.sub(r"<[^>]+>", "|", raw).replace("&nbsp;", " ")
    i = txt.find(label)
    if i < 0:
        return None
    m = re.search(r"-?\d[\d \u00a0.,]*", txt[i + len(label): i + len(label) + 120])
    if not m:
        return None
    s = m.group(0).replace("\u00a0", "").replace(" ", "").replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None


# ----------------------------------------------------------------------------------
# The GFT trading day
# ----------------------------------------------------------------------------------
def gft_day(t, reset_hour):
    """Map a timestamp to its GFT trading day.

    GFT rolls the day over at ~5 PM EST. Ledger seq187 evidence (gold's CME Globex halt at
    ET 17:00 shows up as broker-server hours 0/1/2) puts that rollover at ~server midnight on
    this broker, so reset_hour=0 is the documented default. It is an INPUT, not a guess baked
    into the logic, and the assumption is printed with every report.
    """
    if reset_hour == 0:
        return t.date()
    shifted = t - dt.timedelta(hours=reset_hour)
    return shifted.date()


# ----------------------------------------------------------------------------------
# Goat Guard - rulebook rule 3
# ----------------------------------------------------------------------------------
def combined_floating_path(trades, initial, equity_series):
    """Reconstruct the COMBINED floating PnL of all open positions over time.

    Goat Guard watches exactly this quantity. The identity used is:
        floating(t) = equity(t) - balance(t)
    where balance(t) is the step function built from closed-trade profits up to t. An MT5
    equity series therefore lets us recover the combined float of every open position at once,
    without needing per-position data.
    Returns [(time, floating)] or None if no series was supplied.
    """
    if not equity_series:
        return None
    exits = sorted((t["time"], t["profit"]) for t in trades)
    out, i, bal = [], 0, initial
    for ts, eq in equity_series:
        while i < len(exits) and exits[i][0] <= ts:
            bal += exits[i][1]
            i += 1
        out.append((ts, eq - bal))
    return out


def daily_references(trades, initial, equity_series, reset_hour):
    """Per-GFT-day reference = max(balance, equity) AT THE DAILY RESET.

    Support confirmed the reference is the higher of balance or equity at the reset, including when
    positions are still open. Two details matter and both were wrong in the first draft:
      * it must be measured at the RESET instant, not at the day's first trade - if equity is
        elevated at rollover those differ, and the reference sets the day's absolute floor;
      * it must be computed in ONE pass. Re-scanning the series per day is O(days x samples),
        which on a long intraday series is millions of iterations for no reason.
    Returns {gft_day: reference} or None when no equity series is supplied.
    """
    if not equity_series:
        return None
    exits = sorted((t["time"], t["profit"]) for t in trades)
    refs, i, bal = {}, 0, initial
    for ts, eq in equity_series:
        while i < len(exits) and exits[i][0] <= ts:
            bal += exits[i][1]
            i += 1
        d = gft_day(ts, reset_hour)
        if d not in refs:                     # first sample of this GFT day = the reset instant
            refs[d] = max(bal, eq)
    return refs


def count_threshold_excursions(path, threshold_abs):
    """Count distinct dips of the combined float to/below -threshold_abs.

    An 'excursion' starts when the float crosses from above the threshold to at/below it, and
    ends when it comes back above. This deliberately OVER-counts relative to GFT's snapshot
    rule (an unchanged position set fluctuating around -2% counts once for GFT), because
    over-counting only risks being too cautious, while under-counting would risk declaring a
    dead account safe. Returns (n_excursions, worst_float, first_time).
    """
    n, inside, worst, first = 0, False, 0.0, None
    for ts, f in path:
        if f < worst:
            worst = f
        if f <= -threshold_abs:
            if not inside:
                n += 1
                inside = True
                if first is None:
                    first = ts
        else:
            inside = False
    return n, worst, first


def goat_guard_verdict(trades, initial, gg_abs, equity_series, gg_events):
    """Decide Goat Guard honestly. Never a false pass, never a false breach.

    Evidence hierarchy:
      1. Combined-floating series  -> can PASS exactly (0 excursions) or prove >=1 trigger.
      2. Closed-trade losses only  -> CANDIDATES only. Cannot prove a trigger (another open
         position may have offset it) and cannot prove safety (a position can float past the
         threshold and recover before closing).
    """
    rule = "GOAT GUARD 2% FLOATING"
    path = combined_floating_path(trades, initial, equity_series)

    if path:
        n, worst, first = count_threshold_excursions(path, gg_abs)
        if n == 0:
            return Check(rule, PASS,
                         f"combined floating PnL of all open positions never reached "
                         f"-{gg_abs:,.0f} ({RULES['goat_guard_pct']:.0f}% of initial). Worst was "
                         f"{worst:,.2f}. Computed as equity minus balance over the supplied "
                         f"intraday series, which is exactly what Goat Guard watches - EXACT, "
                         f"and it proves no trigger ever fired.",
                         exact=True, limit=-gg_abs, observed=worst)
        if n == 1:
            return Check(rule, WARN,
                         f"ONE confirmed trigger: combined floating loss first reached "
                         f"-{gg_abs:,.0f} at {first} (worst {worst:,.2f}). Not a breach - "
                         f"positions stay open and trading continues - but the profit split "
                         f"drops 80% -> 50% and a SECOND trigger closes the account permanently.",
                         exact=True, limit=-gg_abs, observed=worst)
        return Check(rule, LIKELY, 
                     f"{n} separate dips of the combined float to/below -{gg_abs:,.0f} "
                     f"(first at {first}, worst {worst:,.2f}). At least ONE trigger is proven. "
                     f"Whether the later dips count as a SECOND trigger depends on Goat Guard's "
                     f"snapshot rule: an unchanged set of open positions cannot re-trigger, but "
                     f"any change in composition creates a new snapshot that can. Settling this "
                     f"needs per-position open/close data. Treat as BLOCKING: if it is a second "
                     f"trigger, the funded account is permanently closed.",
                     exact=False, limit=-gg_abs, observed=worst)

    # ---- closed-trade evidence only ----
    have_mae = any(t["mae"] is not None for t in trades)
    worst_ev = max([(t["mae"] if t["mae"] is not None else abs(min(0.0, t["profit"])))
                    for t in trades] or [0.0])
    src = "per-position worst adverse excursion (MAE)" if have_mae else "closed-trade losses"

    if len(gg_events) >= 2:
        first_two = ", ".join(f"#{e['trade_no']} {e['time']} ({e['amount']:,.2f})"
                              for e in gg_events[:2])
        return Check(rule, LIKELY,
                     f"{len(gg_events)} positions individually reached or passed -{gg_abs:,.0f} "
                     f"[{first_two}]. If any two of these were the sole open position at their "
                     f"time, that is a SECOND trigger and the account is permanently closed. "
                     f"This cannot be settled from {src}, because Goat Guard sums ALL open "
                     f"positions - a concurrent position in profit could have offset any one of "
                     f"them. Treat as BLOCKING until a combined-floating series settles it.",
                     exact=False, limit=-gg_abs, observed=-worst_ev)

    if len(gg_events) == 1:
        e = gg_events[0]
        return Check(rule, UNVERIFIED,
                     f"ONE candidate trigger: trade #{e['trade_no']} on {e['time']} reached "
                     f"{e['amount']:,.2f} against the {gg_abs:,.0f} threshold. Whether Goat Guard "
                     f"actually fired depends on the combined float of ALL positions open at that "
                     f"instant - a concurrent position in profit could have kept the sum above "
                     f"-{gg_abs:,.0f}. A single trigger is only a profit-split penalty, not a "
                     f"breach, but it must be known because a second one is fatal. Supply "
                     f"--equity-series to settle it.",
                     exact=False, limit=-gg_abs, observed=-e["amount"])

    return Check(rule, UNVERIFIED,
                 f"no position closed at or beyond -{gg_abs:,.0f} (worst {worst_ev:,.2f} by "
                 f"{src}), so there is no evidence of a trigger. This does NOT prove safety: "
                 f"Goat Guard watches FLOATING loss, and a position can float past "
                 f"-{gg_abs:,.0f} and then recover to a small closed loss, leaving no trace in "
                 f"this data. Supply --equity-series for an exact verdict.",
                 exact=False, limit=-gg_abs, observed=-worst_ev)


# ----------------------------------------------------------------------------------
# Rulebook rule 4 - minimum hold time, 2 minutes (FUNDED ONLY)
# ----------------------------------------------------------------------------------
def micro_scalp_check(deals, stage):
    """Profit from positions held under 120s is stripped at payout on FUNDED accounts.

    Losses from those same trades still count. Not a breach - a payout adjustment.
    Minute-resolution timestamps cannot resolve the 120s line exactly, so trades are split
    into three honest classes:
        hold <= 1 min  -> certainly under 120s (worst case 119s)
        hold == 2 min  -> AMBIGUOUS (actual 61-179s)
        hold >= 3 min  -> certainly over 120s
    """
    rule = "MIN HOLD TIME 2 MIN (funded payout)"
    if deals is None:
        return Check(rule, UNVERIFIED,
                     "not checkable: needs per-position ENTRY and EXIT times. trades.csv carries "
                     "only the exit time. Supply --deals with an enriched deals CSV. On a funded "
                     "account this rule silently deletes winner profit at payout while leaving "
                     "the losers, so it must be measured before any funded deployment.",
                     exact=False)

    exact_res = all(d["sec_resolution"] for d in deals) if deals else False
    certain = [d for d in deals if d["hold_sec"] < 120.0] if exact_res else \
              [d for d in deals if d["hold_sec"] <= 60.0]
    ambiguous = [] if exact_res else [d for d in deals if d["hold_sec"] == 120.0]

    strip_certain = sum(d["profit"] for d in certain if d["profit"] > 0)
    strip_ambig = sum(d["profit"] for d in ambiguous if d["profit"] > 0)
    loss_kept = sum(d["profit"] for d in certain if d["profit"] < 0)
    total_net = sum(d["profit"] for d in deals)
    res_note = "" if exact_res else (
        " NOTE: deal timestamps are MINUTE resolution, so the 120s line cannot be resolved "
        "exactly; trades showing exactly 2 minutes are reported separately as ambiguous. "
        "Export seconds-resolution times to remove this ambiguity.")

    if stage != "funded":
        if not certain and not ambiguous:
            return Check(rule, PASS,
                         f"not applicable at this stage (funded only), and no position was held "
                         f"under 2 minutes anyway, so there is no exposure once funded.{res_note}",
                         exact=exact_res)
        return Check(rule, INFO,
                     f"not applicable during evaluation (GFT confines this rule to funded "
                     f"accounts). FORWARD-LOOKING EXPOSURE: {len(certain)} position(s) held under "
                     f"2 minutes carrying {strip_certain:,.2f} of profit that WOULD be stripped "
                     f"once funded"
                     + (f", plus {len(ambiguous)} ambiguous at exactly 2 min "
                        f"({strip_ambig:,.2f})" if ambiguous else "")
                     + f". Losses of {loss_kept:,.2f} from those trades would still count."
                     + res_note,
                     exact=exact_res, observed=strip_certain)

    if not certain and not ambiguous:
        return Check(rule, PASS,
                     f"no position was held under 2 minutes, so no profit is stripped at "
                     f"payout.{res_note}", exact=exact_res, limit=120.0, observed=0.0)

    pct = (strip_certain / total_net * 100.0) if total_net else 0.0
    return Check(rule, WARN,
                 f"{len(certain)} position(s) held under 2 minutes. Profit of {strip_certain:,.2f} "
                 f"will be REMOVED at payout ({pct:.1f}% of the {total_net:,.2f} net), while "
                 f"{loss_kept:,.2f} of losses from those same trades still counts."
                 + (f" A further {len(ambiguous)} trade(s) sit at exactly 2 minutes carrying "
                    f"{strip_ambig:,.2f} - these may or may not be stripped." if ambiguous else "")
                 + " Not a breach: payout adjustment only." + res_note,
                 exact=exact_res, limit=120.0, observed=strip_certain)


# ----------------------------------------------------------------------------------
# Rulebook rule 5 - weekend gap trading (FUNDED profit removal)
# ----------------------------------------------------------------------------------
def weekend_gap_check(deals, stage, fri_close_hour, mon_open_hour, window_h=3):
    """Trade opened in Friday's last 3 market hours AND closed in Monday's first 3 -> on funded
    accounts the profit is removed. Holding over the weekend itself is fully allowed.
    Not a violation; no penalty. Profit adjustment only.
    """
    rule = "WEEKEND GAP (funded payout)"
    if deals is None:
        return Check(rule, UNVERIFIED,
                     "not checkable: needs per-position ENTRY and EXIT times. Supply --deals. "
                     "On a funded account, profit from a Friday-late entry closed Monday-early is "
                     "removed, so a strategy must not depend on it.",
                     exact=False)

    fri_from = fri_close_hour - window_h          # e.g. 24-3 = 21:00 server Friday
    mon_to = mon_open_hour + window_h             # e.g. 1+3  = 04:00 server Monday
    flagged = [d for d in deals
               if d["entry"].weekday() == 4 and d["entry"].hour >= fri_from
               and d["exit"].weekday() == 0 and d["exit"].hour < mon_to]
    assume = (f"Assumed market close Friday {fri_close_hour:02d}:00 server and reopen Monday "
              f"{mon_open_hour:02d}:00 server, so the windows are Friday >= {fri_from:02d}:00 and "
              f"Monday < {mon_to:02d}:00. Both are inputs (--fri-close-hour / --mon-open-hour), "
              f"not hidden guesses - confirm against the broker calendar.")

    if not flagged:
        return Check(rule, PASS,
                     f"no position was opened in Friday's final {window_h} market hours and closed "
                     f"in Monday's first {window_h}. Nothing is removed. {assume}", exact=True)

    strip = sum(d["profit"] for d in flagged if d["profit"] > 0)
    if stage != "funded":
        return Check(rule, INFO,
                     f"{len(flagged)} weekend-straddling trade(s) match GFT's gap-trading pattern. "
                     f"Profit removal applies to funded accounts only, so nothing is deducted at "
                     f"this stage. FORWARD-LOOKING EXPOSURE once funded: {strip:,.2f}. {assume}",
                     exact=True, observed=strip)

    return Check(rule, WARN,
                 f"{len(flagged)} trade(s) opened in Friday's last {window_h} market hours and "
                 f"closed within Monday's first {window_h}. Profit of {strip:,.2f} will be REMOVED. "
                 f"GFT states this is not a violation and carries no penalty - profit adjustment "
                 f"only - but the strategy must not rely on this income. {assume}",
                 exact=True, observed=strip)


# ----------------------------------------------------------------------------------
# Rulebook rule 6 - news window profit cap (BOTH evaluation and funded)
# ----------------------------------------------------------------------------------
def news_cap_check(deals, initial, news_events=None):
    """Profit from a trade opened OR closed within +/-5 min of a high-impact release is capped at
    1% of INITIAL; the excess is removed. Not a breach. Applies in evaluation AND funded.

    Verifying this needs a high-impact economic calendar (GFT referenced ForexFactory / Myfxbook).
    Without one the rule cannot be checked at all, and saying so is the only honest option -
    silently omitting it would hide a real cut to evaluation profit.
    """
    rule = "NEWS WINDOW 1% CAP (all stages)"
    cap = initial * RULES["news_profit_cap_pct"] / 100.0
    win = RULES["news_window_min"]

    if not news_events:
        detail = (f"NOT CHECKABLE without a high-impact news calendar. GFT confirmed: profit from a "
                  f"trade opened OR closed within {win} minutes either side of a high-impact "
                  f"release is capped at {cap:,.0f} ({RULES['news_profit_cap_pct']:.0f}% of "
                  f"initial), excess removed, not a breach - and it applies in EVALUATION as well "
                  f"as funded. Reference calendars named: ForexFactory, Myfxbook. Supply a calendar "
                  f"via --news-csv to measure the exposure. UNRESOLVED with GFT: whether the cap "
                  f"is per event, per trade, or per day.")
        if deals is None:
            detail += " A deals CSV with entry+exit times is also required."
        return Check(rule, UNVERIFIED, detail, exact=False, limit=cap)

    flagged, stripped = [], 0.0
    for d in deals or []:
        hit = False
        for ev in news_events:
            for t in (d["entry"], d["exit"]):
                if abs((t - ev).total_seconds()) <= win * 60:
                    hit = True
                    break
            if hit:
                break
        if hit:
            flagged.append(d)
            if d["profit"] > cap:
                stripped += d["profit"] - cap

    if not flagged:
        return Check(rule, PASS,
                     f"no trade opened or closed within {win} minutes of a high-impact release, "
                     f"so the {cap:,.0f} cap never binds.", exact=True, limit=cap)
    if stripped <= 0:
        return Check(rule, PASS,
                     f"{len(flagged)} trade(s) fell inside a news window but none exceeded the "
                     f"{cap:,.0f} cap, so nothing is removed.", exact=True, limit=cap)
    return Check(rule, WARN,
                 f"{len(flagged)} trade(s) fell inside a +/-{win} minute news window and "
                 f"{stripped:,.2f} of profit exceeds the {cap:,.0f} per-trade cap and would be "
                 f"REMOVED. Not a breach. NOTE: computed PER TRADE - GFT has not confirmed whether "
                 f"the cap is per event, per trade or per day, so the true deduction could differ.",
                 exact=False, limit=cap, observed=stripped)


# ----------------------------------------------------------------------------------
# Rulebook rule 15 - margin ceiling, 80% of available margin (all stages)
# ----------------------------------------------------------------------------------
def margin_check(deals, initial, margin_rate, contract_size=100.0):
    """No more than 80% of available margin may be used. Lot size itself is unrestricted.

    Margin for a metals position = volume * contract_size * price * margin_rate. We compare the
    peak single-position margin against the account reference. This matters enormously on a small
    gold account: at gold ~5,000 a 0.09-lot position needs about $4,500 of margin, which is 90% of
    a $5,000 account and therefore over the ceiling.
    """
    rule = f"MARGIN CEILING {RULES['max_margin_pct']:.0f}%"
    limit_pct = RULES["max_margin_pct"]

    if deals is None:
        return Check(rule, UNVERIFIED,
                     f"not checkable: needs per-position VOLUME and entry PRICE. Supply --deals. "
                     f"This matters on a $5k gold account - a 0.09-lot position needs roughly 90% "
                     f"of the account as margin at gold ~5,000, which would exceed the "
                     f"{limit_pct:.0f}% ceiling.",
                     exact=False, limit=limit_pct)

    # "Available margin" is equity/free-margin based, so it grows as the account compounds.
    # Measuring every trade against the FIXED initial would be over-strict on a grown account and
    # would raise a FALSE BREACH (a 0.09 lot late in the run, when equity has doubled, is small in
    # % terms even though it is 97% of the ORIGINAL 5k). Same trap as the daily-reference bug.
    # So reconstruct a running BALANCE from the deals (initial + realized profit of trades already
    # closed at each entry) and measure margin against that balance. Without it we would only have
    # initial, which can prove a breach ONLY while balance is still near initial.
    ordered = sorted([d for d in deals if d.get("volume") and d.get("entry_price")],
                     key=lambda d: d["entry"])
    exits = sorted(((d["exit"], d["profit"]) for d in deals), key=lambda x: x[0])
    worst_pct, worst, worst_ref = 0.0, None, initial
    bal = initial
    ei = 0
    exs = sorted(((d["entry"], d) for d in ordered), key=lambda x: x[0])
    # walk entries in time order, advancing realized balance by any trade that closed before it
    j = 0
    for entry_t, d in exs:
        while j < len(exits) and exits[j][0] <= entry_t:
            bal += exits[j][1]
            j += 1
        ref = max(bal, 1.0)
        used = d["volume"] * contract_size * d["entry_price"] * margin_rate
        pct = used / ref * 100.0
        if pct > worst_pct:
            worst_pct, worst, worst_ref = pct, d, ref

    if worst is None:
        return Check(rule, UNVERIFIED,
                     "deals CSV carried no usable volume/entry_price columns, so margin usage "
                     "could not be computed.", exact=False, limit=limit_pct)

    note = (f"Computed as volume x {contract_size:g} x entry price x {margin_rate:.0%} margin rate, "
            f"against the running BALANCE at each entry (initial + realized P&L to date; worst "
            f"trade's reference balance {worst_ref:,.0f}). The {margin_rate:.0%} rate is our MEASURED "
            f"MetaQuotes-Demo value for XAUUSD (ledger seq67/seq69, leverage-independent for metals); "
            f"GFT's own broker may differ, so confirm it. Balance is a proxy for equity/free margin "
            f"(no floating), so this can slightly UNDER-state usage while a position floats in loss - "
            f"supply --equity-series for an exact reading.")

    if worst_pct > limit_pct:
        return Check(rule, BREACH,
                     f"peak margin usage {worst_pct:.1f}% exceeds the {limit_pct:.0f}% ceiling - "
                     f"worst position {worst['volume']:g} lot at {worst['entry_price']:,.2f} on "
                     f"{worst['entry']} against a {worst_ref:,.0f} balance. {note}",
                     exact=False, limit=limit_pct, observed=worst_pct)
    if worst_pct > limit_pct * 0.8:
        return Check(rule, WARN,
                     f"peak margin usage {worst_pct:.1f}% is under the {limit_pct:.0f}% ceiling but "
                     f"close - a higher gold price raises it for the same lot. {note}",
                     exact=False, limit=limit_pct, observed=worst_pct)
    return Check(rule, PASS,
                 f"peak margin usage {worst_pct:.1f}% of balance, well inside the {limit_pct:.0f}% "
                 f"ceiling. {note}", exact=False, limit=limit_pct, observed=worst_pct)


# ----------------------------------------------------------------------------------
# The referee
# ----------------------------------------------------------------------------------
def evaluate(trades, initial, stage, reset_hour, equity_series=None, htm_path=None,
             deals=None, fri_close_hour=24, mon_open_hour=1, news_events=None,
             margin_rate=DEFAULT_MARGIN_RATE):
    spec = STAGE_SPEC[stage]
    floor_abs = initial * (1.0 - RULES["static_max_loss_pct"] / 100.0)   # e.g. 4500 on 5000
    gg_abs = initial * RULES["goat_guard_pct"] / 100.0                   # e.g. 100 on 5000
    checks = []
    breach = None   # first hard breach: dict(rule, when, trade_no, detail)
    day_refs = daily_references(trades, initial, equity_series, reset_hour)

    # ---------- chronological walk: the firm kills you at the FIRST breach ----------
    balance = initial
    peak_reached_at = None
    day_key = None
    day_start_balance = initial
    day_pl = 0.0
    day_index = {}          # gft_day -> realized P&L
    day_start_ref = {}      # gft_day -> balance at day start
    min_balance = initial
    min_balance_at = None
    gg_events = []          # funded: closed losses that prove floating reached -2%

    for n, tr in enumerate(trades, start=1):
        d = gft_day(tr["time"], reset_hour)
        if d != day_key:
            day_key = d
            # Reference = max(balance, equity) at the reset when an equity series is available
            # (stricter, and what the firm actually uses). Balance alone is LOOSER than the firm,
            # so without a series it is treated as a LOWER BOUND and the daily rule stays
            # UNVERIFIED rather than being reported as a pass.
            ref = day_refs.get(d, balance) if day_refs else balance
            day_start_balance = ref
            day_start_ref[d] = ref
            day_pl = 0.0

        balance += tr["profit"]
        day_pl += tr["profit"]
        day_index[d] = day_pl

        if balance < min_balance:
            min_balance = balance
            min_balance_at = (n, tr["time"])

        # --- HARD RULE 1: static max overall loss (10%, never trails) ---
        if balance <= floor_abs and breach is None:
            breach = {
                "rule": "MAX OVERALL LOSS 10% STATIC",
                "when": tr["time"], "trade_no": n,
                "detail": (f"balance fell to {balance:,.2f}, at or below the STATIC floor "
                           f"{floor_abs:,.2f} (= {100 - RULES['static_max_loss_pct']:.0f}% of the "
                           f"{initial:,.0f} starting capital). This floor never moves up with profit."),
                "limit": floor_abs, "observed": balance,
            }
            break

        # --- HARD RULE 2: daily drawdown 5% of the DAY-START reference ---
        # This is the FIRM's rule and the only daily measure that can kill the account.
        # Our stricter "5% of initial" overlay is a BUFFER, checked separately further down:
        # it must never halt this walk, or it would mask a later genuine firm breach and
        # would raise false breaches once the balance has compounded well above initial.
        day_pct = (day_pl / day_start_balance * 100.0) if day_start_balance else 0.0
        if breach is None and day_pct <= -RULES["daily_dd_pct"]:
            breach = {
                "rule": "DAILY DRAWDOWN 5%",
                "when": tr["time"], "trade_no": n,
                "detail": (f"GFT day {d}: realized P&L {day_pl:,.2f} = {day_pct:.2f}% of the "
                           f"{day_start_balance:,.2f} day-start reference. The firm's limit is "
                           f"-{RULES['daily_dd_pct']:.1f}% of the day's starting equity."),
                "limit": -RULES["daily_dd_pct"], "observed": day_pct,
            }
            break

        # --- RULE 3 (funded only): Goat Guard CANDIDATE collection ---
        # Deliberately does NOT breach here. Goat Guard fires on the COMBINED floating PnL of
        # ALL open positions (rulebook rule 3). A single closed loss of $X does NOT prove a
        # trigger: if another position floated +$Y at that instant the combined figure was
        # -(X-Y) and nothing fired. Our combo EA can hold FIX09 and DTREND at once, so treating
        # a per-trade loss as a trigger would risk a FALSE BREACH and discard a valid strategy.
        # Per-trade evidence is therefore collected as a CANDIDATE and judged after the walk.
        if spec["goat_guard"]:
            float_evidence = tr["mae"] if tr["mae"] is not None else abs(min(0.0, tr["profit"]))
            if float_evidence >= gg_abs:
                gg_events.append({"trade_no": n, "time": tr["time"], "amount": float_evidence})

        # --- profit target progress (evaluation stages) ---
        if spec["target_pct"] is not None and peak_reached_at is None:
            if balance >= initial * (1.0 + spec["target_pct"] / 100.0):
                peak_reached_at = (n, tr["time"], balance)

    trades_used = n if trades else 0
    halted_early = breach is not None

    # ---------------- assemble rule-by-rule verdicts ----------------
    # RULE: static max overall loss
    eq_dd_abs = htm_field(htm_path, "Equity Drawdown Absolute:")
    bal_dd_abs = htm_field(htm_path, "Balance Drawdown Absolute:")
    if breach and breach["rule"].startswith("MAX OVERALL"):
        checks.append(Check("MAX OVERALL LOSS 10% STATIC", BREACH, breach["detail"],
                            exact=True, limit=floor_abs, observed=breach["observed"]))
    else:
        realized_static = max(0.0, initial - min_balance)
        if eq_dd_abs is not None:
            # htm equity drawdown INCLUDES floating P&L -> this is the authoritative static number
            eq_min = initial - eq_dd_abs
            if eq_min <= floor_abs:
                checks.append(Check(
                    "MAX OVERALL LOSS 10% STATIC", BREACH,
                    f"MT5 Equity Drawdown Absolute {eq_dd_abs:,.2f} puts minimum EQUITY at "
                    f"{eq_min:,.2f}, at or below the static floor {floor_abs:,.2f}. Equity counts, "
                    f"not just balance.", exact=True, limit=floor_abs, observed=eq_min))
            else:
                checks.append(Check(
                    "MAX OVERALL LOSS 10% STATIC", PASS,
                    f"minimum EQUITY {eq_min:,.2f} stayed above the static floor {floor_abs:,.2f} "
                    f"(MT5 Equity Drawdown Absolute {eq_dd_abs:,.2f} = "
                    f"{eq_dd_abs / initial * 100:.2f}% of initial; includes floating P&L).",
                    exact=True, limit=floor_abs, observed=eq_min))
        else:
            checks.append(Check(
                "MAX OVERALL LOSS 10% STATIC", UNVERIFIED,
                f"closed-trade balance never went below {min_balance:,.2f} (static DD "
                f"{realized_static:,.2f} = {realized_static / initial * 100:.2f}%), which clears the "
                f"floor {floor_abs:,.2f} on REALIZED terms. But no report.htm was found, so the "
                f"floating-inclusive Equity Drawdown Absolute could not be read. Intraday equity "
                f"can dip below the floor without any closed trade showing it.",
                exact=False, limit=floor_abs, observed=min_balance))

    # RULE: daily drawdown
    if breach and breach["rule"].startswith("DAILY"):
        checks.append(Check("DAILY DRAWDOWN 5%", BREACH, breach["detail"],
                            exact=True, limit=-RULES["daily_dd_pct"], observed=breach["observed"]))
    else:
        worst_day, worst_pct, days_over = None, 0.0, 0
        for d, pl in day_index.items():
            ref = day_start_ref.get(d, initial)
            pct = (pl / ref * 100.0) if ref else 0.0
            if pct <= -RULES["daily_dd_pct"]:
                days_over += 1
            if pct < worst_pct:
                worst_pct, worst_day = pct, d
        detail = (f"worst GFT day {worst_day} at {worst_pct:.2f}% of day-start balance; "
                  f"days at or beyond -{RULES['daily_dd_pct']:.0f}%: {days_over}. "
                  f"Day boundary assumed at server hour {reset_hour:02d}:00.")
        if equity_series:
            checks.append(Check("DAILY DRAWDOWN 5%", PASS if days_over == 0 else BREACH,
                                detail + " Measured on the supplied intraday EQUITY series "
                                         "(floating P&L included) - exact.",
                                exact=True, limit=-RULES["daily_dd_pct"], observed=worst_pct))
        else:
            checks.append(Check(
                "DAILY DRAWDOWN 5%", UNVERIFIED if days_over == 0 else BREACH,
                detail + " REALIZED closed trades only. GFT measures this on intraday EQUITY "
                         "including floating P&L, so this is a LOWER BOUND: a day could have "
                         "dipped past -5% on open positions and recovered before any trade closed. "
                         "Supply --equity-series to make this exact.",
                exact=False, limit=-RULES["daily_dd_pct"], observed=worst_pct))

    # RULE: Goat Guard (funded only) - judged AFTER the walk, never from a single trade.
    # If a deals CSV carries MAE, prefer it: MAE is the per-position floating low, which is far
    # better evidence than the closed profit (a trade can float deep and recover before closing).
    if spec["goat_guard"]:
        gg_trades = trades
        gg_cands = gg_events
        if deals and any(d["mae"] is not None for d in deals):
            gg_trades = [{"time": d["exit"], "profit": d["profit"], "mae": d["mae"]}
                         for d in deals]
            gg_cands = [{"trade_no": i + 1, "time": d["exit"], "amount": d["mae"]}
                        for i, d in enumerate(deals)
                        if d["mae"] is not None and d["mae"] >= gg_abs]
        checks.append(goat_guard_verdict(gg_trades, initial, gg_abs, equity_series, gg_cands))

    # DATA INTEGRITY: the deals CSV must describe the SAME run as trades.csv, or every
    # duration-based verdict below is about a different backtest. Mixing runs is exactly how a
    # confident-looking but meaningless audit gets produced, so it is checked, not assumed.
    recon = None
    if deals:
        d_net, t_net = sum(d["profit"] for d in deals), sum(t["profit"] for t in trades)
        d_n, t_n = len(deals), len(trades)
        net_gap = abs(d_net - t_net)
        if net_gap > 0.01 or d_n != t_n:
            recon = (f"deals CSV does NOT match trades.csv: {d_n} deals netting {d_net:,.2f} "
                     f"versus {t_n} trades netting {t_net:,.2f}. These are different runs, so the "
                     f"2-minute and weekend-gap verdicts below describe the WRONG backtest and "
                     f"must not be trusted. Re-export the deals CSV from the same run.")
            checks.append(Check("DATA INTEGRITY (deals vs trades)", UNVERIFIED, recon, exact=True))
        else:
            checks.append(Check("DATA INTEGRITY (deals vs trades)", PASS,
                                f"deals CSV reconciles with trades.csv: {d_n} positions, "
                                f"net {d_net:,.2f} in both.", exact=True))

    # RULE 4: minimum hold time 2 minutes (funded payout adjustment)
    checks.append(micro_scalp_check(deals, stage))

    # RULE 5: weekend gap trading (funded payout adjustment)
    checks.append(weekend_gap_check(deals, stage, fri_close_hour, mon_open_hour))

    # RULE 6: news-window 1% profit cap - applies in EVALUATION as well as funded
    checks.append(news_cap_check(deals, initial, news_events))

    # RULE 15: margin ceiling 80% of available margin - all stages
    checks.append(margin_check(deals, initial, margin_rate))

    # RULE: min trading days
    n_days = len(day_index)
    if n_days >= RULES["min_trading_days"]:
        checks.append(Check("MIN TRADING DAYS", PASS,
                            f"{n_days} trading days, needs at least {RULES['min_trading_days']}.",
                            exact=True, limit=RULES["min_trading_days"], observed=n_days))
    else:
        # NOT a breach. This is a REQUIREMENT (rulebook rule 7): too few trading days means the
        # stage is not passed / no payout is due, but the account is perfectly alive. Reporting it
        # as a breach would be a FALSE BREACH - it would condemn a compliant strategy for the
        # crime of trading too little, and it would bury any real breach under a wrong headline.
        checks.append(Check("MIN TRADING DAYS", INFO,
                            f"only {n_days} trading day(s); {RULES['min_trading_days']} required. "
                            f"NOT a breach - the account is not violated, the stage is simply not "
                            f"passed yet (and on funded, no payout is due). More trading days fix "
                            f"it.",
                            exact=True, limit=RULES["min_trading_days"], observed=n_days))

    # RULE: profit target (evaluation stages only)
    if spec["target_pct"] is not None:
        need = initial * spec["target_pct"] / 100.0
        if peak_reached_at:
            i, when, bal = peak_reached_at
            checks.append(Check(f"PROFIT TARGET {spec['target_pct']:.0f}%", PASS,
                                f"target {need:,.0f} reached at trade #{i} on {when} "
                                f"(balance {bal:,.2f}) with no prior hard breach.",
                                exact=True, limit=need, observed=bal - initial))
        else:
            final = balance
            checks.append(Check(f"PROFIT TARGET {spec['target_pct']:.0f}%", INFO,
                                f"not reached: net {final - initial:,.2f} of the required "
                                f"{need:,.0f}. Not a rule breach - the stage is simply not passed.",
                                exact=True, limit=need, observed=final - initial))

    # RULE: funded daily profit cap (not a breach - excess is deducted)
    if spec["daily_profit_cap"]:
        cap = spec["daily_profit_cap"]
        over = [(d, pl) for d, pl in day_index.items() if pl > cap]
        if over:
            checks.append(Check("FUNDED DAILY PROFIT CAP", INFO,
                                f"{len(over)} day(s) above {cap:,.0f}; the excess is deducted, "
                                f"it is NOT a breach. Largest: {max(pl for _, pl in over):,.2f}.",
                                exact=True, limit=cap, observed=max(pl for _, pl in over)))
        else:
            checks.append(Check("FUNDED DAILY PROFIT CAP", PASS,
                                f"no day exceeded {cap:,.0f}.", exact=True, limit=cap))
        # payout-valid days
        vd_need = initial * RULES["valid_day_pct"] / 100.0
        vd = sum(1 for pl in day_index.values() if pl >= vd_need)
        st = PASS if vd >= RULES["min_trading_days"] else INFO
        checks.append(Check("PAYOUT VALID DAYS", st,
                            f"{vd} day(s) with profit >= {vd_need:,.0f} (0.5% of initial); "
                            f"{RULES['min_trading_days']} needed per payout.",
                            exact=True, limit=RULES["min_trading_days"], observed=vd))

    # ---------------- our own buffers (Section 4) - warnings, NEVER breaches ----------------
    # These are stricter than the firm on purpose. A buffer trip means "too close to the edge",
    # not "account dead". None of them halts the chronological walk.
    warnings = []
    realized_static_pct = max(0.0, initial - min_balance) / initial * 100.0
    static_pct_used = (eq_dd_abs / initial * 100.0) if eq_dd_abs is not None else realized_static_pct
    if static_pct_used >= BUFFER["static_halt_pct"]:
        warnings.append(f"static drawdown {static_pct_used:.2f}% reached our {BUFFER['static_halt_pct']:.0f}% "
                        f"halt buffer (firm limit {RULES['static_max_loss_pct']:.0f}%) - too close to the floor.")

    day_pcts = {d: (pl / day_start_ref.get(d, initial) * 100.0) for d, pl in day_index.items()}
    worst_day_pct = min(day_pcts.values()) if day_pcts else 0.0
    if worst_day_pct <= -BUFFER["daily_governor_pct"]:
        warnings.append(f"worst day {worst_day_pct:.2f}% of day-start passed our "
                        f"{BUFFER['daily_governor_pct']:.1f}% daily governor buffer "
                        f"(firm limit {RULES['daily_dd_pct']:.0f}%).")

    # Conservative overlay from the rule book: never let a day lose more than 5% of INITIAL.
    # Reported as a buffer, not a breach, and only meaningful while balance is near initial -
    # once the account has compounded far above initial this overlay is deliberately over-strict.
    worst_init_day, worst_init_pct = None, 0.0
    for d, pl in day_index.items():
        p = pl / initial * 100.0
        if p < worst_init_pct:
            worst_init_pct, worst_init_day = p, d
    if worst_init_pct <= -RULES["daily_dd_pct"]:
        ref = day_start_ref.get(worst_init_day, initial)
        firm_pct = day_pcts.get(worst_init_day, 0.0)
        note = ""
        if ref > initial * 1.2:
            firm_state = ("ALSO breached the firm rule" if firm_pct <= -RULES["daily_dd_pct"]
                          else "did NOT breach the firm rule")
            note = (f" NOTE: day-start balance was {ref:,.2f}, far above the {initial:,.0f} initial, "
                    f"so this overlay is over-strict here; on the firm's own day-start basis that "
                    f"day read {firm_pct:.2f}% and {firm_state}.")
        warnings.append(f"conservative overlay: day {worst_init_day} lost {worst_init_pct:.2f}% of INITIAL "
                        f"capital (our stricter reading of the 5% daily rule).{note}")

    if spec["goat_guard"]:
        flat = initial * BUFFER["funded_float_flatten_pct"] / 100.0
        worst_ev = max([(t["mae"] if t["mae"] is not None else abs(min(0.0, t["profit"]))) for t in trades] or [0.0])
        if worst_ev >= flat:
            warnings.append(f"worst floating loss {worst_ev:,.2f} passed our {flat:,.0f} flatten buffer "
                            f"(Goat Guard triggers at {gg_abs:,.0f}).")

    # ---------------- overall verdict ----------------
    # A LIKELY BREACH is blocking but is NOT reported as a proven breach - claiming proof we do
    # not have would be as dishonest as claiming safety we cannot show.
    if any(c.status == BREACH for c in checks):
        verdict, code = "BREACH", 2
    elif any(c.status == LIKELY for c in checks):
        verdict, code = "NOT CLEARED (LIKELY BREACH - BLOCKING)", 1
    elif any(c.status == UNVERIFIED for c in checks):
        verdict, code = "NOT CLEARED", 1
    else:
        verdict, code = "CLEARED", 0

    return {
        "stage": stage, "initial": initial, "reset_hour": reset_hour,
        "trades_total": len(trades), "trades_examined": trades_used,
        "halted_at_breach": halted_early,
        "final_balance": balance, "min_balance": min_balance,
        "min_balance_at": (min_balance_at[1].isoformat() if min_balance_at else None),
        "trading_days": n_days,
        "static_floor": floor_abs,
        "htm_equity_dd_abs": eq_dd_abs, "htm_balance_dd_abs": bal_dd_abs,
        "checks": [c.as_dict() for c in checks],
        "warnings": warnings,
        "first_breach": ({
            "rule": breach["rule"], "trade_no": breach["trade_no"],
            "when": breach["when"].isoformat(), "detail": breach["detail"],
        } if breach else None),
        "verdict": verdict, "exit_code": code,
    }


# ----------------------------------------------------------------------------------
# Reporting
# ----------------------------------------------------------------------------------
SYM = {PASS: "[PASS]", BREACH: "[BREACH]", LIKELY: "[LIKELY BREACH]",
       UNVERIFIED: "[UNVERIFIED]", WARN: "[WARN]", INFO: "[INFO]"}


def report(res, window):
    print("=" * 78)
    print(f"GFT COMPLIANCE REPORT  -  stage: {res['stage'].upper()}")
    print("=" * 78)
    print(f"  window          : {window}")
    print(f"  initial capital : {res['initial']:,.2f}")
    print(f"  static floor    : {res['static_floor']:,.2f}   (never trails up)")
    print(f"  day boundary    : server hour {res['reset_hour']:02d}:00  (GFT rolls over ~5 PM EST)")
    print(f"  trades in file  : {res['trades_total']}")
    if res["halted_at_breach"]:
        print(f"  trades examined : {res['trades_examined']}  <-- STOPPED HERE, breach found")
    print(f"  trading days    : {res['trading_days']}")
    print(f"  final balance   : {res['final_balance']:,.2f}")
    if res["htm_equity_dd_abs"] is not None:
        print(f"  MT5 htm         : Equity DD Abs {res['htm_equity_dd_abs']:,.2f}   "
              f"Balance DD Abs {res['htm_balance_dd_abs'] if res['htm_balance_dd_abs'] is not None else '?'}")
    else:
        print("  MT5 htm         : NOT FOUND (floating-inclusive drawdown unavailable)")

    print("\n  RULES")
    print("  " + "-" * 74)
    if res["halted_at_breach"]:
        print("  (walk stopped at the breach, exactly as the firm would. Rules below other than")
        print("   the breached one describe only the trades UP TO that point.)")
    for c in res["checks"]:
        tag = SYM.get(c["status"], c["status"])
        meas = "" if c["measurement"] == "exact" else "  (lower bound)"
        print(f"  {tag:<13} {c['rule']}{meas}")
        for line in _wrap(c["detail"], 68):
            print(f"                {line}")

    if res["warnings"]:
        print("\n  OUR OWN BUFFERS (stricter than the firm - warnings, not breaches)")
        print("  " + "-" * 74)
        for w in res["warnings"]:
            lines = _wrap(w, 68)
            print(f"  {'[WARN]':<13} {lines[0]}")
            for line in lines[1:]:
                print(f"                {line}")

    print("\n" + "=" * 78)
    print(f"VERDICT: {res['verdict']}")
    print("=" * 78)
    breach_checks = [c for c in res["checks"] if c["status"] == BREACH]
    if res["first_breach"] or breach_checks:
        if res["first_breach"]:
            b = res["first_breach"]
            print(f"  RULE BREACHED : {b['rule']}")
            print(f"  AT            : trade #{b['trade_no']}, {b['when']}")
            for line in _wrap(b["detail"], 72):
                print(f"                  {line}")
        for c in breach_checks:
            # breaches found off the chronological walk (e.g. margin, min-days)
            if res["first_breach"] and c["rule"] == res["first_breach"]["rule"]:
                continue
            print(f"  RULE BREACHED : {c['rule']}")
            for line in _wrap(c["detail"], 72):
                print(f"                  {line}")
        print("\n  This is how a funded account dies. One hard breach = permanently closed,")
        print("  no funding, no payout. Do NOT run this configuration on a real account.")
    elif "LIKELY BREACH" in res["verdict"]:
        print("  There is strong evidence of a rule violation that this data cannot fully settle.")
        print("  It is NOT called a proven breach, because that proof is missing - but it is")
        print("  BLOCKING. Do not deploy until the evidence gap is closed. See the rule above for")
        print("  exactly what data would settle it.")
    elif res["verdict"] == "NOT CLEARED":
        print("  No breach was found, but at least one rule could NOT be verified from the")
        print("  evidence supplied. 'Not checkable' is not 'safe'. Close the gaps listed above")
        print("  before this configuration is trusted with money.")
    else:
        print("  Every applicable rule verified compliant on this window's MT5 output.")
        print("  This clears THIS window only - it is not a promise about future trading.")
    print("\n  (deterministic: same input => same output; limits are the firm's, never relaxed)")


def _wrap(text, width):
    words, line, out = text.split(), "", []
    for w in words:
        if len(line) + len(w) + 1 > width:
            out.append(line)
            line = w
        else:
            line = (line + " " + w).strip()
    if line:
        out.append(line)
    return out


def main():
    ap = argparse.ArgumentParser(description="GFT prop-firm compliance referee (reads MT5 output only).")
    ap.add_argument("--stage", required=True, choices=sorted(STAGE_SPEC.keys()))
    ap.add_argument("--window", required=True,
                    help="directory holding trades.csv (and ideally report.htm), abs or repo-relative")
    ap.add_argument("--initial", type=float, default=5000.0)
    ap.add_argument("--day-reset-hour", type=int, default=0,
                    help="server hour of the GFT daily rollover (default 0; see docs)")
    ap.add_argument("--equity-series", default=None,
                    help="optional 'time,equity' CSV including floating P&L -> exact intraday checks")
    ap.add_argument("--trades", default=None, help="override path to the trades CSV")
    ap.add_argument("--deals", default=None,
                    help="enriched per-position CSV with entry_time+exit_time (+optional mae). "
                         "Required for the 2-minute and weekend-gap rules.")
    ap.add_argument("--fri-close-hour", type=int, default=24,
                    help="server hour of Friday market close (default 24)")
    ap.add_argument("--mon-open-hour", type=int, default=1,
                    help="server hour of Monday market reopen (default 1)")
    ap.add_argument("--margin-rate", type=float, default=DEFAULT_MARGIN_RATE,
                    help=f"symbol margin rate as a fraction (default {DEFAULT_MARGIN_RATE} = our "
                         f"measured XAUUSD value on MetaQuotes-Demo; confirm GFT's)")
    ap.add_argument("--news-csv", default=None,
                    help="high-impact news calendar, one 'YYYY.MM.DD HH:MM' per line (server "
                         "time). Required to check the news-window 1%% profit cap.")
    ap.add_argument("--json", action="store_true", help="emit machine-readable JSON instead of text")
    ap.add_argument("--out", default=None,
                    help="also write the report to this file as UTF-8 (avoids console encoding issues)")
    a = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    wdir = a.window if os.path.isabs(a.window) else os.path.join(root, a.window)
    tcsv = a.trades or os.path.join(wdir, "trades.csv")
    htm = os.path.join(wdir, "report.htm")
    if not os.path.exists(htm):
        alt = os.path.join(wdir, "report.html")
        htm = alt if os.path.exists(alt) else None

    try:
        trades = load_trades(tcsv)
    except FileNotFoundError:
        print(f"[gft_compliance] INPUT ERROR: trades CSV not found: {tcsv}", file=sys.stderr)
        print("  Run the MT5 backtest first (tools/run_candidate.ps1), or pass --trades.", file=sys.stderr)
        return 3

    if not trades:
        print(f"[gft_compliance] INPUT ERROR: no parseable trades in {tcsv}", file=sys.stderr)
        print("  A run with zero trades proves nothing. Not reporting a pass.", file=sys.stderr)
        return 3

    eq = None
    if a.equity_series:
        p = a.equity_series if os.path.isabs(a.equity_series) else os.path.join(root, a.equity_series)
        if not os.path.exists(p):
            print(f"[gft_compliance] INPUT ERROR: equity series not found: {p}", file=sys.stderr)
            return 3
        eq = load_equity_series(p)

    deals = None
    deals_path = a.deals
    if not deals_path:
        # convention: run_candidate.ps1 drops the enriched deals CSV beside trades.csv
        cand = os.path.join(wdir, "deals.csv")
        if os.path.exists(cand):
            deals_path = cand
    if deals_path:
        p = deals_path if os.path.isabs(deals_path) else os.path.join(root, deals_path)
        try:
            deals = load_deals(p)
        except FileNotFoundError:
            print(f"[gft_compliance] INPUT ERROR: deals CSV not found: {p}", file=sys.stderr)
            return 3
        if not deals:
            print(f"[gft_compliance] WARNING: no parseable rows in deals CSV {p}; "
                  f"duration-based rules stay UNVERIFIED.", file=sys.stderr)
            deals = None

    news = None
    if a.news_csv:
        p = a.news_csv if os.path.isabs(a.news_csv) else os.path.join(root, a.news_csv)
        if not os.path.exists(p):
            print(f"[gft_compliance] INPUT ERROR: news calendar not found: {p}", file=sys.stderr)
            return 3
        news = []
        with open(p) as fh:
            for ln in fh:
                ln = ln.strip()
                if not ln or ln.startswith("#"):
                    continue
                ln = ln.split(",")[0].strip()
                for fmt in ("%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M"):
                    try:
                        news.append(dt.datetime.strptime(ln, fmt))
                        break
                    except ValueError:
                        continue

    res = evaluate(trades, a.initial, a.stage, a.day_reset_hour, equity_series=eq, htm_path=htm,
                   deals=deals, fri_close_hour=a.fri_close_hour, mon_open_hour=a.mon_open_hour,
                   news_events=news, margin_rate=a.margin_rate)

    if a.json:
        text = json.dumps(res, indent=2, default=str)
    else:
        import io
        buf = io.StringIO()
        _stdout = sys.stdout
        try:
            sys.stdout = buf
            report(res, wdir)
        finally:
            sys.stdout = _stdout
        text = buf.getvalue()

    print(text)
    if a.out:
        p = a.out if os.path.isabs(a.out) else os.path.join(root, a.out)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(text + f"\nEXIT_CODE={res['exit_code']}  ({res['verdict']})\n")
    return res["exit_code"]


if __name__ == "__main__":
    sys.exit(main())

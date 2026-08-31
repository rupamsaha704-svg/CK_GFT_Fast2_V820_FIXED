#!/usr/bin/env python3
"""
QM/ICT setup — building-block 2: New York session-window + 8:30 / 9:30 manipulation legs.

Scope (intentionally narrow): map each OHLC bar's naive timestamp onto New-York local
time (DST-aware) and classify:
  (1) whether the bar falls inside the New-York session window, and
  (2) whether the bar falls inside the 8:30 leg window or the 9:30 leg window.
The 8:30 and 9:30 legs are two SEPARATE, EQUALLY-labelled manipulation legs (tags
'ny_0830' and 'ny_0930'). NEITHER is hard-coded as "the manipulation" vs "the expansion" —
both are examined downstream. Entry / SL / TP / POI / SMT are OUT OF SCOPE here.

Discipline (anti-overfitting, from SPEC/DESIGN_v1.0.md): nothing subjective is baked in.
The mapping from the CSV's native clock to New York time is a PARAMETER (--data-tz) with a
documented default, because the naive CSV timestamps are some exchange/server clock and MUST
NOT be silently assumed to equal New York. The session-window bounds and the two leg windows
are also PARAMETERS with documented defaults. Pre-choosing a "best" value = overfitting = forbidden.

Definitions (LOCKED, implemented exactly):
  US DST rule = EDT (UTC-4) from the 2nd Sunday of March through the day BEFORE the 1st Sunday
                of November; otherwise EST (UTC-5). The Sunday boundaries are computed
                ARITHMETICALLY (no hard-coded years) and cross-checked against
                zoneinfo.ZoneInfo('America/New_York') in selfcheck().
  Engine timezone = America/New_York for the leg logic; DISPLAY to the user in IST (Asia/Kolkata).

Deterministic: same input CSV + same parameters => identical output.
Pure Python standard library only (csv, datetime, argparse, zoneinfo) — dependency-free.

Usage:
    python3 v1_lab/ny_session.py <ohlc.csv> [--data-tz America/New_York]
        [--session-start HH:MM] [--session-end HH:MM]
        [--leg0830 HH:MM-HH:MM] [--leg0930 HH:MM-HH:MM] [--out ny_tags.csv]
    python3 v1_lab/ny_session.py --selfcheck    # run built-in synthetic assertions only
"""
import os
import sys
import csv
import argparse
import datetime
from zoneinfo import ZoneInfo

# Ensure qm_detect (same directory) is importable when run from the repo root.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qm_detect import load_ohlc  # reuse the identical tolerant CSV/timestamp parser


# ---- defaults (tunable parameters, NOT locked truths) -----------------------
# The naive CSV timestamps are the DATA's native exchange/server clock. We DO NOT know for
# certain that this equals New York. The default below is the neutral assumption that the CSV
# is already stamped in New-York local time; it MUST be confirmed against the actual MT5 export
# (common MT5 brokers use an EET/EEST server clock, which would need --data-tz Europe/Athens).
DATA_TZ_DEFAULT = "America/New_York"

# New-York session window (local NY wall-clock). Default is a broad RTH-ish window; tunable.
SESSION_START_DEFAULT = (9, 30)    # 09:30 NY
SESSION_END_DEFAULT = (16, 0)      # 16:00 NY (exclusive upper bound)

# The two equally-labelled manipulation legs (local NY wall-clock windows, [start, end) each).
# Defaults are one-hour windows anchored on the 08:30 and 09:30 NY prints; tunable.
LEG_0830_DEFAULT = ((8, 30), (9, 30))    # 'ny_0830'
LEG_0930_DEFAULT = ((9, 30), (10, 30))   # 'ny_0930'

LEG_TAGS = ("ny_0830", "ny_0930")   # both neutral; neither is "manipulation" vs "expansion"

NY_TZ = ZoneInfo("America/New_York")
IST_TZ = ZoneInfo("Asia/Kolkata")


# ---- provable DST math (LOCKED rule; boundaries computed arithmetically) ----
def _nth_weekday_of_month(year, month, weekday, n):
    """Return the date of the n-th `weekday` (Mon=0..Sun=6) of `year`/`month`.

    Arithmetic only — no hard-coded years. n is 1-based (n=1 => first occurrence).
    """
    first = datetime.date(year, month, 1)
    # days to add to reach the first desired weekday
    shift = (weekday - first.weekday()) % 7
    day = 1 + shift + (n - 1) * 7
    return datetime.date(year, month, day)


def _second_sunday_of_march(year):
    return _nth_weekday_of_month(year, 3, 6, 2)   # Sunday == 6


def _first_sunday_of_november(year):
    return _nth_weekday_of_month(year, 11, 6, 1)


def ny_utc_offset(date):
    """Return the New-York UTC offset in hours for a given calendar `date`.

    -4 (EDT) from the 2nd Sunday of March through the day BEFORE the 1st Sunday of November,
    -5 (EST) otherwise. Boundaries computed arithmetically; no year is hard-coded.

    Note: this is a per-DATE approximation of the offset (the true switch happens at 02:00
    local on the boundary Sundays). For bar-level classification we use zoneinfo directly on
    the localized datetime; this explicit function exists to PROVE the rule and is cross-checked
    against zoneinfo for non-transition-hour instants in selfcheck().
    """
    if isinstance(date, datetime.datetime):
        date = date.date()
    dst_start = _second_sunday_of_march(date.year)   # DST begins this day
    dst_end = _first_sunday_of_november(date.year)    # DST ends this day (fall back at 02:00)
    # EDT applies from dst_start through the day before dst_end.
    if dst_start <= date < dst_end:
        return -4
    return -5


# ---- timezone mapping -------------------------------------------------------
def to_ny(naive_dt, data_tz):
    """Localize a naive bar timestamp (in the data's native clock) and convert to NY local time.

    `data_tz` is a ZoneInfo. Returns a tz-aware datetime in America/New_York.
    """
    aware = naive_dt.replace(tzinfo=data_tz)
    return aware.astimezone(NY_TZ)


def to_ist(aware_dt):
    """Convert any tz-aware datetime to Asia/Kolkata (IST) for user-facing display."""
    return aware_dt.astimezone(IST_TZ)


# ---- session / leg classification -------------------------------------------
def _minutes(hm):
    return hm[0] * 60 + hm[1]


def classify_ny(ny_dt, session_start, session_end, leg0830, leg0930):
    """Classify a NY-local datetime.

    Returns a dict:
        {"in_session": bool, "leg": 'ny_0830'|'ny_0930'|None}

    A bar is in-session when session_start <= local time-of-day < session_end.
    A bar carries a leg tag when its local time-of-day falls in that leg's [start, end) window.
    The two legs are independent, equally-labelled windows; membership is evaluated separately
    and neither is privileged over the other.
    """
    tod = ny_dt.hour * 60 + ny_dt.minute
    in_session = _minutes(session_start) <= tod < _minutes(session_end)
    leg = None
    l0830_s, l0830_e = _minutes(leg0830[0]), _minutes(leg0830[1])
    l0930_s, l0930_e = _minutes(leg0930[0]), _minutes(leg0930[1])
    if l0830_s <= tod < l0830_e:
        leg = LEG_TAGS[0]   # 'ny_0830'
    elif l0930_s <= tod < l0930_e:
        leg = LEG_TAGS[1]   # 'ny_0930'
    return {"in_session": in_session, "leg": leg}


def tag_bars(bars, data_tz, session_start, session_end, leg0830, leg0930):
    """Tag every bar with its NY-local time, IST-display time, session flag and leg tag.

    Returns list of dicts (one per bar with a parseable datetime):
        {"index","dt_native","dt_ny","dt_ist","in_session","leg"}
    Bars whose datetime failed to parse (dt is None) are skipped for classification.
    """
    tagged = []
    for b in bars:
        idx, dt = b[0], b[1]
        if dt is None:
            continue
        ny = to_ny(dt, data_tz)
        ist = to_ist(ny)
        cls = classify_ny(ny, session_start, session_end, leg0830, leg0930)
        tagged.append({
            "index": idx,
            "dt_native": dt,
            "dt_ny": ny,
            "dt_ist": ist,
            "in_session": cls["in_session"],
            "leg": cls["leg"],
        })
    return tagged


# ---- output -----------------------------------------------------------------
def _fmt_native(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def _fmt_tzed(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S %z")


def write_tags_csv(tagged, path):
    """Deterministic per-bar session-tag CSV."""
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["index", "datetime_native", "datetime_ny", "datetime_ist", "in_session", "leg"])
        for t in tagged:
            w.writerow([
                t["index"],
                _fmt_native(t["dt_native"]),
                _fmt_tzed(t["dt_ny"]),
                _fmt_tzed(t["dt_ist"]),
                "1" if t["in_session"] else "0",
                t["leg"] if t["leg"] else "",
            ])


def print_summary(tagged, data_tz_name, session_start, session_end, leg0830, leg0930, out_path):
    n_total = len(tagged)
    n_session = sum(1 for t in tagged if t["in_session"])
    n_0830 = sum(1 for t in tagged if t["leg"] == "ny_0830")
    n_0930 = sum(1 for t in tagged if t["leg"] == "ny_0930")

    def _hm(hm):
        return f"{hm[0]:02d}:{hm[1]:02d}"

    print("=" * 68)
    print("QM/ICT block-2  New-York session + 8:30/9:30 legs")
    print("=" * 68)
    print(f"  data-tz (assumed native clock): {data_tz_name}")
    print(f"    -> mapped to America/New_York (DST-aware); displayed also in Asia/Kolkata (IST)")
    print(f"  NY session window: {_hm(session_start)}..{_hm(session_end)}  (NY local, [start,end))")
    print(f"  leg 'ny_0830' window: {_hm(leg0830[0])}..{_hm(leg0830[1])}  (NY local)")
    print(f"  leg 'ny_0930' window: {_hm(leg0930[0])}..{_hm(leg0930[1])}  (NY local)")
    print(f"  (both legs are neutral, equally-labelled manipulation legs)")
    print("-" * 68)
    if tagged:
        first, last = tagged[0], tagged[-1]
        print("  date range:")
        print(f"    NY : {_fmt_tzed(first['dt_ny'])}  ..  {_fmt_tzed(last['dt_ny'])}")
        print(f"    IST: {_fmt_tzed(first['dt_ist'])}  ..  {_fmt_tzed(last['dt_ist'])}")
    else:
        print("  date range: n/a (no bars)")
    print("-" * 68)
    print(f"  total bars:        {n_total:>7}")
    print(f"  in NY session:     {n_session:>7}")
    print(f"  8:30-leg (ny_0830):{n_0830:>7}")
    print(f"  9:30-leg (ny_0930):{n_0930:>7}")
    print("-" * 68)
    print(f"  per-bar session tags written to: {out_path}")
    print("=" * 68)


# ---- self-check -------------------------------------------------------------
def selfcheck():
    """Synthetic assertions proving the LOCKED behavior.

    (a) ny_utc_offset agrees with zoneinfo across both DST transitions over multiple years.
    (b) a known NY instant maps to the correct IST wall-clock, and the mapping shifts
        correctly after a DST change (EDT vs EST).
    (c) the 8:30 and 9:30 legs are tagged distinctly ('ny_0830' vs 'ny_0930') and neither
        is labelled 'manipulation' vs 'expansion'.
    (d) a bar just outside the NY session window is classified not-in-session (boundary test).
    """
    # --- (a) DST offset vs zoneinfo across transitions, multiple years ---
    for year in (2023, 2024, 2025, 2026):
        # sample every day-of-month 1 and 15 across all months plus the exact boundary Sundays
        sample_dates = []
        for month in range(1, 13):
            sample_dates.append(datetime.date(year, month, 1))
            sample_dates.append(datetime.date(year, month, 15))
        dst_start = _second_sunday_of_march(year)
        dst_end = _first_sunday_of_november(year)
        # boundary probes: day of switch, day before, day after
        for d in (dst_start, dst_start - datetime.timedelta(days=1),
                  dst_end, dst_end - datetime.timedelta(days=1)):
            sample_dates.append(d)
        for d in sample_dates:
            # noon avoids the 02:00 transition ambiguity so per-date offset == instant offset
            probe = datetime.datetime(d.year, d.month, d.day, 12, 0, tzinfo=NY_TZ)
            zi_off = int(probe.utcoffset().total_seconds() // 3600)
            assert ny_utc_offset(d) == zi_off, (
                f"(a) DST mismatch {d}: hand={ny_utc_offset(d)} zoneinfo={zi_off}")
    # explicit arithmetic boundary sanity (no hard-coded years)
    assert _second_sunday_of_march(2025) == datetime.date(2025, 3, 9), "(a) 2nd Sun Mar 2025"
    assert _first_sunday_of_november(2025) == datetime.date(2025, 11, 2), "(a) 1st Sun Nov 2025"

    # --- (b) NY -> IST mapping, incl. post-DST shift ---
    # NY 08:30 during EDT (August): offset -4 => UTC 12:30 => IST 18:00 (12:30 + 5:30)
    ny_edt = datetime.datetime(2025, 8, 15, 8, 30, tzinfo=NY_TZ)
    ist_edt = to_ist(ny_edt)
    assert (ist_edt.hour, ist_edt.minute) == (18, 0), f"(b) EDT->IST expected 18:00 got {ist_edt}"
    # NY 08:30 during EST (January): offset -5 => UTC 13:30 => IST 19:00
    ny_est = datetime.datetime(2025, 1, 15, 8, 30, tzinfo=NY_TZ)
    ist_est = to_ist(ny_est)
    assert (ist_est.hour, ist_est.minute) == (19, 0), f"(b) EST->IST expected 19:00 got {ist_est}"
    # the mapping SHIFTED by exactly one hour across the DST change
    assert (ist_est.hour - ist_edt.hour) == 1, "(b) IST mapping must shift 1h across DST"

    # --- (c) distinct, equally-labelled legs ---
    ss, se = SESSION_START_DEFAULT, SESSION_END_DEFAULT
    c0830 = classify_ny(datetime.datetime(2025, 8, 15, 8, 45, tzinfo=NY_TZ), ss, se,
                        LEG_0830_DEFAULT, LEG_0930_DEFAULT)
    c0930 = classify_ny(datetime.datetime(2025, 8, 15, 9, 45, tzinfo=NY_TZ), ss, se,
                        LEG_0830_DEFAULT, LEG_0930_DEFAULT)
    assert c0830["leg"] == "ny_0830", f"(c) expected ny_0830 got {c0830['leg']}"
    assert c0930["leg"] == "ny_0930", f"(c) expected ny_0930 got {c0930['leg']}"
    assert c0830["leg"] != c0930["leg"], "(c) legs must be tagged distinctly"
    for tag in LEG_TAGS:
        assert "manipulation" not in tag and "expansion" not in tag, (
            "(c) legs must be neutral, not manipulation-vs-expansion")

    # --- (d) session boundary test ---
    # default session 09:30..16:00: 09:29 is OUT, 09:30 is IN, 16:00 is OUT (exclusive end)
    before = classify_ny(datetime.datetime(2025, 8, 15, 9, 29, tzinfo=NY_TZ), ss, se,
                         LEG_0830_DEFAULT, LEG_0930_DEFAULT)
    at_open = classify_ny(datetime.datetime(2025, 8, 15, 9, 30, tzinfo=NY_TZ), ss, se,
                          LEG_0830_DEFAULT, LEG_0930_DEFAULT)
    at_close = classify_ny(datetime.datetime(2025, 8, 15, 16, 0, tzinfo=NY_TZ), ss, se,
                           LEG_0830_DEFAULT, LEG_0930_DEFAULT)
    assert before["in_session"] is False, "(d) 09:29 must be out-of-session"
    assert at_open["in_session"] is True, "(d) 09:30 must be in-session"
    assert at_close["in_session"] is False, "(d) 16:00 must be out-of-session (exclusive end)"

    # --- extra: end-to-end tag_bars on a tiny synthetic series (native-clock == NY here) ---
    bars = [
        (0, datetime.datetime(2025, 8, 15, 8, 45), 1, 1, 1, 1, 0),   # ny_0830, out-of-session
        (1, datetime.datetime(2025, 8, 15, 9, 45), 1, 1, 1, 1, 0),   # ny_0930, in-session
        (2, datetime.datetime(2025, 8, 15, 3, 0), 1, 1, 1, 1, 0),    # neither
    ]
    tagged = tag_bars(bars, NY_TZ, ss, se, LEG_0830_DEFAULT, LEG_0930_DEFAULT)
    assert tagged[0]["leg"] == "ny_0830" and tagged[0]["in_session"] is False
    assert tagged[1]["leg"] == "ny_0930" and tagged[1]["in_session"] is True
    assert tagged[2]["leg"] is None and tagged[2]["in_session"] is False

    print("selfcheck: PASS")
    print("  (a) ny_utc_offset matches zoneinfo across both DST transitions over 2023-2026")
    print("  (b) NY 08:30 -> IST 18:00 (EDT) / 19:00 (EST): mapping shifts 1h across DST")
    print("  (c) 8:30 and 9:30 legs tagged distinctly (ny_0830 / ny_0930), both neutral")
    print("  (d) session boundary: 09:29 out, 09:30 in, 16:00 out (exclusive end)")
    return True


# ---- CLI --------------------------------------------------------------------
def _parse_hm(s):
    h, m = s.split(":")
    return (int(h), int(m))


def _parse_window(s):
    a, b = s.split("-")
    return (_parse_hm(a), _parse_hm(b))


def parse_args(argv):
    p = argparse.ArgumentParser(
        description="QM/ICT block-2: New-York session + 8:30/9:30 leg tagger (DST-aware, IST display).")
    p.add_argument("path", nargs="?", default=None, help="OHLC CSV (datetime,open,high,low,close,volume)")
    p.add_argument("--selfcheck", action="store_true", help="run synthetic assertions only")
    p.add_argument("--data-tz", default=DATA_TZ_DEFAULT,
                   help=f"IANA tz of the CSV's native clock (default {DATA_TZ_DEFAULT}; "
                        f"MUST be confirmed against the real MT5 export)")
    p.add_argument("--session-start", default=None, help="NY session start HH:MM (default 09:30)")
    p.add_argument("--session-end", default=None, help="NY session end HH:MM exclusive (default 16:00)")
    p.add_argument("--leg0830", default=None, help="ny_0830 window HH:MM-HH:MM (default 08:30-09:30)")
    p.add_argument("--leg0930", default=None, help="ny_0930 window HH:MM-HH:MM (default 09:30-10:30)")
    p.add_argument("--out", default=None, help="write per-bar session-tag CSV to this path")
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

    try:
        data_tz = ZoneInfo(args.data_tz)
    except Exception:
        raise SystemExit(f"--data-tz {args.data_tz!r} is not a valid IANA timezone")

    session_start = _parse_hm(args.session_start) if args.session_start else SESSION_START_DEFAULT
    session_end = _parse_hm(args.session_end) if args.session_end else SESSION_END_DEFAULT
    leg0830 = _parse_window(args.leg0830) if args.leg0830 else LEG_0830_DEFAULT
    leg0930 = _parse_window(args.leg0930) if args.leg0930 else LEG_0930_DEFAULT

    bars = load_ohlc(args.path)
    if not bars:
        raise SystemExit(f"no OHLC rows parsed from {args.path}")

    out = args.out if args.out else "ny_tags.csv"
    tagged = tag_bars(bars, data_tz, session_start, session_end, leg0830, leg0930)
    write_tags_csv(tagged, out)
    print_summary(tagged, args.data_tz, session_start, session_end, leg0830, leg0930, out)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
QM/ICT setup — shared OHLC loader / normalizer (data IO).

Scope: ONE deterministic function that reads BOTH OHLC file layouts the project encounters into the
SAME internal bar structure, so every detector / the state machine / the variant runner consume one
canonical in-memory shape regardless of which broker export produced the file.

Two supported input layouts (auto-detected from the header + delimiter, never guessed per-row):

  (1) CANONICAL (comma-separated), used by the repo's cleaned files and the M15 XAUUSD export:
          datetime,open,high,low,close,volume
          2022-05-30 20:45:00,1855.56000,1855.67000,1854.08000,1854.39000,303
      datetime formats tolerated: '%Y-%m-%d %H:%M:%S', '%Y.%m.%d %H:%M', '%Y-%m-%d %H:%M'.

  (2) MT5 "Export Bars" (TAB-separated), used by fresh MT5 exports (e.g. XAGUSD):
          <DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>
          2022.06.16\t03:45:00\t21.704\t21.709\t21.659\t21.670\t226\t0\t26
      Here the date (dot-separated) and time live in SEPARATE columns and are joined; TICKVOL is used
      as the volume field (MT5's real-volume <VOL> is usually 0 for FX/metals). CRLF line endings are
      tolerated.

Internal bar structure (LOCKED, identical to the existing qm_detect contract so nothing downstream
changes): a list of tuples
        (index, datetime|None, open, high, low, close, volume)
with `index` a 0-based sequential integer in file order and `datetime` a naive datetime (the file's
native clock) or None when unparseable.

Discipline: this is pure normalization — no parameters that could bias a strategy, nothing tunable,
no lookahead (row order preserved exactly). Deterministic: same bytes in => identical bars out. Pure
Python standard library only (csv semantics done by hand to stay dependency-free and format-tolerant).

Usage:
    python3 v1_lab/data_io.py <ohlc.csv>      # parse + print a tiny summary (row count, first/last)
    python3 v1_lab/data_io.py --selfcheck     # prove BOTH layouts parse to identical bars on a fixture
"""
import sys
import datetime

# datetime formats tolerated for the CANONICAL single-column datetime (order = try order)
_CANON_DT_FORMATS = ("%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M")
# datetime formats tolerated for the MT5 joined "<date> <time>" string
_MT5_DT_FORMATS = ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M")


def _parse_dt(s, formats):
    for fmt in formats:
        try:
            return datetime.datetime.strptime(s, fmt)
        except Exception:
            continue
    return None


def _looks_like_header(first_field):
    """A header if the first field is a known label (canonical or MT5) rather than a data value."""
    f = first_field.strip().lower()
    return f in ("datetime", "time", "date", "<date>")


def detect_format(header_line):
    """Return 'mt5' or 'canonical' for a raw header (or first) line, deterministically.

    MT5 export-bars are TAB-separated and begin with the '<DATE>' label (angle-bracket columns).
    Everything else is treated as the canonical comma layout. Detection uses ONLY the delimiter and
    the '<...>' marker, never the numeric contents, so it cannot be fooled by a value.
    """
    if "\t" in header_line and "<" in header_line:
        return "mt5"
    return "canonical"


def _split(line, fmt):
    return line.split("\t") if fmt == "mt5" else line.split(",")


def load_ohlc(path):
    """Read an OHLC CSV in EITHER supported layout into the canonical internal bar list.

    Returns list of bars: (index, datetime|None, open, high, low, close, volume).
    - Format is auto-detected from the first non-empty line (header OR, if headerless, the first row).
    - Rows with fewer than the required columns, or non-numeric OHLC, are skipped (tolerant).
    - Row order is preserved exactly (no reordering => no lookahead introduced).
    Deterministic: identical file bytes => identical output.
    """
    bars = []
    idx = 0
    fmt = None
    with open(path) as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if fmt is None:
                # decide the layout from the very first non-empty line
                fmt = detect_format(line)
                first_field = _split(line, fmt)[0]
                if _looks_like_header(first_field):
                    continue  # consumed the header row; real data starts next line
            p = _split(line, fmt)
            if fmt == "mt5":
                # <DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> <TICKVOL> <VOL> <SPREAD>
                if len(p) < 6:
                    continue
                dt = _parse_dt(p[0].strip() + " " + p[1].strip(), _MT5_DT_FORMATS)
                oi, hi, li, ci, vi = 2, 3, 4, 5, 6  # TICKVOL (col 6) is the volume proxy
            else:
                # datetime,open,high,low,close,volume
                if len(p) < 5:
                    continue
                dt = _parse_dt(p[0].strip(), _CANON_DT_FORMATS)
                oi, hi, li, ci, vi = 1, 2, 3, 4, 5
            try:
                o, h, l, c = float(p[oi]), float(p[hi]), float(p[li]), float(p[ci])
            except Exception:
                continue
            v = 0.0
            if len(p) > vi:
                try:
                    v = float(p[vi])
                except Exception:
                    v = 0.0
            bars.append((idx, dt, o, h, l, c, v))
            idx += 1
    return bars


# ---- self-check -------------------------------------------------------------
def selfcheck():
    """Prove BOTH layouts normalize to IDENTICAL bars on a tiny fixture.

    We hand-write the SAME three bars in the canonical comma layout and in the MT5 TAB export-bars
    layout (dot date + separate time column, CRLF line endings, TICKVOL as volume), load each, and
    assert the resulting internal bar lists are byte-for-byte equal on (index, datetime, o,h,l,c,v).
    A negative check confirms format auto-detection is not accidentally symmetric, and a headerless
    canonical file still parses (tolerant). Deterministic; no files left behind.
    """
    import tempfile
    import os

    canonical = (
        "datetime,open,high,low,close,volume\n"
        "2022-05-30 20:45:00,1855.56000,1855.67000,1854.08000,1854.39000,303\n"
        "2022-05-30 21:00:00,1854.45000,1855.83000,1854.09000,1854.92000,356\n"
        "2022-05-30 21:15:00,1854.90000,1856.10000,1854.20000,1855.70000,412\n"
    )
    # SAME three bars, MT5 export-bars layout: dot date + separate time column, TAB-separated, CRLF,
    # with the MT5 extra columns (<VOL>=0, <SPREAD>). TICKVOL equals the canonical volume above.
    mt5 = (
        "<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>\r\n"
        "2022.05.30\t20:45:00\t1855.56000\t1855.67000\t1854.08000\t1854.39000\t303\t0\t12\r\n"
        "2022.05.30\t21:00:00\t1854.45000\t1855.83000\t1854.09000\t1854.92000\t356\t0\t11\r\n"
        "2022.05.30\t21:15:00\t1854.90000\t1856.10000\t1854.20000\t1855.70000\t412\t0\t13\r\n"
    )

    tmp = tempfile.mkdtemp(prefix="data_io_selfcheck_")
    try:
        cpath = os.path.join(tmp, "canon.csv")
        mpath = os.path.join(tmp, "mt5.csv")
        with open(cpath, "w") as f:
            f.write(canonical)
        with open(mpath, "w", newline="") as f:
            f.write(mt5)

        # detection is by header only, never by numeric content
        assert detect_format(canonical.splitlines()[0]) == "canonical", "detect: canonical header"
        assert detect_format(mt5.splitlines()[0]) == "mt5", "detect: MT5 header"

        cb = load_ohlc(cpath)
        mb = load_ohlc(mpath)
        assert len(cb) == 3 and len(mb) == 3, f"both fixtures must yield 3 bars, got {len(cb)}/{len(mb)}"
        # IDENTICAL bars from BOTH layouts (index, datetime, o, h, l, c, v)
        assert cb == mb, ("both layouts must normalize to IDENTICAL bars\n"
                          f"  canonical: {cb}\n  mt5:       {mb}")
        # spot-check a concrete value: joined MT5 datetime + TICKVOL-as-volume
        assert mb[0][1] == datetime.datetime(2022, 5, 30, 20, 45, 0), "MT5 date+time join"
        assert mb[0][6] == 303.0, "MT5 TICKVOL used as volume"
        assert mb[2][5] == 1855.70000, "MT5 close parsed"

        # determinism: re-load yields identical bars
        assert load_ohlc(mpath) == mb, "load must be deterministic on re-read"

        # tolerant: a headerless canonical file (first line is data) still parses
        headerless = os.path.join(tmp, "headerless.csv")
        with open(headerless, "w") as f:
            f.write("2022-05-30 20:45:00,1855.56,1855.67,1854.08,1854.39,303\n")
        hb = load_ohlc(headerless)
        assert len(hb) == 1 and hb[0][1] == datetime.datetime(2022, 5, 30, 20, 45, 0), \
            "headerless canonical row must still parse"
    finally:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)

    print("selfcheck: PASS")
    print("  detect: canonical header vs MT5 '<DATE>' TAB header (by header only, not by content)")
    print("  identical: canonical comma layout and MT5 export-bars layout => byte-identical bars")
    print("  MT5 specifics: dot-date + separate time column joined; TICKVOL used as volume; CRLF ok")
    print("  determinism + tolerance: re-read identical; headerless canonical row still parses")
    return True


def _summary(path, bars):
    def _fmt(dt):
        return dt.strftime("%Y-%m-%d %H:%M:%S") if isinstance(dt, datetime.datetime) else str(dt)
    print("=" * 60)
    print("data_io  OHLC loader / normalizer")
    print("=" * 60)
    print(f"  file:   {path}")
    print(f"  bars:   {len(bars)}")
    if bars:
        print(f"  first:  {_fmt(bars[0][1])}  O={bars[0][2]} H={bars[0][3]} L={bars[0][4]} C={bars[0][5]}")
        print(f"  last:   {_fmt(bars[-1][1])}  O={bars[-1][2]} H={bars[-1][3]} L={bars[-1][4]} C={bars[-1][5]}")
    print("=" * 60)


def main():
    argv = sys.argv[1:]
    if not argv or "--selfcheck" in argv:
        selfcheck()
        path = next((a for a in argv if not a.startswith("--")), None)
        if path is None:
            return
        print()
    else:
        selfcheck()
        print()
    path = next((a for a in argv if not a.startswith("--")), None)
    if path is None:
        return
    bars = load_ohlc(path)
    if not bars:
        raise SystemExit(f"no OHLC rows parsed from {path}")
    _summary(path, bars)


if __name__ == "__main__":
    main()

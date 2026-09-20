#!/usr/bin/env python3
"""
Day-boundary sensitivity test.

GFT resets the daily drawdown reference at 5 PM EST, but never told us whether that clock follows
US daylight saving. On this GMT+3 broker the reset therefore lands at either server 00:00 (if the
reset follows New York local time, UTC-4 in summer) or server 01:00 (if it is fixed UTC-5).

Rather than block on that answer, this asks a cheaper question: DOES IT EVEN MATTER for our data?
It runs the compliance engine at both candidate boundaries and compares the verdicts. If they
agree, the ambiguity is irrelevant and we can proceed. If they disagree, we know the answer is
genuinely required before trusting any result.

Reads existing MT5 output only. Launches no backtest.
Run:  python tools/sensitivity_reset_hour.py
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ROOT, "tools", "gft_compliance.py")

WINDOWS = [
    ("step1",  r"experiments\combo_base2\windows\last1y",       "known daily BREACH run"),
    ("step1",  r"experiments\combo_v1_daily45\windows\last1y",  "daily-fix run, should not breach"),
    ("funded", r"experiments\combo_m4_funded2\windows\last1y",  "shipped funded config"),
    ("step1",  r"experiments\combo_20m_eval\windows\m20",       "20-month eval breadth"),
]

CANDIDATES = [0, 1]   # server hour of the reset: 00:00 (NY local / DST) or 01:00 (fixed UTC-5)


def run(stage, window, hour):
    p = subprocess.run(
        [sys.executable, ENGINE, "--stage", stage, "--window", window,
         "--day-reset-hour", str(hour), "--json"],
        cwd=ROOT, capture_output=True, text=True)
    try:
        return json.loads(p.stdout)
    except Exception:
        return None


def daily_line(res):
    for c in res.get("checks", []):
        if c["rule"].startswith("DAILY DRAWDOWN"):
            return c["status"], c.get("observed")
    return None, None


def main():
    print("=" * 78)
    print("DAY-BOUNDARY SENSITIVITY  -  does the 5 PM EST / DST ambiguity change any verdict?")
    print("=" * 78)
    print("  candidate reset hours (server): 00:00 (NY local, UTC-4 summer) vs 01:00 (fixed UTC-5)")
    print("  reads existing MT5 output only - no backtest launched\n")

    differs = 0
    checked = 0
    for stage, window, label in WINDOWS:
        if not os.path.exists(os.path.join(ROOT, window, "trades.csv")):
            print(f"  [SKIP] {label}  (missing {window})")
            continue
        checked += 1
        out = {}
        for h in CANDIDATES:
            r = run(stage, window, h)
            if r is None:
                out[h] = ("ERROR", None, None)
                continue
            st, obs = daily_line(r)
            out[h] = (r["verdict"], st, obs)

        v0, s0, o0 = out[CANDIDATES[0]]
        v1, s1, o1 = out[CANDIDATES[1]]
        same = (v0 == v1 and s0 == s1)
        tag = "SAME" if same else "DIFFERS"
        if not same:
            differs += 1
        print(f"  [{tag:>7}] {label}   ({stage})")
        print(f"            reset 00:00 -> verdict {v0!r}, daily {s0}, worst day "
              f"{o0 if o0 is None else round(o0, 2)}%")
        print(f"            reset 01:00 -> verdict {v1!r}, daily {s1}, worst day "
              f"{o1 if o1 is None else round(o1, 2)}%")
        print()

    print("=" * 78)
    if checked == 0:
        print("RESULT: nothing to compare - no windows found.")
        code = 3
    elif differs == 0:
        print("RESULT: verdicts IDENTICAL at both boundaries on every window checked.")
        print("  The DST ambiguity does NOT change any conclusion for this data, so it is not")
        print("  blocking. Still confirm it from the dashboard timer before live trading, because")
        print("  a future run with a loss straddling midnight could split differently.")
        code = 0
    else:
        print(f"RESULT: {differs} window(s) DIFFER between the two boundaries.")
        print("  The reset hour genuinely matters. Do NOT trust a daily verdict until the exact")
        print("  reset time is confirmed from the GFT dashboard timer.")
        code = 1
    print("=" * 78)
    return code


if __name__ == "__main__":
    sys.exit(main())

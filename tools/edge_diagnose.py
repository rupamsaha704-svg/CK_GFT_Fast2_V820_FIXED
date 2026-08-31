#!/usr/bin/env python3
"""Analysis-only edge-concentration diagnostic for an MT5 OnTester CSV (time,profit).
Buckets trades by session / hour / weekday and reports count, net, PF, per-trade expectancy.
Reads MT5 output only - never simulates. Note: buy/sell and VA-width are NOT in the CSV.

Usage: python tools/edge_diagnose.py <trades.csv> [label]
"""
import sys, datetime
from collections import defaultdict

# session boundaries (server time) - same as v1_lab/metrics.py SESSIONS
SESSIONS = [("Asia", 0, 8), ("London", 8, 13), ("LDN_NY", 13, 17), ("NY_late", 17, 24)]
WD = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

def session_of(h):
    for name, a, b in SESSIONS:
        if a <= h < b:
            return name
    return "NY_late"

def load(path):
    rows = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.lower().startswith("time,"):
                continue
            t, p = line.rsplit(",", 1)
            try:
                d = datetime.datetime.strptime(t, "%Y.%m.%d %H:%M")
            except ValueError:
                d = None
            rows.append((d, float(p)))
    return rows

def stats(profits):
    n = len(profits)
    net = sum(profits)
    gw = sum(x for x in profits if x > 0)
    gl = abs(sum(x for x in profits if x < 0))
    pf = (gw / gl) if gl > 0 else (float("inf") if gw > 0 else 0.0)
    exp = net / n if n else 0.0
    wr = 100.0 * sum(1 for x in profits if x > 0) / n if n else 0.0
    return n, net, pf, exp, wr

def report(rows, key, label, order=None):
    buckets = defaultdict(list)
    for d, p in rows:
        if d is None:
            continue
        buckets[key(d)].append(p)
    print(f"\n== {label} ==")
    print(f"{'bucket':<10}{'trades':>7}{'net':>11}{'PF':>7}{'exp/trade':>11}{'win%':>7}")
    keys = order if order else sorted(buckets)
    for k in keys:
        if k not in buckets:
            continue
        n, net, pf, exp, wr = stats(buckets[k])
        pfs = f"{pf:.2f}" if pf != float("inf") else "inf"
        print(f"{str(k):<10}{n:>7}{net:>11.0f}{pfs:>7}{exp:>11.2f}{wr:>7.1f}")

def main():
    path = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else path
    rows = load(path)
    n, net, pf, exp, wr = stats([p for _, p in rows])
    print("=" * 60)
    print(f"EDGE DIAGNOSTIC: {label}")
    print(f"overall: trades {n}  net {net:.0f}  PF {pf:.2f}  exp/trade {exp:.2f}  win {wr:.1f}%")
    print("cost reference: $5/trade => edge must be WELL above $5 to survive")
    print("=" * 60)
    report(rows, lambda d: session_of(d.hour), "By session", order=[s[0] for s in SESSIONS])
    report(rows, lambda d: f"{d.hour:02d}", "By hour (server time)")
    report(rows, lambda d: WD[d.weekday()], "By weekday", order=WD)

if __name__ == "__main__":
    main()

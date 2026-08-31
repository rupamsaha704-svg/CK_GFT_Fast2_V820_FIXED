#!/usr/bin/env python3
"""Monthly + session breakdown of an MT5 OnTester trade CSV (time,profit).
Usage: python tools/monthly_breakdown.py <trades.csv>
Analysis only - reads MT5 output, never simulates."""
import sys, csv, datetime
from collections import defaultdict

path = sys.argv[1]
by_month = defaultdict(lambda: [0, 0.0])   # ym -> [count, net]
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
            continue
        pf = float(p)
        rows.append((d, pf))
        ym = f"{d.year}.{d.month:02d}"
        by_month[ym][0] += 1
        by_month[ym][1] += pf

print(f"total trades: {len(rows)}")
if rows:
    print(f"date range: {rows[0][0]:%Y.%m.%d} -> {rows[-1][0]:%Y.%m.%d}")
print("\nmonth      trades      net      cum_net")
cum = 0.0
for ym in sorted(by_month):
    c, net = by_month[ym]
    cum += net
    print(f"{ym}   {c:6d}  {net:10.2f}  {cum:11.2f}")

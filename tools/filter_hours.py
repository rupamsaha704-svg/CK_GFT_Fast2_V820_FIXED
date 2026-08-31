#!/usr/bin/env python3
"""Analysis-only: filter an MT5 time,profit CSV to a server-hour range [lo,hi) and
print count/net/PF/expectancy + a $5/trade cost-stress. Reads MT5 output; no simulation.
Usage: python tools/filter_hours.py <trades.csv> <lo_hour> <hi_hour> [label]
"""
import sys, datetime

path = sys.argv[1]; lo = int(sys.argv[2]); hi = int(sys.argv[3])
label = sys.argv[4] if len(sys.argv) > 4 else f"{path} h[{lo},{hi})"
profits = []
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
        if lo <= d.hour < hi:
            profits.append(float(p))

def pf_of(ps):
    gw = sum(x for x in ps if x > 0); gl = abs(sum(x for x in ps if x < 0))
    return (gw / gl) if gl > 0 else (float("inf") if gw > 0 else 0.0)

n = len(profits); net = sum(profits); pf = pf_of(profits)
exp = net / n if n else 0.0
wr = 100.0 * sum(1 for x in profits if x > 0) / n if n else 0.0
print(f"{label}")
print(f"  trades {n}  net {net:.0f}  PF {pf:.2f}  exp/trade {exp:.2f}  win {wr:.1f}%")
# cost stress
for mult in (1.0, 1.5, 2.0):
    adj = [x - mult * 5.0 for x in profits]
    print(f"  cost {mult}x$5 : net {sum(adj):.0f}  PF {pf_of(adj):.2f}")

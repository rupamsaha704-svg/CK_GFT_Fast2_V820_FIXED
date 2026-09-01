#!/usr/bin/env python3
"""Analysis-only: split an MT5 time,profit CSV into OLDER vs RECENT (by cutoff date) and show
net/PF/win for ALL hours vs EXCLUDING a losing server-hour block [lo,hi). Reads MT5 output only.
This is a ROUGH estimate (removing trades post-hoc ignores the EA's daily-stop / max-trades / margin
interactions) - use it only to decide whether a real MT5 re-run with a session filter is worth it.
Usage: python tools/split_analyze.py <csv> <cutoff YYYY.MM.DD> <lo> <hi>
"""
import sys, datetime

path = sys.argv[1]
cutoff = datetime.datetime.strptime(sys.argv[2], "%Y.%m.%d")
lo, hi = int(sys.argv[3]), int(sys.argv[4])

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
        rows.append((d, float(p)))

def stats(ps):
    n = len(ps); net = sum(ps)
    gw = sum(x for x in ps if x > 0); gl = abs(sum(x for x in ps if x < 0))
    pf = (gw/gl) if gl > 0 else (float("inf") if gw > 0 else 0.0)
    wr = 100.0*sum(1 for x in ps if x > 0)/n if n else 0.0
    pfs = f"{pf:.2f}" if pf != float("inf") else "inf"
    return f"trades {n:>4}  net {net:>8.0f}  PF {pfs:>5}  win {wr:>4.1f}%"

def block(name, rr):
    allp = [p for _, p in rr]
    keptp = [p for d, p in rr if not (lo <= d.hour < hi)]
    print(f"[{name}]")
    print(f"   ALL hours          : {stats(allp)}")
    print(f"   EXCLUDE {lo:02d}:00-{hi:02d}:00 : {stats(keptp)}")

older = [(d, p) for d, p in rows if d < cutoff]
recent = [(d, p) for d, p in rows if d >= cutoff]
print("="*64)
print(f"SPLIT @ {cutoff.date()}   (exclude losing block {lo:02d}:00-{hi:02d}:00 server)")
print("NOTE: post-hoc estimate; a real MT5 re-run is the truth.")
print("="*64)
block("OLDER (trend period)", older)
block("RECENT (current regime)", recent)
block("WHOLE last year", rows)

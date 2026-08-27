#!/usr/bin/env python3
# Exact A/B diff of v23_ts (baseline) vs v23_live exit-deal trade lists.
# Usage: python3 ab_diff.py ab_baseline.csv ab_live.csv
import sys

def load(p):
    rows = []
    for l in open(p):
        l = l.strip()
        if not l or l.startswith('time,'):
            continue
        t, pf = l.rsplit(',', 1)
        rows.append((t, float(pf)))
    return rows

B = load(sys.argv[1] if len(sys.argv) > 1 else 'ab_baseline.csv')
L = load(sys.argv[2] if len(sys.argv) > 2 else 'ab_live.csv')
print(f"baseline: {len(B)} trades  net {sum(p for _, p in B):.2f}")
print(f"live    : {len(L)} trades  net {sum(p for _, p in L):.2f}")
setB = {t for t, _ in B}
setL = {t for t, _ in L}
only_base = [t for t, _ in B if t not in setL]
only_live = [t for t, _ in L if t not in setB]
print(f"\ntrades in BASELINE but NOT in live ({len(only_base)}):")
for t in only_base:
    print("   ", t, dict(B)[t])
print(f"\ntrades in LIVE but NOT in baseline ({len(only_live)}):")
for t in only_live:
    print("   ", t, dict(L)[t])
common = [t for t, _ in B if t in setL]
mismatch = [(t, dict(B)[t], dict(L)[t]) for t in common if abs(dict(B)[t] - dict(L)[t]) > 1e-9]
print(f"\ncommon timestamps: {len(common)}   profit-mismatches on common: {len(mismatch)}")
for t, b, l in mismatch[:20]:
    print("   ", t, "base", b, "live", l)

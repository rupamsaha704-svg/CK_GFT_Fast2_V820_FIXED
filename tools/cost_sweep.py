#!/usr/bin/env python3
"""Analysis-only cost/slippage stress for an MT5 time,profit CSV. Subtracts $c per FILL for a
range of c and reports net / PF / expectancy. Critical for high-frequency scalpers where
spread+commission can erase a thin per-trade edge. Reads MT5 output only.
Usage: python tools/cost_sweep.py <trades.csv> [label]
"""
import sys

path = sys.argv[1]
label = sys.argv[2] if len(sys.argv) > 2 else path
profits = []
with open(path) as fh:
    for line in fh:
        line = line.strip()
        if not line or "," not in line:
            continue
        _, last = line.rsplit(",", 1)
        try:
            profits.append(float(last))
        except ValueError:
            continue

def pf(ps):
    gw = sum(x for x in ps if x > 0); gl = abs(sum(x for x in ps if x < 0))
    return (gw / gl) if gl > 0 else (float("inf") if gw > 0 else 0.0)

n = len(profits)
print(f"== COST STRESS: {label} ==")
print(f"{'$/fill':>7}{'net $':>10}{'PF':>7}{'exp/fill':>10}")
for c in (0, 1, 2, 3, 4, 5):
    adj = [x - c for x in profits]
    net = sum(adj); e = net / n if n else 0
    p = pf(adj); ps = f"{p:.2f}" if p != float("inf") else "inf"
    print(f"{c:>7}{net:>10.0f}{ps:>7}{e:>10.2f}")
print(f"fills = {n}   (partial-TP closes count as separate fills => real positions are fewer)")

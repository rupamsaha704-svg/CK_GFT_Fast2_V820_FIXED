#!/usr/bin/env python3
"""Compact MT5-style summary across all experiments (reads existing OnTester CSVs only).
Shows per strategy: trades, net $, profit factor, win %, max closed drawdown %.
Usage: python tools/summarize_all.py [deposit]"""
import os, sys, glob, datetime

dep = float(sys.argv[1]) if len(sys.argv) > 1 else 50000.0
root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "experiments")

def load(path):
    r = []
    with open(path) as fh:
        for l in fh:
            l = l.strip()
            if not l or l.lower().startswith("time,"):
                continue
            t, p = l.rsplit(",", 1)
            try: r.append(float(p))
            except ValueError: pass
    return r

def stats(ps):
    n = len(ps); net = sum(ps)
    gw = sum(x for x in ps if x > 0); gl = abs(sum(x for x in ps if x < 0))
    pf = (gw/gl) if gl > 0 else (99.9 if gw > 0 else 0.0)
    wr = 100.0*sum(1 for x in ps if x > 0)/n if n else 0.0
    eq = dep; pk = dep; mdd = 0.0
    for x in ps:
        eq += x; pk = max(pk, eq); d = (pk-eq)/pk*100 if pk > 0 else 0
        mdd = max(mdd, d)
    return n, net, pf, wr, mdd

# preferred "headline" window per experiment
PREF = ["OOS_2026", "baseline_realtick", "baseline_dep50k", "baseline_lev100", "oos_2026H1", "is_2025H2"]

print(f"{'strategy / window':32}{'trades':>7}{'net $':>11}{'PF':>7}{'win%':>7}{'maxDD%':>8}")
print("-"*72)
for exp in sorted(os.listdir(root)):
    wdir = os.path.join(root, exp, "windows")
    if not os.path.isdir(wdir):
        continue
    wins = [w for w in os.listdir(wdir) if os.path.isfile(os.path.join(wdir, w, "trades.csv"))]
    if not wins:
        continue
    pick = next((p for p in PREF if p in wins), sorted(wins)[0])
    n, net, pf, wr, mdd = stats(load(os.path.join(wdir, pick, "trades.csv")))
    print(f"{(exp+' / '+pick):32}{n:>7}{net:>11.0f}{pf:>7.2f}{wr:>7.1f}{mdd:>8.1f}")

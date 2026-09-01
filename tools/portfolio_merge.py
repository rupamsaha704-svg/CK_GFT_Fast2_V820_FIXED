#!/usr/bin/env python3
"""
portfolio_merge.py - honest portfolio/ensemble view: merge N strategy trade streams (each a
separate $dep sleeve) by time into ONE combined equity curve, and report combined net / PF /
max drawdown / monthly, plus each sleeve standalone. Reads MT5 output only (time,profit or
deal,profit tolerant). Respects a sealed-holdout cutoff (drops trades on/after --cutoff).

This is the LEGITIMATE 'combine what works': each sleeve is an independently-run strategy;
we simply run them together. No fitting, no weight tuning.

Usage:
  python tools/portfolio_merge.py --dep 5000 --cutoff 2026.07.01 \
      v17=experiments/v17_live5k/windows/last1yr/trades.csv \
      fix10=experiments/fix10_trendmod/windows/build/trades.csv
"""
import argparse, datetime, sys


def load(path, cutoff):
    rows = []
    with open(path) as fh:
        for l in fh:
            l = l.strip()
            if not l or "," not in l:
                continue
            head, last = l.rsplit(",", 1)
            try:
                p = float(last)
            except ValueError:
                continue
            dt = None
            try:
                dt = datetime.datetime.strptime(head.split(",")[-1].strip(), "%Y.%m.%d %H:%M")
            except Exception:
                dt = None
            if cutoff and dt and dt >= cutoff:
                continue
            rows.append((dt, p))
    return rows


def stats(profits, dep):
    n = len(profits); net = sum(profits)
    gw = sum(x for x in profits if x > 0); gl = abs(sum(x for x in profits if x < 0))
    pf = (gw / gl) if gl > 0 else (float("inf") if gw > 0 else 0.0)
    wr = 100.0 * sum(1 for x in profits if x > 0) / n if n else 0.0
    eq = dep; pk = dep; mdd = 0.0
    for x in profits:
        eq += x; pk = max(pk, eq)
        d = (pk - eq) / pk * 100 if pk > 0 else 0
        mdd = max(mdd, d)
    pfs = f"{pf:.2f}" if pf != float("inf") else "inf"
    return n, net, pfs, wr, mdd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sleeves", nargs="+", help="label=csvpath")
    ap.add_argument("--dep", type=float, default=5000.0, help="deposit per sleeve")
    ap.add_argument("--cutoff", default=None, help="drop trades on/after YYYY.MM.DD (sealed holdout)")
    a = ap.parse_args()
    cutoff = datetime.datetime.strptime(a.cutoff, "%Y.%m.%d") if a.cutoff else None

    sleeves = []
    for s in a.sleeves:
        label, path = s.split("=", 1)
        sleeves.append((label, load(path, cutoff)))

    print("=" * 70)
    print(f"PORTFOLIO MERGE  ({len(sleeves)} sleeves x ${a.dep:,.0f} = ${a.dep*len(sleeves):,.0f} total)"
          + (f"  cutoff<{a.cutoff}" if cutoff else ""))
    print("=" * 70)
    print(f"{'sleeve':16}{'trades':>7}{'net $':>10}{'PF':>7}{'win%':>7}{'maxDD%':>8}")
    print("-" * 70)
    for label, rows in sleeves:
        n, net, pf, wr, mdd = stats([p for _, p in rows], a.dep)
        print(f"{label:16}{n:>7}{net:>10.0f}{pf:>7}{wr:>7.1f}{mdd:>8.1f}")

    # combined: merge by time (undated trades appended at end in file order)
    merged = []
    for _, rows in sleeves:
        merged.extend(rows)
    dated = sorted([r for r in merged if r[0] is not None], key=lambda r: r[0])
    undated = [r for r in merged if r[0] is None]
    allrows = dated + undated
    total_dep = a.dep * len(sleeves)
    n, net, pf, wr, mdd = stats([p for _, p in allrows], total_dep)
    print("-" * 70)
    print(f"{'COMBINED':16}{n:>7}{net:>10.0f}{pf:>7}{wr:>7.1f}{mdd:>8.1f}")
    ret = 100.0 * net / total_dep
    print(f"\ncombined return on ${total_dep:,.0f}: {ret:+.1f}%   final ${total_dep+net:,.0f}")

    # monthly combined
    by_m = {}
    for dt, p in dated:
        k = f"{dt.year}.{dt.month:02d}"
        by_m[k] = by_m.get(k, 0.0) + p
    if by_m:
        print("\nmonthly (combined):")
        cum = 0.0
        for k in sorted(by_m):
            cum += by_m[k]
            print(f"  {k}: {by_m[k]:>8.0f}   cum {cum:>8.0f}")


if __name__ == "__main__":
    main()

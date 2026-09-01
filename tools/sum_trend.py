#!/usr/bin/env python3
"""Summarize trend-EA window results from trades.csv (time,profit) into MT5-style
net $/PF/DD/win%/trades per instrument per window. Tolerant loader."""
import os, sys

def load(path):
    if not os.path.exists(path):
        return None
    profits = []
    for ln in open(path, encoding="utf-8", errors="replace"):
        ln = ln.strip()
        if not ln or ln.lower().startswith("time"):
            continue
        parts = ln.split(",")
        try:
            profits.append(float(parts[-1]))
        except ValueError:
            continue
    return profits

def stats(profits):
    n = len(profits)
    net = sum(profits)
    wins = [p for p in profits if p > 0]
    losses = [p for p in profits if p < 0]
    gw, gl = sum(wins), -sum(losses)
    pf = (gw / gl) if gl > 0 else (float('inf') if gw > 0 else 0.0)
    winpct = (100.0 * len(wins) / n) if n else 0.0
    # max drawdown of cumulative equity (starting 0)
    eq = 0.0; peak = 0.0; mdd = 0.0
    for p in profits:
        eq += p
        if eq > peak: peak = eq
        dd = peak - eq
        if dd > mdd: mdd = dd
    return n, net, pf, winpct, mdd

def main():
    base = "experiments"
    presets = sys.argv[1:] if len(sys.argv) > 1 else ["trend_eurusd", "trend_gbpusd", "trend_xagusd"]
    windows = ["IS_build", "OOS_build", "holdout"]
    out = []
    out.append(f"{'instrument':14} {'window':10} {'trades':>6} {'net$':>10} {'PF':>6} {'win%':>6} {'maxDD$':>10}")
    out.append("-" * 70)
    for pr in presets:
        sym = pr.replace("trend_", "").upper()
        for w in windows:
            path = os.path.join(base, pr, "windows", w, "trades.csv")
            profits = load(path)
            if profits is None:
                out.append(f"{sym:14} {w:10} {'--- no report yet ---':>40}")
                continue
            n, net, pf, winpct, mdd = stats(profits)
            pfs = "inf" if pf == float('inf') else f"{pf:.2f}"
            out.append(f"{sym:14} {w:10} {n:>6} {net:>10.2f} {pfs:>6} {winpct:>6.1f} {mdd:>10.2f}")
    text = "\n".join(out)
    open("tools/trend_summary.txt", "w", encoding="utf-8").write(text + "\n")
    print(text)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Comprehensive sweep summarizer. Walks experiments/sweep_turtle_* and sweep_trend_*,
computes MT5-style net$/PF/DD/win%/trades per window, flags holdout-survivors.
A SURVIVOR = holdout net>0 AND holdout PF>1 AND OOS_build net>0 (edge persists OOS+holdout)."""
import os, glob

def load(path):
    if not os.path.exists(path):
        return None
    profits = []
    for ln in open(path, encoding="utf-8", errors="replace"):
        ln = ln.strip()
        if not ln or ln.lower().startswith("time"):
            continue
        try:
            profits.append(float(ln.split(",")[-1]))
        except ValueError:
            continue
    return profits

def stats(profits):
    n = len(profits); net = sum(profits)
    wins = [p for p in profits if p > 0]; losses = [p for p in profits if p < 0]
    gw, gl = sum(wins), -sum(losses)
    pf = (gw / gl) if gl > 0 else (999.0 if gw > 0 else 0.0)
    winpct = (100.0 * len(wins) / n) if n else 0.0
    eq = peak = mdd = 0.0
    for p in profits:
        eq += p; peak = max(peak, eq); mdd = max(mdd, peak - eq)
    return n, net, pf, winpct, mdd

WINDOWS = ["IS_build", "OOS_build", "holdout"]

def main():
    dirs = sorted(glob.glob("experiments/sweep_turtle_*") + glob.glob("experiments/sweep_trend_*"))
    out = []
    hdr = f"{'combo':28} {'window':10} {'trades':>6} {'net$':>11} {'PF':>6} {'win%':>6} {'maxDD$':>11}"
    out.append(hdr); out.append("-" * len(hdr))
    survivors = []
    for d in dirs:
        name = os.path.basename(d).replace("sweep_", "")
        wstats = {}
        any_data = False
        for w in WINDOWS:
            profits = load(os.path.join(d, "windows", w, "trades.csv"))
            if profits is None:
                out.append(f"{name:28} {w:10} {'--- pending ---':>36}")
                wstats[w] = None
                continue
            any_data = True
            s = stats(profits); wstats[w] = s
            n, net, pf, wp, mdd = s
            pfs = "inf" if pf >= 999 else f"{pf:.2f}"
            out.append(f"{name:28} {w:10} {n:>6} {net:>11.2f} {pfs:>6} {wp:>6.1f} {mdd:>11.2f}")
        # survivor check
        o = wstats.get("OOS_build"); h = wstats.get("holdout")
        if o and h and h[1] > 0 and h[2] > 1.0 and o[1] > 0:
            survivors.append((name, o, h))
        out.append("")
    out.append("=" * len(hdr))
    if survivors:
        out.append("HOLDOUT SURVIVORS (edge persisted OOS + holdout):")
        for name, o, h in survivors:
            out.append(f"  *** {name}: OOS net={o[1]:.2f} PF={o[2]:.2f} | HOLDOUT net={h[1]:.2f} PF={h[2]:.2f}")
    else:
        out.append("HOLDOUT SURVIVORS: none (no combo kept a positive edge through OOS + sealed holdout)")
    text = "\n".join(out)
    open("tools/sweep_summary.txt", "w", encoding="utf-8").write(text + "\n")
    print(text)

if __name__ == "__main__":
    main()

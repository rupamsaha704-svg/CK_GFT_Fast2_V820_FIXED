#!/usr/bin/env python3
"""
screen_gate.py - LOOSE fast-screen gate for the Model-1 (1-min OHLC) pre-filter ONLY.

Purpose: save time by rejecting candidates that are CLEARLY DEAD even on the fast model,
so we only pay for slow Model-4 (real-tick) runs on things that might have an edge.

DISCIPLINE: this is NOT a pass/edge decision. Model 1 is an approximation; real ticks are the
only truth. So the gate is deliberately PERMISSIVE - it rejects only the obviously-hopeless
(OOS profit factor below --min-pf AND OOS net < 0). Anything borderline/positive is kept and
sent to the Model-4 confirm, where the full deterministic pipeline decides PASS/FAIL/REJECT.

Exit codes: 0 = keep (send to real-tick confirm) | 2 = screened out (clearly dead) | 1 = error.

Usage:
  python tools/screen_gate.py --oos OOS.csv [--half1 cr_h1.csv --half2 cr_h2.csv]
                              [--min-pf 0.90] [--deposit 50000]
"""
import argparse, os, sys


def pf_net(path):
    """Tolerant loader (screen only): accepts either 'time,profit' or 'deal,profit' headers,
    skips any unparseable/header line. PF/net math is identical to canonical metrics.py.
    The Model-4 confirm still uses the locked canonical metrics.py + pipeline for the real verdict."""
    if not path or not os.path.isfile(path):
        return None, None, 0
    profits = []
    with open(path) as fh:
        for l in fh:
            l = l.strip()
            if not l or "," not in l:
                continue
            _, last = l.rsplit(",", 1)
            try:
                profits.append(float(last))
            except ValueError:
                continue  # header or garbage row
    gw = sum(p for p in profits if p > 0)
    gl = abs(sum(p for p in profits if p < 0))
    pf = (gw / gl) if gl > 0 else (float("inf") if gw > 0 else 0.0)
    return pf, sum(profits), len(profits)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--oos", required=True)
    ap.add_argument("--half1", default=None)
    ap.add_argument("--half2", default=None)
    ap.add_argument("--min-pf", type=float, default=0.90)
    ap.add_argument("--deposit", type=float, default=50000.0)
    a = ap.parse_args()

    opf, onet, on = pf_net(a.oos)
    if opf is None:
        print("SCREEN ERROR: OOS csv missing ->", a.oos)
        sys.exit(1)

    h1pf, h1net, h1n = pf_net(a.half1)
    h2pf, h2net, h2n = pf_net(a.half2)

    # LOOSE reject: clearly dead only = OOS PF below floor AND OOS net negative.
    dead = (opf < a.min_pf) and (onet < 0)
    # extra mercy: if either current-regime half is clearly alive, keep it for real-tick anyway.
    half_alive = (h1pf is not None and h1pf >= a.min_pf) or (h2pf is not None and h2pf >= a.min_pf)
    keep = (not dead) or half_alive

    pf_str = f"{opf:.2f}" if opf != float("inf") else "inf"
    msg = f"SCREEN(Model1) OOS: trades={on} PF={pf_str} net={onet:.0f}"
    if h1pf is not None:
        msg += f" | cr_h1 PF={h1pf:.2f} net={h1net:.0f}"
    if h2pf is not None:
        msg += f" | cr_h2 PF={h2pf:.2f} net={h2net:.0f}"
    print(msg)
    print(f"  min-pf floor = {a.min_pf:.2f}  ->  " +
          ("KEEP (send to Model-4 real-tick confirm)" if keep
           else "SCREENED OUT (clearly dead on fast model; skip real-tick to save time)"))
    print("  NOTE: Model 1 is a fast approximation; Model 4 real ticks remain the only truth.")
    sys.exit(0 if keep else 2)


if __name__ == "__main__":
    main()

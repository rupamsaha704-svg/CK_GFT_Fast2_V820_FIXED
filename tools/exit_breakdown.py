#!/usr/bin/env python3
"""Analysis-only: count TP-hit vs SL-hit exits from an MT5 tester agent log (UTF-16),
and (from a paired time,profit CSV) win rate + avg win/loss + implied breakeven win rate
+ realized-RR proxy. Reads MT5 output; never simulates.
Usage: python tools/exit_breakdown.py <tester.log> [<trades.csv>]
"""
import sys

def decode(path):
    raw = open(path, "rb").read()
    for enc in ("utf-16", "utf-16-le", "latin-1"):
        try:
            return raw.decode(enc)
        except Exception:
            continue
    return ""

log = sys.argv[1]
text = decode(log)
tp = text.lower().count("take profit triggered")
sl = text.lower().count("stop loss triggered")
close_end = text.lower().count("close at")  # rough: forced/other closes
print(f"log: {log}")
print(f"  TP-hit exits : {tp}")
print(f"  SL-hit exits : {sl}")
print(f"  other 'close at' lines: {close_end}")
tot = tp + sl
if tot:
    print(f"  TP share     : {100.0*tp/tot:.1f}%   (SL share {100.0*sl/tot:.1f}%)")

if len(sys.argv) > 2:
    csv = sys.argv[2]
    profits = []
    with open(csv) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.lower().startswith("time,"):
                continue
            profits.append(float(line.rsplit(",", 1)[1]))
    n = len(profits)
    wins = [p for p in profits if p > 0]
    losses = [p for p in profits if p < 0]
    wr = 100.0 * len(wins) / n if n else 0.0
    aw = sum(wins) / len(wins) if wins else 0.0
    al = sum(losses) / len(losses) if losses else 0.0
    rr = (aw / abs(al)) if al else 0.0            # avg win : avg loss (dollar proxy for realized RR of winners)
    be = 100.0 / (1.0 + rr) if rr > 0 else 0.0     # breakeven win rate given that reward:risk
    print(f"  trades={n}  win_rate={wr:.1f}%  avg_win={aw:.1f}  avg_loss={al:.1f}")
    print(f"  avg_win/avg_loss (realized RR proxy) = {rr:.2f}  => breakeven win rate = {be:.1f}%")
    print(f"  ACTUAL {wr:.1f}% vs BREAKEVEN {be:.1f}%  => {'ABOVE (edge)' if wr>be else 'BELOW (bleeds)'}")

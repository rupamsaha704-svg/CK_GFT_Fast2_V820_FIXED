#!/usr/bin/env python3
"""Compare H1 (baseline no-trail) vs H2 (ATR-trail) MT5 real-tick deals."""
import csv
import datetime as dt
from collections import defaultdict

BASE = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\qm_signalplayer_deals_baseline.csv'
H2   = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\qm_signalplayer_deals_h2trail.csv'

def load(path):
    trades = []
    with open(path, newline='') as f:
        r = csv.DictReader(f)
        for row in r:
            trades.append({
                'close_dt': dt.datetime.strptime(row['close_time'], '%Y.%m.%d %H:%M'),
                'type': row['type'],
                'volume': float(row['volume']),
                'price': float(row['price']),
                'sl': float(row['sl']) if row['sl'] else 0.0,
                'tp': float(row['tp']) if row['tp'] else 0.0,
                'profit': float(row['profit']),
                'swap': float(row['swap']) if row['swap'] else 0.0,
                'commission': float(row['commission']) if row['commission'] else 0.0,
                'comment': row['comment'],
            })
            trades[-1]['net'] = trades[-1]['profit'] + trades[-1]['swap'] + trades[-1]['commission']
    return trades

def summary(name, trades):
    n = len(trades)
    net = sum(t['net'] for t in trades)
    wins = [t for t in trades if t['net'] > 0]
    losses = [t for t in trades if t['net'] < 0]
    gw = sum(t['net'] for t in wins)
    gl = sum(t['net'] for t in losses)
    pf = gw/abs(gl) if gl < 0 else float('inf')
    tp_hits = sum(1 for t in trades if 'tp' in t['comment'].lower())
    sl_hits = sum(1 for t in trades if 'sl' in t['comment'].lower())
    other  = n - tp_hits - sl_hits
    avg_win = gw/max(len(wins),1)
    avg_loss = gl/max(len(losses),1)
    print(f"\n== {name} ==")
    print(f"  Total trades  : {n}")
    print(f"  Net           : ${net:+.2f}")
    print(f"  Wins/Losses   : {len(wins)} / {len(losses)} ({100*len(wins)/n:.1f}% wr)")
    print(f"  PF            : {pf:.3f}")
    print(f"  Avg win       : ${avg_win:+.2f}")
    print(f"  Avg loss      : ${avg_loss:+.2f}")
    print(f"  TP hits       : {tp_hits}")
    print(f"  SL hits       : {sl_hits}")
    print(f"  Other exits   : {other}")
    return trades

def match_by_close(base, h2):
    """Match trades by close_time proximity (within 5min) and compare per-trade net."""
    print("\n== Per-trade comparison (matched by close time) ==")
    print(f"  {'close_time':<18} {'base_net':>10} {'h2_net':>10} {'delta':>10} {'base_cmt':<18} {'h2_cmt':<18}")
    matched = 0
    total_delta = 0.0
    dropped_by_trail = 0
    for b in base:
        best = None; best_diff = 999999
        for h in h2:
            d = abs((h['close_dt'] - b['close_dt']).total_seconds())
            if d < 300 and d < best_diff:
                best_diff = d; best = h
        if best:
            matched += 1
            delta = best['net'] - b['net']
            total_delta += delta
            if delta < -1:
                dropped_by_trail += 1
    print(f"\n  Matched by close time (±5min): {matched} / {len(base)}")
    print(f"  Total net delta (H2 - H1)    : ${total_delta:+.2f}")
    print(f"  Trades where H2 was WORSE by $1+: {dropped_by_trail}")

def show_dropped(base, h2):
    """Show 10 trades where H2 turned a baseline win into a loss (or bigger loss)."""
    print("\n== 10 worst H2 regressions vs baseline ==")
    print(f"  {'close_dt':<18} {'type':<12} {'base_net':>10} {'h2_net':>10} {'delta':>10}")
    matches = []
    for b in base:
        for h in h2:
            d = abs((h['close_dt'] - b['close_dt']).total_seconds())
            if d < 300:
                delta = h['net'] - b['net']
                matches.append((b['close_dt'], b['type'], b['net'], h['net'], delta, b['comment'], h['comment']))
                break
    matches.sort(key=lambda x: x[4])
    for m in matches[:10]:
        print(f"  {m[0].strftime('%Y-%m-%d %H:%M'):<18} {m[1]:<12} ${m[2]:>+9.2f} ${m[3]:>+9.2f} ${m[4]:>+9.2f}  base={m[5][:12]} h2={m[6][:12]}")

base = load(BASE)
h2 = load(H2)
summary("H1 baseline (no trail)", base)
summary("H2 ATR-trail (1.5/2.0)", h2)
match_by_close(base, h2)
show_dropped(base, h2)

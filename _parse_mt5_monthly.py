#!/usr/bin/env python3
"""
Parse MT5 deals CSV (qm_signalplayer_deals.csv) and produce
month-by-month P&L breakdown + FundedNext compliance for $6k account.
"""
import csv
import datetime as dt
from collections import defaultdict

DEALS_CSV = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\qm_signalplayer_deals.csv'
INITIAL = 6000.0
DAILY_LIMIT = 300.0
STATIC_FLOOR = 5400.0
FUNDED_RISK = 180.0

def parse_dt(s):
    return dt.datetime.strptime(s, '%Y.%m.%d %H:%M')

trades = []
with open(DEALS_CSV, newline='') as f:
    r = csv.DictReader(f)
    for row in r:
        p = float(row['profit'])
        s = float(row['swap']) if row['swap'] else 0.0
        c = float(row['commission']) if row['commission'] else 0.0
        trades.append({
            'close_dt': parse_dt(row['close_time']),
            'type': row['type'],
            'volume': float(row['volume']),
            'price': float(row['price']),
            'profit_gross': p,
            'swap': s,
            'commission': c,
            'net': p + s + c,   # net of swap + commission
            'comment': row.get('comment', ''),
        })
trades.sort(key=lambda t: t['close_dt'])

# ---- Overall ----
n = len(trades)
wins = [t for t in trades if t['net'] > 0]
losses = [t for t in trades if t['net'] < 0]
gw = sum(t['net'] for t in wins)
gl = sum(t['net'] for t in losses)
net = gw + gl
pf = gw / abs(gl) if gl < 0 else float('inf')
win_rate = 100.0 * len(wins) / n
swap_total = sum(t['swap'] for t in trades)
comm_total = sum(t['commission'] for t in trades)

print("=" * 72)
print("  MT5 REAL-TICK RESULT: CK_QM_SignalPlayer / erl_h4+dedupe")
print("  Window: XAUUSD M15, real ticks (Model 4), $6,000 deposit, 1:100 lev")
print("  Risk per trade: $85, max concurrent: 2, tolerance: 20min")
print("=" * 72)
print(f"  Total trades closed  : {n}")
print(f"  Wins / Losses        : {len(wins)} ({win_rate:.1f}%) / {len(losses)} ({100-win_rate:.1f}%)")
print(f"  Gross wins           : ${gw:+.2f}")
print(f"  Gross losses         : ${gl:+.2f}")
print(f"  Swap  cumulative     : ${swap_total:+.2f}")
print(f"  Comm  cumulative     : ${comm_total:+.2f}")
print(f"  Net (all inclusive)  : ${net:+.2f}")
print(f"  Return on $6k        : {100*net/INITIAL:+.2f}%")
print(f"  PF (net-basis)       : {pf:.3f}")
print(f"  Expectancy per trade : ${net/n:+.2f}")

# ---- Monthly breakdown ----
monthly = defaultdict(lambda: {'n':0,'wins':0,'net':0.0,'gw':0.0,'gl':0.0})
for t in trades:
    key = t['close_dt'].strftime('%Y-%m')
    monthly[key]['n'] += 1
    if t['net'] > 0:
        monthly[key]['wins'] += 1
        monthly[key]['gw'] += t['net']
    else:
        monthly[key]['gl'] += t['net']
    monthly[key]['net'] += t['net']

print()
print("=" * 72)
print("  MONTHLY BREAKDOWN")
print("=" * 72)
print(f"  {'month':<8} {'trades':>7} {'wins':>5} {'win%':>6} {'gross_w':>10} {'gross_l':>10} {'net':>10}")
running = INITIAL
peak = INITIAL
min_bal = INITIAL
for m in sorted(monthly):
    d = monthly[m]
    wr = 100.0*d['wins']/d['n'] if d['n']>0 else 0
    running += d['net']
    if running > peak: peak = running
    if running < min_bal: min_bal = running
    print(f"  {m:<8} {d['n']:>7} {d['wins']:>5} {wr:>5.1f}% ${d['gw']:>+9.2f} ${d['gl']:>+9.2f} ${d['net']:>+9.2f}")

print()
print(f"  Final balance : ${running:.2f}")
print(f"  Peak balance  : ${peak:.2f}")
print(f"  Min balance   : ${min_bal:.2f}")

# ---- Daily P&L (FN daily-line check) ----
daily = defaultdict(float)
for t in trades:
    daily[t['close_dt'].date()] += t['net']

worst_days = sorted(daily.items(), key=lambda x: x[1])[:10]
breaches = [(d,p) for d,p in daily.items() if p <= -DAILY_LIMIT]

print()
print("=" * 72)
print("  FUNDEDNEXT COMPLIANCE (real-tick data, $6k basis)")
print("=" * 72)
verdict_daily  = 'PASS' if len(breaches) == 0 else f'FAIL ({len(breaches)} days)'
verdict_static = 'PASS' if min_bal > STATIC_FLOOR else 'FAIL'
print(f"  Daily 5% ($300 line) : {verdict_daily}   worst: ${worst_days[0][1]:.2f}  ({worst_days[0][0]})")
print(f"  Static 10% ($5,400 floor) : {verdict_static}  min balance: ${min_bal:.2f}")

print()
print("  5 worst days (realized close-time):")
for d, p in worst_days[:5]:
    print(f"    {d}: ${p:+.2f}  ({100*p/INITIAL:+.2f}% of $6k)")

# ---- Max concurrent (approximate: sequential open/close from deals) ----
# The deals CSV only has close events. We need open events to compute concurrent.
# Instead: count gaps between adjacent closes -- if within-same-hour, likely concurrent.
close_times = sorted([t['close_dt'] for t in trades])
same_hour_pairs = 0
for i in range(1, len(close_times)):
    if (close_times[i] - close_times[i-1]).total_seconds() < 3600:
        same_hour_pairs += 1
print()
print(f"  Deals closing within 1 hour of previous: {same_hour_pairs}  (proxy for concurrent activity)")

# ---- Extrapolations ----
print()
print("=" * 72)
print("  LIVE INCOME PROJECTION (from these real-tick numbers)")
print("=" * 72)
months_span = (trades[-1]['close_dt'] - trades[0]['close_dt']).days / 30.44
monthly_avg = net / months_span
yearly_est = monthly_avg * 12
print(f"  Period : {months_span:.1f} months  |  gross monthly avg: ${monthly_avg:+.2f}")
print(f"  Extrapolated yearly gross: ${yearly_est:+.2f} ({100*yearly_est/INITIAL:+.2f}% on $6k)")
print()
print(f"  Take-home @ 80% split: ${yearly_est*0.80/12:.2f}/mo = ${yearly_est*0.80:.0f}/yr")
print(f"  Take-home @ 90% split: ${yearly_est*0.90/12:.2f}/mo = ${yearly_est*0.90:.0f}/yr")
print(f"  Minus $5 EA fee/mo:")
print(f"    80% split: ${(yearly_est*0.80/12) - 5:.2f}/mo = ~₹{(yearly_est*0.80/12 - 5) * 115:.0f}/mo")
print(f"    90% split: ${(yearly_est*0.90/12) - 5:.2f}/mo = ~₹{(yearly_est*0.90/12 - 5) * 115:.0f}/mo")

print()
print("  vs combo_fnext_03 live: $154/mo take80")
if (yearly_est*0.80/12 - 5) > 154:
    diff = (yearly_est*0.80/12 - 5) - 154
    print(f"  QM erl_h4 WINS by +${diff:.0f}/mo ({100*diff/154:.0f}% higher)")
else:
    diff = 154 - (yearly_est*0.80/12 - 5)
    print(f"  combo_fnext_03 WINS by +${diff:.0f}/mo ({100*diff/(yearly_est*0.80/12-5+0.01):.0f}% higher)")

#!/usr/bin/env python3
"""
Analyze Asian Fade Model 1 result against the pre-reg pass bar.
Model 1 threshold (Phase 3): net > $200 to proceed to Model 4.
"""
import csv, os
import datetime as dt
from collections import defaultdict

DEALS = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\ck_xau_asian_fade_deals.csv'
PLAN_C_DEALS = os.path.join('experiments', 'combo_fnext_journal', 'deals.csv')
INITIAL = 6000.0

def parse_dt(s):
    return dt.datetime.strptime(s.strip(), '%Y.%m.%d %H:%M')

def load(path, key='exit_time'):
    with open(path, newline='') as f:
        r = csv.DictReader(f)
        rows = list(r)
    out = []
    for row in rows:
        try:
            out.append({
                'entry_dt': parse_dt(row['entry_time']),
                'exit_dt' : parse_dt(row['exit_time']),
                'dir'     : row['dir'],
                'net'     : float(row['profit']),
                'volume'  : float(row['volume']),
            })
        except Exception:
            continue
    return sorted(out, key=lambda x: x['exit_dt'])

def monthly_map(deals):
    m = defaultdict(lambda: {'n':0, 'net':0.0, 'wins':0})
    for d in deals:
        k = d['exit_dt'].strftime('%Y-%m')
        m[k]['n']   += 1
        m[k]['net'] += d['net']
        if d['net'] > 0: m[k]['wins'] += 1
    return dict(m)

def daily_map(deals):
    d_ = defaultdict(float)
    for d in deals:
        d_[d['exit_dt'].date()] += d['net']
    return dict(d_)

def running_stats(deals):
    """min balance, peak, drawdown."""
    running = INITIAL
    peak = INITIAL
    min_bal = INITIAL
    max_dd = 0.0
    for d in deals:
        running += d['net']
        if running > peak: peak = running
        if running < min_bal: min_bal = running
        dd = peak - running
        if dd > max_dd: max_dd = dd
    return {'final': running, 'peak': peak, 'min_bal': min_bal, 'max_dd': max_dd}

def pearson(xs, ys):
    n = len(xs)
    if n < 2 or len(ys) < 2:
        return 0.0
    mx = sum(xs)/n; my = sum(ys)/n
    sx2 = sum((x-mx)**2 for x in xs); sy2 = sum((y-my)**2 for y in ys)
    sxy = sum((xs[i]-mx)*(ys[i]-my) for i in range(n))
    if sx2 <= 0 or sy2 <= 0: return 0.0
    return sxy / ((sx2*sy2) ** 0.5)

# ---- load Asian fade deals ----
if not os.path.isfile(DEALS):
    print('DEALS CSV MISSING:', DEALS); raise SystemExit(2)

deals = load(DEALS)
n = len(deals)
if n == 0:
    print('NO CLOSED DEALS - REJECT')
    raise SystemExit(0)

# ---- overall ----
wins = [d for d in deals if d['net'] > 0]
losses = [d for d in deals if d['net'] < 0]
break_even = [d for d in deals if d['net'] == 0]
gw = sum(d['net'] for d in wins)
gl = sum(d['net'] for d in losses)
net = gw + gl
pf = gw / abs(gl) if gl < 0 else float('inf')
win_rate = 100.0 * len(wins) / n

# ---- daily ----
dmap = daily_map(deals)
worst_day = min(dmap.items(), key=lambda x: x[1]) if dmap else (None, 0.0)
best_day  = max(dmap.items(), key=lambda x: x[1]) if dmap else (None, 0.0)

# ---- running stats ----
rs = running_stats(deals)

# ---- consistency vs plan c ----
plan_c_deals = load(PLAN_C_DEALS) if os.path.isfile(PLAN_C_DEALS) else None
plan_c_monthly = monthly_map(plan_c_deals) if plan_c_deals else {}
plan_q_monthly = monthly_map(deals)
overlap = sorted(set(plan_c_monthly.keys()) & set(plan_q_monthly.keys()))
xs = [plan_c_monthly[k]['net'] for k in overlap]
ys = [plan_q_monthly[k]['net'] for k in overlap]
corr = pearson(xs, ys) if overlap else 0.0

# ---- 40% consistency ----
consistency_pct = 100.0 * best_day[1] / net if net > 0 and best_day[1] > 0 else 0.0

# ---- pass/fail bar (Model 1 screen only; final judgement on Model 4) ----
print('='*72)
print('  CK_XAU_ASIAN_FADE  --  MODEL 1 SCREEN RESULT')
print('  window: {} .. {}'.format(deals[0]['exit_dt'].date(), deals[-1]['exit_dt'].date()))
print('='*72)
print(f'  total deals (both TP legs)  : {n}')
print(f'  wins / losses / breakeven   : {len(wins)} / {len(losses)} / {len(break_even)}')
print(f'  gross wins / losses         : ${gw:+.2f} / ${gl:+.2f}')
print(f'  NET                         : ${net:+,.2f}   ({100*net/INITIAL:+.2f}% on $6k)')
print(f'  PF                          : {pf:.3f}')
print(f'  win rate                    : {win_rate:.1f}%')
print(f'  worst day                   : ${worst_day[1]:+.2f}  ({worst_day[0]})')
print(f'  best day                    : ${best_day[1]:+.2f}  ({best_day[0]})')
print(f'  min balance                 : ${rs["min_bal"]:.2f}')
print(f'  peak balance                : ${rs["peak"]:.2f}')
print(f'  max drawdown                : ${rs["max_dd"]:.2f}')
print(f'  consistency (best_day/net%) : {consistency_pct:.1f}%')
print(f'  correlation with Plan C    : {corr:+.3f}  (over {len(overlap)} overlap months)')

print()
print('  MODEL 1 SCREEN THRESHOLD (pre-reg Phase 3):')
if net > 200:
    print(f'  PASS -- net ${net:.2f} > $200 threshold -> proceed to MODEL 4 real-tick verdict')
elif net > 0:
    print(f'  MARGINAL -- net ${net:.2f} above zero but under $200 threshold -> Model 4 unlikely to save it, but eligible')
else:
    print(f'  FAIL -- net ${net:.2f} negative on Model 1 -> REJECT candidate, do not run Model 4')

print()
print('  Pre-registered PASS bar (for Model 4 final verdict):')
def flag(cond): return 'PASS' if cond else 'FAIL'
b1 = net > 600
b2 = win_rate > 55.0
b3 = worst_day[1] > -180
b4 = rs['max_dd'] < 400
b5 = abs(corr) < 0.30
b6 = consistency_pct < 40
print(f'  #1 net > $600            : {flag(b1)}   (${net:.2f})')
print(f'  #2 win rate > 55%        : {flag(b2)}   ({win_rate:.1f}%)')
print(f'  #3 worst day > -$180     : {flag(b3)}   (${worst_day[1]:.2f})')
print(f'  #4 max DD < $400         : {flag(b4)}   (${rs["max_dd"]:.2f})')
print(f'  #5 |corr Plan C| < 0.30 : {flag(b5)}   ({corr:+.3f})')
print(f'  #6 consistency < 40%    : {flag(b6)}   ({consistency_pct:.1f}%)')
passed = all([b1,b2,b3,b4,b5,b6])
print()
print(f'  ALL SIX PASS?  {passed}')

# Monthly breakdown
print()
print('  MONTHLY BREAKDOWN (Asian Fade)')
for k in sorted(plan_q_monthly):
    d = plan_q_monthly[k]
    wr = 100.0*d['wins']/d['n'] if d['n'] else 0.0
    print(f'    {k}   deals={d["n"]:>3}  wins={d["wins"]:>3} ({wr:>4.1f}%)  net=${d["net"]:>+8.2f}')

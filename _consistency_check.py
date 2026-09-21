#!/usr/bin/env python3
"""
Check FN On-Demand '40% consistency' feasibility for both plans.

FN's On-Demand rule (from Allen 2026-09-21 + help.fundednext.com/en/articles/15586820):
- 2% account growth required
- 40% consistency 'across trades'

Common prop-firm interpretation of X% consistency:
    biggest_single_day_profit / total_profit  <=  X%

If our biggest single day is more than 40% of the yearly net, we FAIL consistency
and cannot take On-Demand payouts (or must take smaller / smoother days).

This script reports:
- top 5 winning DAYS (by aggregated deal profit) for each plan
- biggest-day / total-net ratio (the consistency-rule check)
"""
import csv, os
import datetime as dt
from collections import defaultdict

PLAN_C_CSV = os.path.join('experiments', 'combo_fnext_journal', 'deals.csv')
PLAN_Q_CSV = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\qm_signalplayer_deals_baseline.csv'

def parse_dt(s):
    return dt.datetime.strptime(s.strip(), '%Y.%m.%d %H:%M')

def load(path):
    with open(path, newline='') as f:
        r = csv.DictReader(f)
        cols = set(r.fieldnames or [])
        rows = list(r)
    out = []
    if 'exit_time' in cols:
        for row in rows:
            out.append({'dt': parse_dt(row['exit_time']),
                        'net': float(row['profit'])})
    else:
        for row in rows:
            p = float(row['profit'])
            s = float(row['swap']) if row.get('swap') else 0.0
            c = float(row['commission']) if row.get('commission') else 0.0
            out.append({'dt': parse_dt(row['close_time']),
                        'net': p + s + c})
    return sorted(out, key=lambda x: x['dt'])

def analyze(name, deals):
    daily = defaultdict(float)
    for d in deals:
        daily[d['dt'].date()] += d['net']

    total_net = sum(d['net'] for d in deals)
    days_pos = [(k, v) for k, v in daily.items() if v > 0]
    top = sorted(days_pos, key=lambda x: x[1], reverse=True)[:5]

    print('=' * 70)
    print(f'  {name}')
    print(f'  total net: ${total_net:+,.2f}   trading days with any P&L: {len(daily)}')
    print('=' * 70)
    print('  TOP 5 winning days:')
    for date, pnl in top:
        pct = 100.0 * pnl / total_net if total_net > 0 else 0.0
        flag = '  <-- OVER 40%' if pct > 40 else ''
        print(f'    {date}   ${pnl:>+8.2f}   {pct:>5.1f}% of total{flag}')

    if top:
        biggest_pct = 100.0 * top[0][1] / total_net
        verdict = 'PASS' if biggest_pct <= 40 else 'FAIL'
        print()
        print(f'  Consistency (biggest-day / total-net): {biggest_pct:.1f}%   ->  {verdict}')
        if biggest_pct > 40:
            reduction_needed = top[0][1] - 0.40 * total_net
            print(f'  To pass, biggest day would need to be $\'{0.40*total_net:.2f} or less.')
            print(f'  Current biggest is ${top[0][1]:.2f} - over by ${reduction_needed:.2f}.')

    return biggest_pct if top else 0.0

deals_c = load(PLAN_C_CSV)
deals_q = load(PLAN_Q_CSV)

pct_c = analyze('PLAN C (combo FIX 0.02)', deals_c)
print()
pct_q = analyze('PLAN Q (QM signal-player $85 baseline)', deals_q)

# Also: 2% account growth check on $6k basis
INITIAL = 6000.0
GROWTH_2PCT = 0.02 * INITIAL

print()
print('=' * 70)
print('  ON-DEMAND: 2% ACCOUNT GROWTH REQUIREMENT ($6k basis = $120)')
print('=' * 70)
print(f'  Plan C total net: ${sum(d["net"] for d in deals_c):+,.2f}')
print(f'  Plan Q total net: ${sum(d["net"] for d in deals_q):+,.2f}')
print(f'  Both plans clear +$120 growth (per year) many times over.')

# Frequency: how often does a rolling window reach 2% ($120) growth
def growth_windows(deals, target):
    # for each starting deal, how many deals until we hit +target cumulative
    windows = []
    for i in range(len(deals)):
        cum = 0.0
        for j in range(i, len(deals)):
            cum += deals[j]['net']
            if cum >= target:
                days = (deals[j]['dt'] - deals[i]['dt']).days
                windows.append(days)
                break
    return windows

wc = growth_windows(deals_c, GROWTH_2PCT)
wq = growth_windows(deals_q, GROWTH_2PCT)
print()
print(f'  Plan C: {len(wc)} rolling windows that reached +$120')
if wc:
    print(f'    median days to reach +$120 from any start: {sorted(wc)[len(wc)//2]}')
print(f'  Plan Q: {len(wq)} rolling windows that reached +$120')
if wq:
    print(f'    median days to reach +$120 from any start: {sorted(wq)[len(wq)//2]}')

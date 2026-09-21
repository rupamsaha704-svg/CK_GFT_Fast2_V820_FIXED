#!/usr/bin/env python3
"""
Analyze _qm_baseline_trades.csv for FundedNext compliance.

FN rules (steering Section 2 + 6):
  Daily 5% of INITIAL ($250 on $5k)  -- realized closed P&L per day, includes swap/commission
  Static 10% of INITIAL ($500 loss from initial = equity never below $4500)
  Funded 3% risk cap ($150 on $5k) -- max potential SL loss + combined open floating

We have trade-level data: entry_datetime, sl, tp, r_multiple, net.
Not available in the CSV: intraday tick MAE per open trade.
So the compliance we can compute exactly:
  - realized daily P&L (by EXIT date)
  - running balance -> DD from initial
  - concurrent open trades at any moment -> combined SL exposure
"""
import csv
import datetime as dt
from collections import defaultdict, OrderedDict

CSV = '_qm_baseline_trades.csv'
INITIAL = 5000.0

def parse_dt(s):
    return dt.datetime.strptime(s, '%Y-%m-%d %H:%M:%S')

trades = []
with open(CSV, newline='') as f:
    r = csv.DictReader(f)
    for row in r:
        trades.append({
            'entry_dt': parse_dt(row['entry_datetime']),
            'exit_dt' : parse_dt(row['exit_datetime']),
            'dir'     : row['direction'],
            'entry_px': float(row['entry_price']),
            'sl_px'   : float(row['sl']),
            'tp_px'   : float(row['tp']),
            'exit_kind': row['exit_kind'],
            'r'       : float(row['r_multiple']),
            'net'     : float(row['net']),
        })

trades.sort(key=lambda t: t['entry_dt'])
print(f"=== QM/ICT baseline trades: {len(trades)} ===")
print(f"Window: {trades[0]['entry_dt']} -> {trades[-1]['entry_dt']}")

# --- Basic stats ---
wins = [t for t in trades if t['net'] > 0]
losses = [t for t in trades if t['net'] < 0]
gross_win = sum(t['net'] for t in wins)
gross_loss = sum(t['net'] for t in losses)  # negative
net_total = gross_win + gross_loss
pf = (gross_win / abs(gross_loss)) if gross_loss < 0 else float('inf')
win_rate = 100.0 * len(wins) / len(trades)
print(f"\n=== Overall performance ===")
print(f"  Net: ${net_total:+.2f}  ({100*net_total/INITIAL:+.2f}% of $5k)")
print(f"  Wins: {len(wins)} ({win_rate:.1f}%), avg win ${gross_win/max(len(wins),1):.2f}")
print(f"  Losses: {len(losses)} ({100.0*len(losses)/len(trades):.1f}%), avg loss ${gross_loss/max(len(losses),1):.2f}")
print(f"  PF: {pf:.3f}, expectancy: ${net_total/len(trades):+.2f}/trade")

# --- Daily realized P&L (by exit date) ---
daily_pl = defaultdict(float)
for t in trades:
    daily_pl[t['exit_dt'].date()] += t['net']

daily_sorted = sorted(daily_pl.items())
worst_day = min(daily_sorted, key=lambda x: x[1])
best_day = max(daily_sorted, key=lambda x: x[1])
days_over_neg250 = [(d, p) for d, p in daily_sorted if p <= -250.0]
days_over_neg225 = [(d, p) for d, p in daily_sorted if p <= -225.0]
days_over_neg200 = [(d, p) for d, p in daily_sorted if p <= -200.0]
days_over_neg150 = [(d, p) for d, p in daily_sorted if p <= -150.0]

print(f"\n=== FN Daily 5% rule ($250 hard, $225 buffer) ===")
print(f"  Worst day: {worst_day[0]} = ${worst_day[1]:.2f} ({100*worst_day[1]/INITIAL:+.2f}% of INITIAL)")
print(f"  Best day: {best_day[0]} = ${best_day[1]:+.2f}")
print(f"  Days <= -$250 (HARD BREACH): {len(days_over_neg250)}")
if days_over_neg250:
    for d, p in days_over_neg250[:10]:
        print(f"    {d}: ${p:.2f} = {100*p/INITIAL:.2f}%")
print(f"  Days <= -$225 (buffer touch): {len(days_over_neg225)}")
print(f"  Days <= -$200: {len(days_over_neg200)}")
print(f"  Days <= -$150 (3% risk approx): {len(days_over_neg150)}")

# --- Running balance / DD from initial ---
balance = INITIAL
min_balance = INITIAL
min_balance_date = None
peak = INITIAL
max_dd_from_peak = 0.0
max_dd_from_initial = 0.0

# trades processed by exit time (realized order)
by_exit = sorted(trades, key=lambda t: t['exit_dt'])
for t in by_exit:
    balance += t['net']
    if balance > peak:
        peak = balance
    dd_from_peak = peak - balance
    dd_from_initial = INITIAL - balance
    if dd_from_peak > max_dd_from_peak:
        max_dd_from_peak = dd_from_peak
    if dd_from_initial > max_dd_from_initial:
        max_dd_from_initial = dd_from_initial
    if balance < min_balance:
        min_balance = balance
        min_balance_date = t['exit_dt']

print(f"\n=== FN Static 10% rule ($4,500 floor / -$500 from initial) ===")
print(f"  Final balance: ${balance:.2f}")
print(f"  Peak balance : ${peak:.2f}")
print(f"  Min balance  : ${min_balance:.2f} (at {min_balance_date})")
print(f"  Max DD from initial: ${max_dd_from_initial:.2f} ({100*max_dd_from_initial/INITIAL:.2f}%)")
print(f"  Max DD from peak   : ${max_dd_from_peak:.2f} ({100*max_dd_from_peak/peak:.2f}%)")
if min_balance <= 4500:
    print(f"  *** STATIC BREACH: min balance {min_balance:.2f} <= $4,500 floor ***")
else:
    print(f"  Static: SAFE (min balance ${min_balance:.2f} > $4,500)")

# --- Concurrent open trades (combined SL risk snapshot) ---
# For every trade, count how many OTHER trades are open at its entry time
per_trade_risk = 100.0  # each trade risks $100 (2% of $5k) at SL

max_concurrent = 0
max_concurrent_dt = None
concurrent_snapshots = []
for i, t in enumerate(trades):
    open_at_entry = 0
    open_trades = []
    for j, o in enumerate(trades):
        if o['entry_dt'] <= t['entry_dt'] < o['exit_dt']:
            open_at_entry += 1
            open_trades.append(j)
    # combined potential loss if all stop out simultaneously
    combined_risk = open_at_entry * per_trade_risk
    concurrent_snapshots.append((t['entry_dt'], open_at_entry, combined_risk))
    if open_at_entry > max_concurrent:
        max_concurrent = open_at_entry
        max_concurrent_dt = t['entry_dt']

overlap_events = [(dt_, n, r) for dt_, n, r in concurrent_snapshots if n > 1]
print(f"\n=== FN Funded 3% rule (combined risk <= $150) ===")
print(f"  Max concurrent trades open: {max_concurrent} (at {max_concurrent_dt})")
print(f"  Max combined SL risk: ${max_concurrent * per_trade_risk:.2f} ({100*max_concurrent*per_trade_risk/INITIAL:.2f}% of INITIAL)")
print(f"  Moments with 2+ trades open: {len(overlap_events)}")
if max_concurrent * per_trade_risk > 150:
    print(f"  *** FUNDED 3% RULE BREACH: ${max_concurrent*per_trade_risk} > $150 ***")
    print(f"     Fix: cap max_trades_per_day=1 OR combined-floating flatten under $150")
else:
    print(f"  Funded 3%: SAFE")

# --- Monthly P&L breakdown ---
monthly = defaultdict(float)
for t in trades:
    key = t['exit_dt'].strftime('%Y-%m')
    monthly[key] += t['net']

print(f"\n=== Monthly realized P&L ===")
for m in sorted(monthly.keys()):
    print(f"  {m}: ${monthly[m]:+.2f}")

# --- Summary compliance verdict ---
print(f"\n{'='*70}")
print(f"  FUNDEDNEXT COMPLIANCE SUMMARY (baseline QM/ICT, $5000 initial)")
print(f"{'='*70}")
daily_ok = len(days_over_neg250) == 0
static_ok = min_balance > 4500
funded_ok = max_concurrent * per_trade_risk <= 150
print(f"  [{'PASS' if daily_ok else 'FAIL'}] Daily 5% ($250)   worst day = ${worst_day[1]:.2f}")
print(f"  [{'PASS' if static_ok else 'FAIL'}] Static 10% ($4,500) min balance = ${min_balance:.2f}")
print(f"  [{'PASS' if funded_ok else 'FAIL'}] Funded 3% ($150) max combined risk = ${max_concurrent*per_trade_risk:.0f}")

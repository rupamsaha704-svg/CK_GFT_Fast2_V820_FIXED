#!/usr/bin/env python3
"""
Forensic loss analysis of the QM baseline trade set (158 trades over 11.7 months).

Purpose (per steering forensic-journal discipline):
  - Where are the losses clustered? (day, hour, direction, market regime)
  - What is the SINGLE biggest avoidable loss cluster?
  - Report ONE actionable hypothesis, do not batch-tune.

Basis: FundedNext Stellar 2-Step $6,000 account.
  Daily 5% = $300, Static 10% = $5,400 floor, Funded 3% = $180.
"""
import csv
import datetime as dt
from collections import defaultdict, Counter

CSV = '_qm_baseline_trades.csv'
INITIAL = 6000.0
DAILY_LIMIT = 300.0
STATIC_FLOOR = 5400.0
FUNDED_RISK = 180.0

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
            'projected_rr': float(row['projected_rr']),
        })
trades.sort(key=lambda t: t['entry_dt'])
print(f"=== QM baseline forensic ($6k FN basis) ===")
print(f"  {len(trades)} trades, {trades[0]['entry_dt'].date()} -> {trades[-1]['entry_dt'].date()}")

# --- 1. FN COMPLIANCE at $6k, $100/trade risk ---
daily_pl = defaultdict(float)
for t in trades:
    daily_pl[t['exit_dt'].date()] += t['net']

worst_days = sorted(daily_pl.items(), key=lambda x: x[1])[:10]
best_days = sorted(daily_pl.items(), key=lambda x: -x[1])[:5]

# balance walk (by exit order)
balance = INITIAL; peak = INITIAL; min_bal = INITIAL; min_bal_date = None
max_dd_initial = 0.0
by_exit = sorted(trades, key=lambda t: t['exit_dt'])
for t in by_exit:
    balance += t['net']
    if balance > peak: peak = balance
    if balance < min_bal: min_bal = balance; min_bal_date = t['exit_dt']
    dd_initial = INITIAL - balance
    if dd_initial > max_dd_initial: max_dd_initial = dd_initial

# concurrent open trades
max_conc = 0
for t in trades:
    n_open = sum(1 for o in trades if o['entry_dt'] <= t['entry_dt'] < o['exit_dt'])
    if n_open > max_conc: max_conc = n_open

print(f"\n=== FN compliance at $6k initial, $100/trade risk ===")
print(f"  Daily worst: {worst_days[0][0]} = ${worst_days[0][1]:.2f}  ({100*worst_days[0][1]/INITIAL:+.2f}% of $6k)")
print(f"  Days <= -${DAILY_LIMIT}: {sum(1 for d,p in daily_pl.items() if p <= -DAILY_LIMIT)}")
print(f"  Static: min balance ${min_bal:.2f} (breach if <= ${STATIC_FLOOR})")
print(f"  Max DD from initial: ${max_dd_initial:.2f} ({100*max_dd_initial/INITIAL:.2f}%)")
print(f"  Max concurrent: {max_conc} trades = ${max_conc*100:.0f} combined risk")
verdict_daily = 'PASS' if worst_days[0][1] > -DAILY_LIMIT else 'FAIL'
verdict_static = 'PASS' if min_bal > STATIC_FLOOR else 'FAIL'
verdict_funded = 'PASS' if max_conc*100 <= FUNDED_RISK else 'FAIL'
print(f"  Verdict: Daily={verdict_daily}  Static={verdict_static}  Funded={verdict_funded}")

# --- 2. WORST DAYS DETAILED (top 5 worst) ---
print(f"\n=== 5 worst days (raw) ===")
for d, p in worst_days[:5]:
    trades_that_day = [t for t in trades if t['exit_dt'].date() == d]
    print(f"  {d}: ${p:+.2f}  ({len(trades_that_day)} trades)")
    for t in trades_that_day:
        print(f"    entry {t['entry_dt']} {t['dir']:<4} px={t['entry_px']:.2f} sl={t['sl_px']:.2f} exit_kind={t['exit_kind']:<7} net=${t['net']:+.2f}")

# --- 3. LOSING STREAKS ---
streak = 0
max_streak = 0
max_streak_range = (None, None)
cur_start = None
for t in trades:
    if t['net'] < 0:
        if streak == 0:
            cur_start = t['entry_dt']
        streak += 1
        if streak > max_streak:
            max_streak = streak
            max_streak_range = (cur_start, t['entry_dt'])
    else:
        streak = 0

print(f"\n=== Losing streaks ===")
print(f"  Max consecutive losses: {max_streak}")
print(f"  Range: {max_streak_range[0]} -> {max_streak_range[1]}")

# count streaks of each length
streak_counter = Counter()
streak = 0
for t in trades:
    if t['net'] < 0:
        streak += 1
    else:
        if streak > 0: streak_counter[streak] += 1
        streak = 0
if streak > 0: streak_counter[streak] += 1
print(f"  Streak distribution:")
for length in sorted(streak_counter):
    print(f"    {length}-loss streaks: {streak_counter[length]}")

# --- 4. HOUR-OF-DAY (entry hour) performance ---
by_hour = defaultdict(lambda: {'n': 0, 'wins': 0, 'net': 0.0})
for t in trades:
    h = t['entry_dt'].hour
    by_hour[h]['n'] += 1
    if t['net'] > 0: by_hour[h]['wins'] += 1
    by_hour[h]['net'] += t['net']

print(f"\n=== Entry HOUR distribution (data-tz native, likely NY) ===")
print(f"  hour | trades | wins% | net$ | avg/trade")
for h in sorted(by_hour):
    d = by_hour[h]
    wr = 100.0*d['wins']/d['n'] if d['n'] else 0
    avg = d['net']/d['n'] if d['n'] else 0
    marker = ' <-- losing hour' if d['net'] < 0 and d['n'] >= 5 else ''
    print(f"   {h:02d}   |  {d['n']:>3}   | {wr:>4.1f}% | ${d['net']:>+8.2f} | ${avg:>+7.2f}{marker}")

# --- 5. DAY-OF-WEEK performance ---
by_dow = defaultdict(lambda: {'n': 0, 'wins': 0, 'net': 0.0})
dow_names = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
for t in trades:
    d = t['entry_dt'].weekday()
    by_dow[d]['n'] += 1
    if t['net'] > 0: by_dow[d]['wins'] += 1
    by_dow[d]['net'] += t['net']

print(f"\n=== Day of Week ===")
for d in sorted(by_dow):
    v = by_dow[d]
    wr = 100.0*v['wins']/v['n'] if v['n'] else 0
    avg = v['net']/v['n'] if v['n'] else 0
    print(f"  {dow_names[d]}: {v['n']:>3} trades, wins {wr:>4.1f}%, net ${v['net']:+.2f}, avg ${avg:+.2f}")

# --- 6. BEAR vs BULL ---
by_dir = defaultdict(lambda: {'n': 0, 'wins': 0, 'net': 0.0})
for t in trades:
    by_dir[t['dir']]['n'] += 1
    if t['net'] > 0: by_dir[t['dir']]['wins'] += 1
    by_dir[t['dir']]['net'] += t['net']

print(f"\n=== Direction split ===")
for direction in ['bear', 'bull']:
    d = by_dir[direction]
    wr = 100.0*d['wins']/d['n'] if d['n'] else 0
    print(f"  {direction:<4}: {d['n']:>3} trades, wins {wr:>4.1f}%, net ${d['net']:+.2f}, avg ${d['net']/max(d['n'],1):+.2f}")

# --- 7. Projected RR distribution (for entry-quality analysis) ---
low_rr = [t for t in trades if t['projected_rr'] < 1.5]
med_rr = [t for t in trades if 1.5 <= t['projected_rr'] < 3.0]
hi_rr = [t for t in trades if t['projected_rr'] >= 3.0]
print(f"\n=== Projected RR bucketing ===")
for label, group in [('RR<1.5', low_rr), ('RR 1.5-3.0', med_rr), ('RR>=3.0', hi_rr)]:
    if group:
        wr = 100.0*sum(1 for t in group if t['net']>0)/len(group)
        avg = sum(t['net'] for t in group)/len(group)
        print(f"  {label:<12}: {len(group):>3} trades, wins {wr:>4.1f}%, avg ${avg:+.2f}")

# --- 8. First 10 trades (what killed our start?) ---
print(f"\n=== First 10 trades (initial drawdown killer) ===")
print(f"  # | entry_dt              | dir  | proj_rr | exit_kind | net")
cumulative = 0
for i, t in enumerate(trades[:10]):
    cumulative += t['net']
    print(f"  {i+1:>2}| {t['entry_dt']} | {t['dir']:<4} | {t['projected_rr']:>6.2f}  | {t['exit_kind']:<7}  | ${t['net']:>+7.2f}  (cum ${cumulative:+.2f})")

# --- 9. Losses grouped by SL type: was SL too tight? ---
sl_stops = [t for t in trades if t['exit_kind'] == 'sl']
tp_hits = [t for t in trades if t['exit_kind'] == 'tp']
timeouts = [t for t in trades if t['exit_kind'] == 'timeout']
print(f"\n=== Exit kinds ===")
print(f"  SL hit: {len(sl_stops)} ({100*len(sl_stops)/len(trades):.1f}%)")
print(f"  TP hit: {len(tp_hits)} ({100*len(tp_hits)/len(trades):.1f}%)")
print(f"  Timeout: {len(timeouts)} ({100*len(timeouts)/len(trades):.1f}%)")

# same-day SL to next SL: quick reversals?
print(f"\n=== Quick-reverse losses (SL < 30min after entry) ===")
quick_losses = [t for t in trades
                if t['exit_kind']=='sl' and (t['exit_dt']-t['entry_dt']).total_seconds() < 1800]
print(f"  {len(quick_losses)} SL hits within 30min = ${sum(t['net'] for t in quick_losses):+.2f} loss")
print(f"    (proportion of all losses: {100*len(quick_losses)/max(len(sl_stops),1):.1f}%)")

# --- 10. Hypothesis candidate: what filter would help most? ---
print(f"\n{'='*70}")
print(f"  LOSS FORENSIC SUMMARY")
print(f"{'='*70}")
print(f"  Top loss sources ranked (by $$ recoverable if filtered):")

# candidate 1: quick-reverse losses (SL within 30min)
q_loss = sum(t['net'] for t in quick_losses)
print(f"  1. Quick-reverse SL hits (<30min):   ${q_loss:+.2f}  ({len(quick_losses)} trades)")

# candidate 2: losing-hour trades (if any)
losing_hours = [h for h,d in by_hour.items() if d['net']<0 and d['n']>=5]
loser_hour_trades = [t for t in trades if t['entry_dt'].hour in losing_hours]
loser_hour_pl = sum(t['net'] for t in loser_hour_trades)
print(f"  2. Trades in net-loss hours:         ${loser_hour_pl:+.2f}  ({len(loser_hour_trades)} trades, hours {sorted(losing_hours)})")

# candidate 3: low-RR trades (<1.5 projected)
low_rr_pl = sum(t['net'] for t in low_rr)
print(f"  3. Low projected-RR trades (<1.5):   ${low_rr_pl:+.2f}  ({len(low_rr)} trades)")

# candidate 4: losing DOW
losing_dow = [d for d,v in by_dow.items() if v['net']<0 and v['n']>=5]
loser_dow_trades = [t for t in trades if t['entry_dt'].weekday() in losing_dow]
loser_dow_pl = sum(t['net'] for t in loser_dow_trades)
print(f"  4. Trades in net-loss DoW:           ${loser_dow_pl:+.2f}  ({len(loser_dow_trades)} trades, days {[dow_names[d] for d in losing_dow]})")

# candidate 5: worst-day tail — trades on the 5 worst days
worst_day_dates = {d for d,_ in worst_days[:5]}
worst_day_trades = [t for t in trades if t['exit_dt'].date() in worst_day_dates]
worst_day_pl = sum(t['net'] for t in worst_day_trades)
print(f"  5. Trades on 5 worst days:           ${worst_day_pl:+.2f}  ({len(worst_day_trades)} trades)")

# candidate 6: same-day repeat entries (2+ trades same day)
per_day = defaultdict(list)
for t in trades:
    per_day[t['entry_dt'].date()].append(t)
repeat_day_trades = [t for d,ts in per_day.items() for t in ts if len(ts)>=2]
repeat_day_pl = sum(t['net'] for t in repeat_day_trades)
print(f"  6. Same-day 2+entry trades:          ${repeat_day_pl:+.2f}  ({len(repeat_day_trades)} trades)")

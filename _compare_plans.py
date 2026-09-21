#!/usr/bin/env python3
"""
Plan C (combo_fnext_03) vs Plan Q (QM erl_h4 signal-player) side-by-side monthly + yearly
profit breakdown on FundedNext Stellar 2-Step $6,000 Funded basis.

Reads:
  Plan C: experiments/combo_fnext_journal/deals.csv (JOURNAL_FundedNext.md reference)
  Plan Q: MT5 Common\Files\qm_signalplayer_deals_baseline.csv (steering §5a reference)

Both are MT5 real-tick (Model 4) outputs -- steering §5 truth.

Auto-detects the two schemas:
  Plan C  : magic, dir, entry_time, entry_price, exit_time, exit_price, profit, volume, hold_sec, mae, mfe
  Plan Q  : close_time, type, volume, price, sl, tp, profit, swap, commission, comment

Emits:
  - overall stats per plan (net, PF, win rate, expectancy)
  - month-by-month P&L for both, aligned
  - FN $6k compliance (daily $300 line, static $5,400 floor)
  - yearly extrapolation
  - take-home @ 80% and @ 90% split minus $5 EA fee, in USD and Rs
"""
import csv
import datetime as dt
from collections import defaultdict
import os

PLAN_C_CSV = os.path.join(
    'experiments', 'combo_fnext_journal', 'deals.csv'
)
PLAN_Q_CSV = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\qm_signalplayer_deals_baseline.csv'

INITIAL       = 6000.0    # FundedNext Stellar 2-Step $6k
DAILY_LIMIT   = 300.0     # 5% of initial
STATIC_FLOOR  = 5400.0    # 90% of initial
EA_FEE_USD_PER_MONTH = 5.0
INR_PER_USD   = 115.0     # user-stated rate (steering §5a implied)

def parse_dt(s):
    # both schemas use 'YYYY.MM.DD HH:MM'
    return dt.datetime.strptime(s.strip(), '%Y.%m.%d %H:%M')

def load_deals(path, plan_name):
    """Return list of {'close_dt', 'net'} rows, auto-detecting schema."""
    with open(path, newline='') as f:
        r = csv.DictReader(f)
        cols = set(r.fieldnames or [])
        rows = list(r)
    if {'exit_time', 'profit'}.issubset(cols):
        # Plan C schema
        out = [{
            'close_dt': parse_dt(row['exit_time']),
            'entry_dt': parse_dt(row['entry_time']),
            'net': float(row['profit']),
            'volume': float(row.get('volume') or 0),
        } for row in rows]
        schema = 'plan_c'
    elif {'close_time', 'profit'}.issubset(cols):
        # Plan Q schema
        out = []
        for row in rows:
            p = float(row['profit'])
            s = float(row['swap']) if row.get('swap') else 0.0
            c = float(row['commission']) if row.get('commission') else 0.0
            out.append({
                'close_dt': parse_dt(row['close_time']),
                'entry_dt': None,     # not present in Plan Q CSV
                'net': p + s + c,     # swap + commission netted in
                'volume': float(row['volume']),
            })
        schema = 'plan_q'
    else:
        raise SystemExit(f'Unknown schema for {plan_name}: cols={cols}')
    out.sort(key=lambda x: x['close_dt'])
    return out, schema

def overall(deals):
    n = len(deals)
    wins = [d for d in deals if d['net'] > 0]
    losses = [d for d in deals if d['net'] < 0]
    gw = sum(d['net'] for d in wins)
    gl = sum(d['net'] for d in losses)
    net = gw + gl
    pf = gw / abs(gl) if gl < 0 else float('inf')
    win_rate = 100.0 * len(wins) / n if n else 0.0
    return {'n': n, 'wins': len(wins), 'losses': len(losses),
            'gw': gw, 'gl': gl, 'net': net, 'pf': pf,
            'win_rate': win_rate, 'expect': net/n if n else 0.0}

def monthly_map(deals):
    m = defaultdict(lambda: {'n':0,'wins':0,'net':0.0})
    for d in deals:
        k = d['close_dt'].strftime('%Y-%m')
        m[k]['n'] += 1
        m[k]['net'] += d['net']
        if d['net'] > 0:
            m[k]['wins'] += 1
    return dict(m)

def compliance(deals):
    daily = defaultdict(float)
    for d in deals:
        daily[d['close_dt'].date()] += d['net']
    running = INITIAL
    min_bal = INITIAL
    peak = INITIAL
    for d in deals:
        running += d['net']
        if running < min_bal: min_bal = running
        if running > peak:   peak = running
    breaches = [(k,v) for k,v in daily.items() if v <= -DAILY_LIMIT]
    worst_day = min(daily.items(), key=lambda x: x[1]) if daily else (None, 0.0)
    return {
        'daily_breaches': len(breaches),
        'worst_day_date': worst_day[0],
        'worst_day_pnl': worst_day[1],
        'min_balance': min_bal,
        'peak_balance': peak,
        'final_balance': running,
        'static_breach': min_bal <= STATIC_FLOOR,
    }

def yearly_extrapolation(deals, stats):
    if len(deals) < 2:
        return None
    span_days = (deals[-1]['close_dt'] - deals[0]['close_dt']).days
    if span_days <= 0:
        return None
    months = span_days / 30.44
    monthly_gross = stats['net'] / months
    yearly_gross = monthly_gross * 12
    return {
        'span_days': span_days,
        'months': months,
        'monthly_gross': monthly_gross,
        'yearly_gross': yearly_gross,
        'yearly_pct_on_6k': 100.0 * yearly_gross / INITIAL,
    }

def take_home(yearly_gross, split_pct, fee_usd):
    monthly_after_split = (yearly_gross * split_pct / 100.0) / 12.0
    monthly_after_fee = monthly_after_split - fee_usd
    return {
        'usd_per_month': monthly_after_fee,
        'usd_per_year' : monthly_after_fee * 12.0,
        'inr_per_month': monthly_after_fee * INR_PER_USD,
        'inr_per_year' : monthly_after_fee * 12.0 * INR_PER_USD,
    }

def print_plan(name, csv_path, deals, schema):
    stats = overall(deals)
    comp = compliance(deals)
    yr   = yearly_extrapolation(deals, stats)
    print('=' * 78)
    print(f'  {name}  ({schema})')
    print(f'  source: {csv_path}')
    print(f'  window: {deals[0]["close_dt"].date()} .. {deals[-1]["close_dt"].date()}   deals: {stats["n"]}')
    print('=' * 78)
    print(f'  net (all-in)        : ${stats["net"]:+,.2f}   ({100*stats["net"]/INITIAL:+.2f}% on $6k)')
    print(f'  gross wins/losses   : ${stats["gw"]:+,.2f} / ${stats["gl"]:+,.2f}')
    print(f'  PF                  : {stats["pf"]:.3f}')
    print(f'  win rate            : {stats["win_rate"]:.1f}%  ({stats["wins"]}/{stats["n"]})')
    print(f'  expectancy / trade  : ${stats["expect"]:+.2f}')
    print('  ---')
    print(f'  FN daily breaches   : {comp["daily_breaches"]}    (worst day ${comp["worst_day_pnl"]:+.2f} on {comp["worst_day_date"]})')
    verdict_daily = 'PASS' if comp["daily_breaches"] == 0 else f'FAIL ({comp["daily_breaches"]} days)'
    print(f'  FN daily verdict    : {verdict_daily}')
    verdict_static = 'PASS' if not comp["static_breach"] else 'FAIL'
    print(f'  FN static verdict   : {verdict_static}    (min balance ${comp["min_balance"]:.2f})')
    print(f'  peak / final balance: ${comp["peak_balance"]:.2f} / ${comp["final_balance"]:.2f}')
    if yr:
        print('  ---')
        print(f'  window span         : {yr["span_days"]} days = {yr["months"]:.2f} months')
        print(f'  monthly gross avg   : ${yr["monthly_gross"]:+.2f}')
        print(f'  yearly extrapolated : ${yr["yearly_gross"]:+,.2f}   ({yr["yearly_pct_on_6k"]:+.2f}% on $6k)')
        th80 = take_home(yr['yearly_gross'], 80, EA_FEE_USD_PER_MONTH)
        th90 = take_home(yr['yearly_gross'], 90, EA_FEE_USD_PER_MONTH)
        print('  ---')
        print(f'  take-home @ 80% split, minus $5 EA fee/mo:')
        print(f'    ${th80["usd_per_month"]:+.2f}/mo    (~Rs {th80["inr_per_month"]:>+8,.0f}/mo)')
        print(f'    ${th80["usd_per_year"]:+.2f}/yr    (~Rs {th80["inr_per_year"]:>+8,.0f}/yr)')
        print(f'  take-home @ 90% split, minus $5 EA fee/mo:')
        print(f'    ${th90["usd_per_month"]:+.2f}/mo    (~Rs {th90["inr_per_month"]:>+8,.0f}/mo)')
        print(f'    ${th90["usd_per_year"]:+.2f}/yr    (~Rs {th90["inr_per_year"]:>+8,.0f}/yr)')
    return stats, comp, yr

def print_monthly_side_by_side(name_c, deals_c, name_q, deals_q):
    m_c = monthly_map(deals_c)
    m_q = monthly_map(deals_q)
    all_keys = sorted(set(m_c.keys()) | set(m_q.keys()))
    print()
    print('=' * 78)
    print(f'  MONTHLY BREAKDOWN -- {name_c} vs {name_q}  (net USD)')
    print('=' * 78)
    print(f'  {"month":<8}   {name_c:>16}   {name_q:>16}    delta')
    print(f'  {"":<8}   {"trades":>7} {"net":>8}   {"trades":>7} {"net":>8}   {"C-Q":>7}')
    run_c = 0.0
    run_q = 0.0
    for k in all_keys:
        dc = m_c.get(k, {'n':0,'net':0.0})
        dq = m_q.get(k, {'n':0,'net':0.0})
        run_c += dc['net']
        run_q += dq['net']
        delta = dc['net'] - dq['net']
        print(f'  {k:<8}   {dc["n"]:>7} ${dc["net"]:>+7.2f}   {dq["n"]:>7} ${dq["net"]:>+7.2f}   ${delta:>+6.2f}')
    print(f'  {"total":<8}   {sum(x["n"] for x in m_c.values()):>7} ${run_c:>+7.2f}   {sum(x["n"] for x in m_q.values()):>7} ${run_q:>+7.2f}   ${run_c-run_q:>+6.2f}')

if __name__ == '__main__':
    if not os.path.isfile(PLAN_C_CSV):
        print('MISSING:', PLAN_C_CSV); raise SystemExit(2)
    if not os.path.isfile(PLAN_Q_CSV):
        print('MISSING:', PLAN_Q_CSV); raise SystemExit(2)
    deals_c, sch_c = load_deals(PLAN_C_CSV, 'Plan C')
    deals_q, sch_q = load_deals(PLAN_Q_CSV, 'Plan Q')

    stats_c, comp_c, yr_c = print_plan('PLAN C  (CK_GOLD_COMBO FIX 0.02 -- combo_fnext_journal)', PLAN_C_CSV, deals_c, sch_c)
    print()
    stats_q, comp_q, yr_q = print_plan('PLAN Q  (CK_QM_SignalPlayer erl_h4 -- baseline $85 risk)', PLAN_Q_CSV, deals_q, sch_q)

    print_monthly_side_by_side('Plan C', deals_c, 'Plan Q', deals_q)

    # Winner
    print()
    print('=' * 78)
    print('  WINNER (yearly extrapolated, take-80 minus $5 EA fee)')
    print('=' * 78)
    if yr_c and yr_q:
        th80_c = take_home(yr_c['yearly_gross'], 80, EA_FEE_USD_PER_MONTH)
        th80_q = take_home(yr_q['yearly_gross'], 80, EA_FEE_USD_PER_MONTH)
        print(f'  Plan C: ${th80_c["usd_per_month"]:+.2f}/mo  (Rs {th80_c["inr_per_month"]:>+8,.0f})   ${th80_c["usd_per_year"]:+.0f}/yr')
        print(f'  Plan Q: ${th80_q["usd_per_month"]:+.2f}/mo  (Rs {th80_q["inr_per_month"]:>+8,.0f})   ${th80_q["usd_per_year"]:+.0f}/yr')
        if th80_c["usd_per_month"] > th80_q["usd_per_month"]:
            delta = th80_c["usd_per_month"] - th80_q["usd_per_month"]
            print(f'  -> Plan C wins by ${delta:.2f}/mo  ({100*delta/th80_q["usd_per_month"]:+.1f}%)')
        else:
            delta = th80_q["usd_per_month"] - th80_c["usd_per_month"]
            print(f'  -> Plan Q wins by ${delta:.2f}/mo  ({100*delta/th80_c["usd_per_month"]:+.1f}%)')

    # Plan Q at "safe $75" risk (funded stage sizing, steering §7)
    if yr_q:
        SAFE_RISK_SCALE = 75.0 / 85.0
        safe_yearly = yr_q['yearly_gross'] * SAFE_RISK_SCALE
        th80_q_safe = take_home(safe_yearly, 80, EA_FEE_USD_PER_MONTH)
        th90_q_safe = take_home(safe_yearly, 90, EA_FEE_USD_PER_MONTH)
        print()
        print(f'  Plan Q SCALED to $75 safe-risk (funded 3%-rule buffer, steering §7):')
        print(f'    take-80: ${th80_q_safe["usd_per_month"]:+.2f}/mo  (Rs {th80_q_safe["inr_per_month"]:>+8,.0f})   ${th80_q_safe["usd_per_year"]:+.0f}/yr')
        print(f'    take-90: ${th90_q_safe["usd_per_month"]:+.2f}/mo  (Rs {th90_q_safe["inr_per_month"]:>+8,.0f})   ${th90_q_safe["usd_per_year"]:+.0f}/yr')

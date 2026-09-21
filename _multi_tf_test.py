#!/usr/bin/env python3
"""
Multi-timeframe variant sweep on QM/ICT baseline with dedupe fix.

Tests several TF-related variants against the same M15/M5 data, dedupes duplicate
same-setup trades (Python engine bug where a single POI zone can be detected twice),
and computes FundedNext compliance on a $6,000 account for each.

Steering forensic-journal discipline: this is EXPLORATION. Only ONE variant will
be pre-registered + locked afterwards, based on which best satisfies the pre-declared
PASS bar. No batch tuning; no picking the winner without a locked criterion.
"""
import sys
import os
import csv
import datetime as dt
from collections import defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'v1_lab'))
from qm_state_machine import run, make_config, DEFAULT_CONFIG  # noqa
from qm_detect import load_ohlc  # noqa

# ---- config ----
INITIAL = 6000.0                # FN Stellar 2-Step actual smallest ($6k, ledger seq260)
DAILY_LIMIT = 300.0             # 5% of $6k
STATIC_FLOOR = 5400.0           # 10% floor
FUNDED_RISK = 180.0             # 3% risk cap
RISK_PER_TRADE = 100.0          # default engine sizing ($100 = 1.67% of $6k)

M15_PATH = 'XAUUSD_M15_export.csv'
M5_PATH  = 'XAUUSD_M5_202508010105_202607271000.csv'

# ---- variants to test ----
# Each is a single-switch delta from baseline (default). Reason for each in comment.
VARIANTS = [
    # timeframe-axis variants (user asked "shob timeframe dekho")
    ('baseline_h1', {}),                                # baseline: erl_tf=H1
    ('erl_h4',     {'erl_tf': 'H4'}),                    # HIGHER TF ERL - broader liquidity context
    ('erl_m15',    {'erl_tf': 'M15'}),                   # LOWER TF ERL - tighter/faster
    # displacement gate (structural sensitivity)
    ('disp_0p4',   {'disp': 0.4}),                       # looser MSS = more shifts = more trades
    ('disp_0p8',   {'disp': 0.8}),                       # stricter MSS = fewer, higher-quality
    # trend filter (best-quality variant from prior report)
    ('ema_bias',   {'htf_ema_bias': True}),              # EMA200 on M15 - reduces countertrend signals
    # fixed-RR target (may improve win rate at cost of runners)
    ('rr_3',       {'tp_mode': 'fixed_rr', 'fixed_rr': 3.0}),
    ('minrr_1p5',  {'min_projected_rr': 1.5}),           # reject low-RR setups (was $-25/trade avg)
]

def dedupe_trades(trades):
    """Drop trades that share (entry_datetime, entry_price, sl, tp, direction) with an earlier trade."""
    seen = set()
    out = []
    for t in trades:
        key = (t['entry_datetime'], round(t['entry_price'],5), round(t['sl'],5),
               round(t['tp'],5), t['direction'])
        if key in seen:
            continue
        seen.add(key)
        out.append(t)
    return out

def compute_metrics(trades, initial=INITIAL):
    if not trades:
        return None
    n = len(trades)
    wins  = [t for t in trades if t['net'] > 0]
    losses= [t for t in trades if t['net'] < 0]
    gw = sum(t['net'] for t in wins)
    gl = sum(t['net'] for t in losses)  # negative
    net = gw + gl
    pf = gw / abs(gl) if gl < 0 else float('inf')
    win_rate = 100.0*len(wins)/n
    exp = net/n

    # daily P&L
    daily = defaultdict(float)
    for t in trades:
        daily[t['exit_datetime'].date()] += t['net']
    worst_day = min(daily.values()) if daily else 0
    n_daily_breach = sum(1 for p in daily.values() if p <= -DAILY_LIMIT)

    # balance walk
    balance = initial
    min_bal = initial
    for t in sorted(trades, key=lambda x: x['exit_datetime']):
        balance += t['net']
        if balance < min_bal:
            min_bal = balance

    # max concurrent
    max_conc = 0
    for t in trades:
        n_open = sum(1 for o in trades if o['entry_datetime'] <= t['entry_datetime'] < o['exit_datetime'])
        if n_open > max_conc:
            max_conc = n_open
    max_combined = max_conc * RISK_PER_TRADE

    daily_ok  = worst_day > -DAILY_LIMIT
    static_ok = min_bal   > STATIC_FLOOR
    funded_ok = max_combined <= FUNDED_RISK

    return {
        'n': n, 'wins': len(wins), 'losses': len(losses),
        'win_rate': win_rate, 'pf': pf, 'exp': exp, 'net': net,
        'worst_day': worst_day, 'n_daily_breach': n_daily_breach,
        'min_bal': min_bal, 'max_conc': max_conc, 'max_combined': max_combined,
        'daily_ok': daily_ok, 'static_ok': static_ok, 'funded_ok': funded_ok,
        'all_pass': daily_ok and static_ok and funded_ok,
    }

def fmt_row(name, m, note=''):
    return (f"{name:<15} | {m['n']:>3} | {m['win_rate']:>4.1f}% | "
            f"{m['pf']:>5.2f} | ${m['net']:>+7.0f} | ${m['worst_day']:>+6.0f} | "
            f"{'D' if m['daily_ok'] else '.'}{'S' if m['static_ok'] else '.'}{'F' if m['funded_ok'] else '.'} | "
            f"{note}")

def main():
    print("=" * 80)
    print("  QM/ICT MULTI-TF SWEEP  ($6k FN basis, $100/trade risk, dedupe on)")
    print("=" * 80)
    print(f"  Data: M15={M15_PATH}  M5={M5_PATH}")

    print("  Loading bars...")
    m15 = load_ohlc(M15_PATH)
    m5  = load_ohlc(M5_PATH)
    print(f"  M15 bars: {len(m15)}   M5 bars: {len(m5)}")
    print()

    results = {}
    for name, overrides in VARIANTS:
        cfg = make_config(**overrides)
        t0 = dt.datetime.now()
        trades, stats = run(m15, cfg, m5_bars=m5)
        elapsed = (dt.datetime.now() - t0).total_seconds()

        # dedupe
        pre = len(trades)
        trades = dedupe_trades(trades)
        n_dedupe = pre - len(trades)

        m = compute_metrics(trades)
        results[name] = m
        print(f"  {name:<15} {elapsed:>5.1f}s  raw={pre}  dedup_removed={n_dedupe}  final={m['n']}  "
              f"PF={m['pf']:.2f}  worst_day=${m['worst_day']:.0f}  "
              f"FN=[{'D' if m['daily_ok'] else '.'}{'S' if m['static_ok'] else '.'}{'F' if m['funded_ok'] else '.'}]")

    # ranked table
    print()
    print("=" * 80)
    print("  RANKED RESULTS (by PF, dedupe applied, $6k basis)")
    print("=" * 80)
    print(f"  {'variant':<15} | trd | win%  |   PF  |   net   | worst_d | FN | note")
    print("  " + "-"*80)
    ranked = sorted(results.items(), key=lambda x: (-x[1]['pf'], -x[1]['exp']))
    for name, m in ranked:
        note = ''
        if m['all_pass']:
            note = '*** ALL FN RULES PASS ***'
        elif m['daily_ok'] and m['static_ok']:
            note = 'daily+static OK, funded fail (fix: lower lot or cap 1)'
        elif m['static_ok']:
            note = 'static OK, daily+funded fail'
        print("  " + fmt_row(name, m, note))

    # detail of best
    print()
    print("=" * 80)
    print("  BEST 3 IN DETAIL")
    print("=" * 80)
    for name, m in ranked[:3]:
        print(f"\n  === {name} ===")
        print(f"    trades: {m['n']}  wins {m['wins']} ({m['win_rate']:.1f}%)  losses {m['losses']}")
        print(f"    PF: {m['pf']:.3f}  expectancy ${m['exp']:+.2f}/trade  net ${m['net']:+.2f}  ")
        print(f"    return on $6k: {100*m['net']/INITIAL:+.2f}%")
        print(f"    take @80%/month: ${m['net']*0.8/12:.2f}")
        print(f"    daily worst: ${m['worst_day']:.2f}  ({m['n_daily_breach']} days breach $300)")
        print(f"    min balance: ${m['min_bal']:.2f}  (floor $5400)")
        print(f"    max concurrent: {m['max_conc']} trades = ${m['max_combined']:.0f} combined  (limit $180)")
        print(f"    FN: daily={'PASS' if m['daily_ok'] else 'FAIL'}  static={'PASS' if m['static_ok'] else 'FAIL'}  funded={'PASS' if m['funded_ok'] else 'FAIL'}")

    print()
    print("=" * 80)
    print("  vs combo_fnext_03 live (steering §7): 270 trades, +$2,240/yr, +$154/mo take80")
    print("=" * 80)

if __name__ == '__main__':
    main()

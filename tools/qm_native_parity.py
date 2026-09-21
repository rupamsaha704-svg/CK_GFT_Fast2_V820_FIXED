#!/usr/bin/env python3
r"""
Parity check: CK_QM_NATIVE_v1 vs CK_QM_SignalPlayer baseline.

Reads two deals CSVs written by MT5 OnTester with the identical schema
(close_time, type, volume, price, sl, tp, profit, swap, commission,
comment) and reports whether the native port matches the signal-player
baseline within the pre-declared parity band:

  net                   within +/-10% of baseline $2,296.08
  worst realized day    within +/-10% of baseline -$314.66
  min balance           >= $5,600 (baseline $5,353 was borderline;
                                    native must have at least that much room)
  entries               within +/-5 of baseline 88 deals

The verdict is REJECT or ADOPT -- no tuning to rescue a fail per
steering §5. If a metric misses, DIAGNOSE the block responsible
(Block 2 swings? Block 3 POI/ERL/IDM? Block 4 IDM-clear? Block 5
fill timing?), fix the port, re-run. Do not adjust parameters to
force a pass.

Usage:
    python tools/qm_native_parity.py
    # or
    python tools/qm_native_parity.py --native <path> --baseline <path>
"""
import argparse, csv, datetime as dt, os, sys
from collections import defaultdict

DEFAULT_NATIVE = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\ck_qm_native_deals.csv'
DEFAULT_BASELINE = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\qm_signalplayer_deals_baseline.csv'

INITIAL = 6000.0

BASELINE_NET_USD          = 2296.08
BASELINE_WORST_DAY_USD    = -314.66
BASELINE_MIN_BALANCE_USD  = 5353.50
BASELINE_DEALS            = 88
BASELINE_PF               = 1.492
BASELINE_WIN_RATE_PCT     = 22.7

# Pre-registered parity band (steering §5 discipline).
PASS_NET_PCT              = 10.0          # native net within +/-10% of baseline net
PASS_WORST_DAY_PCT        = 10.0
PASS_MIN_BALANCE_USD      = 5600.0        # keep native ABOVE the baseline's $5,353 borderline
PASS_DEALS_TOLERANCE      = 5

def parse_dt(s):
    return dt.datetime.strptime(s.strip(), '%Y.%m.%d %H:%M')

def load(path):
    if not os.path.isfile(path):
        return []
    out = []
    with open(path, newline='') as f:
        r = csv.DictReader(f)
        for row in r:
            try:
                p = float(row['profit'])
                s = float(row.get('swap') or 0.0)
                c = float(row.get('commission') or 0.0)
                out.append({
                    'close_dt': parse_dt(row['close_time']),
                    'net'     : p + s + c,
                    'volume'  : float(row['volume']),
                })
            except Exception:
                continue
    out.sort(key=lambda x: x['close_dt'])
    return out

def summary(deals, label):
    n = len(deals)
    if n == 0:
        return {'label': label, 'n': 0, 'net': 0.0, 'pf': 0.0, 'win_rate': 0.0,
                'worst_day': 0.0, 'min_balance': INITIAL, 'peak': INITIAL,
                'max_dd': 0.0}
    wins = [d for d in deals if d['net'] > 0]
    losses = [d for d in deals if d['net'] < 0]
    gw = sum(d['net'] for d in wins)
    gl = sum(d['net'] for d in losses)
    net = gw + gl
    pf  = gw / abs(gl) if gl < 0 else float('inf')

    daily = defaultdict(float)
    for d in deals:
        daily[d['close_dt'].date()] += d['net']
    worst_day = min(daily.values()) if daily else 0.0

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

    return {
        'label': label, 'n': n, 'net': net, 'gw': gw, 'gl': gl, 'pf': pf,
        'win_rate': 100.0 * len(wins) / n,
        'worst_day': worst_day,
        'min_balance': min_bal, 'peak': peak, 'max_dd': max_dd,
    }

def print_side(s):
    print(f"  {s['label']:<40}  deals={s['n']}  net=${s['net']:+,.2f}  PF={s['pf']:.3f}  win={s['win_rate']:.1f}%")
    print(f"    worst day ${s['worst_day']:+.2f}  min bal ${s['min_balance']:.2f}  max DD ${s['max_dd']:.2f}")

def within_pct(actual, target, band_pct):
    if target == 0: return actual == 0
    return abs(actual - target) / abs(target) * 100.0 <= band_pct

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--native',   default=DEFAULT_NATIVE)
    ap.add_argument('--baseline', default=DEFAULT_BASELINE)
    args = ap.parse_args()

    print('=' * 78)
    print('  CK_QM_NATIVE_v1 -- signal-player parity check')
    print('=' * 78)
    print(f'  native   : {args.native}')
    print(f'  baseline : {args.baseline}')
    print()

    native = load(args.native)
    baseline = load(args.baseline)

    if not baseline:
        print(f'  BASELINE MISSING at {args.baseline}')
        print('  Cannot run parity check without the signal-player deals CSV.')
        sys.exit(2)
    if not native:
        print(f'  NATIVE MISSING at {args.native}')
        print('  Run the MT5 backtest first (CK_QM_NATIVE_v1 Model 4 real ticks).')
        sys.exit(2)

    s_base = summary(baseline, 'BASELINE (signal-player)')
    s_nat  = summary(native,   'NATIVE (Block 1..7 port)')

    print('  METRICS')
    print_side(s_base)
    print_side(s_nat)
    print()

    # ---- pass/fail bar ----
    b1 = within_pct(s_nat['net'],       BASELINE_NET_USD,       PASS_NET_PCT)
    b2 = within_pct(s_nat['worst_day'], BASELINE_WORST_DAY_USD, PASS_WORST_DAY_PCT)
    b3 = s_nat['min_balance'] >= PASS_MIN_BALANCE_USD
    b4 = abs(s_nat['n'] - BASELINE_DEALS) <= PASS_DEALS_TOLERANCE

    def flag(v): return 'PASS' if v else 'FAIL'

    print('  PRE-REGISTERED PARITY BAR (steering §5 discipline):')
    print(f'    #1 net within ±{PASS_NET_PCT:.0f}% of ${BASELINE_NET_USD:+.2f}       : {flag(b1)}   (${s_nat["net"]:+.2f})')
    print(f'    #2 worst day within ±{PASS_WORST_DAY_PCT:.0f}% of ${BASELINE_WORST_DAY_USD:+.2f}   : {flag(b2)}   (${s_nat["worst_day"]:+.2f})')
    print(f'    #3 min balance >= ${PASS_MIN_BALANCE_USD:.0f}                           : {flag(b3)}   (${s_nat["min_balance"]:.2f})')
    print(f'    #4 entries within ±{PASS_DEALS_TOLERANCE} of {BASELINE_DEALS}                       : {flag(b4)}   ({s_nat["n"]})')
    print()

    all_pass = b1 and b2 and b3 and b4
    print(f'  ALL FOUR PASS? {all_pass}')
    if all_pass:
        print()
        print('  VERDICT: ADOPT -- native replaces signal-player as production engine.')
        print('  Log an ADOPT record in SPEC/dof_ledger.jsonl with these metric deltas.')
    else:
        print()
        print('  VERDICT: REJECT -- port has a delta the pre-reg does not allow.')
        print('  DIAGNOSE the responsible block (do NOT tune parameters):')
        if not b4:
            print('   - entry count off by more than ±5: check Block 2/3 (swings + MSS + POI)')
        if not b1 or not b2:
            print('   - net or worst-day off: check Block 5 fill timing + SL/TP geometry')
        if not b3:
            print('   - min balance too low: probably wider losses than baseline; check Block 6 gates + Block 5 SL rule')
        print('   Fix the port block, re-run, re-check. Log REJECT in the ledger with the failing metric(s).')

    # correlation with plan c (informational, not gating)
    print()
    print('  Informational: monthly overlap with signal-player baseline follows below.')
    m_base = defaultdict(lambda: {'n':0, 'net':0.0})
    m_nat  = defaultdict(lambda: {'n':0, 'net':0.0})
    for d in baseline:
        k = d['close_dt'].strftime('%Y-%m'); m_base[k]['n'] += 1; m_base[k]['net'] += d['net']
    for d in native:
        k = d['close_dt'].strftime('%Y-%m'); m_nat[k]['n'] += 1; m_nat[k]['net'] += d['net']
    keys = sorted(set(m_base) | set(m_nat))
    print(f'    {"month":<8} {"base_n":>6} {"base_net":>10} {"nat_n":>6} {"nat_net":>10} {"delta":>10}')
    for k in keys:
        b = m_base.get(k, {'n':0, 'net':0.0})
        n = m_nat.get(k, {'n':0, 'net':0.0})
        print(f'    {k:<8} {b["n"]:>6} ${b["net"]:>+8.2f} {n["n"]:>6} ${n["net"]:>+8.2f} ${b["net"]-n["net"]:>+8.2f}')

if __name__ == '__main__':
    main()

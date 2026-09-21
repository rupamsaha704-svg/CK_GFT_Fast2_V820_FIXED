#!/usr/bin/env python3
"""
Portfolio analysis: combo_fnext_03 + QM erl_h4 dedupe (H1 baseline).

Question: if we run both strategies on the SAME $6k FundedNext account with
mutual exclusion (max 1 open trade at any moment across both), what's the
combined monthly income?

Method:
  1. Load combo trades and QM trades within OVERLAPPING window
  2. Scale combo to same lot basis if needed
  3. Merge chronologically; if a new trade would overlap an already-open one, SKIP it
  4. Compute combined monthly P&L
  5. Compare vs each alone
"""
import csv
import datetime as dt
from collections import defaultdict

COMBO_DEALS = r'experiments/combo_fnext_03/deals.csv'
QM_DEALS    = r'C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\qm_signalplayer_deals_baseline.csv'

INITIAL = 6000.0
FUNDED_3PCT = 180.0
DAILY_LIMIT = 300.0

def load_combo():
    """combo_fnext_03/deals.csv - format: magic, dir, entry_time, entry_price, exit_time, exit_price, profit, volume, hold_sec, mae, mfe"""
    trades = []
    with open(COMBO_DEALS, newline='') as f:
        r = csv.DictReader(f)
        for row in r:
            trades.append({
                'src': 'combo',
                'dir': row['dir'],
                'entry_dt': dt.datetime.strptime(row['entry_time'], '%Y.%m.%d %H:%M'),
                'exit_dt' : dt.datetime.strptime(row['exit_time' ], '%Y.%m.%d %H:%M'),
                'entry_px': float(row['entry_price']),
                'exit_px' : float(row['exit_price']),
                'volume'  : float(row['volume']),
                'profit'  : float(row['profit']),
                'net'     : float(row['profit']),   # combo CSV doesn't split swap/comm
            })
    return trades

def load_qm():
    """QM signal-player deals: close_time, type, volume, price, sl, tp, profit, swap, commission, comment"""
    trades = []
    with open(QM_DEALS, newline='') as f:
        r = csv.DictReader(f)
        for row in r:
            close_dt = dt.datetime.strptime(row['close_time'], '%Y.%m.%d %H:%M')
            profit = float(row['profit'])
            swap = float(row['swap']) if row['swap'] else 0.0
            comm = float(row['commission']) if row['commission'] else 0.0
            trades.append({
                'src': 'qm',
                'exit_dt': close_dt,
                # entry_dt for QM isn't in this CSV; we approximate as exit_dt - default hold time
                # For overlap analysis this is imperfect but ok
                'entry_dt': close_dt - dt.timedelta(hours=4),  # avg hold assumption
                'exit_px': float(row['price']),
                'volume': float(row['volume']),
                'profit': profit,
                'net': profit + swap + comm,
                'type': row['type'],
            })
    return trades

def stats(name, trades):
    n = len(trades)
    net = sum(t['net'] for t in trades)
    wins = [t for t in trades if t['net'] > 0]
    losses = [t for t in trades if t['net'] < 0]
    gw = sum(t['net'] for t in wins)
    gl = sum(t['net'] for t in losses)
    pf = gw/abs(gl) if gl < 0 else float('inf')
    return {
        'name': name, 'n': n, 'net': net,
        'wins': len(wins), 'losses': len(losses),
        'pf': pf, 'win_rate': 100*len(wins)/max(n,1),
        'first_dt': min((t['exit_dt'] for t in trades), default=None),
        'last_dt' : max((t['exit_dt'] for t in trades), default=None),
    }

def print_stats(s):
    n_days = (s['last_dt']-s['first_dt']).days if s['first_dt'] and s['last_dt'] else 0
    months = n_days/30.44 if n_days else 1
    print(f"\n  === {s['name']} ===")
    print(f"    trades  : {s['n']}   window: {s['first_dt']} -> {s['last_dt']} ({months:.1f} mo)")
    print(f"    net     : ${s['net']:+.2f}   ({100*s['net']/INITIAL:+.2f}% on $6k)")
    print(f"    wins/losses: {s['wins']}/{s['losses']}  ({s['win_rate']:.1f}% wr)")
    print(f"    PF      : {s['pf']:.3f}")
    print(f"    per year: ${(s['net']/months*12):+.2f}   per month: ${s['net']/months:+.2f}")

def scale_combo_to_02_lot(combo):
    """combo CSV is 0.03 lot; live shipping is 0.02 lot. Scale profits 2/3."""
    scaled = []
    for t in combo:
        t2 = dict(t)
        t2['profit'] = t['profit'] * (2.0/3.0)
        t2['net'] = t['net'] * (2.0/3.0)
        scaled.append(t2)
    return scaled

# ---- load ----
print("=" * 72)
print("  PORTFOLIO ANALYSIS: combo_fnext_03 (0.02 lot) + QM erl_h4 (real-tick)")
print("  Same $6k FundedNext account, mutual exclusion (max 1 open at once)")
print("=" * 72)

combo_raw = load_combo()
qm = load_qm()

# scale combo to 0.02 lot to match shipping .set
combo = scale_combo_to_02_lot(combo_raw)
print(f"\n  combo raw deals: {len(combo_raw)}, at avg lot {sum(t['volume'] for t in combo_raw)/len(combo_raw):.3f}")
print(f"  combo scaled to 0.02 lot equivalent")
print(f"  QM real-tick deals: {len(qm)} at $85 risk/trade")

# align windows: use OVERLAPPING range
qm_start = min(t['exit_dt'] for t in qm)
qm_end   = max(t['exit_dt'] for t in qm)
combo_start = min(t['exit_dt'] for t in combo)
combo_end   = max(t['exit_dt'] for t in combo)
overlap_start = max(qm_start, combo_start)
overlap_end   = min(qm_end, combo_end)
print(f"\n  QM window   : {qm_start.date()} to {qm_end.date()}")
print(f"  Combo window: {combo_start.date()} to {combo_end.date()}")
print(f"  Overlap     : {overlap_start.date()} to {overlap_end.date()}")

combo_ol = [t for t in combo if overlap_start <= t['exit_dt'] <= overlap_end]
qm_ol    = [t for t in qm    if overlap_start <= t['exit_dt'] <= overlap_end]

# ---- stats each alone (overlapping window) ----
s_c = stats('combo (0.02 lot) [overlap window]', combo_ol)
s_q = stats('QM erl_h4 ($85 risk) [overlap window]', qm_ol)
print_stats(s_c)
print_stats(s_q)

# ---- portfolio with mutual exclusion ----
print(f"\n  === Portfolio simulation (mutual exclusion) ===")
all_trades = sorted(combo_ol + qm_ol, key=lambda t: t['entry_dt'])

# For each trade in chronological order, admit if no other trade currently open.
open_until = dt.datetime.min
admitted = []
skipped = {'combo': 0, 'qm': 0}
for t in all_trades:
    if t['entry_dt'] >= open_until:
        admitted.append(t)
        open_until = t['exit_dt']
    else:
        skipped[t['src']] += 1

net_portfolio = sum(t['net'] for t in admitted)
n_combo_adm = sum(1 for t in admitted if t['src']=='combo')
n_qm_adm    = sum(1 for t in admitted if t['src']=='qm')

n_months = (overlap_end - overlap_start).days / 30.44
print(f"    total admitted   : {len(admitted)}  (combo {n_combo_adm}, QM {n_qm_adm})")
print(f"    skipped (overlap): combo {skipped['combo']}, QM {skipped['qm']}")
print(f"    portfolio net    : ${net_portfolio:+.2f}  ({100*net_portfolio/INITIAL:+.2f}% on $6k, {n_months:.1f} mo)")
print(f"    per month        : ${net_portfolio/n_months:+.2f}")
print(f"    per year (extrap): ${net_portfolio/n_months*12:+.2f}")

# ---- Naive sum (if they were fully uncorrelated on separate accounts) ----
print(f"\n  === Naive sum (if uncorrelated + separate account each) ===")
naive_net = s_c['net'] + s_q['net']
naive_monthly = (s_c['net']/((s_c['last_dt']-s_c['first_dt']).days/30.44) if s_c['first_dt'] else 0) + \
                (s_q['net']/((s_q['last_dt']-s_q['first_dt']).days/30.44) if s_q['first_dt'] else 0)
print(f"    naive combined net (overlap): ${naive_net:+.2f}")
print(f"    naive monthly              : ${naive_monthly:+.2f}")

# ---- FUNDED-STAGE Live income projection ----
print()
print("=" * 72)
print("  FUNDED-STAGE LIVE INCOME PROJECTION ($6k FN, 3% risk-rule respected)")
print("=" * 72)

def project_income(gross_month, name, phase_note=""):
    """Apply news haircut, 80/90 split, EA fee for a monthly gross number."""
    # news haircut: if the strategy hits news, funded profit counts at 40% for those trades
    # rough estimate: ~10-15% of trades hit news, of those profit haircut is 60%
    # net effect on total profit: ~-8% (rough)
    news_adj = gross_month * 0.92
    ta80 = news_adj * 0.80
    ta90 = news_adj * 0.90
    fee = 5.0
    print(f"\n  {name} {phase_note}")
    print(f"    gross monthly       : ${gross_month:>7.2f}")
    print(f"    after ~8% news adj  : ${news_adj:>7.2f}")
    print(f"    @ 80% split - $5 fee: ${ta80-fee:>7.2f}/mo  = INR {(ta80-fee)*115:>6.0f}/mo")
    print(f"    @ 90% scale-up - fee: ${ta90-fee:>7.2f}/mo  = INR {(ta90-fee)*115:>6.0f}/mo")
    return ta80 - fee, ta90 - fee

# Combo (funded stage, needs 3% rework — estimate -20% from cap-1)
combo_monthly_challenge = s_c['net'] / ((s_c['last_dt']-s_c['first_dt']).days/30.44)
combo_monthly_funded = combo_monthly_challenge * 0.80  # -20% from 3% rework cap
print(f"\n  combo_fnext_03 gross monthly (challenge): ${combo_monthly_challenge:.2f}")
print(f"  combo_fnext_03 gross monthly (funded, cap-1 rework est -20%): ${combo_monthly_funded:.2f}")
combo80, combo90 = project_income(combo_monthly_funded, "OPTION W: combo_fnext_03 alone (funded stage)")

# QM (funded stage, no rework needed since 2 concurrent × $75 = $150 < $180)
qm_monthly = s_q['net'] / ((s_q['last_dt']-s_q['first_dt']).days/30.44)
qm_scaled = qm_monthly * (75.0/85.0)  # scale to $75/trade for full 3% buffer
qm80, qm90 = project_income(qm_scaled, "QM erl_h4 alone (funded, $75 risk)")

# Portfolio (mutual exclusion)
portfolio_monthly = net_portfolio / n_months
portfolio_funded = portfolio_monthly * 0.90  # small rework hit for compliance
p80, p90 = project_income(portfolio_funded, "OPTION Z: PORTFOLIO combo+QM (mutex, funded, best of both)")

print()
print("=" * 72)
print("  FINAL RANKING (FUNDED-STAGE $6k FN live account monthly take-home)")
print("=" * 72)
options = [
    ("W: combo alone (funded, rework)", combo80, combo90),
    ("Y: QM alone (funded, $75)"       , qm80, qm90),
    ("Z: PORTFOLIO combo+QM (mutex)"    , p80, p90),
]
options.sort(key=lambda x: -x[1])
print(f"\n  Rank | Option                                | 80% split      | 90% split")
print(f"  -----+---------------------------------------+----------------+----------------")
for i, (name, m80, m90) in enumerate(options):
    marker = "  BEST" if i == 0 else ""
    print(f"   {i+1}   | {name:<38}| ${m80:>6.0f}/mo (INR {m80*115:>6.0f}) | ${m90:>6.0f}/mo (INR {m90*115:>6.0f})  {marker}")

print()
print("  ~INR 30,000/mo target hit?")
best = options[0]
if best[2] * 115 >= 30000:
    print(f"    YES via {best[0]} at 90% split: INR {best[2]*115:.0f}/mo")
elif best[1] * 115 >= 30000:
    print(f"    YES via {best[0]} at 80% split: INR {best[1]*115:.0f}/mo")
else:
    gap = 30000 - best[2]*115
    print(f"    Not yet -- best is INR {best[2]*115:.0f}/mo at 90% split, INR {gap:.0f} short of 30k")

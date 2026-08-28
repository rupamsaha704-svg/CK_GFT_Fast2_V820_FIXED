#!/usr/bin/env python3
"""
M7 — Benchmark suite (deterministic, matched-lot & risk-adjusted). Confirms the strategy's edge is real,
not just long-gold beta. Baselines (pre-declared, non-tuned) over the SAME period & SAME 0.09 lot:
  1) buy-and-hold XAUUSD (long 0.09 held the whole period)
  2) simple-trend baseline (long 0.09 when close>EMA200, else flat)  [canonical, non-optimised]
Compares return, max equity DD, and MAR (=return/DD). Strategy must NOT be dominated on MAR.

XAUUSD contract: 1 lot = 100 oz; $1 price move = $100/lot. lot=0.09 => $9 per $1 move.
Usage: python3 benchmark.py XAUUSD_M15_clean.csv --strat-return 204.3 --strat-dd 16.1 [--lot 0.09 --deposit 5000 --ema 200]
"""
import argparse

def load_px(path):
    rows=[]
    for l in open(path):
        l=l.strip()
        if not l or l.lower().startswith('datetime,') or l.lower().startswith('time,'): continue
        parts=l.split(',')
        try: c=float(parts[4]); h=float(parts[2]); lo=float(parts[3])
        except Exception: continue
        rows.append((h,lo,c))
    return rows

def ema(vals, period):
    k=2.0/(period+1); out=[]; e=None
    for v in vals:
        e=v if e is None else v*k+e*(1-k); out.append(e)
    return out

def curve_stats(equity, equity_low, dep):
    peak=dep; mdd=0.0
    for i in range(len(equity)):
        peak=max(peak,equity[i])
        dd=(peak-equity_low[i])/peak if peak>0 else 0
        if dd>mdd: mdd=dd
    ret=100.0*(equity[-1]-dep)/dep
    return ret, mdd*100.0

def buy_hold(px, lot, dep, cs=100.0):
    c0=px[0][2]; eq=[]; eql=[]
    for h,lo,c in px:
        eq.append(dep+(c-c0)*cs*lot); eql.append(dep+(lo-c0)*cs*lot)
    return curve_stats(eq, eql, dep)

def trend(px, lot, dep, period, cs=100.0):
    closes=[c for _,_,c in px]; e=ema(closes, period)
    eq=dep; equity=[dep]; equity_low=[dep]
    for t in range(1,len(px)):
        pos = 1 if closes[t-1] > e[t-1] else 0
        pnl = pos*(closes[t]-closes[t-1])*cs*lot
        low_pnl = pos*(px[t][1]-closes[t-1])*cs*lot   # intrabar adverse via bar low
        eq_prev=eq; eq=eq+pnl
        equity.append(eq); equity_low.append(eq_prev+low_pnl)
    return curve_stats(equity, equity_low, dep)

def mar(ret,dd): return (ret/dd) if dd>0 else float('inf')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('pxcsv'); ap.add_argument('--strat-return', type=float, required=True)
    ap.add_argument('--strat-dd', type=float, required=True)
    ap.add_argument('--lot', type=float, default=0.09); ap.add_argument('--deposit', type=float, default=5000.0)
    ap.add_argument('--ema', type=int, default=200)
    a=ap.parse_args()
    px=load_px(a.pxcsv)
    bh_r,bh_dd=buy_hold(px,a.lot,a.deposit); tr_r,tr_dd=trend(px,a.lot,a.deposit,a.ema)
    s_mar=mar(a.strat_return,a.strat_dd); bh_mar=mar(bh_r,bh_dd); tr_mar=mar(tr_r,tr_dd)
    print("="*60); print(f"M7 BENCHMARK SUITE (lot {a.lot}, same period, {len(px)} bars)"); print("="*60)
    print(f"  {'series':<22}{'return%':>9}{'maxDD%':>9}{'MAR':>8}")
    print(f"  {'STRATEGY':<22}{a.strat_return:>9.1f}{a.strat_dd:>9.1f}{s_mar:>8.2f}")
    print(f"  {'buy-hold 0.09':<22}{bh_r:>9.1f}{bh_dd:>9.1f}{bh_mar:>8.2f}")
    print(f"  {'simple-trend EMA%d'%a.ema:<22}{tr_r:>9.1f}{tr_dd:>9.1f}{tr_mar:>8.2f}")
    print("-"*60)
    dominated = (s_mar < bh_mar) or (s_mar < tr_mar)
    print(f"  M7: {'FAIL (dominated by a baseline on MAR)' if dominated else 'PASS (beats baselines on MAR)'}")

if __name__=='__main__': main()

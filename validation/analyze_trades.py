"""Analyze v23 closed-trade P/L CSV (from EA OnTester dump).
Computes net/PF/DD/win%, Monte Carlo (bootstrap) with a 9% max-DD gate,
CPCV IS/OOS Sharpe, and Deflated Sharpe. LLM-free, deterministic.
Reads: Common\\Files\\ck_v23_trades.csv (auto-located) or CK_TRADES env / argv[1].
"""
from __future__ import annotations
import os, sys, csv, math
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from cpcv import CombinatorialPurgedKFold
from pbo import deflated_sharpe_ratio

DEPOSIT = float(os.environ.get("CK_DEPOSIT", "5000"))
N_MC = int(os.environ.get("CK_MC", "10000"))
DD_LIMIT = float(os.environ.get("CK_DD_LIMIT", "9.0"))
RESEARCH = os.environ.get("CK_RESEARCH", HERE)

def find_csv():
    if len(sys.argv) > 1 and os.path.isfile(sys.argv[1]):
        return sys.argv[1]
    e = os.environ.get("CK_TRADES")
    if e and os.path.isfile(e):
        return e
    base = os.path.expandvars(r"%APPDATA%\MetaQuotes")
    for dp, _, fns in os.walk(base):
        for fn in fns:
            if fn.lower() == "ck_v23_trades.csv":
                return os.path.join(dp, fn)
    return None

def sharpe(x):
    x = np.asarray(x, float); x = x[~np.isnan(x)]
    if len(x) < 2: return float("nan")
    s = np.std(x, ddof=1)
    return float(np.mean(x)/s) if s > 0 else float("nan")

def eq(pl): return DEPOSIT + np.cumsum(np.asarray(pl, float))
def maxdd(e):
    peak = np.maximum.accumulate(e); dd = e - peak
    return float(-dd.min()), float(-(dd/peak).min()*100.0)
def streak(pl):
    l=m=0
    for p in pl:
        if p < 0: l+=1; m=max(m,l)
        else: l=0
    return m

def main():
    f = find_csv()
    if not f:
        print("ERROR: ck_v23_trades.csv not found. Run the backtest first (EA writes it)."); return 1
    print("Trades file:", f)
    pl=[]
    with open(f, newline="") as fh:
        for row in csv.reader(fh):
            if len(row) < 2: continue
            try: pl.append(float(row[1]))
            except: pass
    pl = np.asarray(pl, float)
    n = len(pl)
    if n < 20:
        print(f"Only {n} trades parsed - too few."); return 0
    e = eq(pl); net = float(pl.sum())
    wins = pl[pl>0]; losses = pl[pl<0]
    pf = float(wins.sum()/-losses.sum()) if losses.sum()!=0 else float("inf")
    ddm, ddp = maxdd(e)
    wr = 100*len(wins)/n
    sr = sharpe(pl)
    print("\n===== v23 (MaxLot 0.09) BACKTEST STATS =====")
    print(f"  Trades={n}  Net={net:.2f}  PF={pf:.3f}  Win%={wr:.1f}")
    print(f"  Max Drawdown = {ddm:.2f}  ({ddp:.2f}%)   [limit {DD_LIMIT:.0f}%]")
    print(f"  DD GATE: " + ("PASS <=9%" if ddp<=DD_LIMIT else "FAIL >9% (reduce risk)"))

    rng=np.random.default_rng(42)
    ddpz=np.empty(N_MC); fin=np.empty(N_MC)
    for i in range(N_MC):
        s=rng.choice(pl,size=n,replace=True); ee=eq(s)
        _,dp=maxdd(ee); ddpz[i]=dp; fin[i]=ee[-1]-DEPOSIT
    dd95=float(np.percentile(ddpz,95)); dd99=float(np.percentile(ddpz,99))
    ruin=float(np.mean(fin<=-0.5*DEPOSIT)*100.0); negp=float(np.mean(fin<0)*100.0)
    print(f"\n===== MONTE CARLO ({N_MC} bootstrap) =====")
    print(f"  DD% median={np.median(ddpz):.2f}  95th={dd95:.2f}  99th={dd99:.2f}")
    print(f"  P(final<0)={negp:.1f}%   risk-of-ruin(-50%)={ruin:.1f}%")
    print(f"  MC DD GATE (95th <=9%): " + ("PASS" if dd95<=DD_LIMIT else "FAIL"))

    ns = 8 if n>=64 else max(4,min(6,n//8))
    cp = CombinatorialPurgedKFold(n_splits=ns,n_test_splits=2,embargo_pct=0.01)
    iss=[]; oos=[]
    for tr,te in cp.split(n):
        iss.append(sharpe(pl[tr])); oos.append(sharpe(pl[te]))
    ism=float(np.nanmean(iss)); oosm=float(np.nanmean(oos))
    print(f"\n===== CPCV (overfit check) =====")
    print(f"  splits={ns} paths={cp.get_n_splits()}  IS Sharpe={ism:.3f}  OOS Sharpe={oosm:.3f}  degradation={ism-oosm:.3f}")
    print(f"  OVERFIT GATE (OOS Sharpe>0): " + ("PASS" if oosm>0 else "FAIL"))

    skew=float(((pl-pl.mean())**3).mean()/(pl.std()**3)) if pl.std()>0 else 0.0
    exk=float(((pl-pl.mean())**4).mean()/(pl.std()**4)-3) if pl.std()>0 else 0.0
    ann=sr*math.sqrt(n)  # per-trade -> annualised-ish over the sample
    dsr=deflated_sharpe_ratio(ann,n_trials=max(2,cp.get_n_splits()),n_obs=n,skewness=skew,excess_kurtosis=exk)
    print(f"\n===== DEFLATED SHARPE =====\n  perTradeSR={sr:.3f}  DSR(prob true SR>0)={dsr:.4f}")

    verdict = (ddp<=DD_LIMIT) and (dd95<=DD_LIMIT) and (oosm>0) and (net>0)
    print("\n============================================")
    print("  OVERALL VERDICT: " + ("ROBUST & WITHIN RISK LIMITS ✓" if verdict else "NOT yet within all gates - needs work"))
    print("============================================")

    try:
        with open(os.path.join(RESEARCH,"10_v23_ROBUSTNESS.md"),"w",encoding="utf-8") as o:
            o.write("# v23 Robustness (MaxLot 0.09)\n\n")
            o.write(f"- Trades: {n}\n- Net: {net:.2f}\n- Profit Factor: {pf:.3f}\n- Win%: {wr:.1f}\n")
            o.write(f"- Max Drawdown: {ddm:.2f} ({ddp:.2f}%)  [limit {DD_LIMIT:.0f}%] -> {'PASS' if ddp<=DD_LIMIT else 'FAIL'}\n")
            o.write(f"- Monte Carlo DD%%: median {np.median(ddpz):.2f}, 95th {dd95:.2f}, 99th {dd99:.2f}\n")
            o.write(f"- P(final<0): {negp:.1f}%  Risk of ruin: {ruin:.1f}%\n")
            o.write(f"- CPCV IS Sharpe {ism:.3f} / OOS Sharpe {oosm:.3f} (degradation {ism-oosm:.3f})\n")
            o.write(f"- Deflated Sharpe: {dsr:.4f}\n")
            o.write(f"- OVERALL: {'ROBUST & within risk limits' if verdict else 'not yet within all gates'}\n")
    except Exception as ex:
        print("report write skipped:", ex)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
Validation Orchestrator — Step 1 (deterministic; same input => same output).
Chains the existing deterministic stages and emits ONE PASS/FAIL.
LLM is NOT involved here — this code MEASURES and JUDGES.

Usage:
  python3 orchestrator.py --is in_sample.csv [--oos out_of_sample.csv] [--deposit 5000]
CSV format: header "time,profit" then rows "YYYY.MM.DD HH:MM,<profit>"

PASS/FAIL thresholds (v1, explicit & tunable):
  - requires an OOS file to PASS (no OOS => INSUFFICIENT)
  - oos_pf >= 1.10 and oos_net > 0
  - IS->OOS not a collapse: oos_pf >= 0.60 * is_pf
  - bootstrap P(losing) on primary set <= 15%
"""
import argparse, datetime, random, statistics

def load(p):
    rows=[]
    for l in open(p):
        l=l.strip()
        if not l or l.lower().startswith('time,'): continue
        t,pf=l.rsplit(',',1)
        try: d=datetime.datetime.strptime(t,"%Y.%m.%d %H:%M")
        except: d=None
        rows.append((d,float(pf)))
    return rows

def basic(rows, dep):
    n=len(rows); net=sum(p for _,p in rows)
    wins=[p for _,p in rows if p>0]; losses=[p for _,p in rows if p<0]
    gw=sum(wins); gl=abs(sum(losses))
    pf=gw/gl if gl>0 else float('inf')
    eq=dep; peak=dep; mdd=0.0
    for _,p in rows:
        eq+=p; peak=max(peak,eq); mdd=max(mdd,(peak-eq)/peak)
    return dict(n=n,net=net,ret=100*net/dep,pf=pf,wr=100*len(wins)/n if n else 0,
                avgw=gw/len(wins) if wins else 0, avgl=(-gl/len(losses)) if losses else 0, mdd=100*mdd)

def by(rows, keyfn):
    d={}
    for dt,p in rows:
        if dt is None: continue
        k=keyfn(dt); d.setdefault(k,[0.0,0.0,0]); d[k][0]+=p; d[k][1]+=(p if p<0 else 0); d[k][2]+=1
    return d

def montecarlo(rows, dep, N=5000, seed=42):
    random.seed(seed); pls=[p for _,p in rows]; n=len(pls)
    def eqstats(seq):
        eq=dep; peak=dep; mdd=0.0
        for p in seq:
            eq+=p; peak=max(peak,eq); mdd=max(mdd,(peak-eq)/peak)
        return eq-dep, mdd*100
    bnet=[]; bdd=[]; los=0
    for _ in range(N):
        seq=[random.choice(pls) for _ in range(n)]
        net,dd=eqstats(seq); bnet.append(net); bdd.append(dd)
        if net<=0: los+=1
    sdd=[]
    for _ in range(N):
        random.shuffle(pls); _,dd=eqstats(pls); sdd.append(dd)
    q=lambda a,x: sorted(a)[int(x*len(a))]
    return dict(boot_net_med=statistics.median(bnet), boot_net_p5=q(bnet,.05), boot_net_p95=q(bnet,.95),
                boot_dd_p95=q(bdd,.95), p_losing=100*los/N, shuf_dd_med=statistics.median(sdd), shuf_dd_p95=q(sdd,.95))

def fmt_by(title, d, top=6):
    print(f"  [{title}] (net | lossOnly | trades)")
    items=sorted(d.items(), key=lambda kv: kv[1][0])[:top]  # worst-net first
    for k,(net,loss,c) in items:
        print(f"     {str(k):<14} net {net:>8.0f} | loss {loss:>8.0f} | {c}")

def report_set(label, rows, dep):
    b=basic(rows,dep)
    print(f"\n=== {label} ===")
    print(f"  trades {b['n']}  net {b['net']:.0f}  ret {b['ret']:.1f}%  PF {b['pf']:.2f}  WR {b['wr']:.1f}%  closedDD {b['mdd']:.1f}%")
    print(f"  avgWin {b['avgw']:.0f}  avgLoss {b['avgl']:.0f}")
    dow=['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
    fmt_by("worst DAY", by(rows, lambda dt: dow[dt.weekday()]))
    fmt_by("worst MONTH", by(rows, lambda dt: f"{dt.year}.{dt.month:02d}"))
    def sess(h): return "Asia" if h<8 else ("London" if h<13 else ("LDN+NY" if h<17 else "NY-late"))
    fmt_by("worst SESSION", by(rows, lambda dt: sess(dt.hour)), top=4)
    return b

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--is', dest='is_', required=True)
    ap.add_argument('--oos', dest='oos', default=None)
    ap.add_argument('--deposit', type=float, default=5000.0)
    a=ap.parse_args()
    print("="*60); print("VALIDATION ORCHESTRATOR — Step 1 (deterministic)"); print("="*60)
    IS=load(a.is_); bi=report_set("IN-SAMPLE", IS, a.deposit)
    mc=montecarlo(IS, a.deposit)
    print("\n=== MONTE CARLO (in-sample series) ===")
    print(f"  bootstrap net: median {mc['boot_net_med']:.0f}  [p5 {mc['boot_net_p5']:.0f} .. p95 {mc['boot_net_p95']:.0f}]")
    print(f"  bootstrap maxDD p95 {mc['boot_dd_p95']:.1f}%   shuffle maxDD median {mc['shuf_dd_med']:.1f}% p95 {mc['shuf_dd_p95']:.1f}%")
    print(f"  P(losing period) {mc['p_losing']:.1f}%")
    bo=None
    if a.oos:
        bo=report_set("OUT-OF-SAMPLE", load(a.oos), a.deposit)
        deg = bo['pf']/bi['pf'] if bi['pf']>0 else 0
        print(f"\n=== IS -> OOS degradation ===\n  PF {bi['pf']:.2f} -> {bo['pf']:.2f}  (OOS/IS ratio {deg:.2f})")

    # ---- deterministic PASS/FAIL ----
    print("\n"+"="*60); print("VERDICT"); print("="*60)
    reasons=[]
    if bo is None:
        print("  RESULT: INSUFFICIENT — no OOS provided; cannot PASS on in-sample alone.")
        print("  (edge is only real if it survives unseen data)")
        return
    ok=True
    if not (bo['pf']>=1.10): ok=False; reasons.append(f"OOS PF {bo['pf']:.2f} < 1.10")
    if not (bo['net']>0):    ok=False; reasons.append(f"OOS net {bo['net']:.0f} <= 0")
    if not (bo['pf']>=0.60*bi['pf']): ok=False; reasons.append(f"IS->OOS collapse: {bo['pf']:.2f} < 0.60*{bi['pf']:.2f}")
    if not (mc['p_losing']<=15.0): ok=False; reasons.append(f"P(losing) {mc['p_losing']:.1f}% > 15%")
    if ok: print("  RESULT: PASS (deterministic gates cleared). Still requires DEMO/forward before live.")
    else:
        print("  RESULT: FAIL"); 
        for r in reasons: print(f"    - {r}")
    print("\n  NOTE: this pipeline MEASURES & JUDGES. Any LLM hypothesis must re-enter here (incl. OOS).")

if __name__=='__main__': main()

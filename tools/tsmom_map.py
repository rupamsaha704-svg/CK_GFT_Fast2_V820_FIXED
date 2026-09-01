#!/usr/bin/env python3
"""EDGE LANDSCAPE MAP (honest exploration): WHERE (per market) and WHEN (regime/day)
does daily TSMOM work -- shown IS vs OOS side by side so in-sample mirages are visible.
Causal signals. This is HYPOTHESIS GENERATION, not validated edge."""
import os, csv, math, datetime as dt
import numpy as np
LB=[20,60,120,250]; VW=60; ANN=252; TARGET=0.10; COST=0.0010
def loaddir(d):
    S={}
    if not os.path.isdir(d): return S
    for f in os.listdir(d):
        if not f.endswith(".csv"): continue
        m=f[:-4]; dd={}
        for r in csv.DictReader(open(os.path.join(d,f),encoding="utf-8")):
            try: dd[r["date"]]=float(r["close"])
            except: pass
        if len(dd)>max(LB)+VW+30: S[m]=dd
    return S
# combine: data_daily (39) + alts from data_crypto (exclude BTC/ETH dup)
S=loaddir("data_daily")
for m,v in loaddir("data_crypto").items():
    if m not in S: S[m]=v
markets=sorted(S)
dates=sorted(set().union(*[set(S[m]) for m in markets])); T=len(dates); idx={d:i for i,d in enumerate(dates)}
split=next((i for i,d in enumerate(dates) if d>="2023-01-01"),T)
px={}; vf={}
for m in markets:
    a=np.full(T,np.nan)
    for d,v in S[m].items(): a[idx[d]]=v
    f=int(np.argmax(~np.isnan(a))); vf[m]=f; last=a[f]
    for t in range(f,T):
        if np.isnan(a[t]): a[t]=last
        else: last=a[t]
    px[m]=a
ret={m:np.zeros(T) for m in markets}
for m in markets: ret[m][vf[m]+1:]=px[m][vf[m]+1:]/px[m][vf[m]:-1]-1
W={m:np.zeros(T) for m in markets}; SIG={m:np.zeros(T) for m in markets}
for m in markets:
    s=vf[m]+max(LB)+1
    for t in range(s,T):
        sg=np.mean([np.sign(px[m][t]/px[m][t-L]-1) for L in LB]); SIG[m][t]=sg
        v=np.std(ret[m][t-VW+1:t+1]); W[m][t]=0 if v<=0 else sg/v
def sh(r):
    r=np.array(r);
    if len(r)<10 or np.std(r)==0: return 0.0
    return (np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))
def netseries(sub):
    n=np.zeros(T); tn=np.zeros(T); fa=min(vf[m]+max(LB)+2 for m in sub)
    for t in range(fa,T):
        n[t]=sum(W[m][t-1]*ret[m][t] for m in sub); tn[t]=sum(abs(W[m][t-1]-W[m][t-2]) for m in sub)
    rv=np.std(n[fa:]); sc=TARGET/(rv*math.sqrt(ANN)) if rv>0 else 0
    return n*sc-tn*COST*sc,fa
out=[]; L=lambda s:out.append(str(s))

# ---- WHERE: per-market standalone Sharpe IS vs OOS ----
L("=== WHERE: per-market TSMOM Sharpe (IS<2023 | OOS>=2023) ===")
rows=[]
for m in markets:
    n,fa=netseries([m])
    rows.append((m, sh(n[fa:split]), sh(n[split:])))
rows.sort(key=lambda x:-x[2])
L(f"  {'market':8} {'IS':>6} {'OOS':>6}   (sorted by OOS)")
for m,i,o in rows:
    flag=" <= durable" if (i>0.3 and o>0.3) else (" (IS-only mirage)" if i>0.5 and o<0 else "")
    L(f"  {m:8} {i:6.2f} {o:6.2f}{flag}")

# ---- WHEN: crypto BTC+ETH conditioned on regime ----
cry=[m for m in markets if m in ("BTC","ETH")]
n,fa=netseries(cry)
L(""); L("=== WHEN (crypto BTC+ETH): regime-conditional Sharpe (causal) ===")
# vol regime: trailing60 vol vs trailing252 median (per-day avg across BTC,ETH)
volst=np.array(["na"]*T,dtype=object)
for t in range(fa,T):
    vv=np.mean([np.std(ret[m][t-VW:t]) for m in cry])
    hist=[np.mean([np.std(ret[m][u-VW:u]) for m in cry]) for u in range(max(fa,t-252),t,5)]
    if hist: volst[t]="HIGH-vol" if vv>np.median(hist) else "LOW-vol"
for lab,(a,b) in [("IS",(fa,split)),("OOS",(split,T))]:
    L(f"  [{lab}] by volatility regime:")
    for st in ["LOW-vol","HIGH-vol"]:
        rr=[n[t] for t in range(a,b) if volst[t]==st]
        L(f"     {st:9} Sharpe {sh(rr):5.2f}  days {len(rr)}")
# trend-strength regime: both aligned (|avg sig|=1) vs mixed
for lab,(a,b) in [("IS",(fa,split)),("OOS",(split,T))]:
    L(f"  [{lab}] by trend-strength:")
    for st,cond in [("aligned(strong)",lambda t: min(abs(SIG[m][t-1]) for m in cry)>=0.99),
                    ("mixed(weak)",   lambda t: min(abs(SIG[m][t-1]) for m in cry)<0.99)]:
        rr=[n[t] for t in range(a,b) if cond(t)]
        L(f"     {st:16} Sharpe {sh(rr):5.2f}  days {len(rr)}")
# day-of-week (noise-prone, caveat)
L("  [OOS] by weekday (NOISE-PRONE, caveat):")
for wd,name in enumerate(["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]):
    rr=[n[t] for t in range(split,T) if dt.datetime.strptime(dates[t],"%Y-%m-%d").weekday()==wd]
    if rr: L(f"     {name} mean {np.mean(rr)*10000:+5.1f}bp  Sharpe {sh(rr):5.2f}")
open("tools/tsmom_map_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-MAP\n")
print("\n".join(out)); print("DONE-MAP")

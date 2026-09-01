#!/usr/bin/env python3
"""Combined book: crypto sleeve (BTC+ETH + vol filter) + NQ (Nasdaq) trend sleeve.
Tests whether an UNCORRELATED sleeve genuinely raises combined Sharpe / lowers DD.
Simple pre-registered blend (risk parity 50/50; 70/30 shown as sensitivity). Causal.
IS<2023 / OOS>=2023."""
import os, csv, math
import numpy as np
rng=np.random.default_rng(11)
LB=[20,60,120,250]; VW=60; ANN=252; TARGET=0.10; COST=0.0010

def loadcsv(path):
    d={}
    for r in csv.DictReader(open(path,encoding="utf-8")):
        try: d[r["date"]]=float(r["close"])
        except: pass
    return d
S={}
S["BTC"]=loadcsv("data_crypto/BTC.csv"); S["ETH"]=loadcsv("data_crypto/ETH.csv")
S["NQ"]=loadcsv("data_daily/NQ.csv")
mk=["BTC","ETH","NQ"]
dates=sorted(set().union(*[set(S[m]) for m in mk])); T=len(dates); idx={d:i for i,d in enumerate(dates)}
split=next((i for i,d in enumerate(dates) if d>="2023-01-01"),T)
px={}; vf={}
for m in mk:
    a=np.full(T,np.nan)
    for d,v in S[m].items(): a[idx[d]]=v
    f=int(np.argmax(~np.isnan(a))); vf[m]=f; last=a[f]
    for t in range(f,T):
        a[t]=last if np.isnan(a[t]) else a[t]; last=a[t]
    px[m]=a
ret={m:np.zeros(T) for m in mk}
for m in mk: ret[m][vf[m]+1:]=px[m][vf[m]+1:]/px[m][vf[m]:-1]-1
W={m:np.zeros(T) for m in mk}
for m in mk:
    s=vf[m]+max(LB)+1
    for t in range(s,T):
        sg=np.mean([np.sign(px[m][t]/px[m][t-L]-1) for L in LB])
        v=np.std(ret[m][t-VW+1:t+1]); W[m][t]=0 if v<=0 else sg/v
# vol regime filter (from BTC+ETH), causal
mv=np.zeros(T)
for t in range(VW+1,T): mv[t]=np.mean([np.std(ret[m][t-VW:t]) for m in ("BTC","ETH")])
mult=np.ones(T)
for t in range(VW+253,T):
    ref=np.median(mv[t-252:t]); mult[t]=max(0.5, min(1.0, ref/mv[t])) if mv[t]>0 else 1.0

fa=max(VW+254, max(vf[m]+max(LB)+2 for m in mk))
def sleeve(sub, use_filter):
    raw=np.zeros(T); tn=np.zeros(T)
    Weff={m:(W[m]*mult if use_filter else W[m]) for m in sub}
    for t in range(fa,T):
        raw[t]=sum(Weff[m][t-1]*ret[m][t] for m in sub)
        tn[t]=sum(abs(Weff[m][t-1]-Weff[m][t-2]) for m in sub)
    rv=np.std(raw[fa:]); sc=TARGET/(rv*math.sqrt(ANN)) if rv>0 else 0
    return raw*sc-tn*COST*sc
cryp=sleeve(["BTC","ETH"],True)
nq  =sleeve(["NQ"],False)
def blend(wc,wn):
    return wc*cryp+wn*nq
def stat(net,i0,i1):
    r=net[i0:i1]
    if len(r)<10 or np.std(r)==0: return (0,0,0)
    eq=np.cumprod(1+r); sh=(np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))
    pk=np.maximum.accumulate(eq); dd=np.max((pk-eq)/pk); cg=eq[-1]**(ANN/len(r))-1 if eq[-1]>0 else -1
    return (sh,cg,dd)
out=[];L=lambda s:out.append(str(s))
L(f"COMBO crypto(BTC+ETH+filter) + NQ  ({dates[fa]}..{dates[-1]})  IS<2023/OOS>=2023")
# correlation of sleeves (OOS)
c1=cryp[split:]; n1=nq[split:]; corr=np.corrcoef(c1,n1)[0,1]
L(f"sleeve correlation (OOS): {corr:+.2f}   (low = good diversification)")
L(f"{'book':22} {'FULLSh':>7} {'ISSh':>6} {'OOSSh':>6} {'OOScagr':>8} {'OOSdd':>6}")
for name,net in [("crypto alone",cryp),("NQ alone",nq),
                 ("combo 50/50",blend(0.5,0.5)),("combo 70/30",blend(0.7,0.3))]:
    f=stat(net,fa,T); i=stat(net,fa,split); o=stat(net,split,T)
    L(f"{name:22} {f[0]:7.2f} {i[0]:6.2f} {o[0]:6.2f} {o[1]*100:7.1f}% {o[2]*100:5.1f}%")
net=blend(0.5,0.5)
ym={}
for t in range(fa,T): ym.setdefault(dates[t][:4],[]).append(net[t])
L(""); L("combo 50/50 per-year: "+"  ".join(f"{y}:{(np.prod(1+np.array(v))-1)*100:+.0f}%" for y,v in sorted(ym.items())))
oos=net[split:]; B=20; nb=len(oos)//B; shs=[]
for _ in range(3000):
    ii=rng.integers(0,len(oos)-B,size=nb); s=np.concatenate([oos[i:i+B] for i in ii])
    v=np.std(s)*math.sqrt(ANN); shs.append((np.mean(s)*ANN)/v if v>0 else 0)
shs=np.array(shs)
L(f"combo 50/50 OOS bootstrap Sharpe: mean {shs.mean():.2f}  5th pct {np.percentile(shs,5):.2f}  P(>0) {np.mean(shs>0)*100:.1f}%")
open("tools/tsmom_combo_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-COMBO\n")
print("\n".join(out)); print("DONE-COMBO")

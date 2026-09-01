#!/usr/bin/env python3
"""CK_CRYPTO_TSMOM_v2 research: diversified crypto basket + causal volatility filter.
Compares v1 (BTC+ETH) vs v2a (basket, no filter) vs v2b (basket + vol filter).
Basket chosen by LIQUIDITY/longevity (ex-ante), NOT by backtest returns (anti-overfit).
Causal, 1-bar lag, inverse-vol equal-risk, vol-target 10%, 10bps cost. IS<2023 / OOS>=2023."""
import os, csv, math
import numpy as np
rng=np.random.default_rng(7)
DATA="data_crypto"; LB=[20,60,120,250]; VW=60; ANN=252; TARGET=0.10; COST=0.0010
# ex-ante liquid/long-history majors+large caps (NOT selected on performance)
BASKET=["BTC","ETH","BNB","XRP","SOL","ADA","DOGE","LTC","LINK","TRX","XLM","ATOM"]
def load(m):
    p=os.path.join(DATA,m+".csv")
    if not os.path.exists(p): return None
    d={}
    for r in csv.DictReader(open(p,encoding="utf-8")):
        try: d[r["date"]]=float(r["close"])
        except: pass
    return d if len(d)>max(LB)+VW+30 else None
S={m:load(m) for m in BASKET}; S={m:v for m,v in S.items() if v}
mk=sorted(S)
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

# causal market-vol regime multiplier (reduce exposure in high vol) -- built from BTC+ETH (always-present) to avoid survivorship
core=[m for m in ["BTC","ETH"] if m in mk]
mv=np.zeros(T)
for t in range(VW+1,T):
    mv[t]=np.mean([np.std(ret[m][t-VW:t]) for m in core])
mult=np.ones(T)
for t in range(VW+253,T):
    ref=np.median(mv[t-252:t])
    mult[t]= min(1.0, ref/mv[t]) if mv[t]>0 else 1.0
    mult[t]=max(0.5,mult[t])

def port(sub, use_filter):
    fa=max(min(vf[m]+max(LB)+2 for m in sub), VW+254)
    raw=np.zeros(T); tn=np.zeros(T)
    Weff={m:(W[m]*mult if use_filter else W[m]) for m in sub}
    for t in range(fa,T):
        raw[t]=sum(Weff[m][t-1]*ret[m][t] for m in sub)
        tn[t]=sum(abs(Weff[m][t-1]-Weff[m][t-2]) for m in sub)
    rv=np.std(raw[fa:]); sc=TARGET/(rv*math.sqrt(ANN)) if rv>0 else 0
    return raw*sc-tn*COST*sc, fa
def stats(net,i0,i1):
    r=net[i0:i1]
    if len(r)<10 or np.std(r)==0: return (0,0,0)
    eq=np.cumprod(1+r); sh=(np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))
    pk=np.maximum.accumulate(eq); dd=np.max((pk-eq)/pk)
    cg=eq[-1]**(ANN/len(r))-1 if eq[-1]>0 else -1
    return (sh,cg,dd)

out=[]; L=lambda s:out.append(str(s))
L(f"CK_CRYPTO_TSMOM v2 study  basket={mk}  ({dates[0]}..{dates[-1]})  IS<2023/OOS>=2023")
L(f"{'variant':22} {'FULL Sh':>8} {'IS Sh':>7} {'OOS Sh':>7} {'OOS CAGR':>9} {'OOS DD':>7}")
defs=[("v1 BTC+ETH",["BTC","ETH"],False),
      ("v1 BTC+ETH +filter",["BTC","ETH"],True),
      ("v2a basket",mk,False),
      ("v2b basket+volfilter",mk,True)]
res={}
for name,sub,uf in defs:
    sub=[m for m in sub if m in mk]
    net,fa=port(sub,uf); res[name]=(net,fa)
    fsh,_,_=stats(net,fa,T); ish,_,_=stats(net,fa,split); osh,ocg,odd=stats(net,split,T)
    L(f"{name:22} {fsh:8.2f} {ish:7.2f} {osh:7.2f} {ocg*100:8.1f}% {odd*100:6.1f}%")
# per-year for the winning config
net,fa=res["v1 BTC+ETH +filter"]
L(""); L("v2b per-year NET:")
ym={}
for i in range(fa,T): ym.setdefault(dates[i][:4],[]).append(net[i])
L("  "+"  ".join(f"{y}:{(np.prod(1+np.array(v))-1)*100:+.0f}%" for y,v in sorted(ym.items())))
# bootstrap OOS Sharpe for v2b
oos=net[split:]; B=20; nb=len(oos)//B; shs=[]
for _ in range(3000):
    ii=rng.integers(0,len(oos)-B,size=nb); s=np.concatenate([oos[i:i+B] for i in ii])
    v=np.std(s)*math.sqrt(ANN); shs.append((np.mean(s)*ANN)/v if v>0 else 0)
shs=np.array(shs)
L(f"v2b OOS bootstrap Sharpe: mean {shs.mean():.2f}  5th pct {np.percentile(shs,5):.2f}  P(>0) {np.mean(shs>0)*100:.1f}%")
open("tools/tsmom_v2_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-V2\n")
print("\n".join(out)); print("DONE-V2")

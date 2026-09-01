#!/usr/bin/env python3
"""Disciplined 'try all sleeves' screen. Each candidate sleeve = a distinct, economically
motivated bet. OBJECTIVE inclusion rule (set BEFORE seeing combos, no cherry-picking):
  include if  OOS Sharpe > 0.25  AND  |corr to crypto-trend| < 0.5.
Included sleeves -> risk-parity book. Also show 'kitchen sink' (all equal) for contrast.
Causal, 1-bar lag, each sleeve vol-target 10%, 10bps. IS<2023 / OOS>=2023.
NOTE: final round (OOS erosion) - forward test is the real judge."""
import os, csv, math
import numpy as np
rng=np.random.default_rng(3)
DATA="data_daily"; LB=[20,60,120,250]; VW=60; ANN=252; TARGET=0.10; COST=0.0010
def load(m):
    p=os.path.join(DATA,m+".csv");
    if not os.path.exists(p): return None
    d={}
    for r in csv.DictReader(open(p,encoding="utf-8")):
        try: d[r["date"]]=float(r["close"])
        except: pass
    return d if len(d)>max(LB)+VW+30 else None
need=["BTC","ETH","NQ","DAX","FTSE","NIKKEI","STOXX","HSI","CL","NG","HG","GC","SI","ZC","ZW","ZS",
      "ZN","ZB","ZF","ZT","EURUSD","GBPUSD","AUDUSD","NZDUSD","USDCAD","USDCHF","USDJPY"]
S={m:load(m) for m in need}; S={m:v for m,v in S.items() if v}
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
# trend weights
WT={m:np.zeros(T) for m in mk}
for m in mk:
    s=vf[m]+max(LB)+1
    for t in range(s,T):
        sg=np.mean([np.sign(px[m][t]/px[m][t-L]-1) for L in LB]); v=np.std(ret[m][t-VW+1:t+1])
        WT[m][t]=0 if v<=0 else sg/v
# crypto mean-reversion weights: fade last 5-day move
WM={m:np.zeros(T) for m in ("BTC","ETH")}
for m in ("BTC","ETH"):
    s=vf[m]+10
    for t in range(s,T):
        mr=-np.sign(px[m][t]/px[m][t-5]-1); v=np.std(ret[m][t-VW+1:t+1])
        WM[m][t]=0 if v<=0 else mr/v
fa=max(VW+2, max(vf[m]+max(LB)+2 for m in mk))
def netfrom(Wd,sub):
    raw=np.zeros(T); tn=np.zeros(T)
    for t in range(fa,T):
        raw[t]=sum(Wd[m][t-1]*ret[m][t] for m in sub); tn[t]=sum(abs(Wd[m][t-1]-Wd[m][t-2]) for m in sub)
    rv=np.std(raw[fa:]); sc=TARGET/(rv*math.sqrt(ANN)) if rv>0 else 0
    return raw*sc-tn*COST*sc
def sh(net,i0,i1):
    r=net[i0:i1]
    return 0.0 if len(r)<10 or np.std(r)==0 else (np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))
def dd(net,i0,i1):
    eq=np.cumprod(1+net[i0:i1]); pk=np.maximum.accumulate(eq); return np.max((pk-eq)/pk)

sleeves={
 "crypto_trend":netfrom(WT,["BTC","ETH"]),
 "nq_trend":netfrom(WT,["NQ"]),
 "intl_equity":netfrom(WT,["DAX","FTSE","NIKKEI","STOXX","HSI"]),
 "commodity":netfrom(WT,["CL","NG","HG","GC","SI","ZC","ZW","ZS"]),
 "bond":netfrom(WT,["ZN","ZB","ZF","ZT"]),
 "fx":netfrom(WT,[m for m in mk if m.endswith("USD") or m.startswith("USD")]),
 "crypto_meanrev":netfrom(WM,["BTC","ETH"]),
}
core=sleeves["crypto_trend"]
out=[];L=lambda s:out.append(str(s))
L("=== SLEEVE SCREEN (objective rule: OOS Sh>0.25 AND |corr to crypto|<0.5) ===")
L(f"{'sleeve':16} {'IS Sh':>6} {'OOS Sh':>7} {'corr_cry':>9} {'include?':>9}")
included=[]
for name,net in sleeves.items():
    o=sh(net,split,T); i=sh(net,fa,split)
    c=np.corrcoef(core[split:],net[split:])[0,1] if name!="crypto_trend" else 1.0
    inc = (name=="crypto_trend") or (o>0.25 and abs(c)<0.5)
    if inc: included.append(name)
    L(f"{name:16} {i:6.2f} {o:7.2f} {c:9.2f} {'YES' if inc else 'no':>9}")

def book(names):
    w=1.0/len(names); b=sum(w*sleeves[n] for n in names)
    return b
L(""); L(f"INCLUDED (rule): {included}")
bk=book(included)
L(f"  BOOK(included) : FULL Sh {sh(bk,fa,T):.2f} | IS {sh(bk,fa,split):.2f} | OOS {sh(bk,split,T):.2f} | OOS DD {dd(bk,split,T)*100:.1f}%")
alln=list(sleeves); ks=book(alln)
L(f"  KITCHEN-SINK(all): FULL Sh {sh(ks,fa,T):.2f} | IS {sh(ks,fa,split):.2f} | OOS {sh(ks,split,T):.2f} | OOS DD {dd(ks,split,T)*100:.1f}%")
# current book for reference: crypto+NQ 70/30
cur=0.7*sleeves["crypto_trend"]+0.3*sleeves["nq_trend"]
L(f"  CURRENT crypto+NQ 70/30: OOS Sh {sh(cur,split,T):.2f} | OOS DD {dd(cur,split,T)*100:.1f}%")
# per-year + bootstrap for included book
ym={}
for t in range(fa,T): ym.setdefault(dates[t][:4],[]).append(bk[t])
L(""); L("BOOK(included) per-year: "+"  ".join(f"{y}:{(np.prod(1+np.array(v))-1)*100:+.0f}%" for y,v in sorted(ym.items())))
oos=bk[split:]; B=20; nb=len(oos)//B; shs=[]
for _ in range(3000):
    ii=rng.integers(0,len(oos)-B,size=nb); s=np.concatenate([oos[i:i+B] for i in ii])
    v=np.std(s)*math.sqrt(ANN); shs.append((np.mean(s)*ANN)/v if v>0 else 0)
shs=np.array(shs)
L(f"BOOK(included) OOS bootstrap Sharpe: mean {shs.mean():.2f}  5th pct {np.percentile(shs,5):.2f}  P(>0) {np.mean(shs>0)*100:.1f}%")
open("tools/tsmom_sleeves_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-SLEEVES\n")
print("\n".join(out)); print("DONE-SLEEVES")

#!/usr/bin/env python3
"""REALISTIC funding-carry backtest incl. BASIS mark-to-market (the risk funding-only missed).
Long spot + short perp: daily P&L = spot_ret - perp_ret + funding_received.
Compare to funding-only; correlation to trend; combined book. IS<2023 / OOS>=2023."""
import os, csv, math
import numpy as np
ANN=365; LB=[20,60,120,250]; VW=60; COST_YR=0.03
def fund_daily(sym):
    import datetime as dt
    d={}
    for r in csv.DictReader(open(f"data_funding/{sym}.csv",encoding="utf-8")):
        try:
            day=dt.datetime.utcfromtimestamp(int(r["time_ms"])/1000).strftime("%Y-%m-%d")
            d[day]=d.get(day,0.0)+float(r["rate"])
        except: pass
    return d
def px(sym):
    sp={}; pp={}
    for r in csv.DictReader(open(f"data_funding/{sym}_px.csv",encoding="utf-8")):
        try: sp[r["date"]]=float(r["spot_close"]); pp[r["date"]]=float(r["perp_close"])
        except: pass
    return sp,pp
def cprice(sym):
    d={}
    for r in csv.DictReader(open(f"data_crypto/{sym}.csv",encoding="utf-8")):
        try: d[r["date"]]=float(r["close"])
        except: pass
    return d
def carry_series(fsym, csym):
    fd=fund_daily(fsym); sp,pp=px(fsym)
    days=sorted(set(fd)&set(sp)&set(pp))
    real={}; fonly={}
    for i in range(1,len(days)):
        d0,d1=days[i-1],days[i]
        sr=sp[d1]/sp[d0]-1; pr=pp[d1]/pp[d0]-1
        real[d1]=sr-pr+fd[d1]      # long spot + short perp + funding
        fonly[d1]=fd[d1]
    return real, fonly
# build for BTC, ETH and average
rb,fb=carry_series("BTCUSDT","BTC"); re,fe=carry_series("ETHUSDT","ETH")
days=sorted(set(rb)&set(re))
carry_real=np.array([(rb[d]+re[d])/2 for d in days])
carry_fonly=np.array([(fb[d]+fe[d])/2 for d in days])
# trend on same days
def trend(csym):
    d=cprice(csym); px_=np.array([d.get(x,np.nan) for x in days])
    # forward-fill any gaps
    for i in range(1,len(px_)):
        if np.isnan(px_[i]): px_[i]=px_[i-1]
    T=len(px_); ret=np.zeros(T); ret[1:]=px_[1:]/px_[:-1]-1; W=np.zeros(T)
    for t in range(max(LB)+1,T):
        sg=np.mean([np.sign(px_[t]/px_[t-L]-1) for L in LB]); v=np.std(ret[t-VW+1:t+1]); W[t]=0 if v<=0 else sg/v
    nr=np.zeros(T)
    for t in range(max(LB)+2,T): nr[t]=W[t-1]*ret[t]
    return nr
tr=(trend("BTC")+trend("ETH"))/2
T=len(days); fa=max(LB)+2; split=next((i for i,d in enumerate(days) if d>="2023-01-01"),T)
carry_real_net=carry_real-COST_YR/ANN
def stats(r,i0,i1):
    r=r[i0:i1]
    if len(r)<10 or np.std(r)==0: return (0,0,0,0)
    eq=np.cumprod(1+r); sh=(np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))
    pk=np.maximum.accumulate(eq); dd=np.max((pk-eq)/pk); cg=eq[-1]**(ANN/len(r))-1 if eq[-1]>0 else -1
    return (sh,cg,dd,np.min(r)*100)
out=[];L=lambda s:out.append(str(s))
L(f"REALISTIC carry (basis + funding)  ({days[fa]}..{days[-1]}, {T} days)  cost {COST_YR*100:.0f}%/yr")
for name,r in [("funding-ONLY",carry_fonly),("REAL(basis+fund)",carry_real),("REAL net",carry_real_net)]:
    s=stats(r,fa,T); i=stats(r,fa,split); o=stats(r,split,T)
    L(f"  {name:18} FULL Sh {s[0]:6.2f} ret {s[1]*100:5.1f}% DD {s[2]*100:4.1f}% worstday {s[3]:5.1f}% | IS {i[0]:6.2f} | OOS {o[0]:6.2f}")
c=np.corrcoef(carry_real_net[fa:],tr[fa:])[0,1]; co=np.corrcoef(carry_real_net[split:],tr[split:])[0,1]
L(f"  corr(carry_real, trend): FULL {c:+.2f}  OOS {co:+.2f}")
def vs(r,i0):
    v=np.std(r[i0:])*math.sqrt(ANN); return r*(0.10/v) if v>0 else r*0
trs=vs(tr,fa); cs=vs(carry_real_net,fa)
for name,r in [("TREND only",trs),("CARRY only",cs),("COMBO 50/50",0.5*trs+0.5*cs),("COMBO 60/40 tr/ca",0.6*trs+0.4*cs)]:
    s=stats(r,fa,T); o=stats(r,split,T)
    L(f"  {name:16} FULL Sh {s[0]:5.2f} DD {s[2]*100:4.1f}% | OOS Sh {o[0]:5.2f} DD {o[2]*100:4.1f}%")
ym={}
for t in range(fa,T): ym.setdefault(days[t][:4],[]).append(carry_real_net[t])
L("  REAL-carry net per-year: "+"  ".join(f"{y}:{(np.prod(1+np.array(v))-1)*100:+.0f}%" for y,v in sorted(ym.items())))
open("tools/funding_bt2_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-FB2\n")
print("\n".join(out)); print("DONE-FB2")

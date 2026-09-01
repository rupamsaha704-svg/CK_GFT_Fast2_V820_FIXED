#!/usr/bin/env python3
"""Robustness stress-test of the BTC+ETH daily time-series-momentum edge.
Checks: (a) sensitivity to lookback choice, (b) sensitivity to trading cost,
(c) per-year + drawdown for the base case. IS<2023 / OOS>=2023 (fair, no fitting)."""
import os, csv, math
import numpy as np

DATA="data_crypto"; MKTS=["BTC","ETH"]; VOL_WIN=60; ANN=252; TARGET=0.10

def load(m):
    d={}
    for row in csv.DictReader(open(os.path.join(DATA,m+".csv"),encoding="utf-8")):
        try: d[row["date"]]=float(row["close"])
        except: pass
    return d
series={m:load(m) for m in MKTS}
dates=sorted(set.intersection(*[set(series[m]) for m in MKTS]))
T=len(dates); idx={d:i for i,d in enumerate(dates)}
px={m:np.array([series[m][d] for d in dates]) for m in MKTS}
ret={m:np.zeros(T) for m in MKTS}
for m in MKTS: ret[m][1:]=px[m][1:]/px[m][:-1]-1
split=next((i for i,d in enumerate(dates) if d>="2023-01-01"),T)

def run(lookbacks,cost):
    W={m:np.zeros(T) for m in MKTS}
    s0=max(lookbacks)+1
    for m in MKTS:
        for t in range(s0,T):
            sig=np.mean([np.sign(px[m][t]/px[m][t-L]-1) for L in lookbacks])
            v=np.std(ret[m][t-VOL_WIN+1:t+1]); W[m][t]=0 if v<=0 else sig/v
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(s0+1,T):
        sret[t]=sum(W[m][t-1]*ret[m][t] for m in MKTS)
        turn[t]=sum(abs(W[m][t-1]-W[m][t-2]) for m in MKTS)
    rv=np.std(sret[s0+1:]); sc=TARGET/(rv*math.sqrt(ANN)) if rv>0 else 0
    net=sret*sc-turn*cost*sc
    return net,s0+1
def sh(r,i0,i1):
    r=r[i0:i1]; v=np.std(r)*math.sqrt(ANN)
    return (np.mean(r)*ANN)/v if v>0 else 0
def mdd(r,i0):
    eq=np.cumprod(1+r[i0:]); pk=np.maximum.accumulate(eq); return np.max((pk-eq)/pk)

out=[]; L=lambda s: out.append(str(s))
L(f"BTC+ETH daily TSMOM robustness  ({dates[0]}..{dates[-1]}, {T} days, IS<2023/OOS>=2023)")
L("")
L("(a) LOOKBACK sensitivity (cost 10bps):  FULL / IS / OOS Sharpe")
for lb in [[20,60,120,250],[50,100,200],[20,100],[100],[250],[10,30,60]]:
    net,st=run(lb,0.0010)
    L(f"   {str(lb):20}  {sh(net,st,T):5.2f} / {sh(net,st,split):5.2f} / {sh(net,split,T):5.2f}")
L("")
L("(b) COST sensitivity (lookbacks 20/60/120/250):  FULL / IS / OOS Sharpe")
for c in [0.0002,0.0010,0.0020,0.0040]:
    net,st=run([20,60,120,250],c)
    L(f"   {c*10000:4.0f} bps   {sh(net,st,T):5.2f} / {sh(net,st,split):5.2f} / {sh(net,split,T):5.2f}")
L("")
net,st=run([20,60,120,250],0.0010)
L("(c) BASE case (20/60/120/250, 10bps) per-year NET return:")
ym={}
for i in range(st,T): ym.setdefault(dates[i][:4],[]).append(net[i])
for y in sorted(ym):
    a=np.array(ym[y]); L(f"     {y}: {(np.prod(1+a)-1)*100:+7.1f}%")
L(f"   maxDD {mdd(net,st)*100:.1f}%   FULL Sharpe {sh(net,st,T):.2f}  OOS Sharpe {sh(net,split,T):.2f}")
open("tools/tsmom_crypto_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-CRYPTO-ROBUST\n")
print("\n".join(out)); print("DONE-CRYPTO-ROBUST")

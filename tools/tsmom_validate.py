#!/usr/bin/env python3
"""Rigorous validation battery for the BTC+ETH daily TSMOM edge.
All CAUSAL (no look-ahead): signal from closes<=t-1, position earns t-1->t return,
leverage from TRAILING realized vol (rolling, not full-sample).
Sections: base, execution stress, robustness grid, attribution, walk-forward, bootstrap."""
import os, csv, math
import numpy as np
rng = np.random.default_rng(12345)

DATA="data_crypto"; ANN=252
def load(m):
    d={}
    for r in csv.DictReader(open(os.path.join(DATA,m+".csv"),encoding="utf-8")):
        try: d[r["date"]]=(float(r["open"]),float(r["close"]))
        except: pass
    return d
S={m:load(m) for m in ["BTC","ETH"]}
dates=sorted(set.intersection(*[set(S[m]) for m in S]))
T=len(dates)
op={m:np.array([S[m][d][0] for d in dates]) for m in S}
cl={m:np.array([S[m][d][1] for d in dates]) for m in S}
rcc={m:np.zeros(T) for m in S}   # close-to-close
roo={m:np.zeros(T) for m in S}   # open-to-open (next-day execution proxy)
for m in S:
    rcc[m][1:]=cl[m][1:]/cl[m][:-1]-1
    # FORWARD open-to-open: decide at close[t-1] -> enter open[t] -> exit open[t+1].
    # net uses W[t-1]*roo[t] so this is the open[t]->open[t+1] move (no look-ahead).
    roo[m][:-1]=op[m][1:]/op[m][:-1]-1
split=next((i for i,d in enumerate(dates) if d>="2023-01-01"),T)

def raw_weights(markets,lookbacks,vol_win,rebal,direction):
    W={m:np.zeros(T) for m in markets}
    s0=max(lookbacks)+1
    last={m:0.0 for m in markets}
    for t in range(s0,T):
        if (t-s0)%rebal==0:
            for m in markets:
                sig=np.mean([np.sign(cl[m][t]/cl[m][t-L]-1) for L in lookbacks])
                if direction=="long": sig=max(sig,0.0)
                elif direction=="short": sig=min(sig,0.0)
                v=np.std(rcc[m][t-vol_win+1:t+1])
                last[m]=0.0 if v<=0 else sig/v
        for m in markets: W[m][t]=last[m]
    return W,s0

def net_series(markets,lookbacks=[20,60,120,250],vol_win=60,rebal=1,cost=0.0010,
               short_fund=0.0,exec="close",direction="both",target=0.10):
    W,s0=raw_weights(markets,lookbacks,vol_win,rebal,direction)
    r=rcc if exec=="close" else roo
    raw=np.zeros(T); turn=np.zeros(T); fund=np.zeros(T)
    for t in range(s0+1,T):
        raw[t]=sum(W[m][t-1]*r[m][t] for m in markets)
        turn[t]=sum(abs(W[m][t-1]-W[m][t-2]) for m in markets)
        # short funding: pay on gross short exposure (annual -> daily)
        fund[t]=sum(max(-W[m][t-1],0) for m in markets)*(short_fund/ANN)
    # CAUSAL leverage: target daily vol / trailing 60d realized vol of raw book (lagged)
    tdaily=target/math.sqrt(ANN)
    lev=np.zeros(T)
    for t in range(s0+2,T):
        tv=np.std(raw[max(s0+1,t-60):t])   # uses info < t
        lev[t]=0.0 if tv<=0 else tdaily/tv
    lev=np.clip(lev,0,50)
    net=lev*raw - lev*turn*cost - lev*fund
    return net,s0+2

def sharpe(net,i0,i1):
    r=net[i0:i1]; v=np.std(r)*math.sqrt(ANN)
    return (np.mean(r)*ANN)/v if v>0 else 0.0
def cagr(net,i0,i1):
    r=net[i0:i1]; eq=np.cumprod(1+r)
    return eq[-1]**(ANN/len(r))-1 if len(r)>0 and eq[-1]>0 else -1
def maxdd(net,i0,i1):
    eq=np.cumprod(1+net[i0:i1]); pk=np.maximum.accumulate(eq); return np.max((pk-eq)/pk)

out=[]; L=lambda s: out.append(str(s))
BOTH=["BTC","ETH"]
L(f"BTC+ETH TSMOM rigorous validation  ({dates[0]}..{dates[-1]}, {T} days)  IS<2023 / OOS>=2023")
L("all causal: 1-bar lag, rolling vol-target 10%, default 10bps cost")

# 1. BASE
net,st=net_series(BOTH)
L(""); L("=== 1. BASE (causal) ===")
L(f"  FULL Sharpe {sharpe(net,st,T):.2f}  CAGR {cagr(net,st,T)*100:.1f}%  maxDD {maxdd(net,st,T)*100:.1f}%")
L(f"  IS   Sharpe {sharpe(net,st,split):.2f}   |   OOS Sharpe {sharpe(net,split,T):.2f}")
ym={}
for i in range(st,T): ym.setdefault(dates[i][:4],[]).append(net[i])
L("  per-year: "+"  ".join(f"{y}:{(np.prod(1+np.array(v))-1)*100:+.0f}%" for y,v in sorted(ym.items())))

# 2. EXECUTION STRESS (OOS Sharpe)
L(""); L("=== 2. EXECUTION / COST STRESS (OOS Sharpe) ===")
for tag,kw in [("close-exec 10bps",dict()),
               ("NEXT-OPEN exec 10bps",dict(exec="open")),
               ("cost 25bps",dict(cost=0.0025)),
               ("cost 50bps",dict(cost=0.0050)),
               ("short-funding 20%/yr",dict(short_fund=0.20)),
               ("open+50bps+fund20%",dict(exec="open",cost=0.0050,short_fund=0.20))]:
    n,s=net_series(BOTH,**kw); L(f"  {tag:24} OOS {sharpe(n,split,T):5.2f}  FULL {sharpe(n,s,T):5.2f}")

# 3. ROBUSTNESS GRID (OOS Sharpe): lookbacks x vol_win, daily vs weekly rebal
L(""); L("=== 3. ROBUSTNESS GRID (OOS Sharpe) ===")
lbsets=[[20,60,120,250],[30,90,180],[10,30,60],[50,200]]
for reb in [1,5]:
    L(f"  rebalance every {reb}d:")
    for lb in lbsets:
        row=[]
        for vw in [20,60,120]:
            n,s=net_series(BOTH,lookbacks=lb,vol_win=vw,rebal=reb)
            row.append(f"vw{vw}:{sharpe(n,split,T):4.1f}")
        L(f"    {str(lb):18} "+"  ".join(row))

# 4. ATTRIBUTION
L(""); L("=== 4. ATTRIBUTION (FULL / OOS Sharpe) ===")
for tag,mk,dr in [("BTC only",["BTC"],"both"),("ETH only",["ETH"],"both"),
                  ("both long+short",BOTH,"both"),("both LONG-only",BOTH,"long"),("both SHORT-only",BOTH,"short")]:
    n,s=net_series(mk,direction=dr); L(f"  {tag:18} FULL {sharpe(n,s,T):5.2f}   OOS {sharpe(n,split,T):5.2f}")

# 5. STATISTICAL
L(""); L("=== 5. STATISTICAL SIGNIFICANCE ===")
yrs=sorted(ym); pos=sum(1 for y in yrs if np.prod(1+np.array(ym[y]))-1>0)
from math import comb
p_binom=sum(comb(len(yrs),k) for k in range(pos,len(yrs)+1))/2**len(yrs)
L(f"  years positive: {pos}/{len(yrs)}  (binomial P under no-edge ~ {p_binom*100:.2f}%, heuristic)")
# block bootstrap on OOS daily net returns
oos=net[split:]; B=20; nboot=3000; shs=[]
nb=len(oos)//B
for _ in range(nboot):
    idx=rng.integers(0,len(oos)-B,size=nb)
    samp=np.concatenate([oos[i:i+B] for i in idx])
    v=np.std(samp)*math.sqrt(ANN); shs.append((np.mean(samp)*ANN)/v if v>0 else 0)
shs=np.array(shs)
L(f"  OOS block-bootstrap Sharpe: mean {shs.mean():.2f}  5th pct {np.percentile(shs,5):.2f}  P(Sharpe>0) {np.mean(shs>0)*100:.1f}%")

open("tools/tsmom_validate_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-VALIDATE\n")
print("\n".join(out)); print("DONE-VALIDATE")

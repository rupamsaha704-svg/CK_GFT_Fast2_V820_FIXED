#!/usr/bin/env python3
"""Unified TSMOM dashboard - EVERY instrument judged the SAME way (one level):
historical edge (IS/OOS Sharpe, vol-target 10%, 10bps, causal) + today's live signal
+ objective verdict (durable if OOS Sharpe > 0.25). No per-instrument tuning."""
import os, csv, math
import numpy as np
LB=[20,60,120,250]; VW=60; ANN=252; TARGET=0.10; COST=0.0010
INSTR=[("BTC","data_crypto/BTC.csv"),("ETH","data_crypto/ETH.csv"),
       ("NQ(Nasdaq)","data_daily/NQ.csv"),("XAU(gold)","data_daily/GC.csv"),
       ("XAG(silver)","data_daily/SI.csv"),
       ("EURUSD","data_daily/EURUSD.csv"),("GBPUSD","data_daily/GBPUSD.csv")]
def load(p):
    d=[]
    for r in csv.DictReader(open(p,encoding="utf-8")):
        try: d.append((r["date"],float(r["close"])))
        except: pass
    return d
def analyze(closes):
    dts=[d for d,_ in closes]; px=np.array([c for _,c in closes]); T=len(px)
    ret=np.zeros(T); ret[1:]=px[1:]/px[:-1]-1
    split=next((i for i,d in enumerate(dts) if d>="2023-01-01"),T)
    W=np.zeros(T); s0=max(LB)+1
    for t in range(s0,T):
        sg=np.mean([np.sign(px[t]/px[t-L]-1) for L in LB]); v=np.std(ret[t-VW+1:t+1])
        W[t]=0 if v<=0 else sg/v
    net=np.zeros(T); turn=np.zeros(T)
    for t in range(s0+1,T):
        net[t]=W[t-1]*ret[t]; turn[t]=abs(W[t-1]-W[t-2])
    rv=np.std(net[s0+1:]); sc=TARGET/(rv*math.sqrt(ANN)) if rv>0 else 0
    net=net*sc-turn*COST*sc
    def sh(a,b):
        r=net[a:b]; return 0.0 if len(r)<10 or np.std(r)==0 else (np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))
    isS=sh(s0+1,split); oS=sh(split,T)
    # today's signal
    sig=np.mean([np.sign(px[-1]/px[-1-L]-1) for L in LB])
    vol=np.std(ret[-VW:]); w=0 if vol<=0 else sig*(0.05/math.sqrt(ANN)/vol); w=max(-3,min(3,w))
    return dts[-1], isS, oS, sig, w
out=[]; L=lambda s: out.append(str(s))
L("=== UNIFIED TSMOM DASHBOARD (every instrument, same rule, one level) ===")
L(f"{'instrument':12} {'IS Sh':>6} {'OOS Sh':>7} {'verdict':>10}   {'today':>10} {'dir':>5} {'sig':>6} {'pos%':>6}")
rows=[]
for name,path in INSTR:
    if not os.path.exists(path): L(f"{name}: no data"); continue
    dt_,isS,oS,sig,w=analyze(load(path))
    rows.append((name,isS,oS,sig,w,dt_))
rows.sort(key=lambda x:-x[2])
for name,isS,oS,sig,w,dt_ in rows:
    verdict="EDGE ✓" if oS>0.25 else ("weak" if oS>0 else "NO EDGE")
    dirn="LONG" if w>0 else ("SHORT" if w<0 else "FLAT")
    L(f"{name:12} {isS:6.2f} {oS:7.2f} {verdict:>10}   {dt_:>10} {dirn:>5} {sig:+6.2f} {w*100:+5.0f}%")
L("")
L("Rule: OOS Sharpe (2023-2026) > 0.25 = durable edge -> in the book. Same test for all.")
L("today = latest bar; dir/sig/pos = what the rule signals now (pos at 5% vol target).")
open("tools/tsmom_dashboard_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-DASH\n")
print("\n".join(out)); print("DONE-DASH")

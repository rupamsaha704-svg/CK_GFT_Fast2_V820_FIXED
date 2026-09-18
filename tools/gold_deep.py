#!/usr/bin/env python3
"""Deeper GOLD-only study: many trend/breakout variants + params, long/short AND long-only.
Goal: is gold's trend edge ROBUST across params (broad plateau = real) or a single spike (overfit)?
Honest: report ALL variants. Daily GC, vol-target 10% + 2bps/turn cost, causal. Gold = user priority.
"""
import os, csv, math
import numpy as np

DATA="data_daily"; ANN=252; COST=0.0002; TV=0.10; REC=315; SPLIT="2023-01-01"

def load_gc():
    rows=[]
    with open(os.path.join(DATA,"GC.csv"),encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            try: rows.append((r["date"],float(r["high"]),float(r["low"]),float(r["close"])))
            except (ValueError,KeyError): pass
    rows.sort(); return rows

def ema(x,p):
    n=len(x); o=np.full(n,np.nan); k=2.0/(p+1.0)
    if n<p: return o
    o[p-1]=np.mean(x[:p]); prev=o[p-1]
    for t in range(p,n): prev=x[t]*k+prev*(1-k); o[t]=prev
    return o

def pos_tsmom(C,LB):
    T=len(C); p=np.zeros(T); st=max(LB)+2
    for t in range(st,T):
        s=0.0
        for Lk in LB:
            if C[t-Lk]>0: s+=(1.0 if C[t]>C[t-Lk] else -1.0)
        p[t]=(1.0 if s>0 else (-1.0 if s<0 else 0.0))
    return p

def pos_donch(C,H,L,N):
    T=len(C); p=np.zeros(T); s=0.0
    for t in range(N+1,T):
        if C[t]>=np.max(H[t-N:t]): s=1.0
        elif C[t]<=np.min(L[t-N:t]): s=-1.0
        p[t]=s
    return p

def pos_macross(C,f,sl):
    T=len(C); ef=ema(C,f); es=ema(C,sl); p=np.zeros(T)
    for t in range(sl+1,T):
        if not np.isnan(ef[t]) and not np.isnan(es[t]): p[t]=1.0 if ef[t]>es[t] else -1.0
    return p

def sharpe(r):
    return float((np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))) if len(r)>0 and np.std(r)>0 else 0.0

def netret(pos,ret,T):
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(2,T): sret[t]=pos[t-1]*ret[t]; turn[t]=abs(pos[t-1]-pos[t-2])
    rv=np.std(sret); sc=(TV/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    return sret*sc - turn*COST*sc

def stats(r,i0,i1):
    r=r[i0:i1]
    if len(r)==0: return (0,0,0)
    eq=np.cumprod(1+r); peak=np.maximum.accumulate(eq); mdd=float(np.max((peak-eq)/peak)) if len(eq)>0 else 0
    return (sharpe(r), eq[-1]-1 if len(eq)>0 else 0, mdd)

def main():
    rows=load_gc(); dates=[r[0] for r in rows]
    H=np.array([r[1] for r in rows]); L=np.array([r[2] for r in rows]); C=np.array([r[3] for r in rows])
    T=len(C); ret=np.zeros(T); ret[1:]=C[1:]/C[:-1]-1.0
    si=next((i for i,d in enumerate(dates) if d>=SPLIT),T); fa=260
    variants=[]
    variants.append(("MAcross 10/50", pos_macross(C,10,50)))
    variants.append(("MAcross 20/100",pos_macross(C,20,100)))
    variants.append(("MAcross 20/50", pos_macross(C,20,50)))
    variants.append(("MAcross 50/200",pos_macross(C,50,200)))
    variants.append(("Donchian 10",   pos_donch(C,H,L,10)))
    variants.append(("Donchian 20",   pos_donch(C,H,L,20)))
    variants.append(("Donchian 40",   pos_donch(C,H,L,40)))
    variants.append(("Donchian 55",   pos_donch(C,H,L,55)))
    variants.append(("TSMOM fast",    pos_tsmom(C,[10,30,60])))
    variants.append(("TSMOM std",     pos_tsmom(C,[20,60,120,250])))
    variants.append(("TSMOM slow",    pos_tsmom(C,[60,120,250])))

    out=[]; Lg=lambda s: out.append(str(s))
    Lg("="*78); Lg("  GOLD (GC) DEEP TREND STUDY  - Sharpe FULL/OOS/rec15m + rec15m ret% + FULL maxDD")
    Lg("  each variant in LONG/SHORT (LS) and LONG-ONLY (LO). honest, no cherry-pick."); Lg("="*78)
    Lg(f"  {'variant':16}{'mode':4}{'FULLsh':>8}{'OOSsh':>7}{'recSh':>7}{'recRet':>8}{'FULLdd':>8}")
    pos_oos=0; tot=0
    for name,pLS in variants:
        pLO=np.maximum(0.0,pLS)
        for mode,p in [("LS",pLS),("LO",pLO)]:
            r=netret(p,ret,T)
            f=stats(r,fa,T); o=stats(r,si,T); rc=stats(r,max(fa,T-REC),T)
            Lg(f"  {name:16}{mode:4}{f[0]:>8.2f}{o[0]:>7.2f}{rc[0]:>7.2f}{rc[1]*100:>7.1f}%{f[2]*100:>7.1f}%")
            tot+=1;
            if o[0]>0: pos_oos+=1
    Lg("-"*78)
    Lg(f"  robustness: {pos_oos}/{tot} variant-modes have POSITIVE OOS Sharpe")
    Lg("  (broad positive = real trend edge on gold; only if most are +, not a lone spike)")
    Lg("="*78)
    open("tools/gold_deep_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-GOLDDEEP\n")
    print("\n".join(out)); print("DONE-GOLDDEEP")

if __name__=="__main__": main()

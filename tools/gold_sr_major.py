#!/usr/bin/env python3
"""GOLD (GC) with MAJOR support/resistance. Major level = a confirmed swing high/low that is the
extreme over a wide window (+/-W bars) -> a significant level, not a short-term N-day extreme.
Test BOTH honest interpretations, long/short AND long-only:
  BOUNCE  : buy near major support / sell near major resistance (fade)         -> mean-reversion
  BREAKOUT: go long when price breaks above major resistance, short/flat below -> trend
Causal: a swing at bar i is only CONFIRMED W bars later (needs the right window). Daily, vol-target
10% + 2bps cost. Report Sharpe FULL/OOS/recent-15m + recent return% + FULL maxDD. Honest, no fit.
"""
import os, csv, math
import numpy as np

DATA="data_daily"; ANN=252; COST=0.0002; TV=0.10; REC=315; SPLIT="2023-01-01"; TOL=0.5

def load_gc():
    rows=[]
    with open(os.path.join(DATA,"GC.csv"),encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            try: rows.append((r["date"],float(r["high"]),float(r["low"]),float(r["close"])))
            except (ValueError,KeyError): pass
    rows.sort(); return rows

def atr(H,L,C,n=14):
    T=len(C); tr=np.zeros(T)
    for t in range(1,T): tr[t]=max(H[t]-L[t],abs(H[t]-C[t-1]),abs(L[t]-C[t-1]))
    a=np.zeros(T)
    for t in range(n,T): a[t]=np.mean(tr[t-n+1:t+1])
    return a

def major_levels(H,L,W):
    """return lastRes[t], lastSup[t] = most recent CONFIRMED major swing high/low price known by t."""
    T=len(H); lastRes=np.full(T,np.nan); lastSup=np.full(T,np.nan)
    curR=np.nan; curS=np.nan
    for t in range(T):
        j=t-W  # bar j's right window [j..j+W]=[j..t] just completed
        if j-W>=0:
            if H[j]==np.max(H[j-W:j+W+1]): curR=H[j]
            if L[j]==np.min(L[j-W:j+W+1]): curS=L[j]
        lastRes[t]=curR; lastSup[t]=curS
    return lastRes,lastSup

def pos_breakout(C,res,sup):
    T=len(C); p=np.zeros(T); s=0.0
    for t in range(T):
        if not np.isnan(res[t]) and C[t]>res[t]: s=1.0
        elif not np.isnan(sup[t]) and C[t]<sup[t]: s=-1.0
        p[t]=s
    return p

def pos_bounce(C,res,sup,a):
    T=len(C); p=np.zeros(T); s=0.0
    for t in range(T):
        if np.isnan(res[t]) or np.isnan(sup[t]) or a[t]<=0: p[t]=s; continue
        if C[t] <= sup[t]+TOL*a[t]: s=1.0        # at major support -> long (bounce)
        elif C[t] >= res[t]-TOL*a[t]: s=-1.0      # at major resistance -> short
        p[t]=s
    return p

def sharpe(r): return float((np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))) if len(r)>0 and np.std(r)>0 else 0.0
def netret(pos,ret,T):
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(2,T): sret[t]=pos[t-1]*ret[t]; turn[t]=abs(pos[t-1]-pos[t-2])
    rv=np.std(sret); sc=(TV/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    return sret*sc-turn*COST*sc
def stat(r,i0,i1):
    r=r[i0:i1]
    if len(r)==0: return (0,0,0)
    eq=np.cumprod(1+r); pk=np.maximum.accumulate(eq); mdd=float(np.max((pk-eq)/pk))
    return (sharpe(r), eq[-1]-1, mdd)

def main():
    rows=load_gc(); dates=[r[0] for r in rows]
    H=np.array([r[1] for r in rows]); L=np.array([r[2] for r in rows]); C=np.array([r[3] for r in rows])
    T=len(C); ret=np.zeros(T); ret[1:]=C[1:]/C[:-1]-1.0
    a=atr(H,L,C); si=next((i for i,d in enumerate(dates) if d>=SPLIT),T); fa=120
    out=[]; Lg=lambda s: out.append(str(s))
    Lg("="*80); Lg("  GOLD (GC) MAJOR support/resistance  - BOUNCE(fade) vs BREAKOUT(trend)")
    Lg("  major level = swing extreme over +/-W bars (confirmed W bars late, causal). honest."); Lg("="*80)
    Lg(f"  {'strategy':22}{'mode':4}{'FULLsh':>8}{'OOSsh':>7}{'recSh':>7}{'recRet':>8}{'FULLdd':>8}")
    for W in [20,40]:
        res,sup=major_levels(H,L,W)
        for label,pfun in [(f"BOUNCE major W{W}", pos_bounce(C,res,sup,a)),
                           (f"BREAKOUT major W{W}", pos_breakout(C,res,sup))]:
            for mode,p in [("LS",pfun),("LO",np.maximum(0.0,pfun))]:
                r=netret(p,ret,T)
                f=stat(r,fa,T); o=stat(r,si,T); rc=stat(r,max(fa,T-REC),T)
                Lg(f"  {label:22}{mode:4}{f[0]:>8.2f}{o[0]:>7.2f}{rc[0]:>7.2f}{rc[1]*100:>7.1f}%{f[2]*100:>7.1f}%")
    Lg("="*80)
    open("tools/gold_sr_major_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-GSRM\n")
    print("\n".join(out)); print("DONE-GSRM")

if __name__=="__main__": main()

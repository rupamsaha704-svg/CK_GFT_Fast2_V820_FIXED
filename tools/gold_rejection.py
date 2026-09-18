#!/usr/bin/env python3
"""GOLD (GC) - REJECTION at MAJOR support/resistance, 1:1. Event-driven, causal, honest.
Only enter when price TESTS a major level AND prints a REJECTION candle (closes back off the level
with a rejection wick / directional close) - not just touching it. This is the refined S/R trade.
  major support: low tests support, closes back ABOVE, bullish rejection -> BUY (SL below, TP=1R)
  major resist : high tests resist, closes back BELOW, bearish rejection -> SELL (mirror)
Long/short AND long-only. Report trades/winrate/expectancy(R)/PF net-of-cost, FULL/IS/OOS/recent-15m.
"""
import os, csv, math
import numpy as np

DATA="data_daily"; W=20; TOL=0.5; BUF=0.5; H_HOLD=20; COST_R=0.03; SPLIT="2023-01-01"; RECDATE_BACK=315

def load_gc():
    rows=[]
    with open(os.path.join(DATA,"GC.csv"),encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            try: rows.append((r["date"],float(r["high"]),float(r["low"]),float(r["close"]),float(r["open"]) if "open" in r else float(r["close"])))
            except (ValueError,KeyError): pass
    rows.sort(); return rows

def atr(H,L,C,n=14):
    T=len(C); tr=np.zeros(T)
    for t in range(1,T): tr[t]=max(H[t]-L[t],abs(H[t]-C[t-1]),abs(L[t]-C[t-1]))
    a=np.zeros(T)
    for t in range(n,T): a[t]=np.mean(tr[t-n+1:t+1])
    return a

def major_levels(H,L):
    T=len(H); lastRes=np.full(T,np.nan); lastSup=np.full(T,np.nan); curR=np.nan; curS=np.nan
    for t in range(T):
        j=t-W
        if j-W>=0:
            if H[j]==np.max(H[j-W:j+W+1]): curR=H[j]
            if L[j]==np.min(L[j-W:j+W+1]): curS=L[j]
        lastRes[t]=curR; lastSup[t]=curS
    return lastRes,lastSup

def sim(O,H,L,C,dates,res,sup,a,long_only):
    T=len(C); trades=[]; pos=None; start=2*W+2
    for t in range(start,T):
        if pos is None:
            r=res[t]; s=sup[t]; at=a[t]
            if at<=0 or np.isnan(r) or np.isnan(s): continue
            rng=H[t]-L[t]
            if rng<=0: continue
            lw=min(O[t],C[t])-L[t]; uw=H[t]-max(O[t],C[t])
            # bullish rejection at major support
            buy = (L[t]<=s+TOL*at) and (C[t]>s) and ((C[t]>O[t]) or (lw>=0.5*rng))
            # bearish rejection at major resistance
            sell= (H[t]>=r-TOL*at) and (C[t]<r) and ((C[t]<O[t]) or (uw>=0.5*rng))
            if buy:
                entry=C[t]; sl=min(L[t],s)-BUF*at; R=entry-sl
                if R>0: pos=('L',entry,sl,entry+R,R,t)
            elif sell and not long_only:
                entry=C[t]; sl=max(H[t],r)+BUF*at; R=sl-entry
                if R>0: pos=('S',entry,sl,entry-R,R,t)
        else:
            d,entry,sl,tp,R,t0=pos; hi=H[t]; lo=L[t]; out=None
            if d=='L': hit_sl=lo<=sl; hit_tp=hi>=tp
            else: hit_sl=hi>=sl; hit_tp=lo<=tp
            if hit_sl: out=-1.0
            elif hit_tp: out=1.0
            elif (t-t0)>=H_HOLD:
                px=C[t]; out=((px-entry) if d=='L' else (entry-px))/R
            if out is not None: trades.append((dates[t0],out)); pos=None
    return trades

def agg(tr):
    if not tr: return None
    r=np.array([x[1] for x in tr]); n=len(r); wr=float(np.mean(r>0))*100
    exp=float(np.mean(r)); net=exp-COST_R; pos=r[r>0].sum(); neg=-r[r<0].sum()
    return dict(n=n,wr=wr,net=net,pf=(pos/neg if neg>0 else 9.99))

def fmt(a): return f"n{a['n']:>4} wr{a['wr']:3.0f}% net{a['net']:+.3f}R pf{a['pf']:.2f}" if a else "n/a"

def main():
    rows=load_gc(); dates=[r[0] for r in rows]
    H=np.array([r[1] for r in rows]); L=np.array([r[2] for r in rows]); C=np.array([r[3] for r in rows]); O=np.array([r[4] for r in rows])
    T=len(C); a=atr(H,L,C); res,sup=major_levels(H,L)
    recdate=dates[max(0,T-RECDATE_BACK)]
    out=[]; Lg=lambda s: out.append(str(s))
    Lg("="*66); Lg("  GOLD (GC) - REJECTION candle at MAJOR S/R, 1:1  (honest, event-driven)"); Lg("="*66)
    for mode,lo in [("LONG/SHORT",False),("LONG-ONLY",True)]:
        tr=sim(O,H,L,C,dates,res,sup,a,lo)
        isw=[x for x in tr if x[0]<SPLIT]; oos=[x for x in tr if x[0]>=SPLIT]; rec=[x for x in tr if x[0]>=recdate]
        Lg(f"  {mode}")
        Lg(f"    FULL {fmt(agg(tr))}")
        Lg(f"    IS   {fmt(agg(isw))}")
        Lg(f"    OOS  {fmt(agg(oos))}")
        Lg(f"    rec15m {fmt(agg(rec))}")
    Lg("="*66)
    open("tools/gold_rejection_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-REJ\n")
    print("\n".join(out)); print("DONE-REJ")

if __name__=="__main__": main()

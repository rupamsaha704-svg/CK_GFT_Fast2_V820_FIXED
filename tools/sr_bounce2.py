#!/usr/bin/env python3
"""Can the S/R bounce be IMPROVED with principled filters? Uniform test, all daily OHLC.
Variants (PRE-DECLARED, all reported - no cherry-pick):
  base            : touch level -> enter 1:1 (as before)
  +confirm        : require a rejection/directional close back inside the level
  +trend          : MA200 filter — buy support only if close>MA200 (uptrend), sell resistance only
                    if close<MA200 (downtrend)  [= buy dips in uptrend / sell rips in downtrend]
  +both           : confirm AND trend
  +both@2R        : same entries, target 1:2 (let trend-aligned pullbacks run)
Causal throughout; one position/market; SL-first; timeout 20d; cost 0.03R; IS<2023/OOS>=2023.
"""
import os, csv, math
import numpy as np

DATA="data_daily"; N=20; ATR_N=14; BUF_LEVEL=0.10; BUF_SL=0.5; H=20; COST_R=0.03; MA=200
SPLIT="2023-01-01"
CLASS={"ES":"equity","NQ":"equity","YM":"equity","RTY":"equity","DAX":"equity","NIKKEI":"equity","FTSE":"equity","STOXX":"equity","HSI":"equity",
 "ZN":"bond","ZB":"bond","ZF":"bond","ZT":"bond",
 "CL":"commod","BZ":"commod","NG":"commod","GC":"commod","SI":"commod","HG":"commod","PL":"commod","PA":"commod","ZC":"commod","ZW":"commod","ZS":"commod","KC":"commod","SB":"commod","CT":"commod","CC":"commod","LE":"commod","HE":"commod",
 "BTC":"crypto","ETH":"crypto",
 "EUR":"fx","GBP":"fx","AUD":"fx","NZD":"fx","USDCAD":"fx","USDCHF":"fx","USDJPY":"fx"}
def klass(m):
    for k,v in CLASS.items():
        if m.startswith(k): return v
    return "other"

def load_ohlc():
    mk={}
    for f in os.listdir(DATA):
        if not f.endswith(".csv"): continue
        m=f[:-4]; rows=[]
        with open(os.path.join(DATA,f),encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                try: rows.append((r["date"],float(r["open"]),float(r["high"]),float(r["low"]),float(r["close"])))
                except (ValueError,KeyError): pass
        rows.sort()
        if len(rows)>300: mk[m]=rows
    return mk

def atr_series(Hh,Ll,C,n):
    T=len(C); tr=np.zeros(T)
    for t in range(1,T): tr[t]=max(Hh[t]-Ll[t],abs(Hh[t]-C[t-1]),abs(Ll[t]-C[t-1]))
    atr=np.zeros(T)
    for t in range(n,T): atr[t]=np.mean(tr[t-n+1:t+1])
    return atr

def sim(rows, confirm=False, trend=False, RR=1.0):
    dates=[r[0] for r in rows]
    O=np.array([r[1] for r in rows]); Hh=np.array([r[2] for r in rows]); Ll=np.array([r[3] for r in rows]); C=np.array([r[4] for r in rows])
    T=len(C); atr=atr_series(Hh,Ll,C,ATR_N)
    ma=np.full(T,np.nan)
    for t in range(MA,T): ma[t]=np.mean(C[t-MA+1:t+1])
    trades=[]; pos=None; start=max(N,ATR_N,MA)+1
    for t in range(start,T):
        if pos is None:
            a=atr[t]
            if a<=0 or np.isnan(ma[t]): continue
            sup=float(np.min(Ll[t-N:t])); res=float(np.max(Hh[t-N:t]))
            buy = Ll[t] <= sup+BUF_LEVEL*a
            sell= Hh[t] >= res-BUF_LEVEL*a
            if confirm:
                buy = buy and (C[t]>O[t]) and (C[t]>sup)
                sell= sell and (C[t]<O[t]) and (C[t]<res)
            if trend:
                buy = buy and (C[t]>ma[t])
                sell= sell and (C[t]<ma[t])
            if buy:
                entry=C[t]; sl=sup-BUF_SL*a; R=entry-sl
                if R>0: pos=('L',entry,sl,entry+RR*R,R,t)
            elif sell:
                entry=C[t]; sl=res+BUF_SL*a; R=sl-entry
                if R>0: pos=('S',entry,sl,entry-RR*R,R,t)
        else:
            d,entry,sl,tp,R,t0=pos; hi=Hh[t]; lo=Ll[t]; out=None
            if d=='L': hit_sl=lo<=sl; hit_tp=hi>=tp
            else:      hit_sl=hi>=sl; hit_tp=lo<=tp
            if hit_sl: out=-1.0
            elif hit_tp: out=float(RR)
            elif (t-t0)>=H:
                px=C[t]; out=((px-entry) if d=='L' else (entry-px))/R
            if out is not None: trades.append((dates[t0],out)); pos=None
    return trades

def agg(tr):
    if not tr: return None
    r=np.array([x[1] for x in tr]); n=len(r); wr=float(np.mean(r>0))*100
    exp=float(np.mean(r)); net=exp-COST_R; pos=r[r>0].sum(); neg=-r[r<0].sum()
    return dict(n=n,wr=wr,exp=exp,net=net,pf=(pos/neg if neg>0 else 9.99))
def sp(tr): return [x for x in tr if x[0]<SPLIT],[x for x in tr if x[0]>=SPLIT]
def fmt(a): return (f"n{a['n']:>4} wr{a['wr']:3.0f}% net{a['net']:+.3f}R pf{a['pf']:.2f}") if a else "n/a"

def main():
    mk=load_ohlc(); out=[]; L=lambda s: out.append(str(s))
    by_class={}
    for m in mk: by_class.setdefault(klass(m),[]).append(m)
    variants=[("base",dict()),("+confirm",dict(confirm=True)),("+trend",dict(trend=True)),
              ("+both",dict(confirm=True,trend=True)),("+both@2R",dict(confirm=True,trend=True,RR=2.0))]
    L(f"S/R IMPROVE test  N={N} MA={MA}  cost {COST_R}R  (net = after cost)")
    for name,kw in variants:
        allt=[]; cls={c:[] for c in by_class}; keyt={}
        for m in mk:
            tr=sim(mk[m],**kw); allt+=tr; cls[klass(m)]+=tr
            if m in ("GC","EURUSD","BTC","NQ"): keyt[m]=tr
        _,ao=sp(allt)
        L(""); L(f"===== {name} =====")
        L(f"  ALL     FULL {fmt(agg(allt))}   OOS {fmt(agg(ao))}")
        for c in sorted(by_class):
            _,co=sp(cls[c]); L(f"  {c:7} OOS {fmt(agg(co))}")
        for m in ("GC","EURUSD","BTC","NQ"):
            if m in keyt: _,ko=sp(keyt[m]); L(f"    {m:7} OOS {fmt(agg(ko))}")
    open("tools/sr_bounce2_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-SR2\n")
    print("\n".join(out)); print("DONE-SR2")

if __name__=="__main__": main()

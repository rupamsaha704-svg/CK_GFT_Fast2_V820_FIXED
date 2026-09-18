#!/usr/bin/env python3
"""Support/Resistance BOUNCE, 1:1 — disciplined uniform test on daily OHLC.
Rule (as specified): at the recent N-day SUPPORT -> BUY; at the recent N-day RESISTANCE -> SELL.
Stop just beyond the level (ATR buffer); target = 1R (1:1). One position at a time per market.

Causal: the S/R level uses bars up to YESTERDAY (t-N..t-1). The touch is judged on today's
low/high; entry at today's CLOSE; the trade is then managed from the NEXT bar (SL-first if both
hit same bar; timeout after H bars -> mark-to-market in R). IS<2023 / OOS>=2023 by ENTRY date.

Anti-overfit: N pre-declared = 20 (10 & 50 shown as robustness, not to cherry-pick). A nominal
cost of 0.03R/trade is subtracted for the 'net' expectancy. Verdict = honest.
"""
import os, csv, math
import numpy as np

DATA="data_daily"
NS=[10,20,50]; PRIMARY=20
ATR_N=14; BUF_LEVEL=0.10; BUF_SL=0.5; H=20; COST_R=0.03
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
    for t in range(1,T):
        tr[t]=max(Hh[t]-Ll[t], abs(Hh[t]-C[t-1]), abs(Ll[t]-C[t-1]))
    atr=np.zeros(T)
    for t in range(n,T): atr[t]=np.mean(tr[t-n+1:t+1])
    return atr

def sim(rows,N):
    dates=[r[0] for r in rows]
    Hh=np.array([r[2] for r in rows]); Ll=np.array([r[3] for r in rows]); C=np.array([r[4] for r in rows])
    T=len(C); atr=atr_series(Hh,Ll,C,ATR_N); trades=[]; pos=None
    start=max(N,ATR_N)+1
    for t in range(start,T):
        if pos is None:
            a=atr[t]
            if a<=0: continue
            sup=float(np.min(Ll[t-N:t])); res=float(np.max(Hh[t-N:t]))
            if Ll[t] <= sup + BUF_LEVEL*a:
                entry=C[t]; sl=sup-BUF_SL*a; R=entry-sl
                if R>0: pos=('L',entry,sl,entry+R,R,t)
            elif Hh[t] >= res - BUF_LEVEL*a:
                entry=C[t]; sl=res+BUF_SL*a; R=sl-entry
                if R>0: pos=('S',entry,sl,entry-R,R,t)
        else:
            d,entry,sl,tp,R,t0=pos; hi=Hh[t]; lo=Ll[t]; out=None
            if d=='L': hit_sl=lo<=sl; hit_tp=hi>=tp
            else:      hit_sl=hi>=sl; hit_tp=lo<=tp
            if hit_sl: out=-1.0
            elif hit_tp: out=1.0
            elif (t-t0)>=H:
                px=C[t]; out=((px-entry) if d=='L' else (entry-px))/R
            if out is not None: trades.append((dates[t0],out)); pos=None
    return trades

def agg(trades):
    if not trades: return None
    r=np.array([x[1] for x in trades])
    n=len(r); wr=float(np.mean(r>0))*100; exp=float(np.mean(r)); net=exp-COST_R
    pos=r[r>0].sum(); neg=-r[r<0].sum(); pf=(pos/neg) if neg>0 else float('inf')
    return dict(n=n,wr=wr,exp=exp,net=net,pf=pf)

def split_trades(trades):
    return [x for x in trades if x[0]<SPLIT], [x for x in trades if x[0]>=SPLIT]

def line(label, tr):
    a=agg(tr)
    if not a: return f"  {label:16} (no trades)"
    isw,oos=split_trades(tr); ai=agg(isw); ao=agg(oos)
    def fmt(a): return f"n{a['n']:>4} wr{a['wr']:4.0f}% exp{a['exp']:+.3f}R net{a['net']:+.3f}R pf{a['pf']:.2f}" if a else "n/a"
    return (f"  {label:16} FULL {fmt(a)}\n"
            f"  {'':16}  IS  {fmt(ai) if ai else 'n/a'}\n"
            f"  {'':16}  OOS {fmt(ao) if ao else 'n/a'}")

def main():
    mk=load_ohlc()
    out=[]; L=lambda s: out.append(str(s))
    L(f"universe {len(mk)} markets  S/R BOUNCE 1:1  (SL beyond level +{BUF_SL}ATR, TP=1R, timeout {H}d, cost {COST_R}R)")
    by_class={}
    for m in mk: by_class.setdefault(klass(m),[]).append(m)
    for N in NS:
        tag = "PRIMARY" if N==PRIMARY else "robustness"
        L(""); L(f"===== N={N} ({tag}) =====")
        all_tr=[]
        cls_tr={c:[] for c in by_class}
        for m in mk:
            tr=sim(mk[m],N); all_tr+=tr; cls_tr[klass(m)]+=tr
        L(line("ALL", all_tr))
        for c in sorted(by_class): L(line(c, cls_tr[c]))
        if N==PRIMARY:
            L("  -- key single markets --")
            for m in ["GC","EURUSD","GBPUSD","USDJPY","NQ","ES","BTC","ETH"]:
                if m in mk: L(line(m, sim(mk[m],N)))
    open("tools/sr_bounce_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-SR\n")
    print("\n".join(out)); print("DONE-SR")

if __name__=="__main__": main()

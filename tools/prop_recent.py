#!/usr/bin/env python3
"""RECENT-window report (last 3/6/12/15 months) for GOLD (priority) and the crypto+NQ book.
Honest, on validated free daily data, $5000, vol-target 6% (GFT-safe). Gold shown separately
because the user is a gold trader. Gold's edge is recent-only (IS negative) - stated honestly.
"""
import os, csv, math
import numpy as np

DATA="data_daily"; LOOKBACKS=[20,60,120,250]; VOL_WIN=60; ANN=252; COST=0.0002
INIT=5000.0; VOL=0.06
BOOK={"BTC":0.35,"ETH":0.35,"NQ":0.30}
WINDOWS=[("last 3m",63),("last 6m",126),("last 12m",252),("last 15m",315)]

def load():
    ms=sorted(f[:-4] for f in os.listdir(DATA) if f.endswith(".csv")); series={}
    for m in ms:
        d={}
        with open(os.path.join(DATA,m+".csv"),encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                try: d[row["date"]]=float(row["close"])
                except (ValueError,KeyError): pass
        if len(d)>max(LOOKBACKS)+VOL_WIN+30: series[m]=d
    return sorted(series),series

def build(ms,series):
    dates=sorted(set().union(*[set(series[m]) for m in ms])); T=len(dates); idx={d:i for i,d in enumerate(dates)}
    px={}; vf={}
    for m in ms:
        a=np.full(T,np.nan)
        for d,v in series[m].items(): a[idx[d]]=v
        f=int(np.argmax(~np.isnan(a))); vf[m]=f; last=a[f]
        for t in range(f,T):
            if np.isnan(a[t]): a[t]=last
            else: last=a[t]
        px[m]=a
    ret={m:np.zeros(T) for m in ms}
    for m in ms: ret[m][vf[m]+1:]=px[m][vf[m]+1:]/px[m][vf[m]:-1]-1.0
    return dates,T,px,ret,vf

def tsmom_w(px,ret,vf,T,m):
    W=np.zeros(T); s=vf[m]+max(LOOKBACKS)+1
    for t in range(s,T):
        sig=np.mean([np.sign(px[m][t]/px[m][t-Lk]-1.0) for Lk in LOOKBACKS])
        vol=np.std(ret[m][t-VOL_WIN+1:t+1]); W[t]=0.0 if vol<=0 else sig/vol
    return W

def series_ret(px,ret,vf,T,Wd,subset,fa):
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(fa,T):
        pnl=0.0; tv=0.0
        for m in subset: pnl+=Wd[m][t-1]*ret[m][t]; tv+=abs(Wd[m][t-1]-Wd[m][t-2])
        sret[t]=pnl; turn[t]=tv
    rv=np.std(sret[fa:]); sc=(VOL/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    return sret*sc - turn*COST*sc

def winstats(r, fa, T, W):
    seg=r[max(fa,T-W):T]
    if len(seg)==0: return None
    eq=np.cumprod(1+seg); ret=eq[-1]-1
    peak=np.maximum.accumulate(eq); mdd=float(np.max((peak-eq)/peak))
    return dict(ret=ret, dollar=INIT*ret, mdd=mdd, worst=float(np.min(seg)), wr=float(np.mean(seg>0))*100, n=len(seg))

def report_series(L, name, r, dates, fa, T):
    L(f"  {name}")
    L(f"    {'window':10}{'return%':>9}{'P&L $':>9}{'maxDD%':>8}{'worstday':>9}{'win%':>6}")
    for wn,W in WINDOWS:
        s=winstats(r,fa,T,W)
        if s: L(f"    {wn:10}{s['ret']*100:>8.1f}%{s['dollar']:>9,.0f}{s['mdd']*100:>7.1f}%{s['worst']*100:>8.1f}%{s['wr']:>5.0f}%")

def main():
    ms,series=load(); dates,T,px,ret,vf=build(ms,series)
    present=[m for m in BOOK if m in ms]
    Wt={m:tsmom_w(px,ret,vf,T,m) for m in set(present+["GC"]) if m in ms}
    fa=min(vf[m]+max(LOOKBACKS)+2 for m in present)
    # book
    Wb={m:BOOK[m]*Wt[m] for m in present}
    book=series_ret(px,ret,vf,T,Wb,present,fa)
    # gold standalone
    gold=None
    if "GC" in ms:
        Wg={"GC":Wt["GC"]}; gold=series_ret(px,ret,vf,T,Wg,["GC"],fa)

    out=[]; L=lambda s: out.append(str(s))
    L("="*62)
    L(f"  RECENT-WINDOW report  (${INIT:.0f}, vol {VOL*100:.0f}%/yr, costs in)  through {dates[-1]}")
    L("  simulated on validated daily data (not MT5 ticks). GOLD shown first.")
    L("="*62)
    if gold is not None:
        L("GOLD (XAU / GC) - trend rule, STANDALONE  [your priority]")
        report_series(L,"gold-trend", gold, dates, fa, T)
        L("  honest note: gold trend is RECENT-ONLY (was negative 2016-2022) -> riding the")
        L("  current gold bull, NOT proven durable across regimes. Trade small / watch.")
        L("-"*62)
    L("CRYPTO+NQ BOOK (the validated durable edge)")
    report_series(L,"book", book, dates, fa, T)
    L("-"*62)
    L("per-instrument (last 12m, standalone trend, vol 6%):")
    for m in ["GC","BTC","ETH","NQ"]:
        if m in Wt:
            rm=series_ret(px,ret,vf,T,{m:Wt[m]},[m],fa); s=winstats(rm,fa,T,252)
            if s: L(f"    {m:5} 12m ret {s['ret']*100:+6.1f}%  maxDD {s['mdd']*100:4.1f}%  worst {s['worst']*100:+.1f}%")
    L("="*62)
    open("tools/prop_recent_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-RECENT\n")
    print("\n".join(out)); print("DONE-RECENT")

if __name__=="__main__": main()

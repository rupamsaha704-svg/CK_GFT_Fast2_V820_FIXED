#!/usr/bin/env python3
"""Disciplined test: does a VOLATILITY-MANAGED overlay improve the crypto+NQ TREND book?
(Moreira-Muir: scale exposure by inverse trailing realized vol of the book.)

Same engine/conventions as tsmom_bt.py. Strictly causal: the scale applied to day t uses the
book's realized vol through day t-1 only. Both base and managed are re-vol-targeted to 10% so
Sharpe AND drawdown are compared at equal risk (fair).

Anti-overfit: overlay windows PRE-DECLARED = {20, 60}; leverage clipped [0.33, 3.0] via a causal
expanding-mean reference. KEEP only if OOS Sharpe improves OR DD drops in BOTH windows; else REJECT.
"""
import os, csv, math
import numpy as np

DATA="data_daily"; LOOKBACKS=[20,60,120,250]; VOL_WIN=60
TARGET_ANN_VOL=0.10; COST=0.0002; ANN=252
BOOK={"BTC":0.35,"ETH":0.35,"NQ":0.30}
OVL_WINS=[20,60]

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

def port_net(Wd,ret,subset,fa,T):
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(fa,T):
        pnl=0.0; tv=0.0
        for m in subset: pnl+=Wd[m][t-1]*ret[m][t]; tv+=abs(Wd[m][t-1]-Wd[m][t-2])
        sret[t]=pnl; turn[t]=tv
    rv=np.std(sret[fa:]); sc=(TARGET_ANN_VOL/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    return sret*sc - turn*COST*sc

def vol_target(series, fa):
    rv=np.std(series[fa:]); sc=(TARGET_ANN_VOL/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    return series*sc

def stats(r,i0,i1):
    r=r[i0:i1]
    if len(r)==0 or np.std(r)==0: return dict(sh=0,cagr=0,mdd=0)
    eq=np.cumprod(1+r); yrs=len(r)/ANN; cagr=eq[-1]**(1/yrs)-1 if eq[-1]>0 else -1
    vol=np.std(r)*math.sqrt(ANN); sh=(np.mean(r)*ANN)/vol if vol>0 else 0
    peak=np.maximum.accumulate(eq); mdd=float(np.max((peak-eq)/peak))
    return dict(sh=sh,cagr=cagr,mdd=mdd)

def main():
    ms,series=load(); dates,T,px,ret,vf=build(ms,series)
    fa=min(vf[m]+max(LOOKBACKS)+2 for m in ms)
    split=next((i for i,d in enumerate(dates) if d>="2023-01-01"),T)
    out=[]; L=lambda s: out.append(str(s))
    present=[m for m in BOOK if m in ms]
    Wt={m:tsmom_w(px,ret,vf,T,m) for m in present}
    Wbook={m:BOOK[m]*Wt[m] for m in present}
    base=port_net(Wbook,ret,present,fa,T)
    b_full=stats(base,fa,T); b_is=stats(base,fa,split); b_oos=stats(base,split,T)
    L(f"universe {len(ms)}m {dates[0]}..{dates[-1]}  book={present}")
    L(f"BASE book         FULL Sh {b_full['sh']:.2f} DD {b_full['mdd']*100:4.1f}% | IS {b_is['sh']:.2f} | OOS {b_oos['sh']:.2f} DD {b_oos['mdd']*100:4.1f}%")
    L("")
    L("=== VOL-MANAGED overlay (causal; re-vol-targeted to 10%) ===")
    verdict_rows=[]
    for W in OVL_WINS:
        rv=np.zeros(T)
        for t in range(fa+W,T): rv[t]=np.std(base[t-W+1:t+1])
        ref=np.zeros(T); cs=0.0; cnt=0
        for t in range(fa,T):
            if rv[t]>0: cs+=rv[t]; cnt+=1
            ref[t]=cs/cnt if cnt>0 else 0.0
        managed=np.zeros(T)
        for t in range(fa+W+1,T):
            if rv[t-1]>0:
                scale=ref[t-1]/rv[t-1]
                scale=min(3.0,max(0.33,scale))
                managed[t]=scale*base[t]
        managed=vol_target(managed,fa+W+1)
        m_full=stats(managed,fa+W+1,T); m_is=stats(managed,fa+W+1,split); m_oos=stats(managed,split,T)
        L(f"VOL-MGD W={W:<2}       FULL Sh {m_full['sh']:.2f} DD {m_full['mdd']*100:4.1f}% | IS {m_is['sh']:.2f} | OOS {m_oos['sh']:.2f} DD {m_oos['mdd']*100:4.1f}%")
        verdict_rows.append((W,m_oos['sh'],m_oos['mdd']))
    L("")
    # verdict
    up_both = all(sh > b_oos['sh']+0.03 for _,sh,_ in verdict_rows)
    dd_both = all(dd < b_oos['mdd']-0.005 for _,_,dd in verdict_rows)
    L(f"BASE OOS: Sh {b_oos['sh']:.2f} DD {b_oos['mdd']*100:.1f}%")
    L(f"gate -> OOS Sharpe up in BOTH windows: {up_both} ; DD down in BOTH: {dd_both}")
    L(f"VERDICT: {'KEEP overlay' if (up_both or dd_both) else 'REJECT (no robust improvement)'}")
    open("tools/book_overlay_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-OVL\n")
    print("\n".join(out)); print("DONE-OVL")

if __name__=="__main__": main()

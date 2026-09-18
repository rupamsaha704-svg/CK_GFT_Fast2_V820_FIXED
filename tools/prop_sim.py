#!/usr/bin/env python3
"""GFT 5K 2-step prop-firm CHALLENGE simulator for the validated crypto+NQ book.
Uses the SAME engine/data as tsmom_bt.py (free 10y daily). Honest — no faking:
reports profit, drawdown (peak AND static-from-initial), worst day, rule breaches, and the
historical pass-rate/days for Step1(+8%) and Step2(+5%) across many start dates, per vol sizing.

Rules (GFT-approx, configurable): Step1 +8%, Step2 +5%, max daily loss 5%, max STATIC drawdown
10% (measured from INITIAL balance, not trailing), initial 5000, no time limit.
"""
import os, csv, math
import numpy as np

DATA="data_daily"; LOOKBACKS=[20,60,120,250]; VOL_WIN=60; ANN=252; COST=0.0002
BOOK={"BTC":0.35,"ETH":0.35,"NQ":0.30}
VOLS=[0.06,0.08,0.10,0.12]
INIT=5000.0; T1=0.08; T2=0.05; DAILY=0.05; STATIC=0.10

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

def book_returns(dates,T,px,ret,vf,present):
    Wt={m:tsmom_w(px,ret,vf,T,m) for m in present}
    Wb={m:BOOK[m]*Wt[m] for m in present}
    fa=min(vf[m]+max(LOOKBACKS)+2 for m in present)
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(fa,T):
        pnl=0.0; tv=0.0
        for m in present: pnl+=Wb[m][t-1]*ret[m][t]; tv+=abs(Wb[m][t-1]-Wb[m][t-2])
        sret[t]=pnl; turn[t]=tv
    return sret,turn,fa

def scale_to_vol(sret,turn,fa,V):
    rv=np.std(sret[fa:]); sc=(V/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    return sret*sc - turn*COST*sc

def stats(r,fa,T):
    r=r[fa:T]
    if len(r)==0 or np.std(r)==0: return dict(ann=0,mdd=0,worst=0)
    eq=np.cumprod(1+r); yrs=len(r)/ANN
    ann=eq[-1]**(1/yrs)-1 if eq[-1]>0 else -1
    peak=np.maximum.accumulate(eq); mdd=float(np.max((peak-eq)/peak))
    return dict(ann=ann,mdd=mdd,worst=float(np.min(r)))

def challenge(r, s0, T):
    """simulate one challenge from start s0. returns (result, days1, days2)
    result: 'both','step1only','fail_static','fail_daily','timeout'"""
    eq=INIT; days1=0; t=s0; passed1=False; endt=s0
    for t in range(s0,T):
        d=r[t]
        if d < -DAILY: return ('fail_daily',t-s0,0)
        eq*=(1+d)
        if eq <= INIT*(1-STATIC): return ('fail_static',t-s0,0)
        if eq >= INIT*(1+T1): passed1=True; days1=t-s0; endt=t; break
    if not passed1: return ('timeout',0,0)
    INIT2=eq; eq2=eq
    for t2 in range(endt+1,T):
        d=r[t2]
        if d < -DAILY: return ('step1only',days1,t2-endt)
        eq2*=(1+d)
        if eq2 <= INIT2*(1-STATIC): return ('step1only',days1,t2-endt)
        if eq2 >= INIT2*(1+T2): return ('both',days1,t2-endt)
    return ('step1only',days1,0)

def run_challenges(r, fa, T):
    starts=range(fa, T-10, 3)
    tot=0; both=0; s1=0; fs=0; fd=0; d1=[]; d2=[]
    for s in starts:
        res,a,b=challenge(r,s,T); tot+=1
        if res=='both': both+=1; s1+=1; d1.append(a); d2.append(b)
        elif res=='step1only': s1+=1; d1.append(a)
        elif res=='fail_static': fs+=1
        elif res=='fail_daily': fd+=1
    med=lambda x: int(np.median(x)) if x else -1
    return dict(tot=tot,both=both,s1=s1,fs=fs,fd=fd,md1=med(d1),md2=med(d2))

def main():
    ms,series=load(); dates,T,px,ret,vf=build(ms,series)
    present=[m for m in BOOK if m in ms]
    sret,turn,fa=book_returns(dates,T,px,ret,vf,present)
    out=[]; L=lambda s: out.append(str(s))
    L(f"GFT 5K 2-step prop sim  book={present}  {dates[fa]}..{dates[-1]}")
    L(f"rules: Step1 +{T1*100:.0f}% Step2 +{T2*100:.0f}% | daily loss {DAILY*100:.0f}% | STATIC DD {STATIC*100:.0f}% from ${INIT:.0f} | no time limit")
    # recent window (last ~3yr)
    r3 = next((i for i,d in enumerate(dates) if d>="2023-09-01"), fa)
    for V in VOLS:
        r=scale_to_vol(sret,turn,fa,V)
        full=stats(r,fa,T); rec=stats(r,r3,T)
        L("")
        L(f"=== vol target {V*100:.0f}%  (per-$5000) ===")
        L(f"  FULL   ann {full['ann']*100:5.1f}%  maxDD(peak) {full['mdd']*100:4.1f}%  worstday {full['worst']*100:+.1f}%")
        L(f"  last3y ann {rec['ann']*100:5.1f}%  maxDD(peak) {rec['mdd']*100:4.1f}%  worstday {rec['worst']*100:+.1f}%")
        # static-DD headroom check: does equity from a fresh $5000 start ever breach -10%? -> the challenge sim captures it
        c=run_challenges(r,fa,T)
        p_both=100.0*c['both']/c['tot']; p_s1=100.0*c['s1']/c['tot']; p_fs=100.0*c['fs']/c['tot']; p_fd=100.0*c['fd']/c['tot']
        L(f"  challenge (over {c['tot']} historical starts):")
        L(f"    Step1 pass {p_s1:4.1f}% (median {c['md1']}d) | BOTH steps pass {p_both:4.1f}% (step2 median {c['md2']}d)")
        L(f"    fail static-DD {p_fs:4.1f}% | fail daily-loss {p_fd:4.1f}%")
    L("")
    L("note: daily-rebalanced daily book -> intraday not modeled; daily P&L used for the 5% daily check.")
    L("      'static DD from initial' is the binding GFT constraint; lower vol = safer DD, slower target.")
    open("tools/prop_sim_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-PROP\n")
    print("\n".join(out)); print("DONE-PROP")

if __name__=="__main__": main()

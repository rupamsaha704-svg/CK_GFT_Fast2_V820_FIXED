#!/usr/bin/env python3
"""MT5-backtest-STYLE report for the validated crypto+NQ book on a $5000 account.
Simulated on the SAME validated free daily data (Yahoo/Binance) as the rest of the lab, because
the crypto symbols are not available on the MetaQuotes terminal. Costs included. Reports total
profit, per-YEAR and per-MONTH P&L, worst drawdown episodes, worst days — like an MT5 report.
"""
import os, csv, math, datetime
import numpy as np

DATA="data_daily"; LOOKBACKS=[20,60,120,250]; VOL_WIN=60; ANN=252; COST=0.0002
BOOK={"BTC":0.35,"ETH":0.35,"NQ":0.30}
INIT=5000.0; VOL=0.08   # recommended GFT sizing

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

def main():
    ms,series=load(); dates,T,px,ret,vf=build(ms,series)
    present=[m for m in BOOK if m in ms]
    Wt={m:tsmom_w(px,ret,vf,T,m) for m in present}
    Wb={m:BOOK[m]*Wt[m] for m in present}
    fa=min(vf[m]+max(LOOKBACKS)+2 for m in present)
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(fa,T):
        pnl=0.0; tv=0.0
        for m in present: pnl+=Wb[m][t-1]*ret[m][t]; tv+=abs(Wb[m][t-1]-Wb[m][t-2])
        sret[t]=pnl; turn[t]=tv
    rv=np.std(sret[fa:]); sc=(VOL/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    r=sret*sc - turn*COST*sc

    # equity path on $5000
    eqd=[]; eq=INIT
    for t in range(fa,T):
        eq*= (1+r[t]); eqd.append((dates[t], r[t], eq))
    finals=eq; net=finals-INIT
    rr=np.array([x[1] for x in eqd]); eqv=np.array([x[2] for x in eqd])
    yrs=len(rr)/ANN; cagr=(finals/INIT)**(1/yrs)-1
    peak=np.maximum.accumulate(eqv); dd=(peak-eqv)/peak; mdd=float(np.max(dd)); mdd_dollar=float(np.max(peak-eqv))
    shp=(np.mean(rr)*ANN)/(np.std(rr)*math.sqrt(ANN)) if np.std(rr)>0 else 0

    out=[]; L=lambda s: out.append(str(s))
    L("="*64)
    L("  CK CRYPTO+NQ BOOK - backtest-style report (simulated)")
    L("="*64)
    L("  NOTE: simulated on validated free DAILY data (Yahoo/Binance), NOT MT5 broker ticks")
    L("        (crypto symbols unavailable on this terminal). Costs included. Daily rebalance.")
    L(f"  Instruments : {'+'.join(present)}   Deposit: ${INIT:.0f}")
    L(f"  Vol target  : {VOL*100:.0f}%/yr   Period: {eqd[0][0]} .. {eqd[-1][0]}  ({yrs:.1f} yrs)")
    L("-"*64)
    L(f"  Total Net Profit : ${net:,.0f}   ({(finals/INIT-1)*100:+.1f}%)   Final: ${finals:,.0f}")
    L(f"  CAGR (per year)  : {cagr*100:+.1f}%")
    L(f"  Max Drawdown     : {mdd*100:.1f}%   (${mdd_dollar:,.0f})")
    L(f"  Best day / Worst : {rr.max()*100:+.1f}% / {rr.min()*100:+.1f}%   Win days: {np.mean(rr>0)*100:.0f}%   Sharpe: {shp:.2f}")

    # yearly
    L("-"*64); L("  PER YEAR:")
    L(f"    {'year':6}{'return%':>10}{'P&L $':>12}{'maxDD%':>9}")
    yrmap={}
    for d,ri,e in eqd: yrmap.setdefault(d[:4],[]).append((d,ri,e))
    prev=INIT
    for y in sorted(yrmap):
        seg=yrmap[y]; e0=prev; e1=seg[-1][2]
        ev=np.array([x[2] for x in seg]); pk=np.maximum.accumulate(np.concatenate([[e0],ev])); ddy=float(np.max((pk-np.concatenate([[e0],ev]))/pk))
        L(f"    {y:6}{(e1/e0-1)*100:>9.1f}%{e1-e0:>12,.0f}{ddy*100:>8.1f}%")
        prev=e1

    # monthly matrix (% returns)
    L("-"*64); L("  MONTHLY RETURN % (compounded):")
    L("    year   Jan   Feb   Mar   Apr   May   Jun   Jul   Aug   Sep   Oct   Nov   Dec")
    mm={}
    for d,ri,e in eqd: mm.setdefault(d[:4],{}).setdefault(d[5:7],[]).append(ri)
    for y in sorted(mm):
        cells=[]
        for mo in ["01","02","03","04","05","06","07","08","09","10","11","12"]:
            if mo in mm[y]:
                mr=np.prod([1+x for x in mm[y][mo]])-1
                cells.append(f"{mr*100:>5.1f}")
            else: cells.append("    .")
        L(f"    {y}  "+" ".join(cells))

    # worst drawdown episodes
    L("-"*64); L("  WORST DRAWDOWN PERIODS (when losses happen):")
    episodes=[]; pk=eqv[0]; pk_i=0; in_dd=False; tr=eqv[0]; tr_i=0
    for i in range(len(eqv)):
        if eqv[i]>=pk:
            if in_dd:
                episodes.append((pk_i,tr_i,i,(pk-tr)/pk)); in_dd=False
            pk=eqv[i]; pk_i=i; tr=eqv[i]; tr_i=i
        else:
            if eqv[i]<tr: tr=eqv[i]; tr_i=i
            in_dd=True
    if in_dd: episodes.append((pk_i,tr_i,len(eqv)-1,(pk-tr)/pk))
    episodes.sort(key=lambda e:-e[3])
    L(f"    {'peak date':12}{'trough date':13}{'depth%':>8}{'$ lost':>10}")
    for (pi,ti,ri,depth) in episodes[:6]:
        pdate=eqd[pi][0]; tdate=eqd[ti][0]; dollar=eqd[pi][2]-eqd[ti][2]
        L(f"    {pdate:12}{tdate:13}{depth*100:>7.1f}%{dollar:>10,.0f}")
    L("="*64)
    open("tools/prop_report_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-RPT\n")
    print("\n".join(out)); print("DONE-RPT")

if __name__=="__main__": main()

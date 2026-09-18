#!/usr/bin/env python3
"""Strategy ZOO - honest uniform test of several DISTINCT families on daily OHLC.
GOLD (GC) shown first (user priority), then all markets. No faking, no cherry-pick.
Families (all causal, position pos[t] uses info through t, applied pos[t-1]*ret[t]):
  TSMOM     : sign of avg sign(20/60/120/250-day return)         (trend)
  DONCH20/55: Donchian breakout state (+1 new N-high, -1 new N-low, else hold)  (trend/breakout)
  MAcross   : EMA20 > EMA100 -> +1 else -1                        (trend)
  BollMR    : fade Bollinger(20,2) - short above +2sd, long below -2sd, exit at mean (mean-rev)
Per market: vol-target 10% + 2bps/turnover cost. Report Sharpe FULL / OOS(>=2023) / recent-15m.
"""
import os, csv, math
import numpy as np

DATA="data_daily"; ANN=252; COST=0.0002; TV=0.10
LB=[20,60,120,250]; DN=[20,55]; MAF=20; MAS=100; BN=20; BK=2.0
REC=315  # last ~15 months (locked window)
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

def load():
    mk={}
    for f in os.listdir(DATA):
        if not f.endswith(".csv"): continue
        m=f[:-4]; rows=[]
        with open(os.path.join(DATA,f),encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                try: rows.append((r["date"],float(r["high"]),float(r["low"]),float(r["close"])))
                except (ValueError,KeyError): pass
        rows.sort()
        if len(rows)>max(LB)+300: mk[m]=rows
    return mk

def ema(x,p):
    n=len(x); o=np.full(n,np.nan); k=2.0/(p+1.0)
    if n<p: return o
    o[p-1]=np.mean(x[:p]); prev=o[p-1]
    for t in range(p,n): prev=x[t]*k+prev*(1-k); o[t]=prev
    return o

def positions(C,H,L):
    T=len(C); start=max(LB)+2
    pos={}
    # TSMOM
    p=np.zeros(T)
    for t in range(start,T):
        s=0.0;n=0
        for Lk in LB:
            if C[t-Lk]>0: s+=(1.0 if C[t]>C[t-Lk] else (-1.0 if C[t]<C[t-Lk] else 0.0)); n+=1
        p[t]=(1.0 if s>0 else (-1.0 if s<0 else 0.0))
    pos["TSMOM"]=p
    # Donchian
    for N in DN:
        p=np.zeros(T); s=0.0
        for t in range(N+1,T):
            hh=np.max(H[t-N:t]); ll=np.min(L[t-N:t])
            if C[t]>=hh: s=1.0
            elif C[t]<=ll: s=-1.0
            p[t]=s
        pos[f"DONCH{N}"]=p
    # MA cross
    ef=ema(C,MAF); es=ema(C,MAS); p=np.zeros(T)
    for t in range(MAS+1,T):
        if not np.isnan(ef[t]) and not np.isnan(es[t]): p[t]=1.0 if ef[t]>es[t] else -1.0
    pos["MAcross"]=p
    # Bollinger MR
    p=np.zeros(T); s=0.0
    for t in range(BN+1,T):
        w=C[t-BN:t]; ma=np.mean(w); sd=np.std(w)
        if sd>0:
            if C[t]>ma+BK*sd: s=-1.0
            elif C[t]<ma-BK*sd: s=1.0
            elif s==1.0 and C[t]>=ma: s=0.0
            elif s==-1.0 and C[t]<=ma: s=0.0
        p[t]=s
    pos["BollMR"]=p
    return pos

def sharpe(r):
    if len(r)==0 or np.std(r)==0: return 0.0
    return float((np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN)))

def strat_returns(pos,ret,T):
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(2,T):
        sret[t]=pos[t-1]*ret[t]; turn[t]=abs(pos[t-1]-pos[t-2])
    rv=np.std(sret); sc=(TV/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    return sret*sc - turn*COST*sc

def main():
    mk=load(); out=[]; L=lambda s: out.append(str(s))
    strategies=["TSMOM","DONCH20","DONCH55","MAcross","BollMR"]
    # precompute per market: for each strat -> (full,oos,rec) sharpe
    res={}  # res[m][strat]=(full,oos,rec)
    for m,rows in mk.items():
        dates=[r[0] for r in rows]; H=np.array([r[1] for r in rows]); Lo=np.array([r[2] for r in rows]); C=np.array([r[3] for r in rows])
        T=len(C); ret=np.zeros(T); ret[1:]=C[1:]/C[:-1]-1.0
        si=next((i for i,d in enumerate(dates) if d>=SPLIT),T)
        pos=positions(C,H,Lo); res[m]={}
        for st in strategies:
            r=strat_returns(pos[st],ret,T)
            fa=max(LB)+3
            res[m][st]=(sharpe(r[fa:T]), sharpe(r[si:T]), sharpe(r[max(fa,T-REC):T]))

    L("="*74); L("  STRATEGY ZOO (Sharpe: FULL / OOS>=2023 / recent-15m-LOCKED)  - honest, no fit")
    L("="*74)
    hdr="  "+f"{'':10}"+"".join(f"{s:>12}" for s in strategies)
    # GOLD FIRST
    if "GC" in res:
        L("GOLD (GC) - YOUR PRIORITY:")
        for lab,i in [("FULL",0),("OOS",1),("recent15m",2)]:
            L("  "+f"{lab:10}"+"".join(f"{res['GC'][s][i]:>12.2f}" for s in strategies))
        L("-"*74)
    # per-class mean OOS
    byc={}
    for m in res: byc.setdefault(klass(m),[]).append(m)
    L("per-class MEAN OOS Sharpe:")
    L(hdr)
    for c in sorted(byc):
        row=[np.mean([res[m][s][1] for m in byc[c]]) for s in strategies]
        L("  "+f"{c:10}"+"".join(f"{v:>12.2f}" for v in row))
    L("-"*74)
    # key markets OOS
    L("key markets (OOS Sharpe):")
    L(hdr)
    for m in ["GC","BTC","ETH","NQ","EURUSD","GBPUSD","USDJPY","CL","SI"]:
        if m in res:
            L("  "+f"{m:10}"+"".join(f"{res[m][s][1]:>12.2f}" for s in strategies))
    L("-"*74)
    # recent-15m for key markets (the locked window)
    L("key markets (recent-15m LOCKED Sharpe):")
    L(hdr)
    for m in ["GC","BTC","ETH","NQ","EURUSD","GBPUSD","USDJPY","CL","SI"]:
        if m in res:
            L("  "+f"{m:10}"+"".join(f"{res[m][s][2]:>12.2f}" for s in strategies))
    L("="*74)
    open("tools/strat_zoo_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-ZOO\n")
    print("\n".join(out)); print("DONE-ZOO")

if __name__=="__main__": main()

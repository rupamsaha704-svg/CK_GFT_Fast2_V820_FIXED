#!/usr/bin/env python3
"""Recent-regime view of the TSMOM edge: performance over trailing windows
(FULL / 2Y / 1Y / 6M / 3M) for crypto (BTC+ETH) and each multi-asset class.
Answers: what is working NOW (volatile regime)? Causal, 1-bar lag, vol-target 10%, 10bps."""
import os, csv, math
import numpy as np
LOOKBACKS=[20,60,120,250]; VOL_WIN=60; ANN=252; TARGET=0.10; COST=0.0010
CLASS={"ES":"equity","NQ":"equity","YM":"equity","RTY":"equity","DAX":"equity","NIKKEI":"equity","FTSE":"equity","STOXX":"equity","HSI":"equity",
 "ZN":"bond","ZB":"bond","ZF":"bond","ZT":"bond","CL":"commod","BZ":"commod","NG":"commod","GC":"commod","SI":"commod","HG":"commod","PL":"commod","PA":"commod",
 "ZC":"commod","ZW":"commod","ZS":"commod","KC":"commod","SB":"commod","CT":"commod","CC":"commod","LE":"commod","HE":"commod","BTC":"crypto","ETH":"crypto",
 "EURUSD":"fx","GBPUSD":"fx","AUDUSD":"fx","NZDUSD":"fx","USDCAD":"fx","USDCHF":"fx","USDJPY":"fx"}
def klass(m):
    for k,v in CLASS.items():
        if m.startswith(k): return v
    return "other"

def load(dirn):
    mk=sorted(f[:-4] for f in os.listdir(dirn) if f.endswith(".csv"))
    S={}
    for m in mk:
        d={}
        for r in csv.DictReader(open(os.path.join(dirn,m+".csv"),encoding="utf-8")):
            try: d[r["date"]]=float(r["close"])
            except: pass
        if len(d)>max(LOOKBACKS)+VOL_WIN+30: S[m]=d
    return sorted(S), S

def engine(dirn):
    mk,S=load(dirn)
    dts=sorted(set().union(*[set(S[m]) for m in mk])); T=len(dts); idx={d:i for i,d in enumerate(dts)}
    px={}; vf={}
    for m in mk:
        a=np.full(T,np.nan)
        for d,v in S[m].items(): a[idx[d]]=v
        f=int(np.argmax(~np.isnan(a))); vf[m]=f; last=a[f]
        for t in range(f,T):
            if np.isnan(a[t]): a[t]=last
            else: last=a[t]
        px[m]=a
    ret={m:np.zeros(T) for m in mk}
    for m in mk: ret[m][vf[m]+1:]=px[m][vf[m]+1:]/px[m][vf[m]:-1]-1
    W={m:np.zeros(T) for m in mk}
    for m in mk:
        s=vf[m]+max(LOOKBACKS)+1
        for t in range(s,T):
            sig=np.mean([np.sign(px[m][t]/px[m][t-L]-1) for L in LOOKBACKS])
            v=np.std(ret[m][t-VOL_WIN+1:t+1]); W[m][t]=0 if v<=0 else sig/v
    fa=min(vf[m]+max(LOOKBACKS)+2 for m in mk)
    def port(sub):
        raw=np.zeros(T); tn=np.zeros(T)
        for t in range(fa,T):
            raw[t]=sum(W[m][t-1]*ret[m][t] for m in sub)
            tn[t]=sum(abs(W[m][t-1]-W[m][t-2]) for m in sub)
        rv=np.std(raw[fa:]); sc=TARGET/(rv*math.sqrt(ANN)) if rv>0 else 0
        return raw*sc-tn*COST*sc
    return mk,dts,fa,port

def wstats(net,dts,fa,win):
    i1=len(net); i0=max(fa, i1-win) if win else fa
    r=net[i0:i1]
    if len(r)<10 or np.std(r)==0: return "  n/a"
    eq=np.cumprod(1+r); tot=(eq[-1]-1)*100
    sh=(np.mean(r)*ANN)/(np.std(r)*math.sqrt(ANN))
    pk=np.maximum.accumulate(eq); dd=np.max((pk-eq)/pk)*100
    return f"Sh{sh:5.2f} ret{tot:+6.1f}% dd{dd:4.1f}%"

WINS=[("FULL",0),("2Y",504),("1Y",252),("6M",126),("3M",63)]
out=[]; L=lambda s:out.append(str(s))

# crypto
mk,dts,fa,port=engine("data_crypto") if os.path.isdir("data_crypto") else (None,)*4
if mk:
    L(f"CRYPTO ({dts[fa]}..{dts[-1]})")
    for tag,sub in [("BTC+ETH",[m for m in mk if m in ("BTC","ETH")]),("BTC",["BTC"]),("ETH",["ETH"])]:
        if all(x in mk for x in sub):
            n=port(sub); L(f"  {tag:10} "+" | ".join(f"{w}: {wstats(n,dts,fa,d)}" for w,d in WINS))

# multi-asset classes
L("")
mk2,dts2,fa2,port2=engine("data_daily")
by={}
for m in mk2: by.setdefault(klass(m),[]).append(m)
L(f"MULTI-ASSET ({dts2[fa2]}..{dts2[-1]})")
for tag,sub in [("ALL",mk2),("ex-FX",[m for m in mk2 if klass(m)!="fx"])]+[(c,by[c]) for c in sorted(by)]:
    n=port2(sub); L(f"  {tag:8} "+" | ".join(f"{w}: {wstats(n,dts2,fa2,d)}" for w,d in WINS))

open("tools/tsmom_recent_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-RECENT\n")
print("\n".join(out)); print("DONE-RECENT")

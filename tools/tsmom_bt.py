#!/usr/bin/env python3
"""Diversified time-series-momentum (TSMOM) PORTFOLIO backtest on daily bars.
Broad multi-asset universe (equity indices, bonds, commodities, crypto, FX).
NON-fitted design (standard lookbacks, no optimization). Handles markets with
different history lengths via a union date grid + per-market activation.
Strictly no look-ahead: position from info through day t applied to t->t+1 return.
"""
import os, csv, math, sys
import numpy as np

DATA = sys.argv[1] if len(sys.argv) > 1 else "data_daily"
LOOKBACKS = [20, 60, 120, 250]   # ~1m,3m,6m,12m  (standard multi-horizon, not optimized)
VOL_WIN   = 60
TARGET_ANN_VOL = 0.10
COST_PER_TURN = 0.0002           # 2 bps per unit weight traded
ANN = 252

# optional asset-class tags for reporting (prefix match)
CLASS = {
    "ES":"equity","NQ":"equity","YM":"equity","RTY":"equity","DAX":"equity","NIKKEI":"equity","FTSE":"equity","STOXX":"equity","HSI":"equity",
    "ZN":"bond","ZB":"bond","ZF":"bond","ZT":"bond","BUND":"bond",
    "CL":"commod","BZ":"commod","NG":"commod","GC":"commod","XAU":"commod","SI":"commod","XAG":"commod","HG":"commod","PL":"commod","PA":"commod","ZC":"commod","ZW":"commod","ZS":"commod","KC":"commod","SB":"commod","CT":"commod","CC":"commod","LE":"commod","HE":"commod",
    "BTC":"crypto","ETH":"crypto",
    "EUR":"fx","GBP":"fx","AUD":"fx","NZD":"fx","USDCAD":"fx","USDCHF":"fx","USDJPY":"fx","EURJPY":"fx",
}
def klass(m):
    for k,v in CLASS.items():
        if m.startswith(k): return v
    return "other"

def load():
    markets = sorted(f[:-4] for f in os.listdir(DATA) if f.endswith(".csv"))
    series = {}
    for m in markets:
        d = {}
        with open(os.path.join(DATA, m + ".csv"), encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                try: d[row["date"]] = float(row["close"])
                except (ValueError, KeyError): pass
        if len(d) > max(LOOKBACKS) + VOL_WIN + 30:
            series[m] = d
    return sorted(series), series

def main():
    markets, series = load()
    if not markets:
        print("NO DATA"); return
    all_dates = sorted(set().union(*[set(series[m]) for m in markets]))
    T = len(all_dates)
    idx = {d:i for i,d in enumerate(all_dates)}
    out=[]; L=lambda s: out.append(str(s))
    L(f"universe ({len(markets)}) over {T} union days {all_dates[0]}..{all_dates[-1]}")
    by_class={}
    for m in markets: by_class.setdefault(klass(m),[]).append(m)
    for c in sorted(by_class): L(f"  {c:7}: {', '.join(by_class[c])}")

    # forward-filled price grid + validity
    px={}; valid_from={}
    for m in markets:
        arr=np.full(T,np.nan); 
        for d,v in series[m].items(): arr[idx[d]]=v
        first=np.argmax(~np.isnan(arr)); valid_from[m]=first
        last=arr[first]
        for t in range(first,T):
            if np.isnan(arr[t]): arr[t]=last
            else: last=arr[t]
        px[m]=arr
    ret={m:np.zeros(T) for m in markets}
    for m in markets:
        f=valid_from[m]
        ret[m][f+1:]=px[m][f+1:]/px[m][f:-1]-1.0

    # weights from info through t
    W={m:np.zeros(T) for m in markets}
    for m in markets:
        s=valid_from[m]+max(LOOKBACKS)+1
        for t in range(s,T):
            sig=np.mean([np.sign(px[m][t]/px[m][t-Lk]-1.0) for Lk in LOOKBACKS])
            vol=np.std(ret[m][t-VOL_WIN+1:t+1])
            W[m][t]=0.0 if vol<=0 else sig/vol

    first_active=min(valid_from[m]+max(LOOKBACKS)+2 for m in markets)
    # OOS split index (IS < 2023, OOS >= 2023) — TSMOM has NO fitted params, so this is a fair durability check
    split=next((i for i,d in enumerate(all_dates) if d>="2023-01-01"), T)

    def port_net(subset):
        """net daily-return array (vol-targeted to 10% using full-sample vol; Sharpe is scale-invariant)"""
        sret=np.zeros(T); turn=np.zeros(T)
        for t in range(first_active,T):
            pnl=0.0; tv=0.0
            for m in subset:
                pnl+=W[m][t-1]*ret[m][t]; tv+=abs(W[m][t-1]-W[m][t-2])
            sret[t]=pnl; turn[t]=tv
        rv=np.std(sret[first_active:]); sc=(TARGET_ANN_VOL/(rv*math.sqrt(ANN))) if rv>0 else 0.0
        return sret*sc - turn*COST_PER_TURN*sc

    def stats(r,i0,i1):
        r=r[i0:i1]
        if len(r)==0 or np.std(r)==0: return dict(sharpe=0,cagr=0,mdd=0,hit=0,n=len(r))
        eq=np.cumprod(1+r); yrs=len(r)/ANN
        cagr=eq[-1]**(1/yrs)-1 if eq[-1]>0 else -1
        vol=np.std(r)*math.sqrt(ANN); sh=(np.mean(r)*ANN)/vol if vol>0 else 0
        peak=np.maximum.accumulate(eq); mdd=np.max((peak-eq)/peak)
        return dict(sharpe=sh,cagr=cagr,mdd=mdd,hit=np.mean(r>0),n=len(r))

    def report(name, subset):
        r=port_net(subset)
        full=stats(r,first_active,T); isw=stats(r,first_active,split); oos=stats(r,split,T)
        L(f"  {name:16} ({len(subset):2}m)  FULL Sh {full['sharpe']:5.2f} CAGR {full['cagr']*100:5.1f}% DD {full['mdd']*100:4.1f}% | "
          f"IS Sh {isw['sharpe']:5.2f} | OOS Sh {oos['sharpe']:5.2f}")
        return r

    exfx=[m for m in markets if klass(m)!="fx"]
    strong=[m for m in markets if klass(m) in ("crypto","bond")]
    bc=[m for m in markets if klass(m) in ("crypto","bond","commod","equity")]  # ex-FX = trend-friendly classes

    L(""); L(f"days traded: {T-first_active}  ({all_dates[first_active]}..{all_dates[-1]})  IS<2023 / OOS>=2023")
    L("=== PORTFOLIO variants (vol-target 10%, 2bps cost) ===")
    report("ALL", markets)
    report("ex-FX", exfx)
    report("crypto+bond", strong)
    L(""); L("  each class (FULL / IS / OOS Sharpe):")
    for c in sorted(by_class):
        report(c, by_class[c])

    open("tools/tsmom_result.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-TSMOM\n")
    print("\n".join(out)); print("DONE-TSMOM")

if __name__=="__main__":
    main()

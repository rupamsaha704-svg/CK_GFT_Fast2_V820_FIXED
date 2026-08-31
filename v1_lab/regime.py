#!/usr/bin/env python3
"""
Regime classifier v1 — CAUSAL implementation of SPEC/regime_classifier_v1.md (frozen: K=0.5, N=20, H1).
TREND iff |EMA200_slope over N H1 bars| >= K * ATR14(H1); else RANGE. Uses only completed bars (index t-1
and earlier) => leakage-free. Does NOT touch FIX09.

Input: M15 price CSV (datetime,open,high,low,close,volume). Resampled to H1 internally.
Usage: python3 regime.py XAUUSD_M15_clean.csv            # prints TREND/RANGE split
       import regime; regime.label_h1(px_h1)             # for joining to trades
"""
import sys, datetime

K=0.5; N=20; EMA_P=200; ATR_P=14

def load_m15(path):
    rows=[]
    with open(path) as fh:               # explicit context manager: no unclosed-file ResourceWarning
        for l in fh:
            l=l.strip()
            if not l or l.lower().startswith(('datetime,','time,')): continue
            p=l.split(',')
            try: dt=datetime.datetime.strptime(p[0],"%Y-%m-%d %H:%M:%S")
            except Exception:
                try: dt=datetime.datetime.strptime(p[0],"%Y.%m.%d %H:%M")
                except Exception: continue
            rows.append((dt,float(p[1]),float(p[2]),float(p[3]),float(p[4])))
    return rows

def resample_h1(m15):
    """group into H1 bars (server time). o=first, h=max, l=min, c=last."""
    buckets={}
    for dt,o,h,l,c in m15:
        key=dt.replace(minute=0,second=0,microsecond=0)
        b=buckets.get(key)
        if b is None: buckets[key]=[o,h,l,c]
        else:
            b[1]=max(b[1],h); b[2]=min(b[2],l); b[3]=c
    return [(k,)+tuple(buckets[k]) for k in sorted(buckets)]

def ema(vals,p):
    k=2.0/(p+1); e=None; out=[]
    for v in vals:
        e=v if e is None else v*k+e*(1-k); out.append(e)
    return out

def atr(h1,p):
    trs=[]; prev_c=None
    for _,o,h,l,c in h1:
        tr=(h-l) if prev_c is None else max(h-l, abs(h-prev_c), abs(l-prev_c)); trs.append(tr); prev_c=c
    # Wilder-ish simple EMA of TR
    return ema(trs,p)

def label_h1(h1):
    """returns list of (datetime, regime, direction) per H1 bar, causal (uses t-1 and earlier)."""
    closes=[c for _,_,_,_,c in h1]; e=ema(closes,EMA_P); a=atr(h1,ATR_P)
    out=[]
    for t in range(len(h1)):
        if t < 1+N:
            out.append((h1[t][0],"NA",0)); continue
        slope=e[t-1]-e[t-1-N]; atrv=a[t-1]
        if atrv and abs(slope) >= K*atrv:
            out.append((h1[t][0],"TREND", 1 if slope>0 else -1))
        else:
            out.append((h1[t][0],"RANGE",0))
    return out

def main():
    m15=load_m15(sys.argv[1]); h1=resample_h1(m15); lab=label_h1(h1)
    counts={}
    for _,r,_ in lab: counts[r]=counts.get(r,0)+1
    tot=sum(v for k,v in counts.items() if k!="NA")
    print("="*50); print(f"REGIME v1 (K={K}, N={N}, EMA{EMA_P}/ATR{ATR_P}, H1)  causal"); print("="*50)
    print(f"  H1 bars: {len(h1)}   (first {h1[0][0].date()} .. last {h1[-1][0].date()})")
    for r in ("TREND","RANGE","NA"):
        c=counts.get(r,0); print(f"  {r:<6} {c:>6}  {100*c/tot:>5.1f}%" if r!="NA" and tot else f"  {r:<6} {c:>6}")

if __name__=='__main__': main()

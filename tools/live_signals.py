#!/usr/bin/env python3
"""LIVE signal monitor: what CK_CRYPTO_TSMOM_v2 says to hold RIGHT NOW.
Uses latest daily closes (data_crypto/, data_daily/). No new params, no fitting -
just the validated rule applied to today. Bridges research -> paper/live trading."""
import os, csv, math
import numpy as np
LB=[20,60,120,250]; VW=60; ANN=252
def series(path):
    d=[]
    for r in csv.DictReader(open(path,encoding="utf-8")):
        try: d.append((r["date"],float(r["close"])))
        except: pass
    return d
def signal_pos(closes, target_vol, use_filter):
    px=np.array([c for _,c in closes]); n=len(px)
    rets=px[1:]/px[:-1]-1
    sig=np.mean([np.sign(px[-1]/px[-1-L]-1) for L in LB])
    vol=np.std(rets[-VW:])
    if vol<=0: return None
    w=sig*(target_vol/math.sqrt(ANN)/vol)
    mult=1.0
    if use_filter:
        refv=np.std(rets[-252:]) if len(rets)>=252 else vol
        mult=max(0.5, min(1.0, refv/vol)) if vol>0 else 1.0
        w*=mult
    w=max(-3.0,min(3.0,w))   # leverage cap
    return dict(date=closes[-1][0], sig=sig, vol_ann=vol*math.sqrt(ANN), mult=mult, w=w,
                dirn=("LONG" if w>0 else ("SHORT" if w<0 else "FLAT")))

books=[("BTC","data_crypto/BTC.csv",0.05,True),
       ("ETH","data_crypto/ETH.csv",0.04,True),
       ("NQ", "data_daily/NQ.csv",  0.05,False)]
out=[]; L=lambda s: out.append(str(s))
L("=== TODAY'S BOOK — CK_CRYPTO_TSMOM_v2 (what to hold now) ===")
L(f"{'instr':5} {'date':11} {'dir':5} {'signal':>7} {'annVol':>7} {'volFilt':>7} {'target_%equity':>15}")
for name,path,tv,uf in books:
    if not os.path.exists(path): L(f"{name}: no data"); continue
    s=signal_pos(series(path),tv,uf)
    if not s: L(f"{name}: insufficient data"); continue
    L(f"{name:5} {s['date']:11} {s['dirn']:5} {s['sig']:+7.2f} {s['vol_ann']*100:6.0f}% {s['mult']:7.2f} {s['w']*100:+14.1f}%")
L("")
L("Notes:")
L(" - target_%equity = position notional as % of account equity (sign = long/short).")
L(" - crypto sleeve ~70% risk, NQ ~30% (per .set vol targets). Rebalance on daily close.")
L(" - volFilt<1 => high-vol regime, crypto exposure trimmed.")
L(" - GEX context (free, live): run tools/gex_calc.py _NDX  (POSITIVE=dampen/range, NEGATIVE=amplify/trend).")
open("tools/live_signals_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-LIVE\n")
print("\n".join(out)); print("DONE-LIVE")

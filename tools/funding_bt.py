#!/usr/bin/env python3
"""Funding-carry sleeve backtest + is it uncorrelated to our trend book?
Carry = long spot + short perp (delta-neutral): per 8h you receive fundingRate (pay if neg).
Daily carry return = sum of that day's funding. Compare to crypto TREND; test combining.
Honest: modest cost haircut applied; real tail risks (venue/liquidation/de-peg) NOT in a
funding-only backtest. IS<2023 / OOS>=2023."""
import os, csv, math, datetime as dt
import numpy as np
ANN=365; LB=[20,60,120,250]; VW=60
def load_fund(sym):
    d={}
    for r in csv.DictReader(open(f"data_funding/{sym}.csv",encoding="utf-8")):
        try:
            day=dt.datetime.utcfromtimestamp(int(r["time_ms"])/1000).strftime("%Y-%m-%d")
            d[day]=d.get(day,0.0)+float(r["rate"])
        except: pass
    return d   # date -> daily carry (sum funding)
def load_px(sym):
    d={}
    for r in csv.DictReader(open(f"data_crypto/{sym}.csv",encoding="utf-8")):
        try: d[r["date"]]=float(r["close"])
        except: pass
    return d
fb=load_fund("BTCUSDT"); fe=load_fund("ETHUSDT")
pb=load_px("BTC"); pe=load_px("ETH")
# common dates
dates=sorted(set(fb)&set(fe)&set(pb)&set(pe))
carry=np.array([(fb[d]+fe[d])/2 for d in dates])           # daily carry (avg BTC,ETH)
# crypto trend daily net (BTC+ETH TSMOM, vol-target) aligned to same dates
def trend_ret(pdict):
    px=np.array([pdict[d] for d in dates]); T=len(px); ret=np.zeros(T); ret[1:]=px[1:]/px[:-1]-1
    W=np.zeros(T)
    for t in range(max(LB)+1,T):
        sg=np.mean([np.sign(px[t]/px[t-L]-1) for L in LB]); v=np.std(ret[t-VW+1:t+1]); W[t]=0 if v<=0 else sg/v
    nr=np.zeros(T)
    for t in range(max(LB)+2,T): nr[t]=W[t-1]*ret[t]
    return nr
tr=(trend_ret(pb)+trend_ret(pe))/2
T=len(dates); split=next((i for i,d in enumerate(dates) if d>="2023-01-01"),T)
fa=max(LB)+2
COST_YR=0.05   # conservative 5%/yr haircut for fees/slippage/hedge-error on carry
carry_net=carry-COST_YR/ANN
def stats(r,i0,i1,ann=ANN):
    r=r[i0:i1]
    if len(r)<10 or np.std(r)==0: return (0,0,0,0)
    eq=np.cumprod(1+r); sh=(np.mean(r)*ann)/(np.std(r)*math.sqrt(ann))
    pk=np.maximum.accumulate(eq); dd=np.max((pk-eq)/pk); cg=eq[-1]**(ann/len(r))-1 if eq[-1]>0 else -1
    return (sh,cg,dd,np.mean(r>0)*100)
out=[];L=lambda s:out.append(str(s))
L(f"FUNDING-CARRY sleeve  ({dates[fa]}..{dates[-1]}, {T} days)  IS<2023/OOS>=2023  (cost {COST_YR*100:.0f}%/yr)")
for name,r in [("carry GROSS",carry),("carry NET",carry_net)]:
    s=stats(r,fa,T); i=stats(r,fa,split); o=stats(r,split,T)
    L(f"  {name:12} FULL Sh {s[0]:5.2f} ret {s[1]*100:5.1f}% DD {s[2]*100:4.1f}% | IS Sh {i[0]:5.2f} | OOS Sh {o[0]:5.2f}")
# correlation carry vs trend
c=np.corrcoef(carry_net[fa:],tr[fa:])[0,1]; co=np.corrcoef(carry_net[split:],tr[split:])[0,1]
L(f"  corr(carry, crypto-trend): FULL {c:+.2f}  OOS {co:+.2f}   (near 0 = great diversifier)")
# vol-scale each to 10% then combine 50/50
def vscale(r,i0):
    v=np.std(r[i0:])*math.sqrt(ANN); return r*(0.10/v) if v>0 else r*0
trs=vscale(tr,fa); cns=vscale(carry_net,fa)
for name,r in [("TREND only",trs),("CARRY only",cns),("COMBO 50/50",0.5*trs+0.5*cns),("COMBO 60/40 tr/ca",0.6*trs+0.4*cns)]:
    s=stats(r,fa,T); o=stats(r,split,T)
    L(f"  {name:16} FULL Sh {s[0]:5.2f} DD {s[2]*100:4.1f}% | OOS Sh {o[0]:5.2f} OOS DD {o[2]*100:4.1f}%")
# per-year carry net
ym={}
for t in range(fa,T): ym.setdefault(dates[t][:4],[]).append(carry_net[t])
L("  carry NET per-year: "+"  ".join(f"{y}:{(np.prod(1+np.array(v))-1)*100:+.0f}%" for y,v in sorted(ym.items())))
open("tools/funding_bt_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-FUNDBT\n")
print("\n".join(out)); print("DONE-FUNDBT")

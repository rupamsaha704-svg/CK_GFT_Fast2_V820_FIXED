"""
STEP 2 - How OTHERS sustain in chop, TESTED on gold daily (honest, causal).
Established chop-survival methods:
  - KAMA (Kaufman Adaptive MA): slows in chop (anti-whipsaw), fast in trend.
  - Trend-aligned DIP-BUY: buy pullbacks ONLY when higher trend is up (no falling knife).
  - TF + dip-buy combined (ride trend + harvest uptrend-chop dips).
  - Clean-range FADE: only fade a range when ADX<20 (a real range), buy low/exit high.
Compare CHOP-day performance vs baseline TF long-only (step1: chop Sharpe 10yr+0.80/3y+2.51/1y+0.18).
Data: data_daily/GC.csv  causal, cost, vol-target 10%.
"""
import os, math
import numpy as np, pandas as pd

CSV=os.path.join("data_daily","GC.csv")
OUT=os.path.join("experiments","gold_chop","step2.txt")
os.makedirs(os.path.dirname(OUT),exist_ok=True)
TARGET_VOL=0.10; LEV_CAP=4.0; COST=0.0002; ANN=252.0
lines=[]
def P(s=""):
    lines.append(str(s)); print(s)

df=pd.read_csv(CSV,parse_dates=["date"]).sort_values("date").reset_index(drop=True)
o,h,l,c=(df[k].values for k in("open","high","low","close"))
n=len(df); ret=np.zeros(n); ret[1:]=c[1:]/c[:-1]-1.0

def wilder(x,p):
    y=np.full(len(x),np.nan)
    if len(x)<p+1: return y
    y[p]=np.nansum(x[1:p+1])
    for i in range(p+1,len(x)): y[i]=y[i-1]-y[i-1]/p+x[i]
    return y
def adx(h,l,c,p=14):
    N=len(c); tr=np.zeros(N);pdm=np.zeros(N);ndm=np.zeros(N)
    for i in range(1,N):
        up=h[i]-h[i-1]; dn=l[i-1]-l[i]
        pdm[i]=up if(up>dn and up>0)else 0.0
        ndm[i]=dn if(dn>up and dn>0)else 0.0
        tr[i]=max(h[i]-l[i],abs(h[i]-c[i-1]),abs(l[i]-c[i-1]))
    atr=wilder(tr,p);sp=wilder(pdm,p);sn=wilder(ndm,p)
    with np.errstate(divide='ignore',invalid='ignore'):
        pdi=100*sp/atr; ndi=100*sn/atr; dx=100*np.abs(pdi-ndi)/(pdi+ndi)
    dx=np.nan_to_num(dx); adxv=np.full(N,np.nan); st=2*p
    if N>st:
        adxv[st]=np.nanmean(dx[p:st])
        for i in range(st+1,N): adxv[i]=(adxv[i-1]*(p-1)+dx[i])/p
    return adxv
def er(c,N):
    e=np.full(len(c),np.nan); ad=np.abs(np.diff(c,prepend=c[0]))
    for i in range(N,len(c)):
        v=np.sum(ad[i-N+1:i+1]); e[i]=abs(c[i]-c[i-N])/v if v>0 else 0.0
    return e
def ema(x,s):
    a=2/(s+1);y=np.full(len(x),np.nan);y[0]=x[0]
    for i in range(1,len(x)):y[i]=a*x[i]+(1-a)*y[i-1]
    return y

ADXv=adx(h,l,c,14)
ema20,ema100=ema(c,20),ema(c,100)
sma20=pd.Series(c).rolling(20).mean().values
std20=pd.Series(c).rolling(20).std(ddof=0).values
boll_low=sma20-2*std20
low20=pd.Series(l).rolling(20).min().values
high20=pd.Series(h).rolling(20).max().values

# KAMA(er10, fast2, slow30)
e10=er(c,10); fast=2/3; slow=2/31
sc=(e10*(fast-slow)+slow)**2
kama=np.full(n,np.nan); 
seed=next((i for i in range(n) if not np.isnan(sc[i])),10); kama[seed]=c[seed]
for i in range(seed+1,n):
    kama[i]=kama[i-1]+sc[i]*(c[i]-kama[i-1])

adx_prev=np.roll(ADXv,1);adx_prev[0]=np.nan
trend_adx=adx_prev>=25.0; chop_adx=adx_prev<25.0

# ---- raw signals (decide with info at i, then lag 1 day) ----
tf_lo=np.where(ema20>ema100,1.0,0.0)
kama_lo=np.where(np.append(np.nan,np.diff(kama))>0,1.0,0.0)  # KAMA rising

def statemachine(entry,exit_,extra_ok=None):
    pos=np.zeros(n); inp=False
    for i in range(n):
        ok=True if extra_ok is None else bool(extra_ok[i])
        if not inp:
            if ok and entry[i]: inp=True; pos[i]=1.0
        else:
            if exit_[i] or not ok: inp=False; pos[i]=0.0
            else: pos[i]=1.0
    return pos

up_ctx = c>ema100
dip    = c<boll_low
exitmid= c>sma20
dipbuy = statemachine(dip,exitmid,extra_ok=up_ctx)   # buy dips only in uptrend
combo  = np.maximum(tf_lo,dipbuy)                    # trend core + uptrend dips

rng=high20-low20
nearlow = c<=low20+0.20*rng
nearhigh= c>=high20-0.20*rng
ranging = adx_prev<20.0
rangefade= statemachine(nearlow,nearhigh,extra_ok=ranging)  # fade only real ranges

def lag(x):
    y=np.roll(x,1);y[0]=0.0;return np.nan_to_num(y)
sigs={"TF-LO(base)":lag(tf_lo),"KAMA-LO":lag(kama_lo),
      "DIPBUY(uptr)":lag(dipbuy),"TF+DIP combo":lag(combo),
      "RANGEFADE":lag(rangefade)}

rv=pd.Series(ret).rolling(20).std(ddof=0).values*math.sqrt(ANN)
rvp=np.roll(rv,1);rvp[0]=np.nan
lev=np.nan_to_num(np.clip(TARGET_VOL/np.where(rvp>0,rvp,np.nan),0,LEV_CAP))
def pnl(sig):
    pos=sig*lev; turn=np.abs(np.diff(pos,prepend=0.0)); return pos*ret-COST*turn
def stats(p,m):
    x=p[m]; x=x[~np.isnan(x)]
    if len(x)<5 or np.std(x)==0: return dict(sh=0,ann=0,tot=0)
    return dict(sh=np.mean(x)/np.std(x)*math.sqrt(ANN),ann=np.mean(x)*ANN,tot=np.sum(x))
def mdd(p,m):
    x=np.where(m,np.nan_to_num(p),0.0); eq=np.cumsum(x); pk=np.maximum.accumulate(eq)
    return float(np.min(eq-pk)) if len(eq) else 0.0

valid=~np.isnan(ema100)&~np.isnan(adx_prev)&~np.isnan(kama)
idx=np.arange(n)
def block(name,m):
    P("\n================= %s ================="%name)
    td=int(np.sum(m)); nc=int(np.sum(m&chop_adx)); nt=int(np.sum(m&trend_adx))
    P("days=%d  CHOP=%d(%.0f%%)  TREND=%d(%.0f%%)"%(td,nc,100*nc/max(td,1),nt,100*nt/max(td,1)))
    P("%-14s %7s %7s %7s | %8s %8s | %8s"%("strategy","ALLsh","ann%","maxDD","CHOPsh","CHOPann%","TRNDsh"))
    for nm,s in sigs.items():
        p=pnl(s); a=stats(p,m); cc=stats(p,m&chop_adx); tt=stats(p,m&trend_adx)
        P("%-14s %7.2f %7.1f %7.3f | %8.2f %8.1f | %8.2f"
          %(nm,a['sh'],100*a['ann'],mdd(p,m),cc['sh'],100*cc['ann'],tt['sh']))
block("FULL 10yr",valid)
block("LAST 3Y",valid&(idx>=n-756))
block("LAST 1Y",valid&(idx>=n-252))
P("\nGoal: beat TF-LO baseline CHOPsh (10yr+0.80/3y+2.51/1y+0.18) WITHOUT hurting ALLsh or maxDD.")
open(OUT,"w").write("\n".join(lines)); print("\n[written]",OUT)

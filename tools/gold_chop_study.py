"""
STEP 1 - Understand the CHOPPY gold market (honest regime decomposition).

Question from user: the trend strategy only made money because a big trend came.
If it were chop, it would bleed. So:
  1) How much of gold's time is CHOP vs TREND? (ADX + Efficiency Ratio)
  2) The validated TF strategy (MAcross 20/100 long-only): how much of its profit
     comes from TREND days vs CHOP days? Does it bleed in chop?
  3) Is gold CHOP tradeable at all? Test mean-reversion measured ON CHOP DAYS ONLY.
  4) Naive regime SWITCH (TF in trend, MR in chop) - quick preview.

All causal (trade day t using info up to t-1), cost-included, vol-targeted to 10%.
Data: data_daily/GC.csv  (10yr gold daily)  columns: date,open,high,low,close
"""
import os, sys, math
import numpy as np
import pandas as pd

CSV   = os.path.join("data_daily", "GC.csv")
OUT   = os.path.join("experiments", "gold_chop", "step1.txt")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

TARGET_VOL = 0.10       # annual
LEV_CAP    = 4.0
COST       = 0.0002     # per unit turnover (notional)
ANN        = 252.0

lines = []
def P(s=""):
    lines.append(str(s))
    print(s)

# ---------- load ----------
df = pd.read_csv(CSV, parse_dates=["date"]).sort_values("date").reset_index(drop=True)
o,h,l,c = df["open"].values, df["high"].values, df["low"].values, df["close"].values
n = len(df)
ret = np.zeros(n)
ret[1:] = c[1:]/c[:-1] - 1.0

# ---------- indicators (Wilder ADX, Efficiency Ratio) ----------
def wilder(x, p):
    y = np.full(len(x), np.nan)
    # seed with simple average of first p
    if len(x) < p: return y
    s = np.nansum(x[1:p+1])   # x[0] often 0/undefined
    y[p] = s
    for i in range(p+1, len(x)):
        y[i] = y[i-1] - y[i-1]/p + x[i]
    return y

def adx(h,l,c,p=14):
    N=len(c)
    tr=np.zeros(N); pdm=np.zeros(N); ndm=np.zeros(N)
    for i in range(1,N):
        up = h[i]-h[i-1]
        dn = l[i-1]-l[i]
        pdm[i] = up if (up>dn and up>0) else 0.0
        ndm[i] = dn if (dn>up and dn>0) else 0.0
        tr[i]  = max(h[i]-l[i], abs(h[i]-c[i-1]), abs(l[i]-c[i-1]))
    atr = wilder(tr,p); spdm=wilder(pdm,p); sndm=wilder(ndm,p)
    with np.errstate(divide='ignore',invalid='ignore'):
        pdi = 100.0*spdm/atr
        ndi = 100.0*sndm/atr
        dx  = 100.0*np.abs(pdi-ndi)/(pdi+ndi)
    dx = np.nan_to_num(dx, nan=0.0, posinf=0.0, neginf=0.0)
    adxv = np.full(N, np.nan)
    # Wilder-smooth DX starting after first valid window
    start = 2*p
    if N>start:
        adxv[start] = np.nanmean(dx[p:start])
        for i in range(start+1,N):
            adxv[i] = (adxv[i-1]*(p-1)+dx[i])/p
    return adxv

def eff_ratio(c, N=20):
    er=np.full(len(c),np.nan)
    absd=np.abs(np.diff(c, prepend=c[0]))
    for i in range(N,len(c)):
        change=abs(c[i]-c[i-N])
        vol=np.sum(absd[i-N+1:i+1])
        er[i]= change/vol if vol>0 else 0.0
    return er

def ema(x,span):
    a=2.0/(span+1.0); y=np.full(len(x),np.nan); y[0]=x[0]
    for i in range(1,len(x)): y[i]=a*x[i]+(1-a)*y[i-1]
    return y
def sma(x,w):
    return pd.Series(x).rolling(w).mean().values
def rstd(x,w):
    return pd.Series(x).rolling(w).std(ddof=0).values

ADXv = adx(h,l,c,14)
ERv  = eff_ratio(c,20)
ema20, ema100 = ema(c,20), ema(c,100)
sma20 = sma(c,20); std20 = rstd(c,20)

# ---------- regime labels (use PREVIOUS day's value -> causal) ----------
adx_prev = np.roll(ADXv,1); adx_prev[0]=np.nan
er_prev  = np.roll(ERv,1);  er_prev[0]=np.nan
# primary: ADX
trend_adx = adx_prev >= 25.0
chop_adx  = adx_prev <  25.0
# secondary: ER
trend_er  = er_prev >= 0.30
chop_er   = er_prev <  0.30

# ---------- signals (positions for day t, using info up to t-1) ----------
tf_ls  = np.where(ema20>ema100, 1.0, -1.0)          # long/short
tf_lo  = np.where(ema20>ema100, 1.0, 0.0)           # long-only
z      = (c - sma20)/std20
mr_ls  = -np.tanh(z/1.5)                             # mean revert both sides
mr_lo  = np.maximum(0.0, -np.tanh(z/1.5))           # buy dips only
# shift signals by 1 (act next day)
def lag(x):
    y=np.roll(x,1); y[0]=0.0; return np.nan_to_num(y,nan=0.0)
tf_ls,tf_lo,mr_ls,mr_lo = map(lag,(tf_ls,tf_lo,mr_ls,mr_lo))

# ---------- vol targeting ----------
rv = pd.Series(ret).rolling(20).std(ddof=0).values*math.sqrt(ANN)
rv_prev = np.roll(rv,1); rv_prev[0]=np.nan
lev = np.clip(TARGET_VOL/np.where(rv_prev>0,rv_prev,np.nan), 0, LEV_CAP)
lev = np.nan_to_num(lev, nan=0.0)

def pnl(signal):
    pos = signal*lev
    turn = np.abs(np.diff(pos, prepend=0.0))
    return pos*ret - COST*turn

pnl_tf_ls=pnl(tf_ls); pnl_tf_lo=pnl(tf_lo)
pnl_mr_ls=pnl(mr_ls); pnl_mr_lo=pnl(mr_lo)
# naive switch: TF-LO on trend days, MR-LO on chop days
sw_sig = np.where(trend_adx, tf_lo, mr_lo)
pnl_sw = pnl(np.nan_to_num(sw_sig))

# ---------- metrics ----------
def stats(p, mask=None):
    x = p if mask is None else p[mask]
    x = x[~np.isnan(x)]
    if len(x)<5 or np.std(x)==0:
        return dict(days=len(x), ann=0.0, sharpe=0.0, tot=0.0)
    return dict(days=len(x),
                ann=np.mean(x)*ANN,
                sharpe=np.mean(x)/np.std(x)*math.sqrt(ANN),
                tot=np.sum(x))
def mdd(p, mask=None):
    x = p.copy()
    if mask is not None: x=np.where(mask,x,0.0)
    eq=np.cumsum(np.nan_to_num(x)); peak=np.maximum.accumulate(eq)
    return float(np.min(eq-peak)) if len(eq) else 0.0

# valid range: where we have ema100 & adx
valid = ~np.isnan(ema100) & ~np.isnan(adx_prev)
def win(name, m):
    P("\n===================== %s ====================="%name)
    tot_days=int(np.sum(m))
    nch=int(np.sum(m & chop_adx)); ntr=int(np.sum(m & trend_adx))
    P("days=%d   CHOP(ADX<25)=%d (%.0f%%)   TREND(ADX>=25)=%d (%.0f%%)"
      %(tot_days,nch,100*nch/max(tot_days,1),ntr,100*ntr/max(tot_days,1)))
    nch2=int(np.sum(m & chop_er))
    P("           CHOP(ER<0.30)=%d (%.0f%%)   [secondary detector]"%(nch2,100*nch2/max(tot_days,1)))
    P("")
    P("%-16s %8s %8s | %8s %8s %8s | %8s %8s %8s"
      %("strategy","ALLshrp","ALLann%","CHOPshrp","CHOPann%","CHOP$","TRNDshrp","TRNDann%","TRND$"))
    def row(nm,p):
        a=stats(p,m); cc=stats(p,m&chop_adx); tt=stats(p,m&trend_adx)
        P("%-16s %8.2f %8.1f | %8.2f %8.1f %8.3f | %8.2f %8.1f %8.3f"
          %(nm,a['sharpe'],100*a['ann'],cc['sharpe'],100*cc['ann'],cc['tot'],
            tt['sharpe'],100*tt['ann'],tt['tot']))
    row("TF long-only",pnl_tf_lo)
    row("TF long/short",pnl_tf_ls)
    row("MR long-only",pnl_mr_lo)
    row("MR long/short",pnl_mr_ls)
    row("SWITCH(tf/mr)",pnl_sw)
    # profit attribution for TF-LO
    a=stats(pnl_tf_lo,m); cc=stats(pnl_tf_lo,m&chop_adx); tt=stats(pnl_tf_lo,m&trend_adx)
    if abs(a['tot'])>1e-9:
        P("")
        P(">> TF long-only profit split:  TREND days = %.1f%% of total,  CHOP days = %.1f%% of total"
          %(100*tt['tot']/a['tot'],100*cc['tot']/a['tot']))
        P(">> TF long-only maxDD(equity units): ALL=%.3f  (chop-only stream=%.3f)"%(mdd(pnl_tf_lo,m),mdd(pnl_tf_lo,m&chop_adx)))

idx=np.arange(n)
win("FULL (10yr)", valid)
win("LAST ~3Y", valid & (idx>=n-756))
win("LAST ~1Y", valid & (idx>=n-252))

# recent chop stretch: longest run of chop days in last 3y
P("\n----- note -----")
P("Positive CHOPshrp/CHOP$ for a strategy = that strategy MAKES money in chop.")
P("TF is expected >0 in TREND, <=0 in CHOP. MR is the chop candidate.")
P("SWITCH uses TF in trend + MR in chop; compare its ALLshrp to TF-only ALLshrp.")

with open(OUT,"w") as f: f.write("\n".join(lines))
print("\n[written]", OUT)

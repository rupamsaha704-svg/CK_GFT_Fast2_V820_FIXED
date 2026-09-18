"""
CLEAR multi-timeframe diagnostic of the fade strategy in the Apr20-Sep2 chop.
- resamples M1 -> 15m / 1H / 1D
- overlays BUY (blue ^) and SELL (magenta v) entries, LOSS (red x) / win (green *)
- shades BIAS backdrop (green where close>EMA50, red where below) so bias is CLEAR
- draws RED BOXES on price zones where entries repeat (same-spot re-entry problem)
- prints a quantified repeat-entry table
Every chart title states the TIMEFRAME explicitly.
"""
import os, re
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.patches import Rectangle

M1  = os.path.join("experiments","dump_m1","xau_m1.csv")
HTM = os.path.join("experiments","mr_aprsep","windows","aprsep","report.htm")
OUT = "charts"; os.makedirs(OUT, exist_ok=True)
T0,T1 = "2026-04-20","2026-09-02"

# ---- price ----
m1 = pd.read_csv(M1); m1["time"]=pd.to_datetime(m1["time"],format="%Y.%m.%d %H:%M")
m1 = m1.set_index("time").sort_index()
def rs(tf):
    o=m1["open"].resample(tf).first(); h=m1["high"].resample(tf).max()
    l=m1["low"].resample(tf).min(); c=m1["close"].resample(tf).last()
    df=pd.DataFrame(dict(open=o,high=h,low=l,close=c)).dropna()
    return df[(df.index>=T0)&(df.index<=T1)]
TF={"15-MIN":rs("15min"),"1-HOUR":rs("60min"),"1-DAY":rs("1D")}

# ---- trades ----
def num(s):
    s=s.replace(" ","")
    try:return float(s)
    except:return float("nan")
raw=open(HTM,"rb").read(); html=None
for enc in ("utf-16","utf-8","latin-1"):
    try:
        t=raw.decode(enc)
        if "<tr" in t and "XAUUSD" in t: html=t; break
    except: pass
deals=[]
for r in html.split("<tr"):
    tds=[re.sub("<.*?>","",x).strip() for x in re.findall(r"<td[^>]*>(.*?)</td>",r,re.S)]
    if len(tds)<13 or tds[2]!="XAUUSD" or tds[4] not in ("in","out"): continue
    deals.append(dict(dirn=tds[4],typ=tds[3],time=tds[0],price=num(tds[6]),profit=num(tds[10])))
T=[];cur=None
for d in deals:
    if d["dirn"]=="in":cur=d
    elif d["dirn"]=="out" and cur:
        T.append(dict(side=cur["typ"],e_time=pd.to_datetime(cur["time"],format="%Y.%m.%d %H:%M:%S"),
                      e_price=cur["price"],x_time=pd.to_datetime(d["time"],format="%Y.%m.%d %H:%M:%S"),
                      x_price=d["price"],profit=d["profit"]));cur=None
tr=pd.DataFrame(T).sort_values("e_time").reset_index(drop=True)
tr=tr[(tr.e_time>=T0)&(tr.e_time<=T1)].reset_index(drop=True)

# ---- repeat-entry detection ----
rng15=(TF["15-MIN"]["high"]-TF["15-MIN"]["low"]).median()
band=1.2*rng15; winh=36
tr["repeat"]=False; tr["rep_of"]=-1
for i in range(len(tr)):
    for j in range(i):
        if abs(tr.e_price[i]-tr.e_price[j])<=band and (tr.e_time[i]-tr.e_time[j]).total_seconds()<=winh*3600:
            tr.loc[i,"repeat"]=True; tr.loc[i,"rep_of"]=j; break
rep=tr[tr.repeat]
print("TOTAL trades=%d  net=%.1f  win%%=%.1f"%(len(tr),tr.profit.sum(),100*(tr.profit>0).mean()))
print("REPEAT entries (within %.1f$ & %dh of a prior entry) = %d  their net=%.1f  (loss share)"%(
      band,winh,len(rep),rep.profit.sum()))
print("  of repeats: losses=%d wins=%d"%(int((rep.profit<0).sum()),int((rep.profit>0).sum())))
# buy/sell split
for s in ("buy","sell"):
    d=tr[tr.side==s]; print("  %s: n=%d net=%.1f win%%=%.1f"%(s,len(d),d.profit.sum(),100*(d.profit>0).mean() if len(d) else 0))

def candles(ax,df,w):
    for t,b in df.iterrows():
        c="#2ca02c" if b.close>=b.open else "#d62728"
        ax.plot([t,t],[b.low,b.high],color=c,lw=0.5,zorder=2)
        ax.plot([t,t],[b.open,b.close],color=c,lw=w,zorder=2)

def biasshade(ax,df):
    ema=df["close"].ewm(span=50,adjust=False).mean()
    up=df["close"]>ema
    ax.plot(df.index,ema,color="#888",lw=1.0,ls="-",label="EMA50 (bias)")
    ymin,ymax=df["low"].min(),df["high"].max()
    ax.fill_between(df.index,ymin,ymax,where=up.values,color="green",alpha=0.05,zorder=0)
    ax.fill_between(df.index,ymin,ymax,where=(~up).values,color="red",alpha=0.05,zorder=0)

def plotTF(name,df,fn,cw,boxes=True):
    fig,ax=plt.subplots(figsize=(16,8))
    biasshade(ax,df); candles(ax,df,cw)
    b=tr[tr.side=="buy"]; s=tr[tr.side=="sell"]
    ax.scatter(b.e_time,b.e_price,marker="^",s=60,color="tab:blue",edgecolor="k",lw=.3,zorder=6,label="BUY entry")
    ax.scatter(s.e_time,s.e_price,marker="v",s=60,color="magenta",edgecolor="k",lw=.3,zorder=6,label="SELL entry")
    L=tr[tr.profit<0]; W=tr[tr.profit>0]
    ax.scatter(L.x_time,L.x_price,marker="x",s=45,color="red",zorder=7,label="LOSS exit")
    ax.scatter(W.x_time,W.x_price,marker="*",s=90,color="lime",edgecolor="k",lw=.2,zorder=7,label="win exit")
    if boxes:
        for _,t in rep.iterrows():
            ax.add_patch(Rectangle((mdates.date2num(t.e_time)-0.15,t.e_price-band/2),0.3,band,
                          fill=False,edgecolor="red",lw=1.2,zorder=8))
    ax.set_title("TIMEFRAME = %s   |   XAUUSD  %s to %s   |   red boxes = REPEAT entry at same zone (%d of %d)"%(
        name,T0,T1,len(rep),len(tr)),fontsize=12)
    ax.set_ylabel("price"); ax.legend(loc="upper right",fontsize=8,ncol=2)
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d"))
    plt.tight_layout(); plt.savefig(os.path.join(OUT,fn),dpi=110); plt.close(); print("saved",fn)

plotTF("1-DAY",TF["1-DAY"],"D1_bias.png",6.0,boxes=False)
plotTF("1-HOUR",TF["1-HOUR"],"H1_trades.png",2.2)
plotTF("15-MIN",TF["15-MIN"],"M15_trades.png",1.0)

# ---------- CLEAR 5-min ZOOM on the densest repeat cluster ----------
m5=rs("5min")
tr["day"]=tr.e_time.dt.floor("D")
dc=tr.groupby("day").size().sort_values(ascending=False)
def zoom(center, tag, fn):
    a=center-pd.Timedelta(days=2); b=center+pd.Timedelta(days=3)
    z=m5[(m5.index>=a)&(m5.index<=b)]
    zt=tr[(tr.e_time>=a)&(tr.e_time<=b)]
    if len(z)==0 or len(zt)==0: return
    fig,ax=plt.subplots(figsize=(16,8))
    ema=z["close"].ewm(span=50,adjust=False).mean()
    candles(ax,z,3.0)
    ax.plot(z.index,ema,color="#1f77b4",lw=1.4,label="EMA50 (bias)")
    # highlight zones repeatedly hit: cluster entry prices
    prices=sorted(zt.e_price.tolist()); used=[]
    for p in prices:
        if any(abs(p-u)<=band for u in used): continue
        grp=[q for q in prices if abs(q-p)<=band]
        if len(grp)>=3:
            lo=min(grp)-band/2; hi=max(grp)+band/2
            ax.axhspan(lo,hi,color="orange",alpha=0.18,zorder=1)
            ax.text(z.index[2],(lo+hi)/2,"  ZONE hit %dx"%len(grp),color="darkorange",fontsize=10,va="center")
            used.append(p)
    bb=zt[zt.side=="buy"]; ss=zt[zt.side=="sell"]
    ax.scatter(bb.e_time,bb.e_price,marker="^",s=110,color="tab:blue",edgecolor="k",zorder=6,label="BUY entry")
    ax.scatter(ss.e_time,ss.e_price,marker="v",s=110,color="magenta",edgecolor="k",zorder=6,label="SELL entry")
    Lz=zt[zt.profit<0]; Wz=zt[zt.profit>0]
    ax.scatter(Lz.x_time,Lz.x_price,marker="x",s=80,color="red",zorder=7,label="LOSS exit")
    ax.scatter(Wz.x_time,Wz.x_price,marker="*",s=150,color="lime",edgecolor="k",zorder=7,label="win exit")
    for _,t in zt.iterrows():
        ax.plot([t.e_time,t.x_time],[t.e_price,t.x_price],color=("red" if t.profit<0 else "green"),lw=.8,alpha=.6,zorder=5)
    net=zt.profit.sum()
    ax.set_title("TIMEFRAME = 5-MIN  |  %s  |  same zones hit repeatedly -> net $%.0f (%d trades, %d losses)"%(
        tag,net,len(zt),int((zt.profit<0).sum())),fontsize=12)
    ax.set_ylabel("price"); ax.legend(loc="upper right",fontsize=8,ncol=2)
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d %H:%M"))
    plt.tight_layout(); plt.savefig(os.path.join(OUT,fn),dpi=120); plt.close(); print("saved",fn)

if len(dc)>=1: zoom(dc.index[0],"cluster A ("+str(dc.index[0].date())+")","ZOOM_A_5m.png")
if len(dc)>=2: zoom(dc.index[1],"cluster B ("+str(dc.index[1].date())+")","ZOOM_B_5m.png")
print("DIAG DONE")

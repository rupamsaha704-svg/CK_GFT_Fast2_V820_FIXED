"""
Visualise WHERE/HOW the fade strategy loses in chop, showing BUY *and* SELL
entries separately (uses the long+short ICT run). Also prints the buy-vs-sell
loss split so we can see which side bled more in the choppy/declining market.
Outputs PNGs to charts/.
"""
import os, re
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

OHLC   = os.path.join("experiments","xau_dump","xau_dump.csv")
HTM    = os.path.join("experiments","gold_ict","windows","chop","report.htm")   # long+short
MAY_HTM= os.path.join("experiments","gold_ict","windows","may","report.htm")
OUT="charts"; os.makedirs(OUT, exist_ok=True)

px = pd.read_csv(OHLC); px["time"]=pd.to_datetime(px["time"],format="%Y.%m.%d %H:%M")
px = px.sort_values("time").reset_index(drop=True)

def num(s):
    s=s.replace(" ","")
    try: return float(s)
    except: return float("nan")
def parse_trades(path):
    raw=open(path,"rb").read(); html=None
    for enc in ("utf-16","utf-16-le","utf-8","latin-1"):
        try:
            t=raw.decode(enc)
            if ("<tr" in t) and ("XAUUSD" in t): html=t; break
        except Exception: pass
    if html is None: html=raw.decode("latin-1","ignore")
    deals=[]
    for r in html.split("<tr"):
        tds=re.findall(r"<td[^>]*>(.*?)</td>", r, re.S)
        tds=[re.sub("<.*?>","",x).strip() for x in tds]
        if len(tds)<13: continue
        if tds[2]!="XAUUSD": continue
        if tds[4] not in ("in","out"): continue
        deals.append(dict(dirn=tds[4],typ=tds[3],time=tds[0],price=num(tds[6]),profit=num(tds[10]),comment=tds[12]))
    trades=[]; cur=None
    for d in deals:
        if d["dirn"]=="in": cur=d
        elif d["dirn"]=="out" and cur is not None:
            trades.append(dict(side=cur["typ"],
                e_time=pd.to_datetime(cur["time"],format="%Y.%m.%d %H:%M:%S"), e_price=cur["price"],
                x_time=pd.to_datetime(d["time"],format="%Y.%m.%d %H:%M:%S"), x_price=d["price"],
                profit=d["profit"]))
            cur=None
    return pd.DataFrame(trades)

tr     = parse_trades(HTM)
tr_may = parse_trades(MAY_HTM)
def split(name,df):
    if len(df)==0: print(name,"(no trades)"); return
    b=df[df.side=="buy"]; s=df[df.side=="sell"]
    print("%s: BUY n=%d net=%.1f loss=%d/%d | SELL n=%d net=%.1f loss=%d/%d"%(
        name,len(b),b.profit.sum(),int((b.profit<0).sum()),len(b),
        len(s),s.profit.sum(),int((s.profit<0).sum()),len(s)))
split("CHOP",tr); split("MAY",tr_may)

# previous-day High/Low
d=px.set_index("time"); day=d.resample("1D").agg(dict(high="max",low="min")).dropna()
pdH=day["high"].shift(1).reindex(d.index,method="ffill"); pdL=day["low"].shift(1).reindex(d.index,method="ffill")
def lvl(series, sub): return series.reindex(sub.set_index('time').index).values

def candles(ax,sub):
    for _,b in sub.iterrows():
        c="tab:green" if b.close>=b.open else "tab:red"
        ax.plot([b.time,b.time],[b.low,b.high],color=c,lw=0.6,zorder=1)
        ax.plot([b.time,b.time],[b.open,b.close],color=c,lw=2.6,zorder=1)

def mark(ax,td):
    b=td[td.side=="buy"]; s=td[td.side=="sell"]
    ax.scatter(b.e_time,b.e_price,marker="^",s=80,color="tab:blue",edgecolor="k",lw=.4,zorder=5,label="BUY entry (fade support)")
    ax.scatter(s.e_time,s.e_price,marker="v",s=80,color="magenta",edgecolor="k",lw=.4,zorder=5,label="SELL entry (fade resistance)")
    L=td[td.profit<0]; W=td[td.profit>0]
    ax.scatter(L.x_time,L.x_price,marker="x",s=70,color="red",zorder=6,label="LOSS exit (SL)")
    ax.scatter(W.x_time,W.x_price,marker="*",s=130,color="green",zorder=6,label="win exit (TP)")
    for _,t in td.iterrows():
        ax.plot([t.e_time,t.x_time],[t.e_price,t.x_price],color=("red" if t.profit<0 else "green"),lw=.6,alpha=.5,zorder=4)

# ---- FIG1: chop overview + equity ----
cw=px[(px.time>="2026-03-01")&(px.time<="2026-08-27")]
b=tr[tr.side=="buy"]; s=tr[tr.side=="sell"]
fig,(a1,a2)=plt.subplots(2,1,figsize=(15,9),gridspec_kw=dict(height_ratios=[3,1]),sharex=True)
a1.plot(cw.time,cw.close,color="#333",lw=0.8,label="XAUUSD close")
a1.plot(cw.time,lvl(pdH,cw),color="tab:blue",lw=.7,ls="--",alpha=.4,label="prev-day High")
a1.plot(cw.time,lvl(pdL,cw),color="tab:orange",lw=.7,ls="--",alpha=.4,label="prev-day Low")
mark(a1,tr)
a1.set_title("CHOP Mar-Aug 2026 (long+short fade)  BUY:%d (net %.0f)  SELL:%d (net %.0f) - which side bled?"%(
    len(b),b.profit.sum(),len(s),s.profit.sum()))
a1.set_ylabel("XAUUSD"); a1.legend(loc="upper right",fontsize=8)
eq=5000+tr.sort_values("x_time")["profit"].cumsum()
a2.plot(tr.sort_values("x_time")["x_time"],eq,color="crimson",lw=1.3); a2.axhline(5000,color="k",ls=":",lw=.6); a2.axhline(4500,color="red",ls="--",lw=.6)
a2.set_ylabel("equity $"); a2.set_title("equity",fontsize=9)
a1.xaxis.set_major_formatter(mdates.DateFormatter("%b %d"))
plt.tight_layout(); plt.savefig(os.path.join(OUT,"1_chop_overview.png"),dpi=120); plt.close(); print("saved 1")

# ---- FIG2: March 3-6 zoom (candles) ----
z=px[(px.time>="2026-03-03")&(px.time<="2026-03-06")]
zt=tr[(tr.e_time>="2026-03-03")&(tr.e_time<="2026-03-06")]
fig,ax=plt.subplots(figsize=(15,7)); candles(ax,z)
ax.plot(z.time,lvl(pdH,z),color="tab:blue",lw=1.2,ls="--",alpha=.6,label="prev-day High")
ax.plot(z.time,lvl(pdL,z),color="tab:orange",lw=1.2,ls="--",alpha=.6,label="prev-day Low")
mark(ax,zt)
zb=zt[zt.side=="buy"]; zs=zt[zt.side=="sell"]
ax.set_title("Mar 3-5 zoom: gold 5348->5077. BUY:%d (net %.0f) SELL:%d (net %.0f) - fades on both sides run over"%(
    len(zb),zb.profit.sum(),len(zs),zs.profit.sum()))
ax.set_ylabel("XAUUSD"); ax.legend(loc="upper right",fontsize=8)
ax.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d %H:%M"))
plt.tight_layout(); plt.savefig(os.path.join(OUT,"2_march_loss_cascade.png"),dpi=120); plt.close(); print("saved 2")

# ---- FIG3: May zoom ----
z=px[(px.time>="2026-05-01")&(px.time<="2026-05-31")]
mb=tr_may[tr_may.side=="buy"]; ms=tr_may[tr_may.side=="sell"]
fig,ax=plt.subplots(figsize=(15,7))
ax.plot(z.time,z.close,color="#333",lw=0.8,label="XAUUSD close")
ax.plot(z.time,lvl(pdH,z),color="tab:blue",lw=.8,ls="--",alpha=.5,label="prev-day High")
ax.plot(z.time,lvl(pdL,z),color="tab:orange",lw=.8,ls="--",alpha=.5,label="prev-day Low")
mark(ax,tr_may)
ax.set_title("MAY 2026 (long+short)  BUY:%d (net %.0f)  SELL:%d (net %.0f)"%(
    len(mb),mb.profit.sum(),len(ms),ms.profit.sum()))
ax.set_ylabel("XAUUSD"); ax.legend(loc="upper right",fontsize=8)
ax.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d"))
plt.tight_layout(); plt.savefig(os.path.join(OUT,"3_may_chop.png"),dpi=120); plt.close(); print("saved 3")
print("ALL DONE")

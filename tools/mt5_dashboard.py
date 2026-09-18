"""
MT5-style dashboard for the shipped BALANCED config (Model-4 real-tick, last 1 year):
 - equity/balance curve (with start line + -10% static limit)
 - month-by-month PnL bars
 - full stats table
Reads the per-trade CSV from the Model-4 run. Saves charts/mt5_dashboard.png.
"""
import os, csv
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

CSV = os.path.join("experiments","dtrend_bal_m4","windows","last1y_m4","trades.csv")
OUT = "charts"; os.makedirs(OUT, exist_ok=True)
DEP = 5000.0

rows=[]
for line in open(CSV, encoding="utf-8", errors="ignore"):
    line=line.strip()
    if not line or line.lower().startswith("time"): continue
    parts=line.split(",")
    if len(parts)<2: continue
    t=parts[0].strip(); p=parts[1].strip()
    try: pf=float(p)
    except: continue
    for fmt in ("%Y.%m.%d %H:%M","%Y.%m.%d %H:%M:%S"):
        try: dt=pd.to_datetime(t,format=fmt); break
        except: dt=None
    if dt is None: continue
    rows.append((dt,pf))
tr=pd.DataFrame(rows,columns=["time","profit"]).sort_values("time").reset_index(drop=True)
tr["equity"]=DEP+tr["profit"].cumsum()

# stats
net=tr.profit.sum(); ret=100*net/DEP
wins=tr[tr.profit>0]; loss=tr[tr.profit<0]
pf=wins.profit.sum()/abs(loss.profit.sum()) if len(loss) else float('inf')
winrate=100*len(wins)/len(tr) if len(tr) else 0
peak=np.maximum.accumulate(tr.equity.values); dd=(peak-tr.equity.values)
maxdd=dd.max(); maxdd_pct=100*maxdd/peak[np.argmax(dd)] if len(dd) else 0
below=DEP-tr.equity.min(); staticdd=max(0,below); staticdd_pct=100*staticdd/DEP

# monthly
tr["m"]=tr.time.dt.to_period("M").astype(str)
mon=tr.groupby("m")["profit"].sum()

fig=plt.figure(figsize=(15,11))
gs=fig.add_gridspec(3,1,height_ratios=[3,1.6,1.1],hspace=0.35)

# equity
ax1=fig.add_subplot(gs[0])
ax1.plot(tr.time,tr.equity,color="#0b6",lw=2,marker="o",ms=3)
ax1.fill_between(tr.time,DEP,tr.equity,where=(tr.equity>=DEP),color="#0b6",alpha=0.10)
ax1.axhline(DEP,color="k",ls=":",lw=1,label="start $5000")
ax1.axhline(DEP*0.9,color="red",ls="--",lw=1,label="-10% STATIC limit ($4500)")
ax1.set_title("CK_GOLD_DTREND (BALANCED) - Model-4 REAL-TICK - last 1 year   |   net +%.1f%%  PF %.2f  trades %d"%(ret,pf,len(tr)),fontsize=13,weight="bold")
ax1.set_ylabel("equity $"); ax1.legend(loc="upper left",fontsize=9)
ax1.xaxis.set_major_formatter(mdates.DateFormatter("%Y-%m"))

# monthly bars
ax2=fig.add_subplot(gs[1])
colors=["#0b6" if v>=0 else "#d33" for v in mon.values]
ax2.bar(range(len(mon)),mon.values,color=colors)
ax2.set_xticks(range(len(mon))); ax2.set_xticklabels(mon.index,rotation=45,ha="right",fontsize=8)
ax2.axhline(0,color="k",lw=.6); ax2.set_ylabel("month PnL $"); ax2.set_title("Month-by-month PnL",fontsize=10)
for i,v in enumerate(mon.values): ax2.text(i,v+(8 if v>=0 else -8),"%.0f"%v,ha="center",va=("bottom" if v>=0 else "top"),fontsize=7)

# stats table
ax3=fig.add_subplot(gs[2]); ax3.axis("off")
stats=[
 ["Net profit","$%.2f  (+%.1f%%)"%(net,ret)],
 ["Profit factor","%.2f"%pf],
 ["Trades / Win%%","%d  /  %.1f%%"%(len(tr),winrate)],
 ["Avg win / Avg loss","$%.2f  /  $%.2f"%(wins.profit.mean() if len(wins) else 0, loss.profit.mean() if len(loss) else 0)],
 ["Largest win / loss","$%.2f  /  $%.2f"%(tr.profit.max(),tr.profit.min())],
 ["Max DD (peak-to-trough)","%.2f%%  (trailing - static firm ignores)"%maxdd_pct],
 ["STATIC DD (below $5000 start)","%.2f%%  (GFT limit 10%%)"%staticdd_pct],
]
tbl=ax3.table(cellText=stats,colWidths=[0.34,0.66],loc="center",cellLoc="left")
tbl.auto_set_font_size(False); tbl.set_fontsize(11); tbl.scale(1,1.6)
plt.savefig(os.path.join(OUT,"mt5_dashboard.png"),dpi=120,bbox_inches="tight"); plt.close()
print("saved charts/mt5_dashboard.png  net=%.2f ret=%.1f pf=%.2f trades=%d staticDD=%.2f%%"%(net,ret,pf,len(tr),staticdd_pct))

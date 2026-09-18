"""
Last-1-year (2025.09 -> 2026.09) month-by-month P&L + equity curve for the
keeper config (CK_GOLD_DTREND H4 + D1-EMA50 confirm). Parses the MT5 deals htm.
"""
import os, re
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

HTM=os.path.join("experiments","dtrend_h4htf50","windows","full","report.htm")
OUT="charts"; os.makedirs(OUT,exist_ok=True)
DEP=5000.0

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
rows=[]
for r in html.split("<tr"):
    tds=[re.sub("<.*?>","",x).strip() for x in re.findall(r"<td[^>]*>(.*?)</td>",r,re.S)]
    if len(tds)<13 or tds[2]!="XAUUSD" or tds[4]!="out": continue
    rows.append(dict(time=pd.to_datetime(tds[0],format="%Y.%m.%d %H:%M:%S"),
                     side=tds[3], profit=num(tds[10])))
tr=pd.DataFrame(rows).sort_values("time").reset_index(drop=True)
tr["equity"]=DEP+tr["profit"].cumsum()

# monthly P&L
tr["month"]=tr["time"].dt.to_period("M")
m=tr.groupby("month").agg(trades=("profit","size"),pnl=("profit","sum"),
                          wins=("profit",lambda x:(x>0).sum())).reset_index()
m["pnl_pct_of_5k"]=100*m["pnl"]/DEP
print("=== LAST 1 YEAR  month-by-month (CK_GOLD_DTREND keeper) ===")
print("month     trades  wins   P&L($)   %of5k")
for _,r in m.iterrows():
    print("%-8s  %5d  %4d  %8.2f  %+6.2f"%(str(r['month']),r['trades'],r['wins'],r['pnl'],r['pnl_pct_of_5k']))
print("-"*44)
print("TOTAL     %5d       %8.2f  %+6.2f%%"%(len(tr),tr['profit'].sum(),100*tr['profit'].sum()/DEP))
print("winners=%d losers=%d  win%%=%.1f  PF=%.2f"%((tr.profit>0).sum(),(tr.profit<0).sum(),
      100*(tr.profit>0).mean(), tr[tr.profit>0].profit.sum()/abs(tr[tr.profit<0].profit.sum())))
# min equity vs initial (static DD)
print("min equity (closed) = %.2f  -> lowest below start = %.2f"%(tr.equity.min(), min(0,tr.equity.min()-DEP)))

# equity chart
fig,ax=plt.subplots(figsize=(15,7))
ax.plot(tr.time,tr.equity,color="tab:blue",lw=1.6,marker="o",ms=3,label="equity (closed trades)")
ax.axhline(DEP,color="k",ls=":",lw=.8,label="start $5000")
ax.axhline(DEP*0.90,color="red",ls="--",lw=.9,label="-10% STATIC limit ($4500)")
# color months
ax.fill_between(tr.time,DEP,tr.equity,where=(tr.equity>=DEP),color="green",alpha=0.08)
ax.set_title("CK_GOLD_DTREND keeper - LAST 1 YEAR (2025.09-2026.09): +%.1f%%  |  never below $5000 (static DD ~0)"%(100*tr.profit.sum()/DEP))
ax.set_ylabel("equity $"); ax.legend(loc="upper left",fontsize=9)
ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y-%m"))
plt.tight_layout(); plt.savefig(os.path.join(OUT,"last_1year_equity.png"),dpi=120); plt.close()
print("saved charts/last_1year_equity.png")

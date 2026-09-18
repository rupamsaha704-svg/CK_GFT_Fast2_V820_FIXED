"""
(1) Per-trade list (MT5-style) for the BALANCED Model-4 real-tick run -> charts/trade_list.html
(2) Risk-level comparison equity curves (SAFE M4 vs BALANCED M4) -> charts/risk_compare.png
"""
import os, re
import pandas as pd, numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

BAL_HTM=os.path.join("experiments","dtrend_bal_m4","windows","last1y_m4","report.htm")
SAFE_CSV=os.path.join("experiments","dtrend_m4","windows","last1y","trades.csv")
BAL_CSV =os.path.join("experiments","dtrend_bal_m4","windows","last1y_m4","trades.csv")
OUT="charts"; os.makedirs(OUT,exist_ok=True); DEP=5000.0

def num(s):
    s=s.replace(" ","")
    try:return float(s)
    except:return float("nan")
def load_htm(path):
    raw=open(path,"rb").read(); html=None
    for enc in ("utf-16","utf-8","latin-1"):
        try:
            t=raw.decode(enc)
            if "<tr" in t and "XAUUSD" in t: html=t; break
        except: pass
    return html
# ---- parse balanced deals -> trades ----
html=load_htm(BAL_HTM); deals=[]
for r in html.split("<tr"):
    tds=[re.sub("<.*?>","",x).strip() for x in re.findall(r"<td[^>]*>(.*?)</td>",r,re.S)]
    if len(tds)<13 or tds[2]!="XAUUSD" or tds[4] not in ("in","out"): continue
    deals.append(dict(dirn=tds[4],typ=tds[3],time=tds[0],price=num(tds[6]),profit=num(tds[10])))
T=[];cur=None
for d in deals:
    if d["dirn"]=="in": cur=d
    elif d["dirn"]=="out" and cur:
        T.append(dict(side=cur["typ"].upper(),e_time=cur["time"],e_price=cur["price"],
                      x_time=d["time"],x_price=d["price"],profit=d["profit"])); cur=None
tr=pd.DataFrame(T); tr["bal"]=DEP+tr["profit"].cumsum()

# ---- HTML table ----
rows=""
for i,r in tr.iterrows():
    col="#39d353" if r.profit>=0 else "#ff5555"
    rows+="<tr><td>%d</td><td>%s</td><td>%s</td><td>%.2f</td><td>%s</td><td>%.2f</td><td style='color:%s;font-weight:bold'>%+.2f</td><td>%.2f</td></tr>"%(
        i+1,r.side,r.e_time,r.e_price,r.x_time,r.x_price,col,r.profit,r.bal)
net=tr.profit.sum()
html_out="""<html><head><meta charset='utf-8'><title>CK_GOLD_DTREND trades</title>
<style>body{background:#111;color:#eee;font-family:Segoe UI,Arial;margin:20px}
h1{color:#4da3ff}table{border-collapse:collapse;width:100%%;font-size:14px}
th,td{border:1px solid #444;padding:6px 10px;text-align:right}th{background:#222;color:#4da3ff}
tr:nth-child(even){background:#181818}</style></head><body>
<h1>CK_GOLD_DTREND (BALANCED) - per-trade list - Model-4 real-tick - last 1 year</h1>
<p>Start $5000 &nbsp; | &nbsp; Net %+.2f (+%.1f%%) &nbsp; | &nbsp; %d trades &nbsp; | &nbsp; ended $%.2f</p>
<table><tr><th>#</th><th>Side</th><th>Entry time</th><th>Entry</th><th>Exit time</th><th>Exit</th><th>Profit $</th><th>Balance $</th></tr>
%s</table></body></html>"""%(net,100*net/DEP,len(tr),DEP+net,rows)
open(os.path.join(OUT,"trade_list.html"),"w",encoding="utf-8").write(html_out)
print("saved charts/trade_list.html  (%d trades, net %.2f)"%(len(tr),net))

# ---- risk comparison equity (SAFE vs BALANCED, both M4) ----
def eq_from_csv(path):
    pf=[]; 
    for line in open(path,encoding="utf-8",errors="ignore"):
        line=line.strip()
        if not line or line.lower().startswith("time"): continue
        p=line.split(",")
        if len(p)<2: continue
        t=p[0]
        try: v=float(p[1])
        except: continue
        dt=None
        for fmt in ("%Y.%m.%d %H:%M","%Y.%m.%d %H:%M:%S"):
            try: dt=pd.to_datetime(t,format=fmt); break
            except: pass
        if dt is not None: pf.append((dt,v))
    d=pd.DataFrame(pf,columns=["time","profit"]).sort_values("time")
    d["eq"]=DEP+d["profit"].cumsum(); return d
safe=eq_from_csv(SAFE_CSV); bal=eq_from_csv(BAL_CSV)
fig,ax=plt.subplots(figsize=(15,7))
ax.plot(safe["time"],safe["eq"],color="#3a7",lw=1.8,marker="o",ms=2,label="SAFE (risk1/cap3) real-tick +%.0f%%"%(100*(safe["eq"].iloc[-1]-DEP)/DEP))
ax.plot(bal["time"],bal["eq"],color="#e8a33d",lw=1.8,marker="o",ms=2,label="BALANCED (risk2.5/cap5) real-tick +%.0f%%"%(100*(bal["eq"].iloc[-1]-DEP)/DEP))
ax.axhline(DEP,color="k",ls=":",lw=1); ax.axhline(DEP*0.9,color="red",ls="--",lw=1,label="-10% static ($4500)")
ax.set_title("Risk-level comparison (Model-4 real-tick, last 1 year) - same edge, different sizing",fontsize=12,weight="bold")
ax.set_ylabel("equity $"); ax.legend(loc="upper left",fontsize=10)
ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y-%m"))
plt.tight_layout(); plt.savefig(os.path.join(OUT,"risk_compare.png"),dpi=120); plt.close()
print("saved charts/risk_compare.png  SAFE end=%.0f BAL end=%.0f"%(safe["eq"].iloc[-1],bal["eq"].iloc[-1]))

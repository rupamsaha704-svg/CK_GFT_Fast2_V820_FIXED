import pandas as pd, numpy as np, re, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

DEP=5000.0
OUT=os.path.join(os.path.expanduser("~"),"Desktop","gold_chop_charts")
FIX,DT="20260716","20260930"
CFG=[
 ("BASELINE (daily5, no block)", r"experiments\combo_1y\windows\last1y"),
 ("V1 daily4.5 (no block)",       r"experiments\combo_v1_daily45\windows\last1y"),
 ("V2 block 15,16 (daily5)",      r"experiments\combo_v2_block1516\windows\last1y"),
 ("V3 both (daily4.5 + 15,16)",   r"experiments\combo_v3_both\windows\last1y"),
]
def load(d):
    df=pd.read_csv(os.path.join(d,"trades.csv")); df.columns=[c.strip().lower() for c in df.columns]
    df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M")
    df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0); df["magic"]=df["magic"].astype(str)
    return df.sort_values("time").reset_index(drop=True)
def stat(df,label):
    prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
    net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
    static=max(0.0,DEP-eq.min()); peak=np.maximum.accumulate(eq); trail=((peak-eq)/peak*100).max()
    run=DEP; worst=0.0; worstd=None
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl
        if pl<0 and pl/s*100<worst: worst=pl/s*100; worstd=dte
    # count days <= -5 and <= -3
    run=DEP; d5=0; d3=0
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
        if pct<=-5: d5+=1
        if pct<=-3: d3+=1
    return dict(label=label,eq=eq,times=[df["time"].iloc[0]-pd.Timedelta(minutes=1)]+list(df["time"]),
               net=net,pf=pf,static=static,trail=trail,worst=worst,worstd=worstd,n=len(df),
               days5=d5,days3=d3)
def htm(d,lab):
    p=os.path.join(d,"report.htm")
    try: raw=open(p,"r",encoding="utf-16",errors="ignore").read()
    except: raw=open(p,"rb").read().decode("utf-16",errors="ignore")
    raw=re.sub(r"<[^>]+>","|",raw).replace("&nbsp;"," "); i=raw.find(lab)
    if i<0: return "?"
    m=re.search(r"-?\d[\d \u00a0.,]*",raw[i+len(lab):i+len(lab)+80]); 
    return m.group(0).replace("\u00a0","").replace(" ","").replace(",","") if m else "?"

S=[]
for lab,d in CFG:
    if not os.path.exists(os.path.join(d,"trades.csv")):
        print("MISSING", lab, d); continue
    S.append(stat(load(d),lab))

hdr=f"{'config':30s} | {'net$':>14s} | {'PF':>5s} | {'trades':>7s} | {'staticDD%':>9s} | {'worstday%':>16s} | {'days<=-5':>8s} | {'days<=-3':>8s}"
print(hdr); print("-"*len(hdr))
for s in S:
    print(f"{s['label']:30s} | {s['net']:>8,.0f}({s['net']/DEP*100:+.0f}%) | {s['pf']:>5.2f} | {s['n']:>7d} | {s['static']/DEP*100:>9.2f} | {s['worst']:>7.2f} ({str(s['worstd'])}) | {s['days5']:>8d} | {s['days3']:>8d}")

print("\nMT5 native (htm):")
for lab,d in CFG:
    if os.path.exists(os.path.join(d,"report.htm")):
        print(f"  {lab:30s} net={htm(d,'Total Net Profit:')} PF={htm(d,'Profit Factor:')} balDDabs={htm(d,'Balance Drawdown Absolute:')} eqDDabs={htm(d,'Equity Drawdown Absolute:')}")

# chart
fig,ax=plt.subplots(figsize=(13,6.5))
colors=["#999","#1f77b4","#ff7f0e","#2ca02c"]
for s,c in zip(S,colors):
    ax.plot(s["times"],s["eq"],color=c,lw=1.5 if s is S[-1] else 1.2,
            label=f"{s['label']}: ${DEP+s['net']:,.0f} ({s['net']/DEP*100:+.0f}%) worst {s['worst']:.1f}% d<=-5:{s['days5']}")
ax.axhline(DEP,color="gray",ls="--",lw=0.8); ax.axhline(DEP*0.9,color="red",ls=":",lw=1.0)
ax.set_title("Combo fixes: #1 daily 4.5% vs #2 block 15,16 vs #3 both")
ax.set_ylabel("Equity $"); ax.legend(fontsize=8,loc="upper left"); ax.grid(alpha=0.25)
ax.xaxis.set_major_formatter(mdates.DateFormatter("%b'%y"))
plt.tight_layout(); pth=os.path.join(OUT,"combo_variants_compare.png"); plt.savefig(pth,dpi=115)
print("saved:",pth)

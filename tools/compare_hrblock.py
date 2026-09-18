import pandas as pd, numpy as np, re, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

DEP = 5000.0
OUT = os.path.join(os.path.expanduser("~"), "Desktop", "gold_chop_charts")
BASE = r"experiments\combo_1y\windows\last1y\trades.csv"
HB   = r"experiments\combo_hrblock\windows\last1y\trades.csv"
BASE_HTM = r"experiments\combo_1y\windows\last1y\report.htm"
HB_HTM   = r"experiments\combo_hrblock\windows\last1y\report.htm"
FIX, DT = "20260716", "20260930"

def load(p):
    df = pd.read_csv(p); df.columns=[c.strip().lower() for c in df.columns]
    df["time"]=pd.to_datetime(df["time"], format="%Y.%m.%d %H:%M")
    df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
    df["magic"]=df["magic"].astype(str)
    return df.sort_values("time").reset_index(drop=True)

def stats(df, label):
    prof=df["profit"].values
    eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
    net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum()
    pf=gp/abs(gl) if gl!=0 else float("inf")
    static=max(0.0,DEP-eq.min())
    peak=np.maximum.accumulate(eq); trail=((peak-eq)/peak*100).max()
    run=DEP; worst=0.0; worstd=None
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl
        if pl<0 and pl/s*100<worst: worst=pl/s*100; worstd=dte
    fn=df[df["magic"]==FIX]["profit"].sum(); dn=df[df["magic"]==DT]["profit"].sum()
    fc=(df["magic"]==FIX).sum(); dc=(df["magic"]==DT).sum()
    return dict(label=label, eq=eq, times=[df["time"].iloc[0]-pd.Timedelta(minutes=1)]+list(df["time"]),
                net=net, pf=pf, static=static, trail=trail, worst=worst, worstd=worstd,
                n=len(df), fn=fn, dn=dn, fc=fc, dc=dc)

def htmval(p, label):
    try:
        raw=open(p,"r",encoding="utf-16",errors="ignore").read()
    except: 
        raw=open(p,"rb").read().decode("utf-16",errors="ignore")
    raw=re.sub(r"<[^>]+>","|",raw).replace("&nbsp;"," ")
    i=raw.find(label)
    if i<0: return None
    m=re.search(r"-?\d[\d \u00a0.,]*", raw[i+len(label):i+len(label)+80])
    return m.group(0).replace("\u00a0","").replace(" ","").replace(",","") if m else None

b=stats(load(BASE),"BASELINE (all hours)")
h=stats(load(HB),  "HOUR-BLOCK (4,12,15,16)")

print(f"{'metric':22s} | {'BASELINE':>16s} | {'HOUR-BLOCK':>16s}")
print("-"*62)
def row(name, bv, hv): print(f"{name:22s} | {bv:>16s} | {hv:>16s}")
row("net $", f"{b['net']:,.0f} ({b['net']/DEP*100:+.0f}%)", f"{h['net']:,.0f} ({h['net']/DEP*100:+.0f}%)")
row("profit factor", f"{b['pf']:.2f}", f"{h['pf']:.2f}")
row("trades", f"{b['n']} (F{b['fc']}/D{b['dc']})", f"{h['n']} (F{h['fc']}/D{h['dc']})")
row("static DD %", f"{b['static']/DEP*100:.2f}", f"{h['static']/DEP*100:.2f}")
row("trailing DD %", f"{b['trail']:.2f}", f"{h['trail']:.2f}")
row("worst day %", f"{b['worst']:.2f} ({b['worstd']})", f"{h['worst']:.2f} ({h['worstd']})")
row("FIX09 net $", f"{b['fn']:,.0f}", f"{h['fn']:,.0f}")
row("DTREND net $", f"{b['dn']:,.0f}", f"{h['dn']:,.0f}")

print("\nMT5 native htm:")
for lab in ["Total Net Profit:","Profit Factor:","Balance Drawdown Absolute:","Equity Drawdown Absolute:","Total Trades:"]:
    print(f"  {lab:28s} base={htmval(BASE_HTM,lab)}   hrblock={htmval(HB_HTM,lab)}")

# chart
fig,ax=plt.subplots(figsize=(13,6))
ax.plot(b["times"], b["eq"], color="#999", lw=1.3, label=f"BASELINE  ${DEP+b['net']:,.0f} ({b['net']/DEP*100:+.0f}%)  worstday {b['worst']:.1f}%")
ax.plot(h["times"], h["eq"], color="#2ca02c", lw=1.5, label=f"HOUR-BLOCK 4,12,15,16  ${DEP+h['net']:,.0f} ({h['net']/DEP*100:+.0f}%)  worstday {h['worst']:.1f}%")
ax.axhline(DEP,color="gray",ls="--",lw=0.8); ax.axhline(DEP*0.9,color="red",ls=":",lw=1.0,label="10% static breach")
ax.set_title("Combo: block new entries at 15/16/04/12h (running trades kept) vs baseline")
ax.set_ylabel("Equity $"); ax.legend(fontsize=9); ax.grid(alpha=0.25)
ax.xaxis.set_major_formatter(mdates.DateFormatter("%b'%y"))
plt.tight_layout(); pth=os.path.join(OUT,"combo_hrblock_compare.png"); plt.savefig(pth,dpi=115)
print("saved:",pth)

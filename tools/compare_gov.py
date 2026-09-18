import pandas as pd, numpy as np, re, os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt, matplotlib.dates as mdates
DEP=5000.0; OUT=os.path.join(os.path.expanduser("~"),"Desktop","gold_chop_charts")
FIX,DT="20260716","20260930"
CFG=[("BASELINE (daily5 reactive)", r"experiments\combo_base2\windows\last1y"),
     ("GOVERNOR (predictive4 + cap3)", r"experiments\combo_gov\windows\last1y")]
def load(d):
    df=pd.read_csv(os.path.join(d,"trades.csv")); df.columns=[c.strip().lower() for c in df.columns]
    df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M"); df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
    df["magic"]=df["magic"].astype(str); return df.sort_values("time").reset_index(drop=True)
def stat(df):
    prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
    net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
    static=max(0.0,DEP-eq.min())
    run=DEP; worst=0.0; worstd=None; d5=0; d45=0; d3=0
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
        if pct<worst: worst=pct; worstd=dte
        if pct<=-5:d5+=1
        if pct<=-4.5:d45+=1
        if pct<=-3:d3+=1
    fn=df[df["magic"]==FIX]["profit"].sum(); dn=df[df["magic"]==DT]["profit"].sum()
    return dict(eq=eq,times=[df["time"].iloc[0]-pd.Timedelta(minutes=1)]+list(df["time"]),
                net=net,pf=pf,static=static,worst=worst,worstd=worstd,d5=d5,d45=d45,d3=d3,n=len(df),fn=fn,dn=dn)
def htm(d,lab):
    p=os.path.join(d,"report.htm")
    if not os.path.exists(p): return "?"
    try: raw=open(p,"r",encoding="utf-16",errors="ignore").read()
    except: raw=open(p,"rb").read().decode("utf-16",errors="ignore")
    raw=re.sub(r"<[^>]+>","|",raw).replace("&nbsp;"," "); i=raw.find(lab)
    if i<0:return "?"
    m=re.search(r"-?\d[\d \u00a0.,]*",raw[i+len(lab):i+len(lab)+80]); return m.group(0).replace("\u00a0","").replace(" ","").replace(",","") if m else "?"
S=[]
for lab,d in CFG:
    if not os.path.exists(os.path.join(d,"trades.csv")): print("MISSING",lab); continue
    s=stat(load(d)); s["label"]=lab; s["dir"]=d; S.append(s)
print(f"{'config':32s}|{'net$':>16s}|{'PF':>5s}|{'trades':>7s}|{'staticDD%':>9s}|{'worstday%':>16s}|{'d>=5':>5s}|{'d>=3':>5s}")
print("-"*100)
for s in S:
    print(f"{s['label']:32s}|{s['net']:>8,.0f}({s['net']/DEP*100:+.0f}%)|{s['pf']:>5.2f}|{s['n']:>7d}|{s['static']/DEP*100:>9.2f}|{s['worst']:>7.2f} ({s['worstd']})|{s['d5']:>5d}|{s['d3']:>5d}")
    print(f"    FIX09 ${s['fn']:,.0f} / DTREND ${s['dn']:,.0f}   (days<=-4.5%: {s['d45']})")
print("\nMT5 native htm:")
for lab,d in CFG:
    print(f"  {lab:32s} net={htm(d,'Total Net Profit:')} PF={htm(d,'Profit Factor:')} balDDabs={htm(d,'Balance Drawdown Absolute:')} eqDDabs={htm(d,'Equity Drawdown Absolute:')}")
if len(S)==2:
    ret=S[1]['net']/S[0]['net']*100 if S[0]['net']!=0 else 0
    print(f"\nEDGE RETENTION governor/baseline net = {ret:.0f}%  (prereg pass >=80%)")
    print(f"WORST DAY: baseline {S[0]['worst']:.2f}% -> governor {S[1]['worst']:.2f}%   days>=5%: {S[0]['d5']} -> {S[1]['d5']}  (prereg pass = 0)")
    verdict = "PASS" if (S[1]['d5']==0 and S[1]['static']/DEP*100<10 and ret>=80) else "REVIEW"
    print("PREREG QUICK-CHECK:", verdict)
    fig,ax=plt.subplots(figsize=(13,6))
    for s,c in zip(S,["#999","#2ca02c"]):
        ax.plot(s["times"],s["eq"],color=c,lw=1.5,label=f"{s['label']}: ${DEP+s['net']:,.0f} ({s['net']/DEP*100:+.0f}%) worst {s['worst']:.1f}% d>=5:{s['d5']}")
    ax.axhline(DEP,color="gray",ls="--",lw=0.8); ax.axhline(DEP*0.9,color="red",ls=":",lw=1.0,label="10% static breach")
    ax.set_title("CK_GOLD_COMBO: pre-trade predictive daily governor + per-trade cap vs baseline")
    ax.set_ylabel("Equity $"); ax.legend(fontsize=8); ax.grid(alpha=0.25); ax.xaxis.set_major_formatter(mdates.DateFormatter("%b'%y"))
    plt.tight_layout(); p=os.path.join(OUT,"combo_governor_compare.png"); plt.savefig(p,dpi=115); print("saved:",p)

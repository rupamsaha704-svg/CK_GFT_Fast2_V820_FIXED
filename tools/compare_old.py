import pandas as pd, numpy as np, re, os
DEP=5000.0; FIX,DT="20260716","20260930"
CFG=[("OLD BASELINE (daily5)", r"experiments\combo_base_old\windows\old2025h1"),
     ("OLD GOVERNOR (pred4+cap3)", r"experiments\combo_gov_old\windows\old2025h1")]
def load(d):
    df=pd.read_csv(os.path.join(d,"trades.csv")); df.columns=[c.strip().lower() for c in df.columns]
    df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M"); df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
    df["magic"]=df["magic"].astype(str); return df.sort_values("time").reset_index(drop=True)
def stat(df):
    prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
    net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
    static=max(0.0,DEP-eq.min()); run=DEP; worst=0.0; worstd=None; d5=0
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
        if pct<worst: worst=pct; worstd=dte
        if pct<=-5: d5+=1
    return net,pf,static,worst,worstd,d5,len(df)
def htm(d,lab):
    p=os.path.join(d,"report.htm")
    if not os.path.exists(p): return "?"
    try: raw=open(p,"r",encoding="utf-16",errors="ignore").read()
    except: raw=open(p,"rb").read().decode("utf-16",errors="ignore")
    raw=re.sub(r"<[^>]+>","|",raw).replace("&nbsp;"," "); i=raw.find(lab)
    if i<0:return "?"
    m=re.search(r"-?\d[\d \u00a0.,]*",raw[i+len(lab):i+len(lab)+80]); return m.group(0).replace("\u00a0","").replace(" ","").replace(",","") if m else "?"
for lab,d in CFG:
    if not os.path.exists(os.path.join(d,"trades.csv")): print("MISSING",lab,d); continue
    net,pf,static,worst,worstd,d5,n=stat(load(d))
    print(f"{lab:28s} net={net:+8.0f}({net/DEP*100:+.0f}%) PF={pf:.2f} trades={n} staticDD%={static/DEP*100:.2f} worstday={worst:.2f}%({worstd}) days>=5%={d5}")
    print(f"    htm: net={htm(d,'Total Net Profit:')} balDDabs={htm(d,'Balance Drawdown Absolute:')} eqDDabs={htm(d,'Equity Drawdown Absolute:')}")

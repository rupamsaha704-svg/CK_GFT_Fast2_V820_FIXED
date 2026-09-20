import pandas as pd, numpy as np, re, os
DEP=5000.0; FIX,DT="20260716","20260930"
CFG=[("GOVERNOR (MTF off)", r"experiments\combo_gov\windows\last1y"),
     ("MTF ON (M15/H1/H4/D1)", r"experiments\combo_mtf\windows\last1y")]
def load(d):
    df=pd.read_csv(os.path.join(d,"trades.csv")); df.columns=[c.strip().lower() for c in df.columns]
    df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M"); df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
    df["magic"]=df["magic"].astype(str); return df.sort_values("time").reset_index(drop=True)
def stat(df):
    prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
    net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
    nz=df[df["profit"]!=0]; wr=(nz["profit"]>0).mean()*100 if len(nz) else 0
    static=max(0.0,DEP-eq.min()); run=DEP; worst=0.0; d5=0
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
        if pct<worst: worst=pct
        if pct<=-5: d5+=1
    fwr=0; f=df[df["magic"]==FIX]; fnz=f[f["profit"]!=0]; fwr=(fnz["profit"]>0).mean()*100 if len(fnz) else 0
    return dict(net=net,pf=pf,wr=wr,fwr=fwr,static=static,worst=worst,d5=d5,n=len(df),
                fn=f["profit"].sum(),dn=df[df["magic"]==DT]["profit"].sum(),fc=len(f),dc=(df["magic"]==DT).sum())
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
    if not os.path.exists(os.path.join(d,"trades.csv")): print("MISSING",lab,d); continue
    s=stat(load(d)); s["label"]=lab; s["dir"]=d; S.append(s)
print(f"{'config':26s}|{'net$':>15s}|{'PF':>5s}|{'winrate':>8s}|{'FIX09 win':>9s}|{'trades':>7s}|{'worstday':>16s}|{'d>=5':>4s}")
print("-"*100)
for s in S:
    print(f"{s['label']:26s}|{s['net']:>7,.0f}({s['net']/DEP*100:+.0f}%)|{s['pf']:>5.2f}|{s['wr']:>7.1f}%|{s['fwr']:>8.1f}%|{s['n']:>7d}|{s['worst']:>7.2f}({s['d5']}d>=5)|{s['d5']:>4d}")
    print(f"   FIX09 ${s['fn']:,.0f}/{s['fc']}tr   DTREND ${s['dn']:,.0f}/{s['dc']}tr   staticDD {s['static']/DEP*100:.2f}%")
for lab,d in CFG:
    print(f"  htm {lab:24s}: net={htm(d,'Total Net Profit:')} PF={htm(d,'Profit Factor:')} balDDabs={htm(d,'Balance Drawdown Absolute:')}")
if len(S)==2:
    print(f"\nWIN RATE: {S[0]['wr']:.1f}% -> {S[1]['wr']:.1f}%   FIX09 win: {S[0]['fwr']:.1f}% -> {S[1]['fwr']:.1f}%")
    print(f"NET: {S[0]['net']/DEP*100:+.0f}% -> {S[1]['net']/DEP*100:+.0f}%   worstday: {S[0]['worst']:.2f}% -> {S[1]['worst']:.2f}%   days>=5: {S[0]['d5']} -> {S[1]['d5']}")

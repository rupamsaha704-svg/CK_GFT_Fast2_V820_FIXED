import pandas as pd, numpy as np, os, re
DEP=5000.0; GG=100.0; FLAT=85.0
CFG=[("0.01 lot (funded2, baseline)", r"experiments\combo_m4_funded2\windows\last1y"),
     ("0.02 lot (+$85 flatten)",       r"experiments\combo_fs_a\windows\last1y"),
     ("0.03 lot (+$85 flatten)",       r"experiments\combo_fs_b\windows\last1y")]
def htm(d,lab):
    p=os.path.join(d,"report.htm")
    if not os.path.exists(p): return "?"
    try: raw=open(p,"r",encoding="utf-16",errors="ignore").read()
    except: raw=open(p,"rb").read().decode("utf-16",errors="ignore")
    raw=re.sub(r"<[^>]+>","|",raw).replace("&nbsp;"," "); i=raw.find(lab)
    if i<0:return "?"
    m=re.search(r"-?\d[\d \u00a0.,]*",raw[i+len(lab):i+len(lab)+80]); return m.group(0).replace("\u00a0","").replace(" ","").replace(",","") if m else "?"
def analyze(d):
    fp=os.path.join(d,"trades.csv")
    if not os.path.exists(fp): return None
    df=pd.read_csv(fp); df.columns=[c.strip().lower() for c in df.columns]
    df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M"); df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
    df=df.sort_values("time").reset_index(drop=True)
    prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
    net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
    static=max(0.0,DEP-eq.min()); worst=prof.min() if len(prof) else 0
    over_gg=int((prof<=-GG).sum()); over_flat=int((prof<=-FLAT).sum())
    run=DEP; wd=0.0; d5=0
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
        if pct<wd: wd=pct
        if pct<=-5: d5+=1
    ok=(over_gg==0 and abs(worst)<GG and d5==0 and static/DEP*100<10)
    return dict(net=net,pf=pf,n=len(df),worst=worst,over_gg=over_gg,over_flat=over_flat,wd=wd,d5=d5,static=static/DEP*100,ok=ok)
print("FUNDED LOT SWEEP (real-tick last1y) - find max safe size under Goat Guard $100 (flatten $85)")
print(f"{'size':30s}|{'net%':>7s}|{'PF':>5s}|{'trades':>6s}|{'worstTrade':>10s}|{'>$85':>5s}|{'>=$100(GG)':>10s}|{'worstday':>9s}|{'RULES':>6s}")
print("-"*100)
for lab,d in CFG:
    r=analyze(d)
    if r is None: print(f"{lab:30s}|  (not finished)"); continue
    print(f"{lab:30s}|{r['net']/DEP*100:>+6.0f}%|{r['pf']:>5.2f}|{r['n']:>6d}|{r['worst']:>10.2f}|{r['over_flat']:>5d}|{r['over_gg']:>10d}|{r['wd']:>8.2f}%|{'PASS' if r['ok'] else 'FAIL':>6s}")
    print(f"    htm net={htm(d,'Total Net Profit:')} ({(float(htm(d,'Total Net Profit:'))/DEP*100 if htm(d,'Total Net Profit:') not in ('?','') else 0):+.0f}%)  balDDabs={htm(d,'Balance Drawdown Absolute:')}")
print("-"*100)
print("Pick the LARGEST lot that still has 0 trades>=$100 (Goat Guard) AND 0 days>=5%. That = max safe funded size.")

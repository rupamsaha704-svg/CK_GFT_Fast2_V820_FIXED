import pandas as pd, numpy as np, os
DEP=5000.0; FIX,DT="20260716","20260930"; GG=100.0  # Goat Guard 2% of 5000
CFG=[
 ("Gov eval MTFoff  last1y", r"experiments\combo_gov\windows\last1y", "eval"),
 ("MTF=1 eval       last1y", r"experiments\combo_mtf1\windows\last1y", "eval"),
 ("MTF=2 eval       last1y", r"experiments\combo_mtf\windows\last1y", "eval"),
 ("MTF=3 eval       last1y", r"experiments\combo_mtf3\windows\last1y", "eval"),
 ("Gov eval MTFoff  2025H1", r"experiments\combo_gov_old\windows\old2025h1", "eval"),
 ("MTF=2 eval OOS   2025H1", r"experiments\combo_mtf_old\windows\old2025h1", "eval"),
 ("FUNDED           last1y", r"experiments\combo_funded\windows\last1y", "funded"),
 ("FUNDED OOS       2025H1", r"experiments\combo_funded_old\windows\old2025h1", "funded"),
]
def analyze(d, mode):
    fp=os.path.join(d,"trades.csv")
    if not os.path.exists(fp): return None
    df=pd.read_csv(fp); df.columns=[c.strip().lower() for c in df.columns]
    df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M"); df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
    df["magic"]=df["magic"].astype(str); df=df.sort_values("time").reset_index(drop=True)
    prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
    net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
    nz=df[df["profit"]!=0]; wr=(nz["profit"]>0).mean()*100 if len(nz) else 0
    static=max(0.0,DEP-eq.min()); worst_trade=prof.min() if len(prof) else 0
    over_gg=int((prof<=-GG).sum())
    run=DEP; worst=0.0; d5=0
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
        if pct<worst: worst=pct
        if pct<=-5: d5+=1
    if mode=="funded": ok = (d5==0 and static/DEP*100<10 and over_gg==0 and abs(worst_trade)<GG)
    else:              ok = (d5==0 and static/DEP*100<10)
    return dict(net=net,pf=pf,wr=wr,n=len(df),worst=worst,d5=d5,static=static/DEP*100,worst_trade=worst_trade,over_gg=over_gg,ok=ok,mode=mode)
print(f"{'config':26s}|{'net%':>7s}|{'PF':>5s}|{'win%':>6s}|{'trades':>6s}|{'worstday':>9s}|{'d>=5':>4s}|{'staticDD':>8s}|{'worstTrade':>10s}|{'RULES':>6s}")
print("-"*108)
best=None
for lab,d,mode in CFG:
    r=analyze(d,mode)
    if r is None: print(f"{lab:26s}|  (missing - run not finished)"); continue
    extra = f"  GGover={r['over_gg']}" if mode=="funded" else ""
    print(f"{lab:26s}|{r['net']/DEP*100:>+6.0f}%|{r['pf']:>5.2f}|{r['wr']:>5.1f}%|{r['n']:>6d}|{r['worst']:>8.2f}%|{r['d5']:>4d}|{r['static']:>7.2f}%|{r['worst_trade']:>10.2f}|{'PASS' if r['ok'] else 'FAIL':>6s}{extra}")
    if mode=="eval" and "last1y" in lab and r['ok']:
        if best is None or r['pf']>best[1]: best=(lab,r['pf'],r['wr'],r['net'])
print("-"*108)
if best: print(f"BEST eval (last1y, rule-safe, by PF): {best[0].strip()}  PF={best[1]:.2f} win={best[2]:.1f}% net={best[3]/DEP*100:+.0f}%")
print("COMPLIANCE: eval must have 0 days>=5% & staticDD<10%; FUNDED must ALSO have 0 trades<=-$100 (Goat Guard 2%).")

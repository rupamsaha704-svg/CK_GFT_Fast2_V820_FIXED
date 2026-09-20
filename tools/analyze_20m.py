import pandas as pd, numpy as np, os, re
DEP=5000.0; FIX,DT="20260716","20260930"; GG=100.0
CFG=[("20m EVAL   (Stage0,MTF2)", r"experiments\combo_20m_eval\windows\m20", "eval"),
     ("20m FUNDED (Stage1,tight)", r"experiments\combo_20m_funded\windows\m20", "funded")]
def htm(d,lab):
    p=os.path.join(d,"report.htm")
    if not os.path.exists(p): return "?"
    try: raw=open(p,"r",encoding="utf-16",errors="ignore").read()
    except: raw=open(p,"rb").read().decode("utf-16",errors="ignore")
    raw=re.sub(r"<[^>]+>","|",raw).replace("&nbsp;"," "); i=raw.find(lab)
    if i<0:return "?"
    m=re.search(r"-?\d[\d \u00a0.,]*",raw[i+len(lab):i+len(lab)+80]); return m.group(0).replace("\u00a0","").replace(" ","").replace(",","") if m else "?"
def analyze(d,mode):
    fp=os.path.join(d,"trades.csv")
    if not os.path.exists(fp): return None
    df=pd.read_csv(fp); df.columns=[c.strip().lower() for c in df.columns]
    df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M"); df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
    df["magic"]=df["magic"].astype(str); df=df.sort_values("time").reset_index(drop=True)
    prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
    net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
    nz=df[df["profit"]!=0]; wr=(nz["profit"]>0).mean()*100 if len(nz) else 0
    static=max(0.0,DEP-eq.min()); worst_trade=prof.min() if len(prof) else 0; over_gg=int((prof<=-GG).sum())
    run=DEP; worst=0.0; d5=0
    for dte,g in df.groupby(df["time"].dt.date):
        s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
        if pct<worst: worst=pct
        if pct<=-5: d5+=1
    if mode=="funded": ok=(d5==0 and static/DEP*100<10 and over_gg==0 and abs(worst_trade)<GG)
    else: ok=(d5==0 and static/DEP*100<10)
    return dict(net=net,pf=pf,wr=wr,n=len(df),worst=worst,d5=d5,static=static/DEP*100,worst_trade=worst_trade,over_gg=over_gg,ok=ok)
print("20-MONTH BREADTH CHECK (Model-1 fast) - last-1-year real-tick remains the AUTHORITY")
print(f"{'config':26s}|{'net%':>7s}|{'PF':>5s}|{'win%':>6s}|{'trades':>6s}|{'worstday':>9s}|{'d>=5':>4s}|{'static':>7s}|{'wTrade':>9s}|{'RULES':>6s}")
print("-"*100)
for lab,d,mode in CFG:
    r=analyze(d,mode)
    if r is None: print(f"{lab:26s}|  (missing / not finished)"); continue
    extra=f" GG={r['over_gg']}" if mode=="funded" else ""
    print(f"{lab:26s}|{r['net']/DEP*100:>+6.0f}%|{r['pf']:>5.2f}|{r['wr']:>5.1f}%|{r['n']:>6d}|{r['worst']:>8.2f}%|{r['d5']:>4d}|{r['static']:>6.2f}%|{r['worst_trade']:>9.2f}|{'PASS' if r['ok'] else 'FAIL':>6s}{extra}")
    print(f"    htm: net={htm(d,'Total Net Profit:')} PF={htm(d,'Profit Factor:')} balDDabs={htm(d,'Balance Drawdown Absolute:')}")
print("-"*100)
print("Note: eval PASS = 0 days>=5% & static<10%; funded ALSO 0 trades<=-$100 (Goat Guard). 20m = older regime included; may differ from last-1-yr (that's expected, regime shifted).")

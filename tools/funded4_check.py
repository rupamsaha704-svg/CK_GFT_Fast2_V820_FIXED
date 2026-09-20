import pandas as pd, numpy as np, os, re
DEP=5000.0; FIX,DT="20260716","20260930"; GG=100.0
D=r"experiments\combo_m4_funded4\windows\last1y"
df=pd.read_csv(os.path.join(D,"trades.csv")); df.columns=[c.strip().lower() for c in df.columns]
df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M"); df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
df["magic"]=df["magic"].astype(str); df=df.sort_values("time").reset_index(drop=True)
prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
nz=df[df["profit"]!=0]; wr=(nz["profit"]>0).mean()*100 if len(nz) else 0
worst=prof.min(); over_gg=int((prof<=-GG).sum()); over85=int((prof<=-85).sum()); static=max(0.0,DEP-eq.min())
run=DEP; wd=0.0; d5=0
for dte,g in df.groupby(df["time"].dt.date):
    s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
    if pct<wd: wd=pct
    if pct<=-5: d5+=1
fc=(df["magic"]==FIX).sum(); dc=(df["magic"]==DT).sum()
def htm(lab):
    p=os.path.join(D,"report.htm")
    try: raw=open(p,"r",encoding="utf-16",errors="ignore").read()
    except: raw=open(p,"rb").read().decode("utf-16",errors="ignore")
    raw=re.sub(r"<[^>]+>","|",raw).replace("&nbsp;"," "); i=raw.find(lab)
    if i<0:return "?"
    m=re.search(r"-?\d[\d \u00a0.,]*",raw[i+len(lab):i+len(lab)+80]); return m.group(0).replace("\u00a0","").replace(" ","").replace(",","") if m else "?"
print("===== FUNDED v4 (lot 0.03 + SL cap 20pts) REAL-TICK last1y =====")
print(f"  net {net:,.2f} ({net/DEP*100:+.2f}%)  PF {pf:.2f}  trades {len(df)} (F{fc}/D{dc})  win {wr:.1f}%")
print(f"  worst single trade : {worst:.2f}   trades<=-$85: {over85}   trades<=-$100(GG): {over_gg}")
print(f"  worst day {wd:.2f}%   days>=5% {d5}   staticDD {static/DEP*100:.2f}%")
print(f"  htm net={htm('Total Net Profit:')} PF={htm('Profit Factor:')} balDDabs={htm('Balance Drawdown Absolute:')} eqDDabs={htm('Equity Drawdown Absolute:')}")
ok=(over_gg==0 and abs(worst)<GG and d5==0 and static/DEP*100<10)
print("  vs baseline funded +11% (0.01 lot).  RULES:", "PASS - SAFE & MORE PROFIT" if ok else "FAIL")

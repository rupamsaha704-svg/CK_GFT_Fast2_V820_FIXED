import pandas as pd, numpy as np, re, os, sys
DEP=5000.0; FIX,DT="20260716","20260930"
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root (this file lives in tools/)
# window dir to check: optional CLI arg (absolute, or relative to repo root); default = shipped funded run
_arg=sys.argv[1] if len(sys.argv)>1 else r"experiments\combo_funded\windows\last1y"
D=_arg if os.path.isabs(_arg) else os.path.join(ROOT,_arg)
GG=DEP*0.02   # Goat Guard = 2% of initial = $100
FLAT=DEP*0.015 # our flatten buffer = 1.5% = $75
_tcsv=os.path.join(D,"trades.csv")
if not os.path.exists(_tcsv): sys.exit(f"[funded_check] trades.csv not found: {_tcsv}\n  usage: python tools/funded_check.py [window_dir]   (path absolute or relative to repo root)")
df=pd.read_csv(_tcsv); df.columns=[c.strip().lower() for c in df.columns]
df["time"]=pd.to_datetime(df["time"],format="%Y.%m.%d %H:%M"); df["profit"]=pd.to_numeric(df["profit"],errors="coerce").fillna(0.0)
df["magic"]=df["magic"].astype(str); df=df.sort_values("time").reset_index(drop=True)
prof=df["profit"].values; eq=np.concatenate([[DEP],DEP+np.cumsum(prof)])
net=prof.sum(); gp=prof[prof>0].sum(); gl=prof[prof<0].sum(); pf=gp/abs(gl) if gl!=0 else 9.99
nz=df[df["profit"]!=0]; wr=(nz["profit"]>0).mean()*100 if len(nz) else 0
worst_trade=prof.min(); over_gg=int((prof<=-GG).sum()); over_flat=int((prof<=-FLAT).sum())
static=max(0.0,DEP-eq.min())
run=DEP; worstday=0.0; d5=0
for dte,g in df.groupby(df["time"].dt.date):
    s=run; pl=g["profit"].sum(); run+=pl; pct=pl/s*100
    if pct<worstday: worstday=pct
    if pct<=-5: d5+=1
fn=df[df["magic"]==FIX]["profit"].sum(); dn=df[df["magic"]==DT]["profit"].sum()
fc=(df["magic"]==FIX).sum(); dc=(df["magic"]==DT).sum()
print("===== FUNDED MODE (Combo_Stage=1) — last1y M15 =====")
print(f"  net            : {net:,.2f} ({net/DEP*100:+.2f}%)   PF {pf:.2f}   trades {len(df)} (F{fc}/D{dc})  win {wr:.1f}%")
print(f"  worst 1 trade  : {worst_trade:,.2f}   [Goat Guard limit -{GG:.0f} (2% of init); flatten -{FLAT:.0f}]")
print(f"  trades <= -$100 (>=Goat Guard 2%) : {over_gg}   <= -$75 (flatten) : {over_flat}")
print(f"  worst day      : {worstday:.2f}%   days>=5% : {d5}")
print(f"  static DD      : {static:,.2f} ({static/DEP*100:.2f}%)")
print(f"  FIX09/DTREND $ : {fn:,.2f} / {dn:,.2f}")
def htm(lab):
    p=os.path.join(D,"report.htm")
    if not os.path.exists(p): return "?"
    try: raw=open(p,"r",encoding="utf-16",errors="ignore").read()
    except: raw=open(p,"rb").read().decode("utf-16",errors="ignore")
    raw=re.sub(r"<[^>]+>","|",raw).replace("&nbsp;"," "); i=raw.find(lab)
    if i<0:return "?"
    m=re.search(r"-?\d[\d \u00a0.,]*",raw[i+len(lab):i+len(lab)+80]); return m.group(0).replace("\u00a0","").replace(" ","").replace(",","") if m else "?"
print("  MT5 htm: net=%s PF=%s balDDabs=%s eqDDabs=%s"%(htm("Total Net Profit:"),htm("Profit Factor:"),htm("Balance Drawdown Absolute:"),htm("Equity Drawdown Absolute:")))
gg_ok = (over_gg==0 and abs(worst_trade)<GG)
print("\n  GOAT-GUARD SAFE (no closed trade reached -2% of initial):", "YES" if gg_ok else "REVIEW")
print("  daily-rule (0 days>=5%):", "YES" if d5==0 else "NO")
print("  static (<10%):", "YES" if static/DEP*100<10 else "NO")

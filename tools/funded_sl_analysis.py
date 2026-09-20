import pandas as pd, numpy as np, os
FIX,DT="20260716","20260930"
DEALS=os.path.join(os.environ["APPDATA"],"MetaQuotes","Terminal","Common","Files","ck_gold_combo_deals.csv")
if not os.path.exists(DEALS):
    print("deals CSV not found:",DEALS); raise SystemExit
d=pd.read_csv(DEALS); d.columns=[c.strip().lower() for c in d.columns]
for c in ["entry_price","exit_price","profit"]: d[c]=pd.to_numeric(d[c],errors="coerce")
d["magic"]=d["magic"].astype(str)
d["sl_points"]=(d["entry_price"]-d["exit_price"]).abs()   # price distance entry->exit (for SL-losers ~ SL width)
d["who"]=d["magic"].map({FIX:"FIX09",DT:"DTREND"}).fillna(d["magic"])
print("deals file (from LAST run = 0.03-lot sweep):", len(d), "trades")
print("\n--- SL-distance (points) of LOSERS, by strategy ---")
for who in ["FIX09","DTREND"]:
    L=d[(d["who"]==who)&(d["profit"]<0)]
    if len(L)==0: print(f"  {who}: no losers"); continue
    print(f"  {who}: losers={len(L)}  avg SL={L['sl_points'].mean():.1f} pts  max SL={L['sl_points'].max():.1f} pts  worst $={L['profit'].min():.2f}  avg loss=${L['profit'].mean():.2f}")
print("\n--- WORST 12 losing trades (any strategy) ---")
w=d[d["profit"]<0].sort_values("profit").head(12)
for _,r in w.iterrows():
    print(f"  {r['who']:6s} {r['dir']:4s}  entry {r['entry_price']:.2f} -> exit {r['exit_price']:.2f}  SL={r['sl_points']:.1f} pts  loss ${r['profit']:.2f}")
# how big is a normal winner's move vs loser SL?
print("\n--- avg WIN move vs avg LOSS SL (points) ---")
for who in ["FIX09","DTREND"]:
    W=d[(d["who"]==who)&(d["profit"]>0)]; L=d[(d["who"]==who)&(d["profit"]<0)]
    if len(W) and len(L):
        print(f"  {who}: avg win move {W['sl_points'].mean():.1f} pts / avg loss SL {L['sl_points'].mean():.1f} pts")

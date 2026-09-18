import pandas as pd, numpy as np, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

DEP = 5000.0
F09 = r"experiments\fix09_1y\windows\last1y\trades.csv"
DTR = r"experiments\dtrend_bal\windows\full\trades.csv"

def load(p):
    df = pd.read_csv(p)
    df.columns = [c.strip().lower() for c in df.columns]
    df["time"] = pd.to_datetime(df["time"], format="%Y.%m.%d %H:%M")
    df["profit"] = pd.to_numeric(df["profit"], errors="coerce").fillna(0.0)
    return df[["time","profit"]].sort_values("time").reset_index(drop=True)

f = load(F09); f["src"]="FIX09"
d = load(DTR); d["src"]="DTREND"

def stats(df, label):
    df = df.sort_values("time").reset_index(drop=True)
    eq = DEP + df["profit"].cumsum()
    eq_full = pd.concat([pd.Series([DEP]), eq], ignore_index=True)
    net = df["profit"].sum()
    wins = df.loc[df["profit"]>0,"profit"].sum()
    loss = df.loc[df["profit"]<0,"profit"].sum()
    pf = wins/abs(loss) if loss!=0 else float("inf")
    nz = df[df["profit"]!=0]
    wr = (nz["profit"]>0).mean()*100 if len(nz) else 0
    # STATIC DD = worst dip below initial deposit (GFT rule), closed-trade approx
    min_eq = eq_full.min()
    static_dd_abs = max(0.0, DEP - min_eq)
    static_dd_pct = static_dd_abs/DEP*100
    # trailing peak-to-trough
    peak = eq_full.cummax()
    dd = (peak - eq_full)
    trail_pct = (dd/peak).max()*100
    # worst single calendar-day realized loss (daily 5% rule approx)
    by_day = df.groupby(df["time"].dt.date)["profit"].sum()
    worst_day = by_day.min()
    # worst day as % of running equity at that day's start
    day_eq = {}
    run = DEP
    worst_day_pct = 0.0
    for dte, grp in df.groupby(df["time"].dt.date):
        start_eq = run
        day_pl = grp["profit"].sum()
        run += day_pl
        if day_pl < 0:
            worst_day_pct = min(worst_day_pct, day_pl/start_eq*100)
    print(f"--- {label} ---")
    print(f"  trades(nonzero) : {len(nz)}  (rows {len(df)})")
    print(f"  net             : {net:,.2f}  ({net/DEP*100:+.2f}%)")
    print(f"  end equity      : {DEP+net:,.2f}")
    print(f"  PF              : {pf:.2f}")
    print(f"  win_rate        : {wr:.1f}%")
    print(f"  STATIC DD (<5k) : {static_dd_abs:,.2f}  ({static_dd_pct:.2f}%)  [GFT limit 10%]")
    print(f"  trailing DD     : {trail_pct:.2f}%")
    print(f"  worst day $     : {worst_day:,.2f}")
    print(f"  worst day %     : {worst_day_pct:.2f}%  [GFT daily limit 5%]")
    return dict(label=label, eq=eq_full, times=[df["time"].iloc[0]-pd.Timedelta(minutes=1)]+list(df["time"]),
                net=net, pf=pf, wr=wr, static_pct=static_dd_pct, static_abs=static_dd_abs,
                trail=trail_pct, worst_day_pct=worst_day_pct, min_eq=min_eq)

print("="*60)
print("STANDALONE (last 1yr 2025.09.02-2026.09.02, Model-1 fast)")
print("="*60)
sf = stats(f, "FIX09 alone (fixed 0.09)")
sd = stats(d, "DTREND balanced alone")

# COMBINED: one $5000 account, both EAs, merged by close time
c = pd.concat([f,d], ignore_index=True).sort_values("time").reset_index(drop=True)
print("="*60)
print("COMBINED  (FIX09 + DTREND on ONE $5000 account)")
print("="*60)
sc = stats(c, "COMBINED")

# also monthly combined P&L
c["ym"] = c["time"].dt.to_period("M")
monthly = c.groupby("ym")["profit"].sum()
print("\nCOMBINED monthly P&L:")
for k,v in monthly.items():
    print(f"  {k}: {v:+,.2f}")

# ---- chart ----
fig, ax = plt.subplots(2,1, figsize=(13,9), gridspec_kw={"height_ratios":[3,1]})
for s,color in [(sd,"#1f77b4"),(sf,"#ff7f0e"),(sc,"#2ca02c")]:
    ax[0].plot(s["times"], s["eq"].values, label=f"{s['label']}  end ${DEP+s['net']:,.0f} ({s['net']/DEP*100:+.0f}%)",
               color=color, linewidth=1.6 if s is sc else 1.1)
ax[0].axhline(DEP, color="gray", ls="--", lw=0.8)
ax[0].axhline(DEP*0.9, color="red", ls=":", lw=1.0, label="10% static breach ($4500)")
ax[0].set_title("FIX09 + DTREND combined on one $5,000 account — last 1 year (Model-1 fast)")
ax[0].set_ylabel("Equity ($)"); ax[0].legend(loc="upper left", fontsize=8); ax[0].grid(alpha=0.25)
ax[0].xaxis.set_major_formatter(mdates.DateFormatter("%b'%y"))

# combined underwater (below initial)
eqc = sc["eq"].values
below = np.minimum(0, eqc-DEP)
ax[1].fill_between(sc["times"], below, 0, color="red", alpha=0.4)
ax[1].axhline(-DEP*0.10, color="red", ls=":", lw=1.0, label="-10% static limit")
ax[1].set_ylabel("Below start ($)"); ax[1].legend(loc="lower left", fontsize=8); ax[1].grid(alpha=0.25)
ax[1].xaxis.set_major_formatter(mdates.DateFormatter("%b'%y"))
plt.tight_layout()
out = os.path.join(os.path.expanduser("~"),"Desktop","gold_chop_charts","combined_fix09_dtrend.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
plt.savefig(out, dpi=110)
print("\nsaved:", out)

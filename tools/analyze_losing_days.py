import pandas as pd, numpy as np, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

DEP = 5000.0
CSV = r"experiments\combo_1y\windows\last1y\trades.csv"
M1  = r"experiments\dump_m1\xau_m1.csv"
OUT = os.path.join(os.path.expanduser("~"), "Desktop", "gold_chop_charts")
os.makedirs(OUT, exist_ok=True)
FIX, DT = "20260716", "20260930"

df = pd.read_csv(CSV)
df.columns = [c.strip().lower() for c in df.columns]
df["time"] = pd.to_datetime(df["time"], format="%Y.%m.%d %H:%M")
df["profit"] = pd.to_numeric(df["profit"], errors="coerce").fillna(0.0)
df["magic"] = df["magic"].astype(str)
df["date"] = df["time"].dt.date
df["hour"] = df["time"].dt.hour
df = df.sort_values("time").reset_index(drop=True)

# ---- per-day P&L with running equity ----
rows = []
run = DEP
for dte, g in df.groupby("date"):
    start = run
    pl = g["profit"].sum()
    fpl = g[g["magic"]==FIX]["profit"].sum()
    dpl = g[g["magic"]==DT]["profit"].sum()
    run += pl
    rows.append((dte, pl, fpl, dpl, start, pl/start*100))
day = pd.DataFrame(rows, columns=["date","pl","fix","dt","eq_start","pct"])

nloss = (day["pl"]<0).sum(); nwin=(day["pl"]>0).sum()
b1=((day["pct"]<=-1)&(day["pct"]>-2)).sum()
b2=((day["pct"]<=-2)&(day["pct"]>-3)).sum()
b3=((day["pct"]<=-3)&(day["pct"]>-5)).sum()
b5=(day["pct"]<=-5).sum()
print(f"total trading days : {len(day)}   win {nwin} / loss {nloss}")
print(f"loss buckets: -1..-2%={b1}  -2..-3%={b2}  -3..-5%={b3}  <=-5%={b5}")
print("\nWORST 12 DAYS (by % of that day's start equity):")
worst = day.sort_values("pct").head(12)
for _,r in worst.iterrows():
    who = "FIX09" if r["fix"]<r["dt"] else "DTREND"
    print(f"  {r['date']}  {r['pct']:6.2f}%  ${r['pl']:8.2f}  (FIX09 ${r['fix']:7.2f} / DTREND ${r['dt']:7.2f})  main={who}")

# who causes the losing days overall
lossdays = day[day["pl"]<0]
print(f"\nOn LOSING days: FIX09 total ${lossdays['fix'].sum():,.0f}  DTREND total ${lossdays['dt'].sum():,.0f}")

# ---- hour-of-day (close hour) ----
hr = df.groupby("hour").agg(total=("profit","sum"),
                            fix=("profit", lambda s: s[df.loc[s.index,"magic"]==FIX].sum()),
                            n=("profit","size")).reset_index()
hr["dt"] = hr["total"] - hr["fix"]
print("\nHOUR-of-day (trade CLOSE hour, server time) P&L:")
for _,r in hr.iterrows():
    print(f"  {int(r['hour']):02d}:00  ${r['total']:8.2f}  (FIX09 ${r['fix']:7.0f}/DTREND ${r['dt']:7.0f})  n={int(r['n'])}")
worst_hours = hr.sort_values("total").head(5)["hour"].tolist()
print("worst hours:", [f"{int(h):02d}:00" for h in worst_hours])

# =================== CHART 1: losing days ===================
fig, ax = plt.subplots(2,1, figsize=(13,8), gridspec_kw={"height_ratios":[2,1]})
d = pd.to_datetime(day["date"])
colors = ["#2ca02c" if x>=0 else "#d62728" for x in day["pl"]]
ax[0].bar(d, day["pl"], color=colors, width=1.0)
for _,r in worst.head(6).iterrows():
    ax[0].annotate(f"{r['pct']:.1f}%", (pd.to_datetime(r['date']), r['pl']),
                   fontsize=7, ha="center", va="top", color="darkred")
ax[0].axhline(0, color="black", lw=0.6)
ax[0].axhline(-DEP*0.05, color="red", ls=":", lw=1.0, label="approx -5% day zone (early)")
ax[0].set_title(f"Combined daily P&L  |  {len(day)} trading days: {nwin} win / {nloss} loss  |  days <=-3%: {b3+b5}")
ax[0].set_ylabel("Day P&L ($)"); ax[0].legend(fontsize=8); ax[0].grid(alpha=0.2, axis="y")
ax[0].xaxis.set_major_formatter(mdates.DateFormatter("%b'%y"))
# bucket bar
labels=["-1..-2%","-2..-3%","-3..-5%","<=-5%"]; vals=[b1,b2,b3,b5]
ax[1].bar(labels, vals, color=["#ffb14e","#fa8c1a","#e8590c","#c5221f"])
for i,v in enumerate(vals): ax[1].text(i, v, str(v), ha="center", va="bottom", fontsize=9)
ax[1].set_title("How many days fell each loss bucket"); ax[1].set_ylabel("# days")
plt.tight_layout(); p1=os.path.join(OUT,"combo_losing_days.png"); plt.savefig(p1,dpi=115); plt.close()

# =================== CHART 2: hour-of-day ===================
fig, ax = plt.subplots(figsize=(13,6))
x=hr["hour"].values
ax.bar(x-0.2, hr["fix"], width=0.4, label="FIX09", color="#ff7f0e")
ax.bar(x+0.2, hr["dt"],  width=0.4, label="DTREND", color="#1f77b4")
ax.plot(x, hr["total"], color="black", lw=1.2, marker="o", ms=3, label="net/hour")
ax.axhline(0, color="black", lw=0.6)
ax.set_xticks(range(0,24)); ax.set_xlabel("Hour of trade CLOSE (server/broker time)")
ax.set_ylabel("P&L ($)"); ax.set_title("Which HOUR bleeds? Combined P&L by close-hour (FIX09 vs DTREND)")
ax.legend(); ax.grid(alpha=0.2, axis="y")
plt.tight_layout(); p2=os.path.join(OUT,"combo_hour_pnl.png"); plt.savefig(p2,dpi=115); plt.close()

# =================== CHART 3: worst day price zoom ===================
worst_day = worst.iloc[0]["date"]
p3=None
try:
    m1 = pd.read_csv(M1)
    m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M")
    dd = m1[m1["time"].dt.date==worst_day].copy()
    if len(dd)>10:
        fig, ax = plt.subplots(figsize=(13,6))
        ax.plot(dd["time"], dd["close"], color="#333", lw=0.9)
        ax.fill_between(dd["time"], dd["low"], dd["high"], color="gray", alpha=0.15)
        # mark exits that day
        ex = df[df["date"]==worst_day]
        for _,r in ex.iterrows():
            near = dd.iloc[(dd["time"]-r["time"]).abs().argmin()]
            col = "green" if r["profit"]>0 else ("red" if r["profit"]<0 else "gray")
            ax.scatter([r["time"]],[near["close"]], color=col, s=70, zorder=5, edgecolor="black")
            ax.annotate(f"${r['profit']:.0f}", (r["time"], near["close"]), fontsize=8, xytext=(0,8), textcoords="offset points", ha="center")
        hi=dd["high"].max(); lo=dd["low"].min()
        ax.axhline(hi, color="red", ls=":", lw=0.8); ax.axhline(lo, color="blue", ls=":", lw=0.8)
        rng=(hi-lo); rngpct=rng/dd["close"].iloc[0]*100
        ax.set_title(f"WORST DAY {worst_day}: {worst_day} intraday XAUUSD (M1)  range ${rng:.0f} ({rngpct:.1f}%)  |  markers=trade exits")
        ax.set_ylabel("Price"); ax.grid(alpha=0.2)
        ax.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M"))
        plt.tight_layout(); p3=os.path.join(OUT,"combo_worstday_zoom.png"); plt.savefig(p3,dpi=115); plt.close()
        print(f"\nworst day {worst_day}: intraday range ${rng:.0f} ({rngpct:.1f}%), {len(ex)} exits")
    else:
        print(f"\nworst day {worst_day}: not enough M1 data (dump starts 2026.02.02)")
except Exception as e:
    print("zoom err", e)

print("\nsaved:", p1); print("saved:", p2); print("saved:", p3)

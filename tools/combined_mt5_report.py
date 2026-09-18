import pandas as pd, numpy as np, os, math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.gridspec as gridspec

DEP = 5000.0
F09 = r"experiments\fix09_1y\windows\last1y\trades.csv"
DTR = r"experiments\dtrend_bal\windows\full\trades.csv"
OUTDIR = os.path.join(os.path.expanduser("~"), "Desktop", "gold_chop_charts")
os.makedirs(OUTDIR, exist_ok=True)

def load(p, src):
    df = pd.read_csv(p)
    df.columns = [c.strip().lower() for c in df.columns]
    df["time"] = pd.to_datetime(df["time"], format="%Y.%m.%d %H:%M")
    df["profit"] = pd.to_numeric(df["profit"], errors="coerce").fillna(0.0)
    df["src"] = src
    return df[["time", "profit", "src"]]

f = load(F09, "FIX09")
d = load(DTR, "DTREND")
c = pd.concat([f, d], ignore_index=True).sort_values("time").reset_index(drop=True)

prof = c["profit"].values
eq = DEP + np.cumsum(prof)
eq_full = np.concatenate([[DEP], eq])
times = [c["time"].iloc[0] - pd.Timedelta(minutes=1)] + list(c["time"])

# ---- MT5-style metrics ----
n_total = len(c)
net = prof.sum()
gp = prof[prof > 0].sum()
gl = prof[prof < 0].sum()
pf = gp / abs(gl) if gl != 0 else float("inf")
exp_payoff = net / n_total if n_total else 0
n_win = int((prof > 0).sum())
n_loss = int((prof < 0).sum())
n_be = int((prof == 0).sum())
win_pct = n_win / n_total * 100
loss_pct = n_loss / n_total * 100
largest_win = prof.max()
largest_loss = prof.min()
avg_win = prof[prof > 0].mean() if n_win else 0
avg_loss = prof[prof < 0].mean() if n_loss else 0

# drawdown (MT5)
peak = np.maximum.accumulate(eq_full)
dd_money = peak - eq_full
dd_pct = dd_money / peak * 100
maxdd_money = dd_money.max()
maxdd_money_pct = dd_pct[dd_money.argmax()] * 1  # % at the money-max point
maxdd_pct = dd_pct.max()
min_eq = eq_full.min()
abs_dd = max(0.0, DEP - min_eq)  # Balance Drawdown Absolute (below initial)
recovery = net / maxdd_money if maxdd_money > 0 else float("inf")
sharpe = prof.mean() / prof.std(ddof=1) if prof.std(ddof=1) > 0 else 0

# consecutive streaks
def streaks(arr, positive=True):
    best_cnt = 0; best_cnt_sum = 0.0
    best_sum = 0.0; best_sum_cnt = 0
    cur_cnt = 0; cur_sum = 0.0
    for p in arr:
        hit = (p > 0) if positive else (p < 0)
        if hit:
            cur_cnt += 1; cur_sum += p
            if cur_cnt > best_cnt:
                best_cnt = cur_cnt; best_cnt_sum = cur_sum
            if (cur_sum > best_sum) if positive else (cur_sum < best_sum):
                best_sum = cur_sum; best_sum_cnt = cur_cnt
        else:
            cur_cnt = 0; cur_sum = 0.0
    return best_cnt, best_cnt_sum, best_sum, best_sum_cnt

mcw_cnt, mcw_cnt_sum, mcw_sum, mcw_sum_cnt = streaks(prof, True)
mcl_cnt, mcl_cnt_sum, mcl_sum, mcl_sum_cnt = streaks(prof, False)

# per-source split
def src_net(s): 
    sub = c[c["src"] == s]["profit"]
    return sub.sum(), len(sub), int((sub > 0).sum())
f_net, f_n, f_w = src_net("FIX09")
d_net, d_n, d_w = src_net("DTREND")

# worst day (daily rule)
run = DEP; worst_day_pct = 0.0; worst_day_money = 0.0; worst_day_date = None
for dte, grp in c.groupby(c["time"].dt.date):
    start = run; pl = grp["profit"].sum(); run += pl
    if pl < worst_day_money:
        worst_day_money = pl
    if pl < 0 and pl / start * 100 < worst_day_pct:
        worst_day_pct = pl / start * 100; worst_day_date = dte

# monthly
c["ym"] = c["time"].dt.to_period("M")
monthly = c.groupby("ym")["profit"].sum()

bars_from = c["time"].min(); bars_to = c["time"].max()

# ================= HTML REPORT (MT5 style) =================
def money(x): return f"{x:,.2f}"
rows = [
    ("Symbol", "XAUUSD"), ("Period", "M1 merged (Model-1 fast, control points)"),
    ("Dates", f"{bars_from:%Y.%m.%d} - {bars_to:%Y.%m.%d}"),
    ("Strategy", "COMBINED: CK_GOLD_PRO_FIX09 (fixed 0.09) + CK_GOLD_DTREND (balanced) on ONE account"),
    ("Initial Deposit", money(DEP)),
    ("Total Net Profit", money(net) + f"  ({net/DEP*100:+.2f}%)"),
    ("Gross Profit", money(gp)), ("Gross Loss", money(gl)),
    ("Profit Factor", f"{pf:.2f}"), ("Expected Payoff", money(exp_payoff)),
    ("Recovery Factor", f"{recovery:.2f}"), ("Sharpe Ratio (per-trade)", f"{sharpe:.2f}"),
    ("Balance Drawdown Absolute (below start)", money(abs_dd) + f"  ({abs_dd/DEP*100:.2f}%)  [GFT static limit 10%]"),
    ("Balance Drawdown Maximal (peak-to-trough)", money(maxdd_money) + f"  ({maxdd_pct:.2f}%)"),
    ("Worst single day", money(worst_day_money) + f"  ({worst_day_pct:.2f}%)  on {worst_day_date}  [GFT daily limit 5%]"),
    ("Total Trades", str(n_total)),
    ("Profit Trades", f"{n_win}  ({win_pct:.2f}%)"), ("Loss Trades", f"{n_loss}  ({loss_pct:.2f}%)"),
    ("Break-even Trades", str(n_be)),
    ("Largest profit trade", money(largest_win)), ("Largest loss trade", money(largest_loss)),
    ("Average profit trade", money(avg_win)), ("Average loss trade", money(avg_loss)),
    ("Max consecutive wins", f"{mcw_cnt}  ({money(mcw_cnt_sum)})"),
    ("Max consecutive losses", f"{mcl_cnt}  ({money(mcl_cnt_sum)})"),
    ("Maximal consecutive profit", f"{money(mcw_sum)}  ({mcw_sum_cnt} trades)"),
    ("Maximal consecutive loss", f"{money(mcl_sum)}  ({mcl_sum_cnt} trades)"),
    ("FIX09 contribution", f"{money(f_net)}  ({f_n} trades, {f_w} wins)"),
    ("DTREND contribution", f"{money(d_net)}  ({d_n} trades, {d_w} wins)"),
]
html = ["<html><head><meta charset='utf-8'><title>COMBINED MT5 Report</title>",
        "<style>body{font-family:Tahoma,Arial;font-size:13px;background:#f4f4f0;color:#111;margin:18px}",
        "h2{background:#4a4a4a;color:#fff;padding:8px 12px;margin:18px 0 0}",
        "table{border-collapse:collapse;width:100%;background:#fff}",
        "td,th{border:1px solid #ccc;padding:5px 9px}",
        "th{background:#e6e6df;text-align:left}",
        "tr:nth-child(even){background:#faf9f4}",
        ".pos{color:#137333;font-weight:bold}.neg{color:#c5221f;font-weight:bold}",
        "td.r{text-align:right;font-variant-numeric:tabular-nums}</style></head><body>",
        "<h2>Strategy Tester Report &mdash; COMBINED (FIX09 + DTREND)</h2><table>"]
for k, v in rows:
    cls = ""
    if k in ("Total Net Profit",) : cls = "pos" if net>=0 else "neg"
    html.append(f"<tr><th style='width:340px'>{k}</th><td class='{cls}'>{v}</td></tr>")
html.append("</table>")

# monthly table
html.append("<h2>Monthly Profit / Loss</h2><table><tr><th>Month</th><th>Net P/L</th><th>Cumulative</th></tr>")
cum = DEP
for k, v in monthly.items():
    cum += v
    cls = "pos" if v >= 0 else "neg"
    html.append(f"<tr><td>{k}</td><td class='r {cls}'>{money(v)}</td><td class='r'>{money(cum)}</td></tr>")
html.append("</table>")

# full trade list
html.append(f"<h2>All Trades ({n_total})</h2><table><tr><th>#</th><th>Close Time</th><th>Source</th><th>Profit</th><th>Equity</th></tr>")
for i, (_, r) in enumerate(c.iterrows(), 1):
    p = r["profit"]; e = DEP + prof[:i].sum()
    cls = "pos" if p > 0 else ("neg" if p < 0 else "")
    html.append(f"<tr><td>{i}</td><td>{r['time']:%Y.%m.%d %H:%M}</td><td>{r['src']}</td>"
                f"<td class='r {cls}'>{money(p)}</td><td class='r'>{money(e)}</td></tr>")
html.append("</table></body></html>")
rep = os.path.join(OUTDIR, "combined_MT5_report.html")
open(rep, "w", encoding="utf-8").write("\n".join(html))

# ================= DASHBOARD PNG (MT5 tester look) =================
fig = plt.figure(figsize=(14, 11))
gs = gridspec.GridSpec(3, 2, height_ratios=[3, 1.3, 1.6], hspace=0.32, wspace=0.18)

# equity curve
ax1 = fig.add_subplot(gs[0, :])
ax1.plot(times, eq_full, color="#2ca02c", lw=1.5, label="Combined equity")
ax1.plot(times, peak, color="#7fbf7f", lw=0.7, ls="--", label="Peak")
ax1.axhline(DEP, color="gray", ls="--", lw=0.9, label="Initial $5,000")
ax1.axhline(DEP*0.9, color="red", ls=":", lw=1.0, label="10% static breach $4,500")
imax = int(np.argmax(eq_full)); imin_dd = int(dd_money.argmax())
ax1.scatter([times[imax]], [eq_full[imax]], color="green", zorder=5, s=25)
ax1.annotate(f"peak ${eq_full[imax]:,.0f}", (times[imax], eq_full[imax]), fontsize=8,
             xytext=(0, 8), textcoords="offset points")
ax1.set_title(f"COMBINED Backtest  |  Net {net/DEP*100:+.1f}%  ${net:,.0f}  |  PF {pf:.2f}  |  {n_total} trades  |  static DD {abs_dd/DEP*100:.1f}%",
              fontsize=12, fontweight="bold")
ax1.set_ylabel("Equity ($)"); ax1.grid(alpha=0.25); ax1.legend(loc="upper left", fontsize=8)
ax1.xaxis.set_major_formatter(mdates.DateFormatter("%b'%y"))

# underwater
ax2 = fig.add_subplot(gs[1, :])
ax2.fill_between(times, -(dd_pct), 0, color="#d62728", alpha=0.45)
ax2.axhline(-10, color="red", ls=":", lw=1.0, label="-10% static limit")
ax2.set_ylabel("Drawdown %"); ax2.grid(alpha=0.25); ax2.legend(loc="lower left", fontsize=8)
ax2.xaxis.set_major_formatter(mdates.DateFormatter("%b'%y"))
ax2.set_title("Drawdown from peak (%)", fontsize=10)

# monthly bars
ax3 = fig.add_subplot(gs[2, 0])
mlabels = [str(k) for k in monthly.index]
mcolors = ["#2ca02c" if v >= 0 else "#d62728" for v in monthly.values]
ax3.bar(range(len(monthly)), monthly.values, color=mcolors)
ax3.set_xticks(range(len(monthly))); ax3.set_xticklabels(mlabels, rotation=60, fontsize=7, ha="right")
ax3.axhline(0, color="black", lw=0.6); ax3.set_ylabel("Monthly P/L $"); ax3.grid(alpha=0.2, axis="y")
ax3.set_title("Monthly P/L", fontsize=10)

# stats box
ax4 = fig.add_subplot(gs[2, 1]); ax4.axis("off")
txt = (f"Total Net Profit   : ${net:,.2f}  ({net/DEP*100:+.2f}%)\n"
       f"Gross Profit/Loss  : ${gp:,.0f} / ${gl:,.0f}\n"
       f"Profit Factor      : {pf:.2f}\n"
       f"Expected Payoff    : ${exp_payoff:,.2f}\n"
       f"Recovery Factor    : {recovery:.2f}\n"
       f"Sharpe (per-trade) : {sharpe:.2f}\n"
       f"Total Trades       : {n_total}\n"
       f"Win / Loss / BE    : {n_win} / {n_loss} / {n_be}\n"
       f"Win rate           : {win_pct:.1f}%\n"
       f"Largest win/loss   : ${largest_win:,.0f} / ${largest_loss:,.0f}\n"
       f"Avg win/loss       : ${avg_win:,.0f} / ${avg_loss:,.0f}\n"
       f"Max cons. wins     : {mcw_cnt}  (${mcw_cnt_sum:,.0f})\n"
       f"Max cons. losses   : {mcl_cnt}  (${mcl_cnt_sum:,.0f})\n"
       f"Static DD (<$5000) : {abs_dd/DEP*100:.2f}%   [limit 10%]\n"
       f"Max DD peak->trough: {maxdd_pct:.2f}%\n"
       f"Worst day          : {worst_day_pct:.2f}%   [limit 5%]\n"
       f"FIX09 / DTREND net : ${f_net:,.0f} / ${d_net:,.0f}")
ax4.text(0, 1, txt, family="monospace", fontsize=9.2, va="top")
ax4.set_title("Statistics", fontsize=10, loc="left")

png = os.path.join(OUTDIR, "combined_MT5_dashboard.png")
plt.savefig(png, dpi=115, bbox_inches="tight")

print("net", round(net,2), "pf", round(pf,2), "trades", n_total, "win%", round(win_pct,1))
print("staticDD%", round(abs_dd/DEP*100,2), "maxDD%", round(maxdd_pct,2), "worstday%", round(worst_day_pct,2))
print("saved_html", rep)
print("saved_png", png)

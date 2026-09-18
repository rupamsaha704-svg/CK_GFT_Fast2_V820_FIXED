"""
loss_visualizer.py  --  "show me where the losses happen" agent engine.

Reads the enriched combo deals CSV (entry+exit paired) + M1 price, and for each
LOSING trade draws the actual price chart around it:
  - candlesticks (M15 by default)
  - ENTRY marker + price line
  - EXIT / SL marker + price line (for SL-losers exit price = where SL hit)
  - shaded hold window
  - MAE (worst adverse move) annotation
  - STOP-HUNT flag: did price reverse to our intended side AFTER the SL hit?
    (= evidence the entry was too early / we got wicked out)

Outputs one PNG per losing trade + a gallery.html + a summary table.

Usage:
  python tools\\loss_visualizer.py [--tf 15] [--top 24] [--deals <path>]
"""
import pandas as pd, numpy as np, os, sys, argparse
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

ap = argparse.ArgumentParser()
ap.add_argument("--tf", type=int, default=15, help="candle timeframe in minutes (default 15)")
ap.add_argument("--top", type=int, default=24, help="how many worst losers to draw (0 = all in range)")
ap.add_argument("--deals", default=None)
ap.add_argument("--m1", default=r"experiments\dump_m1\xau_m1.csv")
ap.add_argument("--pre", type=int, default=14, help="candles of context before entry")
ap.add_argument("--post", type=int, default=10, help="candles after exit")
args = ap.parse_args()

DEALS = args.deals or os.path.join(os.environ.get("APPDATA",""), "MetaQuotes","Terminal","Common","Files","ck_gold_combo_deals.csv")
OUT = os.path.join(os.path.expanduser("~"), "Desktop", "gold_chop_charts", "losses")
os.makedirs(OUT, exist_ok=True)
FIXM, DTM = "20260716", "20260930"

if not os.path.exists(DEALS):
    print("DEALS CSV not found:", DEALS); sys.exit(1)

d = pd.read_csv(DEALS)
d.columns = [c.strip().lower() for c in d.columns]
for c in ["entry_time","exit_time"]:
    d[c] = pd.to_datetime(d[c], format="%Y.%m.%d %H:%M", errors="coerce")
for c in ["entry_price","exit_price","profit"]:
    d[c] = pd.to_numeric(d[c], errors="coerce")
d["magic"] = d["magic"].astype(str)
d = d.dropna(subset=["entry_time","exit_time","entry_price","exit_price"])

# M1 -> chosen TF candles
m1 = pd.read_csv(args.m1)
m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M")
m1 = m1.set_index("time").sort_index()
rule = f"{args.tf}min"
c = pd.DataFrame({
    "open":  m1["open"].resample(rule).first(),
    "high":  m1["high"].resample(rule).max(),
    "low":   m1["low"].resample(rule).min(),
    "close": m1["close"].resample(rule).last(),
}).dropna()
c = c.reset_index()   # columns: time, open, high, low, close
tmin, tmax = c["time"].min(), c["time"].max()

def nearest_idx(t):
    # index of the candle whose time is closest to t
    return int((c["time"] - t).abs().values.argmin())

# losing trades within M1 range
losers = d[(d["profit"] < 0) & (d["entry_time"] >= tmin) & (d["exit_time"] <= tmax)].copy()
losers = losers.sort_values("profit")  # worst first
if args.top > 0:
    losers = losers.head(args.top)
print(f"deals total={len(d)}  losers_in_M1_range={((d['profit']<0)&(d['entry_time']>=tmin)&(d['exit_time']<=tmax)).sum()}  drawing={len(losers)}")

def draw_candles(ax, sub):
    for i,(_,r) in enumerate(sub.iterrows()):
        up = r["close"] >= r["open"]
        col = "#26a69a" if up else "#ef5350"
        ax.plot([i,i], [r["low"], r["high"]], color=col, lw=0.8, zorder=2)
        lo = min(r["open"], r["close"]); hi = max(r["open"], r["close"])
        ax.add_patch(Rectangle((i-0.3, lo), 0.6, max(hi-lo, 0.01), color=col, zorder=3))

rows = []
for k,(_,t) in enumerate(losers.iterrows(), 1):
    ei = nearest_idx(t["entry_time"]); xi = nearest_idx(t["exit_time"])
    a = max(0, ei - args.pre); b = min(len(c)-1, xi + args.post)
    sub = c.iloc[a:b+1].reset_index(drop=True)
    if len(sub) < 5: 
        continue
    eix = ei - a; xix = xi - a
    isbuy = (t["dir"] == "buy")
    entry = t["entry_price"]; exitp = t["exit_price"]
    who = "FIX09" if t["magic"]==FIXM else ("DTREND" if t["magic"]==DTM else t["magic"])
    # MAE during hold (adverse excursion vs entry)
    hold = sub.iloc[max(0,eix):xix+1]
    if isbuy:
        mae_price = hold["low"].min(); mae = entry - mae_price
        mfe_price = hold["high"].max(); mfe = mfe_price - entry
    else:
        mae_price = hold["high"].max(); mae = mae_price - entry
        mfe_price = hold["low"].min(); mfe = entry - mfe_price
    # STOP-HUNT: after exit, did price reverse to our side beyond entry by >= SL distance?
    sl_dist = abs(entry - exitp)
    post = sub.iloc[xix+1:]
    stophunt = False; rev = 0.0
    if len(post) > 0 and sl_dist > 0:
        if isbuy:
            rev = post["high"].max() - exitp
            stophunt = (post["high"].max() >= entry)   # came back to/above our entry after stopping us
        else:
            rev = exitp - post["low"].min()
            stophunt = (post["low"].min() <= entry)

    fig, ax = plt.subplots(figsize=(12,6))
    draw_candles(ax, sub)
    # entry & exit
    ax.axhline(entry, color="#1565c0", ls="--", lw=1.0)
    ax.axhline(exitp, color="#c62828", ls="--", lw=1.0)
    mk = "^" if isbuy else "v"
    ax.scatter([eix],[entry], marker=mk, s=160, color="#1565c0", edgecolor="black", zorder=6)
    ax.scatter([xix],[exitp], marker="x", s=140, color="#c62828", zorder=6, linewidths=3)
    ax.annotate(f"ENTRY {entry:.2f}", (eix, entry), textcoords="offset points", xytext=(0,12), ha="center", fontsize=9, color="#1565c0", fontweight="bold")
    ax.annotate(f"SL HIT {exitp:.2f}", (xix, exitp), textcoords="offset points", xytext=(0,-16), ha="center", fontsize=9, color="#c62828", fontweight="bold")
    # shade hold window
    ax.axvspan(eix, xix, color="#ffd54f", alpha=0.12, zorder=1)
    # x labels
    step = max(1, len(sub)//10)
    ax.set_xticks(range(0,len(sub),step))
    ax.set_xticklabels([sub["time"].iloc[i].strftime("%m-%d %H:%M") for i in range(0,len(sub),step)], rotation=40, ha="right", fontsize=7)
    flag = "  ⚠ STOP-HUNT: price reversed to our side AFTER SL (entry too early)" if stophunt else ""
    ax.set_title(f"#{k}  {t['entry_time']:%Y-%m-%d %H:%M}  {who} {'BUY' if isbuy else 'SELL'}  loss ${t['profit']:.0f}  |  held {xix-eix} bars  MAE ${mae:.0f}{flag}", fontsize=10.5)
    ax.set_ylabel("XAUUSD"); ax.grid(alpha=0.2, axis="y")
    plt.tight_layout()
    fn = os.path.join(OUT, f"loss_{k:02d}_{t['entry_time']:%Y%m%d_%H%M}_{who}.png")
    plt.savefig(fn, dpi=110); plt.close()
    rows.append(dict(k=k, time=t["entry_time"], who=who, dir=("BUY" if isbuy else "SELL"),
                     loss=t["profit"], held=xix-eix, mae=mae, mfe=mfe, sl_dist=sl_dist,
                     stophunt=stophunt, rev=rev, file=os.path.basename(fn)))

R = pd.DataFrame(rows)
if len(R):
    sh = int(R["stophunt"].sum())
    print(f"\nDrawn {len(R)} loss charts. STOP-HUNT (price reversed to our side after SL): {sh}/{len(R)} = {sh/len(R)*100:.0f}%")
    print("  => high % means entries are TOO EARLY (wicked out, then it went our way).")
    print("\nworst losses:")
    for _,r in R.head(12).iterrows():
        print(f"  #{r['k']:2d} {r['time']:%Y-%m-%d %H:%M} {r['who']:6s} {r['dir']:4s} ${r['loss']:7.0f} held {r['held']:2d}b MAE ${r['mae']:5.0f} {'STOPHUNT' if r['stophunt'] else ''}")
    # gallery
    html = ["<html><head><meta charset='utf-8'><title>COMBO losses</title>",
            "<style>body{font-family:Arial;background:#111;color:#eee;margin:16px}",
            "h2{color:#fff}img{width:100%;border:1px solid #333;margin:6px 0}",
            ".c{background:#1c1c1c;padding:10px;margin:14px 0;border-radius:6px}",
            "table{border-collapse:collapse}td,th{border:1px solid #444;padding:4px 8px}</style></head><body>",
            f"<h2>CK_GOLD_COMBO — losing trades on the chart ({len(R)} worst)</h2>",
            f"<p>STOP-HUNT (price reversed to our side after SL hit) = <b>{sh}/{len(R)} ({sh/len(R)*100:.0f}%)</b>. "
            "High % = entries too early / wicked out.</p>",
            "<table><tr><th>#</th><th>time</th><th>strat</th><th>dir</th><th>loss $</th><th>held</th><th>MAE $</th><th>stop-hunt?</th></tr>"]
    for _,r in R.iterrows():
        html.append(f"<tr><td>{r['k']}</td><td>{r['time']:%Y-%m-%d %H:%M}</td><td>{r['who']}</td><td>{r['dir']}</td><td>{r['loss']:.0f}</td><td>{r['held']}</td><td>{r['mae']:.0f}</td><td>{'YES' if r['stophunt'] else ''}</td></tr>")
    html.append("</table>")
    for _,r in R.iterrows():
        html.append(f"<div class='c'><b>#{r['k']} {r['time']:%Y-%m-%d %H:%M} {r['who']} {r['dir']} loss ${r['loss']:.0f}</b>"
                    f"{'  ⚠ STOP-HUNT' if r['stophunt'] else ''}<br><img src='{r['file']}'></div>")
    html.append("</body></html>")
    open(os.path.join(OUT,"gallery.html"),"w",encoding="utf-8").write("\n".join(html))
    R.to_csv(os.path.join(OUT,"loss_summary.csv"), index=False)
    print("\nsaved gallery:", os.path.join(OUT,"gallery.html"))
else:
    print("no losing trades drawn (check M1 date range vs trade dates)")

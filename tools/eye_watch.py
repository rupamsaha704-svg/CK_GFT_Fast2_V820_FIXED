#!/usr/bin/env python3
"""
eye_watch.py  --  "line chart on one side, candle chart on the other" diagnostic.

For each trade it draws ONE figure with TWO panels side by side:
  LEFT  = LINE chart, wide context (many bars) -> shows WHERE the trade sits in the bigger move
          (are we entering with the trend or fading it? near a swing? mid-range?).
  RIGHT = CANDLE chart, tight zoom on the trade -> shows WHY it worked or failed
          (wick/rejection, the bar that stopped us, structure right at entry).
Both panels share entry / exit(SL) / MAE / MFE annotations and a shaded hold window.

Same inputs as loss_visualizer.py (the enriched combo deals CSV + M1 price). Read-only: it never
touches trading code, never runs a backtest. It only draws what the MT5 run already produced.

Usage:
  python tools\\eye_watch.py [--which losers|winners|all] [--top 20] [--tf 15]
                             [--line-pre 120] [--line-post 40] [--deals <path>] [--m1 <path>]
"""
import argparse
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import numpy as np
import pandas as pd

ap = argparse.ArgumentParser()
ap.add_argument("--which", choices=["losers", "winners", "all"], default="losers")
ap.add_argument("--top", type=int, default=20, help="how many trades to draw (0 = all in range)")
ap.add_argument("--tf", type=int, default=15, help="candle timeframe minutes for the RIGHT panel")
ap.add_argument("--line-pre", type=int, default=120, help="LEFT line-chart bars of context before entry")
ap.add_argument("--line-post", type=int, default=40, help="LEFT line-chart bars after exit")
ap.add_argument("--cand-pre", type=int, default=14, help="RIGHT candle bars before entry")
ap.add_argument("--cand-post", type=int, default=10, help="RIGHT candle bars after exit")
ap.add_argument("--deals", default=None)
ap.add_argument("--m1", default=r"experiments\dump_m1\xau_m1.csv")
args = ap.parse_args()

DEALS = args.deals or os.path.join(os.environ.get("APPDATA", ""), "MetaQuotes", "Terminal",
                                   "Common", "Files", "ck_gold_combo_deals.csv")
OUT = os.path.join(os.path.expanduser("~"), "Desktop", "gold_chop_charts", "eye_watch")
os.makedirs(OUT, exist_ok=True)
FIXM, DTM = "20260716", "20260930"

if not os.path.exists(DEALS):
    print("DEALS CSV not found:", DEALS)
    sys.exit(1)
if not os.path.exists(args.m1):
    print("M1 CSV not found:", args.m1, "-- export it first (CK_ExportOHLC / dump_m1).")
    sys.exit(1)

d = pd.read_csv(DEALS)
d.columns = [c.strip().lower() for c in d.columns]
for c in ["entry_time", "exit_time"]:
    d[c] = pd.to_datetime(d[c], format="%Y.%m.%d %H:%M", errors="coerce")
for c in ["entry_price", "exit_price", "profit"]:
    d[c] = pd.to_numeric(d[c], errors="coerce")
d["magic"] = d["magic"].astype(str)
d = d.dropna(subset=["entry_time", "exit_time", "entry_price", "exit_price"])

m1 = pd.read_csv(args.m1)
m1["time"] = pd.to_datetime(m1["time"], format="%Y.%m.%d %H:%M")
m1 = m1.set_index("time").sort_index()
rule = f"{args.tf}min"
c = pd.DataFrame({
    "open":  m1["open"].resample(rule).first(),
    "high":  m1["high"].resample(rule).max(),
    "low":   m1["low"].resample(rule).min(),
    "close": m1["close"].resample(rule).last(),
}).dropna().reset_index()
tmin, tmax = c["time"].min(), c["time"].max()


def nearest_idx(t):
    return int((c["time"] - t).abs().values.argmin())


sel = d[(d["entry_time"] >= tmin) & (d["exit_time"] <= tmax)].copy()
if args.which == "losers":
    sel = sel[sel["profit"] < 0].sort_values("profit")
elif args.which == "winners":
    sel = sel[sel["profit"] > 0].sort_values("profit", ascending=False)
else:
    sel = sel.reindex(sel["profit"].abs().sort_values(ascending=False).index)
if args.top > 0:
    sel = sel.head(args.top)
print(f"deals={len(d)}  in_range={((d['entry_time']>=tmin)&(d['exit_time']<=tmax)).sum()}  "
      f"drawing {args.which}={len(sel)}")


def draw_candles(ax, sub):
    for i, (_, r) in enumerate(sub.iterrows()):
        up = r["close"] >= r["open"]
        col = "#26a69a" if up else "#ef5350"
        ax.plot([i, i], [r["low"], r["high"]], color=col, lw=0.8, zorder=2)
        lo = min(r["open"], r["close"]); hi = max(r["open"], r["close"])
        ax.add_patch(Rectangle((i - 0.3, lo), 0.6, max(hi - lo, 0.01), color=col, zorder=3))


def xlabels(ax, sub):
    step = max(1, len(sub) // 8)
    ax.set_xticks(range(0, len(sub), step))
    ax.set_xticklabels([sub["time"].iloc[i].strftime("%m-%d %H:%M") for i in range(0, len(sub), step)],
                       rotation=40, ha="right", fontsize=7)


rows = []
for k, (_, t) in enumerate(sel.iterrows(), 1):
    ei = nearest_idx(t["entry_time"]); xi = nearest_idx(t["exit_time"])
    isbuy = (t["dir"] == "buy")
    entry = t["entry_price"]; exitp = t["exit_price"]
    who = "FIX09" if t["magic"] == FIXM else ("DTREND" if t["magic"] == DTM else t["magic"])
    win = t["profit"] > 0

    # ---- LEFT: wide line-chart context ----
    la = max(0, ei - args.line_pre); lb = min(len(c) - 1, xi + args.line_post)
    lsub = c.iloc[la:lb + 1].reset_index(drop=True)
    if len(lsub) < 10:
        continue
    lei, lxi = ei - la, xi - la

    # ---- RIGHT: tight candle zoom ----
    ca = max(0, ei - args.cand_pre); cb = min(len(c) - 1, xi + args.cand_post)
    csub = c.iloc[ca:cb + 1].reset_index(drop=True)
    cei, cxi = ei - ca, xi - ca

    # excursions during hold (on candle zoom)
    hold = csub.iloc[max(0, cei):cxi + 1]
    if isbuy:
        mae = entry - hold["low"].min(); mfe = hold["high"].max() - entry
    else:
        mae = hold["high"].max() - entry; mfe = entry - hold["low"].min()

    fig, (axL, axR) = plt.subplots(1, 2, figsize=(17, 6.2),
                                   gridspec_kw={"width_ratios": [1.15, 1]})

    # LEFT line panel
    axL.plot(range(len(lsub)), lsub["close"], color="#90caf9", lw=1.3, zorder=2)
    axL.axhline(entry, color="#1565c0", ls="--", lw=1.0)
    axL.axhline(exitp, color="#c62828", ls="--", lw=1.0)
    axL.axvspan(lei, lxi, color="#ffd54f", alpha=0.12)
    axL.scatter([lei], [entry], marker=("^" if isbuy else "v"), s=150, color="#1565c0",
                edgecolor="black", zorder=6)
    axL.scatter([lxi], [exitp], marker="x", s=130, color="#c62828", zorder=6, linewidths=3)
    xlabels(axL, lsub)
    axL.set_title(f"LINE (where): {args.line_pre}+{args.line_post} bars context", fontsize=10)
    axL.set_ylabel("XAUUSD"); axL.grid(alpha=0.2)

    # RIGHT candle panel
    draw_candles(axR, csub)
    axR.axhline(entry, color="#1565c0", ls="--", lw=1.0)
    axR.axhline(exitp, color="#c62828", ls="--", lw=1.0)
    axR.axvspan(cei, cxi, color="#ffd54f", alpha=0.12)
    axR.scatter([cei], [entry], marker=("^" if isbuy else "v"), s=150, color="#1565c0",
                edgecolor="black", zorder=6)
    axR.scatter([cxi], [exitp], marker="x", s=130, color="#c62828", zorder=6, linewidths=3)
    axR.annotate("ENTRY", (cei, entry), textcoords="offset points", xytext=(0, 12), ha="center",
                 fontsize=8, color="#1565c0", fontweight="bold")
    axR.annotate(("TP" if win else "SL"), (cxi, exitp), textcoords="offset points", xytext=(0, -16),
                 ha="center", fontsize=8, color="#c62828", fontweight="bold")
    xlabels(axR, csub)
    axR.set_title(f"CANDLE (why): {args.tf}m zoom", fontsize=10)
    axR.grid(alpha=0.2, axis="y")

    res = "WIN" if win else "LOSS"
    fig.suptitle(f"#{k}  {t['entry_time']:%Y-%m-%d %H:%M}  {who} {'BUY' if isbuy else 'SELL'}  "
                 f"{res} ${t['profit']:.0f}  |  held {cxi-cei} bars  MAE ${mae:.0f}  MFE ${mfe:.0f}",
                 fontsize=11.5, fontweight="bold")
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    fn = os.path.join(OUT, f"{res.lower()}_{k:02d}_{t['entry_time']:%Y%m%d_%H%M}_{who}.png")
    plt.savefig(fn, dpi=105); plt.close()
    rows.append(dict(k=k, time=t["entry_time"], who=who, dir=("BUY" if isbuy else "SELL"),
                     result=res, profit=t["profit"], held=cxi - cei, mae=mae, mfe=mfe,
                     file=os.path.basename(fn)))

R = pd.DataFrame(rows)
if not len(R):
    print("nothing drawn (check M1 date range vs trade dates, or --which).")
    sys.exit(0)

# gallery
html = ["<html><head><meta charset='utf-8'><title>eye-watch</title>",
        "<style>body{font-family:Arial;background:#111;color:#eee;margin:16px}",
        "h2{color:#fff}img{width:100%;border:1px solid #333;margin:6px 0}",
        ".c{background:#1c1c1c;padding:10px;margin:14px 0;border-radius:6px}</style></head><body>",
        f"<h2>eye-watch — LINE (where) + CANDLE (why), {args.which}, {len(R)} trades</h2>",
        "<p>Left panel = wide line chart: is the entry with or against the bigger move. "
        "Right panel = candle zoom: the wick/structure at entry and the bar that closed it.</p>"]
for _, r in R.iterrows():
    html.append(f"<div class='c'><b>#{r['k']} {r['time']:%Y-%m-%d %H:%M} {r['who']} {r['dir']} "
                f"{r['result']} ${r['profit']:.0f}  MAE ${r['mae']:.0f} MFE ${r['mfe']:.0f}</b>"
                f"<br><img src='{r['file']}'></div>")
html.append("</body></html>")
open(os.path.join(OUT, "gallery.html"), "w", encoding="utf-8").write("\n".join(html))
R.to_csv(os.path.join(OUT, "eye_watch_summary.csv"), index=False)
print(f"drew {len(R)} twin-panel charts -> {os.path.join(OUT, 'gallery.html')}")

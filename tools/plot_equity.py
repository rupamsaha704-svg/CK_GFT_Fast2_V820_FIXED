#!/usr/bin/env python3
"""
plot_equity.py - MT5-style PICTURE from an OnTester trades CSV: equity curve + drawdown (underwater),
with net profit, final balance, return %, max drawdown %, trades, PF and win %.

Reads MT5 output only (never simulates). Accepts either 'time,profit' or 'deal,profit' headers.

Usage:
  python tools/plot_equity.py --csv trades.csv --deposit 5000 --title "FIX09 $5k last 1yr" --out chart.png
"""
import argparse, datetime
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates


def load(path):
    times, profits = [], []
    with open(path) as fh:
        for l in fh:
            l = l.strip()
            if not l or "," not in l:
                continue
            head, last = l.rsplit(",", 1)
            try:
                p = float(last)
            except ValueError:
                continue  # header/garbage
            profits.append(p)
            t = None
            try:
                t = datetime.datetime.strptime(head.split(",")[-1].strip(), "%Y.%m.%d %H:%M")
            except Exception:
                t = None
            times.append(t)
    if not any(times):
        times = list(range(1, len(profits) + 1))
    return times, profits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--deposit", type=float, default=5000.0)
    ap.add_argument("--title", default="Strategy")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    times, profits = load(a.csv)
    if not profits:
        raise SystemExit("plot_equity: no trades parsed from " + a.csv)

    # equity curve + underwater drawdown
    eq = a.deposit
    peak = a.deposit
    xs, equity, dd = [], [], []
    have_dates = isinstance(times[0], datetime.datetime)
    for i, p in enumerate(profits):
        eq += p
        peak = max(peak, eq)
        xs.append(times[i] if have_dates else i + 1)
        equity.append(eq)
        dd.append((eq - peak) / peak * 100.0 if peak > 0 else 0.0)

    net = sum(profits)
    n = len(profits)
    gw = sum(p for p in profits if p > 0)
    gl = abs(sum(p for p in profits if p < 0))
    pf = (gw / gl) if gl > 0 else float("inf")
    wr = 100.0 * sum(1 for p in profits if p > 0) / n
    maxdd = -min(dd) if dd else 0.0
    ret = 100.0 * net / a.deposit
    final = a.deposit + net
    up = net >= 0
    col = "#1a9850" if up else "#d73027"

    fig, (ax1, ax2) = plt.subplots(
        2, 1, figsize=(12, 7.2), sharex=True, gridspec_kw={"height_ratios": [3, 1]}
    )
    fig.suptitle(a.title, fontsize=15, fontweight="bold", y=0.985)

    ax1.plot(xs, equity, color=col, linewidth=1.7)
    ax1.axhline(a.deposit, color="#888", linestyle="--", linewidth=1, label=f"deposit ${a.deposit:,.0f}")
    ax1.fill_between(xs, a.deposit, equity, where=[e >= a.deposit for e in equity], color=col, alpha=0.12)
    ax1.fill_between(xs, a.deposit, equity, where=[e < a.deposit for e in equity], color="#d73027", alpha=0.12)
    ax1.set_ylabel("Balance ($)")
    ax1.grid(True, alpha=0.3)
    box = (f"Net profit:  ${net:,.0f}  ({ret:+.0f}%)\n"
           f"Final bal.:  ${final:,.0f}\n"
           f"Max DD:      {maxdd:.1f}%\n"
           f"Trades:      {n}    Win: {wr:.0f}%\n"
           f"Profit factor: {pf:.2f}")
    ax1.text(0.012, 0.97, box, transform=ax1.transAxes, va="top", ha="left",
             family="monospace", fontsize=10,
             bbox=dict(boxstyle="round", facecolor="#f7f7f7", edgecolor="#bbb"))
    ax1.legend(loc="lower right", fontsize=9)

    ax2.fill_between(xs, dd, 0, color="#d73027", alpha=0.5)
    ax2.set_ylabel("Drawdown %")
    ax2.grid(True, alpha=0.3)
    ax2.axhline(-maxdd, color="#d73027", linestyle=":", linewidth=1)
    ax2.text(0.012, 0.06, f"max drawdown {maxdd:.1f}%", transform=ax2.transAxes,
             va="bottom", ha="left", fontsize=9, color="#d73027")

    if have_dates:
        ax2.xaxis.set_major_formatter(mdates.DateFormatter("%Y-%m"))
        fig.autofmt_xdate(rotation=0, ha="center")
        ax2.set_xlabel("Date")
    else:
        ax2.set_xlabel("Trade #")

    fig.tight_layout(rect=[0, 0, 1, 0.97])
    fig.savefig(a.out, dpi=120)
    print(f"chart -> {a.out}")
    print(f"net=${net:,.0f} ret={ret:+.0f}% final=${final:,.0f} maxDD={maxdd:.1f}% trades={n} win={wr:.0f}% pf={pf:.2f}")


if __name__ == "__main__":
    main()

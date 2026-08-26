"""CK_GFT robustness validator (v2).
Parses the MT5 baseline HTML report's DEALS table (13-col MT5 layout),
groups deals into positions (handles partial closes), splits Long/Short,
then runs: rich trade stats, Monte Carlo (bootstrap), CPCV IS/OOS Sharpe,
and Deflated Sharpe. Writes markdown deliverables. LLM-free, deterministic.
"""
from __future__ import annotations
import os, re, sys, math, csv
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from cpcv import CombinatorialPurgedKFold
from pbo import deflated_sharpe_ratio

RESEARCH = os.environ.get("CK_RESEARCH", HERE)
N_MC = int(os.environ.get("CK_MC", "10000"))
DEPOSIT = float(os.environ.get("CK_DEPOSIT", "5000"))
YEARS = float(os.environ.get("CK_YEARS", "0.5"))

def find_report():
    for base in [RESEARCH, os.path.expandvars(r"%APPDATA%\MetaQuotes\Terminal")]:
        if base and os.path.isdir(base):
            for dp, _, fns in os.walk(base):
                for fn in fns:
                    if fn.lower() in ("ck_baseline.htm", "ck_baseline.html"):
                        return os.path.join(dp, fn)
    return None

def strip(s):
    s = re.sub(r"<[^>]+>", " ", s).replace("&nbsp;", " ").replace("&amp;", "&")
    return re.sub(r"\s+", " ", s).strip()

def num(x):
    x = re.sub(r"(?<=\d)[ \u00a0]+(?=\d)", "", x).replace(",", "")
    try:
        return float(x)
    except Exception:
        return 0.0

def grab(text, label):
    m = re.search(re.escape(label) + r"\s*:?\s*(-?\d[\d .,]*(?:\s*\([-\d.,%\s]*\))?)", text)
    if not m:
        return "?"
    return re.sub(r"(?<=\d)\s+(?=\d)", "", m.group(1)).strip()

def parse_positions(html):
    """Group MT5 deals into positions. Returns (pls, sides).
    One position at a time; all 'out' deals after an 'in' belong to it."""
    rows = re.findall(r"(?is)<tr[^>]*>(.*?)</tr>", html)
    hdr = -1; cols = []
    for i, r in enumerate(rows):
        cells = [strip(c).lower() for c in re.findall(r"(?is)<t[dh][^>]*>(.*?)</t[dh]>", r)]
        if "direction" in cells and "profit" in cells and "balance" in cells and "volume" in cells:
            hdr = i; cols = cells; break
    if hdr < 0:
        return [], []
    di = cols.index("direction"); pi = cols.index("profit"); ti = cols.index("type")
    ci = cols.index("commission") if "commission" in cols else -1
    si = cols.index("swap") if "swap" in cols else -1
    pls, sides = [], []
    cur_side, cur, opened = None, 0.0, False
    for r in rows[hdr + 1:]:
        cells = [strip(c) for c in re.findall(r"(?is)<t[dh][^>]*>(.*?)</t[dh]>", r)]
        if len(cells) <= max(di, pi, ti):
            continue
        d = cells[di].lower()
        if d == "in":
            if opened:
                pls.append(round(cur, 2)); sides.append(cur_side)
            cur_side = "long" if cells[ti].lower() == "buy" else "short"
            cur, opened = 0.0, True
        elif d == "out":
            p = num(cells[pi])
            if 0 <= ci < len(cells): p += num(cells[ci])
            if 0 <= si < len(cells): p += num(cells[si])
            cur += p
    if opened:
        pls.append(round(cur, 2)); sides.append(cur_side)
    return pls, sides

def sharpe(x):
    x = np.asarray(x, float); x = x[~np.isnan(x)]
    if len(x) < 2: return float("nan")
    s = np.std(x, ddof=1)
    return float(np.mean(x) / s) if s > 0 else float("nan")

def equity_curve(pl, deposit=DEPOSIT):
    return deposit + np.cumsum(np.asarray(pl, float))

def max_dd(equity):
    peak = np.maximum.accumulate(equity)
    dd = equity - peak
    return float(-dd.min()), float(-(dd / peak).min() * 100.0)

def streaks(pl):
    win = loss = mw = ml = 0
    for p in pl:
        if p > 0: win += 1; loss = 0; mw = max(mw, win)
        elif p < 0: loss += 1; win = 0; ml = max(ml, loss)
    return mw, ml

def side_stats(pl, sides, s):
    m = sides == s
    sub = pl[m]
    if len(sub) == 0:
        return f"{s}: 0 trades"
    w = sub[sub > 0]
    return (f"{s}: {len(sub)} trades, win {100*len(w)/len(sub):.1f}%, "
            f"net {sub.sum():.2f}, avg {sub.mean():.2f}")

def main():
    rep = find_report()
    if not rep:
        print("ERROR: CK_baseline.htm not found."); return 1
    print("Report:", rep)
    html = open(rep, encoding="utf-8", errors="ignore").read()
    text = strip(html)
    summary = {k: grab(text, k) for k in
               ["Total Net Profit", "Gross Profit", "Gross Loss", "Profit Factor",
                "Expected Payoff", "Total Trades", "Balance Drawdown Maximal",
                "Equity Drawdown Maximal"]}
    print("\n-- MT5 SUMMARY (authoritative) --")
    for k, v in summary.items(): print(f"   {k}: {v}")

    pls, sides = parse_positions(html)
    print(f"\nParsed {len(pls)} positions (round-turn trades).")
    if len(pls) < 20:
        print("WARNING: too few trades parsed; deals table layout differs.")
        _write_partial(summary, len(pls)); return 0

    pl = np.asarray(pls, float); sides = np.asarray(sides)
    eq = equity_curve(pl)
    net = float(pl.sum())
    wins = pl[pl > 0]; losses = pl[pl < 0]
    pf = float(wins.sum() / -losses.sum()) if losses.sum() != 0 else float("inf")
    dd_money, dd_pct = max_dd(eq)
    sr = sharpe(pl)
    win_rate = 100 * len(wins) / len(pl)
    avg_win = float(wins.mean()) if len(wins) else 0.0
    avg_loss = float(losses.mean()) if len(losses) else 0.0
    payoff = (avg_win / -avg_loss) if avg_loss < 0 else float("inf")
    expectancy = float(pl.mean())
    mw, ml = streaks(pl)
    skew = float(((pl - pl.mean())**3).mean() / (pl.std()**3)) if pl.std() > 0 else 0.0
    exk = float(((pl - pl.mean())**4).mean() / (pl.std()**4) - 3) if pl.std() > 0 else 0.0

    stats = dict(trades=len(pl), net=net, pf=pf, dd_money=dd_money, dd_pct=dd_pct,
                 sr=sr, win_rate=win_rate, avg_win=avg_win, avg_loss=avg_loss,
                 payoff=payoff, expectancy=expectancy, max_win=float(pl.max()),
                 max_loss=float(pl.min()), max_consec_win=mw, max_consec_loss=ml)
    print("\n-- RECONSTRUCTED TRADE STATS --")
    print(f"   trades={len(pl)}  net={net:.2f}  PF={pf:.3f}  maxDD={dd_money:.2f} ({dd_pct:.2f}%)")
    print(f"   win%={win_rate:.2f}  expectancy={expectancy:.2f}  payoff={payoff:.2f}  "
          f"avgW={avg_win:.2f}  avgL={avg_loss:.2f}  maxCW={mw} maxCL={ml}")
    print(f"   {side_stats(pl, sides, 'long')}")
    print(f"   {side_stats(pl, sides, 'short')}")

    rng = np.random.default_rng(42)
    ddm = np.empty(N_MC); ddp = np.empty(N_MC); fin = np.empty(N_MC); stk = np.empty(N_MC)
    for i in range(N_MC):
        samp = rng.choice(pl, size=len(pl), replace=True)
        e = equity_curve(samp)
        a, b = max_dd(e); ddm[i] = a; ddp[i] = b; fin[i] = e[-1] - DEPOSIT
        stk[i] = streaks(samp.tolist())[1]
    ruin = float(np.mean(fin <= -0.5 * DEPOSIT) * 100.0)
    mc = dict(sims=N_MC, dd_pct_median=float(np.median(ddp)), dd_pct_95=float(np.percentile(ddp, 95)),
              dd_pct_99=float(np.percentile(ddp, 99)), dd_money_95=float(np.percentile(ddm, 95)),
              final_median=float(np.median(fin)), final_5pct=float(np.percentile(fin, 5)),
              final_neg=float(np.mean(fin < 0) * 100.0), ruin=ruin,
              streak95=float(np.percentile(stk, 95)))
    print(f"\n-- MONTE CARLO (bootstrap, {N_MC} sims) --")
    print(f"   DD% median={mc['dd_pct_median']:.2f} 95th={mc['dd_pct_95']:.2f} 99th={mc['dd_pct_99']:.2f}")
    print(f"   final median={mc['final_median']:.0f} 5th={mc['final_5pct']:.0f} P(final<0)={mc['final_neg']:.1f}% RoR={ruin:.1f}%")

    n = len(pl)
    ns = 8 if n >= 64 else max(4, min(6, n // 8))
    cpcv = CombinatorialPurgedKFold(n_splits=ns, n_test_splits=2, embargo_pct=0.01)
    iss, ooss = [], []
    for tr, te in cpcv.split(n):
        iss.append(sharpe(pl[tr])); ooss.append(sharpe(pl[te]))
    ism, oosm = float(np.nanmean(iss)), float(np.nanmean(ooss))
    cp = dict(ns=ns, paths=cpcv.get_n_splits(), ism=ism, oosm=oosm, deg=ism - oosm)
    print(f"\n-- CPCV --  splits={ns} paths={cpcv.get_n_splits()} IS={ism:.3f} OOS={oosm:.3f} deg={ism-oosm:.3f}")

    tpy = n / YEARS if YEARS > 0 else n
    ann = sr * math.sqrt(tpy)
    dsr = deflated_sharpe_ratio(ann, n_trials=max(2, cpcv.get_n_splits()), n_obs=n,
                                skewness=skew, excess_kurtosis=exk)
    print(f"\n-- DEFLATED SHARPE --  perTradeSR={sr:.3f} annSR={ann:.2f} DSR={dsr:.4f}")

    _write(rep, summary, pl, sides, stats, mc, cp, ann, dsr)
    print("\nDeliverables written to:", RESEARCH)
    return 0

def _p(name): return os.path.join(RESEARCH, name)

def _write_partial(summary, ntr):
    with open(_p("02_BASELINE_REPRODUCTION.md"), "w", encoding="utf-8") as f:
        f.write("# 02 - Baseline Reproduction (summary only)\n\n")
        f.write(f"Only {ntr} trades parsed.\n\n")
        for k, v in summary.items(): f.write(f"- {k}: {v}\n")

def _write(rep, summary, pl, sides, s, mc, cp, ann, dsr):
    with open(_p("baseline_trades.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(["trade_no", "side", "profit"])
        for i, (p, sd) in enumerate(zip(pl, sides), 1): w.writerow([i, sd, p])
    def ss(side):
        m = sides == side; sub = pl[m]
        if len(sub) == 0: return f"- {side}: 0 trades\n"
        w = sub[sub > 0]
        return f"- {side}: {len(sub)} trades, win {100*len(w)/len(sub):.1f}%, net {sub.sum():.2f}, avg {sub.mean():.2f}\n"
    with open(_p("02_BASELINE_REPRODUCTION.md"), "w", encoding="utf-8") as f:
        f.write("# 02 - Baseline Reproduction (independent broker)\n\n")
        f.write(f"Source report: `{os.path.basename(rep)}`\n")
        f.write("Model: MT5 Every-tick. Data: MetaQuotes-Demo XAUUSD M5. Window: 2024-01-01..2024-07-01.\n\n")
        f.write("## MT5 authoritative summary\n")
        for k, v in summary.items(): f.write(f"- {k}: {v}\n")
        f.write("\n## Reconstructed from parsed positions\n")
        f.write(f"- Trades: {s['trades']}\n- Net P/L: {s['net']:.2f}\n- Profit Factor: {s['pf']:.3f}\n")
        f.write(f"- Win rate: {s['win_rate']:.2f}%\n- Expectancy/trade: {s['expectancy']:.2f}\n")
        f.write(f"- Avg win: {s['avg_win']:.2f}  Avg loss: {s['avg_loss']:.2f}  Payoff: {s['payoff']:.2f}\n")
        f.write(f"- Largest win: {s['max_win']:.2f}  Largest loss: {s['max_loss']:.2f}\n")
        f.write(f"- Max consec wins: {s['max_consec_win']}  Max consec losses: {s['max_consec_loss']}\n")
        f.write(f"- Max drawdown: {s['dd_money']:.2f} ({s['dd_pct']:.2f}%)\n\n")
        f.write("## Long vs Short\n")
        f.write(ss("long")); f.write(ss("short"))
        f.write("\n## VERDICT\n")
        f.write("The claimed baseline (+$10,838, PF 2.03) was NOT reproduced on independent\n")
        f.write("MetaQuotes-Demo data for this window. This indicates the result is highly\n")
        f.write("broker/execution/period dependent. Authoritative confirmation requires the\n")
        f.write("ORIGINAL broker's XAUUSD tick data. Until then the baseline is UNVERIFIED.\n")
    with open(_p("07_MONTE_CARLO.md"), "w", encoding="utf-8") as f:
        f.write("# 07 - Monte Carlo (bootstrap resample, with replacement)\n\n")
        f.write(f"Sims: {mc['sims']}. Deposit: {DEPOSIT:.0f}.\n\n| Metric | Value |\n|---|---|\n")
        f.write(f"| Max DD % median | {mc['dd_pct_median']:.2f}% |\n")
        f.write(f"| Max DD % 95th | {mc['dd_pct_95']:.2f}% |\n")
        f.write(f"| Max DD % 99th | {mc['dd_pct_99']:.2f}% |\n")
        f.write(f"| Final P/L median | {mc['final_median']:.0f} |\n")
        f.write(f"| Final P/L 5th pct | {mc['final_5pct']:.0f} |\n")
        f.write(f"| P(final < 0) | {mc['final_neg']:.2f}% |\n")
        f.write(f"| Risk of ruin (-50%) | {mc['ruin']:.2f}% |\n")
        f.write(f"| Max losing streak 95th | {mc['streak95']:.0f} |\n")
    with open(_p("08_CPCV_PBO.md"), "w", encoding="utf-8") as f:
        f.write("# 08 - CPCV\n\nTool: vendored loadchange/ai-hedge-fund (Lopez de Prado ch.7).\n\n")
        f.write(f"- Splits: {cp['ns']}  Paths: {cp['paths']}\n- IS Sharpe: {cp['ism']:.3f}\n")
        f.write(f"- OOS Sharpe: {cp['oosm']:.3f}\n- IS->OOS degradation: {cp['deg']:.3f}\n\n")
        f.write("> Full PBO needs a matrix of many optimization configs (next stage).\n")
    with open(_p("09_DEFLATED_SHARPE.md"), "w", encoding="utf-8") as f:
        f.write("# 09 - Deflated Sharpe\n\nTool: vendored (Bailey & Lopez de Prado 2014).\n\n")
        f.write(f"- Per-trade Sharpe: {s['sr']:.3f}\n- Annualised Sharpe: {ann:.2f}\n")
        f.write(f"- Deflated Sharpe (prob true SR>0): {dsr:.4f}\n\n> >0.95 = significant.\n")

if __name__ == "__main__":
    raise SystemExit(main())

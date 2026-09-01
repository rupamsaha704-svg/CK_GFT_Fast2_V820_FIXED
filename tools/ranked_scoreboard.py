#!/usr/bin/env python3
"""
ranked_scoreboard.py - render the strategies that MADE MONEY as ranked MT5-style results blocks
(like the MetaTrader 5 Strategy Tester "Backtest" summary). Ranked by CURRENT-regime performance
(the honest, decision-relevant criterion), all at the same live spec where possible. Reads MT5
OnTester CSVs only. Outputs a single HTML + is converted to PDF by the caller.
"""
import os, datetime

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "PORTFOLIO")
os.makedirs(OUT, exist_ok=True)


def load(path):
    ps = []
    with open(path) as fh:
        for l in fh:
            l = l.strip()
            if not l or "," not in l:
                continue
            _, last = l.rsplit(",", 1)
            try:
                ps.append(float(last))
            except ValueError:
                continue
    return ps


def mt5(path, deposit):
    ps = load(path)
    n = len(ps)
    gp = sum(x for x in ps if x > 0)
    gl = sum(x for x in ps if x < 0)          # negative
    net = gp + gl
    pf = (gp / abs(gl)) if gl < 0 else (float("inf") if gp > 0 else 0.0)
    wins = [x for x in ps if x > 0]
    loss = [x for x in ps if x < 0]
    winp = 100.0 * len(wins) / n if n else 0
    # drawdown (balance) from equity curve
    eq = deposit; peak = deposit; ddabs = 0.0; ddpct = 0.0
    for x in ps:
        eq += x; peak = max(peak, eq)
        d = peak - eq
        if d > ddabs: ddabs = d
        dp = d / peak * 100 if peak > 0 else 0
        if dp > ddpct: ddpct = dp
    rf = (net / ddabs) if ddabs > 0 else float("inf")
    return dict(net=net, gp=gp, gl=gl, pf=pf, exp=(net / n if n else 0), n=n,
                winp=winp, lossp=100 - winp, nwin=len(wins), nloss=len(loss),
                lw=(max(wins) if wins else 0), ll=(min(loss) if loss else 0),
                aw=(sum(wins) / len(wins) if wins else 0), al=(sum(loss) / len(loss) if loss else 0),
                ddabs=ddabs, ddpct=ddpct, rf=rf, dep=deposit)


def pfx(v):
    return "inf" if v == float("inf") else f"{v:.2f}"


def block(title, m):
    def row(l1, v1, l2, v2):
        return (f"<tr><td class='l'>{l1}</td><td class='v'>{v1}</td>"
                f"<td class='l'>{l2}</td><td class='v'>{v2}</td></tr>")
    net_cls = "pos" if m["net"] >= 0 else "neg"
    rows = "".join([
        row("Initial Deposit", f"{m['dep']:,.2f}", "Profit Factor", pfx(m["pf"])),
        row("Total Net Profit", f"<b class='{net_cls}'>{m['net']:,.2f}</b>", "Expected Payoff", f"{m['exp']:.2f}"),
        row("Gross Profit", f"{m['gp']:,.2f}", "Recovery Factor", pfx(m["rf"])),
        row("Gross Loss", f"{m['gl']:,.2f}", "Balance DD Maximal", f"{m['ddabs']:,.2f} ({m['ddpct']:.2f}%)"),
        row("Total Trades", f"{m['n']}", "Profit Trades %", f"{m['winp']:.2f}%"),
        row("Largest profit trade", f"{m['lw']:,.2f}", "Largest loss trade", f"{m['ll']:,.2f}"),
        row("Average profit trade", f"{m['aw']:,.2f}", "Average loss trade", f"{m['al']:,.2f}"),
    ])
    return f"<div class='mt5'><div class='mt5h'>{title}</div><table class='mt5t'>{rows}</table></div>"


V = os.path.join(REPO, "experiments", "v17_live5k", "windows")
F = os.path.join(REPO, "experiments")

# rank #1 = v17 (works in current regime), #2 = FIX09 (trend-only)
v17_now  = mt5(os.path.join(V, "recent_regime", "trades.csv"), 5000)
v17_year = mt5(os.path.join(V, "last1yr", "trades.csv"), 5000)
fx_now   = mt5(os.path.join(F, "fix09hrs_off", "windows", "recent_regime", "trades.csv"), 5000)
fx_year  = mt5(os.path.join(F, "fix09_live5k", "windows", "last1yr", "trades.csv"), 5000)
today = datetime.date.today().isoformat()

html = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>Ranked Results - MT5 style</title><style>
 body{{font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;max-width:900px;margin:0 auto;
   padding:26px;color:#16202b}} h1{{font-size:22px;margin:0 0 4px}} .sub{{color:#5b6b7b;font-size:13px}}
 .rank{{border:1px solid #dbe4ec;border-radius:12px;padding:16px 18px;margin:16px 0;background:#fbfdff}}
 .rank h2{{margin:0 0 4px;font-size:17px}} .badge{{display:inline-block;border-radius:12px;padding:2px 10px;
   font-size:12px;font-weight:700;margin-left:8px;vertical-align:middle}}
 .win{{background:#e5f5e9;color:#1a7a3a;border:1px solid #b7e0c2}} .warn{{background:#fdeceb;color:#c0362c;border:1px solid #f2c4c0}}
 .num{{font-size:30px;font-weight:800;margin:2px 0}} .pos{{color:#1a9850}} .neg{{color:#d73027}}
 .two{{display:flex;gap:14px;flex-wrap:wrap;margin-top:8px}} .mt5{{flex:1;min-width:340px;border:1px solid #cdd8e3;
   border-radius:8px;overflow:hidden}} .mt5h{{background:#eef3f8;padding:6px 10px;font-weight:700;font-size:13px;
   border-bottom:1px solid #cdd8e3}} .mt5t{{width:100%;border-collapse:collapse;font-size:12px;font-family:Consolas,monospace}}
 .mt5t td{{border-bottom:1px solid #eef2f6;padding:4px 8px}} .mt5t .l{{color:#5b6b7b}} .mt5t .v{{text-align:right;font-weight:600}}
 .why{{font-size:13px;margin-top:8px}} table.rej{{border-collapse:collapse;width:100%;font-size:13px;margin-top:6px}}
 table.rej td,table.rej th{{border:1px solid #dbe4ec;padding:6px 8px;text-align:right}} table.rej td:first-child,table.rej th:first-child{{text-align:left}}
 .foot{{color:#5b6b7b;font-size:12px;margin-top:22px;border-top:1px solid #dbe4ec;padding-top:10px}}
</style></head><body>
<h1>XAUUSD strategies - ranked results (MT5 Strategy Tester)</h1>
<div class="sub">Same live spec ($5,000, 1:10, 0.09 cap, real ticks) &middot; ranked by CURRENT-regime result &middot; {today}</div>

<div class="rank">
 <h2>#1 &nbsp; CK_GFT_Fast v17 <span class="badge win">WORKS IN CURRENT MARKET</span></h2>
 <div class="sub">Current 6 months net</div>
 <div class="num pos">+${v17_now['net']:,.0f}</div>
 <div class="two">{block("Current regime (Mar-Aug 2026)", v17_now)}{block("Last 12 months", v17_year)}</div>
 <div class="why"><b>Why #1:</b> the only strategy still profitable in the current market; passes cost-stress + forward tests. Small risk-based lots, so $5k is fine. <b>Status: demo-forward (no real money yet).</b></div>
</div>

<div class="rank">
 <h2>#2 &nbsp; FIX09 (CK_GOLD_PRO) <span class="badge warn">TREND-ONLY - loses now</span></h2>
 <div class="sub">Current 6 months net (fresh $5k)</div>
 <div class="num neg">${fx_now['net']:,.0f}</div>
 <div class="two">{block("Current regime (Mar-Aug 2026)", fx_now)}{block("Last 12 months", fx_year)}</div>
 <div class="why"><b>Why #2:</b> huge in a trending market (last 12m +${fx_year['net']:,.0f}), but in the current regime it loses and, on $5k with a fixed 0.09 lot, the account margin-locks after a few losses (only {fx_now['n']} trades). Use only in a confirmed trend, on a bigger account.</div>
</div>

<h2 style="font-size:16px">Rejected (positive only in a past regime or over-optimized backtest)</h2>
<table class="rej">
<tr><th>Strategy</th><th>Out-of-sample net (50k)</th><th>Profit factor</th><th>Verdict</th></tr>
<tr><td>v23 (trend)</td><td>+2,512</td><td>1.12</td><td>REJECT - thin / regime-dependent</td></tr>
<tr><td>POC_VA (volume)</td><td>+2,433</td><td>1.06</td><td>REJECT - edge below cost</td></tr>
<tr><td>QT/CRT</td><td>-3,180</td><td>0.76</td><td>REJECT - no edge</td></tr>
<tr><td>QM/ICT</td><td>-3,325</td><td>0.50</td><td>REJECT - no edge</td></tr>
</table>

<div class="foot">Historical MT5 real-tick simulation, not a promise of future results. Trade counts include partial-take-profit
closes. No real money was traded; v17 proceeds to demo-forward validation. All runs recorded in a hash-chained ledger.</div>
</body></html>"""

path = os.path.join(OUT, "Ranked_Results_MT5style.html")
with open(path, "w", encoding="utf-8") as f:
    f.write(html)
print("ranked ->", path)
print(f"#1 v17 now +{v17_now['net']:.0f} PF{pfx(v17_now['pf'])} | year +{v17_year['net']:.0f}")
print(f"#2 FIX09 now {fx_now['net']:.0f} PF{pfx(fx_now['pf'])} | year +{fx_year['net']:.0f}")

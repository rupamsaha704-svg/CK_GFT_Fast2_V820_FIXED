#!/usr/bin/env python3
"""
M4 — Cost / slippage stress (deterministic). Applies extra execution cost per trade at pre-declared
multipliers and checks the edge survives. Baseline cost-per-trade MUST be pre-declared (from broker
spec / demo fills, recorded in manifest) — never invented to be lenient.

Model: adjusted_profit_i = profit_i - (multiplier * baseline_cost_per_trade).
(The trade CSV is already net of real backtest spread; this adds WORSE fills on top.)

PASS (M4, pre-declared): at 1.5x -> net>0 AND PF>=1.0. 2.0x = advisory red-flag only.

Usage: python3 cost_stress.py trades.csv --cost-per-trade 2.50 [--deposit 5000]
"""
import argparse
import metrics as M

MULTIPLIERS=[1.0,1.25,1.5,2.0]
M4_PASS_MULT=1.5

def adj(rows, extra):
    return [(dt, p-extra) for dt,p in rows]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('csv'); ap.add_argument('--cost-per-trade', type=float, required=True)
    ap.add_argument('--deposit', type=float, default=M.DEPOSIT_DEFAULT)
    a=ap.parse_args()
    rows=M.load_trades(a.csv); dep=a.deposit
    print("="*56); print(f"M4 COST/SLIPPAGE STRESS  (baseline extra cost = ${a.cost_per_trade:.2f}/trade)"); print("="*56)
    verdict_ok=None
    for m in MULTIPLIERS:
        r=adj(rows, m*a.cost_per_trade)
        net=M.net_profit(r); pf=M.profit_factor(r)
        flag=""
        if m==M4_PASS_MULT: flag=" <- M4 gate"
        print(f"  {m:>4}x : net {net:>9.0f}  PF {pf:.2f}{flag}")
        if m==M4_PASS_MULT: verdict_ok=(net>0 and pf>=1.0)
    print("-"*56)
    print(f"  M4: {'PASS' if verdict_ok else 'FAIL'} (survives {M4_PASS_MULT}x cost)")

if __name__=='__main__': main()

#!/usr/bin/env python3
"""
EMA-bias PLATEAU / robustness check (ledger seq48).

NOT a new strategy and NOT a copy of any existing one: this is a small ANALYSIS tool that re-runs
the ALREADY-BUILT qm_state_machine 'ema_bias' variant at several EMA periods and prints the
out-of-sample metrics for each, so we can see whether the ema_bias improvement is a robust PLATEAU
(credible) or a lonely spike at period 200 (an overfit artifact to be downgraded).

It reuses qm_state_machine.run (the engine) and metrics.py (canonical metrics) verbatim; it invents
no rule and tunes no threshold. Deterministic: same data + same periods => same table.

Usage:
    python3 v1_lab/ema_plateau.py --data <XAUUSD_M15> --m5 <XAUUSD_M5> [--split 2024-07-01]
"""
import os
import sys
import argparse
import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qm_state_machine as QM   # noqa: E402
import metrics as M            # noqa: E402

PERIODS = [50, 100, 150, 200, 250, 300]


def split_rows(rows, boundary):
    """Split (dt, net) metric rows into (is, oos) by a naive datetime boundary; unparseable -> IS."""
    is_r, oos_r = [], []
    for dt, net in rows:
        if dt is not None and dt >= boundary:
            oos_r.append((dt, net))
        else:
            is_r.append((dt, net))
    return is_r, oos_r


def rows_from_trades(trades):
    """Engine trades -> metrics rows [(datetime, net)] (metrics.py expects (dt, profit))."""
    out = []
    for t in sorted(trades, key=lambda x: (x["entry_index"], x["direction"])):
        out.append((t["entry_datetime"], t["net"]))
    return out


def metrics_block(rows, deposit):
    return {
        "n": M.n_trades(rows),
        "pf": M.profit_factor(rows),
        "exp": M.expectancy(rows),
        "dd": M.max_dd_closed(rows, deposit),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--m5", required=True)
    ap.add_argument("--split", default="2024-07-01")
    ap.add_argument("--deposit", type=float, default=M.DEPOSIT_DEFAULT)
    a = ap.parse_args()
    boundary = datetime.datetime.strptime(a.split, "%Y-%m-%d")

    m15 = QM.load_ohlc(a.data)
    m5 = QM.load_ohlc(a.m5)
    if not m15 or not m5:
        raise SystemExit("could not load data")

    # baseline (ema_bias OFF) for reference, then the sweep with ema_bias ON at each period.
    def run_cfg(cfg):
        trades, _ = QM.run(m15, cfg, m5_bars=m5)
        rows = rows_from_trades(trades)
        _, oos = split_rows(rows, boundary)
        return metrics_block(oos, a.deposit), metrics_block(rows, a.deposit)

    base_cfg = QM.DEFAULT_CONFIG
    base_oos, base_all = run_cfg(base_cfg)

    print("=" * 84)
    print("EMA-BIAS PLATEAU CHECK — OUT-OF-SAMPLE metrics by EMA period (split %s)" % a.split)
    print("=" * 84)
    print(f"  {'config':<18}{'OOSn':>6}{'OOSpf':>9}{'OOSexp':>10}{'OOSmaxDD%':>11}")
    print("-" * 84)
    print(f"  {'baseline(off)':<18}{base_oos['n']:>6}{_pf(base_oos['pf']):>9}"
          f"{base_oos['exp']:>10.2f}{base_oos['dd']:>11.2f}")
    results = []
    for p in PERIODS:
        cfg = base_cfg._replace(htf_ema_bias=True, ema_period=p)
        oos, _all = run_cfg(cfg)
        results.append((p, oos))
        print(f"  {'ema_bias p=' + str(p):<18}{oos['n']:>6}{_pf(oos['pf']):>9}"
              f"{oos['exp']:>10.2f}{oos['dd']:>11.2f}")
    print("-" * 84)
    # honest plateau read: how many periods keep OOS PF meaningfully above the baseline PF
    base_pf = base_oos["pf"]
    improved = [p for p, o in results if o["pf"] > base_pf and o["exp"] > 0]
    print(f"  baseline OOS PF = {_pf(base_pf)}; periods improving on it (PF up & exp>0): "
          f"{improved if improved else 'NONE'}")
    if len(improved) >= 4:
        print("  READ: broad PLATEAU — the trend-bias improvement is NOT a lonely spike (credible).")
    elif len(improved) >= 2:
        print("  READ: partial plateau — some robustness, treat with caution.")
    else:
        print("  READ: lonely/absent — likely an OVERFIT artifact; downgrade ema_bias.")
    print("  NOTE: low OOS trade counts remain (a filter reduces frequency); this checks ROBUSTNESS")
    print("        of the effect, not certification. Certification still needs forward/locked data.")
    print("=" * 84)


def _pf(pf):
    return "inf" if pf == float("inf") else f"{pf:.2f}"


if __name__ == "__main__":
    main()

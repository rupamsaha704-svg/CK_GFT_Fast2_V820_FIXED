"""Validate a strategy's REAL trade P&L using Vibe-Trading's official quantlib.

Input: a trades CSV that our MT5 EA dumps via OnTester -> columns include 'profit'
       (one row per closed trade). Same format as ck_v23_trades.csv etc.

Runs Vibe's institutional validation (NOT hand-rolled):
  - per-trade Sharpe (quantlib.sharpe_ratio)
  - Probabilistic Sharpe Ratio (is the edge real given the sample?)
  - Combinatorial Purged CV: IS vs OOS Sharpe (overfit check, leak-free)
  - Deflated Sharpe Ratio (accounts for how many variants we tried)

Usage:
  PYTHONPATH="<vibe>/agent:<vibe>/agent/src" python vibe_validate.py <trades.csv> [n_trials]

This is the "Vibe validation brain" half of the pipeline; MT5 remains the executor/truth.
"""
import sys
import numpy as np
import pandas as pd
from quantlib import multipletesting as mt
from quantlib import crossvalidation as cv


def load_profits(path):
    df = pd.read_csv(path)
    col = "profit" if "profit" in df.columns else df.columns[-1]
    p = pd.to_numeric(df[col], errors="coerce").dropna().to_numpy()
    return p


def main(path, n_trials, initial_cash=5000.0):
    profit = load_profits(path)
    n = len(profit)
    if n < 30:
        print(f"Only {n} trades - too few for reliable validation."); return
    # per-trade returns relative to starting capital (consistent, simple)
    r = profit / initial_cash

    obs_sr = mt.sharpe_ratio(r)
    psr = mt.probabilistic_sharpe_ratio(obs_sr, n_observations=n,
                                        skew=float(pd.Series(r).skew()),
                                        kurtosis=float(pd.Series(r).kurt() + 3.0))

    # Combinatorial Purged CV -> IS vs OOS Sharpe (leak-free overfit check)
    is_sr, oos_sr = [], []
    for sp in cv.combinatorial_purged_splits(n_samples=n, n_groups=6, n_test_groups=2):
        tr, te = r[sp.train], r[sp.test]
        if tr.std() > 0 and len(tr) > 5:
            is_sr.append(mt.sharpe_ratio(tr))
        if te.std() > 0 and len(te) > 5:
            oos_sr.append(mt.sharpe_ratio(te))
    is_m = float(np.mean(is_sr)) if is_sr else float("nan")
    oos_m = float(np.mean(oos_sr)) if oos_sr else float("nan")
    trial_std = float(np.std(oos_sr, ddof=1)) if len(oos_sr) > 1 else abs(obs_sr) or 1e-6

    dsr = mt.deflated_sharpe_ratio(observed_sharpe=obs_sr, n_trials=max(n_trials, 1),
                                   n_observations=n, trial_sharpe_std=trial_std,
                                   skew=float(pd.Series(r).skew()),
                                   kurtosis=float(pd.Series(r).kurt() + 3.0))

    total = float(profit.sum())
    wins = (profit > 0).sum()
    gp = profit[profit > 0].sum(); gl = -profit[profit < 0].sum()
    pf = (gp / gl) if gl > 0 else float("inf")

    print("=" * 60)
    print(f"  VIBE QUANTLIB VALIDATION  ({path.split('/')[-1]})")
    print("=" * 60)
    print(f"  trades={n}  net={total:+.2f}  PF={pf:.3f}  win%={100*wins/n:.1f}")
    print(f"  per-trade Sharpe        = {obs_sr:+.4f}")
    print(f"  Probabilistic Sharpe    = {psr:.4f}   (prob the edge > 0; want > 0.95)")
    print(f"  CPCV  IS Sharpe         = {is_m:+.4f}")
    print(f"  CPCV  OOS Sharpe        = {oos_m:+.4f}   (want > 0 and close to IS)")
    print(f"  CPCV  degradation IS-OOS= {is_m - oos_m:+.4f}")
    print(f"  Deflated Sharpe (n_trials={n_trials})")
    print(f"        DSR={dsr.deflated_sharpe_ratio:.4f}  survives={dsr.survives}  (want survives=True)")
    print("=" * 60)
    verdict = (oos_m > 0) and (psr > 0.90) and dsr.survives
    print(f"  VERDICT: {'edge looks REAL (not overfit)' if verdict else 'NOT convincing yet - treat with caution'}")
    print("=" * 60)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: vibe_validate.py <trades.csv> [n_trials]"); sys.exit(1)
    nt = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    main(sys.argv[1], nt)

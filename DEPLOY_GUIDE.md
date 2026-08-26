# CK_GFT_Fast_v23 — DEPLOY GUIDE (final, validated)

## What this is
The validated XAUUSD trend strategy. Real MT5 real-tick backtest + Vibe-Trading
official quantlib validation: **not overfit** (CPCV OOS Sharpe +0.107 ≥ IS), profitable
(+$5,760 / +115% on $5,000 in the 2025-08→2026-08 test), profit factor 1.39.
Modest edge (Deflated Sharpe) → expect less live than backtest. Drawdown ~14%.

## Exact MT5 settings (match the validated run — DO NOT change beyond these)
- Symbol: **XAUUSD**   Timeframe: **M15**
- Leverage: **1:10**   Deposit: **$5,000**   Model: **Every tick based on real ticks**
- EA inputs:
  - InpRiskPercent = 0.5
  - InpRR = 3.0
  - InpMaxLot = 0.09   (HARD CAP — never above)
  - InpMaxSL_ATR = 2.5
  - InpMaxTradesPerDay = 3
  - InpDailyLossStopR = 2.0 , InpDailyProfitStopR = 4.0
  - InpUseBreakEven = true

## Honest expectations
- Backtest year benefited from a strongly trending gold market. Live / other regimes = less.
- Drawdown ~14% is intrinsic to this edge on a $5k account (proven: 5 reduction attempts failed).
- For a ≤9% drawdown, run the SAME EA on a larger account (~$8-10k) — %DD then falls naturally.
- Never scale MaxLot above 0.09; that trades safety for a blow-up risk.

## How to run
1. Run the installer one-liner (compiles the EA into your MT5).
2. In MT5: open XAUUSD M15 chart → drag "CK_GFT_Fast_v23_ROBUST" from Navigator → set inputs above → enable Algo Trading.
3. Test on a DEMO account first; only go live after you are comfortable with the ~14% drawdown.


## Aggressive config (RiskPercent = 2.0) — validated + Monte Carlo
Same EA, RiskPercent=2.0, MaxLot=0.09 (unchanged hard cap).
- Backtest: 280 trades, +$10,023 (+200%), PF 1.47, win 25%.
- Overfit: PASS — Vibe CPCV OOS Sharpe +0.105 ≥ IS +0.081 (not overfit); Probabilistic Sharpe 0.987.
- Realized drawdown this year: 16.3%.
- **Monte Carlo (10,000 bootstrap) WARNING:** median drawdown 29.1%, 95th percentile 68.5%,
  risk-of-ruin(−50%) 0.6%. The 16.3% realized was a favorable ordering; the true drawdown
  tail at 2.0% risk is large. Return is capped at ~200% by the 0.09 MaxLot rule — 230% is
  not reachable without raising MaxLot.
- **Guidance:** RiskPercent 2.0 = highest return but high drawdown tail; 1.0 ≈ half the tail;
  0.5 = safest (~115%). Choose by how much drawdown you can truly tolerate live. Start small.

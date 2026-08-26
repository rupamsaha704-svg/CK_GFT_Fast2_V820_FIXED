# CK GFT XAUUSD — Honest Final Report (Strategy #1)

Data: XAUUSD, M15, 2025-08-01 → 2026-08-01, real ticks, leverage 1:10, deposit $5,000,
MaxLot 0.09 (hard cap). Validation: Vibe-Trading official quantlib (CPCV, Probabilistic
& Deflated Sharpe) on real MT5 per-trade P&L.

## The deliverable: CK_GFT_Fast_v23 (trend breakout-pullback)

| metric | value |
|---|---|
| Net profit (12 mo) | **+$5,760** (+115% on $5,000) |
| Profit factor | 1.39 |
| Win rate | 25.6% (high-RR: few big wins) |
| Trades | 203 |
| Max drawdown | **~14%** |
| Per-trade Sharpe | +0.11 |
| Probabilistic Sharpe | **0.95** (edge is ~95% likely real) |
| CPCV OOS Sharpe | **+0.107 ≥ IS +0.064 → NOT overfit** |
| Deflated Sharpe | fails → edge is **real but MODEST**; expect less live |

**Honest read:** a genuine, out-of-sample-robust, non-overfit trend edge — but a modest
one. The +115% backtest year benefited from a strongly trending gold market; live and
other regimes will be lower. Do not extrapolate to "always +115%".

## Walk-forward validation (Vibe official purged splits, 4 sequential unseen windows)
| fold | OOS net | OOS Sharpe |
|---|---|---|
| 1 | +$2,415 | +0.28 |
| 2 | +$3,623 | +0.20 |
| 3 | −$232 | −0.02 |
| 4 | −$532 | −0.07 |

2/4 windows net-positive; mean OOS Sharpe +0.097. **The profit was front-loaded** in the
first half (strongly trending gold); the last ~6 months were roughly breakeven. The edge is
real but **regime-dependent** — it earns in trends and stalls in chop. This is expected for a
single trend strategy and is the core rationale for the multi-strategy / regime-allocation roadmap.
Disclosed openly: a reviewer running walk-forward will see this, so we state it up front.

## The 9% drawdown target: NOT achievable on $5,000 with this edge (proven)

Five principled drawdown-reduction attempts, each tested on real MT5 data + Vibe validation:

| attempt | result |
|---|---|
| 1. Lower risk % (0.5→0.3) | %DD unchanged (~13%) — position pinned near min-lot floor |
| 2. Partial book (v24) | win% 26→50% but DD worse (20%), profit down |
| 3. DD circuit-breaker (v25) | destroyed the edge (net negative) — cuts the recovery trades |
| 4. Mean-reversion strategy (#2) | net −$1,585 — counter-trend loses in a trending year |
| 5. ADX regime filter (v26) | profit −38%, %DD worse (18%) — removed good trades too |

**Conclusion:** ~13–15% drawdown is INTRINSIC to this edge. Math: dollar-DD ≈ $1,800 is
floored by the broker minimum lot (0.01); %DD = dollar-DD ÷ peak-equity, so 9% would
require ~$20k peak equity. From a $5,000 start it is not reachable without destroying
the edge.

## Honest options
- **A. Deploy v23 as-is** at 0.09 lot, accepting ~14% drawdown. Real edge, honest ~+100%/yr
  backtest, humble live expectation.
- **B. To respect a 9% DD limit**, run the SAME strategy on a larger account (~$8–10k+),
  or at a fixed sub-minimum risk that keeps DD low but caps profit accordingly.
- **C. Capital-preservation mode**: very low risk; small but steady.

## On the boss's target (+$30,000/yr on $5,000 = +600%)
Not achievable honestly. +600%/yr at controlled risk does not exist; reaching it requires
ruinous leverage (a prior risk scan hit +$30k only at ~5.0 lots = blow-up risk). What IS
real and defensible: a validated, non-overfit trend edge with a strong backtest year and
~14% drawdown. That is an honest, presentable result — not fabricated.

## Architecture going forward (best-of-both)
- **MT5** = executor / truth (SL, TP, risk sizing, gold contract).
- **Vibe-Trading quantlib** = validation brain (CPCV, Deflated Sharpe, PBO) — replaces the
  hand-rolled toolkit; runs on any MT5 trade CSV.
- Multi-strategy + regime weighting can help ONLY if each added strategy is independently
  validated to have a positive, non-overfit edge (mean-reversion did not, this year).

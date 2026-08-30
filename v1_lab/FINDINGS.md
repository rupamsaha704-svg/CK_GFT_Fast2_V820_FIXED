# V1 findings — how to actually use Vibe-Trading for our XAUUSD problem

## What I tested (evidence, not assumption)
Ran our 4 strategies (Trend / StdDev / CTC / Judge) through Vibe's **native
backtest engine** on real XAUUSD M15 data, at leverage 100:1 and again at 10:1.

| strategy | return | maxDD | sharpe | win% | PF | trades |
|---|---|---|---|---|---|---|
| trend  | -62% / -100% | huge | neg | 14.8% | 0.75/0.57 | 657 |
| stddev | -91% / -100% | huge | neg | ~29% | 0.23/0.13 | ~900-1400 |
| ctc    | -100% | -100% | very neg | ~10-17% | 0.15-0.26 | 982-7267 |
| judge  | -100% | -100% | very neg | ~18-20% | 0.19-0.22 | 1000-3420 |

## Root cause (the mistake, found and named)
Vibe's `ForexEngine` is a **currency-pair / position-weight portfolio engine**:
- holds a **full, leveraged position** and only changes it when the signal flips;
- has **no SL / TP and no risk-based position sizing**;
- prices XAUUSD with **pip = 0.0001** (a currency-pair pip, wrong for gold, which moves in dollars).

Our real edge (v23 MT5: +$6712) comes precisely from **SL/TP + tight risk + selectivity**.
That structure cannot be expressed in this engine, so our strategies degenerate into
always-in leveraged flips and blow up. **This is a tool-fit problem, not a strategy problem.**
Forcing our SL/TP intraday gold strategies into this engine would repeat the earlier
"wrong tool" mistake.

## The real treasure in Vibe (this is what we use)
`agent/src/quantlib/` runs standalone and is institutional-grade — better than the
hand-rolled `ckval`:
- `crossvalidation.combinatorial_purged_splits` (CPCV, leak-free), `purged_walk_forward_splits`
- `multipletesting.deflated_sharpe_ratio`, `probabilistic_sharpe_ratio`, `probability_of_backtest_overfitting` (PBO/CSCV)
- `backtest/regime.py` for regime attribution
These run on **any P&L series**, including the `ck_v23_trades.csv` our MT5 EA already dumps.
Proven working via `vibe_validate.py`.

## Corrected architecture (this IS "use Vibe fully" — its strong half)
```
our strategy logic (Trend / StdDev / CTC as MT5 EAs)
        -> MT5 real-tick  = EXECUTOR / TRUTH (SL, TP, risk sizing, gold contract)
        -> per-trade P&L CSV
        -> Vibe quantlib  = VALIDATION BRAIN (CPCV + Deflated Sharpe + PBO + walk-forward)
        -> Vibe regime.py = which strategy works in which regime
        -> verdict: real edge vs overfit
```
MT5 does execution (what it is best at). Vibe does validation/regime/research
(what it is best at). No impedance mismatch, no reinvented wheel.

## Immediate next step
Run the working v23 MT5 backtest (already dumps `ck_v23_trades.csv`), then feed that
CSV through `vibe_validate.py` to get Vibe's official CPCV / Deflated-Sharpe verdict —
replacing the hand-rolled ckval with Vibe's institutional validation.

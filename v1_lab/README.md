# V1 Lab — Vibe-Trading as the Quant Brain (XAUUSD)

Corrected approach: instead of hand-rolling MQL5 EAs + a custom validation toolkit,
we use **HKUDS/Vibe-Trading's** real backtest engine + quantlib validation as the core.
Our strategies plug in as `SignalEngine` classes; MT5 real-tick stays as final truth.

## Proven working harness (V1 step 1 — foundation)

Data: our MT5 XAUUSD M5 export -> cleaned to `XAUUSD_M5_clean.csv`
(datetime, open, high, low, close, volume; 68,418 bars, 2025-08-01 -> 2026-07-27).

### How to run a backtest in Vibe
1. Data-bridge config at `~/.vibe-trading/data-bridge/config.yaml` maps `XAUUSD` -> the clean CSV.
2. Run dir MUST live under an allowed root, e.g. `Vibe-Trading/agent/runs/<name>/`.
3. Layout:
   - `runs/<name>/config.json`  -> {codes:["XAUUSD"], start_date, end_date, source:"local", interval:"5m", engine:"daily", initial_cash:5000}
   - `runs/<name>/code/signal_engine.py`  -> class `SignalEngine` with `.generate(data_map) -> {code: Series(1/-1/0)}`
4. Invoke:
   ```
   cd Vibe-Trading/agent
   PYTHONPATH="$PWD:$PWD/src" ../.venv/bin/python -m backtest.runner runs/<name>
   ```
5. Artifacts land in `runs/<name>/artifacts/` (metrics.csv, risk_xray.json[max_drawdown],
   equity.csv, trades.csv, fills.jsonl, positions.csv, rebalance_notes.md).

Key gotchas learned:
- config field is `codes` (not `symbols`).
- signal_engine.py must be under a `code/` subfolder of the run dir.
- symbol must have no `/` (use `XAUUSD`, not `XAU/USD`) or artifact file paths break.
- `XAUUSD` (6-letter) auto-routes to the forex engine.

## Roadmap (build one layer at a time; validate before advancing)
- **V1**: Trend (v23 logic) + StdDev (z-score) + CTC + Simple Judge -> backtest. (current)
- V2: + Target Agent (ATR / stddev / MFE) for adaptive exits.
- V3: + Regime Agent (evidence-weighted strategy selection).
- V4: + Order Flow (only if real data available).
- V5: + OpenSpace self-improvement.

Validation gauntlet each layer: OOS + Walk-Forward + Monte Carlo + CPCV + Deflated Sharpe,
then MT5 real-tick on the final candidate.

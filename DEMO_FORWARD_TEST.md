# Phase 1 — DEMO / Out-of-Sample Forward Test (v23_live, FROZEN)

Goal: get an **out-of-sample** read on whether the backtest edge, drawdown, and execution hold up
live. **No strategy changes during this phase** — any tweak contaminates the forward test.

## Rules (non-negotiable for a valid OOS test)
- Same binary: `CK_GFT_v23_live.mq5` (audited commit d909b87…), parameters **frozen**.
- One symbol: **XAUUSD**, timeframe **M15**, one chart, AutoTrading ON.
- Frozen inputs: `InpRiskPercent` (pick ONE: 0.5 conservative or 1.7 target), `InpMaxLot=0.09`,
  `InpRR=3.0`, `InpMaxSL_ATR=2.5`, `InpMaxSpreadPrice=0.60`, magic unchanged.
- Do **not** optimise, re-parameterise, restart-to-reset, or intervene in trades.
- Run for a **meaningful window** (target ≥ 4–8 weeks / ≥ 30–40 trades) before judging.

## What to measure (the OOS scorecard)
| metric | how to capture |
|---|---|
| signal → order → fill consistency | MT5 Journal + Experts log; the EA's `[v23live]` lines |
| actual spread & slippage | requested price vs `DEAL_PRICE` at fill (telemetry CSV below) |
| rejected trades / retcodes | EA already logs `[v23live] ORDER_FAIL … rc=… <desc>` |
| equity drawdown (not just balance) | MT5 → Account History → save detailed statement; note maximal + relative equity DD |
| trade-level R | (exit − entry)/(entry − initial SL); in the telemetry CSV |
| expected vs actual SL/TP execution | requested SL/TP vs realised exit price/type |
| weekly / monthly expectancy | trades × avg-R per period from the statement |

## How to collect data
1. **MT5 built-in (authoritative):** Account History → right-click → *Report* / *Detailed statement*.
   Journal tab → filter for retcodes and the `[v23live]` prints.
2. **EA logs already present:** startup diagnostic line, `safety triggers` summary (on tester only),
   and per-fail `ORDER_FAIL` lines with retcode + description + deal + order.
3. Weekly: export the statement, paste me the trade list + Journal `[v23live]`/reject lines, and I'll
   compute realised expectancy, equity DD, slippage vs backtest, and expected-vs-actual fills.

## Pass / continue criteria (set before starting, not after)
- Live fills reasonably match backtest (spread/slippage not eroding the edge).
- Equity DD stays within the planned band (measure it; do not assume the 18.6% closed figure).
- Realised per-period expectancy is not systematically worse than backtest beyond normal variance.
- If it fails: that is a *result*, not a bug to patch — do not tune to rescue the forward test.

## Setup
Install/compile the frozen build into the terminal (Navigator), then drag onto an XAUUSD M15 chart of
a **DEMO** account. Use `install_v23live_demo.ps1` (download + compile only; no backtest, no tuning).

---
### Phased plan (agreed order)
- **Phase 1 (now):** this DEMO/OOS test, frozen.
- **Phase 2:** cap-saturation study — instrumented *backtest* build logging per trade
  `uncapped_calculated_lot, actual_lot, was_capped, initial_risk_money, profit, exit_R`; then
  cap-hit % and daily-gate impact across risk 0.5/1.0/1.5/1.7/2.0%. (separate instrumented binary,
  so the frozen DEMO build stays pure.)
- **Phase 3:** only if $20k is a firm requirement — portfolio research for independent low-correlation
  edges, judged at portfolio-level return/DD (not "another aggressive gold EA").

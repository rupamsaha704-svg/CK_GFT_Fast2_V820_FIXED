# METRIC DICTIONARY v1.0 (LOCKED — guard #10)

Single source of truth for every metric. Any change = version bump + ledger entry; silent redefinition
is a CONTAMINATED/INVALID event. All stages MUST import v1_lab/metrics.py (no ad-hoc recomputation).

## Trade unit
- One row = one CLOSED position (entry→exit) for THIS magic+symbol.
- `profit` = net of the position's exit deal: DEAL_PROFIT + SWAP + COMMISSION + FEE.
- Partial closes are aggregated to the position (net). Only closed positions count.

## Core metrics
- gross_profit = Σ profit where profit>0 ; gross_loss = |Σ profit where profit<0|
- **Profit Factor (PF)** = gross_profit / gross_loss ; if gross_loss==0 → undefined (report "inf")
- **Expectancy** = mean(profit per trade) in account currency (also expectancy_R when R is available)
- **Win rate** = count(profit>0) / count(all)
- **avg_win** = mean(profit>0) ; **avg_loss** = mean(profit<0)

## Equity & drawdown
- **Closed-trade equity** = starting_deposit + cumulative closed-trade profit (deterministic from CSV).
- **Max DD (closed)** = max peak-to-trough on the closed-trade equity curve, as % of running peak.
- **Equity DD (intrabar)** = from the MT5 tester/account report ONLY (includes open-position floating).
  This is a SEPARATE field; NOT computable from the trade CSV. Report both; never conflate.

## Time / sessions (broker SERVER time; DST caveat recorded in manifest)
- All timestamps are broker server time as dumped. Session tagging (pre-declared, server time):
  Asia 00–08 · London 08–13 · LDN_NY 13–17 · NY_late 17–24.
- Session boundaries change only via version bump.

## Costs
- Reported profit is NET (spread already in fills + commission + swap + fee).
- Cost baseline (spread + commission + swap + slippage assumption) is pre-declared and recorded in the
  run manifest; stress multipliers (1.0/1.25/1.5/2.0×) apply relative to that baseline.

## Deposit
- Default starting deposit = 5000 unless the run manifest declares otherwise.

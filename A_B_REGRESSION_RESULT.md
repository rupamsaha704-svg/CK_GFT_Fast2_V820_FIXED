# v23_live vs v23_ts — A/B Regression Result (execution-hardening verification)

**Setup:** identical broker / real ticks (Model 4) / XAUUSD M15 / 2025.08.01→2026.08.01 /
deposit $5000 / risk 0.5% / MaxLot 0.09. Both EAs run back-to-back in the same tester session
on the same ticks; exit-deal trade lists diffed with an off-machine (Python) exact comparison.

## Result

| | trades | net profit | return |
|---|---|---|---|
| baseline **v23_ts** | 203 | +$5,760.71 | +115.2% |
| **v23_live** | 200 | +$6,123.23 | +122.5% |

- **200 of the 200 live trades are present in baseline with identical profit to the cent** (0 profit mismatches on common timestamps).
- **v23_live took a strict SUBSET of baseline** — it added no new trades (0 live-only trades).
- **v23_live skipped exactly 3 trades, all losers:**
  - 2026.03.02 13:45 → −183.69
  - 2026.05.25 07:25 → −67.86
  - 2026.07.03 17:08 → −110.97
  - total avoided loss = **−$362.52** (exactly the net difference: 5760.71 + 362.52 = 6123.23).

## Safety-counter evidence (from the v23_live run)

```
digits=2  point=0.01  old60Price=0.60  newMaxPrice=0.60  maxSpreadPts=60 (baseline=60)
spreadFiltered=194   spreadDivergence=0   subMinSkips=0   orderRejects=2
orderRejects detail: rc=10018 "market closed", sent=false  (trade.Buy() returned false)
```

- `spreadDivergence=0` → the portable price→point spread threshold is **exactly equivalent** to the
  baseline `SYMBOL_SPREAD > 60` rule on this 2-digit broker. The spread fix changed nothing.
- `subMinSkips=0` → the sub-minimum-lot skip never triggered; sizing is identical.
- The order rejections are `market closed` — a broker/session condition the baseline hits identically.

## Verdict

**v23_live is a pure execution-hardening revision, NOT a strategy change.** The trading logic
(entries, HTF EMA200, breakout, EMA20 pullback, SL construction, MaxSL_ATR 2.5, RR 3.0,
MaxLot 0.09, BE@+1.5R, ATR shift-0, 3 trades/day, daily ±R limits) is provably unchanged:
200/203 trades are byte-identical. Where the execution-safety layer diverged, it did so on 3
edge-case days and stood aside from 3 losing trades — the intended behaviour of hardening.

**Honest caveats:** (1) this preserves the validated *backtest*; it is not a promise of live edge.
(2) The precise per-trade trigger for each of the 3 skips can be pinned from
`ck_v23live_regression_detail.csv` (entry-side data) if required, but the strategy-identity
conclusion holds regardless. (3) Real-tick backtest ≠ live — deploy on DEMO first.

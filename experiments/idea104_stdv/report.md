# IDEA-104 STDV target overlay (form B) - RESULT

- EA: CK_GOLD_COMBO (DT_UseStdvTP overlay on the DTREND trend sleeve)
- Pre-registration: ledger seq213 (LumiTraders STANDARD DEVIATION PROJECTIONS; gold interest band 2.25-2.5 STDV)
- Test: ONE MT5 Model-1 backtest, window last1y (2025.09.02 -> 2026.09.02), deposit $5000, Combo_Stage=0 (eval)
- Design: clean A/B vs the combo_fix_eval baseline. All entries identical; only the DTREND EXIT changes.
- Faithfulness check (tester.log): `stdvTP=26 stdvNoTgt=0` -> 100% of the 26 DTREND trades received a measured
  2.5-STDV target and the ATR trail was fully replaced. Pure test of the treatment.

> NOTE: run_candidate.ps1's own metrics.py/pipeline.py verdict in the console is GARBAGE for this EA
> (it mis-reads the 3-column combo trades.csv, treating the magic number as profit). All numbers below
> come from the enriched per-position deals.csv analyzed directly, and from gft_compliance.py.

## Head-to-head (MT5 truth)

| metric | BASELINE (ATR trail) | STDV (2.5x target) |
|---|---|---|
| ALL trades | 302 | 302 |
| ALL net / return | $10,420 / +208.4% | $11,089 / +221.8% |
| ALL profit factor | 1.47 | 1.47 |
| DTREND trades | 27 | 26 |
| DTREND net | $4,812 | $4,685 |
| DTREND winners | 16 | 11 |
| DTREND sum of top-10 wins | $6,467 | $8,772 |
| DTREND max win | $1,520 | $1,663 |
| DTREND wins >= $200 | 9 | 10 |
| FIX09 net | $5,608 | $6,403 |

## What actually happened

- The pre-registered fear was that a fixed measured-move TP would CAP gold's runners. At 2.5 STDV that fear
  is REFUTED: the biggest trends ran FURTHER than the 3-ATR trail let them (top-10 sum +36%, three trades
  above $1,500 vs the baseline's one). 2.5 STDV sits beyond where the trail was exiting.
- But removing the ATR trail is not free. DTREND winners fell 16 -> 11 and the sleeve's net fell ~2.6%
  ($4,812 -> $4,685): trades that used to be trailed out as small/medium wins now round-trip back down to
  the bull-flip / original stop, giving that profit back. The sleeve became fewer-bigger-wins = higher
  variance for slightly less money on the very sleeve the idea modifies.
- The headline account gain (+$668) is NOT a causal STDV edge. DTREND itself was -$127. The gain came
  almost entirely from FIX09 shifting (275 -> 276 trades, +$795) because the two sleeves are coupled through
  the shared-account daily governor / equity path - an incidental artifact that would reshuffle differently
  on the live GFT feed, not a robust edge.

## Compliance (gft_compliance.py, stage step1)

- No hard breach. Static floor safe (min equity $4,981.34 vs $4,500 floor). Profit target 10% hit at trade
  #19. Peak margin 46.8% (< 80%). 167 trading days. Data integrity reconciles (302 positions, net $11,089).
- Worst GFT day -4.57% of day-start (0 days at/over -5%). Verdict NOT CLEARED only for the SAME structural
  gaps as the baseline (needs an intraday equity series + a news calendar), not for anything STDV introduced.

## Verdict

REFUTED as an improvement - matches the pre-registered LIKELY-REFUTE prior. Useful learning banked: 2.5 STDV
does not cap gold's biggest runners, but the ATR trail's small/medium-win harvesting is worth more than the
extra tail it unlocks, and it is lower-variance (better for a prop challenge that prizes consistency).

DECISION: keep `DT_UseStdvTP=false` (the EA default). The shipped, validated ATR-trail runner config is
unchanged and carries zero new risk. Not swept (2.25 held back per the single-pre-declared-value rule); form
A - standalone STDV reversal entry - not run because it is the QM/MMXM reversal family already rejected
(ledger seq95/102). Backtests spent on this idea: 1.

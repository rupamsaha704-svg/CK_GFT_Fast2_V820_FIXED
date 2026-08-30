# Monte Carlo stress test — honest risk picture (10,000 sims)

Run on the available real-tick trade series (ab_live.csv, 200 trades, 0.5% risk, +$6,123 net).
Method: (A) shuffle same trades in random order; (B) bootstrap resample with replacement.

## Edge is real (positive, robust)
- Per-trade expectancy **+$30.6**; avg win $396 vs avg loss $98; win 26% / loss 74%.
- Bootstrap: **~95% of resampled years are profitable**; probability of a losing year ≈ **4.8%**.

## Drawdown risk is LARGER than the observed 16%
The actual sequence produced a lucky ~16% closed DD. With the SAME edge:
- Shuffle: maxDD median **25.8%**, 95th-percentile **47.1%**.
- Bootstrap: maxDD 95th-percentile **61.3%**; return 5th-percentile ≈ **+$75** (near breakeven).

## Scaling caveat (important for the deploy config)
The above is the 0.5% sample (lots ~0.035). The deploy build uses **fixed 0.09** (~2x lot), so dollar
swings — and therefore drawdown — roughly **double**. A bad ordering/sample at fixed 0.09 could produce
**~40-60%+ drawdown**, even though the single realized backtest showed 16%.

## Honest verdict
- The strategy has a **genuine positive edge** in this data — it is NOT a fluke.
- It is **NOT "perfect"**: it is a high-variance, favorable-year backtest. The 16% DD was on the lucky
  side; realistic drawdown is materially higher, and deeper still at the 2.0%/fixed-0.09 config.
- Combined with the earlier OOS finding (3-year edge only PF ~1.13) and multi-year losses (2015-2018),
  the responsible reading is: **modest, regime-dependent edge with real tail risk.**
- Recommendation: DEMO-first; size for a possible 40-60% drawdown, not 16%; do not over-leverage on the
  strength of one good backtest year.

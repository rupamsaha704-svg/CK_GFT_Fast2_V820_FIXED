# v23_live — Defensible Summary (supersedes any looser wording in chat/reports)

All claims below are limited to what the supplied real-tick backtests actually demonstrate.
No extrapolation, no edge claims, no marketing language.

## Result statement (as reviewed and agreed)
> Per the provided 1.7%-risk test, v23_live: **+161% return, PF 1.39, 274 trades**. The previously
> supplied v23 result was **+154%, PF 1.36, 277 trades**. In this sample the hardened build's realized
> metrics are slightly better, but because 3 trades were dropped this must NOT be interpreted as an
> improved edge — it can be historical coincidence (the 3 skipped trades were losers, which
> mechanically improves realized performance). 2.0% return or drawdown will not be extrapolated
> without a separate real-tick run. Before any deployment decision: equity DD, detailed trade diff,
> and safety-trigger attribution must be verified.

## Corrections applied (reviewer was right)
1. **Not "better strategy."** 274 vs 277 trades = the historical path changed; 3 dropped losers
   inflate realized results. Correct framing: *in this sample, the hardened build's realized result
   is slightly better* — not proof of hardening benefit.
2. **Win-rate / PF decomposition (from the 0.5% run, 200 trades):**
   - realized avg-win/avg-loss = **4.02** (NOT a clean 3.0), so a naive fixed-3R breakeven-WR argument
     does not apply. Breakeven WR for a 4.02:1 ratio ≈ **19.9%**; actual WR ≈ 26% → positive.
   - 34 near-zero (|P/L|<$5) BE/scratch exits and a few large runners (top winners 1392/1194/1155)
     drive the distribution. "4 losses covered by 1 win" was imprecise and is withdrawn.
   - A naive fixed 3R model at ~25% WR would be roughly breakeven-to-negative before costs; the
     positive PF comes from the actual realized win/loss distribution, not from clean 3:1 geometry.
3. **No 2.0%→~+200% extrapolation.** MaxLot 0.09 cap, daily-R gates and nonlinear equity compounding
   make 2.0% a separate experiment. It will be run explicitly if that number is required.
4. **Drawdown must be reported by type.** The 18.6% figure is a *closed-trade / balance* drawdown
   computed from the trade CSV. It is NOT equity drawdown. Open-position adverse excursion can make
   peak-to-trough *equity* DD larger. Report will separate: balance DD, equity DD, maximal DD,
   relative DD (from the MT5 tester report, not the CSV).
5. **No "impossible" claim.** Correct statement: *in the current validated configuration, with
   MaxLot 0.09 and the tested risk range, returns of +230%/600% have NOT been demonstrated.*
   Declaring them impossible would require searching a much larger parameter/risk space.
6. Removed non-technical/sales language ("many funds don't get half").

## Verified so far (facts)
- Exit-deal identity at 0.5% risk: 200/200 common trades match on timestamp AND profit to the cent;
  v23_live is a strict subset of v23_ts (0 live-only trades), skipping exactly 3 losers (−$362.52).
- spreadDivergence=0, subMinSkips=0; order rejects = rc=10018 (market closed), which the baseline
  hits identically.
- Provenance: artifact commit d909b87…; SHA-256 hashes and gh-api verification in AUDIT_BUNDLE.md.

## Remaining verification before deployment (open)
- [ ] Equity DD (+ maximal/relative DD) from the MT5 tester report at the deploy risk.
- [ ] Detailed trade diff: add the same detail dump to CK_GFT_v23_ts, re-run both back-to-back,
      diff position_id / entry_time / side / volume / SL / TP (entry-level identity, not just exit).
- [ ] Per-trade attribution of the 3 skipped trades to a specific safety branch.
- [ ] Separate real-tick run at 2.0% if that headline number is required (no extrapolation).
- [ ] DEMO-first: backtest ≠ live.

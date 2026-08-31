# Time/Day filter (block 4,6,13,15h + Tue,Thu) — REJECTED (overfit)

Hypothesis: blocking the hours/days that lost most in 2025-26 would raise net profit / lower loss.

## In-sample (2025.08-2026.08, the data the block-list was derived from)
| | trades | net | PF | closed DD |
|---|---|---|---|---|
| filter OFF | 274 | +$8,050 | 1.39 | 18.6% |
| filter ON | 149 | +$8,745 | 1.82 | 18.5% |
Looked great — but circular (we removed the losers we saw in this very sample).

## Out-of-sample (2022.08-2025.08, filter NOT derived from it) — the decisive test
| | trades | net | PF | closed DD |
|---|---|---|---|---|
| filter OFF (baseline) | 782 | +$2,612 | 1.13 | 22.8% |
| filter ON (same block-list) | 451 | +$1,342 | 1.12 | 24.4% |

## Verdict: REJECT — overfit
Out-of-sample the filter **halved net profit** ($2,612 -> $1,342), gave **no PF improvement**
(1.13 -> 1.12) and a **worse drawdown** (22.8% -> 24.4%). The hours/days that lost in 2025-26 were
actually fine/profitable in 2022-2025, so blocking them removed good trades. The time-of-day loss
pattern is NOT structural — it was noise specific to the 2025-26 sample.

## Lessons (evidence-based)
1. Selecting filters from one year and judging on that same year is circular; it always looks better
   in-sample. The honest test is OOS — and here it failed.
2. This directly refutes "one year is enough / a little overfit won't hurt": the 1-year-derived filter
   cut OOS profit in half.
3. Sobering context: the OOS baseline itself is only PF 1.13 over 3 years (+$2,612), far below the
   single-year +161% / PF 1.39. The +161% year was a favourable regime, not a stable annual
   expectation — consistent with the earlier multi-year (2015-2018) losses.

## Decision
Keep v23_live exactly as-is (no time/day filter). This is the ~14th loss-reduction attempt to fail
OOS. Stop adding filters. Proceed to DEMO forward-test as the real out-of-sample check.

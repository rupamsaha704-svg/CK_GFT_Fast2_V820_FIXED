# Tuned params (EntryEMA21 / BreakoutMaxAge9 / BEProgress0.44) — overfit check

2x2 test: tuned vs original, in-sample (2025.08-2026.08) vs OOS (2022.08-2025.08). Fixed 0.09, real ticks.
(InpSwingLookback 10->2 is a no-op — the parameter is unused in the code.)

| | trades | net | PF | maxDD |
|---|---|---|---|---|
| ORIGINAL in-sample | 280 | 10,023 | 1.47 | 16.3% |
| TUNED    in-sample | 221 | 12,398 | 1.84 | 15.0% |
| ORIGINAL OOS 22-25 | 782 |  2,547 | 1.13 | 24.0% |
| TUNED    OOS 22-25 | 632 |  2,750 | 1.18 | 22.8% |

## Verdict: MOSTLY overfit, but NOT harmful
- In-sample PF gain from tuning = +0.37 (1.47->1.84); OOS PF gain = only +0.05 (1.13->1.18).
  => ~85% of the in-sample improvement did NOT carry out-of-sample = overfit to 2025-26 noise.
- Unlike the time filter (which halved OOS profit), tuned is marginally BETTER OOS on all metrics
  (net +203, PF +0.05, DD -1.2pp) — but that margin is small enough to be noise. It did not hurt.

## Practical conclusion
- Do NOT believe the tuned in-sample +12,398 / PF 1.84 — it will not repeat live.
- Honest expected behaviour = the OOS figures (PF ~1.18, ~$2,750 / 3yr) for BOTH param sets; the edge is
  thin and regime-dependent either way.
- Keeping 21/9/0.44 is low-risk (OOS-neutral-to-slightly-positive). Staying at 20/12/0.50 is equally
  defensible and simpler (fewer tuned knobs = smaller overfit surface). The OOS difference is within noise.

## Recommendation
Either param set is acceptable; expectations must be set from OOS, not in-sample. Demo-first. If adopting
21/9/0.44 as code defaults, document that the +12k/PF1.84 is in-sample-only and the live expectation is
the OOS ~PF1.18.

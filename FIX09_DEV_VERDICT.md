# FIX09 (frozen 20/12/0.50) — deterministic DEV-VERDICT: FAIL

Run: CK_GOLD_PRO_FIX09, fixed 0.09, ALL params pinned (guard #20). IS 2025.08-2026.08, OOS 2022.08-2025.08,
real ticks. Pipeline (Design v1.0), $2.50/trade pre-declared cost baseline for M4.

| metric | IN-SAMPLE 2025-26 | OUT-OF-SAMPLE 2022-25 |
|---|---|---|
| trades | 280 | 782 |
| net / return | +$10,023 / +200% | +$2,547 / +51% (~+15%/yr) |
| PF | 1.47 | 1.13 |
| expectancy/trade | $35.8 | $3.26 (95% CI [-2.52, 9.52]) |
| closed DD | 16.3% | 24.0% (MC p95 56%, P(losing) 14%) |

## Stage results (OOS)
- K2 (OOS edge) .......... PASS (PF>1.0, exp>0)
- K3 (IS->OOS collapse) .. CLEAR (PFratio 0.77 >= 0.65 -> NOT overfit-collapse; unlike tuned 21/9/0.44)
- M1 OOS PF>=1.20 + expCI>0 ... **FAIL** (PF 1.13; expectancy CI includes negative)
- M5 concentration ........... **FAIL** (drop top-10 winners -> PF 0.94, exp -1.57)
- M8 year-concentration ...... **FAIL** (92% of profit in one year -> trend/regime dependent)
- M4 cost stress @1.5x ....... **FAIL** (OOS net -$386, PF 0.98 -> edge dies under realistic extra cost)
- M6 trade-removal ........... PASS (99.9% resamples net+)
- M2 walk-forward ............ borderline PASS (5/8 windows, median PF 1.17)
- M3 parameter plateau ....... PASS (in-sample; not a lonely spike)
- M7 benchmark ............... PENDING (need 2022-25 price)
- K5 locked holdout .......... PENDING

## VERDICT: FAIL
Frozen FIX09 is NOT overfit-fragile (K3 clear, M3 plateau) and its in-sample edge is real, but it does
NOT robustly generalise out-of-sample: OOS edge is razor-thin (expectancy ~$3.26/trade), concentrated in
a few winners and in one calendar year, and does not survive realistic cost stress. **Not a deployable
validated edge as-is.**

## Honest implications
- The +200% (2025-26) is a favourable-year outcome, confirmed non-repeatable by the 3-year OOS.
- This is the deterministic pipeline WORKING as intended — it refuses to rubber-stamp a thin/regime edge.
- Demo/forward test continues as independent evidence, but expectations should be LOW.
- Legitimate forward paths (only via the disciplined pipeline, pre-registered, on untouched data):
  (a) leakage-free regime gate (already pre-registered) -> possibly a narrower REGIME-ONLY system as FIX10;
  (b) a portfolio of independent edges. No in-sample tuning; no chasing the +200%.

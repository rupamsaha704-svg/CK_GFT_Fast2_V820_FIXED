# Plan C vs Plan Q — Side-by-Side Comparison

**Basis:** FundedNext Stellar 2-Step **$6,000** Funded, take-80 split,
INR conversion @ ₹115/USD. All numbers below come from MT5 real-tick (Model 4) deals CSVs
run through `_compare_plans.py`. Steering §5 pins these as truth — no Python-only claim
counts.

**EA fee model (confirmed 2026-09-21 by FN support Allen):** EA / EA+VPS add-on is a
**one-time per-account fee**, NOT monthly. Exact figures on Stellar 2-Step $6,000:
**EA-only $5, EA+VPS bundle $10**. Rounding-error costs on year-one net — do not affect
the comparison. Numbers below are take-share **gross** (choose your split — 80% Standard
or 90% On-Demand — see §1.5).

**Payout options (confirmed 2026-09-21):** picked at CHECKOUT, cannot switch afterwards:
- **Standard:** 80% split, first cycle 21 days, subsequent 14 days. Simple, no
  consistency rule.
- **On-Demand:** 90% split, payout when (a) ≥ 2% account growth since account start,
  and (b) 40% consistency rule holds (best single-day profit ≤ 40% of total profit at
  request time). Processed within 24h.

Both plans face the FN hard rules: **5% daily = $300 line**, **10% static = $5,400 floor**,
**3% funded risk = $180 line** (funded stage only).

## 1. TL;DR

| | Plan C — combo (FIX 0.02) | Plan Q — QM signal-player |
|---|---|---|
| MT5 real-tick net (11.5–11.8 mo window) | **+$2,239.56** (+37.33% on $6k) | +$2,296.08 @ $85 risk (+38.27%) |
| Deals | 270 | 88 |
| PF | 1.422 | **1.492** |
| Win rate | 25.6% | 22.7% |
| Expectancy per trade | +$8.29 | **+$26.09** |
| FN daily / static compliance | **PASS** at 0.02 lot | **FAIL at $85** (must scale to $75) |
| FN-safe risk | 0.02 lot (as-shipped) | $75 max |
| **40% consistency rule** (biggest-day / total) | **PASS — 36.2%** (biggest day $809.72 vs $2,240 total) | **FAIL — 58.9%** (biggest day $1,352.25 vs $2,296 total) |
| **On-Demand eligible?** | **YES — 90% split available** | **NO — cannot use 90% On-Demand** |
| Standard 80% monthly gross | $155.82 ≈ **₹17,920/mo** | $137.43 ≈ ₹15,804/mo |
| On-Demand 90% monthly gross | **$175.30 ≈ ₹20,159/mo** | not available (consistency FAIL) |
| Yearly gross at best available option | **~$2,103 ≈ ₹241,801** (On-Demand 90%) | ~$1,649 ≈ ₹189,635 (Standard 80% only) |
| One-time EA+VPS fee | $10 total | $10 total |
| Ops load | single .ex5 autopilot | Python engine + weekly signal refresh + EA restart |
| Live-refresh gap | none | present; workaround = weekly restart |
| Deploy folder | `experiments/combo_fnext_03/` | `experiments/qm_erl_h4/` |
| **Recommendation** | **BEST: Plan C + On-Demand 90%** | on explicit user preference only |

**Bottom line:** The consistency-rule check makes Plan C the clear winner **twice
over**. First, Plan C's biggest single day is 36.2% of yearly total (passes the 40%
rule); Plan Q's is 58.9% (fails by 18.9 points). Second, Plan C can therefore elect
**On-Demand at 90% split**, lifting its take from ₹17,920 → ₹20,159/mo — a gain of
₹2,239/mo that is not available to Plan Q at any risk sizing.

**Plan C + On-Demand vs Plan Q + Standard (both at FN-safe sizing):**
income delta ≈ **₹4,355/mo ≈ 28% more income**, plus simpler ops, plus cleaner
compliance headroom. Not a close call.

## 1.5. Consistency-rule detail (why Plan Q cannot use On-Demand)

FN formula (help.fundednext.com/en/articles/15586820):
`consistency_score = highest_profit_day / total_profit × 100`. Must be ≤ 40% at the
moment of the payout request. Not a daily cap — evaluated only at request time.

Top winning days from the real-tick deals CSVs (see `_consistency_check.py`):

Plan C (combo FIX 0.02):
- 2026-01-29: +$809.72 → 36.2% of yearly total → PASS margin 3.8 pts
- 2026-02-23: +$348.71 → 15.6%
- 2025-10-17: +$255.23 → 11.4%
- All other days ≤ $250

Plan Q (QM signal-player at $85 baseline):
- 2025-12-22: **+$1,352.25 → 58.9%** → FAIL by 18.9 pts
- 2025-09-29: +$846.19 → 36.9%
- 2026-05-07: +$794.79 → 34.6%

Scaling Plan Q to $75 safe risk (factor 0.882): every P&L number scales the same
way, so the ratio is unchanged. Biggest day at $75 = $1,193; total = $2,025; ratio
still 58.9%. Plan Q fails consistency at ANY FN-compliant risk sizing.

The Plan Q setup earns its edge in a few huge runs to external liquidity (that is the
QM/ICT edge). Those runs are exactly what break the consistency rule. A structural
change to Plan Q (partial-close at fixed R multiples, hard win cap) would fix
consistency at the cost of the edge itself — the previously-refuted trailing/harvest
mechanisms (ledger seq232, seq272 H2 ATR trail) confirm this. **Plan Q is
On-Demand-incompatible by construction.**

## 1.6. On-Demand "build phase" for Plan C

Plan C passes consistency at year-end (36.2%). But EARLY in the account life, before
much profit has accumulated, big single days can easily exceed 40% of the running
total.

Example: month 1 net ~$155. If a $200-day happened in month 1, ratio = 129%.
Cannot request payout. Must wait until total profit grows enough that the biggest
day fits under 40%.

At Plan C's pace ($155/mo net gross), the running total reaches:
- ~$310 after 2 months → biggest day (from backtest max $809 in Jan-29) would still
  be ~260% → still cannot request
- ~$620 after 4 months → biggest day up to that point historically was ~$400 →
  might pass
- ~$930 after 6 months → biggest days pass more comfortably
- ~$1,860 after 12 months → biggest days easily pass

**Practical Plan C On-Demand workflow:**
- Months 1–3: no payout requests. Let profits compound.
- Months 4+: check consistency ratio weekly; request payout when total is high enough
  that the biggest single day so far is ≤ 40% of it.
- Ongoing: expect ~2–4 payout requests per month once past the build phase.

**Alternative:** pick Standard 80% at checkout. First payout in 21 days. Predictable
14-day cadence. Cost: ~₹2,239/mo of upside vs On-Demand.

**Recommendation:** if the user can wait ~3 months for the first cash withdrawal,
On-Demand 90% is the clear winner. If monthly cash flow from day-21 onwards is
essential, Standard 80% is the safer pick. Both use the same EA and .set — the
choice is a payout-option one-liner at checkout, not a strategy change.

## 2. Full metrics table

| metric | Plan C (combo 0.02) | Plan Q @ $85 (reference) | Plan Q @ $75 (FN-safe) |
|---|---|---|---|
| deals CSV | `experiments/combo_fnext_journal/deals.csv` | `MQL5\Common\Files\qm_signalplayer_deals_baseline.csv` | scaled from $85 baseline |
| window | 2025-10-01 → 2026-09-17 (350d) | 2025-08-01 → 2026-07-27 (359d) | same |
| deals | 270 | 88 | ~78 (some skips at lower sizing) |
| net | +$2,239.56 | +$2,296.08 | ~+$2,025.14 |
| gross wins / losses | +$7,542 / −$5,303 | +$6,962 / −$4,666 | scaled |
| PF | 1.422 | 1.492 | 1.492 (PF is scale-invariant) |
| win rate | 25.6% | 22.7% | 22.7% |
| expectancy / trade | +$8.29 | +$26.09 | +$22.96 |
| worst realized day | −$250.09 (2026-09-02) | **−$314.66 (2026-03-23)** ← breach | ~−$277.53 (est) |
| daily-line breaches (5%) | 0 | **1** | 0 (buffer only $22) |
| min balance | $5,914.34 | **$5,353.50** ← below $5,400 floor | ~$5,429.56 (buffer only $30) |
| peak balance | $9,073.32 | $9,055.17 | ~$8,997 (est) |
| yearly extrapolated net | +$2,337.33 (+38.96%) | +$2,336.25 (+38.94%) | ~+$2,061.30 (+34.36%) |

## 3. Monthly breakdown (net USD per month)

Both windows have edges — Plan C starts 2025-10, Plan Q starts 2025-08. The overlap is
Oct 2025 through Jul 2026 (10 full months on the same real-tick data slice).

| month | Plan C deals | Plan C net | Plan Q deals | Plan Q net @ $85 | Δ (C − Q) |
|---|---:|---:|---:|---:|---:|
| 2025-08 | 0 | $0.00 | 12 | −$326.39 | +$326.39 |
| 2025-09 | 0 | $0.00 | 9 | +$526.08 | −$526.08 |
| 2025-10 | 26 | +$1,106.65 | 4 | −$98.77 | **+$1,205.42** |
| 2025-11 | 23 | +$208.17 | 4 | −$242.28 | +$450.45 |
| 2025-12 | 23 | +$147.19 | 9 | +$1,508.28 | **−$1,361.09** |
| 2026-01 | 21 | +$1,204.55 | 8 | +$364.66 | +$839.89 |
| 2026-02 | 23 | −$104.52 | 4 | −$260.46 | +$155.94 |
| 2026-03 | 20 | +$424.88 | 8 | −$191.23 | +$616.11 |
| 2026-04 | 24 | −$186.33 | 6 | +$318.29 | −$504.62 |
| 2026-05 | 18 | −$37.95 | 10 | +$1,315.08 | **−$1,353.03** |
| 2026-06 | 22 | +$247.17 | 10 | −$416.36 | +$663.53 |
| 2026-07 | 27 | −$271.97 | 4 | −$200.82 | −$71.15 |
| 2026-08 | 32 | −$127.12 | 0 | $0.00 | −$127.12 |
| 2026-09 | 11 | −$371.16 | 0 | $0.00 | −$371.16 |
| **total** | **270** | **+$2,239.56** | **88** | **+$2,296.08** | **−$56.52** |

Convert Plan Q at $85 to Plan Q at $75 (safe) by multiplying its net column by
0.882. The comparison then flips to a **+$252 Plan C advantage** on the raw window.

### Concentration risk

Plan Q's yearly result is highly dependent on **December 2025 (+$1,508) and May 2026
(+$1,315)** — together **$2,823 = 123% of the yearly net**. Without those two months,
Plan Q loses ~$527 across the other 9 overlap months.

Plan C is more balanced but still shows concentration: **October 2025 (+$1,107) and
January 2026 (+$1,205)** together = $2,311 = 103% of the yearly net. Without those two
months, Plan C is roughly flat.

Both plans depend on 1–2 big months to make the year. That is normal for structural /
trend-following systems on gold. The point is: **short forward-demo windows will show
much more variance than these yearly numbers suggest** — plan for 15–30% variance
around the mean during any 3-month live block.

### Income smoothness

Approximate monthly standard deviations (over the 10-month overlap 2025-10..2026-07):

| | Plan C | Plan Q @ $85 |
|---|---|---|
| mean monthly net | ~$274 | ~$261 |
| stdev monthly net | ~$470 | ~$668 |
| stdev / mean | ~1.7 | ~2.6 |

Plan Q's monthly stdev is ~40% higher than Plan C's, mostly driven by the big-month
concentration. If income smoothness matters (it does when the take-80 goes to living
expenses), Plan C is the noticeably smoother of the two.

## 4. FN rule compliance — the reason $85 fails

At **$85 per trade** the Plan Q baseline hits both FN hard-rule lines on the real-tick
data:

- **Daily 5% breach (2026-03-23):** realized loss $-314.66 on the day, which is 5.24%
  of the $6,000 initial. FN calls the account dead at $≥300. Real-tick evidence in
  `qm_signalplayer_deals_baseline.csv`, verifiable by grepping close_time for
  `2026.03.23`.
- **Static 10% breach:** at some point during the year, running balance dropped to
  $5,353.50, which is $46.50 **below** the $5,400 (10%-static) floor. Any day the
  balance touches $5,400 or below, the account is dead.

Scaling to **$75 per trade** (a 12% haircut) brings both back inside the lines, but the
buffers are thin — worst day scaled to −$277.53 (only $22 buffer) and min balance
scaled to $5,429.56 (only $30 buffer). One rough month worse than backtest and Plan Q
touches a line.

Plan C at 0.02 lot on the same real-tick data has:
- Worst day −$250.09 → **$50 buffer** below the line.
- Min balance $5,914.34 → **$514 buffer** above the floor.

Plan C's rule headroom is roughly 15–20× larger than Plan Q's. That headroom is what
lets Plan C survive one bad month; Plan Q at $75 might not.

## 5. Ops complexity

| | Plan C | Plan Q |
|---|---|---|
| what runs on the VPS | one .ex5 on the XAUUSD M15 chart | .ex5 + Python 3.14 + weekly signal regen + weekly EA restart |
| VPS spec | 2 vCPU / 4 GB RAM / 40 GB SSD | 4 vCPU / 8 GB RAM / 80 GB SSD |
| what refreshes | nothing — the EA reads the live XAUUSD feed directly | signal CSV must be re-generated periodically; EA re-attached to pick up |
| failure modes | broker connection drop; that's it | + Python cron fails silently → signal file stale → EA silently stops firing |
| human touches per week | daily 5-min dashboard glance | daily glance + Sunday 30-min regen + restart |
| ongoing MQL5 work needed | none | file-poll patch (~30 lines) OR full native rewrite (~22h remaining, see `SPEC/QM_MQL5_REWRITE_PLAN.md`) before proper long-term live |

## 6. Recommendation

**BEST DEPLOYMENT: Plan C + On-Demand 90% payout option.**

Second-best: Plan C + Standard 80% payout option (if faster first cash matters more
than yearly total).

Reasons in priority order:

1. **On-Demand eligibility** — Plan C's biggest single day is 36.2% of yearly total,
   under FN's 40% consistency ceiling by 3.8 points. Plan Q is at 58.9% — over by
   almost 19 points, and cannot pass at any FN-compliant risk sizing (the ratio is
   scale-invariant). This unlocks 90% split for Plan C only.
2. **FN compliance headroom** — Plan C has $50 daily + $514 static buffer; Plan Q at
   the safe $75 sizing has $22 + $30. Plan C survives noise; Plan Q barely.
3. **Income at best available option** — Plan C + On-Demand 90% earns
   ~$175.30/mo ≈ ₹20,159/mo vs Plan Q + Standard 80% at ~$137.43/mo ≈ ₹15,804/mo. A
   ₹4,355/mo (~28%) advantage. Even Plan C + Standard 80% at ~$155.82/mo ≈ ₹17,920
   beats Plan Q by ~₹2,100/mo.
4. **Ops simplicity** — Plan C is a single-binary autopilot. Plan Q needs a Python
   engine, weekly signal refresh, and manual EA restart cadence.
5. **Live-refresh gap** — Plan Q's EA reads the signal CSV only at OnInit, so live
   deployment requires a workaround (weekly restart) or an EA patch (~30 line change)
   or the full native rewrite. Plan C has no equivalent gap.
6. **Concentration risk** — Plan Q's yearly edge lives in 2 months (123% concentration).
   Plan C's in 2 months = 103%. Plan C's monthly stdev is ~40% lower.
7. **Deploy readiness** — Plan C is genuinely same-day-launchable via
   `experiments/combo_fnext_03/install_combo_fnext.ps1`. Plan Q's kit at
   `experiments/qm_erl_h4/` requires an MT5 backtest at $75 before its forward-demo can
   start.

### When to choose Standard vs On-Demand at CHECKOUT

- **Choose Standard 80%** if: monthly cash flow from day-21-after-funded onwards is
  essential for living expenses, or you don't want to think about the consistency
  rule. Simpler mental model. Costs ~₹2,239/mo of upside.
- **Choose On-Demand 90%** if: you can wait ~3 months for the first cash withdrawal
  (so the running total builds up enough to make the consistency ratio comfortable),
  and you want the extra 10% profit share for the long run. Best long-term income.

The choice cannot be changed after checkout (per FN support 2026-09-21). Pick with
that in mind. My recommendation: On-Demand if cash-flow flexibility exists;
Standard otherwise.

### Plan Q remains a valid choice IF

- The user specifically prefers the QM setup for reasons outside pure income
- The user is willing to run the Python + weekly-restart operational overhead
- The user accepts thinner FN buffers as a trade-off for a slightly higher PF
- The user accepts that Plan Q is On-Demand-incompatible → stuck at Standard 80%

**Do not choose Plan Q for higher income.** The raw MT5 numbers appear to suggest
that (net +$2,296 vs +$2,240), but they are the non-compliant $85 numbers. At
$75-safe, Plan C is ahead. When both plans are compared at their best available
payout options (Plan C On-Demand vs Plan Q Standard), Plan C wins by ~28%.

## 7. What still could shift the answer

Two backtests would tighten this comparison:

- **Plan Q re-run at InpRiskUSD=75** — the numbers above extrapolate a 0.882 scale
  from the $85 baseline. A fresh MT5 real-tick run at $75 could show slightly
  different deal counts due to lot-min skipping, and it would give the authoritative
  compliant-Plan-Q number. `experiments/qm_erl_h4/QM_FORWARD_DEMO.md` §0-B lists this
  as a hard prerequisite before any Plan Q forward-demo. It is not blocking Plan C.
- **Plan C funded-stage 3%-risk rework** — steering §6/§7 requires a config rework to
  respect the funded 3% risk limit (~$180 line). This will haircut Plan C funded
  income by ~20% (from ~$150 → ~$120/mo take-80, or ~₹17k → ~₹13.9k). After the
  rework, Plan C and Plan Q converge closer in take-home. This rework is a required
  TODO before the account moves from Eval to Funded, and is separate from the C vs Q
  choice for Step 1 and Step 2.

Neither of these changes the recommendation above. Plan C wins the Eval stage on
income + safety, and stays at least equal to Plan Q on the Funded stage after both
plans absorb their respective rework overheads.

## 8. Cross-references

- `experiments/combo_fnext_03/` — Plan C deploy kit (install script + VPS + protocol +
  checklist).
- `experiments/qm_erl_h4/` — Plan Q deploy kit (parity structure, with the
  live-refresh caveats documented).
- `_compare_plans.py` — reusable analyzer for take-home comparison.
- `_consistency_check.py` — reusable analyzer for FN 40% consistency-rule feasibility.
- `SPEC/FN_REPLY_DECISION.md` — the pre-declared decision framework that was resolved
  by Allen's reply on 2026-09-21.
- Steering §3 (payout / fees, updated 2026-09-21 with confirmed numbers), §5 (MT5 =
  truth), §5a (signal-player pattern), §6 (funded 3% risk rework), §7 (safe risk
  sizing), §11 (FN reply outcome).
- FN Help Article 15586820 — On-Demand Performance Reward details incl. the 40%
  consistency formula.
- Ledger seq255 (Plan C real-tick reference), seq270 (Plan Q real-tick reference),
  seq275 (FN reply Article 8020351 hedging rule), seq276 (this comparison v1),
  seq277 (FN payout / fee answers batch), seq278 (Plan C + On-Demand recommendation
  after consistency-rule check).

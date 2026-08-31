# CK_GOLD_PRO_FIX09 — Consolidated MT5-Native Validation Report

- Strategy ID / Version: CK_GOLD_PRO_FIX09 (v1.03), XAUUSD M15, fixed 0.09 lot
- Simulator: MetaTrader 5 Strategy Tester, real ticks (Model 4) — the single source of truth
- Analysis: Python reads MT5 outputs only (never simulates trades)
- Inputs: all 19 EA inputs pinned every run (GUARD #20); enforced by tools/make_ini.ps1
- Deposit note: deployed config is $5,000; the EDGE was measured at $50,000 to remove a broker margin wall (see §1). Leverage 1:10 (as deployed).
- Ledger trail: SPEC/dof_ledger.jsonl seq 61–76 (hash-chained, verified)
- Final verdict: **REJECT** (not a robust, current edge)

---

## সারাংশ (বাংলা) — সহজ ভাষায়

**সিদ্ধান্ত: এই স্ট্র্যাটেজিটা এখন নির্ভরযোগ্য (robust) নয় — REJECT।** কারণগুলো:

1. **মার্জিন সমস্যা (ডিপ্লয় ঝুঁকি):** গোল্ডের দাম এখন ~$৫,০০০। এই ব্রোকারে ০.০৯ লট গোল্ড খুলতে ~$৪,৯৫০ মার্জিন লাগে — মানে $৫,০০০ অ্যাকাউন্টের প্রায় পুরোটা। লিভারেজ ১:১০ হোক বা ১:১০০, একই (গোল্ডে মার্জিন ফিক্সড)। তাই $৫,০০০ দিয়ে শুরু করে সামান্য লস হলেই অ্যাকাউন্ট নতুন ট্রেড খুলতে পারে না — "No money"। এটা আসল ডিপ্লয়মেন্ট ঝুঁকি।

2. **IS → OOS ধস:** পুরোনো ডেটায় (IS) PF ছিল ১.৯৮, কিন্তু অদেখা নতুন ডেটায় (OOS) PF নেমে ১.১৩। নিয়ম-ভিত্তিক পাইপলাইন এটাকে "severe collapse / overfit" বলে **REJECT** করেছে।

3. **সব লাভ একটা স্পাইকে:** অক্টো ২০২৫–ফেব ২০২৬-এর গোল্ড বুল রান-এ সব লাভ। সবচেয়ে সাম্প্রতিক ৬ মাস (মার্চ–আগস্ট ২০২৬) নিট **লোকসান (−$৩,৪৫১)**।

4. **কয়েকটা ট্রেডের উপর নির্ভরশীল:** OOS-এর সেরা ১০টা ট্রেড বাদ দিলে বাকিটা লোকসানি।

5. **Walk-forward:** ৮টার মধ্যে মাত্র ৪টা ফোল্ড লাভজনক (median PF ১.০৭)।

**সৎ উপসংহার:** ব্যাকটেস্টের বড় লাভটা মূলত একটা বিশেষ বাজার-পরিস্থিতির (গোল্ড স্পাইক) ফল, যা সাম্প্রতিক মাসগুলোতে হারিয়ে গেছে। এখনই আসল টাকা দিয়ে চালানো ঠিক হবে না। (কোনো ইনপুট/স্ট্র্যাটেজি বদলানো হয়নি — শুধু পরীক্ষা করা হয়েছে।)

---

## 1. Environment & the margin finding (critical)

- Real-tick coverage on this terminal (MetaQuotes-Demo): XAUUSD 2025.05.27 → 2026.08.27. All authoritative windows constrained to this range.
- XAUUSD uses a **fixed ~10% margin rate** (a 1:10 cap for metals). Account leverage does NOT override it: a Leverage=1:10 run and a Leverage=1:100 run produced **byte-identical** results (359 trades, PF 1.32).
- At gold ≈ $5,000, one 0.09-lot position needs ≈ $4,950 margin ≈ the entire $5,000 deposit. A fresh $5k account that draws down gets locked out (`not enough money`), e.g. a fresh start in 2026.03 produced only 8 trades then a total halt.
- A compounding $5k account that has grown above the wall is barely affected (359 trades vs 369 at $50k). So the edge was measured at **$50,000** (margin non-binding) to separate the edge from the capital constraint.
- **Deployment implication:** the $5,000 / 0.09-lot config is structurally fragile — a losing streak near the deposit can stop trading entirely. This cannot be fixed by leverage; only by more capital or a smaller lot.

## 2. Baseline (full real-tick range, deployed $5,000)

- 2025.06.01 → 2026.08.28: 359 trades, PF 1.32, net +$8,213.87 (+164%), win 23.1%, max closed DD 23.94%.
- At $50,000 (margin non-binding): 369 trades, PF 1.32, expectancy $24.02, max closed DD 7.67% (≈ $3,835 absolute). Edge is stable across capital.

## 3. In-sample vs Out-of-sample (deposit $50k, real ticks) — REJECT

| Metric | IS (2025.06.01–2025.12.01) | OOS (2025.12.01–2026.08.28) |
|---|---|---|
| Trades | 154 | 215 |
| Profit factor | 1.98 | 1.13 |
| Expectancy | $38.64 | $13.55 |
| Win rate | 27.3% | 20.5% |
| Max closed DD | 2.2% | 8.46% |

- **K3 killer fired:** PF ratio 0.57 (< 0.65) AND expectancy ratio 0.35 (< 0.50) → severe IS→OOS collapse (overfit).
- M1 fail: OOS PF 1.13 < 1.20; expectancy 95% CI [−33.15, 65.93] includes 0.
- **M5 concentration fail:** drop top-10 winners → PF 0.58, expectancy −45.11 (edge lives in ~10 trades).
- M6: 93% of trade-removal resamples net-positive (< 95%).
- **Deterministic verdict: REJECT.**

## 4. Walk-forward (8 folds, on OOS)

- 4/8 folds positive, median PF 1.07, worst fold PF 0.25. Fails ≥60% / median ≥1.10. Not robust.

## 5. Current-regime analysis (primary judge) — consistency FAILED

- 2025.10.01 → 2026.08.29, deposit $50k, split into two independent halves:

| Half | Window | Trades | PF | Expectancy | Net |
|---|---|---|---|---|---|
| cr_h1 | 2025.10.01–2026.03.15 | 129 | 2.16 | +$95.52 | +$12,322 |
| cr_h2 | 2026.03.15–2026.08.29 | 135 | 0.67 | −$33.40 | −$4,509 |

- Full regime (264 trades): PF 1.32, but **monthly** shows all profit is the Oct 2025–Feb 2026 gold spike (+$11,264 cumulative); the most recent ~6 months (Mar–Aug 2026) are **net −$3,451**.
- The edge is not consistent across the two halves and has decayed/reversed in the freshest data. **Consistency guard FAILED.**

## 6. Execution / cost stress (M4)

- Extra cost $5/trade (est. XAUUSD spread ~$0.30×100×0.09 ≈ $2.70 + slippage), on MT5 trade CSVs:
  - Full current-regime: survives 1.5× → PF 1.23, net +$5,833 → M4 PASS.
  - OOS_2026: survives 1.5× → PF 1.06, net +$1,301 → M4 PASS (marginal).
- Reading: the (fragile, regime-specific) edge is not purely a spread artifact, but this does not rescue robustness.

## 7. Monte-Carlo (advisory, on OOS)

- DD p95 17%, P(losing) 31%, net p5 −$5,574 (on $50k). Meaningful tail/negative probability.

## 8. Not run (and why)

- M3 parameter plateau / stability and multi-timeframe: deliberately NOT run. Tuning parameters to rescue a strategy that already fails the K3 collapse killer and the both-halves consistency guard would be curve-fitting a decayed edge. Per project rules ("overfitting is forbidden"; "no robust edge is a valid answer"), further tuning is not justified at this stage.
- M7 benchmark and K5 locked holdout: PENDING (need matched-period price series / a sealed holdout).

## 9. Robustness assessment

| Test | Result |
|---|---|
| IS→OOS stability | FAIL (K3 collapse) |
| OOS PF ≥ 1.20 (M1) | FAIL (1.13) |
| Winner concentration (M5) | FAIL (edge in ~10 trades) |
| Trade-removal (M6) | FAIL (93% < 95%) |
| Walk-forward | FAIL (4/8, med 1.07) |
| Current-regime consistency | FAIL (PF 2.16 → 0.67) |
| Recent 6 months (Mar–Aug 2026) | FAIL (net −$3,451) |
| Cost stress (M4) | PASS (survives 1.5×) |
| Capital robustness ($5k deploy) | FRAGILE (margin lockout) |

**Strengths:** strong in-sample and Oct 2025–Feb 2026 performance; edge is not a spread artifact; edge metrics stable across deposit size.

**Weaknesses:** severe IS→OOS collapse; profit concentrated in one bull-spike regime; net losing over the most recent 6 months; weak walk-forward; margin-lockout fragility at the deployed $5k.

## 10. Verdict & recommendation

- **VERDICT: REJECT** — not a robust, current edge. The historical profit is largely a regime-specific (gold bull spike) phenomenon that has decayed into losses over the most recent 6 months.
- **Do NOT risk real money on this configuration now.** (Requires explicit human approval regardless.)
- Honest next options (research only, no live risk): investigate whether a *different, simpler* regime filter has an independently-validated basis; or accept "no robust edge" for this candidate. Any change must pass A/B + OOS + walk-forward + both-halves consistency before it is called an improvement.

---

*All trade simulation performed in the MT5 Strategy Tester (real ticks). Python computed statistics only. Every run pinned all EA inputs (GUARD #20) and is recorded in SPEC/dof_ledger.jsonl (seq 61–76, hash-chain verified).*

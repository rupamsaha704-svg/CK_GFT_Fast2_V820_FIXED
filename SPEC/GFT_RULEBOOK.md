# GFT RULEBOOK — every rule, ordered, with proof of source

> **Account under audit:** Goat Funded Trader, **$5,000, 2-Step Standard**, XAUUSD, MT5.
> **Purpose:** the single machine-checkable source of truth for `tools/gft_compliance.py`.
> **Rule of construction:** every entry below is either quoted-in-substance from GFT's own help
> centre (linked), or explicitly marked as **UNCONFIRMED**. Nothing here is invented. If a rule
> cannot be sourced, it is flagged, not guessed.
> **Last researched:** 2026-09-15.

---

## 0. How to read this document

Every rule carries five fields:

| Field | Meaning |
|---|---|
| **Class** | `HARD BREACH` = account permanently dead. `PROFIT ADJUSTMENT` = money removed, account lives. `SOFT / DISCRETIONARY` = GFT reviews and decides. `REQUIREMENT` = must be met to progress or get paid. |
| **Stage** | Step 1 (eval), Step 2 (eval), Step 3 (funded). Many rules apply to **funded only** — this is the most common misunderstanding and the most expensive one. |
| **Measured on** | Balance, closed-trade equity, or **intraday floating equity**. Decides whether our backtest data can prove it at all. |
| **Confidence** | `CONFIRMED` (GFT's own help centre), `CONFLICTING` (sources disagree — treat as unknown), `UNCONFIRMED` (no primary source found). |
| **Checkable?** | What data the compliance engine needs before it may claim a verdict. |

**The asymmetry that governs everything:** a *false pass* costs the account. A *false breach*
costs a good strategy. The engine must produce neither — so when data cannot settle a rule it
reports `UNVERIFIED`, never `PASS`.

---

## 1. Model table (CONFIRMED)

Source: [GFT — 2-Step Standard](https://help.goatfundedtrader.com/en/articles/13575169-2-step-standard)

| Rule | Step 1 | Step 2 | Step 3 (Funded) |
|---|---|---|---|
| Profit target | 10% | 5% | none |
| Daily drawdown | 5% | 5% | 5% |
| Max overall loss | 10% **static** | 10% **static** | 10% **static** |
| Minimum trading days | 3 | 3 | 3 per payout (**4** if account bought on/after 25 Jul 2026) |
| Max daily profit | no limit | no limit | **$3,000** |
| Consistency rule | No | No | No |
| Goat Guard | No | No | **Yes** |

Funded terms (CONFIRMED, same source): profit split **80%**; payout cycle **bi-weekly (14 days)**;
daily profit above $3,000 is **deducted, not a breach**; first two payouts capped at 6% of initial
or $10,000 (whichever lower), **4% for $5k two-step accounts bought from 25 Jul 2026**; cap lifted
after the 2nd payout. Leverage differs between phases — verify the exact figure on the dashboard.

---

## 2. HARD BREACH rules — one of these kills the account permanently

### RULE 1 — Max overall loss, 10% STATIC
- **Class:** HARD BREACH · **Stage:** all three · **Confidence:** CONFIRMED
- **Threshold:** equity **or** balance must never fall below **90% of starting capital**.
  On $5,000 the absolute floor is **$4,500**.
- **Static** means the floor never trails upward as the account grows. It is fixed for the life of
  the account.
- **Measured on:** balance **and** equity. Equity includes floating P&L, so an open position alone
  can breach it.
- **Checkable?** Yes, and exactly, when MT5 `report.htm` is present: MT5's *Equity Drawdown
  Absolute* is floating-inclusive and is the GFT-relevant number. From `trades.csv` alone it is
  realized-only → `UNVERIFIED`.
- **Our buffer:** halt everything at 8% below initial ($4,600), never approach $4,500.

### RULE 2 — Daily drawdown, 5%
- **Class:** HARD BREACH · **Stage:** all three · **Confidence:** CONFIRMED **twice** — support bot
  and human agent (Michael) independently, 2026-09-15
- **Reference:** the **higher of balance or equity at 5 PM EST**. Stated in those exact terms by
  the human agent. A higher reference raises the day's absolute floor, so it is *stricter* than
  using balance alone — which is why the engine was corrected (see §6c).
- **Threshold:** within one trading day, equity must not drop **5% below that reference**
  (~$250 on $5,000).
- **Measured on:** **intraday equity, floating P&L included.** This is the critical detail. A day
  can breach on an open position and recover before anything closes.
- **Day boundary:** GFT rolls the day at approximately **5 PM EST**. On this broker's server clock
  that lands near **server midnight** — evidence: ledger seq187, gold's CME Globex halt at ET 17:00
  appears as server hours 0/1/2. Engine input `--day-reset-hour`, default `0`. **Verify on the
  dashboard** before trusting a live deployment.
- **Checkable?** Closed trades give a **LOWER BOUND** only → can prove a breach, can never prove
  safety. Exact only with an intraday equity series.
- **Our buffer:** pre-trade predictive governor at 4.0% — refuse a new entry if
  `today_realized_loss% + this_trade_worst_case_SL_risk%` would exceed it.

### RULE 3 — Goat Guard, 2% combined floating loss (FUNDED ONLY)
- **Class:** 1st trigger = PENALTY · 2nd trigger = **HARD BREACH** · **Stage:** funded only
  (excludes Instant Funding) · **Confidence:** CONFIRMED
- Source: [GFT — What is Goat Guard](https://help.goatfundedtrader.com/en/articles/10742107-what-is-goat-guard)
- **Threshold:** the **combined floating PnL of all open positions** reaching a loss equal to
  **2% of the initial account size**. On $5,000 that is a fixed **$100**.
- Measured against **initial** — not balance, not equity. It does **not** grow as the account grows.
- **1st trigger:** not a breach. Positions stay open, account stays active, trading continues, but
  the **profit split drops 80% → 50%**.
- **2nd trigger:** account **breached and permanently closed**.
- **The snapshot mechanic (essential, and easy to get wrong):** when Goat Guard fires, GFT records
  a snapshot of the positions open at that instant. While that exact set stays unchanged, further
  fluctuation below −2% does **not** re-trigger. A **new snapshot** is created whenever the
  composition changes — closing one of them, or opening another. If the new set then reaches −2%,
  that is the second trigger and the account dies.
- **Checkable?** Only with a combined-floating series. **A single closed trade at −$106 does NOT
  prove a trigger**, because Goat Guard sums *all* open positions: if a second position floated
  +$50 at that moment, the combined figure was −$56 and nothing fired. Our combo EA can hold FIX09
  and DTREND simultaneously, so this matters. Closed-trade data yields **candidate** triggers only.
- **Our buffer:** flatten all positions once combined floating loss reaches 1.5% ($75).

---

## 3. PROFIT ADJUSTMENT rules — the "hidden" rules that quietly delete money

These do **not** kill the account. They delete profit at payout time, which is exactly when it
hurts most and exactly why they must be modelled before going live.

### RULE 4 — Minimum hold time: trades under 2 minutes (FUNDED ONLY)
- **Class:** PROFIT ADJUSTMENT · **Stage:** **funded only — explicitly not evaluation** ·
  **Confidence:** CONFIRMED
- Source: [GFT — trades lasting less than 2 minutes](https://help.goatfundedtrader.com/en/articles/12849041-what-is-the-rule-about-trades-lasting-less-than-2-minutes)
- **Rule:** on funded accounts, profit from any position open **less than 2 minutes (120 seconds)**
  is treated as invalid and **removed when a payout is requested**.
- **Asymmetric and brutal:** the **losses from sub-2-minute trades still count**. Winners get
  deleted, losers stay.
- GFT states plainly that this is **not** a breach or violation — it only reduces the payout. And
  that it applies to funded accounts only, not challenge accounts.
- **Checkable?** Needs **trade duration** = exit time − entry time. `trades.csv` carries only the
  exit time, so this is **not checkable** from it. Requires a deals CSV with entry and exit.
- **Design consequence for us:** any funded-stage strategy whose edge lives in sub-2-minute
  holds has **no funded edge at all**, however good the backtest looks. Worth checking against our
  own EAs before any funded deployment.
- **Related, UNCONFIRMED for GFT:** GFT's futures sibling (Goat Funded **Futures**) states that
  closing *any part* of a position within 2 minutes — including partial take-profit — violates the
  micro-scalping rule ([GFF source](https://help.goatfundedfutures.com/en/articles/14185552-can-i-take-partial-profit-from-my-trade-within-2-minutes-of-opening-the-trade)).
  That is a **different firm brand**; do not assume it for GFT. Confirm with GFT support before
  relying on partial exits. Note also that GFF applies its 2-minute rule in **both** evaluation and
  funded phases, whereas GFT confines it to funded — another reason not to cross-apply.

### RULE 5 — Weekend gap trading (FUNDED ONLY for the money effect)
- **Class:** PROFIT ADJUSTMENT + review · **Stage:** review at any stage; profit removal on funded
  accounts · **Confidence:** CONFIRMED
- Source: [GFT — do you allow trading the weekend gap](https://help.goatfundedtrader.com/en/articles/14123389-do-you-allow-trading-the-weekend-gap)
- **Holding over the weekend is fully allowed.** What is not allowed is opening a position purely
  to capture the Monday re-open gap.
- **The mechanical test GFT applies:** a trade opened during the **last 3 market hours on Friday**
  and closed within the **first 3 market hours on Monday** is subject to review, and **on funded
  accounts the profit from it is removed**.
- GFT states this is **not** a violation and carries no penalty or termination — strictly a profit
  adjustment.
- **Checkable?** Yes, given entry and exit timestamps: flag trades whose entry falls in Friday's
  final 3 market hours *and* whose exit falls in Monday's first 3 market hours.
- **Design consequence:** our gap analysis (ledger seq184–188) already showed gap risk drives
  funded sizing. This rule adds the mirror image: gap *profit* in that window will not be paid.
  A strategy must not depend on it.

### RULE 6 — Funded daily profit cap, $3,000
- **Class:** PROFIT ADJUSTMENT · **Stage:** funded only · **Confidence:** CONFIRMED
- Profit above **$3,000** in a single day is **deducted**. Explicitly **not** a breach.
- **Checkable?** Yes, from daily realized totals. Effectively unreachable on a $5k account.

---

## 4. REQUIREMENTS — must be satisfied to progress or be paid

### RULE 7 — Minimum trading days
- **Class:** REQUIREMENT · **Confidence:** CONFIRMED
- Step 1: **3** days. Step 2: **3** days. Funded: **3 per payout**, resetting after each payout —
  **4** for accounts purchased on or after **25 July 2026**.
- **Checkable?** Yes. Confirm the account purchase date to pick 3 vs 4.

### RULE 8 — Payout valid day: profit ≥ 0.5% of initial
- **Class:** REQUIREMENT · **Stage:** funded · **Confidence:** CONFIRMED
- A day counts toward the payout requirement only if its profit is at least **0.5% of initial**
  (**≥ $25** on $5,000).
- **Checkable?** Yes, from daily realized totals.

### RULE 9 — Profit targets
- **Class:** REQUIREMENT · **Confidence:** CONFIRMED
- Step 1: **+10%** (+$500 on $5k). Step 2: **+5%** (+$250). Funded: none.
- **Checkable?** Yes — and the engine must confirm the target was reached **with no prior hard
  breach**, because order matters: breaching first kills the account regardless of later profit.

### RULE 10 — Consistency rule
- **Class:** none for this model · **Confidence:** CONFIRMED
- The 2-Step Standard table lists Consistency Rule = **No** for all three stages.
- **Caution:** other GFT models do impose one, and GFT keeps a dedicated consistency article. If
  the account model is ever anything other than 2-Step Standard, re-check this row first.

---

## 5. SOFT / DISCRETIONARY — GFT judges these, no fixed number

### RULE 15 — Margin ceiling: 80% of available margin (CONFIRMED, and it bites us)
- **Class:** PROHIBITION · **Stage:** all · **Confidence:** CONFIRMED by GFT human support
  (Michael), 2026-09-15
- **Rule as stated:** there are **no lot-size restrictions**, but **no more than 80% of available
  margin** may be used.
- Related reading GFT pointed to:
  [Does GFT allow "All or Nothing" strategies](https://help.goatfundedtrader.com/en/articles/10742096-does-goat-funded-trader-allow-all-or-nothing-trading-strategies)

**This rule breaks our shipped EVALUATION config.** The finding, with our own measurements:

| Config | Lot | Margin at gold ~5,000 | % of $5,000 | vs 80% ceiling |
|---|---|---|---|---|
| **Eval** (`FIX_FixedLot = 0.09`) | 0.09 | ~$4,500 | **~90%** | **BREACH** |
| **Funded** (`Combo_FundedFixLot = 0.01`) | 0.01 | ~$500 | ~10% | comfortably inside |

- Margin for a metals position = `volume × contract_size × price × margin_rate`. Our measured
  XAUUSD margin rate on MetaQuotes-Demo is **~10% of notional, and account leverage does NOT
  override it** (ledger seq67, seq69 — the leverage hypothesis was tested and refuted).
- At gold ≈ 4,450 the 0.09 lot already crosses 80%. Gold traded 4,500–5,600 in our test window, so
  the eval config is over the ceiling across essentially the whole period.
- **We had already seen the symptom and misread it as a performance problem.** Ledger seq67 logged
  explicit `not enough money [No money]` order rejections at 0.09 lot, and seq110 showed a fresh
  $5k run producing only **8 trades** because of margin lockout. That was not just an annoyance —
  under this rule it is a **compliance failure**.
- **Open:** GFT's own broker margin rate is unknown, and "available margin" could mean equity or
  free margin. Either reading leaves 90% over the ceiling. Engine input `--margin-rate`.
- **Consequence:** the eval lot must come down, or the eval must run on a larger account. This is
  now a blocking item for any $5k evaluation attempt, not an optimisation.

### RULE 11 — Abuse of the simulated environment
- **Class:** SOFT / DISCRETIONARY · **Confidence:** CONFIRMED (wording is deliberately open)
- Source: [GFT — prohibited trading practices](https://help.goatfundedtrader.com/en/articles/10742118-what-are-prohibited-trading-practices)
- GFT describes abuse as repeatedly placing **large-volume trades with no clear or logical
  strategy**, disregarding analysis and risk management, which yields no useful trading data.
  Consequences range from warnings and trading limitations to suspension or termination.
- **Checkable?** Not mechanically. Our defence is documentary: a pre-registered, backtested,
  fixed-rule EA with a hash-chained ledger is the opposite of "no coherent strategy".

### RULE 12 — No duplicating trades across accounts
- **Class:** SOFT → can lead to termination · **Confidence:** CONFIRMED
- GFT prohibits copying trades — manually or by EA — from a funded account to an evaluation
  account, or between evaluation accounts. It covers **the trade ideas as well as the trades**.
- **Consequence for us:** the same EA must not run on two GFT accounts simultaneously. One EA, one
  account.

### RULE 12b — Expert Advisors: ALLOWED, with two named exclusions (CONFIRMED)
- **Class:** REQUIREMENT / PROHIBITION · **Stage:** all · **Confidence:** CONFIRMED by GFT human
  support agent (Michael), 2026-09-15
- **Automated EAs are allowed**, provided they comply with the prohibited-practices rule (rule 11).
- **Two explicit exclusions:**
  1. **High-frequency trading (HFT) strategies or systems** — not permitted.
  2. **Gold Arbitrage EAs** — not permitted. This one names our exact instrument, so it matters.
- **Where we stand (measured, not assumed):** `CK_GOLD_COMBO` places roughly **276–337 trades per
  year** — about one per day — and holds for hours, not seconds. The deals export showed only
  **2 positions** held under 2 minutes across a full year. The strategy is trend/breakout, with no
  arbitrage component of any kind. On every reading, this is far from HFT.
- **STILL UNRESOLVED:** GFT has not given a *numeric* definition of HFT — no minimum hold time and
  no maximum trades per day. An undefined prohibition is a payout-time risk, so the definition has
  been requested. Until answered, keep trade frequency and hold times where they are and do not
  move toward faster trading.
- **Design consequence:** any future idea that shortens holds toward seconds, or raises frequency
  sharply, must be checked against this rule *before* it is built. Note that a very fast strategy
  would also collide with rule 4 (the 2-minute payout strip), so the two rules point the same way.

### RULE 13 — Hedging, grid, martingale, arbitrage
- **Class:** SOFT / DISCRETIONARY · **Confidence:** **PARTLY UNCONFIRMED — do not treat as settled**
- Arbitrage on gold is now explicitly prohibited (see rule 12b). Hedging, grid and martingale
  remain unconfirmed.
- GFT maintains dedicated help articles titled *Is hedging allowed?* and *Does GFT allow "All or
  Nothing" strategies?*, and a blog stating that grid, martingale and latency arbitrage are banned
  as exploitative — but a blog post is **not** the rule page.
- Third-party trackers (e.g. [tradingfinder](https://tradingfinder.com/props/goat-funded-trader/rules/))
  list hedging, grid, martingale, arbitrage and cross-account duplication as banned. Third-party
  summaries are **not** an acceptable basis for a money decision.
- GFT's futures sibling bans arbitrage of every kind and gap trading around closures
  ([GFF source](https://help.goatfundedfutures.com/en/articles/14111227-what-strategies-are-prohibited)) —
  again a different brand.
- **Action required:** read GFT's own *Is hedging allowed?* article and confirm with support before
  any strategy relies on hedging or averaging. **Our EAs are single-direction with fixed stops and
  no martingale/grid, so this is currently moot** — but it constrains future designs.

### RULE 14 — Risk-Limitation Policy
- **Class:** SOFT / DISCRETIONARY · **Confidence:** UNCONFIRMED (carried from project steering)
- GFT may cap risk per trade idea at **1% of initial** where it judges risk-taking excessive.
- **Consequence:** keep per-trade risk visibly under 1% of initial on funded. Our shipped funded
  config already sits far below this.

---

## 6. RULE 6b — News-window 1% profit cap (CONFIRMED by support, applies to ALL stages)

- **Class:** PROFIT ADJUSTMENT · **Stage:** **evaluation AND funded** · **Confidence:** CONFIRMED
  by GFT support 2026-09-15
- **Rule (full wording now obtained):** **any trade** opened **or** closed — *manually or
  automatically, including by stop loss, take profit, or pending order* — within **5 minutes
  before or after** a high-impact news release can generate a **maximum profit of 1% of the
  account's initial balance** (**$50** on $5,000). Excess profit is **removed**, typically at
  account review. **No breach, no penalty.**
- **Basis: PER TRADE.** The wording is "any trade … can generate a maximum profit of 1%", which
  reads per trade, and that is how the engine computes it.
- **High-impact = the red-folder events on ForexFactory.com and myfxbook.com** (named explicitly).
- **The detail that matters most for an EA:** an automatic close counts. Our EA sets a stop and a
  target and then leaves the trade alone — if that **take-profit fires inside a news window, the
  rule applies**, even though nothing "decided" to close then. Passive exits are not exempt.
- **This is the one rule where our earlier reading was wrong, and the correction matters.** GFT's
  own help article [Is News Trading allowed?](https://help.goatfundedtrader.com/en/articles/10742084-is-news-trading-allowed)
  says news trading is allowed and breaks no rule — which is true but **incomplete**. A
  third-party review ([velotrade](https://velotrade.com/blog/goat-funded-trader-review)) had
  claimed the 1% / 5-minute cap, and support **confirmed the review, not the article**. This is
  why the item was logged CONFLICTING rather than dismissed: treating the primary source as
  complete would have hidden a real deduction.
- **Why it matters more than the other adjustment rules:** it is the only profit-adjustment rule
  that bites during **evaluation**. Step 1 needs +$500; if a meaningful share of that arrives
  inside news windows, the real progress is less than the equity curve suggests.
- **Checkable?** Only with a high-impact calendar plus entry/exit times. Engine flag `--news-csv`
  (one `YYYY.MM.DD HH:MM` per line, server time). Without it the rule reports `UNVERIFIED` — it is
  never silently skipped.
- **STILL UNRESOLVED with GFT:** whether the cap is **per event, per trade, or per day**. The
  engine computes it **per trade** and says so, because that is the interpretation it can actually
  evaluate — the true deduction may differ.

---

## 6c. Daily reference — CORRECTED after support reply

Support confirmed two details that change the daily rule (rule 2):

1. **The reference is the HIGHER of balance or equity at the reset**, including when positions are
   still open. A higher reference raises the day's absolute floor, so this is **stricter** than
   using balance alone. Our engine originally used balance only, which was **looser than the firm**
   and could have produced a **false pass**. Now corrected: the engine takes
   `max(balance, equity)` when an equity series is available, and otherwise treats the
   balance-only reference as a **lower bound** and keeps the daily rule `UNVERIFIED`.
2. **A temporary intraday equity breach is still a breach**, even if the trade later recovers.
   This closes the door on any argument that a dip which recovered "did not count", and confirms
   that closed-trade data can never prove daily compliance.

---

## 7. What our backtest data can and cannot prove

This is the honest accounting of measurement gaps. Each row states the data needed to upgrade a
rule from `UNVERIFIED` to a real verdict.

| Rule | From `trades.csv` (exit, profit) | From `report.htm` | Needs more |
|---|---|---|---|
| 1 · static 10% | realized lower bound | **EXACT** (Equity DD Absolute) | — |
| 2 · daily 5% | lower bound only | no | intraday equity series |
| 3 · Goat Guard 2% | **candidates only** | no | combined floating series |
| 4 · 2-min hold | **impossible** (no entry time) | no | deals CSV: entry + exit |
| 5 · weekend gap | **impossible** (no entry time) | no | deals CSV: entry + exit |
| 6 · daily profit cap | EXACT | — | — |
| 7 · trading days | EXACT | — | — |
| 8 · valid days ≥0.5% | EXACT | — | — |
| 9 · profit target | EXACT | — | — |
| 10 · consistency | n/a for this model | — | — |
| 11–14 · discretionary | not mechanical | — | human judgement |

**Consequence, stated plainly:** three rules that can silently delete funded profit — the 2-minute
rule, the weekend-gap rule, and the Goat Guard combined-float rule — are **not verifiable from the
trade CSVs this project has produced so far**. Closing that gap requires the EA to export, per
position: **entry time, exit time, profit, and worst adverse excursion**, plus ideally a sampled
equity series. Until then the compliance verdict for a funded deployment can be at best
`NOT CLEARED`, and that is the correct answer rather than an optimistic one.

---

## 8. Open items to confirm with GFT support or the dashboard

1. Exact daily-reset time in **broker server terms** (rule 2). Highest priority — it decides how
   days are grouped, and therefore whether a day breached.
2. Account **purchase date** → minimum trading days 3 or 4, and payout cap 6% or 4% (rules 7, 1).
3. Whether the **partial-close-within-2-minutes** prohibition applies at GFT as it does at GFF
   (rule 4).
4. **News trading** — resolve the contradiction in §6.
5. **Hedging / averaging** explicit position (rule 13).
6. Exact **leverage** per phase for the $5k 2-Step Standard.

---

## 9. Sources

All GFT help-centre pages retrieved 2026-09-15:

- [2-Step Standard model](https://help.goatfundedtrader.com/en/articles/13575169-2-step-standard)
- [What is Goat Guard](https://help.goatfundedtrader.com/en/articles/10742107-what-is-goat-guard)
- [Trades lasting less than 2 minutes](https://help.goatfundedtrader.com/en/articles/12849041-what-is-the-rule-about-trades-lasting-less-than-2-minutes)
- [Weekend gap trading](https://help.goatfundedtrader.com/en/articles/14123389-do-you-allow-trading-the-weekend-gap)
- [Prohibited trading practices](https://help.goatfundedtrader.com/en/articles/10742118-what-are-prohibited-trading-practices)
- [Is news trading allowed](https://help.goatfundedtrader.com/en/articles/10742084-is-news-trading-allowed)

Cross-brand (Goat Funded **Futures** — different brand, cited only to show a rule exists there and
must not be assumed for GFT):
[prohibited strategies](https://help.goatfundedfutures.com/en/articles/14111227-what-strategies-are-prohibited),
[holding-time rules](https://help.goatfundedfutures.com/en/articles/14130422-holding-time-rules-on-each-plan),
[partial profit within 2 minutes](https://help.goatfundedfutures.com/en/articles/14185552-can-i-take-partial-profit-from-my-trade-within-2-minutes-of-opening-the-trade).

Third-party, **not** authoritative, listed for traceability only:
[tradingfinder rules page](https://tradingfinder.com/props/goat-funded-trader/rules/),
[velotrade review](https://velotrade.com/blog/goat-funded-trader-review).

*Content from all sources was paraphrased and condensed for licensing compliance; figures and rule
substance preserved unchanged.*

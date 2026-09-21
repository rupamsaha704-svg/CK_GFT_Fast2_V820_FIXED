# Multi-Account Differentiation Plan for FundedNext (FN)

**Author:** research pass, 2026-09-21
**Purpose:** Analyze how to legally scale income across multiple sub-$50k FN
accounts while respecting FN rules that block clone-EA scaling.

## 1. Hard FN constraints (from steering §7)

1. **"Identical trades across accounts are NOT allowed"** — FN rule (Article
   8020351 explicitly targets mirrored/opposite positions; the "identical"
   pattern is enforced by their monitoring).
2. **Accounts ≥ $50,000 are MANUAL-ONLY** — no EA permitted, so the same EA
   cannot be scaled onto a bigger account.
3. **EA add-on fee**: $5 one-time per account (or $10 EA+VPS bundle). Not
   recurring.
4. **News handling on funded**: 40% profit-only counting → applies per account.
5. **On-Demand 90% payout eligibility**: 2% account growth + 40% consistency
   (biggest-day / total ≤ 40%). Each account tracked separately.

**Implication:** The naive plan "buy 5 clone accounts and run Plan C on all" is
BANNED. You need DIFFERENTIATED strategy or entry logic per account.

## 2. Differentiation strategies — ranked by (a) legal safety and (b) research cost

### Option A: Different symbols (SAFEST + HIGHEST WORK)

Different symbols produce different trade streams, trivially "not identical".

| Account | Symbol | EA / config | Status |
|---|---|---|---|
| 1 | XAUUSD | Plan C (FIX09 + DTChop) | **MT5-verified**, +$2,239/yr on $6k = 37% |
| 2 | XAGUSD (silver) | Plan C ported to XAG | **UNTESTED** — needs full backtest |
| 3 | EURUSD or DXY-basket | Plan C ported to FX | **UNTESTED** — commissions/spread differ |

**Pros:** Zero risk of FN flagging as "identical".
**Cons:** Each new symbol = full pre-reg + MT5 test cycle (1-2 days each). No
guarantee Plan C's edge (which was tuned to gold's volatility regime) transfers
to silver/forex.

### Option B: Different strategies on same symbol (SAFE + MODERATE WORK)

Different EAs on the same symbol produce genuinely different trade streams.

| Account | Symbol | EA | Status |
|---|---|---|---|
| 1 | XAUUSD | Plan C (FIX09 + DTChop) | MT5-verified |
| 2 | XAUUSD | QM native (CK_QM_NATIVE_v1) | **PENDING Model 4 parity test** |
| 3 | XAUUSD | Alternative TREND-family EA | needs new pre-reg + test |

**Pros:** Same symbol expertise, no new-market research cost.
**Cons:** Correlation risk — if all 3 EAs go long gold on same day, joint DD
compounds. Need to verify low correlation between strategy P&L.

**Confirmed corr from earlier work (steering context):**
- Plan C vs QM signal-player: **BORDERLINE** independent (0 same-direction, 0
  opposite trades within ±30 min in overlap window).
- Plan C vs LookBack v2: net-negative sleeve (already rejected).

### Option C: Different session filters on same EA (MODERATE RISK)

Trigger the SAME EA but limit to different hours per account. Trades will
differ, but the underlying signal is the same → FN's monitoring may still flag.

| Account | Hours (server) | Rationale |
|---|---|---|
| 1 | 08:00–13:00 (London only) | Half-day risk |
| 2 | 13:00–22:00 (NY only) | Half-day risk |
| 3 | 08:00–22:00 (full US-EU) | Full day |

**Pros:** Minimal research cost (already have Plan C).
**Cons:** RISKY — same underlying signal could still be flagged. Also filters
cut trade count, potentially cut edge. Not recommended as primary.

### Option D: Different lot sizes (HIGH RISK OF FLAG)

Account 1 at 0.01, Account 2 at 0.02, Account 3 at 0.03 — same signal, different
sizes. Trades are technically "identical direction, identical time, different
size" → FN's monitoring will almost certainly flag as identical.

**Recommendation: DO NOT use this option.**

## 3. Recommended path — hybrid A+B

Given that our confirmed edge is Plan C on gold, the fastest legal
diversification path is:

**Phase 1 (immediate, once user has $70):**
- **Account 1**: FN Stellar 2-Step $6k on XAUUSD with Plan C EA
- Get through both eval steps → funded
- Take On-Demand 90% payouts starting month 4
- Income: ~$175/mo take-home (= ~₹20,159/mo)

**Phase 2 (after 3 months of first payout, capital reinvested):**
- **Account 2**: FN Stellar 2-Step $6k on XAUUSD with **QM native EA**
  (requires QM native Model 4 parity to have passed first — task #3)
- Total income: ~$350/mo (~₹40,250/mo) assuming both funded

**Phase 3 (after 6 more months):**
- **Account 3**: FN Stellar 2-Step $6k on XAUUSD with a **third differentiated
  EA** (Donchian breakout if it passes task #2, or new pre-reg experiment)
- Total income: ~$525/mo (~₹60,375/mo)

**Alternative Phase 3**: instead of a 3rd EA on gold, port Plan C to XAGUSD
(silver) — this is Option A. Silver is close to gold but different regime, so
Plan C parameters may need re-tuning. Full pre-reg + Model 4 backtest first.

## 4. Capital and timeline math

| Milestone | Elapsed | Accounts | Combined take-home | ₹/mo (at 115/USD) |
|---|---|---|---|---|
| Start | 0 | 0 | $0 | ₹0 |
| Buy Acct 1 ($70) | 0 | 1 (in eval) | $0 | ₹0 |
| Acct 1 funded | 2-3 mo | 1 (funded) | $175/mo | ₹20,125 |
| Acct 2 funded | 5-6 mo | 2 (funded) | $350/mo | ₹40,250 |
| Acct 3 funded | 8-12 mo | 3 (funded) | $525/mo | ₹60,375 |

**Target achieved (~₹60k/mo):** end of year 1, all 3 accounts funded,
differentiated.

**Compare vs single-account scale-up (FN's built-in scale-up plan):**
- Not fully documented publicly; steering §3 mentions "scaling to 90% under
  FundedNext's scale-up plan" but does NOT confirm account-size grows over time
- Assumed: single account income stays flat around ~$175/mo unless FN grows
  account size explicitly (needs re-verification with FN support)

**Multi-account clearly wins on income scalability** because each account is
independent, sums linearly, and the "identical trades" ban is respected by
using different EAs.

## 5. Risks

- **QM native parity fails (task #3)**: no viable second EA yet; would need to
  test another TREND family strategy (task #2 Donchian, or new pre-reg)
- **Donchian breakout fails (task #2)**: similar problem, need to find another
  differentiated edge
- **Correlated blow-ups**: all 3 accounts long gold on same day + adverse news
  = all 3 might hit daily 5% line together. Mitigation: at least one account
  should be different symbol (Phase 3 alternative → silver port).
- **FN monitoring flags anyway**: even with 3 different EAs on gold, if FN's
  algorithm decides they're "too similar" (e.g. all long during trending days),
  flag risk. Mitigation: use portfolio-style rules that stagger entries.
- **Capital constraint**: user has ~$0 now, needs $60-70 to start Account 1.
  Subsequent accounts funded by payouts from earlier accounts.

## 6. Action items (in priority order)

1. Complete task #3 (QM native Model 4 parity) — determines whether Account 2
   can use QM native as its differentiated EA.
2. Complete task #2 (Donchian breakout test) — determines whether we have a
   third differentiated candidate for Account 3.
3. User: save ~$70 for Account 1 challenge fee + EA add-on.
4. First-time payout at 21 days (Standard 80%) or wait 3 months for On-Demand
   90% (~$20/mo income difference).
5. After Account 1 funded and running clean for 30 days, reinvest payout into
   Account 2 with second differentiated EA.

## 7. Assumptions and caveats

- FN rules current as of 2026-09-21 per steering §7 (Diana + Allen support
  chats). Re-verify before real-money purchase because FN changes terms.
- Take-home projections assume:
  - Plan C real-tick number of +$2,239/yr on $6k (MT5 Model 4, seq255)
  - 80% (Standard) or 90% (On-Demand) split
  - 40% consistency rule satisfied (Plan C at 36.2% currently passes)
  - No news-heavy month reducing profit by 60%
- Income NOT guaranteed — historical backtest ≠ forward performance. First
  demo-forward pass (~2 weeks) still required per steering §4 before real
  money.

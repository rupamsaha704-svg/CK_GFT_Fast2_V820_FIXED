# PREREG — CK_XAU_ASIAN_FADE — Asian-session range-fade candidate on XAUUSD

**Status:** pre-registered 2026-09-21 (ledger seq279). NO code written yet. NO test run
yet. Rules and pass/fail bar locked BEFORE any implementation to prevent p-hacking
and post-hoc tuning (steering §5).

**Purpose:** add a mean-reversion sleeve that earns during flat / choppy market
months when the trend-following combo (FIX09 + DTREND) stands down. Target: an
uncorrelated additive edge, not a replacement for combo.

## 1. Hypothesis

On XAUUSD, the Asian trading session (22:00–04:00 server time; approx 03:30–09:30
IST) is historically lower-volatility and range-bound because institutional flow is
mostly absent and Asian retail dominates. A mean-reversion entry — fading a M15
rejection candle at either edge of the session range — should generate small,
consistent profits during periods when trend-following strategies produce no signal
or small losses (Plan C's Feb 2026 −$105, Apr −$186, Jul −$272, Aug −$127 months
are the exact target regime).

The edge is intentionally SESSION-SCOPED and TIME-BOUNDED. No positions carry
outside the Asian window. This eliminates overnight/weekend gap risk and keeps
the daily-loss exposure predictable.

## 2. Rules (v1 — LOCKED)

### Session

- Session open: **22:00 server time** (input `Inp_SessionStartHour`, default 22).
- Session close: **04:00 server time next day** (input `Inp_SessionEndHour`,
  default 4).
- Range definition: high and low of the FIRST 8 M15 bars after session open
  (= 2 hours). Range fixed after bar 8. Adjustable via `Inp_RangeBars`, default 8.

### Entry trigger

Once range is fixed (i.e. we're past bar 9 of the session):

- **SELL** at next-bar open if:
  - Current M15 bar's HIGH ≥ session range high, AND
  - Bar close is BELOW range high, AND
  - Upper wick (high − max(open, close)) ≥ 1.5 × body size, AND
  - No open position already exists for this EA.
- **BUY** mirror: bar low ≤ session range low, close above range low, lower wick
  ≥ 1.5 × body.

### Stops and targets

- **Stop loss:** range extreme + `Inp_SLBufferATR × ATR(14)` beyond in the entry
  direction. Default buffer 0.3 × ATR.
- **Take profit 1** (TP1, 50% partial): range midpoint. Move stop to entry on
  TP1 hit (break-even lock).
- **Take profit 2** (TP2, remaining 50%): opposite range extreme.
- **Time exit:** flatten ALL positions at session close (04:00 server) regardless
  of P&L. Never carry outside the session.

### Filters

- **Volatility filter:** skip entries if 24-hour ATR > 2.0 × its 10-day median.
  Rationale: fading a genuinely trending day is where mean-reversion strategies
  blow up. Default `Inp_VolFilterMult = 2.0`, can be turned off.
- **News gate:** reuse the master `Combo_UseNewsGate` pattern — block entries ±6
  minutes around high-impact economic releases (MT5 native
  `CalendarValueHistory`).
- **Weekly cap:** max 3 trades per calendar week. Rationale: caps overfitting
  behaviour where a "signal" fires every day of a range-bound week and blows the
  edge. Default `Inp_MaxTradesPerWeek = 3`, can be increased.

### Risk sizing

- **Fixed dollar risk per trade:** `Inp_RiskUSD` default **$50**. On $6,000
  initial that is 0.83% per trade. Lot computed from SL distance.
- **Max lot cap:** `Inp_MaxLot = 0.10`.
- **Max concurrent positions (this EA):** 1.

### Magic number

- **`Inp_Magic = 20260921`** — distinct from FIX09 (20260716) and DTREND
  (20260930) so positions never collide.

## 3. Pass / fail bar — PRE-DECLARED, LOCKED

Test environment:

- MT5 Strategy Tester Model 4 (real ticks) — steering §5 pins as the only truth.
- Symbol: XAUUSD.
- Window: **2025-10-01 → 2026-09-17** (matches Plan C's `combo_fnext_journal`
  window for direct correlation measurement).
- Deposit: $6,000 (FundedNext basis).
- Leverage: 1:100.
- All inputs pinned per §2 above; no optimisation, no walk-forward tuning.

ALL of the following must PASS for adoption; a single failure = REJECT:

| # | Metric | Bar | Rationale |
|---|---|---|---|
| 1 | Net profit | **> +$600** | 10% of $6k over the year — meaningful additive contribution to Plan C's $2,240 |
| 2 | Win rate | **> 55%** | Mean-reversion should have high hit-rate; below 55% suggests the rule is picking bad extremes |
| 3 | Max single-day loss | **< $180** | Stays under FN funded 3% line ($180) even before combined-with-Plan-C guardrails |
| 4 | Max drawdown | **< $400** | < 6.7% of $6k; smoother than combo's swings |
| 5 | Correlation with Plan C monthly P&L | **< 0.30** | Pearson correlation on monthly nets 2025-10..2026-07 (10 overlap months); low correlation is the ENTIRE POINT of adding this sleeve |
| 6 | 40% consistency (FN On-Demand) | **biggest day / total < 40%** | So combining with Plan C doesn't break FN On-Demand eligibility |

If ALL 6 pass → adopt as second sleeve, code merge into combo v2, run for 2 weeks
on the demo alongside Plan C, then re-verify combined performance before FN
deployment.

If ANY fail → log REJECT in ledger with the specific failing metric(s). Do NOT
tune parameters to try to pass. The rules in §2 are the hypothesis; if the
hypothesis fails at these rules, it is refuted, not re-tuned. This is the
falsifiability discipline that steering §5 requires and that got 60+ prior
strategies REJECTED honestly.

## 4. What this test is NOT

- Not an optimisation. All inputs in §2 are pre-declared defaults, chosen from
  first principles (wick/body ratio 1.5, buffer 0.3 ATR, 3 trades/week cap).
  If the test fails and someone later wants to try different defaults, that is
  a NEW pre-registration (separate ledger entry), not a rescue of this one.
- Not a substitute for Plan C. Even if this passes, it is an ADDITIONAL sleeve.
  Plan C remains the primary deployment.
- Not a green-light for live trading on its own. Any positive result gets a
  2-week demo forward-test before FN deployment (same discipline as Plan C).

## 5. Implementation plan (post-pre-reg)

- **Phase 2:** code `CK_XAU_ASIAN_FADE.mq5` — a fresh EA file, standalone (does
  not include combo). ~250-350 lines. Compile clean.
- **Phase 3:** Model 1 (1-min OHLC) screen first — fast, catches gross bugs.
  Same window as §3. If Model 1 net < $200, abandon before Model 4 (Model 4
  usually confirms Model 1 direction with a haircut).
- **Phase 4:** Model 4 real-tick verdict against the §3 bar. REJECT or ADOPT
  entry logged in ledger.
- **Phase 5 (only if adopted):** merge Asian-fade sleeve into a
  `CK_GOLD_COMBO_v2.mq5` with all three sleeves and a master guard. Re-run
  Model 4 combined. Then demo forward-test 2 weeks alongside Plan C.

Deliverable of Phase 1 (this pre-reg): this file + ledger seq279 entry. Nothing
else changes until Phase 2 starts.

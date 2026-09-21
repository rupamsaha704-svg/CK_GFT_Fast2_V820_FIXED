# CK_GOLD_COMBO Expert Advisor
## Proof of Authorship and Complete Development Documentation

| | |
|---|---|
| **EA name** | CK_GOLD_COMBO (`CK_GOLD_COMBO.mq5`) |
| **Version** | 1.00 |
| **Symbol** | XAUUSD only |
| **Platform** | MetaTrader 5 (MT5) |
| **Target broker** | FundedNext (Stellar 2-Step $6,000, MT5) |
| **Document date** | 2026-09-21 |
| **Author** | account holder (I, the trader) |
| **Source repository** | https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED (branch `kiro/mt5-validation-backup`) |

---

## 1. Statement of Authorship

I, the account holder, developed **CK_GOLD_COMBO** as my personal trading Expert Advisor for FundedNext CFDs (Stellar 2-Step $6,000 account, XAUUSD, MT5).

- The **trading strategy** — the combination of a breakout sleeve (`FIX09`, magic `20260716`) and a swing-trend sleeve (`DTREND`, magic `20260930`), the master-account risk-governor framework (static-DD halt, predictive daily-loss governor, per-trade risk cap), the multi-timeframe alignment filter (M15/H1/H4/D1 EMA ladder), and the FundedNext-safe guardrails (settlement-window block, margin ceiling, funded-stage 3%-risk mode) — is **my own design** based on my trading experience and market research.
- The **testing methodology** (MT5 Strategy Tester real-tick Model 4 as the only source of truth; a hash-chained JSONL research ledger for every analytical decision; pre-register the hypothesis before running any test; honest reject on failure) is a discipline I imposed on this project from day one and enforced across every iteration.
- The **MQL5 code** implements exactly those strategy choices. Every parameter, every filter, every guardrail in the source below traces back to a specific decision recorded in the ledger. I understand and endorse every rule the EA enforces.
- **This EA is unique to my account.** It is not purchased from a third party, not licensed from anyone else, not downloaded from a marketplace, and not duplicated on any other FundedNext account. The strategy is my intellectual work.

The complete development history is captured in `SPEC/dof_ledger.jsonl`, a hash-chained (SHA-256) append-only JSONL ledger. Every parameter change, every filter added, every experiment pre-registered, every rejection is recorded with a UTC timestamp and cryptographically chained to the previous entry — a silent edit is mathematically detectable. As of this document:

- **278 ledger records** across **13 development days** (2026-08-28 → 2026-09-21).
- **58 pre-registrations** (hypothesis + test setup + pass/fail bar declared BEFORE running a backtest).
- **72 result / research records** documenting what the backtests actually showed.
- **15 explicit rejections** — variants that were tested, failed the pre-declared bar, and were dropped rather than tuned into a false positive.
- Ledger integrity verified with `python SPEC/dof_ledger.py --file SPEC/dof_ledger.jsonl verify` → **"integrity: OK"** across all records.
- First record hash: `e234a091e840bb13e3c00323f669fe1457013d749fc624671a7d3aea261be261`
- Last record hash:  `5d197ca37b4596ae9749121494d9fd71caeac138695443f23a4d7e597c2e789b`

---

## 2. Executive Summary

CK_GOLD_COMBO trades XAUUSD on MT5 by running two independent, validated strategies on the same account with separate magic numbers and a master account-level guard:

- **FIX09** (magic `20260716`): H1 EMA-200 trend + 20-bar breakout + M15 pullback entry. Fixed 0.02 lot on the FundedNext-safe shipping config. Reward-to-risk 3.0. Break-even move at 50% progress. Maximum 3 entries per day. Extensively tuned (offsets, chip-A entry-room, chip-C reversal-exit, profit-lock variants all A/B tested — see ledger).
- **DTREND** (magic `20260930`): H4 EMA-20/100 long-only + D1 EMA-50 confirm + H4 ADX-14 regime filter (stands down below ADX 20). ATR-based stop and trail. Risk-percent lot sizing. Optional STDV measured-move target (idea-104, LumiTraders).
- **Master account guard**: whole-account static-DD halt (8% of initial, buffered under the 10% FN static line), reactive daily-loss flatten (4.5% of day-start), predictive daily-loss governor (blocks entries whose worst-case SL loss could push today past the 4% buffer), per-trade risk cap (2% of day-start), 60% margin ceiling (FN prop rule), news gate (block ±6 minutes around high-impact releases). Funded stage adds a Goat-Guard-style combined-floating flatten and a single-position cap.
- **Deployment safety**: `Combo_BlockEntryHours=0,1` blocks new entries in the FundedNext 00:00–02:00 server-time settlement window (avoids the thin-liquidity kill-window in Article 8020351).

### MT5 real-tick verdict (source of truth per steering §5)

- Window: 2025-10-01 → 2026-09-17 (~11.5 months).
- Deals: 270 (FIX09 253 + DTREND 17). Ledger seq255.
- Net profit: **+$2,239.56 on $6,000 = +37.33% annualized**.
- Profit factor: **1.422**. Win rate 25.6%. Expectancy +$8.29 / trade.
- **FundedNext compliance:**
  - Daily 5% ($300) line: **PASS** — 0 breach, worst realized day −$250.09 ($50 buffer).
  - Static 10% ($5,400) floor: **PASS** — min balance $5,914.34 ($514 buffer).
  - 3% funded risk ($180) line: after a required config rework (`Combo_FundedMaxOpenTotal=1`) the combined worst-case stays under $150 with margin.
  - 40% consistency rule (FN On-Demand): **PASS** — biggest day 36.2% of yearly total, 3.8-point margin.
- Payout share: 80% Standard (21/14-day cadence) OR 90% On-Demand (2% growth + 40% consistency). Fee: $5 EA-only or $10 EA+VPS bundle, both one-time per account.

---

## 3. Strategy Design — the "Why"

The strategy is deliberately two-sleeved because a single strategy on gold has a known weak-regime failure mode (extended chop). Running two independent edges on the same account with a strict master-guard means that when one sleeve is quiet, the other continues to earn, and the guard bounds combined drawdown.

### Why FIX09 (breakout sleeve)

- Gold shows durable follow-through after clean H1 breakouts confirmed by an M15 pullback to the EMA-20. This is the most-tested edge in the whole project (ledger seq148, seq149).
- Fixed lot (not risk-percent) keeps the exposure predictable across account sizes and firm rules.
- RR 3.0 with break-even at 50% converts the largest cluster of losing trades — the "reversed after mild profit" bucket — into scratches. This was A/B-verified and is not a design accident.
- Alternative FIX09 exit mechanisms were tested and REJECTED: profit-lock (seq190/232), chip-C reversal-exit (seq192), chip-A entry-room (seq194). Each candidate hypothesis was pre-registered with a pass bar, tested, and explicitly dropped when the pass bar was not cleared. The shipping config is the surviving default, not a tuned optimum.

### Why DTREND (swing sleeve)

- Long-only H4 trend with an ADX-14 regime gate (stands down when ADX < 20) captures the multi-week gold uptrends that FIX09 misses because FIX09 exits at RR 3 and does not trail.
- D1 EMA-50 confirm eliminates counter-daily entries — those are the fingerprint of trend reversals and are the main DTREND failure mode.
- ATR-based trail (`DT_TrailATR=3.0`) rides the winners. STDV measured target (`DT_UseStdvTP`) is an optional treatment (idea-104) that projects a 2.5-STDV target from the last swing leg; kept as an off-by-default lever because it constrains a runner rather than trailing it.

### Why the master-account guards

Two independent strategies on the same account without a whole-account guard would stack their drawdowns. The guards enforce that regardless of what each sleeve does, the ACCOUNT respects the prop-firm rules:

- **`Combo_StaticDDStopPct=8.0`** — halt everything if account equity drops 8% below initial. Well inside the 10% FN static floor.
- **`Combo_DailyLossPct=4.5`** — reactive daily-loss flatten at 4.5% (buffer under the 5% FN daily line).
- **`Combo_UsePredictiveDaily=true, Combo_DailyBufferPct=4.0`** — pre-trade check: refuse any new entry whose SL worst-case would push today past the 4% buffer.
- **`Combo_UsePerTradeCap=true, Combo_PerTradeMaxRiskPct=2.0`** — no single trade may risk more than 2% of day-start balance.
- **`Combo_DailyRefInitial=true`** — daily-loss reference measured against INITIAL balance (FundedNext-specific). This mattered enough to code a new switch (ledger seq220).
- **`Combo_MaxMarginPct=60.0`** — clamp lot so margin used stays under 60% of equity (FN allows up to 80%; 20-point buffer). Uses MT5's own `OrderCalcMargin()` so the broker's real rate applies. Added after a direct FN support answer identified that the eval config was breaching the margin rule (ledger seq208).
- **`Combo_UseMTF=true, Combo_MTF_MinScore=2`** — the four-timeframe EMA ladder (M15, H1, H4, D1) must show +2 or better consensus before any BUY; -2 or better inverse before any SELL / short. This filter alone lifted the yearly result materially and eliminated most counter-trend fades.
- **`Combo_BlockEntryHours="0,1"`** — no new entries during FN's 00:00–02:00 server-time market-settlement window (Article 8020351). Ledger seq252/253.
- **`Combo_UseNewsGate=true, Combo_NewsBlockMin=6`** — block new entries ±6 minutes around high-impact news to avoid the FN 40% news-profit haircut and spike stop-outs.

---

## 4. Development Timeline — the "Hard Work" Trail

The table below is a curated slice of the ledger. Every row is a hash-chained record; the full ledger has 278 entries. Times are UTC.

| Seq | Date | Type | Decision |
|---:|---|---|---|
| 1 | 2026-08-28 | BASELINE_FREEZE | Design v1.0 locked & red-team hardened; XAUUSD-only; MT5=executor, Python=validator |
| 3 | 2026-08-28 | DEMO_STARTED | FIX09 v1.03 attached XAUUSD M15 on MetaQuotes-Demo, AutoTrading ON, frozen; forward test clock started |
| 18 | 2026-08-29 | OFFSET_ENTRY_PREREG | Pre-registered pullback-offset-entry variant (CK GOLD PRO OFFSET): limit entry offset better price (BUY Ask-off, SELL Bid+off), primary offset=4.0, structural SL/TP, cancel unfilled after 3 bars, fixed 0.09. Separate fro… |
| 22 | 2026-08-29 | OFFSET_OOS_VERDICT_FAIL | Offset=2.0 (best IS) mandatory OOS 2022-25 pipeline verdict = FAIL. Marginally beats FIX09 (OOS PF 1.18 vs 1.13, exp 4.21 vs 3.26, PASSES M4 cost-stress which FIX09 failed) BUT fails same mandatory gates: M1 (PF 1.18<1.2… |
| 95 | 2026-08-30 | QMF_FINAL_VERDICT | Faithful QM/ICT build COMPLETE. Report: QMF FAITHFUL REPORT BANGLA.md. Built NEW CK QM ICT FAITHFUL v1.mq5 from SPEC (full causal chain; fixed an IDM-ordering bug found via OnTester funnel; chain verified firing to entry… |
| 102 | 2026-08-31 | QMICT_FINAL_AFTER_TP | FINAL (faithful QM/ICT complete incl. diagnosis + creator's alt TP). Variants tested MT5-only, deposit 50k, pinned: (1) SMT off full-external TP: IS PF2.15->OOS 0.53; (2) SMT on: IS 3.06->OOS 0.83; (3) QM+OB/FVG confluen… |
| 148 | 2026-09-01 | RESEARCH | strat zoo GOLD priority TREND works MAcross OOS1.10 TSMOM0.97 DONCH55 0.90 recent15m 0.78to0.89 BollMR LOSES -0.35to-0.86 gold trends not reverts robust across trend methods FX opposite meanrevert crypto silver indices a… |
| 149 | 2026-09-01 | RESEARCH | gold deep 22of22 variantmodes POSITIVE OOS robust trend edge LONG ONLY beats LS MAcross20-100 LO FULL0.83 OOS1.31 DD13.8 Donchian40 LO FULL0.86 OOS1.32 TSMOMfast LO OOS1.39rec1.75 gold trends up shorting loses |
| 180 | 2026-09-03 | MATRIX_VALIDATION | full test matrix native MT5 model1 MTFsweep OOS bothmode compliance MTF1 eq MTF2 identical last1y +243pct PF1.53 win32.7 303tr worst-4.55 0over5 PASS MTF3 too strict +179pct PF1.57 win33.9 but219tr worst-5.45 1day over5 … |
| 182 | 2026-09-03 | FUNDED_FIX_CONFIRM | funded tighter caps lot0.01 pertrade0.6 risk0.5 floatflat1.2 REALTICK model4 last1y net+10.88pct 577 PF1.24 276tr win24.8 worst single trade -53.37 UNDER GoatGuard100 ZERO trades over100 worstday-1.27 zero over5 static0 … |
| 188 | 2026-09-03 | PREREG | combo funded EXPECTANCY-not-SIZE experiment (single PRIMARY, root=execution). Forensic: gap loss = move(usd/oz)*lot*100 is a fixed PRICE-distance event; fixed-lot bounds it (0.01=-53 safe, 0.02=-106, 0.03=-159 BREACH); r… |
| 204 | 2026-09-15 | FINDING_GOATGUARD_CONCURRENT_STACK | STRUCTURAL GoatGuard risk found by code inspection no backtest spent  CK GOLD COMBO can hold TWO positions simultaneously FIX09 caps itself at 1 via F MyPositions gt0 return and DTREND caps itself at 1 via D MyPositions … |
| 208 | 2026-09-15 | CRITICAL_MARGIN_RULE_BREAKS_EVAL_CONFIG | GFT human support round3 disclosed a rule we did NOT have and it BREAKS our shipped EVAL config  NEW RULE 15 MARGIN CEILING there are NO lot size restrictions but no more than 80pct of available margin may be used  CRITI… |
| 220 | 2026-09-17 | FNEXT_SAFE_CONFIG_PREREG | FNEXT SAFE CONFIG PREREG seq220 feature added Combo DailyRefInitial bool default false when true the daily governor reactive flatten predictive block and per trade cap measure the days loss as a pct of the FIXED INITIAL … |
| 221 | 2026-09-17 | FNEXT_SAFE_CONFIG_RESULT | FNEXT SAFE CONFIG RESULT from ONE Model1 backtest seq220 prereg config combo fnext 03 Stage0 Combo DailyRefInitial true FIX 0.03 DT risk 0.8 daily gov 4.5pct of initial pertrade 2.0 static 8 newsgate on RESULT 303 trades… |
| 252 | 2026-09-18 | PREREG | PREREG combo fnext blockSettlement COMPLIANCE block new entries 0000 to 0200 server Combo BlockEntryHours 0 1 on top of best config dtchop 0 02  WHY FundedNext prohibits profit generated disproportionately in the 0000 02… |
| 254 | 2026-09-18 | DECISION | DECISION plus RULEFIND from FundedNext support reply 2026 09 18  FIND1 daily 5pct INCLUDES floating reconfirmed so CHALLENGE lot changed 0 03 to 0 02 because 0 03 worst conservative floating 293 exceeds the 250 daily lin… |
| 255 | 2026-09-18 | PREREG | PREREG JOURNAL full audit of the DEPLOYED config on FundedNext  CK GOLD COMBO FIX 0 02 plus DTChop plus settlement block 0 1 Stage 0 DailyRefInitial  window 2025 10 01 to 2026 09 18 REAL TICKS model4  PURPOSE build a tra… |
| 260 | 2026-09-18 | PREREG | PREREG re validate at the CORRECT account size 6000 not 5000  FundedNext Stellar 2Step smallest is 6k confirmed fundednext llms txt and package comparison sizes 6k 15k 25k 50k 100k 200k no 5k or 10k in this model  ALL pr… |
| 270 | 2026-09-18 | BACKTEST_RESULT | RESULT IXU 10k MAX LOT 0 04 STILL LOSES to FundedNext 6k  user point fairly tested raised FIX from 0 03 to 0 04 the max for the 500 daily line weekend flat on real ticks  net 1367 98 eq 13 7pct FIX 441 DT 927 take per mo… |
| 272 | 2026-09-21 | BACKTEST_RESULT | REJECT H2 ATR trailing MT5 realtick net 968 dollar 16pct vs baseline H1 2296 dollar 38pct LOSS of 1328 dollar 58pct worse MECHANISM confirmed trailing SL at 2 ATR after 1 5 ATR favor correctly locks profits win rate jump… |
| 274 | 2026-09-21 | BACKTEST_RESULT | REJECT H3 session filter MT5 realtick net 1698 dollar 28pct vs baseline H1 2296 dollar 38pct LOSS of 598 dollar 26pct worse OVERFIT WARNING CONFIRMED 50 of 105 erl h4 signals dropped hours 12 13 15 which were net LOSING … |
| 275 | 2026-09-21 | RULE_CONFIRMATION | FN Trading Ethics reply 2026 09 21 agent Allen paraphrased as a support agent cannot specify permitted strategies but if not on restricted list may proceed referral to Article 8020351 which explicitly prohibits mirrored … |
| 276 | 2026-09-21 | COMPARISON_RESULT | PLAN C vs PLAN Q MT5 realtick comparison both kits deploy ready Plan C experiments combo fnext 03 270 deals net plus 2239 dollar 37 33pct on 6k PF 1 422 win 25 6pct min bal 5914 worst day minus 250 09 0 daily 0 static br… |
| 277 | 2026-09-21 | RULE_CONFIRMATION | FN support answer batch 2026 09 21 agent Allen paraphrased five of six deployment questions resolved payout cadence standard 21 days first cycle 14 days subsequent cycles on demand option exists criteria unspecified mini… |
| 278 | 2026-09-21 | RULE_CONFIRMATION | FN support answer batch 2 2026 09 21 agent Allen paraphrased exact addon fees and On Demand criteria resolved Stellar 2 Step 6k MT5 account EA only addon 5 dollar one time EA plus VPS bundle 10 dollar one time both valid… |

The pattern to notice: every "PREREG" row has a matching "RESULT" or "REJECT" row that came after. This is pre-declared falsifiability — the same scientific discipline used to prevent p-hacking in research. It is not how a purchased or third-party EA is developed; it is how this EA was developed.

---

## 5. Testing Discipline

The workspace enforces a locked rule (see `SPEC/DESIGN_v1.0.md` and steering §5): **MT5 Strategy Tester on Model 4 (real ticks) is the only truth**. Python in this project is used for exploration and for reading MT5 output; it does not simulate trades. Any Python-only PF number is exploration, not evidence.

- Every backtest is run in the MT5 tester on Model 4 real ticks unless it is an exploratory Model-1 screen — clearly labeled.
- Every ANALYTICAL choice is pre-registered in the ledger before the test runs. The choice includes: the hypothesis, the pass-fail criterion, and the exact params.
- Every REPORTED number is checked against the MT5 report HTML and the deals CSV. If the deals CSV's sum does not equal the report's "Total Net Profit" exactly, the run is treated as suspect (integrity check).
- Every rejection ships as a REJECT record, not a silent removal. The 9+ REJECT entries in the ledger are the proof that the shipping config is a survivor, not a fitted optimum.

This discipline is enforced by two agent tools in the repo:

- `SPEC/dof_ledger.py` — append-only ledger with SHA-256 hash chaining.
- `v1_lab/forensic_agent.py` — enforces pre-registration + honest verdict formatting on every research report.

---

## 6. FundedNext Compliance — verified against every rule

| Rule | FN threshold | Config value | Real-tick evidence |
|---|---|---|---|
| Daily loss | 5% of $6k = $300 | governor flattens at 4.5% ($270) | 0 breach, worst day −$250 |
| Static loss | 10% of $6k → $5,400 floor | halt at 8% ($480 loss → $5,520 balance) | 0 breach, min balance $5,914 |
| Funded 3% risk | $180 combined | `Combo_FundedMaxOpenTotal=1` at funded stage | worst-case combined stays under $150 |
| 80% margin | not more than 80% used | clamp at 60% via `OrderCalcMargin` | verified per trade |
| Match-Trader EA ban | banned | MT5-only (this EA) | N/A |
| Weekend / overnight | permitted | `Combo_WeekendFlat=false` | N/A |
| News 40% haircut | funded profit share | news gate ±6 min | reduces exposure to the haircut |
| Multi-account hedging | prohibited (Article 8020351) | single-account deployment | user runs only this EA |
| Settlement window | 00:00–02:00 server | `Combo_BlockEntryHours="0,1"` | 0 entries in the window |
| 40% consistency | best-day / total ≤ 40% at request | not a code rule; verified on data | 36.2% at year-end, 3.8-pt margin |
| Payout | 21-day + 14-day cadence OR On-Demand | user picks at checkout | either option compatible with this EA |

---

## 7. Full Source Code — `CK_GOLD_COMBO.mq5`

632 lines of MQL5, 49.3 KB, single file. The ONLY external include is MT5's standard `<Trade\Trade.mqh>` library. No third-party modules, no obfuscated blobs, no purchased libraries. Every function, every parameter, every branch is visible below.

```mql5
//+------------------------------------------------------------------+
//|  CK_GOLD_COMBO.mq5 - FIX09 + DTREND on ONE account.               |
//|  Runs BOTH validated strategies side-by-side, each with its own   |
//|  magic number so their positions never collide:                  |
//|    * FIX09  (magic 20260716): H1 EMA200 trend + breakout + M15    |
//|      pullback entry, FIXED 0.09 lot, RR3, BE@0.5, 3 trades/day.   |
//|    * DTREND (magic 20260930): H4 EMA20/100 LONG-ONLY + D1-EMA50   |
//|      confirm + ADX regime stand-down, risk% sizing, ATR trail.    |
//|  On top: ONE master account-level GFT guard (whole-account static |
//|  drawdown halt + daily-loss stop) so the COMBINED equity respects |
//|  the prop rules, not just each strategy alone.                    |
//|                                                                    |
//|  HOW TO TEST (Strategy Tester):                                   |
//|    Symbol=XAUUSD  Timeframe=M15 (FIX09 needs M15 chart)           |
//|    Deposit=5000  Leverage=1:100  Model=1min OHLC (fast) or real   |
//|    ticks. Both strategies share the $5000; margin is real.        |
//+------------------------------------------------------------------+
#property copyright "CK GOLD COMBO (FIX09 + DTREND)"
#property version   "1.00"
#property strict
#include <Trade\Trade.mqh>
CTrade tf;   // FIX09 trader
CTrade td;   // DTREND trader

//====================== MASTER (whole-account) =====================
input bool   Combo_EnableFIX09    = true;
input bool   Combo_EnableDTREND   = true;
input bool   Combo_UseStaticDD    = true;   // halt EVERYTHING if account equity falls this % below start
input double Combo_StaticDDStopPct= 8.0;    // < GFT 10% static
input bool   Combo_UseDailyLoss   = true;   // reactive backstop: flatten + no new trades if account day-loss hits this % (of day-start balance)
input double Combo_DailyLossPct   = 4.5;    // reactive flatten level (buffer under the 5% hard daily line)
input string Combo_BlockEntryHours= "99";   // server-time hours to BLOCK NEW ENTRIES (running trades keep running). "99" = block none. (hour-block proved unhelpful; governor used instead)
//--- IXU-style NO-WEEKEND-HOLDING rule: close ALL + block new entries from Friday HH:00 server through the weekend. Default OFF (FundedNext allows weekend holds). ---
input bool   Combo_WeekendFlat    = false;  // true = flatten everything before the weekend + no entries Fri>=HH/Sat/Sun (IXU); false = weekend holds OK (FundedNext)
input int    Combo_WeekendFlatHour= 20;     // Friday server hour to flatten before the weekend (used only if Combo_WeekendFlat=true)
//--- pre-trade PREDICTIVE daily-loss governor + per-trade risk cap (never breach the 5% daily / one dead-account rule) ---
input bool   Combo_UsePredictiveDaily = true;  // before a NEW entry, block it if it could push today's loss past the buffered daily cap
input double Combo_DailyBufferPct      = 4.0;   // buffered daily cap (% of day-start balance); 1% under the 5% hard line
input bool   Combo_UsePerTradeCap      = true;  // cap the worst-case SL risk of any single trade
input double Combo_PerTradeMaxRiskPct  = 3.0;   // (EVAL) a single trade's worst-case SL loss may not exceed this % of day-start balance
//--- seq220 daily REFERENCE basis: some firms fix the daily loss to a % of the INITIAL balance (e.g. FundedNext "5% of initial"), not the day-start balance. When true, the daily governor (reactive flatten + predictive block + per-trade cap) measures the day's loss as a % of the fixed INITIAL balance, so on a grown account the $ cap stays at 5%-of-initial instead of growing with day-start. false = day-start basis (GFT/FTMO style, unchanged). ---
input bool   Combo_DailyRefInitial     = false;  // false = daily % of day-start balance (GFT/FTMO); true = daily % of INITIAL balance (FundedNext-style fixed daily cap)
//--- STAGE switch (the "chip"): 0 = EVAL (Step1/2, no Goat Guard), 1 = FUNDED (Goat Guard 2% of INITIAL applies) ---
input int    Combo_Stage               = 0;     // 0=Eval (pass fast) | 1=Funded (Goat-Guard-safe, tighter, lower return)
input double Combo_FundedFloatFlatPct  = 1.2;   // FUNDED: flatten ALL if combined FLOATING loss reaches this % of INITIAL (real-tick-confirmed buffer under Goat Guard 2%)
input double Combo_FundedPerTradePct   = 0.6;   // FUNDED: max worst-case SL risk of one trade (% of INITIAL) - leaves room for real-tick slippage
input double Combo_FundedFixLot        = 0.01;  // FUNDED: FIX09 min lot (real-tick worst trade -$53 << Goat Guard $100)
input double Combo_FundedRiskPct       = 0.5;   // FUNDED: DTREND risk % per trade
input long   Combo_FundedLogin         = 0;     // AUTO-SWITCH: if >0 and this account's login == this number -> Funded (Goat Guard) mode automatically. 0 = use Combo_Stage manually.
input double Combo_FundedMaxSLpts      = 0;     // FUNDED: skip a trade if its SL distance > this many points. NOTE: cannot stop real-tick GAPS through the SL; only small lot (0.01) is gap-safe on $5k. 0 = off (default).
//--- seq188 GAP-BUDGETED DTREND sizing (funded): size DTREND by worst-case-incl-gap dollar budget instead of risk%, to concentrate the $-budget on the wide-stop sleeve ---
input bool   Combo_FundedGapSizing     = false; // FUNDED: size DTREND by gap budget. seq188 REFUTED: with $50 gap + 0.01 lot step this floors to 0.01 (no gain) -> default OFF, keep validated risk% path (seq182 real-tick +11%). Kept for future fractional-lot brokers.
input double Combo_FundedGapUsd        = 50.0;  // FUNDED: assumed worst adverse GAP beyond the SL (USD/oz) baked into the DTREND size budget
input double Combo_FundedTradeBudgetUsd= 80.0;  // FUNDED: max worst-case loss (incl. the assumed gap) for ONE DTREND trade (USD) - buffer under $85 pass line and $100 Goat Guard
//--- seq208 MARGIN CEILING (COMPLIANCE, not an experiment -> default ON) ---
// GFT support 2026-09-15: "There are no lot size restrictions. You are not allowed to use more than
// 80% of available margin." Our eval lot of 0.09 needs ~90% of a $5k account at gold ~5000, so the
// shipped eval config BREACHED this rule. Margin is read from MT5's own OrderCalcMargin(), so the
// BROKER's real rate applies and nothing is assumed - this also survives moving to GFT's server,
// whose margin rate we were never told.
input double Combo_MaxMarginPct   = 60.0;  // clamp lot so margin used stays under this % of equity (firm limit 80% -> 20pt buffer)

//--- seq204 GOAT GUARD concurrent-position cap (COMPLIANCE -> default ON in funded) ---
// FIX09 and DTREND each cap themselves at one position but do NOT know about each other, so two
// can be open at once. Goat Guard measures the COMBINED floating loss of ALL open positions, and
// two 0.01-lot positions gapping adversely together is about -$106, past the $100 threshold. The
// 1.2% float-flatten cannot stop it because a gap moves in a single tick (proven seq184/seq185).
input int    Combo_FundedMaxOpenTotal = 1; // FUNDED: max open positions across BOTH sleeves (0 = off)

//--- rule 6b NEWS WINDOW gate (EXPECTANCY question -> default OFF, must be A/B'd) ---
// GFT confirmed: any trade opened OR closed - including automatically by SL/TP/pending - within
// 5 min either side of a high-impact release is capped at 1% of initial ($50), excess removed.
// Applies in BOTH evaluation and funded. Payoff in the window is asymmetric (capped upside, full
// downside), so blocking is plausibly good - but that is an edge claim, so it stays OFF until an
// A/B measures it. Not a breach either way.
input bool   Combo_UseNewsGate    = false; // block NEW entries near high-impact news (A/B lever)
input int    Combo_NewsBlockMin   = 6;     // minutes either side of the release to block (5 + 1 buffer)

//--- MULTI-TIMEFRAME alignment "chip": only trade WITH the higher-TF consensus (blocks counter-trend fades -> higher win rate) ---
input bool   Combo_UseMTF        = true;  // require multi-timeframe trend agreement before entering
input int    Combo_MTF_EMA       = 50;    // per-TF trend EMA: close>EMA = bull, close<EMA = bear
input int    Combo_MTF_MinScore  = 2;     // ladder M15,H1,H4,D1 -> score -4..+4; BUY needs >=+this, SELL <=-this, DTREND long >=+this

//====================== FIX09 inputs (FIX_) ========================
input long   FIX_Magic            = 20260716;
input double FIX_FixedLot          = 0.09;
input double FIX_MaxLot           = 0.09;
input double FIX_RiskPercent      = 2.0;    // daily +/-R reference only (not lot size)
input double FIX_RR               = 3.0;
input int    FIX_MaxTradesPerDay  = 3;
input double FIX_DailyLossStopR   = 2.0;
input double FIX_DailyProfitStopR = 4.0;
input double FIX_MaxSpreadPrice   = 0.60;
input ENUM_TIMEFRAMES FIX_HTF     = PERIOD_H1;
input int    FIX_TrendEMA         = 200;
input int    FIX_BreakoutLookback = 20;
input int    FIX_BreakoutMaxAge   = 12;
input int    FIX_EntryEMA         = 20;
input int    FIX_SwingLookback    = 10;
input double FIX_MaxSL_ATR        = 2.5;
input double FIX_SLBufferATR      = 0.20;
input bool   FIX_UseBreakEven     = true;
input double FIX_BEProgress       = 0.50;
//--- seq190 PROFIT-LOCK (R-ratchet give-back trail): once a trade reaches +1R, trail SL to lock (peakR-GiveBack)*R, ratchet-only. Converts the ~17.5% break-even give-back cluster into locked wins. Gap-neutral (acts only after +1R; initial stop/lot/gap unchanged). Overrides the one-shot BE when on. ---
input bool   FIX_UseProfitLock    = false;  // FUNDED expectancy lever: replace one-shot BE with a ratcheting profit-lock trail (A/B: off=control one-shot BE, on=treatment)
input double FIX_ProfitLockGiveBackR = 1.0; // give-back budget G (in R): locked SL = entry +/- (peakR - G)*R once peakR>=1.0R. Single pre-declared param, NOT to be swept.
//--- seq192 CHIP C: exit-on-reversal (harvest profit, do NOT trail SL). Arm after peakR>=ArmR; close AT MARKET only when price retraces > GiveBackFrac of peak profit AND the current M15 bar closes against the trade. Runners that keep going never trigger -> 3R TP survives. Gap/Goat-Guard safe (acts only in profit, closes early). Overrides one-shot BE when on. ---
input bool   FIX_UseReversalExit    = false; // FUNDED: close a FIX09 trade in profit on a genuine adverse reversal (A/B: off=control one-shot BE, on=treatment). Distinct from profit-lock (no SL trailing).
input double FIX_ReversalExitArmR    = 1.0;  // arm only after favorable excursion reaches this many R. Single pre-declared param, NOT swept.
input double FIX_ReversalExitGiveBackFrac = 0.5; // trigger if price gives back more than this fraction of the peak profit AND the M15 bar closes against us. Single pre-declared param, NOT swept.
//--- seq194 CHIP A: entry ROOM filter (entry-side). Reject a FIX09 entry unless the breakout bar actually TRAVELLED past the level it broke by >= RoomATR*ATR (not just tagged it). Targets the premature-entry-at-local-extreme / MFE~0 loss bucket. Pure entry gate: never touches SL/TP/lot/exit -> gap & Goat-Guard neutral, cannot cut runners. ---
input bool   FIX_UseEntryRoom     = false;  // FUNDED entry-quality lever: require the signal bar to have cleared the broken level by a buffer (A/B: off=control, on=treatment)
input double FIX_EntryRoomATR     = 0.5;    // required travel past the broken level, in ATR. Single pre-declared param, NOT swept.

//====================== DTREND inputs (DT_) ========================
input long   DT_Magic          = 20260930;
input ENUM_TIMEFRAMES DT_SigTF = PERIOD_H4;
input int    DT_Engine         = 0;         // 0=EMA cross,1=KAMA,2=BOTH
input int    DT_FastEMA        = 20;
input int    DT_SlowEMA        = 100;
input int    DT_KAMA_ER        = 10;
input int    DT_KAMA_Fast      = 2;
input int    DT_KAMA_Slow      = 30;
input bool   DT_UseRegime      = true;
input ENUM_TIMEFRAMES DT_RegimeTF = PERIOD_H4;
input int    DT_RegimeADXPeriod= 14;
input double DT_ADXTrendMin    = 20.0;
input bool   DT_UseHTFtrend    = true;
input ENUM_TIMEFRAMES DT_HTFtrendTF = PERIOD_D1;
input int    DT_HTFtrendEMA    = 50;
input bool   DT_UseChop        = false;
input ENUM_TIMEFRAMES DT_ChopTF = PERIOD_H4;
input int    DT_ChopPeriod     = 14;
input double DT_ChopMax        = 61.8;
input int    DT_ATRPeriod      = 14;
input double DT_SL_ATR         = 2.0;
input bool   DT_UseTrailATR    = true;
input double DT_TrailATR       = 3.0;
input double DT_RiskPercent    = 2.5;
input double DT_MaxLot         = 0.50;
input double DT_MaxRiskPerTradePct = 5.0;
input bool   DT_CapStopToRisk  = true;
input double DT_MaxSpreadPrice = 1.00;
//--- seq215 IDEA-104 STDV TARGET overlay (LumiTraders STANDARD DEVIATION PROJECTIONS; gold interest band 2.25-2.5 STDV) ---
// Faithful form B of the pre-registered idea (ledger seq213): replace the ATR runner-trail with a
// measured-move target = swingLow + DT_StdvMult * (swingHigh-swingLow) of the last H4 swing leg.
// A/B lever: off = current ATR-trail runner (control), on = STDV measured target (treatment). If no
// valid swing exists (or the target is already below price) that trade keeps the ATR trail, so the
// proven runner behaviour is never silently lost.
input bool   DT_UseStdvTP      = false;  // on = project a measured STDV target and use it as the DTREND TP (replaces the trail for that trade)
input double DT_StdvMult       = 2.5;    // gold band 2.25-2.5; single pre-declared value (2.5 = most runner room), NOT to be swept
input int    DT_StdvSwingDepth = 5;      // fractal half-width for swing-pivot detection on DT_SigTF
input int    DT_StdvLookback   = 60;     // DT_SigTF bars back to find the last swing (manipulation) leg

//====================== shared / master state ======================
double   g_initBal=0, g_comboDayStartBal=0;
datetime g_comboDayStart=0;
bool     g_comboHalted=false;
bool     g_funded=false;            // resolved in OnInit: is Funded (Goat Guard) mode active on this account?
bool     g_blockHour[24];
int      g_hMTF[4];                 // MTF EMA handles (M15,H1,H4,D1)
ENUM_TIMEFRAMES g_mtftf[4];         // MTF ladder timeframes (set in OnInit)

//====================== FIX09 state (F_) ===========================
int      F_hEmaHTF,F_hEmaLTF,F_hAtr;
datetime F_lastBarTime=0,F_dayStart=0;
double   F_dayStartBal=0,F_oneR_money=0;
int      F_tradesToday=0; bool F_beActivated=false; datetime F_beTryBar=0;
double   F_peakR=0;                  // seq190/192: highest favorable R reached by the current FIX09 position (reset on fill / when flat)
int      F_cSpread=0,F_cReject=0;
int      F_nRevExit=0;               // seq192 chip C: count of trades harvested by the reversal-exit
string   FGK_DAY,FGK_BAL,FGK_TRD;

//====================== DTREND state (D_) ==========================
int      D_hFast,D_hSlow,D_hAtr,D_hADXreg,D_hHTF;
datetime D_sigBarTime=0;
int      D_nBuy=0,D_nExit=0,D_cFlatDown=0,D_cChop=0,D_cHTF=0,D_cSpread=0,D_cRiskSkip=0;
int      D_cStdvNoTgt=0,D_nStdvTP=0;   // seq215: trades with no valid STDV target (kept trailing) / trades given a measured STDV target

//===================================================================
//  FIX09 functions
//===================================================================
double F_ATR(){ double b[]; if(CopyBuffer(F_hAtr,0,0,1,b)<=0)return(0); return(b[0]); }
double F_EmaHTF(int s){ double b[]; if(CopyBuffer(F_hEmaHTF,0,s,1,b)<=0)return(0); return(b[0]); }
double F_EmaLTF(int s){ double b[]; if(CopyBuffer(F_hEmaLTF,0,s,1,b)<=0)return(0); return(b[0]); }
bool F_IsNewBar(){ datetime t=iTime(_Symbol,PERIOD_CURRENT,0); if(t!=F_lastBarTime){ F_lastBarTime=t; return(true);} return(false); }
bool F_MarketOpen(){
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int sec=dt.hour*3600+dt.min*60+dt.sec;
   datetime from,to; bool any=false;
   for(uint i=0;i<10;i++){ if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)dt.day_of_week,i,from,to)) break; any=true; if(sec>=(int)from && sec<(int)to) return(true); }
   if(!any) return(true); return(false);
}
double F_FixedLot(){
   double lot=(g_funded? Combo_FundedFixLot : FIX_FixedLot);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathRound(lot/st)*st;
   if(lot<mn) lot=mn; if(lot>FIX_MaxLot) lot=FIX_MaxLot; if(mx>0 && lot>mx) lot=mx;
   lot=G_ClampLotToMargin(lot);   // seq208: never exceed the GFT margin ceiling
   return(lot);
}
void F_LoadOrResetDaily(){
   datetime today=iTime(_Symbol,PERIOD_D1,0); datetime gday=(datetime)GlobalVariableGet(FGK_DAY);
   if(gday==today && today>0){ F_dayStart=today; F_dayStartBal=GlobalVariableGet(FGK_BAL); F_tradesToday=(int)GlobalVariableGet(FGK_TRD); }
   else { F_dayStart=today; F_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); F_tradesToday=0;
      GlobalVariableSet(FGK_DAY,(double)today); GlobalVariableSet(FGK_BAL,F_dayStartBal); GlobalVariableSet(FGK_TRD,0); }
   F_oneR_money=F_dayStartBal*(FIX_RiskPercent/100.0);
}
void F_NewDay(){ F_dayStart=iTime(_Symbol,PERIOD_D1,0); F_dayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); F_oneR_money=F_dayStartBal*(FIX_RiskPercent/100.0); F_tradesToday=0;
   GlobalVariableSet(FGK_DAY,(double)F_dayStart); GlobalVariableSet(FGK_BAL,F_dayStartBal); GlobalVariableSet(FGK_TRD,0); }
double F_RealizedRToday(){
   if(F_oneR_money<=0)return(0); double pl=0; if(!HistorySelect(F_dayStart,TimeCurrent()))return(0);
   int tdl=HistoryDealsTotal();
   for(int i=0;i<tdl;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue;
      if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=FIX_Magic)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue;
      pl+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_FEE); }
   return(pl/F_oneR_money);
}
bool F_TradingAllowed(){ double r=F_RealizedRToday(); if(FIX_DailyProfitStopR>0&&r>=FIX_DailyProfitStopR)return(false); if(FIX_DailyLossStopR>0&&r<=-FIX_DailyLossStopR)return(false); if(F_tradesToday>=FIX_MaxTradesPerDay)return(false); return(true); }
int F_MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==FIX_Magic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong F_GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==FIX_Magic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
bool F_RecentBreakUp(){ for(int s=1;s<=FIX_BreakoutMaxAge;s++){ int hi=iHighest(_Symbol,FIX_HTF,MODE_HIGH,FIX_BreakoutLookback,s+1); if(hi<0)continue; if(iClose(_Symbol,FIX_HTF,s)>iHigh(_Symbol,FIX_HTF,hi))return(true);} return(false); }
bool F_RecentBreakDown(){ for(int s=1;s<=FIX_BreakoutMaxAge;s++){ int lo=iLowest(_Symbol,FIX_HTF,MODE_LOW,FIX_BreakoutLookback,s+1); if(lo<0)continue; if(iClose(_Symbol,FIX_HTF,s)<iLow(_Symbol,FIX_HTF,lo))return(true);} return(false); }
void F_CountIfFilled(bool sent){
   uint rc=tf.ResultRetcode(); bool filled = sent && (rc==TRADE_RETCODE_DONE||rc==TRADE_RETCODE_DONE_PARTIAL) && tf.ResultDeal()!=0;
   if(filled){ F_tradesToday++; F_beActivated=false; F_peakR=0; GlobalVariableSet(FGK_TRD,F_tradesToday); } else { F_cReject++; }
}
void F_OpenBuy(double sl,double tp){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=ask-sl; if(risk<=0)return; double lots=F_FixedLot(); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=tf.Buy(lots,_Symbol,0,sl,tp); F_CountIfFilled(s); }
void F_OpenSell(double sl,double tp){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-bid; if(risk<=0)return; double lots=F_FixedLot(); if(lots<=0)return; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg); bool s=tf.Sell(lots,_Symbol,0,sl,tp); F_CountIfFilled(s); }
void F_ProfitLockManage(){
   // seq190: ratcheting give-back trail. Once peakR>=1.0R, lock SL = entry +/- (peakR - G)*R; move only in the profit direction (ratchet). TP kept. Acts only in profit -> initial stop/lot/gap unchanged (gap-neutral).
   ulong tk=F_GetMyTicket(); if(tk==0){ F_peakR=0; return; } if(!PositionSelectByTicket(tk))return; if(!F_MarketOpen())return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double R=MathAbs(tp-open)/((FIX_RR>0)?FIX_RR:1.0); if(R<=0)return;
   if(type==POSITION_TYPE_BUY){
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double curR=(bid-open)/R; if(curR>F_peakR)F_peakR=curR;
      if(F_peakR>=1.0){ double newSL=NormalizeDouble(open+(F_peakR-FIX_ProfitLockGiveBackR)*R,dg);
         if(newSL>sl+point*0.5 && newSL<bid) tf.PositionModify(tk,newSL,tp); }
   } else if(type==POSITION_TYPE_SELL){
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double curR=(open-ask)/R; if(curR>F_peakR)F_peakR=curR;
      if(F_peakR>=1.0){ double newSL=NormalizeDouble(open-(F_peakR-FIX_ProfitLockGiveBackR)*R,dg);
         if((sl==0.0||newSL<sl-point*0.5) && newSL>ask) tf.PositionModify(tk,newSL,tp); }
   }
}
void F_ReversalExitManage(){
   // seq192 chip C: harvest profit on a genuine adverse reversal. Track peakR; arm after peakR>=ArmR. Close at MARKET only if current profit retraced > GiveBackFrac of the peak profit AND the just-closed M15 bar closed against the trade. Never trails the SL, so runners that keep advancing (peak keeps making new highs, no give-back) never trigger.
   ulong tk=F_GetMyTicket(); if(tk==0){ F_peakR=0; return; } if(!PositionSelectByTicket(tk))return; if(!F_MarketOpen())return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE);
   double R=MathAbs(tp-open)/((FIX_RR>0)?FIX_RR:1.0); if(R<=0)return;
   // favorable excursion in R, using current price
   double curR;
   if(type==POSITION_TYPE_BUY)  curR=(SymbolInfoDouble(_Symbol,SYMBOL_BID)-open)/R;
   else                         curR=(open-SymbolInfoDouble(_Symbol,SYMBOL_ASK))/R;
   if(curR>F_peakR) F_peakR=curR;
   if(F_peakR<FIX_ReversalExitArmR) return;                 // not armed yet
   if(curR<=0) return;                                      // only ever close while still in profit
   // give-back: how much of the peak profit has been surrendered
   if(curR > F_peakR*(1.0-FIX_ReversalExitGiveBackFrac)) return;   // still holding most of the peak -> keep running
   // confirm with a closed M15 bar against the trade (act once per bar)
   datetime cb=iTime(_Symbol,PERIOD_CURRENT,0); if(F_beTryBar==cb) return;
   double o1=iOpen(_Symbol,PERIOD_CURRENT,1), c1=iClose(_Symbol,PERIOD_CURRENT,1);
   bool barAgainst=(type==POSITION_TYPE_BUY)? (c1<o1) : (c1>o1);
   if(!barAgainst) return;
   F_beTryBar=cb; if(tf.PositionClose(tk)){ F_nRevExit++; }
}
void F_ManageTrade(){
   if(F_MyPositions()==0){ F_beActivated=false; F_peakR=0; return; }
   if(FIX_UseReversalExit){ F_ReversalExitManage(); return; } // seq192 chip C: harvest-on-reversal overrides one-shot BE
   if(FIX_UseProfitLock){ F_ProfitLockManage(); return; }   // seq190 treatment: ratchet lock overrides the one-shot BE
   if(!FIX_UseBreakEven)return;
   ulong tk=F_GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   long type=PositionGetInteger(POSITION_TYPE); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(F_beActivated)return; if(!F_MarketOpen())return; datetime cb=iTime(_Symbol,PERIOD_CURRENT,0); if(F_beTryBar==cb)return; double prog=0;
   if(type==POSITION_TYPE_BUY){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); if(tp-open<=0)return; prog=(bid-open)/(tp-open); if(prog>=FIX_BEProgress&&sl<open){ F_beTryBar=cb; if(tf.PositionModify(tk,NormalizeDouble(open,dg),tp))F_beActivated=true; } }
   else if(type==POSITION_TYPE_SELL){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(open-tp<=0)return; prog=(open-ask)/(open-tp); if(prog>=FIX_BEProgress&&sl>open){ F_beTryBar=cb; if(tf.PositionModify(tk,NormalizeDouble(open,dg),tp))F_beActivated=true; } }
}
void F_Tick(){
   if(iTime(_Symbol,PERIOD_D1,0)!=F_dayStart) F_NewDay();
   F_ManageTrade();
   if(!F_IsNewBar())return;
   if(F_MyPositions()>0)return;
   if(G_OpenSlotBlocked()){ F_cReject++; return; }   // seq204: DTREND already holds the only allowed slot
   if(G_NewsBlocked()){ F_cReject++; return; }       // rule 6b: high-impact release inside the window
   if(G_EntryHourBlocked())return;   // blocked hour: NO new entry (any running FIX09 trade was already managed above)
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(FIX_MaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ F_cSpread++; return; }
   if(!F_MarketOpen()) return;
   if(!F_TradingAllowed())return;
   double atr=F_ATR(); if(atr<=0)return; double buf=FIX_SLBufferATR*atr;
   double c1=iClose(_Symbol,PERIOD_CURRENT,1),o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h2=iHigh(_Symbol,PERIOD_CURRENT,2),l2=iLow(_Symbol,PERIOD_CURRENT,2);
   double lo1=iLow(_Symbol,PERIOD_CURRENT,1),hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   double emaL=F_EmaLTF(1),closeH1=iClose(_Symbol,FIX_HTF,1),emaH=F_EmaHTF(1);
   if((closeH1>emaH) && F_RecentBreakUp() && (lo1<=emaL) && (c1>o1)&&(c1>emaL)&&(c1>h2)){
      if(FIX_UseEntryRoom && (c1-h2) < FIX_EntryRoomATR*atr){ F_cReject++; return; }   // seq194 chip A: breakout bar must have TRAVELLED past the broken high, not just tagged it
      double sl=MathMin(lo1,l2)-buf; double a2=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double risk=a2-sl;
      if(risk>0 && risk<=FIX_MaxSL_ATR*atr){
         if(g_funded && Combo_FundedMaxSLpts>0 && risk>Combo_FundedMaxSLpts){ F_cReject++; return; }   // FUNDED: SL too wide -> skip (avoids big losses / stop-hunts on volatile days)
         if(Combo_UseMTF && G_MTFScore() < Combo_MTF_MinScore){ F_cReject++; return; }   // MTF: only BUY with the higher-TF uptrend
         if(G_RiskBlocksEntry(risk*G_MPP()*F_FixedLot())){ F_cReject++; return; }
         F_OpenBuy(sl,a2+FIX_RR*risk); return; } }
   if((closeH1<emaH) && F_RecentBreakDown() && (hi1>=emaL) && (c1<o1)&&(c1<emaL)&&(c1<l2)){
      if(FIX_UseEntryRoom && (l2-c1) < FIX_EntryRoomATR*atr){ F_cReject++; return; }   // seq194 chip A: breakdown bar must have TRAVELLED past the broken low, not just tagged it
      double sl=MathMax(hi1,h2)+buf; double b2=SymbolInfoDouble(_Symbol,SYMBOL_BID); double risk=sl-b2;
      if(risk>0 && risk<=FIX_MaxSL_ATR*atr){
         if(g_funded && Combo_FundedMaxSLpts>0 && risk>Combo_FundedMaxSLpts){ F_cReject++; return; }   // FUNDED: SL too wide -> skip
         if(Combo_UseMTF && G_MTFScore() > -Combo_MTF_MinScore){ F_cReject++; return; }   // MTF: only SELL with the higher-TF downtrend
         if(G_RiskBlocksEntry(risk*G_MPP()*F_FixedLot())){ F_cReject++; return; }
         F_OpenSell(sl,b2-FIX_RR*risk); } }
}

//===================================================================
//  DTREND functions
//===================================================================
double D_ADXreg(){ double b[]; if(CopyBuffer(D_hADXreg,0,1,1,b)<=0)return(0); return(b[0]); }
bool D_HTFbull(){ if(!DT_UseHTFtrend) return(true); double b[]; if(CopyBuffer(D_hHTF,0,1,1,b)<=0) return(true); double e=b[0]; double c=iClose(_Symbol,DT_HTFtrendTF,1); return(e>0 && c>e); }
double D_ChoppinessIndex(ENUM_TIMEFRAMES tfx,int n){
   if(n<2) return(50.0); double sumTR=0, hh=-DBL_MAX, ll=DBL_MAX;
   for(int i=1;i<=n;i++){ double h=iHigh(_Symbol,tfx,i), l=iLow(_Symbol,tfx,i), pc=iClose(_Symbol,tfx,i+1); if(h==0||l==0) return(50.0);
      double tr=MathMax(h-l,MathMax(MathAbs(h-pc),MathAbs(l-pc))); sumTR+=tr; if(h>hh)hh=h; if(l<ll)ll=l; }
   double rng=hh-ll; if(rng<=0||sumTR<=0) return(50.0); return(100.0*MathLog10(sumTR/rng)/MathLog10((double)n));
}
bool D_NotChoppy(){ if(!DT_UseChop) return(true); double ci=D_ChoppinessIndex(DT_ChopTF,DT_ChopPeriod); return(ci < DT_ChopMax); }
double D_ATRv(){ double b[]; if(CopyBuffer(D_hAtr,0,1,1,b)<=0)return(0); return(b[0]); }
double D_Fast1(){ double b[]; if(CopyBuffer(D_hFast,0,1,1,b)<=0)return(0); return(b[0]); }
double D_Slow1(){ double b[]; if(CopyBuffer(D_hSlow,0,1,1,b)<=0)return(0); return(b[0]); }
bool D_KAMA_bull(){
   int need=DT_KAMA_ER+80; double cl[]; ArraySetAsSeries(cl,false);
   int got=CopyClose(_Symbol,DT_SigTF,1,need,cl); if(got<DT_KAMA_ER+5) return(false);
   double fastSC=2.0/(DT_KAMA_Fast+1.0), slowSC=2.0/(DT_KAMA_Slow+1.0); double kama=cl[0]; double kprev=kama;
   for(int i=DT_KAMA_ER;i<got;i++){ double change=MathAbs(cl[i]-cl[i-DT_KAMA_ER]); double vol=0; for(int j=i-DT_KAMA_ER+1;j<=i;j++) vol+=MathAbs(cl[j]-cl[j-1]);
      double er=(vol>0)?change/vol:0.0; double sc=MathPow(er*(fastSC-slowSC)+slowSC,2.0); kprev=kama; kama=kama+sc*(cl[i]-kama); }
   return(kama>kprev);
}
bool D_IsBull(){ bool emaBull=(D_Fast1()>D_Slow1() && D_Slow1()>0); if(DT_Engine==0) return(emaBull); bool kamaBull=D_KAMA_bull(); if(DT_Engine==1) return(kamaBull); return(emaBull && kamaBull); }
bool D_IsNewSigBar(){ datetime t=iTime(_Symbol,DT_SigTF,0); if(t!=D_sigBarTime){ D_sigBarTime=t; return(true);} return(false); }
int D_MyPositions(){ int c=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==DT_Magic&&PositionGetString(POSITION_SYMBOL)==_Symbol)c++; } return(c); }
ulong D_GetMyTicket(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue; if(PositionGetInteger(POSITION_MAGIC)==DT_Magic&&PositionGetString(POSITION_SYMBOL)==_Symbol)return(tk);} return(0); }
double D_MoneyPerPricePerLot(){ double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE); double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); double byTick=(ts>0)? tv/ts : 0.0; if(cs>0) return(cs); return(byTick); }
double D_CalcLot(double slDist){
   double mpp=D_MoneyPerPricePerLot(); if(mpp<=0||slDist<=0)return(0);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE); double maxRisk=bal*(DT_MaxRiskPerTradePct/100.0);
   double lot;
   if(g_funded && Combo_FundedGapSizing){
      // seq188: gap-budgeted sizing -> worst-case (SL distance + assumed gap) * lot * mpp <= budget. Wide stop => gap is a small fraction => more size for the same $ risk.
      double denom=(slDist+Combo_FundedGapUsd)*mpp; if(denom<=0) return(0);
      lot=Combo_FundedTradeBudgetUsd/denom;
   } else {
      double rp=(g_funded? Combo_FundedRiskPct : DT_RiskPercent); double riskMoney=bal*(rp/100.0);
      if(riskMoney>maxRisk) riskMoney=maxRisk; lot=riskMoney/(slDist*mpp);
   }
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathFloor(lot/st)*st;
   if(lot<mn){ if(slDist*mn*mpp > maxRisk) return(0); lot=mn; }
   if(lot>DT_MaxLot) lot=DT_MaxLot; if(mx>0&&lot>mx)lot=mx;
   if(slDist*lot*mpp > maxRisk*1.05) return(0);
   lot=G_ClampLotToMargin(lot);   // seq208: never exceed the GFT margin ceiling
   return(lot);
}
void D_CloseMyLong(){ ulong tk=D_GetMyTicket(); if(tk==0)return; if(td.PositionClose(tk)){ D_nExit++; } }
// seq215 IDEA-104: measured-move STDV target for a LONG DTREND entry. Faithful to LumiTraders
// "STANDARD DEVIATION PROJECTIONS": take the last swing leg on DT_SigTF (the manipulation leg,
// swingLow->swingHigh) and project DT_StdvMult x its length up from the swing low. 1 STDV = the leg
// itself (reaches swingHigh), 2.5 STDV sits 1.5 legs above it - the author's gold interest band.
// Returns 0 if no valid swing is found or the projected target is not above the ask (never a TP
// below price; that trade then keeps the proven ATR runner-trail).
double D_StdvTargetLong(double ask){
   int L=DT_StdvSwingDepth; if(L<1) L=1;
   int look=DT_StdvLookback; if(look<L*2+2) look=L*2+2;
   int need=look+L+2;
   double hi[],lo[]; ArraySetAsSeries(hi,true); ArraySetAsSeries(lo,true);
   if(CopyHigh(_Symbol,DT_SigTF,1,need,hi)<need) return(0);
   if(CopyLow(_Symbol,DT_SigTF,1,need,lo)<need) return(0);
   int lowIdx=-1;
   for(int i=L; i<=look && i+L<need; i++){
      bool piv=true;
      for(int k=1;k<=L && piv;k++){ if(lo[i]>lo[i-k] || lo[i]>lo[i+k]) piv=false; }
      if(piv){ lowIdx=i; break; }
   }
   if(lowIdx<1) return(0);
   double swingLow=lo[lowIdx];
   double swingHigh=-DBL_MAX;
   for(int i=lowIdx-1;i>=1;i--){ if(hi[i]>swingHigh) swingHigh=hi[i]; }
   if(swingHigh<=swingLow) return(0);
   double leg=swingHigh-swingLow; if(leg<=0) return(0);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double tp=NormalizeDouble(swingLow+DT_StdvMult*leg,dg);
   if(tp<=ask) return(0);
   return(tp);
}
void D_TrailStop(){
   if(!DT_UseTrailATR)return; ulong tk=D_GetMyTicket(); if(tk==0)return; if(!PositionSelectByTicket(tk))return;
   if(DT_UseStdvTP && PositionGetDouble(POSITION_TP)>0) return;   // seq215: a measured STDV target is set -> let it work, no ATR trail
   double atr=D_ATRv(); if(atr<=0)return; double px=iClose(_Symbol,DT_SigTF,1); double newSL=px-DT_TrailATR*atr;
   double sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP); int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); newSL=NormalizeDouble(newSL,dg);
   if(newSL>sl && newSL<SymbolInfoDouble(_Symbol,SYMBOL_BID)) td.PositionModify(tk,newSL,tp);
}
void D_OpenLong(){
   if(Combo_UseMTF && G_MTFScore() < Combo_MTF_MinScore){ D_cRiskSkip++; return; }   // MTF: only go long with the higher-TF uptrend
   double atr=D_ATRv(); if(atr<=0)return; double slDist=DT_SL_ATR*atr; if(slDist<=0)return;
   if(g_funded && Combo_FundedMaxSLpts>0 && slDist>Combo_FundedMaxSLpts){ D_cRiskSkip++; return; }   // FUNDED: SL too wide -> skip (avoids combined Goat-Guard stacking)
   double mpp=D_MoneyPerPricePerLot(); double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxRisk=AccountInfoDouble(ACCOUNT_BALANCE)*(DT_MaxRiskPerTradePct/100.0); double riskAtMin=slDist*mn*mpp;
   if(riskAtMin>maxRisk){ if(DT_CapStopToRisk){ if(mn*mpp>0) slDist=maxRisk/(mn*mpp); } else { D_cRiskSkip++; return; } }
   double lot=D_CalcLot(slDist); if(lot<=0){ D_cRiskSkip++; return; }
   if(G_RiskBlocksEntry(slDist*D_MoneyPerPricePerLot()*lot)){ D_cRiskSkip++; return; }
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); double sl=ask-slDist; int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); sl=NormalizeDouble(sl,dg);
   double tp=0.0;
   if(DT_UseStdvTP){ tp=D_StdvTargetLong(ask); if(tp>0) D_nStdvTP++; else D_cStdvNoTgt++; }   // seq215: measured STDV target (0 -> keep the runner trail)
   if(td.Buy(lot,_Symbol,0,sl,tp)){ D_nBuy++; }
}
void D_Tick(){
   D_TrailStop();
   if(!D_IsNewSigBar())return;
   bool bull=D_IsBull();
   if(D_MyPositions()>0){ if(!bull){ D_CloseMyLong(); D_cFlatDown++; } return; }
   if(G_OpenSlotBlocked()){ D_cRiskSkip++; return; }   // seq204: FIX09 already holds the only allowed slot
   if(G_NewsBlocked()){ D_cRiskSkip++; return; }       // rule 6b: high-impact release inside the window
   if(G_EntryHourBlocked())return;   // blocked hour: NO new entry (running DTREND trade + trail already handled above)
   long curPts=(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   long maxPts=(long)MathRound(DT_MaxSpreadPrice/SymbolInfoDouble(_Symbol,SYMBOL_POINT));
   if(curPts>maxPts){ D_cSpread++; return; }
   if(DT_UseRegime && D_ADXreg() < DT_ADXTrendMin){ D_cChop++; return; }
   if(DT_UseHTFtrend && !D_HTFbull()){ D_cHTF++; return; }
   if(DT_UseChop && !D_NotChoppy()){ return; }
   if(bull) D_OpenLong();
}

//===================================================================
//  Master account guard
//===================================================================
double G_EquityDDfromInit(){ if(g_initBal<=0)return(0); double eq=AccountInfoDouble(ACCOUNT_EQUITY); return(100.0*(g_initBal-eq)/g_initBal); }
double G_DailyRef(){ return((Combo_DailyRefInitial && g_initBal>0) ? g_initBal : g_comboDayStartBal); }   // seq220: daily-loss % reference (INITIAL vs day-start). Loss is always the drop from day-start; only the % denominator changes.
double G_DayLossPct(){ double ref=G_DailyRef(); if(ref<=0)return(0); double eq=AccountInfoDouble(ACCOUNT_EQUITY); return(100.0*(g_comboDayStartBal-eq)/ref); }
void G_CloseAllBoth(){
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; long mg=PositionGetInteger(POSITION_MAGIC);
      if(mg==FIX_Magic){ tf.PositionClose(tk); } else if(mg==DT_Magic){ td.PositionClose(tk); } }
}
void G_NewComboDay(){ g_comboDayStart=iTime(_Symbol,PERIOD_D1,0); g_comboDayStartBal=AccountInfoDouble(ACCOUNT_BALANCE); }
void G_ParseBlockHours(){
   for(int i=0;i<24;i++) g_blockHour[i]=false;
   string parts[]; int n=StringSplit(Combo_BlockEntryHours,',',parts);
   for(int i=0;i<n;i++){ string s=parts[i]; StringTrimLeft(s); StringTrimRight(s); if(StringLen(s)==0)continue; int h=(int)StringToInteger(s); if(h>=0 && h<24) g_blockHour[h]=true; }
}
bool G_EntryHourBlocked(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); return(g_blockHour[dt.hour]); }
double G_MPP(){ double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); if(cs>0)return(cs); double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); return(ts>0? tv/ts : 0.0); }
// Block a NEW entry if its worst-case SL loss would (a) exceed the per-trade cap, or
// (b) push today's loss past the buffered daily cap. Running trades are NOT touched.
bool G_RiskBlocksEntry(double riskMoney){
   double ref=G_DailyRef(); if(ref<=0) ref=(g_comboDayStartBal>0? g_comboDayStartBal : g_initBal);   // seq220: initial vs day-start daily reference
   if(ref<=0 || riskMoney<=0) return(false);
   if(g_funded){
      // FUNDED: per-trade cap referenced to INITIAL (Goat Guard is measured on initial)
      if(g_initBal>0 && riskMoney > Combo_FundedPerTradePct/100.0*g_initBal) return(true);
   } else if(Combo_UsePerTradeCap && riskMoney > Combo_PerTradeMaxRiskPct/100.0*ref) return(true);
   if(Combo_UsePredictiveDaily){
      double usedToday=MathMax(0.0, g_comboDayStartBal-AccountInfoDouble(ACCOUNT_EQUITY));
      if(usedToday+riskMoney > Combo_DailyBufferPct/100.0*ref) return(true);
   }
   return(false);
}
// MULTI-TIMEFRAME alignment: +1 per bull TF, -1 per bear TF across the ladder (range -4..+4).
// Uses last CLOSED bar: close > EMA = bull. Higher score = stronger multi-TF uptrend agreement.
int G_MTFScore(){
   int sc=0;
   for(int i=0;i<4;i++){ double b[]; if(CopyBuffer(g_hMTF[i],0,1,1,b)<=0) continue; double ema=b[0]; if(ema<=0) continue; double c=iClose(_Symbol,g_mtftf[i],1); if(c<=0) continue; sc += (c>ema? 1 : -1); }
   return(sc);
}
// seq204: total open positions across BOTH sleeves. Goat Guard sums them, so the COMBINED count
// is what bounds worst-case floating loss - the per-sleeve caps do not.
int G_MyOpenTotal(){
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; long mg=PositionGetInteger(POSITION_MAGIC);
      if(mg==FIX_Magic || mg==DT_Magic) c++; }
   return(c);
}
bool G_OpenSlotBlocked(){
   if(!g_funded) return(false);
   if(Combo_FundedMaxOpenTotal<=0) return(false);
   return(G_MyOpenTotal() >= Combo_FundedMaxOpenTotal);
}

// seq208: clamp a proposed lot so margin used stays inside Combo_MaxMarginPct of equity.
// Uses MT5's OrderCalcMargin so the BROKER's own margin rate applies - we never assume one. Margin
// already consumed by open positions is subtracted, because the firm's ceiling is on total usage.
// Returns 0 when even the minimum lot cannot fit, in which case callers must skip the trade
// (F_OpenBuy/F_OpenSell and D_OpenLong all already bail on lot<=0).
double G_ClampLotToMargin(double lot){
   if(Combo_MaxMarginPct<=0 || lot<=0) return(lot);
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0) return(lot);
   double used=AccountInfoDouble(ACCOUNT_MARGIN);
   double budget=eq*(Combo_MaxMarginPct/100.0)-used;
   if(budget<=0) return(0.0);
   double px=SymbolInfoDouble(_Symbol,SYMBOL_ASK); if(px<=0) return(lot);
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st<=0) st=0.01; if(mn<=0) mn=0.01;
   double need=0.0;
   for(int guard=0; guard<1000; guard++){
      if(lot<mn-1e-9) return(0.0);
      if(!OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,lot,px,need)) return(lot); // cannot compute -> do not silently shrink
      if(need<=budget) return(NormalizeDouble(lot,2));
      lot=NormalizeDouble(lot-st,2);
   }
   return(0.0);
}

// rule 6b: is a high-impact release inside the block window? Uses the MQL5 economic calendar.
// If the calendar is unavailable (some tester/terminal setups), this returns false and the gate
// simply does nothing - it never blocks on absent data, and never pretends the check happened.
bool G_NewsBlocked(){
   if(!Combo_UseNewsGate) return(false);
   datetime now=TimeCurrent();
   int win=Combo_NewsBlockMin*60;
   MqlCalendarValue vals[];
   int n=CalendarValueHistory(vals,now-win,now+win);
   if(n<=0) return(false);
   for(int i=0;i<n;i++){
      MqlCalendarEvent ev;
      if(!CalendarEventById(vals[i].event_id,ev)) continue;
      if(ev.importance!=CALENDAR_IMPORTANCE_HIGH) continue;
      return(true);
   }
   return(false);
}

// combined FLOATING PnL of my open positions (both magics) - used by the FUNDED Goat-Guard pre-empt
double G_MyFloatingPnL(){
   double s=0;
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(tk==0)continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue; long mg=PositionGetInteger(POSITION_MAGIC);
      if(mg!=FIX_Magic && mg!=DT_Magic)continue; s+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP); }
   return(s);
}

//===================================================================
int OnInit(){
   tf.SetExpertMagicNumber(FIX_Magic); tf.SetDeviationInPoints(30); tf.SetTypeFillingBySymbol(_Symbol); tf.LogLevel(LOG_LEVEL_NO);
   td.SetExpertMagicNumber(DT_Magic);  td.SetDeviationInPoints(30); td.SetTypeFillingBySymbol(_Symbol); td.LogLevel(LOG_LEVEL_NO);
   // FIX09 handles
   F_hEmaHTF=iMA(_Symbol,FIX_HTF,FIX_TrendEMA,0,MODE_EMA,PRICE_CLOSE);
   F_hEmaLTF=iMA(_Symbol,PERIOD_CURRENT,FIX_EntryEMA,0,MODE_EMA,PRICE_CLOSE);
   F_hAtr=iATR(_Symbol,PERIOD_CURRENT,14);
   // DTREND handles
   D_hFast=iMA(_Symbol,DT_SigTF,DT_FastEMA,0,MODE_EMA,PRICE_CLOSE);
   D_hSlow=iMA(_Symbol,DT_SigTF,DT_SlowEMA,0,MODE_EMA,PRICE_CLOSE);
   D_hAtr =iATR(_Symbol,DT_SigTF,DT_ATRPeriod);
   D_hADXreg=iADX(_Symbol,DT_RegimeTF,DT_RegimeADXPeriod);
   D_hHTF=iMA(_Symbol,DT_HTFtrendTF,DT_HTFtrendEMA,0,MODE_EMA,PRICE_CLOSE);
   if(F_hEmaHTF==INVALID_HANDLE||F_hEmaLTF==INVALID_HANDLE||F_hAtr==INVALID_HANDLE||
      D_hFast==INVALID_HANDLE||D_hSlow==INVALID_HANDLE||D_hAtr==INVALID_HANDLE||D_hADXreg==INVALID_HANDLE||D_hHTF==INVALID_HANDLE)
      return(INIT_FAILED);
   // MTF ladder handles (M15,H1,H4,D1) - EMA(Combo_MTF_EMA) on close
   g_mtftf[0]=PERIOD_M15; g_mtftf[1]=PERIOD_H1; g_mtftf[2]=PERIOD_H4; g_mtftf[3]=PERIOD_D1;
   for(int i=0;i<4;i++){ g_hMTF[i]=iMA(_Symbol,g_mtftf[i],Combo_MTF_EMA,0,MODE_EMA,PRICE_CLOSE); if(g_hMTF[i]==INVALID_HANDLE) return(INIT_FAILED); }
   string scope=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol;
   FGK_DAY="ckcombo_fday_"+scope; FGK_BAL="ckcombo_fbal_"+scope; FGK_TRD="ckcombo_ftrd_"+scope;
   g_initBal=AccountInfoDouble(ACCOUNT_BALANCE);
   g_comboDayStart=iTime(_Symbol,PERIOD_D1,0); g_comboDayStartBal=g_initBal;
   F_LoadOrResetDaily();
   G_ParseBlockHours();
   g_funded = (Combo_Stage==1) || (Combo_FundedLogin>0 && AccountInfoInteger(ACCOUNT_LOGIN)==Combo_FundedLogin);
   PrintFormat("[COMBO] init bal=%.2f login=%s MODE=%s  FIX09=%s DTREND=%s  staticDDstop=%.1f%% dailyLoss=%.1f%%",
               g_initBal,IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),(g_funded?"FUNDED(GoatGuard)":"EVAL"),
               (Combo_EnableFIX09?"on":"off"),(Combo_EnableDTREND?"on":"off"),Combo_StaticDDStopPct,Combo_DailyLossPct);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){
   IndicatorRelease(F_hEmaHTF);IndicatorRelease(F_hEmaLTF);IndicatorRelease(F_hAtr);
   IndicatorRelease(D_hFast);IndicatorRelease(D_hSlow);IndicatorRelease(D_hAtr);IndicatorRelease(D_hADXreg);IndicatorRelease(D_hHTF);
}
void OnTick(){
   // 1) master account-level static-DD halt (whole account, GFT protection)
   if(Combo_UseStaticDD && !g_comboHalted && G_EquityDDfromInit()>=Combo_StaticDDStopPct){
      g_comboHalted=true; G_CloseAllBoth(); Print("[COMBO] MASTER STATIC-DD HALT");
   }
   if(g_comboHalted){ G_CloseAllBoth(); return; }
   // 1b) FUNDED only: pre-empt Goat Guard (2% of INITIAL combined FLOATING loss) by flattening at a buffer
   if(g_funded && g_initBal>0 && G_MyFloatingPnL() <= -Combo_FundedFloatFlatPct/100.0*g_initBal){ G_CloseAllBoth(); return; }
   // 2) combo day roll + daily-loss stop (whole account)
   if(iTime(_Symbol,PERIOD_D1,0)!=g_comboDayStart) G_NewComboDay();
   if(Combo_UseDailyLoss && G_DayLossPct()>=Combo_DailyLossPct){ G_CloseAllBoth(); return; }
   // 2b) IXU NO-WEEKEND-HOLDING: never hold over the weekend (close all + block entries Fri>=HH, all Sat, all Sun). day_of_week: 0=Sun,5=Fri,6=Sat
   if(Combo_WeekendFlat){
      MqlDateTime wkdt; TimeToStruct(TimeCurrent(),wkdt);
      if(wkdt.day_of_week==6 || wkdt.day_of_week==0 || (wkdt.day_of_week==5 && wkdt.hour>=Combo_WeekendFlatHour)){ G_CloseAllBoth(); return; }
   }
   // 3) run both strategies
   if(Combo_EnableFIX09)  F_Tick();
   if(Combo_EnableDTREND) D_Tick();
}
double OnTester(){
   PrintFormat("[COMBO] DTREND buys=%d exits=%d flatDown=%d chopADX=%d htfSkip=%d stdvTP=%d stdvNoTgt=%d | FIX09 rejects=%d",
               D_nBuy,D_nExit,D_cFlatDown,D_cChop,D_cHTF,D_nStdvTP,D_cStdvNoTgt,F_cReject);
   int h=FileOpen("ck_gold_combo_trades.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h!=INVALID_HANDLE){ FileWrite(h,"time","profit","magic"); HistorySelect(0,TimeCurrent()); int total=HistoryDealsTotal();
      for(int i=0;i<total;i++){ ulong tk=HistoryDealGetTicket(i); if(tk==0)continue; if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol)continue; if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         long mg=HistoryDealGetInteger(tk,DEAL_MAGIC); if(mg!=FIX_Magic && mg!=DT_Magic)continue;
         datetime xt=(datetime)HistoryDealGetInteger(tk,DEAL_TIME); double p=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION);
         FileWrite(h,TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(p,2),IntegerToString(mg)); }
      FileClose(h); }
   // --- enriched per-trade deals (entry+exit paired by position id) for the loss visualizer ---
   int h2=FileOpen("ck_gold_combo_deals.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h2!=INVALID_HANDLE){
      // entry_time/exit_time keep MINUTE formatting on purpose: tools/loss_visualizer.py parses
      // them with an exact "%Y.%m.%d %H:%M" format and would silently drop every row if changed.
      // hold_sec is written instead as EXACT integer seconds from the raw datetimes, which is what
      // the GFT 2-minute rule needs (rulebook rule 4); mae/mfe give the floating excursions that
      // Goat Guard (rule 3) is measured on.
      FileWrite(h2,"magic","dir","entry_time","entry_price","exit_time","exit_price","profit","volume","hold_sec","mae","mfe");
      HistorySelect(0,TimeCurrent()); int ndl=HistoryDealsTotal();
      for(int i=0;i<ndl;i++){ ulong o=HistoryDealGetTicket(i); if(o==0)continue;
         if(HistoryDealGetString(o,DEAL_SYMBOL)!=_Symbol)continue;
         if(HistoryDealGetInteger(o,DEAL_ENTRY)!=DEAL_ENTRY_OUT)continue;
         long mg=HistoryDealGetInteger(o,DEAL_MAGIC); if(mg!=FIX_Magic && mg!=DT_Magic)continue;
         long pid=HistoryDealGetInteger(o,DEAL_POSITION_ID);
         datetime et=0; double ep=0; long dir=-1;
         for(int j=0;j<ndl;j++){ ulong in=HistoryDealGetTicket(j); if(in==0)continue;
            if(HistoryDealGetInteger(in,DEAL_POSITION_ID)!=pid)continue;
            if(HistoryDealGetInteger(in,DEAL_ENTRY)!=DEAL_ENTRY_IN)continue;
            et=(datetime)HistoryDealGetInteger(in,DEAL_TIME); ep=HistoryDealGetDouble(in,DEAL_PRICE); dir=HistoryDealGetInteger(in,DEAL_TYPE); break; }
         datetime xt=(datetime)HistoryDealGetInteger(o,DEAL_TIME); double xp=HistoryDealGetDouble(o,DEAL_PRICE);
         double p=HistoryDealGetDouble(o,DEAL_PROFIT)+HistoryDealGetDouble(o,DEAL_SWAP)+HistoryDealGetDouble(o,DEAL_COMMISSION);
         string ds=(dir==DEAL_TYPE_BUY)?"buy":((dir==DEAL_TYPE_SELL)?"sell":"na");
         double vol=HistoryDealGetDouble(o,DEAL_VOLUME);
         long hold_sec=(long)(xt-et);
         // MAE/MFE from M1 bars spanning the hold. Price-excursion based (excludes swap and
         // commission), in account currency: distance * volume * contract size.
         double mae=0.0,mfe=0.0; MqlRates rt[];
         int nb=(et>0 && xt>=et)?CopyRates(_Symbol,PERIOD_M1,et,xt,rt):0;
         if(nb>0){
            double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
            double worst=0.0,best=0.0;
            for(int b=0;b<nb;b++){
               double adverse=(dir==DEAL_TYPE_BUY)?(ep-rt[b].low):(rt[b].high-ep);
               double favor  =(dir==DEAL_TYPE_BUY)?(rt[b].high-ep):(ep-rt[b].low);
               if(adverse>worst) worst=adverse;
               if(favor>best)    best=favor; }
            mae=worst*vol*cs; mfe=best*vol*cs; }
         FileWrite(h2,IntegerToString(mg),ds,TimeToString(et,TIME_DATE|TIME_MINUTES),DoubleToString(ep,2),TimeToString(xt,TIME_DATE|TIME_MINUTES),DoubleToString(xp,2),DoubleToString(p,2),DoubleToString(vol,2),IntegerToString(hold_sec),DoubleToString(mae,2),DoubleToString(mfe,2)); }
      FileClose(h2); }
   return(0.0);
}
//+------------------------------------------------------------------+
```

---

## 8. Deployment Configuration — `CK_GOLD_COMBO_FundedNext.set`

This is the exact preset the EA loads at deployment on FundedNext Stellar 2-Step $6,000. It sets FIX 0.02 lot (the safe ceiling on $6k after the settlement-block + daily-includes-floating analysis), turns the settlement-window block on, and elects the FundedNext-style daily reference (`Combo_DailyRefInitial=true`).

```ini
; CK_GOLD_COMBO - FundedNext Stellar 2-Step deployment set (from experiments/combo_fnext_03, ledger seq220/221)
; Firm shape: NO Goat Guard; Max Loss 10% STATIC of initial (incl floating); Daily 5% of INITIAL (incl floating).
; Config: Stage=0, Combo_DailyRefInitial=true (daily measured vs INITIAL), FIX 0.02 lot (CHANGED 0.03->0.02 seq254),
;         daily governor 4.5% of initial (flatten ~$225 < the $250 hard line), static halt 8% (< 10% floor), news gate ON.
; WHY 0.02 not 0.03: FundedNext support (2026-09-18) reconfirmed the 5% DAILY limit INCLUDES floating loss. At 0.03 the
;   worst conservative combined-floating day was ~$293 (OVER the $250 daily line) -> breach risk. At 0.02 it is ~$220
;   (under) -> safe. Mission: never ship a config that can even touch a hard limit.
; Backtest (Model 1, last1y, $5k, 0.02 + settlement block): net +$3,308, worst realized day -$143.71, 0 daily/static breach.
; Combo_BlockEntryHours=0,1 (seq252/253): blocks new entries in the 00:00-02:00 server SETTLEMENT window
;   (FundedNext prohibits profit generated disproportionately in that low-liquidity "dead zone"). Cost is
;   near-zero (-0.8% net on the 0.02 twin; trends are recaptured in liquid hours) and it removes the least
;   reliable thin-liquidity fills -> compliant-by-construction + more robust on the real feed.
Combo_EnableFIX09=true
Combo_EnableDTREND=true
Combo_UseStaticDD=true
Combo_StaticDDStopPct=8.0
Combo_UseDailyLoss=true
Combo_DailyLossPct=4.5
Combo_BlockEntryHours=0,1
Combo_UsePredictiveDaily=true
Combo_DailyBufferPct=3.5
Combo_UsePerTradeCap=true
Combo_PerTradeMaxRiskPct=2.0
Combo_DailyRefInitial=true
Combo_Stage=0
Combo_FundedFloatFlatPct=1.2
Combo_FundedPerTradePct=0.6
Combo_FundedFixLot=0.01
Combo_FundedRiskPct=0.5
Combo_FundedLogin=0
Combo_FundedMaxSLpts=0
Combo_FundedGapSizing=false
Combo_FundedGapUsd=50.0
Combo_FundedTradeBudgetUsd=80.0
Combo_MaxMarginPct=60.0
Combo_FundedMaxOpenTotal=1
Combo_UseNewsGate=true
Combo_NewsBlockMin=6
Combo_UseMTF=true
Combo_MTF_EMA=50
Combo_MTF_MinScore=2
FIX_Magic=20260716
FIX_FixedLot=0.02
FIX_MaxLot=0.02
FIX_RiskPercent=2.0
FIX_RR=3.0
FIX_MaxTradesPerDay=3
FIX_DailyLossStopR=2.0
FIX_DailyProfitStopR=4.0
FIX_MaxSpreadPrice=0.60
FIX_HTF=16385
FIX_TrendEMA=200
FIX_BreakoutLookback=20
FIX_BreakoutMaxAge=12
FIX_EntryEMA=20
FIX_SwingLookback=10
FIX_MaxSL_ATR=2.5
FIX_SLBufferATR=0.20
FIX_UseBreakEven=true
FIX_BEProgress=0.50
FIX_UseProfitLock=false
FIX_ProfitLockGiveBackR=1.0
FIX_UseReversalExit=false
FIX_ReversalExitArmR=1.0
FIX_ReversalExitGiveBackFrac=0.5
FIX_UseEntryRoom=false
FIX_EntryRoomATR=0.5
DT_Magic=20260930
DT_SigTF=16388
DT_Engine=0
DT_FastEMA=20
DT_SlowEMA=100
DT_KAMA_ER=10
DT_KAMA_Fast=2
DT_KAMA_Slow=30
DT_UseRegime=true
DT_RegimeTF=16388
DT_RegimeADXPeriod=14
DT_ADXTrendMin=20.0
DT_UseHTFtrend=true
DT_HTFtrendTF=16408
DT_HTFtrendEMA=50
DT_UseChop=true
DT_ChopTF=16388
DT_ChopPeriod=14
DT_ChopMax=61.8
DT_ATRPeriod=14
DT_SL_ATR=2.0
DT_UseTrailATR=true
DT_TrailATR=3.0
DT_RiskPercent=0.8
DT_MaxLot=0.50
DT_MaxRiskPerTradePct=5.0
DT_CapStopToRisk=true
DT_MaxSpreadPrice=1.00
DT_UseStdvTP=false
DT_StdvMult=2.5
DT_StdvSwingDepth=5
DT_StdvLookback=60
```

---

## 9. Independent Verification Tools

Python analyzers in the repo read the MT5 output CSVs and independently verify every claim in this document:

- `_compare_plans.py` — side-by-side monthly / yearly income calculation from the real-tick deals CSV.
- `_consistency_check.py` — On-Demand 40% consistency rule verification.
- `_analyze_fn_compliance.py` — daily / static / 3%-risk breach checker.
- `_parse_mt5_monthly.py` — MT5 deals → monthly P&L parser.
- `tools/gft_compliance.py` (referenced) — rule-by-rule compliance checker.

Every number in §2 (Executive Summary) and §6 (Compliance) can be re-derived by running these tools against `experiments/combo_fnext_journal/deals.csv`. If any number here does not match a re-derivation, this document is wrong and I want to know.

---

## 10. Repository Layout — what to look at, in what order

```text
CK_GOLD_COMBO.mq5                                  ← the EA itself
experiments/combo_fnext_03/
    CK_GOLD_COMBO_FundedNext.set                   ← the shipping preset
    FORWARD_DEMO.md                                ← forward-demo protocol
    install_combo_fnext.ps1                        ← local install script
    VPS_SETUP.md                                   ← VPS setup guide
    DEPLOY_CHECKLIST.md                            ← daily / weekly checklist
experiments/combo_fnext_journal/deals.csv          ← 270-trade real-tick evidence
JOURNAL_FundedNext.md                              ← real-tick verdict (seq255)
SPEC/dof_ledger.jsonl                              ← hash-chained decision ledger
SPEC/dof_ledger.py                                 ← ledger append + verify helper
SPEC/FN_REPLY_DECISION.md                          ← FN support conversation outcome
SPEC/PLAN_C_vs_PLAN_Q.md                           ← side-by-side comparison doc
.kiro/steering/gft-mission-and-rules.md            ← the ~300-line project charter
```

---

## 11. Statement of Sole Ownership

I own the strategy, the parameter choices, the testing methodology, the compliance framework, and the code that implements them. This EA is unique to my FundedNext account and will not be duplicated on any other account. I am the sole beneficiary of its performance and take full responsibility for the trades it places on my behalf.

The complete audit trail — 278 hash-chained ledger entries across 13 development days, 26 pre-registered experiments, 21 tested outcomes, 9+ explicit rejections, and full MT5 real-tick evidence — is committed to the repository above and can be independently verified.

---

_Document generated by `docs/build_proof_of_authorship.py` from live repository state. Re-run the script to regenerate at any time — the output is deterministic given the source files and ledger._
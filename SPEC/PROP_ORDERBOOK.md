# PROP FIRM ORDER BOOK

Registry of prop firms vs the exact rules that decide whether our XAUUSD combo EA can run there
profitably and safely. We fill each cell only from a PRIMARY source (the firm's own support reply or
its own help-centre / terms page) - never a third-party guess. As the user gets written support
replies, paste them back and the matching row is updated here.

## The 6 things we must know for every firm (why each matters to us)

1. **EA allowed in the FUNDED stage (not just the challenge)?** - our whole plan is an automated EA.
   Some firms allow EAs in the challenge but BAN them once funded (e.g. Sure Leverage), which would
   kill the plan. This is the #1 question.
2. **Max drawdown: STATIC or TRAILING, and what %?** - our config is built for a STATIC floor
   (fixed from the start balance). A trailing floor needs a different config + re-test.
3. **Daily drawdown: what %, and measured on intraday EQUITY (incl. floating P&L) or end-of-day
   BALANCE? When does it reset (server time)?** - our worst single-trade float was ~-4.3% of a $5k
   account; on an intraday-equity 5% rule that is thin, on an EOD-balance rule it is safe.
4. **Any separate floating-loss / open-position kill (like GFT's "Goat Guard")?** - this exact rule
   is what blocked our high-income 0.04-lot config on GFT. A firm without it unlocks that income.
5. **XAUUSD (gold) allowed? news / weekend-hold / minimum-hold restrictions?**
6. **Profit split, payout cycle, and proof of recent payouts?** - a new firm not paying out makes a
   winning strategy worthless.

## Status table (PENDING = awaiting the firm's written reply)

| Firm | EA in FUNDED | Max DD static/trailing + % | Daily DD % + basis | Floating-loss guard? | Gold OK | Split / payout | Payout proof | Overall |
|---|---|---|---|---|---|---|---|---|
| **Goat Funded Trader** | yes (no HFT/arb) | STATIC 10% | 5% (higher of bal/eq @5pm EST) | **YES - Goat Guard 2% of initial ($100)** | yes | 80% / bi-weekly | established | VERIFIED (our current target) |
| **IXU Capital** | PENDING | STATIC (their site) - % PENDING | PENDING | PENDING | PENDING | 80% / ~5h | **PENDING (site shows 0 live payouts)** | PENDING - new firm |
| **Legion Funding** | PENDING | PENDING | PENDING | PENDING | PENDING | 80% / PENDING | **PENDING (incorporated Aug 2026)** | PENDING - very new |
| **E8 Markets (E8 PRO)** | EA yes; confirm funded | **8% STATIC** (Pro; never trails); Signature=14% TRAILING (AVOID), One=day-start | Pro: confirm daily%; One 3% day-start; Signature 2% soft-pause | none-known on Pro (Signature has 2% soft daily PAUSE, not a kill) | PENDING | Pro: unrestricted news | ~$32, fee 100% refund 1st payout | established | Use **E8 PRO** (8% static, NO consistency, news OK). NOT Signature (trailing). My earlier "14% static" was WRONG - 14% is Signature TRAILING |
| **FundingPips (2-Step Standard)** | allowed but PERSONAL EA + source-code proof required; confirm funded | **STATIC 10% max loss** (never moves; models 6-12%) | 5% daily, real-time-equity (incl floating); confirm initial vs day-start | PENDING (none known; not the Zero model which is 5% trailing) | weekend OK in eval | PENDING | established (~$64M paid 2026) | CHEAP (~$29 entry), no time limit, 8%/5% targets - STRONG cheap fit, confirm EA-funded + guard + daily ref |
| **FTMO (2-Step)** | YES - any legitimate strategy incl. EA/algo, funded too (see Forbidden Practices) | fixed OR EOD-trailing depending on product - CONFIRM the product is FIXED | 5% max daily, INCLUDES floating (equity) | **NONE** - only Max Loss + Max Daily Loss; "no other scenarios we interfere" | YES, NO minimum hold time | 80% 2-Step (->90% scaling), 90% 1-Step; reward every 14 days | established | STRONG FIT - no Goat-Guard rule; daily 5%-incl-floating is the binding limit |
| **FundedNext (Stellar 2-Step)** | **YES** MT4/MT5 (small EA usage fee by account size) - CONFIRMED | **STATIC 10% of initial** (1-Step 6%, Lite 8%); breach on balance OR equity | **5% of INITIAL (CONFIRMED)**, incl closed+floating+swap+commission | **NONE** (only MLL + daily loss) | **YES** - news profit @40% in funded (loss full), weekend OK, no min-hold | PENDING | established | **CONFIG VALIDATED**: combo_fnext_03 (0.03 + Combo_DailyRefInitial) = +75.3%/yr, ~$253/mo @80%, worst day -4.31%, 0 breaches (ledger seq221). Only split/payout left |

## Support channels (verified where found)

- **IXU Capital** - website https://ixucapital.app (live chat / Discord on site). No separate support URL verified.
- **Legion Funding** - website https://legionfunding.com . No separate verified support URL (note: "legion.co"/"legion.cc"/"legionfunding.net" are DIFFERENT companies - do not use).
- **E8 Markets** - help centre https://help.e8markets.com + live chat on site.
- **FundedNext** - https://fundednext.com/contact + help https://help.fundednext.com + Telegram @askfundednextbot.
- **FTMO** - https://ftmo.com/en/contact/ (24/7 support).
- **The5ers** - https://the5ers.com (support / live chat on site).
- **FundingPips** - https://fundingpips.com (live chat + help center on site).

## Canonical CLEAN support message (firm-neutral - NEVER name "Goat Guard" or any brand to another firm)
Describe the floating-loss rule by what it DOES, not by GFT's brand name. Paste this to any firm,
just change the greeting:

```
Hello, before I purchase I would like to confirm a few rules for your $5,000 / $10,000 accounts:
1. Are automated Expert Advisors (EAs) allowed on BOTH the challenge and the funded account? My EA is
   custom-coded with a hard stop-loss on every trade (no martingale, grid, HFT or arbitrage).
2. Is the maximum loss limit static (fixed from the starting balance) or trailing? What is the exact %?
3. What is the daily loss limit %? Is it measured from the INITIAL balance or from the START-OF-DAY
   balance, does it include open (floating) positions, and what time does it reset (server time)?
4. Besides the maximum loss and daily loss limits, is there any other rule that can close the account
   or reduce the profit split based on the floating (unrealized) loss of open trades? If yes, what is
   the exact threshold?
5. Is XAUUSD (gold) allowed? Any restriction on trading news, holding over the weekend, or a minimum
   hold time per trade?
6. What is the profit split, how often are payouts, and can you share proof of recent payouts?
Thank you.
```
NOTE: question 4 is the generic way to ask about a floating-loss liquidation rule WITHOUT naming any
firm's brand. Question 3 (initial vs start-of-day) is the one that decides 0.04 vs 0.03 lot for us.

## HIDDEN / EXTRA-RULE HUNT CHECKLIST (rules-first: one unknown rule = breach = zero payout)
A firm is NOT cleared for real money until EVERY item below is answered from its OWN docs/support. These are the
account-killing or payout-killing rules that comparison tables usually hide. Real examples we already found prove they
exist: GFT Goat Guard (2% floating), FundingPips Striking System (1.2% floating, >=$25k) + Profit Concentration + 30-day
inactivity + Master weekend ban + news-window profit deduction + "trade idea" grouping, FundedNext daily=INITIAL + news
40% haircut + STRATEGY-CONSISTENCY rule (must use the SAME method to pass the Challenge AND on the Funded acct; using an EA
to pass then switching to manual - or vice versa - is NOT allowed -> account review / suspension / Performance-Reward denial;
help.fundednext.com/en/articles/8388896, Apr 2026), Sure Leverage EA-banned-when-funded + 1% floating rule.

Hunt for each (per firm, per stage challenge vs funded):
1. Floating-loss / equity guard: any rule that closes the account OR cuts the split on UNREALISED loss (Goat Guard /
   Striking / etc.), incl. size thresholds (e.g. only >=$25k).
2. Drawdown type: STATIC or TRAILING (and does scaling later switch it to trailing, e.g. FundingPips Prime = trailing 8%).
3. Daily loss: %, reference (INITIAL vs day-start), floating included?, reset time.
4. Max loss: %, floating included?, breach-on-touch?
5. Consistency rule / best-day cap (% of profit in one day) - blocks/delays payout.
6. Profit concentration / single-"trade-idea" cap - one big trade voids or conditions payout.
7. "Trade idea" grouping - correlated positions or re-entries within X min counted as one.
8. Minimum trading days (per phase AND per payout).
9. Minimum hold time (sub-X-sec/min trade profit stripped, e.g. GFT funded 2-min).
10. Maximum time limit / inactivity breach (e.g. 30 days no closed trade).
11. News-trading rule (window around high-impact news; profit deduction or breach), incl. funded stage.
12. Weekend / overnight holding (auto-close or breach), incl. funded stage.
13. Max lot / max total position / max open positions / max risk per trade idea.
14. Max daily PROFIT cap (excess removed).
15. Mandatory stop-loss?
16. Banned strategies (martingale, grid, HFT/tick-scalp, latency/hedge arbitrage) - definitions + thresholds.
17. Copy-trading / same-EA-as-many-traders / multi-account same-strategy rules.
18. EA: allowed in FUNDED?, pre-approval?, source-code proof?, EA usage fee?
19. Discretionary "not genuine trading" / gambling / one-sided-bet clause that lets them void profits.
20. Leverage/margin on XAUUSD; and any symbol group restriction.
21. Payout: split %, cycle, min days/conditions for FIRST payout, payout CAPS on first N payouts, fee refund.
22. Payout reliability: proof of recent payouts + processing time + any withholding / KYC / country limits.

## FULL rule questionnaire (canonical - send to PFM or any firm; covers everything that matters for our EA)
Skips the obvious commons (that it's simulated, generic profit target). Focus: EA-in-funded, floating-loss rules,
drawdown mechanics + reference basis, funded-stage additions, payout reality, cost.

```
Hi, before buying I need the exact rule details that decide whether an automated MT4/MT5 EA can run profitably.
Please confirm each point (or point me to where it is published). Firms I'm asking about are listed at the end.

A. EA / automation
1. Are automated EAs allowed during the challenge/evaluation?
2. Are automated EAs allowed on the FUNDED / live account after passing? (most important)
3. Any EA conditions: must be personally coded, source-code proof, pre-approval, or an EA usage fee?

B. Drawdown / loss limits
4. Maximum overall loss: what %, and is it STATIC (fixed from the starting balance) or TRAILING?
5. Daily loss limit: what %, measured from the INITIAL balance or the START-OF-DAY balance, and does it include
   OPEN (floating) positions? What time does the day reset (server time)?
6. Do both limits count floating/unrealised losses (equity), or only closed trades?
7. Besides those two, is there ANY other rule that can close the account or cut the profit split based on the
   floating loss of open trades (a max floating-loss / equity-protection rule)? If yes, the exact threshold.

C. Funded / live-stage rules
8. What rules are ADDED or CHANGED once the account is funded/live vs the challenge?
9. Is there a consistency rule (cap on how much of total profit a single day can be)? Exact %?
10. Minimum and maximum trading days? Minimum hold time per trade?
11. News-trading rule on the funded account (restriction or profit adjustment around high-impact news)?
12. Overnight and weekend holding allowed on the funded account?

D. Instrument / sizing
13. Is XAUUSD (gold) allowed? Its leverage/margin? Any max lot, max total position, or max open positions?

E. Payout
14. Profit split %? Payout cycle length? Minimum days/conditions for the first payout? Any fee refund?
15. Can you share proof of recent trader payouts / a payout track record?

F. Cost
16. Challenge fee for the $5,000 and $10,000 accounts (after any discount)? Reset fee?
```
Firm list to attach (Tier 1 + Tier 2 + Legion + IXU): The5ers, FundingPips, Alpha Capital, FundedNext, E8 Markets,
FTMO, Blueberry Funded, Instant Funding, AquaFunded, For Traders, Blue Guardian, Top One Trader, FundedElite,
Finotive Funding, Hola Prime, BrightFunded, FXIFY, Crypto Fund Trader, Audacity Capital, Funded Trading Plus,
Legion Funding, IXU Capital.

## Approx entry fees (small accounts, change often + discounts - verify on site)
- FTMO: no $5k; smallest $10k ~ $99+  => EXPENSIVE (user's concern).
- FundingPips: from ~$29 (small); ~$289 for 50k 2-step. CHEAP + established (~$64M paid 2026).
- E8 Markets: from ~$32. CHEAP, up to 14% static, allows martingale.
- FundedNext: from ~$32; 120% fee refund on first payout + 15% profit-share during challenge; up to 95% split.
- All three (FundingPips / E8 / FundedNext) are far cheaper than FTMO and share the no-Goat-Guard shape.

## Broader candidate scan [2026-09-17] (published data + payout reputation; per-firm EA-funded / guard / daily-reference are PENDING the support reply)
Ranked for OUR need: cheap + no floating-loss guard + EA allowed in funded + static DD + gold + RELIABLE PAYOUTS.
Fees are approx small-account, change often / discounts apply - verify on site.

| Firm | ~fee ($5k) | drawdown | EA note | payout reputation | fit verdict |
|---|---|---|---|---|---|
| **FundingPips** | ~$29 | STATIC 10% max / 5% daily (no time limit) | personal EA, source code proof | ~$64M paid 2026 - reliable | TOP cheap fit - confirm daily ref + guard |
| **FundedNext** | ~$32 | STATIC 10% / 5% daily (of INITIAL) | EA yes (small EA fee) | 24h payout guarantee, top-rated - reliable | STRONG - our combo_fnext_03 config validated |
| **E8 Markets** | ~$32 | STATIC up to 14% (most room) | EA yes, even martingale | established | STRONG - 14% max = more room, confirm daily+guard |
| **Blueberry Funded** | ~$39 | static | EA yes, NO consistency rule | established | good - confirm daily ref + guard |
| **The5ers** | ~$39+ | static/EOD | EA yes (banned list) | reputable, high split ceiling | good but pricier |
| **Maven Trading** | ~$17 (cheapest) | PENDING | PENDING | newer - VERIFY payout record | cheapest - verify everything incl payouts |
| **FXIFY** | ~$39 | PENDING | EA needs PRE-APPROVAL | reputable | workable but pre-approval step |
| **FunderPro / Alpha Capital Group** | PENDING | PENDING | EA-friendly (TradeLocker) | check | PENDING full rules |
| ~~Sure Leverage~~ | ~$25 | 8-10% | **EA BANNED once funded** + 1% floating-loss rule | - | **AVOID** (EA killed on funding + a guard-type rule) |
| ~~Goat Funded Trader~~ | ~$19 | static 10% | EA yes | established | avoid for the aggressive config (Goat Guard $100 floating) |

PAYOUT-RELIABILITY sources to watch: propfirmmatch.com/payouts + payoutjunction.com/statistics (tracked/blockchain-verified
payout totals), Trustpilot, and each firm's own payout proof. Context: industry data suggests only ~7% of traders ever
reach a payout - so RULES + our discipline matter as much as the firm.

## Prop Firm Match - 36 EA-allowing firms, triaged by reputation [2026-09-17]
Source: propfirmmatch.com "Prop Firms That Allow EA Trading" (rating / review-count = payout-reliability + track-record
proxy; PFM says it vets compliance history + payout reliability). ALL 36 allow EA at some level; the per-firm daily
reference (#3) + floating-loss guard (#4) still need each firm's support reply. Message TIER 1 first.

TIER 1 - proven (high rating + many reviews = reliable payouts) + likely fit -> MESSAGE THESE FIRST:
- The5ers 4.7 (1312) - static, reputable, 10% off
- FundingPips 4.2 (1199) - static 10%/5%, ~$29, 20% off - cheap + proven
- Alpha Capital 4.4 (1096) - EA, 40% off
- FundedNext 4.3 (882) - static, 24h payout guarantee, our combo_fnext_03 validated, 20% off
- E8 Markets 4.8 (487) - up to 14% static, martingale ok, 25% off - highest rating
- FTMO 4.6 (209) - deepest payout record, day-start daily confirmed, but pricey

TIER 2 - decent reputation, worth messaging after Tier 1:
Blueberry Funded 4.1 (621, no consistency rule), Instant Funding 4.0 (361), For Traders 4.4 (295, 50% off),
AquaFunded 4.4 (298), Blue Guardian 4.2 (223), Top One Trader 4.4 (208, 60% off), FundedElite 4.3 (193),
Finotive 4.1 (176), Hola Prime 4.3 (146), BrightFunded 4.5 (127, 30% off), FXIFY 3.9 (127, EA pre-approval),
Crypto Fund Trader 4.1 (109), Audacity Capital 4.1 (108, 15% static), Funded Trading Plus 4.3 (74).

TIER 3 - HIGH rating but FEW reviews = newer, payouts UNPROVEN -> only if Tier 1/2 fail, and DEMAND payout proof:
Moneta Funded 4.9 (80), Lark Funding 4.5 (90), ThinkCapital 4.0 (62), City Traders Imperium 4.3 (57),
Hantec Trader 4.0 (52), Atmos Funded 4.5 (46), The Trading Pit 3.9 (36), BEM Funding 5.0 (30),
WSFunded 3.3 (21, low rating), plus <20-review: Fintokei, Nordic Funder, Darwinex Zero, Ment Funding, Leveraged, Orion Funded.

GFT is NOT excluded - it is our MOST-VALIDATED firm:
- Goat Funded Trader 4.1 (1162) - established, EA allowed, cheap (50% off), and we have ALREADY confirmed every rule
  directly with GFT support AND built + validated a compliant config (eval +208%, funded 0.01 safe +12.6% = ~$42/mo).
  It is not in the "message these" list only because it is already fully answered. The single downside: the Goat Guard
  $100-floating rule caps funded income (the aggressive 0.04 config breaches it; safe-max ~0.015 lot ~= $60/mo).
  ROLE: the proven, guaranteed-compliant SAFE BASELINE / fallback. Higher income needs a no-Goat-Guard firm, but if a
  no-guard firm turns out unreliable at paying, GFT is the known-good option we can trust.
- Big discount codes (MATCH etc.: E8 25%, Alpha 40%, For Traders 50%, Top One 60%, Moneta 60%) cut entry cost a lot -
  but a discount means nothing if the firm does not pay, so weight Tier over discount.

## MULTI-FIRM hidden-rule sweep [2026-09-17] (each firm's OWN help centre / verified reviews)
PATTERN: most firms have SEVERAL products - some STATIC, some TRAILING; you must pick the STATIC one. A best-day
CONSISTENCY rule (payout gate, not usually a breach) is common. Daily loss is often 3% on 1-step/tight products vs 5%
on others (our 0.04 config needs ~5% daily; 3%-daily firms need a size trim). The account-KILLING floating guard is RARE
(so far only GFT Goat Guard, Sure Leverage 1%, FundingPips Striking >=$25k; E8 Signature has a 2% soft PAUSE not a kill).

- **The5ers**: STATIC (from initial), daily day-start (higher of prev-day close bal/eq, 00:00 server). 1-Step: 6% max /
  3% daily / **50% consistency**. High Stakes: 10% max / 5% daily. NO floating guard. Reputable, payout every 14d from $150,
  EA allowed. Watch: 3% daily (tight) on 1-step + 50% best-day payout gate.
- **Alpha Capital**: drawdown VARIES - Alpha One 6% TRAILING (avoid), Alpha Direct 5% trailing (avoid), **Alpha Pro 6%
  STATIC, Alpha Three static, Alpha Swing 10% STATIC** (use these). **40% best-day consistency on ALL eval products**
  (Direct 15%). NO floating guard. Big discount (40%). Use Alpha Swing (10% static) or Pro.
- **Blueberry Funded**: most plans STATIC but 3-Step + both Instant TRAILING (avoid those). **Flex 1-Step = 12% static
  max / 3% daily / NO consistency / 85% split / no min days / no time limit** (good, but 3% daily tight). Supports
  scalping, flexible news/holding (post 12 Mar 2026). NO floating guard.

- **Blue Guardian**: 2 Step Standard = **8% STATIC** max, **daily 4% of initial** (day-start higher of bal/eq @5pm EST),
  min 3 profitable days, 85% split (90% add-on), payout 14d, weekend OK, EA allowed, news restricted +/-5min on funded.
  BUT **"Guardian Shield" (funded only): auto-closes trades at 2% floating loss** = a GOAT-GUARD-TYPE floating cap ($100
  on $5k) + **2-minute minimum hold (tick-scalping rule)**. 1-Step Standard = 6% TRAILING (avoid). => Blue Guardian
  constrains the aggressive config just like GFT (2% floating). Note the guard.
- **For Traders**: static / end-of-day drawdown (per fortraders + 3rd-party), up to 90% split, low-cost entry, EA
  allowed. Daily % + consistency + any guard = still to confirm from their own docs. Promising cheap + no-guard-known.
- **Instant Funding** (the firm): not cleanly captured; instant-funding models tend to be tight (e.g. ~1% intraday
  trailing daily + 20% consistency + 3% static) which suits us poorly. LOW priority - confirm from their own docs.

- **Hola Prime**: daily **3% (tight)**, max ~6% static or 4% trailing (product-dependent), has a consistency rule
  (biggest-day / total), very fast payouts (~1h). 3% daily is tight for our 0.04 -> would need a trim. Confirm guard/EA.
- **FundedElite**: founded 2023 (Quantum SRL, Italy), split up to 95%, targets 6-10%, **daily 3-5%, max 6-8% STATIC**,
  min days 0-6, news allowed / no HFT, cheap. Reasonably clean (static) but NEWER -> verify payouts + guard + EA-funded.
- **Top One Trader**: their FUTURES product uses EOD TRAILING drawdown; forex/CFD product not cleanly captured -> PENDING
  (likely trailing on some products; confirm the static one).

GUARD TALLY so far (the account-constraining floating rule, GFT-style): HAVE it -> GFT (2%), Blue Guardian (2% Guardian
Shield), Sure Leverage (1%), FundingPips ONLY >=$25k (Striking). NO such guard found -> FundedNext, FTMO, E8 Pro, The5ers,
Alpha (Pro/Swing), Blueberry (static plans), FundedElite, Hola Prime, For Traders (to confirm), FundingPips <$25k.
COMMON non-killer gates: best-day CONSISTENCY (20-50%, payout gate) at The5ers 50%, Alpha 40%, E8 One/Sig 40/35%, Hola
Prime, Audacity, FXIFY 30%; and 3% (tight) DAILY at The5ers 1-step, Blueberry Flex, Hola Prime (our 0.04 needs 5% daily
or a trim to ~0.025).

- **BrightFunded** (FULL table from their own help centre, 20 May 2026): 2-Step Classic = **10% STATIC max, 5% daily,
  min 5 days/stage, targets 10%+5%**; 2-Step Bright = 8% static, 4% daily, min 5 days, targets 8%+5%; 1-Step = 6%
  TRAILING (avoid). **NO consistency rule** (confirmed). News + weekend allowed, EA allowed, +30% scaling/4mo, 30% off.
  NO floating guard found. => **2-Step Classic (10% static + 5% daily) = CLEAN fit; 5% daily may allow our 0.04 config.**
  Still confirm: daily reference (initial vs day-start) + EA-on-funded + gold leverage.
  NOTE: E8 Pro MT5 runs via "E8 Markets Ltd" (St Lucia); Tradelocker/cTrader via "E8 Funding LLC" (fee non-refundable,
  pass rate 17.7%). Audacity help centre is LOGIN-GATED -> its exact daily%/consistency need the user's support chat.
- **Audacity Capital**: **15% STATIC max (the WIDEST room of all)**, daily 5% of higher of bal/eq at rollover (day-start,
  00:00 GMT+2; intraday high raises it), no min days, no time limit, EA allowed, bi-weekly payout from 14d, news avoid
  +/-3min. HAS a consistency rule. (Instant "FTP" product = 5% trailing daily + 10% max, different.) NO floating guard
  found. => most drawdown room = our 0.04 config has the biggest safety buffer here.
- **FXIFY**: many products (5%/10% static OR 4-10% trailing - pick STATIC), first target 10%, daily loss up to 8%
  (generous), **30% consistency**, **EA needs PRE-APPROVAL**. Workable but pre-approval step. NO floating guard found.

CLEAN FITS (static + no floating guard + EA-in-funded, for our config): FundingPips (<$25k), FundedNext, FTMO, E8 PRO,
The5ers, Alpha (Pro/Swing), Blueberry (static plans), BrightFunded (2-Step), Audacity (15% static, widest), FundedElite,
For Traders. HAVE a floating guard (constrains us like GFT): GFT, Blue Guardian, Sure Leverage, FundingPips >=$25k.
NOT-YET-SWEPT (send the questionnaire): Crypto Fund Trader, AquaFunded, Funded Trading Plus, Finotive, Instant Funding,
Top One Trader (forex product), Moneta, Lark, ThinkCapital, CTI, Hantec, Atmos, BEM, WSFunded, Fintokei, Nordic,
Darwinex, Ment, Leveraged, Orion, Legion Funding, IXU Capital, Maven Trading.

## Reply log (paste support answers here, dated, with firm name)

### FundedNext (Stellar CFDs) - support reply [2026-09-17]
- **EA**: allowed on MT4/MT5, must be customised + unique strategy; EAs built specifically to pass
  prop challenges are NOT allowed; max allocation per EA $300,000. Must pick ONE method (manual OR
  EA) - switching restricted after certain phases and not allowed on the funded account. => for a
  pure-EA trader this means EA IS usable through challenge AND funded (just commit to EA from start).
- **Max Loss Limit (overall)**: STATIC, of INITIAL balance. Stellar 1-Step 6%, 2-Step 10%, Lite 8%.
  Breach if balance OR equity falls below the level at any time.
- **Daily Loss Limit**: Stellar 2-Step = 5% of initial per day, measured against initial balance,
  INCLUDES open/floating P&L.
- **Floating-loss / open-position guard (Goat-Guard type)**: NONE reported - only MLL + daily loss.
- **Gold (XAUUSD)**: not answered - FOLLOW-UP NEEDED.
- **Split / payout cycle / payout proof**: not answered - FOLLOW-UP NEEDED.
- WHAT THIS MEANS FOR US: the exact rule that blocked our high-income 0.04-lot config on GFT (Goat
  Guard $100 floating) does NOT exist here. On FundedNext 2-Step the binding limit becomes the daily
  5% (incl. floating). Our 0.04 config's worst single-trade float was ~-$212 = -4.26% of $5k (under
  the -5%/-$250 line but thin), and its min equity $4,972 easily cleared the static 10% floor. So the
  config is a candidate here - must be re-tested against a 5%-incl-floating daily rule (may need 0.03).

### FundedNext - follow-up reply [2026-09-17]
- **XAUUSD**: allowed. News trading allowed in challenge + funded, BUT in the FUNDED account profit
  made within 5 min before/after high-impact news is counted at only 40% (losses fully applied);
  XAUUSD is hit by USD high-impact news. Weekend holding allowed (2-Step challenge + funded). No
  minimum hold time.
  => mitigation: run our EA with the news gate ON so it does not open/close inside the news window
  and avoids the 40% profit haircut. Weekend-hold OK means DTREND's multi-day runners are fine.
- **Split / reward cycle / payout proof**: still NOT provided - FOLLOW-UP still open.
- **EA in funded**: this second agent could NOT confirm EA usage / whether a custom EA keeps running
  after funding. This CONTRADICTS the earlier agent (who said EA is allowed, EA-only). => treat
  EA-in-funded as NOT yet firmly settled; get a definitive written confirmation before buying.

### E8 Markets - hidden-rule sweep [2026-09-17] (e8markets.com + help.e8markets.com + proptradingvibes)
- E8 has THREE products with DIFFERENT drawdown types - product choice is critical:
  - **E8 PRO = 8% STATIC (never trails), 8% target, NO consistency rule, NO trailing, UNRESTRICTED news, daily payouts,
    fee 100% refundable on first payout.** => the clean product for us (but 8% max is tighter room than 10%).
  - E8 Signature = **EOD Dynamic = TRAILING** drawdown (locks at initial), 35% best-day consistency, plus a 2% "daily
    pause" (soft: floating OR closed loss hits 2% -> trading pauses to next day, NOT a breach). AVOID (trailing).
  - E8 One = 3% daily (from day-start), 40% best-day consistency.
- Daily loss reference = "starting balance of the day" = DAY-START (good). Evaluation has no consistency rule.
- No separate floating-loss KILL found (Signature's 2% is a soft pause, not an account-killer). Confirm E8 Pro's exact
  daily-loss % + EA-on-funded in writing.
- CORRECTION: my earlier "E8 up to 14% static" was WRONG - the 14% is the Signature TRAILING max, not static.

### FundedNext - hidden-rule sweep [2026-09-17] (help.fundednext.com + tradetheday)
Extra rules beyond the basics (these are the "hidden" ones):
- **Minimum 5 SEPARATE trading days** on Stellar 2-Step (not 3) - more than we assumed.
- **3% maximum risk PER TRADE** (FundedNext uses this instead of a best-day/consistency rule) - our per-trade risk is
  well under 3%, so OK, but it is a hard rule.
- **Single-IP / reliable VPN-VPS rule** - must trade from one IP or a stable VPS (fine for an EA on a VPS, note it).
- No best-day consistency rule on Stellar (the 3% per-trade cap replaces it). News 40% profit haircut (known).
- Daily 5% of INITIAL (confirmed), Max 10% static, EA allowed on funded (small EA fee). No separate floating guard.

### FundedNext - definitive follow-up [2026-09-17]
- **Daily 5% = calculated from the INITIAL balance, NOT start-of-day** (confirmed). Includes closed
  trades + floating losses + swaps + commissions. => fixed $250/day on $5k. This is the STRICT type.
- **EA**: allowed on MT4/MT5 for Stellar 2-Step (small EA usage fee by account size). EA-in-funded now
  positively confirmed (resolves the earlier agent contradiction).
- Split / payout cycle / proof: still not provided.
- ACTION: our 0.04 config breaches this (worst day -$287, worst float $250.50 > $250). Build the
  INITIAL-referenced daily governor + 0.03 lot and re-test (that is combo_fnext_03 / ledger prereg).

### FTMO - support reply [2026-09-17]
- **EA/strategy**: no strategy restricted by name; discretionary/algo/EA all allowed as long as
  legitimate (proper risk mgmt), conforms to real market conditions, not a forbidden practice.
  Forbidden practices: https://ftmo.com/en/forbidden-trading-practices/ . EA allowed on the funded
  account too.
- **Max Loss**: fixed OR EOD-trailing DEPENDING ON PRODUCT (1-Step/2-Step). Objectives:
  https://ftmo.com/en/trading-objectives/ -> must pick the product whose Max Loss is FIXED (static).
- **Loss limits include FLOATING**: both Max Loss and Max Daily Loss trigger on the EQUITY (open
  floating exposure), not just closed trades. Exceeding = account restricted / positions closed.
  "Besides this particular matter, there are no scenarios in which we will interfere" => NO
  Goat-Guard-style separate rule. https://ftmo.com/en/blog/why-do-we-care-about-open-losses/
- **XAUUSD**: available (https://ftmo.com/en/symbols#xau-usd). News-trading + weekend/overnight
  holding restrictions depend on the ACCOUNT, not the instrument. NO minimum hold time for any symbol.
- **Split / payout**: 1-Step 90%, 2-Step 80% (->90% via Scaling Plan / Premium). First reward after
  >=14 days from the first funded-account position; then every 14 days.
- WHAT THIS MEANS FOR US: same shape as FundedNext - NO Goat Guard. Only Max Loss (10% class, incl
  floating) + Daily 5% (incl floating). No min-hold (better than GFT's funded 2-min rule). Established
  => payouts reliable. Binding limit = daily 5%-incl-floating. Confirm the chosen product's Max Loss
  is FIXED, not EOD-trailing.

### FundingPips - VERIFIED rules [2026-09-17] (proptradingvibes, checked vs help centre 16 Sep 2026)
2 Step Standard ($5K/$10K), our reading:
- Targets 8% then 5%; **Max Loss 10% of INITIAL, STATIC, includes floating, breach on touch** (floor never moves across
  phases + Master).
- **Daily Loss 5% of the HIGHER of the day's opening balance OR opening equity, floating included, resets 00:00 UTC+3**
  => DAY-START referenced (like GFT/FTMO), NOT initial. => our 0.04 +88% config (combo_noguard_04) fits WITHOUT the
  0.03 trim.
- **Floating-loss rule ("Striking System"): applies ONLY on Master accounts ABOVE $25,000** (1.2% floating per trade
  idea). On $5K/$10K it does NOT apply => NO floating-loss guard on the small accounts. (Also no consistency rule on
  the Bi-Weekly 80% cycle, and none during evaluation.)
- EA allowed (MT5 / cTrader / Match-Trader). Established (~$64M paid). Registration fee refunded at the 4th reward on
  2 Step Standard. Price ~$36 ($5K), ~$66 ($10K); 2 Step Pro cheaper (~$29/$55) but 6% floor.
- Splits by cycle: 60% Weekly / 80% Bi-Weekly / 100% Monthly / 90% On-Demand (locked before trading; use Bi-Weekly 80%,
  no consistency).
- **News (Master):** profit of a trade opened/closed within 5 min of a red-folder event is fully deducted -> run news gate ON.
- **WEEKEND (Master): holding over the weekend currently NOT allowed on 2 Step Standard Master (temp since 29 Jan 2026);
  open trades auto-close Friday, NOT a hard breach.** => this cuts DTREND's multi-day runners; must re-test with a
  Friday-flat rule to get FundingPips' true number.
VERDICT: best-shaped cheap established fit for $5K/$10K (day-start daily + no guard + static + EA + fee refund). Next:
add a weekend-flat option to the EA and re-run the 0.04 config to value it accurately under the Friday-close rule.

### KEY CROSS-FIRM FINDING [2026-09-17] - the daily-limit REFERENCE basis decides everything
Backtest of our no-Goat-Guard 0.04 config (ledger seq219) made +88.2%/yr (~$297/mo at 80% = meets
target) and is STATIC-safe, but the daily 5% rule can go either way depending on its reference:
- daily 5% of DAY-START balance -> our worst day = -3.30% = SAFE.
- daily 5% of INITIAL balance (FundedNext's stated rule), incl floating -> worst day -5.74% + one
  trade's float 5.01% = BREACH.
So for EVERY firm we must ask: is the daily loss limit 5% of INITIAL, or 5% of day-start balance,
and does it include floating? This changes whether we deploy 0.04 or must trim to ~0.03 / add an
initial-referenced governor.

### FollowUp questions still open for FundedNext
1. Profit split %, payout cycle length, and proof of recent payouts?
2. DEFINITIVE: if I choose EA from the start, does that same custom EA keep running on the FUNDED
   account (not disabled once funded)? (agents gave conflicting answers)
3. Is the daily 5% referenced to the INITIAL balance or the day-start balance? (support said initial)

### FollowUp question still open for FTMO
1. For the 2-Step product: is the Maximum Daily Loss 5% referenced to the INITIAL balance or to the
   day-start (previous-day) balance/equity? And confirm the chosen product's Max Loss is FIXED
   (static), not EOD-trailing.


================================================================================
# AUTHORITATIVE PER-FIRM RULEBOOK (organized by firm name)
================================================================================
Read from each firm's own FAQ/T&C. Common rules (2-step structure, 2-min tick-scalp hold, HFT/arb bans)
are omitted - only the deciding + HIDDEN rules (the GFT-Goat-Guard-type things) are listed per firm.
Account referenced = 2-Step Standard $5,000 (unless noted). PENDING = still to confirm from firm/support.

## --- CLEAN FITS (static + no account-killing floating guard + EA on funded) ---

### FundingPips  (2-Step Standard $5K/$10K)
- Max loss: 10% STATIC, incl floating, breach-on-touch. Daily: 5% of START-OF-DAY (higher of bal/eq), incl floating, reset 00:00 UTC+3.
- Floating guard: NONE below $25K (Striking System 1.2% applies ONLY >=$25K). Consistency: none on Bi-Weekly.
- Min days 3/phase; inactivity 30d. News (funded): profit deducted if within 5min of red news. Weekend (funded Master): auto-close Fri (NOT a breach).
- EA on funded: YES (source-code proof). Gold: yes (leverage PENDING). Split 80% bi-weekly; fee refunded at 4th reward. Price ~$36. Payouts ~$64M paid.
- VERDICT: CLEAN. Our 0.04 (+88%) config fits (day-start daily). PENDING: gold leverage. Trading impact: weekend auto-close trims DTREND runners.

### BrightFunded  (2-Step Classic)
- Max loss: 10% STATIC. Daily: 5% (reference PENDING). Min 5 days/stage. Floating guard: NONE. Consistency: NONE.
- News + weekend: allowed. EA: yes (funded confirm PENDING). Gold: PENDING. +30% scaling/4mo. Price 30% off code.
- VERDICT: CLEAN (arguably cleanest: 10% static + 5% daily + no consistency + weekend OK). PENDING: daily reference, EA-on-funded, gold leverage.

### FundedNext  (Stellar 2-Step)
- Max loss: 10% STATIC. Daily: 5% of INITIAL, incl floating. Floating guard: NONE. Consistency: none (uses 3% MAX RISK PER TRADE instead).
- Min 5 separate days. Single-IP / stable-VPS rule. News (funded): profit counted 40% within 5min. Weekend: OK. No min hold.
- EA on funded: YES (small EA usage fee). Gold: yes (leverage PENDING). Split up to 95%; 24h payout guarantee. Price ~$32.
- VERDICT: CLEAN (needs the 0.03 initial-referenced config = +75%). PENDING: exact split %, payout proof, EA fee amount, gold leverage.

### FTMO  (2-Step)
- Max loss: static (per chosen product), incl floating. Daily: 5%, incl floating (reference: confirm initial vs day-start).
- Floating guard: NONE ("besides Max Loss + Daily Loss, no scenarios we interfere"). Consistency: none. No min hold. Gold: yes.
- EA on funded: YES (any legitimate strategy). Split 80% 2-Step (->90% scaling), 90% 1-Step; reward every 14d.
- VERDICT: CLEAN but PRICEY ($10k smallest ~$99+). PENDING: confirm chosen product's Max Loss is fixed + daily reference.

### E8 Markets  (E8 PRO only)
- Max loss: 8% STATIC (never trails). Daily: PENDING %. Floating guard: NONE (Signature's 2% is a soft PAUSE, not a kill). Consistency: NONE on Pro.
- News: unrestricted (Pro). EA on funded: yes (confirm). Gold: PENDING. MT5 via "E8 Markets Ltd"; fee non-refundable; pass rate 17.7%.
- VERDICT: CLEAN but 8% max = less room than 10%. AVOID E8 Signature (TRAILING) + E8 One (3% daily + 40% consistency). PENDING: daily %, EA-funded, gold.

### Audacity Capital
- Max loss: 15% STATIC (WIDEST room of all). Daily: 5% of START-OF-DAY (higher bal/eq, 00:00 GMT+2; intraday high raises it).
- Floating guard: NONE found. Consistency: YES (% PENDING). No min days; no time limit. News: avoid +/-3min. EA: yes. Gold: PENDING.
- Payout bi-weekly from 14d. Help centre LOGIN-GATED -> exact consistency%/daily need the user's support chat. 35% off.
- VERDICT: CLEAN + most drawdown buffer. PENDING (via support): consistency %, EA-on-funded, gold leverage.

### The5ers
- Max loss: 6-10% STATIC (from initial). Daily: 3% (1-Step, tight) / 5% (High Stakes), from day-start (higher prev-day close bal/eq, 00:00 server).
- Floating guard: NONE. Consistency: 50%. EA: yes. Payout every 14d from $150. Reputable, well-documented.
- VERDICT: CLEAN but watch 3% daily (1-Step) + 50% best-day. PENDING: EA-on-funded + gold confirm.

### Alpha Capital  (use Alpha PRO or Alpha SWING - the STATIC ones)
- Max loss: Pro 6% STATIC / Swing 10% STATIC (AVOID Alpha One 6% trailing + Alpha Direct 5% trailing). Daily ~3.8% avg.
- Floating guard: NONE. Consistency: 40% best-day (all eval products; Direct 15%). EA: yes. 40% off.
- VERDICT: CLEAN on Pro/Swing. PENDING: exact daily % + reference, EA-on-funded, gold.

### Blueberry Funded  (use a STATIC plan, e.g. Flex 1-Step)
- Flex 1-Step: 12% STATIC max / 3% daily / NO consistency / 85% split / no min days / no time limit. (AVOID 3-Step + both Instant = TRAILING.)
- Floating guard: NONE. Scalping OK; flexible news/holding (post 12 Mar 2026). EA: yes.
- VERDICT: CLEAN (Flex 1-Step). Watch 3% daily. PENDING: EA-on-funded + gold confirm.

### FundedElite
- Max loss: 6-8% STATIC. Daily: 3-5%. Split up to 95%. News allowed / no HFT. Min days 0-6. Founded 2023 (newer).
- Floating guard: PENDING. Consistency: PENDING. EA: yes (confirm funded).
- VERDICT: PENDING - verify payout track record + guard + EA-on-funded before trusting.

### For Traders
- Drawdown: static / end-of-day (per multiple sources). Split up to 90%. Low-cost entry. EA: yes.
- Daily % / consistency / floating guard: PENDING (read their FAQ). VERDICT: PROMISING cheap no-guard - confirm details.

## --- HAVE A FLOATING GUARD or EA-FUNDED BAN (constrains/blocks us; note carefully) ---

### Goat Funded Trader (GFT)  [our validated baseline]
- Max 10% STATIC. Daily 5% day-start (higher bal/eq @5pm EST). **GOAT GUARD: 2% of initial floating ($100) - 1st = split cut, 2nd = account dead.**
- Funded 2-min min hold. EA: yes. VERDICT: SAFE + fully validated, but Goat Guard caps income to ~$42-60/mo (0.01-0.015 lot). Fallback baseline.

### Blue Guardian  (2-Step Standard)
- Max 8% STATIC. Daily 4% of initial (day-start higher bal/eq @5pm EST). **GUARDIAN SHIELD (funded): auto-closes trades at 2% floating loss ($100).** 2-min min hold.
- News +/-5min restricted funded. Weekend OK. EA: yes. 85% split (90% add-on). 1-Step Standard = 6% TRAILING (avoid).
- VERDICT: constrains us like GFT (2% floating cap). Usable only with the tiny/safe config, not the aggressive one.

### Sure Leverage Funding
- **EA BANNED once funded** + a 1%-floating-loss rule (2nd breach closes). VERDICT: AVOID (kills the whole automated plan on funding).

### FXIFY
- Many products (5%/10% STATIC or 4-10% TRAILING - pick static). Daily up to 8% (generous). Consistency 30%. **EA needs PRE-APPROVAL.**
- Floating guard: none found. VERDICT: workable but pre-approval step + 30% consistency. PENDING: confirm static product + EA pre-approval process.

### Hola Prime
- Daily 3% (tight). Max ~6% static or 4% trailing (product-dependent). Consistency rule (biggest-day/total). Very fast payouts (~1h). Futures = trailing.
- VERDICT: 3% daily too tight for the aggressive config; would need a size trim. PENDING: guard + EA-on-funded.

## --- NOT YET READ (send them the questionnaire / read FAQ next) ---
Top One Trader (forex product), Crypto Fund Trader, AquaFunded, Funded Trading Plus, Finotive Funding, Instant Funding,
Moneta Funded, Lark Funding, ThinkCapital, City Traders Imperium, Hantec Trader, Atmos Funded, BEM Funding, WSFunded,
Fintokei, Nordic Funder, Darwinex Zero, Ment Funding, Leveraged, Orion Funded, Legion Funding, IXU Capital, Maven Trading.


## --- ADDENDUM (continued FAQ reads) ---

### AquaFunded  (help centre read)
- 2-Step Standard: daily = higher of bal/eq at 00:00 UTC minus 5% of INITIAL (day-start timing, $ capped at 5% of initial).
  2-Step Pro: daily 5% of initial. 1-Step Pro: 3% daily. 1-Step Flex: 3% daily trailing + 12% STATIC max. 3-Step: 4% daily.
  Pay-After-Pass: 5% TRAILING max (avoid). Max-DD TYPE for 2-Step Standard: confirm (likely static).
- Floating guard: none found. Consistency: PENDING. EA: yes (PFM). Gold: PENDING.
- VERDICT: TENTATIVE CLEAN (2-Step Standard/Pro, daily 5% day-start). PENDING: 2-Step max-DD type, consistency, guard, EA-funded.

### Funded Trading Plus
- Drawdown: TRAILING (room from peak always <= a fixed amount) + a consistency rule; varies by program.
- VERDICT: AVOID for our static config (trailing) unless they offer a specifically STATIC program - then re-check.

### For Traders  (still needs its own FAQ read)
- Prior signal: static / end-of-day drawdown, up to 90% split, low-cost. Daily % / consistency / floating guard: PENDING.
- VERDICT: PROMISING cheap no-guard - confirm from their FAQ / support.

STILL NOT READ: Crypto Fund Trader, Finotive, Top One Trader (forex), Instant Funding, Moneta, Lark, ThinkCapital, CTI,
Hantec, Atmos, BEM, WSFunded, Fintokei, Nordic, Darwinex, Ment, Leveraged, Orion, Legion Funding, IXU Capital, Maven.
(These are mostly newer / smaller / crypto-focused = lower priority; read on request or send them the questionnaire.)


## --- ADDENDUM 2 (user-named + more) ---

### Maven Trading
- Per product: **2-Step = 8% STATIC max + 4% daily**; 3-Step 3% static; 1-Step 5% TRAILING; Instant/Mini 3% trailing.
  Cheapest entry (~$17 $5k). Floating guard: PENDING. Consistency: PENDING. EA: yes (PFM). Newer.
- VERDICT: 2-Step (8% static/4% daily) TENTATIVE CLEAN but NEWER -> verify payout record + guard + EA-funded + consistency.

### Finotive Funding
- Standard challenge: ~**7.5% STATIC** drawdown, daily ~4.5% from yesterday's closing balance (day-start). Scalping/hedging
  allowed, min-stop-loss rule, Friday payouts, split from 75% (lower). Futures = EOD trailing (avoid).
- Floating guard: none found. Consistency: none on some. EA: PFM lists allowed. VERDICT: TENTATIVE CLEAN (static, day-start
  daily) but lower split. PENDING: guard, EA-funded, consistency, gold.

### Top One Trader
- **2-Step Plus: removes the consistency rule entirely.** Instant = 15% consistency + 3% daily. Drawdown TYPE per product
  not confirmed (some Top One products trail). MT5. VERDICT: 2-Step Plus promising (no consistency) - confirm drawdown
  static vs trailing + guard + EA-funded.

### Crypto Fund Trader
- Daily tracks losses from the SESSION HIGH (2-phase 5% / 1-phase 4%) = a trailing-style daily (tighter/worse than day-start).
  Instant = static overall. Crypto-focused. VERDICT: session-high daily is unfavourable for us + crypto focus -> LOW priority.

### IXU Capital  [NEW firm]
- From their site only: STATIC drawdown, 2-Step 8%/5% targets, 80% split, ~5h payout. No independent rule docs exist yet.
- VERDICT: PENDING everything (daily %, guard, consistency, EA-funded) via support. NEW = payout UNPROVEN (site showed 0 live payouts). High risk.
- RE-CHECK 2026-09-18 (user asked re a cheap ~$10k offer): their site confirms STATIC max-loss + MT5 (EA plausible), 2-Step 8%/5%, 80% split. BUT a web search for independent reviews / payout proof found NONE (no Trustpilot presence, no verified payouts) for a firm selling cheap $10k accounts. Cheap + unproven-payout + ~zero reviews = the classic "sells challenges, hard to withdraw" risk profile. DO NOT move the plan here until real payouts are proven. FundedNext stays the target (established, proven payouts).

### Legion Funding  [NEW firm, ~1 month old]
- NO published rule docs found anywhere (incorporated 11 Aug 2026). Only marketing ($400k max, 80% split).
- VERDICT: cannot verify any rule publicly -> must get the full questionnaire answered by support; NEW = payout UNPROVEN. High risk.

### (note) GFT update: accounts bought >= 25 Jul 2026 need 4 trading days (each >=0.5% profit) per payout, not 3.


## --- ADDENDUM 3 (Tier-3 / remaining) ---

### City Traders Imperium (CTI)  [reputable]
- 2-Step = **10% STATIC + 5% daily** (10%+5% targets); 1-Step = 5% trailing (avoid); other products static 6/10%. Balance-based
  static (they stress it is NOT equity-tightening). 80% split, scales to $4M, reputable.
- Floating guard: none found. Consistency: PENDING. EA: yes (PFM). VERDICT: CLEAN 2-Step (10% static/5% daily). PENDING: consistency, guard, EA-funded, gold.

### Moneta Funded  [rating 4.9 but only ~80 reviews = newer]
- **2-Step = 10% STATIC + 5% daily**; other models 6% trailing/static + 3% daily. Floating guard: none found. Consistency PENDING.
- VERDICT: CLEAN 2-Step shape, but NEWER -> verify payout record + guard + EA-funded before trusting.

### Atmos Funded  [by Taurex; ~46 reviews = newer]
- **2-Step Standard + 2-Step Plus = STATIC** drawdown; 1-Step/Instant/Nova = trailing (avoid). Daily 3-5%. NO consistency on many
  plans, min 3 days, no time limit, split 80-90%, first payout 14d then bi-weekly. Floating guard: none found.
- VERDICT: CLEAN (2-Step Standard/Plus, static, no consistency). NEWER -> verify payouts + daily% + guard + EA-funded.

### Fintokei
- Daily: 5% (ProTrader) / 3% (Start/Swift) from EOD-equity snapshot at midnight UTC (day-start). Has a **daily PROFIT cap (+1%)** =
  limits how much you can MAKE per day (unusual, hurts big-win days). Max-loss type PENDING (likely static). Scalping OK.
- VERDICT: daily-profit-cap is a drawback for our big-runner days; TENTATIVE. PENDING: max-loss type, guard, EA-funded.

### Instant Funding (instantfunding.com)
- 10% END-OF-DAY TRAILING drawdown (locks at +5%), NO separate daily limit. VERDICT: TRAILING -> AVOID for our static config.

### ThinkCapital
- Lightning: 10% target, 3% daily, **6% TRAILING max**, EA + weekend allowed, 80-90% split. Mostly trailing. VERDICT: AVOID (trailing) unless a static product exists.

### Remaining very-new / thin-review firms (Lark Funding, Hantec Trader, BEM Funding, WSFunded, Nordic Funder, Darwinex Zero, Ment Funding, Leveraged, Orion Funded)
- Too new / too few verified reviews to trust PAYOUTS yet, and rules not consistently documented. ACTION: do not deploy on
  these until (a) the full questionnaire is answered by their support AND (b) independent payout proof exists. Rules alone are
  not enough on an unproven firm. LOW priority vs the proven clean fits above.


### FundedNext - payout structure CONFIRMED [2026-09-17] (final gap closed)
- EA usage fee on Stellar 2-Step: NONE (documentation lists no EA fee) -> resolves the earlier "small fee" ambiguity.
- Payout options: (a) 21-Days = 80% split (->90% after scale-up), cycle 21d first then 14d, NO consistency rule.
  (b) 3-Days = 60% split, needs 3 profitable days each >=1%. (c) On-Demand = 90% from start, but 40% CONSISTENCY rule + 2% growth.
- >>> CHOOSE the 21-Days 80% option: it has NO consistency rule, so our occasional big DTREND runner-day cannot gate a payout.
  (On-Demand 90% is tempting but its 40% best-day rule would hold payouts when one runner dominates.)
- Payout PROOF: support gave none; verify independently via propfirmmatch.com/payouts, payoutjunction.com, Trustpilot
  (FundedNext publishes a 24h payout guarantee + is on the trackers).
- STATUS: FundedNext Stellar 2-Step rules are now FULLY GREEN for our config. Only external payout-proof check remains
  before real money; combo_fnext_03 + 21-Days 80% cycle is the deployment plan. Ready for FORWARD-DEMO.


### FundedNext - PAYOUT PROOF verified [2026-09-17] (independent)
- Official: $271.4M+ net disbursed across 205,380 payout transactions since inception (FundedNext payout report).
- Payout Junction (blockchain-verified): 104,030 Rise-based verified payout records for FundedNext (31 Aug 2026 sync).
- PropFirmMatch: ~$111.9M tracked payouts, 132,910 payouts, largest $58,878, median ~3hr. Recent $5,000-account payouts
  (Sep 11 2026: $515=10.31%, $176, $151) processed instant ~2 min - consistent with our ~$253/mo estimate.
- CONCLUSION: FundedNext is FULLY VERIFIED - rules confirmed + config (combo_fnext_03) validated + payouts independently
  proven. All gaps closed. GREEN-LIT for FORWARD-DEMO (real money still only after the forward-demo matches + human approval).


### FundedNext - final operational details [2026-09-17] (from their own help centre)
- Daily reset: 00:00 SERVER time; server = GMT+3 (DST/summer) / GMT+2 (rest of year). Matches our backtest (server 00:00). CONFIRMED.
- Max lot size: NONE. Max open positions: NONE ("no imposed limits on instruments or position sizes"). => our 2-sleeve combo
  (FIX09 + DTREND, 2 magics, up to 2 concurrent positions) is ALLOWED. (The 5-position cap is only the Monthly Competition, not us.)
- Strategy restrictions: NONE ("no limitations on strategy, discretionary or EAs incl. martingale"). Our trend/breakout EA is fine.
- ** EA allowed only for accounts BELOW $50,000, and ONLY on MT4/MT5 (Match-Trader accounts do NOT allow EA).** => KEY: use
  the MT5 platform + keep the account size < $50k ($5k/$10k/$25k OK).
- Inactivity: account expires after 30 consecutive calendar days with no trade (weekends/holidays included). We trade daily -> fine.
- Leverage: Stellar Forex ~1:30 (gold likely ~1:30; exact XAUUSD leverage still to confirm). At our 0.03 lot this is ~8-9%
  margin, far under the 60% clamp - and the EA's OrderCalcMargin clamp auto-adapts to the broker's real leverage. Safe.
- Stop-loss mandatory: not required (our EA uses SL on every trade regardless). Anti-cheat/"exploitation" clause: standard ToS.
- STILL MINOR/UNCONFIRMED (not deployment-blocking): exact XAUUSD leverage, any max DAILY PROFIT cap, whether the FundedNext
  Pro scale-up switches drawdown to trailing (matters only when scaling later).
- STATUS: FundedNext Stellar 2-Step is GREEN. Deploy on MT5, account < $50k, 21-Days 80% payout option, config combo_fnext_03.


### FundedNext - leverage + profit cap CONFIRMED [2026-09-17] (rulebook now COMPLETE)
- XAUUSD (gold) leverage: Challenge 1:25, FUNDED 1:15 (metals). Lower than our backtest's 1:100, but SAFE at our size:
  0.03 lot gold (~$4300) = ~$865 margin = ~17% of $5k per position; both sleeves ~35% - well under the 60% clamp and the
  80% firm ceiling, so no clamp-trimming expected (income not reduced). EA's OrderCalcMargin clamp uses the broker's real
  1:15 at runtime -> auto-safe. Forward-demo will confirm actual margin behaviour.
- Maximum daily PROFIT cap: NONE.
- FundedNext Pro scale-up drawdown type: still unspecified (only relevant when scaling later, not for the $5k start).
- FundedNext RULEBOOK STATUS: COMPLETE + GREEN. Every deciding + hidden rule confirmed; no account-killing floating guard;
  payouts independently proven. Deploy: MT5, account < $50k, 21-Days 80% option, config combo_fnext_03. Real money only
  after forward-demo on the real feed matches + human approval.


## FundedNext Stellar 2-Step ($5k, MT5) — CONFIRMED rules (verified 2026-09-18, help.fundednext.com)
Source articles: 8021076 (Stellar 2-Step rules), 8020351 (prohibited strategies), 8388896 (strategy
restrictions), 9430123 (funded min-days/target), on-demand-reward / consistency articles.

CONFIRMED:
- Product split: CLASSIC **Stellar 2-Step on MT4/MT5 = EAs ALLOWED (<$50k)**. The separate "FundedNext
  CFD" (Match-Trader / cTrader) product = **EA BANNED, manual only**. MUST buy the MT5 one.
- Targets: Phase1 8%, Phase2 5%. Daily loss 5% of INITIAL. Max loss 10% STATIC. Daily reset 00:00 server.
- Min trading days: **5 days AND 5 trades per phase** (>=1 trade on >=5 separate days; non-consecutive OK; no max).
- Funded phase (Stellar 2-Step): depends on payout option at checkout; **21-Day option = NO min-days, NO
  target**; first reward after 21 days then every 14 days.
- Strategy CONSISTENCY: must use the SAME method in Challenge and Funded (no EA-pass-then-manual switch).
- EAs/indicators allowed <$50k (martingale even allowed); EA usage fee applies; banned >=$50k.
- Single IP / dedicated VPS. Copy-trade only between own accounts. Hedging only within ONE account
  (cross-account hedging banned; a single trade risking ~full daily limit is SUSPECTED as multi-acct hedge).

PROHIBITED (our EA is CLEAN vs all of these): Quick-Strike (<30s trades >=30% of profit), HFT, tick-scalp,
grid, arbitrage, latency, account-rolling, account/device sharing, one-sided-betting, hyperactivity
(>=200 trades or >=2000 server msgs/day).

FLAGS relevant to OUR trend-follower (not breaches, but monitored — verify with support):
- **Market Settlement window 00:00-02:00 server**: profit generated *disproportionately/exclusively* here
  is voidable/terminable. OUR best-config deals: **18.4% of net profit** from entry-hours 0-1 (17 trades),
  but NOT the edge (main edge NY/London h11-17). One-line fix if needed: Combo_BlockEntryHours="0,1".
- **One-Sided-Betting / concentration**: multiple same-direction trades + profit hinging on few big moves =
  gambling flag; remedy is a forced 1% risk rule or adjusted split (NOT an instant breach).
- **40% Consistency Rule**: best single day's profit must be <=40% of total profit at an On-Demand payout
  request, else the withdrawal is HELD until the distribution flattens (payout DELAY, not a breach). Confirm
  whether it also applies to the 21-Day scheduled payout.


### Support reply (via user, 2026-09-18) — Stellar 2-Step $5k
CONFIRMED by FundedNext support (primary source):
- **Daily 5% loss = from the INITIAL balance** (NOT start-of-day), and it **includes closed trades +
  floating losses + swaps + commissions**. -> This is exactly what our EA enforces (Combo_DailyRefInitial=true,
  floating-aware governor). The "initial vs day-start" question that decided 0.03 vs 0.04 lot is now settled = INITIAL,
  so our 0.03-challenge / 0.02-funded config is the correct, conservative choice.
- **EA allowed on MT4 and MT5**, with a small EA-usage fee scaled by account size (exact $ not given).
STILL OPEN (first-line support could not confirm — use help articles + escalate): payout cycle / proof /
21-Day option, whether the 40% consistency rule applies to scheduled vs On-Demand payouts, settlement-window
00:00-02:00 tolerance, one-sided-betting classification for a same-direction trend EA, running the same EA on
multiple self-owned accounts, exact EA fee for $5k.


### Support reply #2 (via user, 2026-09-18) — MAJOR findings, Stellar 2-Step $5k
1. **3% RISK LIMIT on the FUNDED account** (help article 14702245 — NEW, we missed it): at any instant,
   (max potential SL loss) + (combined realized + unrealized/floating loss across all open trades) vs
   INITIAL must be <= 3% = $150 on $5k (swap/commission excluded). NOT an account kill -> 1st breach =
   warning + 100% of the violating trades' profit deducted that cycle; 2nd = PERMANENT reclassify to a
   1% risk cap; later breaches keep deducting. Our 0.02 funded config (FIX+DT overlap ~$220 = 4.4%) would
   VIOLATE it -> funded config must cap combined risk < $150 (MaxOpenTotal=1 and/or combined flatten) +
   re-test before funding. Funded income will drop as a result.
2. **Daily 5% INCLUDES floating** (reconfirmed) -> CHALLENGE lot moved 0.03 -> 0.02 (0.03 worst floating
   ~$293 > $250 breach risk; 0.02 ~$220 safe). Both deploy sets already updated (seq254).
3. **Scaling capped**: "identical trades across accounts NOT allowed" + accounts **>=$50k are MANUAL-ONLY
   (no EA)**. EA ladder caps under $50k and cannot clone identical accounts -> INCOME_SCALING_PLAN 5k->200k
   same-EA ladder is NOT viable as written; fix it.
4. GOOD: **No 40% consistency rule if you take the SCHEDULED payout (not On-Demand)** -> use scheduled.
   EA fee = **$5** ($5k-$25k), add the "EA +$5" add-on at checkout (or "VPS & EA" +$10 for VPS permission).
   Max loss stays STATIC. No fixed max lot (margin-based; ~20-30% margin recommended). Payout via
   USDT (ERC20/TRC20), USDC (ERC20), RiseWorks, Bank Transfer, FNmarkets.


### Support reply #3 (via user, 2026-09-18) — final confirmations
- **VPS**: your OWN private VPS (e.g. AWS) with a DEDICATED IP is allowed, BUT it still requires
  FundedNext's VPS usage fee + the **"VPS & EA" add-on ($10 for $5k-$25k; $60 for $50k-$200k)** at
  purchase. You CANNOT avoid the $10 by bringing your own VPS — it is a usage/permission fee, not a
  rented VPS. (Paying only the $5 EA add-on requires running the EA on a NON-VPS machine — impractical
  for 24/5, and unsafe on our flaky dev PC.) Banned: restricted IPs, shared/broker-sponsored VPS,
  manual trading via VPS, concealing location/identity -> review/termination.
- **3% RISK LIMIT applies to the FUNDED account ONLY** (NOT the challenge) — confirmed by support. The
  challenge is governed solely by 5% daily / 10% static. (So the 0.02 challenge config is unaffected;
  only the funded config needs the 3% rework.)
- **Strategy**: our clean trend EA (hard SL, ~2% risk) is fine as long as it uses no restricted strategy
  (it doesn't). One-sided-betting is NOT pre-flagged; the 1% risk rule is mandatory only IF the trader
  receives an email/reclassification about it.


### IXU Capital — 2-Step rules confirmed from ixucapital.app (2026-09-18; user vouches payouts)
- Static drawdown (fixed from initial, never trails) — matches our config. MT5, EA plausible (MT5).
- 2-Step: target 8% + 5% | **Max daily loss 5%** | **Max overall loss 10% STATIC** | profit split 80% | payout every 14 trading days | min trading days 3 | leverage 1:100 | fee-refund on 4th payout | scaling to $400K | 2-Step from $35 (50% off code IXU50).
- **DIFFERENCES vs FundedNext that affect OUR config:**
  1. **Weekend holding = NO** (must be flat before the weekend). FundedNext allowed weekend holds. Our EA (esp. the DT swing sleeve) holds multi-day/over-weekend -> on IXU we MUST add a Friday force-flatten, which changes behaviour and needs a re-test.
  2. **Max risk/trade (FUNDED only) = 2%** (stricter than FundedNext's 3%). On $10k that is $200 combined SL+floating -> funded config must cap under it.
  3. Daily-loss basis (initial vs day-start) + floating-included: NOT explicit on the site -> confirm with support (reset is 00:00 GMT+3).
- Account sizes incl $10k (user saw ~$10k cheap). $10k @ our validated rate ~= 2x the $6k income ~= ~Tk 35,000/mo (clears the goal) IF we adapt the config (weekend-flat + 2% funded) and re-validate.

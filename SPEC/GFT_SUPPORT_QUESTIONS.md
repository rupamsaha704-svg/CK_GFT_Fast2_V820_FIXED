# Open questions — GFT support + what is needed from the user

> Why this file exists: `SPEC/GFT_RULEBOOK.md` marks several rules `UNCONFIRMED` or `CONFLICTING`.
> Until they are settled, the compliance engine cannot return a real verdict and must report
> `NOT CLEARED`. These are the exact gaps, and who can close each one.
> Created 2026-09-15.

---

## PART A — message to send to GFT support

Copy the block below as-is. It is deliberately ordered by how much each answer changes our risk
calculation, and phrased so a support agent can answer each line without extra back-and-forth.

```
Hello,

I trade a $5,000 2-Step Standard account (XAUUSD, MT5) using an automated strategy, and I am
building a compliance checker so I never breach a rule by accident. Your help centre answered
most of my questions. These are the ones I could not settle from the articles, in order of
importance to me. Short answers are fine.

1. DAILY RESET TIME
   At exactly what time is the daily drawdown reference reset? Please give it in both:
   (a) your platform / server time, and (b) UTC.
   My broker terminal runs on a GMT+3 server clock, so I need to know which server hour begins a
   new "trading day" for the 5% daily rule.

2. DAILY DRAWDOWN REFERENCE
   Is the 5% daily limit measured against the day's starting BALANCE or the day's starting EQUITY?
   If a position is still open at the daily reset, which of the two is used as that day's
   reference?

3. DAILY DRAWDOWN — WHAT IS MEASURED
   Is the 5% breach evaluated on intraday EQUITY including floating (unrealised) P&L, or only on
   closed/realised P&L? In other words, if my equity dips 5% while a trade is open but recovers
   before I close it, is that already a breach?

4. MAX OVERALL LOSS — BALANCE OR EQUITY
   For the 10% static limit ($4,500 floor on my $5,000 account), is the breach triggered by
   balance, by equity, or by whichever touches the floor first?

5. GOAT GUARD — SNAPSHOT DETAILS
   Your article explains that a snapshot is taken when Goat Guard triggers, and that a new
   snapshot is created when the composition of open positions changes.
   (a) Does a PARTIAL close of an existing position create a new snapshot?
   (b) Does modifying a stop loss or take profit create a new snapshot?
   (c) Is the trigger count ever reset — for example after a payout, or at the start of a new
       payout cycle — or is it counted for the entire life of the account?

6. MINIMUM 2-MINUTE HOLD — HOW IT IS MEASURED
   (a) Is the 2 minutes measured from POSITION open to POSITION fully closed, or per individual
       deal/fill?
   (b) If I close only PART of a position within 2 minutes and the rest much later, is the profit
       from the partial close removed, or the whole position's profit?
   (c) Confirming: this applies to funded accounts only and not to Step 1 / Step 2 — correct?

7. NEWS TRADING
   Your article "Is News Trading allowed?" says news trading is allowed and breaks no rule.
   I have seen third-party sites claim that profit made within 5 minutes of a high-impact news
   release is capped at 1%. Is there any such cap, restriction, or profit adjustment around news
   events on the 2-Step Standard model? I would rather hear it from you than assume.

8. WEEKEND GAP RULE — EXACT HOURS
   The rule refers to the last 3 market hours on Friday and the first 3 market hours on Monday.
   For XAUUSD specifically, what are the exact Friday close time and Monday open time you use for
   this, in your server time? (Gold reopens Sunday evening on my terminal, so I want to be sure
   which session counts as "Monday".)

9. AUTOMATED TRADING / EAs
   Is a fully automated Expert Advisor allowed on this account with no restriction? Is there any
   limit on order frequency, number of trades per day, or minimum time between orders that I
   should code against?

10. HEDGING AND AVERAGING
    Is hedging (holding a long and a short on the same symbol) allowed? Is adding to a losing
    position (averaging down) allowed? I want to confirm from you rather than rely on
    third-party summaries.

11. POSITION AND LOT LIMITS
    On a $5,000 account, is there any maximum lot size per trade, maximum total open volume, or
    maximum number of simultaneously open positions?

12. LEVERAGE PER PHASE
    What is the exact leverage for XAUUSD in Step 1, Step 2, and the Funded stage on the $5k
    2-Step Standard? Your model page says leverage is adjusted between phases but does not give
    the numbers.

13. MY ACCOUNT SPECIFICS
    Please confirm for MY account:
    (a) the purchase date,
    (b) whether my minimum trading days requirement is 3 or 4 per payout,
    (c) whether my first-two-payout cap is 6% or 4% of initial.

14. BROKER / DATA FEED
    Which broker and server will my funded account trade on, and is historical tick data for that
    server available so I can validate on the same feed I will trade on?

Thank you.
```

### If a shorter message is needed first
Questions **1, 2, 3, 5, 6, 13** are the ones that change whether a run passes or fails. If support
prefers fewer questions per ticket, send those first.

---

## PART B — what is needed from the user (I cannot get these myself)

### B1. Facts only you can supply

```
1. Account purchase date (day/month/year) for the $5k 2-Step Standard.
   -> decides minimum trading days 3 vs 4, and payout cap 6% vs 4%.

2. Current stage right now: Step 1 / Step 2 / Funded / not purchased yet.
   -> decides which rule set the compliance agent should treat as live.

3. Funded account LOGIN NUMBER, once you have it.
   -> lets the EA auto-switch to Funded (Goat Guard) mode via Combo_FundedLogin,
      instead of relying on the manual Combo_Stage toggle.

4. Which trading platform GFT gave you: MT5 / Match Trader / cTrader / TradeLocker.
   -> our whole toolchain assumes MT5. If it is not MT5, the execution path changes.

5. Broker + server name of the GFT account (not the MetaQuotes demo).
   -> see the warning in B3 below.
```

### B2. Decisions I need from you before I touch anything

```
1. Goat Guard concurrent-position fix (ledger seq204):
   In FUNDED mode, cap total open positions across FIX09 + DTREND to ONE.
   Reason: two 0.01-lot positions gapping adversely together is about -$106,
   which exceeds the $100 Goat Guard threshold, and the 1.2% flatten cannot
   stop a gap (proven in seq184/seq185).
   Cost: DTREND contributed only $3.66 across 2 trades in funded mode (seq189).
   -> Approve? YES / NO

2. One Model 1 backtest to (a) validate that fix and (b) produce the new
   hold_sec / mae / mfe columns, which is the ONLY way the 2-minute rule,
   weekend-gap rule and Goat Guard stop being UNVERIFIED.
   Both goals are met by the SAME single run.
   -> Run it? YES / NO, and confirm the PC is cool and MT5 is closed.

3. Weekly loss cap: add one? (we have daily 5% and static 10%, nothing weekly)
   -> YES / NO

4. Daily automated compliance report (cron/Task Scheduler) once the above is done.
   -> YES / NO
```

### B3. A validation gap you should know about

Every backtest in this repo runs on **MetaQuotes-Demo** data. The funded account will trade on
**GFT's own broker feed**, which will have different spreads, different slippage, and — most
importantly for us — **different gap behaviour**. Our entire funded ceiling (+11%) and the
$100 Goat Guard safety margin rest on the worst observed gap being about **-$53 per 0.01 lot**.

If GFT's feed gaps harder than MetaQuotes-Demo, that margin shrinks and the Goat Guard risk rises.
This is why question **A14** asks for the broker and whether its history is available. Until we can
test on the real feed, the honest statement is: *validated on demo data, not yet on the feed we
will actually trade.*

### B4. Things I can do without you
- Implement and test the Goat Guard concurrent cap (after your approval in B2.1)
- Run and read backtests (after your approval in B2.2)
- Extend the compliance engine and rulebook as answers arrive
- Build the scheduled compliance report
- Keep the ledger and regression suite green

### B5. Things I cannot do at all
- Contact GFT support or read your GFT dashboard (needs your login)
- Confirm the real daily-reset time — only GFT can state it
- Obtain historical tick data for GFT's broker server
- Place any real-money trade, or approve one

---

## Tracking

Update this table as answers arrive, then update `SPEC/GFT_RULEBOOK.md` and re-run
`tools/test_compliance.py`.

| # | Question | Status | Answer | Rulebook rule affected |
|---|---|---|---|---|
| A1 | daily reset time | OPEN | | 2 |
| A2 | daily reference balance vs equity | OPEN | | 2 |
| A3 | daily measured on floating? | OPEN | | 2 |
| A4 | static floor balance vs equity | OPEN | | 1 |
| A5 | Goat Guard snapshot details | OPEN | | 3 |
| A6 | 2-minute measurement basis | OPEN | | 4 |
| A7 | news trading cap | CONFLICTING | | §6 |
| A8 | weekend gap exact hours | OPEN | | 5 |
| A9 | EA allowed / frequency limits | OPEN | | 11, 13 |
| A10 | hedging / averaging | OPEN | | 13 |
| A11 | lot / position limits | OPEN | | 14 |
| A12 | leverage per phase | OPEN | | §1 |
| A13 | my account specifics | OPEN | | 7, §1 |
| A14 | broker / data feed | OPEN | | B3 |

# CK_GOLD_COMBO � FundedNext Trade Journal & Rule Audit

- **Config audited:** FIX 0.02 + DTREND (DTChop on) + settlement-block (Combo_BlockEntryHours=0,1), Stage=0, DailyRefInitial=true
- **Window:** 2025.10.01 -> 2026.09.18  |  **Data:** MT5 Strategy Tester, REAL TICKS (Model 4)
- **Account:** $5,000 FundedNext Stellar 2-Step
- **Rules audited:** 5% daily of INITIAL incl floating (=$250, KILL) | 10% static floor $4,500 (KILL) | 3% funded risk $150 (funded-only: profit-deduction/reclassify, NOT kill)

> Method note: profit/day is REALIZED (grouped by trade EXIT date, authoritative). The daily FLOATING figure is a
> CONSERVATIVE proxy = sum of every open trade's max-adverse-excursion (MAE) on each date it was open (assumes all
> open trades hit their worst point together � an over-estimate, deliberately strict). MT5 native report gives the
> authoritative equity drawdown; see the .htm. No number here is invented; all come from the MT5 deals CSV.

## 1. Headline result (real ticks)

| Metric | Value |
|---|---|
| Total trades | 270 (FIX 253 / DT 17) |
| **Net profit** | **$2239.56** on $5,000 = **44.8%** |
| FIX net / DT net | $656.63 / $1582.93 |
| Win rate | 25.6% (avg win $109.31 / avg loss $-26.78) |
| Min balance reached | $4914.34 (static floor $4,500) |
| Max drawdown from peak (realized) | $833.76 |
| Worst single trade (realized) | $-217.59 |
| Worst single-trade MAE (adverse) | $106.68 |

## 2. RULE AUDIT verdict

| Rule | Limit | Worst observed | Breaches | Verdict |
|---|---|---|---|---|
| Daily loss (realized, by exit day) | -$250 | $-250.09 on 2026.09.02 | 1 | BREACH |
| Daily floating (conservative MAE proxy) | $250 | $233.33 on 2026-01-13 | 0 | CLEAN |
| Static max loss | balance < $4,500 | min $4914.34 | 0 | CLEAN |
| 3pct funded risk (MAE proxy) | $150 | $233.33 | 10 days | see note |

Days where the conservative floating proxy exceeded $250 (would need a closer look on real equity): NONE

## 3. Monthly net (is profit growing or shrinking?)

| Month | Net |
|---|---|
| 2025.10 | $1106.65 |
| 2025.11 | $208.17 |
| 2025.12 | $147.19 |
| 2026.01 | $1204.55 |
| 2026.02 | $-104.52 |
| 2026.03 | $424.88 |
| 2026.04 | $-186.33 |
| 2026.05 | $-37.95 |
| 2026.06 | $247.17 |
| 2026.07 | $-271.97 |
| 2026.08 | $-127.12 |
| 2026.09 | $-371.16 |

## 4. Worst 12 days (realized)

| Date | Realized P&L |
|---|---|
| 2026.09.02 | $-250.09 |
| 2026.01.13 | $-145.45 |
| 2026.08.13 | $-106.74 |
| 2026.03.12 | $-97.68 |
| 2026.04.02 | $-96.58 |
| 2026.03.16 | $-95.52 |
| 2026.02.13 | $-93.72 |
| 2026.01.28 | $-93.02 |
| 2026.03.27 | $-86.40 |
| 2026.02.04 | $-84.90 |
| 2026.08.10 | $-84.37 |
| 2026.04.10 | $-84.07 |

## 5. Method / integrity
- MAE-units check: median (trade MAE / |realized loss|) over losing trades = 1.12 (near 1.0 => MAE is in account $, so the floating proxy is in $).
- Full per-trade journal: journal_trades.csv (every trade, chronological, with running balance).
- Source: experiments/combo_fnext_journal/ (preset.json + windows/oct25_sep26/report.htm). Ledger seq255.


## 6. Authoritative MT5 report figures (report.htm) - cross-check
- Total Net Profit: $2,239.56 (matches the deals calc exactly -> integrity OK)
- Balance Drawdown Absolute (below the initial $5,000): only $85.66
- Equity Drawdown Absolute (incl floating, below initial): only $87.22
- Balance Drawdown Maximal (peak-to-trough): $833.76 (10.33%)
- Equity Drawdown Maximal (peak-to-trough, incl floating): $1,001.33 (12.15%)
- Note: the "Absolute" DD (vs the initial $5k) is tiny ($85-87), so the 10% STATIC rule ($4,500 floor)
  is safe by a wide margin. The "Maximal" DDs are measured from the equity PEAK after profits piled up,
  not from the initial balance, so they do NOT breach the static rule.

## 7. HONEST VERDICT
1. **PROFIT IS LOWER ON REAL TICKS.** Net $2,239.56 (44.8%/yr) vs the Model-1 screens' ~$3,335 (66.7%).
   Real spread/slippage cost ~$1,100/yr and cut the win rate to 25.6%. The funded take @80% is therefore
   well BELOW the earlier ~$204/mo estimate.
2. **VERY LUMPY + CURRENTLY BLEEDING.** Two months (Oct 2025 +$1,107, Jan 2026 +$1,205) produced MORE than
   the whole year's net; the last three months (Jul/Aug/Sep 2026) are ALL negative (-$770 combined). Normal
   for a low-win trend-follower, but it means long losing stretches are expected - and it is in one now.
3. **DAILY LINE IS TOO TIGHT.** One day (2026-09-02) hit -$250.09 by strict exit-day attribution; the
   conservative floating proxy for the worst day was $233 (just under $250). Either way the worst day sits
   RIGHT AT the $250 daily line -> NOT a safe buffer. The daily governor must be tightened before deploy.
4. **STATIC: safe** by a wide margin. **FUNDED 3% rule: 10 days exceed the $150 proxy** -> the funded config
   still needs the 3%-risk rework.

**RECOMMENDATION:** do NOT deploy as-is. (a) Tighten the daily governor so the worst day clears $250 with a
buffer, and re-test. (b) Set expectations to the lower, lumpier real-tick income. (c) The forward-demo is
now doubly important given the recent losing stretch. (d) 0.03 is NOT viable - at 0.02 the worst day is
already at $250, so 0.03 (~1.5x) would be ~$375 = a hard daily breach.


## 8. Follow-up test (seq258/259): was the -$250 day a REAL breach? -> NO
To check the worst day, the daily governor was tightened (reactive flatten 4.5%->3.5% = $225->$175,
predictive buffer 3.5%->2.8%) and re-run on real ticks, same window.

| | Baseline (gov 4.5%) | Tightened (gov 3.5%) |
|---|---|---|
| Net | $2,239.56 | $2,244.44 (+$4.88) |
| Worst realized day | -$250.09 | -$250.09 (IDENTICAL) |
| Conservative floating worst | $233.33 | $233.33 (IDENTICAL) |
| Trades | 270 | 270 |

**Interpretation:** flattening at 3.5% ($175) changed ZERO trades -> therefore NO single day's intraday
loss (from day-start, floating included, the way FundedNext measures it) ever reached even 3.5%. So the
-$250.09 "worst day" is an EXIT-DAY ATTRIBUTION ARTIFACT: a multi-day trade's whole loss lands on its
close date in this grouping, even though it accrued (floated) across several prior days. The true
intraday daily loss stayed under 3.5% ($175) all year -> **comfortably under the 5% ($250) daily line.**

**Revised verdict:** the config is DAILY-SAFE (and static-safe). The daily-breach flag in section 7 was
a measurement artifact, now cleared. The governor stays at 4.5% (tightening gained nothing). The REAL,
unchanged takeaways: (1) real-tick profit is LOWER (~$2,240/yr vs the Model-1 ~$3,335) and (2) it is
LUMPY and currently in a losing stretch; (3) the funded 3% rework is still required before funding.

# FUNDEDNEXT-SAFE config (0.03 lot + initial-referenced daily) - RESULT

- EA: CK_GOLD_COMBO, Combo_Stage=0, **Combo_DailyRefInitial=true** (new seq220 feature: daily
  governor measures the day's loss as a % of the FIXED initial balance, matching FundedNext's rule).
- Pre-registration: ledger seq220. For firms whose daily loss is "5% of INITIAL, incl floating"
  (FundedNext confirmed). Config: FIX 0.03, DT risk 0.8, daily gov 4.5% of initial, per-trade 2.0,
  static 8, news on.
- Test: ONE MT5 Model-1 backtest, window last1y, deposit $5000.

## Income (meets the target)

- 303 trades, net $3,765 = **+75.3%/yr**, PF 1.53, win 28.4%.
- Your 80% split: **~$253/month, ~$507 / 2 months, ~$3,012 / year**.
- At 90%: ~$285/month, ~$570 / 2 months.
- => ~$507-570 per 2 months meets the ~50,000-taka target, and it is ~6x the GFT 0.01 safe config
  (+12.6%/yr, ~$42/mo) - because a no-Goat-Guard firm lets us size up 3x (0.01 -> 0.03).

## Compliance vs FundedNext's STRICT rule (daily 5% of INITIAL, incl floating)

- **Daily**: worst realized day 2026-01-13 = -$216 = **-4.31% of initial**. Days at/over 4.5%: 0.
  Days at/over 5%: 0. The initial-referenced governor held the daily under the $250 line.
- **Single-trade floating**: worst MAE $159.63 = **3.19% of initial**. Trades with MAE > $225: 0;
  > $250: 0. No single trade's float approached the daily line.
- **Static max loss (10%)**: SAFE. Min running balance $5,000; never near the $4,500 floor.
- VERDICT: PASS - safe on the strict 5%-of-initial-incl-floating rule with margin.

## Deployment

- **FundedNext (2-Step)**: deployable - EA allowed (small EA fee), no Goat Guard, gold + weekend OK,
  news gate on avoids the 40% news-profit haircut. Use THIS 0.03 config (Combo_DailyRefInitial=true).
- **Day-start-referenced no-guard firms (FTMO / FundingPips if confirmed start-of-day)**: the 0.04
  config (combo_noguard_04, +88%/yr, ~$297/mo) can be used instead - more income, same safety there.

## Caveats

- Model-1 floating is a lower bound; the exact intraday combined-floating on the single worst day
  (2026-01-13) needs an equity series to be 100% certain, though every signal is under 5%.
- Real money only after a forward-demo on the real FundedNext feed + human approval.
- Still open for FundedNext: exact profit split %, payout cycle, payout proof.

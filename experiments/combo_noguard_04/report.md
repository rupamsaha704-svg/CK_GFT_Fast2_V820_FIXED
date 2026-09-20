# NO-GUARD 0.04 config (FTMO / FundedNext shape) - RESULT

- EA: CK_GOLD_COMBO, Combo_Stage=0 (no Goat-Guard flatten). No code change.
- Pre-registration: ledger seq218. For firms with NO floating-loss guard; binding limits = static
  max loss (~10%) + daily 5% (incl floating).
- Config: FIX_FixedLot 0.04, DT_RiskPercent 1.0, Combo_DailyLossPct 4.5 (equity governor),
  Combo_PerTradeMaxRiskPct 2.5, StaticDDStopPct 8, news gate on.
- Test: ONE MT5 Model-1 backtest, window last1y, deposit $5000.

## Income (this is the good part - meets the target)

- 305 trades, net $4,411 = **+88.2%/yr**, PF 1.44, win 28.9%.
- Your 80% split: **~$297/month, ~$593 / 2 months, ~$3,529 / year**.
- At 90% (FTMO scaling / 1-Step): ~$334/month, ~$667 / 2 months.
- => This MEETS the ~50,000-taka-per-2-months target.

## Compliance

- **Static max loss (10%)**: SAFE. Min equity $4,979 vs $4,500 floor; MT5 equity DD absolute only $20.
- **Daily 5% - THE DECIDING FACTOR, and it depends on the firm's reference basis**:
  - Measured against **DAY-START balance** (account grown to ~$8,700 by then): worst day 2026-01-13
    = **-3.30%** -> SAFE. 0 days >= 5%.
  - Measured against **INITIAL $5,000** (this is what FundedNext support stated): that same day was
    **-$287 = -5.74%** -> BREACH. Also the worst single-trade FLOATING excursion was **$250.50 =
    5.01% of initial** -> a single trade's float also crosses the 5%-of-initial line.
  - So: on a "5% of INITIAL, incl floating" daily rule (FundedNext), this 0.04 config BREACHES on 1
    day + 1 float. On a "5% of day-start" rule it is safe. FTMO's reference must be confirmed.

## Why (root cause)

The EA's daily governor references the DAY-START balance (correct for GFT). Once the account grows,
4.5% of a grown day-start ($391) is a bigger dollar loss than 5% of the fixed initial ($250) allows -
so a firm that fixes the daily limit to INITIAL is under-protected by the current governor.

## Verdict + fix

PROMISING - the income clears the target and static is safe. To be safe on the STRICT "5% of initial,
incl floating" rule, one of:
1. Add an INITIAL-referenced daily governor (flatten all at ~4% of initial = $200) - small EA change,
   makes it safe on both initial- and day-start-referenced firms; or
2. Trim size to ~0.03 lot so the worst day/float stays under $250 (income scales down ~25% but stays
   near target); or
3. Deploy as-is ONLY on a firm whose daily 5% is referenced to day-start balance (confirm FTMO).

Real money only after a forward-demo on the real feed (Model-1 floating is a lower bound; real ticks
can be worse). Next backtest: the initial-referenced-governor + 0.03 variant to get a "safe on the
strictest rule" number.

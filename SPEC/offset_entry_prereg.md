# Pullback-Offset Entry — PRE-REGISTRATION (frozen before results)

New strategy variant (NOT an edit of FIX09). Declared before testing, per Design v1.0/v1.1.

## Hypothesis (falsifiable)
On XAUUSD, market entries at the breakout/pullback signal are frequently stop-hunted: price wicks against
the position (hitting SL) before moving to TP. Entering on a small PULLBACK via a LIMIT order at a better
price should make that wick our fill (not our stop) and improve realised expectancy.

## Rule (frozen)
- Same FIX09 signal logic, fixed 0.09 lot, all FIX09 params.
- Instead of market entry: place a LIMIT order at an offset better price:
  - BUY  -> Buy Limit at (signal Ask - InpEntryOffset)
  - SELL -> Sell Limit at (signal Bid + InpEntryOffset)
- SL/TP kept at FIX09 STRUCTURAL levels (swing +/- ATR buffer; TP = RR from the market-signal price), so a
  better fill yields smaller risk / larger reward on the same structural targets.
- Pending cancelled if not filled within InpPendingBars bars (default 3). One order in flight at a time.
- **Primary declared offset = 4.0 price ($4.00 = "4 points / 40 pips").** This is the single confirmatory value.

## Anti-overfit conditions (locked)
- Offsets 5.0 / 6.0 etc. are EXPLORATORY ONLY (log-only). Picking the best in-sample offset = optimization
  = overfit; forbidden as a confirmatory claim.
- Judged by the deterministic pipeline: IS is not evidence; requires OOS + cross-window consistency
  (helps in BOTH 2022-25 AND 2025-26, not one), + forward/demo (v1.1). Counts as 1 Primary hypothesis.
- If it improves in-sample only, or flips sign across periods (like the regime gate), it is REJECTED.

## Status
PRE-REGISTERED. Next: implement CK_GOLD_PRO_OFFSET (frozen), backtest, then pipeline OOS+consistency.

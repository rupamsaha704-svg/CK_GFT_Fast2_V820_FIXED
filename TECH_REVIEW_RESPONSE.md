# Technical Review — Response & Corrected Positions (for review)

The reviewer's corrections are accepted. Each is technically correct; the wording below is
tightened to be verifiable and not overstated.

## 1. Order-result check (#2) — corrected wording
"Strategy Tester never rejects" was wrong. The Tester CAN fail a request (invalid stops,
invalid volume, insufficient margin) and these appear as trade return codes. `CTrade::Buy()`
returning true only means the request passed structural checks — execution is confirmed via
`ResultRetcode()` / `ResultDeal()`.
- **Verifiable claim:** *If the Tester Journal for the validated run shows no failed/rejected
  trades, then issue #2 did not affect that specific backtest result.* (Action: read the Journal.)
- Live fix required regardless: verify `ResultRetcode()` before `g_tradesToday++`.

## 2. Spread filter portability (#1) — must preserve ABSOLUTE price-spread
Do NOT just re-scale the raw point count. If the validated broker had 60 points = $0.60 on
2-digit gold, the 3-digit equivalent is ~600 points, not 60. Correct fix = compare the spread
in PRICE terms:  `spread_price = SymbolInfoInteger(SYMBOL_SPREAD) * _Point;`  reject if
`spread_price > InpMaxSpreadUSD` (e.g. 0.60). This preserves the validated logic across digits.

## 3. CPCV interpretation — corrected (not overstated)
Earlier "CPCV pass ⇒ edge is real" is too strong. Correct statement:
> CPCV results are **evidence for the strategy's robustness** (out-of-sample Sharpe held up,
> leak-free); they do **not** by themselves prove a persistent/live edge. Parameter selection,
> data leakage, transaction-cost assumptions and regime dependence can all survive CPCV.
> Equally, the "overfit/fake" accusation is not self-proven either.
Net: v23 has good robustness evidence + a modest measured edge, with regime dependence
(trend-only) demonstrated. Not a guarantee of future profit.

## 4. Two additional live-safety issues (accepted, real)
- **Daily-state persistence:** on EA restart / recompile / chart reload, `ResetDaily()` zeroes
  `g_tradesToday` and re-anchors day-start balance → daily trade/loss/profit limits can reset
  mid-day live. Fix: persist daily state (e.g., GlobalVariables keyed by date).
- **Magic-specific daily P/L:** `RealizedRToday()` uses whole-account balance change, so manual
  trades or other EAs on the same account pollute this EA's daily stops. Fix: compute realised
  P/L from this magic's own closed deals for the current day, not account balance.

## Agreed fix priority (LIVE robustness; strategy logic UNCHANGED)
1. Spread semantics (absolute price-spread, digit-independent)
2. Verified order result (`ResultRetcode`/`ResultDeal`) before counting a trade
3. `SetTypeFillingBySymbol(_Symbol)` for broker-correct filling
4. Sub-minimum lot → **skip** trade (don't floor to min = over-risk)
5. Daily-state persistence across restart/recompile
6. Magic-specific daily realised P/L

**Left untouched on purpose (strategy definition — changing them changes the validated result):**
MaxLot 0.09 cap (return plateaus by design), break-even at +1.5R (0.50 × RR3), ATR shift-0.

## Honest status of the deliverable (v23)
- Validated on real-tick XAUUSD, last 1 year: +115% (risk 0.5%) … +154% (1.7%) … +200% (2.0%),
  drawdown scaling with risk (~15% → ~20% → 16–29% Monte-Carlo tail).
- NOT overfit by CPCV (OOS Sharpe held); modest edge (Deflated Sharpe humble); **trend-regime
  specialist** (lost in 2015–2018 range years — regime dependence confirmed).
- Backtest ≠ live. The fixes above make live behaviour match the backtest more closely; a
  DEMO run on the actual live broker is the required next validation step before real capital.

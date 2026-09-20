# FUNDED AGGRESSIVE (0.04 lot + hard $90 float-flatten) - RESULT

- EA: CK_GOLD_COMBO, Combo_Stage=1 (funded). No code change - existing funded inputs only.
- Pre-registration: ledger seq216. Pass/fail bar: (1) no trade float/MAE > ~$95, (2) all hard rules
  compliant, (3) return > the 0.01 config's +12.6%.
- Config: FundedFixLot=0.04, FundedFloatFlatPct=1.8 ($90 hard combined-float flatten), FundedPerTradePct=1.8,
  FundedRiskPct=1.0, FundedMaxSLpts=22, UseNewsGate=true, FundedMaxOpenTotal=1.
- Test: ONE MT5 Model-1 backtest, window last1y, deposit $5000.

## The money (this part is great)

- 264 trades, net $3,105 = **+62.1%/yr** (PF 1.42). vs the safe 0.01 config's +12.6%.
- Your 80% split: **~$209/month, ~$418 per 2 months** - right around the target.

## The problem (this part is fatal)

- Worst REALIZED loss was only -$86 (the $90 flatten caps *closed* losses). That is a FALSE comfort.
- Goat Guard triggers on **FLOATING** loss, and the floating loss blew past $100 repeatedly:
  worst MAE (peak float on a single trade) = **$212.84**; **14 trades floated to/over $100**; 19 over $90.
- With FundedMaxOpenTotal=1, each such trade WAS the only open position, so each -$100 float = a Goat
  Guard trigger. First trigger cuts the split 80%->50%; the second **permanently closes the account**.
  14 triggers = the account is dead almost immediately.
- gft_compliance.py --stage funded verdict: **NOT CLEARED (LIKELY BREACH - BLOCKING)**.

## Why (the physics)

A software "$90 flatten" cannot stop a fast move or gap that jumps THROUGH $90 in one step. At 0.04 lot,
gold's normal adverse excursions ($30-53/oz on volatile trades) = $120-212 of float, well past the $100
Goat Guard. The stop-distance cap limits the *initial* stop, not the intra-hold spike.

## Verdict: REFUTED (matches the pre-registered honest prior)

Fails bar criteria (1) and (2). Do NOT deploy 0.04 lot on a $5k funded account - it breaches Goat Guard.

## The real math + the honest way forward

Goat Guard = 2% of the account's INITIAL size (fixed $100 on $5k). A single gold position must never float
past it. That hard-caps the lot:
- $5k: safe-max ~ **0.015-0.017 lot** (worst float ~$90) -> ~$60-70/month to you. Better than 0.01 ($42)
  but still modest. I can measure the exact safe-max in one more backtest.
- The ~50k-taka / 2-month (~$400-600) target is NOT safely reachable on $5k - the $100 Goat Guard forbids
  the size it needs.
- It IS reachable on a **bigger account**, because Goat Guard scales with size: $25k -> $500 GG -> ~0.075
  lot safe -> ~5x the $5k income; $50k -> $1000 GG -> ~0.15 lot -> ~$600/month. Same strategy, just scaled.

RECOMMENDATION: on $5k keep the validated safe funded config (or the tested safe-max ~0.015). To actually
hit the income target, use a larger GFT account where 0.04+ lot stays Goat-Guard-safe. Real money only after
a forward-demo on the real GFT feed confirms the float behaviour (Model-1 MAE is a lower bound; real ticks
can be worse).

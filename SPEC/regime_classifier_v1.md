# Regime Classifier v1 — PRE-REGISTRATION (frozen BEFORE any gating test)

Declared before implementation/testing, per DESIGN v1.0 §4. Once hash-locked in the ledger this is
FROZEN; changing it = versioned amendment + new trial. Purpose: label each decision bar as TREND vs
RANGE using ONLY information available at that bar (leakage-free), so a regime-gate can later be tested
on UNTOUCHED data. Goal is NOT to fit 2025-26; it is a fixed, causal, simple rule declared in advance.

## Inputs (all causal — value at bar t never revised later)
- Closed-bar data on the decision timeframe (M15) and HTF (H1). Only bars with index >= 1 (completed).
- No future candle/high/low, no future ATR, no repainting indicators, no future-smoothed states.

## Regime definition (fixed, pre-declared)
Compute at decision bar t (using completed bars only):
- `emaHTF = EMA(close, 200)` on H1
- `slope = emaHTF[t-1] - emaHTF[t-1-N]`, N = 20 H1 bars  (drift over ~20 bars)
- `atrHTF = ATR(14)` on H1 (completed)
- **TREND** iff `abs(slope) >= K * atrHTF`, else **RANGE**.
- Pre-declared K = **0.5** (single value, not optimised). Direction (up/down trend) = sign(slope).

## Anti-leakage rules (locked)
- Any scaler/threshold/normalizer, if ever introduced, is fit on TRAINING fold only; OOS/holdout are
  transform-only. (v1 uses a fixed K, so no fitting — trivially leakage-free.)
- Walk-forward retraining schedule: NONE for v1 (fixed rule). Any future adaptive version must pre-declare its schedule.

## How it will be USED (and how it will be judged) — declared now
- A regime-gate = "only take FIX-series entries when regime == TREND (matching direction)".
- REGIME-ONLY approval (per DESIGN v1.0 §4) requires, on UNTOUCHED/OOS data, that gating:
  1) improves expectancy vs ungated, 2) reduces DD / false trades, 3) repeats across multiple WF windows,
  4) has >=50 OOS trades in the TREND regime (<30 => INSUFFICIENT).
- The classifier is itself ONE trial in the DoF ledger; only ONE classifier per research cycle.

## Explicit non-goals
- Not tuned to 2025-26. K=0.5 and N=20 are declared, not searched.
- This does NOT modify FIX09 (frozen demo continues untouched). If gating proves out on untouched data,
  it becomes part of a NEW version (FIX10), which starts its own fresh independent forward test.

## Status
PRE-REGISTERED (this document). Next: implement a causal `regime.py` matching this spec exactly, then —
only on untouched/OOS data — test the gate. No FIX09 change; no in-sample tuning.

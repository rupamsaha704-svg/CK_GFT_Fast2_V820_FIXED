# QM/ICT XAUUSD Strategy — Complete Build Spec (for a FAITHFUL MT5 EA)

> This is the authoritative, consolidated specification of the user's actual QM/ICT setup, gathered
> from the user + the setup creator's confirmed answers (ledger seq 18, 24, 30). Build a NEW,
> faithful MQL5 EA from THIS document. Everything is tested on the **MT5 Strategy Tester only**
> (real ticks / Model 4). Python is for reading MT5 output only — never to simulate trades.
> Earlier Python-engine numbers (PF 1.33, ema_bias, plateau, minrr) are NON-AUTHORITATIVE — ignore.

## 0. Hard constraints (never violate)
- Symbol: **XAUUSD only**. Lot: **fixed 0.09** (hard cap; pin it).
- **MT5 Strategy Tester = the only trade simulator.** Pin EVERY input on every run (Guard #20).
- **Current regime (last ~11 months, 2025-10-01 → 2026-08-29) = PRIMARY judge of value;** older
  history is context only. A candidate must also hold across **both halves** of the current regime.
- Measure the edge at a **non-binding deposit (e.g. 50k)** because at $5k the 0.09-lot gold position
  needs ~$4,950 margin (near the whole account) and causes margin lockout — a real deployment
  fragility to report separately, NOT a way to judge the edge.
- No overfitting. Anything the creator did not fix is a **parameter/variant**, A/B-tested on
  out-of-sample data, never hand-picked. Log every choice to the ledger.

## 1. The setup — bearish (bullish is the exact mirror)
Ordered causal chain (each step uses only past/closed information — NO look-ahead):

```
1. ERL RAID   : price sweeps external liquidity (a prior significant HIGH for bear) — the "head"
                raids the left-shoulder / range high.
2. SMT        : divergence vs XAGUSD near the raid (XAU makes a higher high that XAG does NOT
                confirm) — see §5. Guarded by rolling correlation.
3. MSS        : a M15 Market-Structure-Shift DOWN — a candle whose BODY CLOSES below the most
                recent confirmed swing low, with meaningful displacement (see §3). NOT a wick.
4. IDM        : an inducement (a minor swing high) forms after the shift; it MUST have a key level
                above it. It must be CLEARED (price trades through it) on the retrace before POI.
5. POI/QM     : price returns UP into the QM / left-shoulder zone (the return/entry zone) — see §4.
6. CONFIRM    : at the POI, a lower-TF (M5) confirmation = "1 rejection" candle (see §6).
7. ENTRY      : SELL at the rejection LOW; SL = rejection HIGH (+ buffer). TP = opposite external
                liquidity (see §6/§7).
```
Bullish mirror: lower ERL sweep → bullish SMT → bullish MSS (body-close above swing high) → IDM low
→ IDM cleared → return DOWN into QM/POI → M5 bullish rejection → BUY at rejection HIGH, SL =
rejection LOW, TP = opposite (upper) external liquidity.

TF cascade: **H4 → H1 → M15 → M5.** H4/H1 give context/POI; M15 = structure (MSS/IDM/swings);
M5 = execution/confirmation.

## 2. LOCKED definitions (implement exactly — creator/analysis confirmed)
- **MSS = M15 body-close beyond the most recent CONFIRMED swing (low for bear / high for bull) +
  displacement.** A wick through the swing does NOT count.
- **Displacement = |close − open| / ATR(14) on M15.** Only count the MSS if this ≥ `disp` threshold.
- **Swing (pivot):** a confirmed swing needs `pivot` bars on each side (strictly higher high / lower
  low). A swing is only usable once its right-side `pivot` bars have closed (leak-free).
- **Head must raid the left shoulder:** for bear, the head (the high that gets swept) must be a
  HIGHER HIGH than the left-shoulder high (it raids that liquidity). Mirror for bull. Without this
  it is not a true Quasimodo.
- **Entry (creator-confirmed):** after the LTF structure shift, at the QM/POI wait for **1 rejection**
  candle, then **enter at the rejection's extreme** (bear: its LOW; bull: its HIGH) on the break, and
  **SL = the rejection's opposite extreme** (bear: its HIGH; bull: its LOW) + a small ATR buffer.
  (A direct/H1 entry has a larger SL — keep as a variant.)
- **IDM clear is MANDATORY** for the A+ variant (inducement must be taken before the POI return);
  keep an "IDM optional" experimental variant for A/B only.
- **Symbol XAUUSD, lot 0.09, NY session** (see §8).

## 3. PARAMETERS (creator did NOT fix these — expose as inputs, A/B test, do NOT hand-pick)
| input | default | notes |
|---|---|---|
| `pivot` (swing L/R) | 2 | structure sensitivity |
| `disp` (MSS displacement, body/ATR14) | 0.6 | test 0.6 / 0.8 / 1.0 |
| `atr_period` | 14 | ATR for displacement + SL buffer |
| `sl_buffer_atr` | 0.5 | buffer beyond the rejection extreme |
| `min_projected_rr` | 1.0 | reject setups with projected RR below this (test 1.0/1.5) |
| `erl_tf` | H1 | ERL/external-liquidity source timeframe (test H1/H4) |
| `erl_lookback` | 5 | swings defining the external range |
| `idm_clear_required` | true | A+ = true; experimental = false |
| `max_trades_per_day` | 2 | risk cap — NOTE: interacts with session-gating, see §8 warning |
| SMT on/off + `corr_window`/`corr_min` | on / 20 / 0.3 | see §5 |

## 4. POI / QM zone (creator: any high-accuracy key)
The POI is the **QM left-shoulder return zone**. The creator accepts several "key" types as the POI,
in priority order — use the TOP-MOST valid key:
1. QM left-shoulder swing zone (base), with confluence of **FVG** or **Order Block (OLC)**;
2. **Classic-V** or **Classic-A** structure key;
3. if no rejection forms at the primary QM, use the next higher Classic-A/V/OLC key.
Implement POI as a variant switch: `qm` (base), `qm_ob`, `qm_fvg` (confluence). Do not collapse to one.

## 5. SMT (XAUUSD vs XAGUSD)
- Bear SMT candidate: XAU makes a higher high near the raid but **XAGUSD fails to confirm** the
  corresponding high (mirror for bull with lows).
- **Rolling-correlation guard:** if XAU/XAG correlation over `corr_window` bars is too weak
  (< `corr_min`), SMT is INVALID → skip (do not force it).
- Needs the **XAGUSD** series available in the terminal, time-aligned to XAUUSD M15. If XAGUSD is
  absent, run SMT=off and say so honestly (do not fabricate).

## 6. Entry / confirmation / SL / TP (creator-confirmed)
- **Confirmation = "1 rejection" at the POI on M5** (a bar closing against the prior push at the POI).
- **Entry:** on the break of the rejection extreme — bear: SELL at rejection LOW; bull: BUY at
  rejection HIGH. If price never breaks the extreme within a horizon → NO TRADE (causal fill).
- **SL:** rejection HIGH + `sl_buffer_atr`×ATR (bear) / rejection LOW − buffer (bull).
- **TP:** the **opposite external liquidity** (bear → the lower external swing low; bull → upper),
  OR the opposite H1/H4 key level. Require **projected RR ≥ `min_projected_rr`** or NO TRADE.
  Keep TP-mode variants: `full_external` (base), `fixed_rr` — A/B only.

## 7. Discretionary layer (do NOT hard-code — optional flag only)
The creator says the **8:30 / 9:30 NY manipulation** read (and ASIAN/LONDON/BSL/SSL daily levels) is
**experience-based, differs every day, and cannot be written as a fixed rule.** Therefore implement
it (if at all) only as an OPTIONAL, off-by-default diagnostic tag — **never a hard entry gate.**

## 8. Session & timezone
- Session: **New York.** Default session gate = NY 09:30–16:00 (implement exactly as the intended
  clock; on this broker's data the raw server timestamp was treated as the session clock — verify on
  MT5, do not assume). Display any times to the user in **IST** (user is in India).
- 8:30 and 9:30 legs are examined but neither is hard-coded as "manipulation" vs "expansion".
- **WARNING (learned on MT5):** a session gate INTERACTS with `max_trades_per_day` — restricting
  hours frees the daily cap and can let MORE (often worse) trades in. So a session filter that looks
  good on a CSV can REVERSE on a real MT5 run. Always judge session/any filter by a **real MT5 run**,
  not by filtering a CSV. (This exact trap already produced a phantom edge once.)

## 9. Build & test protocol (Windows Kiro)
1. Build a NEW faithful `.mq5` from this spec (do not reuse the old simplified `CK_QM_ICT_EA`). It
   must evaluate the full chain causally, allow the setup to fire as often as the structure genuinely
   occurs (do not artificially throttle to one setup), and dump trades via `OnTester` as
   `time,profit` (so walk-forward/date analysis works).
2. Compile via MetaEditor; stop loudly on any error.
3. Pin EVERY input in `[TesterInputs]` (Guard #20). Deposit 50k (edge), also note the $5k margin wall.
4. Run on MT5 real ticks: IS vs OOS, **current-regime primary window + both halves**, walk-forward,
   cost/slippage stress. Judge with the deterministic pipeline. A/B every parameter/variant.
5. Verdict rules: consistent across both halves AND no severe IS→OOS collapse AND edge survives
   realistic cost AND not concentrated in a few trades. Otherwise REJECT/FAIL honestly.
6. Log every run to the hash-chained ledger. Never touch real money without explicit human approval.

## 10. Honest expectation
This setup is genuinely worth a faithful test — it was never fairly implemented before (the old EA
was a simplified WIP). But be honest: even a faithful build may land borderline. Report the true MT5
result either way — a clean "no robust edge" is a valid, valuable answer; a fabricated edge is not.

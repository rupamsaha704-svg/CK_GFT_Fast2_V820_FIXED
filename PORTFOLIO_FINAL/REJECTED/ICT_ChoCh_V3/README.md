# ICT CHoCH + Fibonacci OTE (CK_XAU_ICT_ChoCh_V1/V2/V3) — REJECTED

**What it is:** H1 Change-of-Character (CHoCH) sets directional bias → price retraces to the
H1 POI (order block) → M15 Break-of-Structure (BOS) confirms → entry on M5 in the Fibonacci
**OTE zone (0.618–0.786)** with a confirmation candle. Prop-firm risk rules (risk %, 4% daily
loss, 13% static-DD halt, one position, TP1 2R + break-even, TP2 3R). Built from a full Kiro
spec (`.kiro/specs/ict-choch-fib-ea/` on branch `feature/ict-choch-fib-v1`). Intended target:
GoatFundedTrader 5K 2-step, $5,000 → $15,000.

## How it was tested (MT5 = truth)
MT5 Strategy Tester, **real ticks (Model 4)**, XAUUSD **M5**, current regime
**2025-10-01 → 2026-08-29**, deposit **$5,000**, all 30 inputs pinned (GUARD #20). Two honest
configurations:

| Config | Trades | Net | PF | Win% | MaxDD | Verdict |
|---|---|---|---|---|---|---|
| **A — as-shipped** (relaxed confirm, $1.5 OTE proximity, risk 1.5%, 5 tr/day, timeout 48h, M15 swing 1) | 25 | **−$211 (−4.2%)** | **0.72** | 32% | 7.7% | LOSES |
| **B — spec-faithful** (strict engulfing/pin *inside* OTE, risk 1%, 3 tr/day, timeout 12h, SL $5–15, OTE $2–15) | 12 | **+$0.15 (~0%)** | **1.00** | 42% | 4.9% | break-even, INSUFFICIENT |

## Why REJECT
- The **as-shipped "relaxed / more-trades" config LOSES** (PF 0.72). The relaxations added to
  raise trade count — entering up to **$1.5 OUTSIDE the OTE zone**, same-zone re-entry after a
  loss, looser guards — **degraded entry quality**. More trades, worse result.
- The **spec-faithful config is exactly break-even** (PF 1.00) and fires only **12 times in 11
  months** — far too few to certify an edge, and nowhere near what a $5k→$15k/6-month challenge
  needs.
- Turning inputs until a config goes green = **overfitting** (forbidden by our discipline).
  Neither honest config shows a durable edge → REJECT.

## Important: the decode was checked — this is NOT a coding bug
An audit confirmed the EA is **causal and free of look-ahead / repaint** (it reads only closed
bars `[1]` and gates once per closed bar). So the REJECT is about the **strategy's edge in this
regime**, not a decode mistake. (One real logic bug was found for the record — a same-direction
CHoCH re-fires every H1 bar and resets the setup timer — but fixing it would not change the
verdict: the setup is simply too rare with no positive expectancy.)

## Bigger pattern
Gold mechanical ICT / trend setups have failed out-of-sample **repeatedly** here:
`CK_GFT_Fast_v17`, `CK_GOLD_PRO_FIX09`, `QM/ICT`, `QT/CRT`, and now **ChoCh**. In the current
regime XAUUSD is choppy / efficient for these mechanical patterns.

## Evidence in this folder
- `CK_XAU_ICT_ChoCh_V3.mq5` — the audited EA (with an analysis-only `OnTester` trade-dump added).
- `relaxed_report.md`, `strict_report.md` — MT5 metrics per config.
- `relaxed_preset.json`, `strict_preset.json` — exact pinned inputs + window.
- Ledger: `SPEC/dof_ledger.jsonl` **seq 141** (hash-chained). Full spec on `feature/ict-choch-fib-v1`.

_Not financial advice. Backtest ≠ live._

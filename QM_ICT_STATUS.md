# QM/ICT Setup — Honest Status & Findings

**Symbol:** XAUUSD only · **Lot:** fixed 0.09 · **Data:** real MT5 ticks/bars, 2022-06 → 2026-08
**Evaluation principle (locked):** the market regime shifted ~Oct 2025; the **current regime
(last ~11 months, 2025-10 → 2026-08)** is the PRIMARY judge of value. Older history is context
only. In-sample is never self-evidence; nothing is "certified" without out-of-sample / forward
evidence. Overfitting is forbidden. (Ledger seq53; DESIGN_v1.1 amendment.)

---

## 1. What this setup is

A discretionary **Quasimodo / ICT liquidity-reversal** model decoded from the setup creator
(Instagram) + the user's own knowledge:

```
ERL raid (external liquidity sweep) -> SMT (vs XAGUSD) -> M15 MSS (body-close + displacement)
-> IDM (inducement) formed -> IDM cleared -> price returns to QM/POI (left-shoulder zone)
-> lower-TF (M5) confirmation -> ENTRY ; SL beyond the head ; TP = opposite external liquidity.
TF cascade H4 -> H1 -> M15 -> M5. Sessions: New York (08:30 / 09:30 legs noted, not hard-coded).
```

## 2. What was built (deterministic, reusable, on GitHub)

- A full **Python variant engine** for the setup: `v1_lab/qm_state_machine.py` (+ `qm_detect.py`,
  `erl_detect.py`, `idm_detect.py`, `poi_zone.py`, `smt_detect.py`, `ny_session.py`), each with a
  synthetic self-check, deterministic and causal (no look-ahead).
- A **variant grid runner** `v1_lab/variant_runner.py` (31 variants) feeding the UNMODIFIED
  deterministic verdict pipeline `v1_lab/pipeline.py` (MIN_OOS_TRADES=200, M1_MIN_PF=1.20, etc.).
- Every unconfirmed rule is a tunable switch, A/B-screened on out-of-sample data — never a
  hand-picked "best". A hash-chained ledger (`SPEC/dof_ledger.py`, 55+ records, integrity OK)
  records every analytical choice for multiple-testing honesty.

## 3. Honest results

### 3a. Full 4-year out-of-sample (context)
25→31 variants, a-priori split 2024-07-01. **0 variants PASSED** all mandatory OOS gates.
Most are INSUFFICIENT (the setup is selective → <200 OOS trades). This is the honest expected
outcome — not a certified edge on long history.

### 3b. Current regime (2025-10 → 2026-08) — the PRIMARY judge — via the faithful Python engine
| config | trades | PF | expectancy | max-DD |
|---|---|---|---|---|
| **baseline (QM, no EMA filter)** | **121** | **1.33** | **+$20.4** | **14.3%** |
| ema_bias EMA200 | 31 | 1.07 | +$4.7 | 10.0% |
| ema_bias EMA250 | 36 | 1.33 | +$20.0 | 9.1% |
| ema_bias EMA150 | 29 | 1.18 | +$12.0 | 9.1% |

**Key honest reads:**
- The **baseline QM model is positive in the current regime** with a decent 11-month sample
  (121 trades, PF 1.33, DD 14.3%). This is the most promising, honest signal we have.
- The **EMA trend-bias filter does NOT help in the current regime** — it only improved the
  *older* data (PF 1.73 on the 2024-07 split came from pre-Oct-2025 bars). Per the regime
  principle it is **dropped**.
- The creator's **rejection-entry** rule (enter at rejection low, SL = rejection high) was tested
  and is **harmful** (OOS PF ~1.05, drawdown ~60%) — the tight stop kills winners. Dropped.
- **SMT vs XAGUSD** makes the setup far too selective (24-36 trades / 4yr) to validate. Optional.

### 3c. Monte-Carlo / walk-forward / concentration
The pipeline's advisory stages ran on the variant grid; nothing reached a PASS on long history.
The current-regime baseline is promising but is **not** a full pipeline certification (it is one
window, ~11 months). Certification still requires forward / locked-unseen evidence.

## 4. Live MQL5 EA status — NOT yet trustworthy

`CK_QM_ICT_EA.mq5` was built to run a forward demo. **Honest status: it does NOT faithfully
reproduce the Python engine and must not be trusted or traded yet.**
- On the current regime the EA produces **~14 trades, PF ~0.4** vs the engine's **121 trades,
  PF 1.33** — a ~9x under-firing and a losing result.
- Root cause: the EA is an over-simplified *online* re-implementation — it tracks a single setup /
  single position at a time and uses simplified POI/IDM/target definitions, whereas the engine
  evaluates every MSS shift with exact structure/target logic. Closing this gap is a substantial
  **rewrite** (multi-setup evaluation + exact POI/IDM/target/entry port), which could not be
  reliably completed and verified in the current remote setup (no local MQL5 compiler).
- The EA's loss is therefore an **implementation artifact, not the strategy's truth**.

## 5. Honest conclusion & remaining work

- **Promising, not proven.** The validated Python engine shows a positive current-regime baseline
  (PF 1.33). That is a genuine, honestly-measured signal — but one 11-month window is not a
  certification.
- **Remaining, in order:** (1) a faithful MQL5 port of the baseline engine (multi-setup + exact
  logic), verified against the engine's trade list; (2) a frozen **forward demo** in the current
  regime to gather live, unseen evidence; (3) only then, with the deterministic pipeline + forward
  evidence agreeing, consider anything beyond demo. Money is risked only after demo proof + human
  approval.
- **No result here was tuned, fabricated, or overfit.** Where there is no proven edge, this file
  says so plainly.

*Artifacts: `v1_lab/qm_state_machine.py`, `v1_lab/variant_runner.py`, `v1_lab/VARIANT_REPORT_REAL.md`,
`v1_lab/ema_plateau.py`, `CK_QM_ICT_EA.mq5` (WIP), `SPEC/dof_ledger.jsonl`. Branch:
`kiro/validation-toolkit`.*

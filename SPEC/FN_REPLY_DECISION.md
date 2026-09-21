# FundedNext Trading-Ethics Reply — Decision Framework

Status: **RESOLVED 2026-09-21** — FN support agent **Allen** replied. Interpretation
maps to matrix row **"Ambiguous / referral to formal review"** with a strengthening:
Allen explicitly pointed at the restricted-strategies list, and that list explicitly
prohibits mirrored / opposite positions across accounts (Article 8020351). Therefore
**Plan Z′ is BLOCKED** and the deployment default is **Plan C** unless the user
prefers Plan Q. Steering §11 records the outcome; ledger seq275 is the hash-chained
record. The doc below is preserved as historical decision-framework evidence.

---

Purpose of this doc: pre-decided what to do for EVERY plausible reply, so the moment the
user forwarded the email response, deployment started in one turn — no re-analysis, no
re-computing numbers.

## 1. What we asked

Paraphrased from the email drafted on 2026-09-21 (steering §6, §7 context; Article 8020351):

- **Q1.** Two SEPARATE, INDEPENDENTLY-signaled strategies (combo EA and QM signal-player)
  running on two FundedNext accounts under one profile, where at some moments they happen
  to hold opposite positions on XAUUSD — is that a violation of the "mirrored / opposite
  positions across accounts" rule, or is that rule aimed only at intentional hedging?
- **Q2.** Does "identical trades across accounts is not allowed" (from the general rules
  page) cover same-symbol-same-direction-different-EA trades that coincidentally align, or
  is it about running the exact same EA / parameters on two accounts?
- **Q3.** How do you MEASURE mirror/hedge — by open-position snapshot at the same
  timestamp, by entry-time overlap window, by intent, or by realized correlation across a
  period?
- **Q4.** If our specific setup would qualify as a violation, what is the enforcement path
  — automatic account termination, warning + review, or payout-time deduction? And does
  the answer change between Eval and Funded stages?

Kept the tone factual and specific, referenced the exact article numbers, no ask for
relaxation of any rule. Ready for the reply.

## 2. The three plans on the table

Numbers are from MT5 real-tick (Model 4) runs on the reference window
(2025-08-01 → 2026-07-28) at the FundedNext Stellar 2-Step **$6,000** basis. Steering
§5 pins these as truth — no Python-only claim survives.

### Plan Q — QM erl_h4 + dedupe SIGNAL-PLAYER, solo

- EA: `CK_QM_SignalPlayer.mq5` reading `_signals_erl_h4.csv` (105 signals).
- Sizing: **$75 / trade** (funded-stage safe risk — combined with 1 concurrent max stays
  under the $180 3%-risk line with $30 buffer).
- MT5 real-tick result at reference risk ($85, one step riskier): net **+$2,296 =
  +38.27%/yr**, PF 1.49, 88 deals from 105 signals, min bal $5,674, 1 daily-line touch
  (2026-03-23 = -$314.66) that the governor caught.
- Scaled to safe $75 risk: net ≈ **+$2,061 = +34.4%/yr**, worst day est -$278 (safe).
- Funded take-home: **~$132/mo take-80 minus $5 EA fee ≈ ₹15,200/mo** (₹17,200 at the
  scale-up 90% split).
- **Live-ready state:** signal-player EA compiles clean; requires periodic Python
  regeneration of `_signals_erl_h4.csv` before the historical window boundary is hit.
  VPS also needs Python 3.14 + the analyzer scripts. More moving parts than combo.
- **Native rewrite** (`CK_QM_NATIVE_v1.mq5`): Block 1 done. Blocks 2–7 = ~22h to
  replace signal-player entirely; not required for a solo Plan Q launch, but nice to
  have.

### Plan C — Combo (FIX09 + DTChop) $0.02 lot, solo

- EA: `CK_GOLD_COMBO.mq5` + `experiments/combo_fnext_03/CK_GOLD_COMBO_FundedNext.set`.
- Sizing: **FIX 0.02 lot** (the $6k-safe ceiling; 0.03 breaches the 5% daily on real
  ticks) + DTChop swing sleeve. `Combo_Stage=0` for Eval; funded-stage needs a
  3%-risk rework per steering §6.
- MT5 real-tick result (`JOURNAL_FundedNext.md`, ledger seq255): 270 trades / +$2,240
  on $5k basis / PF 1.35 / win 25.6% / 1 daily-line touch handled by governor. On $6k
  basis same-lot ≈ **+37.3%/yr**.
- Funded take-home (with the required 3%-risk rework, -~20% haircut): **~$139/mo
  take-80 minus $5 EA fee ≈ ₹15,900/mo**.
- **Live-ready state:** completely prepared today. Install script, VPS guide,
  daily/weekly checklist, forward-demo protocol — all in
  `experiments/combo_fnext_03/`. Zero extra work to launch.

### Plan Z′ — Two accounts, combo on A + QM signal-player on B

- Naive additive: combo A + QM B ≈ **$287/mo take-80 ≈ ₹33,000/mo** (~₹37,300 at 90%).
- Hits the user's ~₹30k target that Q or C solo cannot.
- **Requires FN to say Article 8020351 does NOT apply to independently-signaled
  strategies with coincidental opposite positions.** Statistical evidence
  (`_verify_strategy_independence.py`): 0 same-direction and 0 opposite-direction
  entries within ±30 minutes; 4 suspicious same-day pairs out of 391 (1%); 27.2%
  time-bucket overlap. BORDERLINE by any letter-of-the-rule read — needs FN's
  written interpretation.
- **Live-ready state:** combo side is ready; QM side needs a mirrored deploy kit
  (install / VPS / checklist for the signal-player), ~2–3h of work. Not built yet
  precisely because this plan is contingent.

## 3. Decision matrix — parse the FN reply, pick the plan

Read the reply and identify which pattern it matches. The winning plan is the
right-hand column.

| FN reply pattern | Q1 | Q2 | Q3 | Q4 | Plan |
|---|---|---|---|---|---|
| **Explicit green-light** — "independently-signaled strategies with coincidental opposite positions are NOT a violation" | NO | narrow | intent / correlation over period | N/A | **Z′** |
| **Same-direction ok, opposite forbidden** — "any opposite position across accounts is prohibited regardless of intent" | YES on opposite | narrow | snapshot / entry-window | account termination | **C** (Z′ blocked by opposite-side risk) |
| **All same-symbol multi-account forbidden** — "no XAUUSD across multiple accounts under one profile, period" | YES both directions | broad | snapshot | account termination | **C** (single account, single EA) |
| **Ambiguous / referral to formal review** — "we review case-by-case, no blanket answer" | — | — | — | — | **C** (deploy now, iterate later — cannot start on ambiguity) |
| **Warning-then-review, not instant-kill** — "first coincidence = warning, second = review" | YES softly | broad | snapshot | warning → review | **Z′ tentatively**, with a monitoring rule to close one side if warned |
| **Payout-time deduction only, not termination** | YES | — | — | payout-time only | **Z′** — worst case is a haircut on winnings, not a dead account. Acceptable. |
| **No reply within 5 business days** | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | **C** — cannot risk the account on an unwritten interpretation |

Notes:
- **When in doubt, default to Plan C.** It is fully prepped, MT5-verified, and safe on
  every plausible rule reading. Losing ₹17k/mo of upside is far better than losing the
  account.
- Plan Q solo is a rounding error over Plan C in take-home (₹15.2k vs ₹15.9k) and adds
  operational complexity. It only wins if the user specifically prefers the QM setup
  for reasons outside pure income (e.g. wanting to run the winner strategy standalone,
  or to build ops experience for the native-rewrite hand-off). Otherwise skip.

## 4. Deployment sequence per plan

### If Plan C — start today

1. User buys FundedNext Stellar 2-Step **$6,000** in the client area.
2. On the VPS (or dev PC for smoke test), run
   `experiments\combo_fnext_03\install_combo_fnext.ps1`.
3. Follow `experiments\combo_fnext_03\FORWARD_DEMO.md` steps A.1 – A.7 (attach, load
   preset, verify inputs, enable Algo Trading).
4. Start the DAILY checklist from `experiments\combo_fnext_03\DEPLOY_CHECKLIST.md`.
5. 2-week forward-demo window; user forwards deals CSV + dashboard screenshot at day 14.
6. Kiro re-runs compliance + edge-check against MT5 backtest. Green-light or diagnose.

Everything above is documented in the four docs already committed (task #3).

### If Plan Q — need ~2–3h of prep first

1. Build `experiments/qm_erl_h4/` folder mirroring `experiments/combo_fnext_03/`:
   - `install_qm_signalplayer.ps1` — copies `CK_QM_SignalPlayer.mq5` to `MQL5\Experts`,
     copies `_signals_erl_h4.csv` (or `.txt`) to `MQL5\Common\Files`, compiles.
   - `QM_VPS_SETUP.md` — same VPS choices as combo, PLUS: Python 3.14 install,
     `_multi_tf_test.py` + `_export_signals_for_mt5.py` on the VPS, scheduled weekly
     signal-refresh task.
   - `QM_FORWARD_DEMO.md` — same pass/fail bar as combo (0 daily / 0 static / edge
     intact), but tuned to QM's expectations (win-rate ~22.7%, PF 1.49, 88 deals /
     11.8mo pace).
   - `QM_DEPLOY_CHECKLIST.md` — daily/weekly checks including signal-file freshness.
2. Repeat steps 1–6 from Plan C but with the QM kit.

### If Plan Z′ — need Plan Q prep PLUS a portfolio protocol

1. Do the Plan Q prep above.
2. Add `experiments/portfolio_z_prime/PROTOCOL.md`:
   - Two separate FundedNext accounts under one profile.
   - Account A runs combo. Account B runs QM signal-player.
   - Hard rule: NEVER run identical EA / parameters on both. Zero same-config overlap.
   - Daily monitoring: check the FN dashboard on both accounts for any rule flag,
     warning email, or "under review" notification. If FN flags one account, close
     matching positions on the other IMMEDIATELY and message back.
   - Payout timing: stagger so that scale-up ladders build on ONE account first
     (steering §7 — cannot exceed sub-$50k on any single account).
3. Steps 3–6 same as Plan C but done in parallel on both accounts.

## 5. Prep status audit — what exists, what does not

| Artifact | Plan C | Plan Q | Plan Z′ |
|---|---|---|---|
| EA compiled clean | ✓ CK_GOLD_COMBO.mq5 | ✓ CK_QM_SignalPlayer.mq5 | uses both |
| Ship-ready `.set` / signal file | ✓ CK_GOLD_COMBO_FundedNext.set | ✓ _signals_erl_h4.csv/.txt | uses both |
| Install script | ✓ install_combo_fnext.ps1 | ✗ **needs building** | ✗ needs both |
| VPS setup guide | ✓ VPS_SETUP.md | ✗ **needs building** | ✗ needs portfolio VPS protocol |
| Forward-demo protocol | ✓ FORWARD_DEMO.md | ✗ **needs building** | ✗ needs portfolio protocol |
| Daily / weekly checklist | ✓ DEPLOY_CHECKLIST.md | ✗ **needs building** | ✗ needs portfolio checklist |
| MT5-real-tick evidence | ✓ ledger seq255 / JOURNAL_FundedNext.md | ✓ ledger seq270 / steering §5a | derived from both |
| Rule-independence evidence | N/A single account | N/A single account | ✓ _verify_strategy_independence.py (BORDERLINE — needs FN written answer) |

Interpretation: Plan C can launch **the same day the FN reply lands** (assuming green
for Plan C, which it is under every scenario). Plans Q and Z′ need ~2–3h and ~4–5h of
prep respectively — do that work AFTER the reply narrows the choice, not before.

## 6. On the QM native rewrite (SPEC/QM_MQL5_REWRITE_PLAN.md)

Independent of the FN reply. Block 1 is committed. Blocks 2–7 are ~22h of work.
When to schedule:

- **If Plan C wins:** the native rewrite becomes optional — combo is already the
  live engine. QM native is a research parallel to keep the door open. Low priority.
- **If Plan Q or Z′ wins:** the native rewrite goes from optional to strategic.
  Signal-player is fine for month one, but a single-binary QM engine is much easier
  to operate long-term on the VPS. Bump to normal priority.

Either way, the rewrite plan is the same — Block 2 next, one block per session.

## 7. Kill-switch conditions (any plan)

Regardless of which plan wins, these override:

- **Any hard-rule breach** (5% daily, 10% static, 3% funded risk) → account is dead,
  post-mortem in the ledger, no re-attempt on that account.
- **FN warning / notification** while running Plan Z′ → immediately close matching
  positions on the paired account and pause new entries pending FN clarification.
- **FN pattern that suggests our reading was wrong** (e.g. a Trading Ethics update
  clarifying multi-account rules more tightly) → switch to Plan C on the next
  weekend, do not wait for a breach.
- **User's own judgement call** — Bengali overrides English overrides steering
  overrides this doc. The user is the pilot.

## 8. Ready state

- Waiting on: FN Trading Ethics reply.
- On reply arrival: parse against §3, pick a plan, execute §4.
- If reply takes > 5 business days: default to Plan C and note that the ambiguity
  cost us ₹17k/mo of potential upside; revisit if / when FN eventually replies.

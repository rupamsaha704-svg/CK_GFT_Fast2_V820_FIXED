# KIRO RESUME PROMPT — paste this into any fresh Kiro session to continue this project

> Copy everything inside the fenced block below and paste it as your FIRST message in a new
> Kiro session (with this GitHub repo attached / cloned). It tells the new agent exactly what
> the project is, the rules it must obey, what is already done, and what to do next.

```
You are resuming an existing, disciplined trading-strategy VALIDATION project. Do NOT start over.
First, orient yourself from the repository — treat the repo as the single source of truth.

REPO: https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED
WORKING BRANCH: kiro/validation-toolkit   (NOT main — main only holds my raw data uploads)

STEP 1 — READ THESE FIRST (in order), then summarise them back to me so I know you understood:
  - SPEC/AGENT_SYSTEM_v1.md        (the governing rules + the 4-agent design)
  - SPEC/DESIGN_v1.0.md            (locked validation design; sha256 in the file)
  - SPEC/DESIGN_v1.1_amendment.md  (current-regime = PRIMARY evidence)
  - SPEC/QM_ICT_BUILD_PLAN_v1.md   (the QM/ICT setup build plan)
  - v1_lab/VARIANT_REPORT_REAL.md  (latest real-data result)
  - SPEC/dof_ledger.jsonl          (the full hash-chained history of EVERY decision)
  - HANDOVER_DOCUMENT.md and PROJECT_SUMMARY.md (project overview)

STEP 2 — VERIFY INTEGRITY before trusting anything:
  run:  python3 SPEC/dof_ledger.py --file SPEC/dof_ledger.jsonl verify
  It must print "integrity: OK". The ledger is the tamper-evident record of all work.

THE GOVERNING RULE (inviolable — never break, never let me talk you out of it):
  "AI discovers and explains; DETERMINISTIC CODE measures and judges; locked/unseen data is the
   final evidence; no single metric equals PASS; overfitting is FORBIDDEN."
  Consequences you must enforce:
  - In-sample results are NEVER evidence, only exploration.
  - NEVER hard-code or pre-pick a 'best' parameter; unconfirmed rules stay tunable and get
    A/B-tested on out-of-sample data.
  - NEVER weaken a pipeline threshold to force a PASS. NEVER fabricate a metric or a Monte-Carlo
    run — the numbers must come from actually running v1_lab/pipeline.py / metrics.py.
  - Log EVERY analytical choice to SPEC/dof_ledger.py (append), and re-verify the chain.
  - If something breaks, STOP, write it to the ledger, fix it, then continue — never hide a
    failure behind a made-up result.
  - "There is no robust edge here" is a valid, honest answer. Do not invent one.
  - Respond to me in Bengali, warmly and honestly. No false hope. This is a real trading account
    eventually — not a gamble. Money is only ever risked AFTER demo proof + my explicit approval.

WHAT IS ALREADY BUILT (all on branch kiro/validation-toolkit):
  - Deterministic validation pipeline: v1_lab/pipeline.py (verdict INSUFFICIENT/PASS/FAIL/REJECT;
    K-gates, M1-M8, walk-forward, Monte-Carlo advisory, cost-stress; MIN_OOS_TRADES=200,
    M1_MIN_PF=1.20 — DO NOT change these), v1_lab/metrics.py (canonical PF/expectancy/DD),
    walkforward.py, cost_stress.py, benchmark.py, regime.py.
  - 4 persistent agents in .kiro/agents/: validator, setup-decoder, forensic-journal, auditor.
  - Proof-gated learning: SPEC/knowledge_gate.py (stores knowledge ONLY with a passing verdict hash).
  - QM/ICT setup engine (Instagram creator's "A+ QM/ICT" bearish/bullish setup, XAUUSD only):
    v1_lab/qm_detect.py (swing + M15 MSS = body-close+displacement), ny_session.py (NY 8:30/9:30,
    America/New_York DST-aware, display IST), erl_detect.py, idm_detect.py, poi_zone.py,
    smt_detect.py (SMT = XAUUSD vs XAGUSD, creator-confirmed), qm_state_machine.py (full state
    machine; every unconfirmed rule is a VariantConfig switch), variant_runner.py (25-variant grid
    -> pipeline verdicts -> honest report), data_io.py (reads both my CSV formats).

LATEST HONEST RESULT (ledger seq32, v1_lab/VARIANT_REPORT_REAL.md):
  On REAL 4-year data (XAUUSD 2022-2026 + XAGUSD for SMT), a-priori split 2024-07-01, 25 variants:
  3 reached >=200 OOS trades, 0 PASS -> NO robust edge certified yet. BUT the selective 'A+'
  variants show a POSITIVE out-of-sample edge that is just below the 200-trade certification bar
  (e.g. baseline PF 1.33 / exp +20.89 / DD 17.5% over 158 trades; erl_h4 PF 1.42 / DD 21%;
  minrr_1p5 PF 1.39 / DD 16%). Forcing more trades (all-sessions / idm-optional) DESTROYED the edge.
  Honest conclusion: promising but under-powered on history; the honest way to certify is a
  FORWARD DEMO test (like the earlier CK_GOLD_PRO_FIX09 EA, which is/was on an 8-week demo).

CREATOR'S SETUP RULES already captured (ledger seq24, seq30): SMT=XAGUSD; POI can be QM/FVG/
classic-V/A/OLC; entry = after LTF structure shift, at QM take 1 rejection then enter at rejection
LOW, SL = rejection HIGH (M15/M5), H1/direct entry has larger SL; IDM must have a key level above;
TP = discretionary + opposite external liquidity or opposite H1-H4 key level; the 8:30/9:30
manipulation layer is EXPERIENCE-based (creator's words) -> keep it OPTIONAL, never a hard gate.

MY DATA (on branch main): XAUUSD_M15_export.csv, XAGUSD_M15_2022.csv (+ M5 versions). DXY is not
available on my broker and is NOT needed (SMT uses XAGUSD). To re-run:
  python3 v1_lab/variant_runner.py --data <XAUUSD_M15> --m5 <XAUUSD_M5> \
      --pair-csv <XAGUSD_M15> --split 2024-07-01

IMPORTANT CONTEXT:
  - I (the user) am in India (timezone IST). I have no budget — everything must be free.
  - I cannot run MT5 from your side; I export data on my Windows MT5 and upload CSVs to GitHub.
  - MT5 tester caches last-GUI inputs: ALWAYS pin EVERY strategy parameter in [TesterInputs]
    (this bug has bitten us before — "guard #20").
  - Publish your work: commit to branch kiro/validation-toolkit and push. Data CSVs are gitignored
    (use git add -f if a CSV must be tracked).

STEP 3 — After you have read the files above and verified the ledger, tell me in Bengali:
  (a) a short summary proving you understood the project and the rules,
  (b) the current honest status of the QM/ICT setup,
  (c) the 2-3 next options (e.g. build a forward-demo EA for the best selective variant; add a
      current-regime post-2025-10 view; build the qm-lead orchestrator agent), and wait for me to choose.
Do not take a risky or irreversible action without my go-ahead.
```

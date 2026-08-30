# SESSION EXPORT — CK_GFT Gold EA family + Anti-Overfit Validation Toolkit

> **Purpose of this file:** Complete, honest recovery record of one Kiro (Vibe-mode) session.
> Written because the user's free AWS quota is ending and all sessions are being consolidated
> into `github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED`. A future agent with **no access
> to the original chat** should be able to fully understand and continue the work from this file.
>
> **Honesty note:** Where a number came from the *user's* MT5 screenshots or their local machine
> logs (not independently reproduced by this agent), it is explicitly labelled as such. Where
> something is uncertain, it says so. Nothing here is fabricated.
>
> - Repo: `rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED`
> - Branch this file is written to: `kiro/validation-toolkit`
> - Export written: 2026-08-11 (session date), by Kiro (Claude Opus 4.8), Vibe mode.
> - Sandbox repo path used: `/projects/sandbox/CK_GFT_Fast2_V820_FIXED` (+ worktree `/projects/sandbox/vtk`).

---

## 1. PURPOSE (what this session was about)

Two intertwined tracks for a **Bengali-speaking retail algo trader**:

### Track A — MT5 Expert Advisor development (XAUUSD / gold, M5 timeframe)
Build and iteratively modify a family of MetaTrader 5 Expert Advisors (`.mq5`) that trade **spot
gold (XAUUSD) on the M5 chart**. The user drives every change with exact instructions and wants
**raw GitHub links** to copy each finished `.mq5`. The EA family is named `CK_GFT_Fast_vNN`.

The user's core dissatisfaction that motivated most of the work: **the EA is profitable overall
but performs poorly in ranging / sideways markets** (user reported roughly the April→17-August
window making only "~1 lakh" profit, which felt too low relative to the trending-period gains).

### Track B — Anti-overfit validation toolkit (Python, `v1_lab/` + `SPEC/`)
A separate, pure-standard-library Python pipeline (no pandas/numpy dependency) that re-implements
a QM/ICT ("Quasimodo" / Inner-Circle-Trader) style strategy engine and subjects it to a
**deterministic, overfitting-resistant validation process**: in-sample/out-of-sample split,
walk-forward, Monte-Carlo, cost stress, multiple-testing (researcher-degrees-of-freedom) accounting,
and a hash-chained tamper-evident ledger. This lives on the `kiro/validation-toolkit` branch.

The governing philosophy (verbatim from the toolkit, treated as inviolable):
> AI discovers and explains; deterministic code measures and judges; locked/unseen data is final
> evidence; no single metric equals PASS; overfitting is forbidden.

---

## 2. KEY DECISIONS (and why)

1. **v22 is the "screenshot EA".** Multiple candidate EAs matched the user's screenshots. Decision:
   `CK_GFT_Fast_v22.mq5` is the correct one, because it has a **single `InpUsePartialTP` boolean**,
   whereas v25 (`CK_GFT_Fast_v333333.mq5`) has **two** TP booleans (TP1/TP2). The screenshot showed
   a single partial-TP toggle → v22.

2. **Best raw performer = `CK_GFT_Fast_v333333.mq5`** (this file == v25 code, sits on `main`). When
   the user asked "give the one that worked best," this file was provided. *(Performance numbers are
   the user's — see §4; not independently reproduced by the agent.)*

3. **Root cause of sideways-market weakness = ENTRY QUALITY (regime), NOT money management.** The
   EA is a **breakout system**; breakouts fail repeatedly in ranging markets. Evidence: the user's
   own diagnostic log showed **994 SL hits vs 237 TP hits** and unstable per-run final balances
   (4418.60 / 3162.37 / 5279.68 across runs) → non-robust. Therefore the fix target was the
   entry filter, **not** lot size / SL / TP / risk management.

4. **Chosen fix = ADX regime filter** (reject: a full mean-reversion module — judged too complex and
   overfit-prone). Built `CK_GFT_Fast_v22_RegimeADX.mq5` = v22 + ADX gate. New inputs:
   `InpUseADXFilter`, `InpADXPeriod=14`, `InpADXThreshold=20`. Logic: early-return inside
   `TryArmSetup()` when `ADX < threshold` (skip entries in low-trend/ranging conditions). Brace
   balance verified 59/59.

5. **ADX filter defaults ON but is toggleable.** `InpUseADXFilter=false` reproduces exact original
   v22 behaviour, enabling clean A/B comparison. (Never silently change behaviour with no off-switch.)

6. **"No mid-booking" request handling.** When the user wanted no mid-trade booking, both
   `InpUseLock` and `InpUseBreakEven` were disabled. Later the user said keep break-even →
   `InpUseBreakEven=true` was restored.

7. **Validation toolkit will NEVER weaken thresholds to force a PASS.** `pipeline.py` constants
   (`M1_MIN_PF=1.20`, `MIN_OOS_TRADES=200`, `SPLIT_BOUNDARY=2026-02-01`) are treated as locked.
   Declaring INSUFFICIENT honestly is preferred over tuning-to-pass. This is a hard rule.

8. **SMT partner series = XAUUSD vs XAGUSD (NOT DXY).** DXY is unavailable in the user's feed; the
   `smt_dxy` variant is kept for traceability but cannot run without a DXY series.

9. **Honesty about scope.** This agent **cannot** access the user's local machine, their MT5
   terminal, their local `ckrepo` workspace, or their separate "Vibe-Trading" analyst tool. It will
   not pretend to resume something running on the user's PC. (Vibe-Trading is an *analyst* using a
   free model `minimax/minimax-m3:free` via OpenRouter — it explains, it does not backtest.)

---

## 3. CODE & FILES (branches, files, and what each contains)

### 3.1 EA family — git branches (all confirmed present on `origin`)
All EA work was pushed to branches; the full `.mq5` source lives in git (not lost). Key branches:

| Branch | File(s) | What it is |
|---|---|---|
| `main` | `CK_GFT_Fast_v333333.mq5` | Best raw performer (== v25 code). |
| `kiro/v22-optimized-defaults` | `CK_GFT_Fast_v22.mq5` | The confirmed "screenshot EA" (single `InpUsePartialTP`). |
| `kiro/v29-final-management` | `CK_GFT_Fast_v29.mq5` | v29 with final trade-management tweaks. |
| `kiro/v30-fixed-lot-no-partial-timefilter` | v30 variant | Fixed lot, partial-TP off, time filter. |
| `kiro/v22-fixed-lot-002` | v22 variant | v22 with fixed 0.02 lot. |
| `kiro/best-maxloss83-timefilter` | best/v25 variant | Daily max-loss $83 + time filter. |
| `kiro/best-maxloss85-book002` | best/v25 variant | Daily max-loss $85, book 0.02. |
| `kiro/v22-regime-adx-filter` | `CK_GFT_Fast_v22_RegimeADX.mq5` | **v22 + ADX regime filter** (the main §2.4 deliverable). |
| `kiro/validation-toolkit` | `v1_lab/`, `SPEC/`, data CSV | The Python anti-overfit toolkit (this branch). |

> Other pre-existing branches also present (context / earlier iterations): `kiro/v13-final-fixes`,
> `v14-partial-tp`, `v15-be-at-65`, `v16-clean-base`, `v17-sell-and-rr3`, `v18-*`, `v19-tp1-removed`,
> `v20-no-partial-tp`, `v23-tp1-40-no-tp2`, `v24-tp1-at-25`, `v25-final-optimized`, `v26-maxloss-230`,
> `v27-stopday-after-maxloss`, `v28-gft-compliance`, plus `feature/ict-choch-*`,
> `feature/xau-hybrid-knee-v21/v22/v23`, `goat1-v812-fixed-sl-tp`.

> **Full `.mq5` contents are NOT pasted here** because they are already preserved in git on the
> branches above (this satisfies the "include full contents only if not already in a git repo"
> rule). To recover any EA: `git show <branch>:<file>` or the raw URL
> `https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/<branch>/<file>`.

### 3.2 Validation toolkit — files on `kiro/validation-toolkit` (all committed)
`v1_lab/` (pure Python 3.9 stdlib — no pandas/numpy):
- `variant_runner.py` — enumerates the OFAT variant grid, runs each through the pipeline, writes
  `variant_results.csv` + `VARIANT_REPORT.md`. Deterministic. CLI: `--data <M15 csv> --m5 <M5 csv>
  [--pair-csv <XAG/DXY>] --outdir --results --report --deposit`.
- `pipeline.py` — the **judge**. Locked thresholds: `M1_MIN_PF=1.20`, min OOS trades `>=200`,
  pre-declared IS/OOS split boundary `2026-02-01 00:00` (dataset chronological midpoint).
- `qm_state_machine.py` — full QM/ICT engine: ERL → SMT → MSS → IDM → POI → M5-confirm →
  entry/SL/TP. Every "open" rule is a `VariantConfig` switch. Trade funnel: 3243 → 967 → 155.
- `metrics.py`, `walkforward.py`, `paramstability.py`, `cost_stress.py`, `benchmark.py`,
  `manifest.py`, `orchestrator.py`, `regime.py`.
- Detectors: `erl_detect.py`, `idm_detect.py`, `poi_zone.py`, `smt_detect.py`, `qm_detect.py`,
  `ny_session.py`.
- Strategy engines: `strategies/{ctc,judge,stddev,trend}_signal_engine.py`, `hello_signal_engine.py`.
- Misc / A-B: `ab_diff.py`, `forensic_agent.py`, `vibe_validate.py`, `erl_detect.py`.
- Reports/CSVs (committed): `VARIANT_REPORT.md`, `FINDINGS.md`, `README.md`, `STRATEGY_SCREEN.md`,
  `variant_results.csv`, `v23_diag.csv`, `v23_r2_trades.csv`, `v23_trades_real.csv`, `ab_*.csv`,
  `grid_results.csv`, `hello_metrics.csv`.

`SPEC/` (governance / methodology):
- `dof_ledger.py` + `dof_ledger.jsonl` — hash-chained researcher-degrees-of-freedom ledger
  (append-only, tamper-evident; had 43 records from all sessions at export time, integrity OK;
  this export appended one more — see §7/§9).
- `knowledge_gate.py` + `knowledge_ledger.jsonl`.
- `DESIGN_v1.0.md`, `DESIGN_v1.1_amendment.md`, `AGENT_SYSTEM_v1.md`, `QM_ICT_BUILD_PLAN_v1.md`,
  `regime_classifier_v1.md`, `metric_dictionary.md`, `offset_entry_prereg.md`.

### 3.3 IMPORTANT: `.gitignore` behaviour in `v1_lab/`
`v1_lab/.gitignore` contains `XAUUSD_M5_clean.csv`, `*.csv`, `!hello_metrics.csv`. **Consequence:**
the "clean" working CSVs (`XAUUSD_M15_clean.csv`, `XAUUSD_M5_clean.csv`) are **NOT committed**.
Only the raw root file `XAUUSD_M5_202508010105_202607271000.csv` (repo root, ~4.2 MB) is in git.

---

## 4. DATA (datasets, numbers, results, parameters)

### 4.1 Committed market data
- `XAUUSD_M5_202508010105_202607271000.csv` — repo root, **~4.2 MB**, XAUUSD M5, coverage
  **≈ 2025-08-01 → 2026-07-27 (~12 months only)**. This is the ONLY substantial data committed.
- **NOT committed / NOT in repo:** any multi-year XAUUSD M5, any XAUUSD 4-year M15, any XAGUSD
  (M5 or M15), any DXY series. The user exports XAGUSD/DXY locally via `export_xag_dxy.ps1`, but
  those outputs were **never pushed** — so the SMT variants cannot actually run in this repo.

### 4.2 EA backtest numbers — **provenance: user's MT5 screenshots / local logs (NOT reproduced here)**
- `CK_GFT_Fast_v333333` (best): user reported **net ≈ +$10,511, PF 1.75, max DD ≈ $840**.
- A later user screenshot of the same/similar run: **Initial $5,000; Net Profit $10,838.35; PF 2.03;
  Win-rate 52.51%; 459 trades; Equity max DD ≈ 8.3%; risk/trade 0.53%; max 3 trades/day;
  EMA 17/51; SL buffer 0.29×ATR; MaxLot 0.09; Buy+Sell ON; Partial-TP + Break-even ON.**
  *(The two sets differ; both are the user's figures. Treat as indicative, not agent-verified.)*
- v22 diagnostic (user's tester log, `v23_diag3` run): final balances **4418.60 / 4418.60 /
  4418.60 / 3162.37 / 5279.68**; dealLines 2780; **SL hits 994; TP hits 237**. No HTML/XML report
  was generated by that build.
- Baseline H1-2024 report (`CK_baseline.htm`, user-supplied): **≈ −$581, PF 0.81** (i.e. the
  strategy was a net loser on that earlier out-of-window period → fragility evidence).

### 4.3 Validation toolkit results — **agent-reproduced, deterministic (the honest core result)**
From the committed `v1_lab/VARIANT_REPORT.md` (regenerated deterministically by `variant_runner.py`):
- Variants enumerated: **25** (effective distinct trials: **24**; `tp_partial` == `tp_fixed_rr` by
  construction).
- Reached the pre-declared **≥200 OOS-trade** bar (eligible for a verdict): **0**.
- Returned **INSUFFICIENT** (too few OOS trades to judge): **25 (all of them)**.
- **PASS: 0.**
- **Honest verdict: INSUFFICIENT / no robust edge established.** No "best variant" is declared.
  Reason: the QM engine is highly selective (~155 trades over ~12 months), so a chronological
  half yields far fewer than 200 OOS trades. **The binding constraint is DATA (trade count),
  not compute.**

> **Cross-session update (NOT this session — added for honesty):** After this session's base
> commit, a *different* session obtained ~4 years of XAUUSD+XAGUSD data and re-ran the same grid
> (commit `dda2fd1`, split 2024-07): **25 variants, 3 became eligible (≥200 OOS), still 0 PASS —
> "honest no-edge".** So even with far more data the engine did not certify a robust edge. The
> "0 eligible" figure above is correct *for this session's ~12-month committed data*; the newer
> run supersedes it on data volume but reaches the same qualitative conclusion (no edge).

Per-variant OOS table (reading aid only — the verdict column is the only judgement):

| # | variant | verdict | OOS n | OOS PF | OOS exp | OOS maxDD% | switch |
|---|---------|---------|-------|--------|---------|-----------|--------|
| 1 | disp_0p4 | INSUFFICIENT | 88 | 1.37 | 23.55 | 23.65 | MSS displacement gate = 0.4 (looser) |
| 2 | session_all | INSUFFICIENT | 177 | 1.37 | 23.10 | 28.51 | session scope = ny+london+asia (24h) |
| 3 | idm_body | INSUFFICIENT | 59 | 1.30 | 18.70 | 17.74 | IDM clear precision = body |
| 4 | tp_fixed_rr | INSUFFICIENT | 77 | 1.33 | 16.73 | 13.33 | TP mode = fixed_rr (2R) |
| 5 | tp_partial (==tp_fixed_rr) | INSUFFICIENT | 77 | 1.33 | 16.73 | 13.33 | TP mode = partial_be_trail (proxy; not distinct) |
| 6 | ob_lb_3 | INSUFFICIENT | 75 | 1.24 | 15.45 | 28.39 | POI qm_ob + ob_lookback=3 |
| 7 | sl_buf_0p25 | INSUFFICIENT | 74 | 1.20 | 14.01 | 19.70 | SL buffer = 0.25×ATR |
| 8 | erl_h4 | INSUFFICIENT | 71 | 1.21 | 13.26 | 17.74 | ERL source TF = H4 |
| 9 | poi_qm_ob | INSUFFICIENT | 74 | 1.15 | 10.04 | 18.65 | POI type = qm_ob |
| 10 | minrr_1p5 | INSUFFICIENT | 62 | 1.13 | 9.14 | 19.71 | min projected-RR gate = 1.5 |
| 11 | erl_lb_8 | INSUFFICIENT | 73 | 1.13 | 8.86 | 19.71 | ERL lookback = 8 swings |
| 12 | sl_tight_poi | INSUFFICIENT | 72 | 1.10 | 8.22 | 21.11 | SL mode = tight_poi |
| 13 | baseline | INSUFFICIENT | 72 | 1.11 | 7.47 | 19.71 | documented default (no switch) |
| 14 | reentry_on | INSUFFICIENT | 72 | 1.11 | 7.47 | 19.71 | reentry = True |
| 15 | smt_dxy | INSUFFICIENT | 72 | 1.11 | 7.47 | 19.71 | SMT pair = dxy (needs DXY series) |
| 16 | smt_xag | INSUFFICIENT | 72 | 1.11 | 7.47 | 19.71 | SMT pair = xag (needs XAGUSD series) |
| 17 | max_trades_4 | INSUFFICIENT | 97 | 1.09 | 6.08 | 33.51 | max trades/day = 4 |
| 18 | rr_3 | INSUFFICIENT | 77 | 1.10 | 5.88 | 17.90 | fixed_rr target = 3R |
| 19 | erl_lb_3 | INSUFFICIENT | 69 | 1.07 | 4.85 | 19.71 | ERL lookback = 3 swings |
| 20 | disp_0p8 | INSUFFICIENT | 54 | 1.04 | 2.80 | 21.50 | MSS displacement gate = 0.8 (stricter) |
| 21 | sl_buf_1p0 | INSUFFICIENT | 73 | 0.99 | -0.90 | 21.71 | SL buffer = 1.0×ATR |
| 22 | erl_m15 | INSUFFICIENT | 51 | 0.90 | -6.29 | 22.47 | ERL source TF = M15 |
| 23 | poi_qm_fvg | INSUFFICIENT | 49 | 0.89 | -7.59 | 30.80 | POI type = qm_fvg |
| 24 | idm_optional | INSUFFICIENT | 142 | 0.81 | -13.39 | 48.55 | IDM clear optional (experimental) |
| 25 | pivot_3 | INSUFFICIENT | 64 | 0.28 | -60.87 | 78.54 | swing pivot L/R = 3 (stricter) |

> Note: several IS (in-sample) PF/expectancy figures look attractive (e.g. `idm_body` IS PF 1.54,
> `disp_0p4` IS PF 1.51) but IS is **exploration only** and is explicitly NOT evidence of an edge.

### 4.4 Key EA parameters (from user screenshots — the "screenshot config")
EMA fast/slow **17 / 51**; SL buffer **0.29 × ATR**; **MaxLot 0.09**; risk/trade ~**0.53%**;
**max 3 trades/day**; Buy + Sell both ON; Partial-TP ON; Break-even ON. Later custom requests:
fixed **0.02** lot; daily max-loss stepping **$50 → $83 → $85**; time filter at worst-loss hour
(**identified 08:00**) then later **removed** at user request.

---

## 5. STRATEGY RULES

### 5.1 EA (`CK_GFT_Fast_v22` family) — as understood
- **Type:** EMA-based **breakout / trend** system on XAUUSD **M5**.
- **Trend filter:** EMA 17 vs 51.
- **Stop:** ATR-based, buffer ≈ 0.29×ATR (configurable).
- **Targets:** Partial TP + break-even management (single `InpUsePartialTP` toggle in v22).
- **Position sizing:** risk-% based with a `MaxLot` cap (0.09 in the screenshot). `MaxLot` is a
  *hidden effective parameter* — see WARNINGS.
- **Trade cap:** max 3 trades/day (looser 4/day tested).
- **ADX regime addition (v22_RegimeADX):** skip arming a setup when `ADX(14) < 20` (default),
  to avoid breakout entries in ranging markets. Toggle `InpUseADXFilter`.
- **Known weakness:** ranging/sideways markets → many false breakouts (994 SL vs 237 TP).

### 5.2 QM/ICT validation engine (`qm_state_machine.py`) — full setup logic
Sequential state machine, each stage an ICT concept; **every open rule is a variant switch**:
`ERL (external range liquidity) → SMT (divergence vs partner series, rolling-corr guarded) →
MSS (market-structure shift w/ displacement gate) → IDM (inducement, cleared) → POI (point of
interest: QM left-shoulder, OB or FVG confluence) → M5 confirmation → entry, SL, TP.`
- Sessions: NY 8:30 / 9:30 (DST-aware, displayed in IST). ~6581 in-session bars.
- ERL: zones/raids (4762 raids detected).
- IDM: inducement + cleared (3277 levels / 258 cleared).
- Funnel: 3243 candidate → 967 → **155 trades** (default variant, ~12 months).
- Default TP proxy: `partial_be_trail` is modelled as the `fixed_rr` target level (documented
  proxy — that is why `tp_partial` == `tp_fixed_rr`).
- Symbols/timeframes: XAUUSD, execution M5, structure M15 (H4 for some ERL variants). SMT partner
  = XAGUSD (preferred) or DXY (unavailable).

---

## 6. MY INSTRUCTIONS / PREFERENCES (things to always honour)

1. **"যেগুলো বলব সেগুলোই করবে, এর বাইরে কিছু করবে না"** — Do ONLY what I explicitly ask; do not
   add extras (including tests) unless requested.
2. **Reply in Bengali.**
3. Provide **raw GitHub links** for finished `.mq5` files so I can copy them directly.
4. **Do NOT weaken validation thresholds** and do NOT tune-to-pass. Declare INSUFFICIENT honestly
   when OOS < 200 trades. Present both full-history and post-2025-10 views when relevant.
5. Do NOT run slow tests / full multi-period validation unless explicitly requested; default to
   fast tests only (recorded learning).
6. Be honest about capability boundaries — never pretend to drive my local MT5 / `ckrepo` /
   Vibe-Trading tool.
7. Keep changes reversible (feature flags with an off-switch that restores prior behaviour).

---

## 7. UNFINISHED WORK / INTENDED NEXT STEPS

**State at export:** The validation track has reached its honest, correct endpoint on the data that
exists in the repo — **all 25 variants INSUFFICIENT, 0 reached 200 OOS trades**. This is the last
committed result (`VARIANT_REPORT.md`) and matches ledger seq 27 (`QM_ENGINE_COMPLETE`).

**The single blocker to progress = DATA, not code and not compute.** To move past INSUFFICIENT:
1. Commit/push into the repo (e.g. `v1_lab/data_drop/`, using `git add -f` since CSVs are gitignored):
   - **Multi-year XAUUSD M5** (2–4 years, not just the ~12 months currently present).
   - **XAGUSD M5 + M15** (to actually enable the `smt_xag` variant).
   - Optionally a **DXY** series (to enable `smt_dxy`).
   Expected canonical format: `datetime,open,high,low,close,volume`. The user's XAGUSD export is
   TAB-delimited MT5 format `<DATE>\t<TIME>...` with dots in the date — a loader must handle both.
2. Then run the full grid **in the FOREGROUND** (never background/`nohup`, never write to `/tmp`):
   `python3 v1_lab/variant_runner.py --data <M15.csv> --m5 <M5.csv> --pair-csv <XAGUSD.csv>`
   and regenerate `VARIANT_REPORT.md` honestly.
3. Append a ledger record for the new data ingestion + run, then `verify`.

**EA track open item:** `CK_GFT_Fast_v22_RegimeADX.mq5` (ADX regime filter) was built and pushed to
`kiro/v22-regime-adx-filter` but **had not yet been backtested by the user in MT5** at session end.
Intended next step: user runs A/B (`InpUseADXFilter` false vs true) on the same period and reports
whether the ADX gate improves ranging-market behaviour without gutting trending-market profit.

**Open questions:** (a) Will the ADX(14)<20 gate help enough, or is a different regime measure
needed? (b) Can enough clean XAUUSD/XAGUSD history be exported to cross the 200-OOS-trade bar?

---

## 8. WARNINGS (bugs, caveats, mistakes a future agent MUST know)

1. **Why the user's local run "hung / stopped" (the recurring complaint):** on the user's local
   sandbox the variant grid was launched as a **background/`nohup` process writing to `/tmp`**;
   that sandbox **clears `/tmp` and kills background jobs** between steps → the long run was killed.
   It was NOT a code error. **Fix: always run foreground, write outputs inside the repo, not `/tmp`.**
   (This agent moved its own git worktree out of `/tmp` into `/projects/sandbox/vtk` for the same reason.)
2. **Finishing that killed run would NOT have changed the verdict** — the binding limit is OOS
   trade count (needs more data), not run completion.
3. **HTML MT5 reports are UTF-16.** Convert before parsing: `iconv -f UTF-16 -t UTF-8 file.html`.
   Deal rows have 13 columns; Direction is `in`/`out`; profit is on the `out` deal.
4. **No pandas/numpy** in the sandbox (Python 3.9.25). The toolkit is deliberately pure-stdlib —
   keep it that way.
5. **`v1_lab/*.csv` is gitignored** (except `hello_metrics.csv`). Any data you want preserved must
   be added with `git add -f`, or it will silently not be committed.
6. **MaxLot (0.09) is a hidden effective parameter.** Because risk-% sizing is clamped by MaxLot,
   backtest results depend on it in a non-obvious way; treat it as a tunable/curve-fit risk when
   comparing runs at different account sizes.
7. **Realized vs unrealized drawdown differ** in this EA (partial-TP + break-even management);
   don't conflate equity-DD with closed-trade DD when judging robustness.
8. **`smt_dxy` variant cannot run** — DXY series unavailable in the user's feed. `smt_xag` needs
   an XAGUSD series that is currently NOT in the repo.
9. **Do not confuse the two EAs:** v22 has ONE partial-TP boolean; v25 (`CK_GFT_Fast_v333333`) has
   TWO (TP1/TP2). Picking the wrong one silently changes exit behaviour.
10. **Ledger is hash-chained** (`SPEC/dof_ledger.jsonl`). Never edit past records; only append.
    Any silent edit/deletion is detectable via `python3 SPEC/dof_ledger.py --file
    SPEC/dof_ledger.jsonl verify` (was `integrity: OK` with 43 records before this export appended one).
11. **User's "Vibe-Trading" preflight** showed OKX API timing out and used a free model
    (`minimax/minimax-m3:free`). It is an *analyst*, not a backtester; its Markdown output is
    commentary, not measured evidence. Do not treat its text as validation results.

---

## 9. Recovery quick-start for a future agent
```bash
# get the toolkit branch
git clone https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED.git
cd CK_GFT_Fast2_V820_FIXED && git checkout kiro/validation-toolkit

# verify the tamper-evident ledger
python3 SPEC/dof_ledger.py --file SPEC/dof_ledger.jsonl verify

# read the honest result
sed -n '1,140p' v1_lab/VARIANT_REPORT.md

# to progress: drop multi-year XAUUSD M5 + XAGUSD M5/M15 into v1_lab/data_drop/ (git add -f),
# then run FOREGROUND (never /tmp, never background):
python3 v1_lab/variant_runner.py --data <M15.csv> --m5 <M5.csv> --pair-csv <XAGUSD.csv>
```

*End of session export. Everything above is either agent-verified from the repo or explicitly
labelled as user-supplied/unverified. Nothing was fabricated.*

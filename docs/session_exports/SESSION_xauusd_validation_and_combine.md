# XAUUSD Strategy Validation + Disciplined Combine — Full Session Record

> Copy this whole file: click inside it, **Ctrl+A** then **Ctrl+C**.
> Instrument: XAUUSD (Gold) · Simulator: MetaTrader 5 Strategy Tester, "Every tick based on real ticks".
> Spec tested: deposit $5,000, leverage 1:10, fixed 0.09 lot cap. **No real money was ever traded.**

---

## TL;DR (বাংলা)
- একটা কঠোর, সৎ MT5 validation ল্যাব বানিয়ে ৮+ strategy যাচাই করেছি (MT5 = একমাত্র সত্য, প্রতিটা input pin, hash-chain ledger)।
- **শুধু v17** এখনকার (range) মার্কেটে edge দেখিয়েছে; **FIX09** শুধু trend-এ কাজ করে; বাকি সব (QM/ICT, QT/CRT, POC, mean-reversion, Trapbox) — edge নেই।
- v17 + FIX09 কে সৎভাবে combine করেছি (regime-switch, sealed holdout সহ)।
- **সিল-করা শেষ ২ মাসে (Jul–Aug 2026) v17-এর edge মাইনাসে (−7.8%)** — edge শেষ হয়ে যাচ্ছে।
- **রায়: এখন real money-তে কিছু দেওয়া যাবে না।** sealed-holdout শৃঙ্খলা একটা লস-করা deployment ঠেকিয়ে **টাকা বাঁচিয়েছে**। v17 শুধু demo-forward-এ।

---

## 1. Goal
Build an MT5-native, anti-overfit validation lab; test gold strategies honestly; only risk real
money on an edge that survives out-of-sample + a sealed holdout. Reply in Bengali; no real money.

## 2. The honest validation engine (reusable tools)
- `run_candidate.ps1` — one command: compile EA → headless MT5 real-tick test per window → collect
  MT5 report + OnTester trade CSV → metrics + deterministic PASS/FAIL pipeline.
- `run_batch.ps1` — queue many presets, output to files, regenerate summary.
- `screen_confirm.ps1` / `screen_gate.py` — fast Model-1 screen → survivors confirmed on Model-4 real ticks.
- `warm_ticks.ps1` — warm the real-tick cache once.
- `run_optimize.ps1` + `parse_opt.py` — MT5 native optimization used for PLATEAU/robustness only
  (never peak-picking) + MT5 forward mode.
- `plot_equity.py` — MT5-style equity + drawdown picture.
- `portfolio_merge.py` — combine strategy trade streams into one portfolio equity (honest ensemble).
- `v1_lab/pipeline.py` — deterministic gates: PF-collapse (K2/K3), walk-forward, Monte-Carlo,
  trade-removal, year-concentration, cost/slippage stress.
- `SPEC/dof_ledger.py` — append-only SHA-256 hash-chained ledger (every run + decision logged).

## 3. Scoreboard — every strategy tested (out-of-sample, deposit $50k unless noted)
| Strategy | family | OOS net $ | PF | verdict |
|---|---|---|---|---|
| FIX09 / v23 | trend-breakout | +2,913 / +2,512 | 1.13 / 1.12 | REJECT — trend-only, collapses in range |
| POC_VA | volume/value-area | +2,433 | 1.06 | REJECT — edge below cost |
| QM/ICT | ICT structure | −3,325 | 0.50 | REJECT |
| QT/CRT | quarterly/CRT | −3,180 | 0.76 | REJECT |
| CK_MR_StdDev | mean-reversion | losing all windows | 0.84 | REJECT — 57% DD |
| Trapbox [DKT] | session ORB breakout | losing (both exit styles) | 0.68–0.84 | REJECT — 73% win but broken RR |
| **v17** | Asian-session scalp | **profitable in current regime** | **1.39** | **only current edge (but decaying)** |

## 4. The two that worked
**#1 v17 (CK_GFT_Fast_v17)** — XAUUSD M5, untuned defaults, $5k, real ticks:
- Last 12 months: **+$5,808 (+116%)**, PF 1.49, DD 9.2%, 951 fills.
- Current 6 months: **+$2,175 (+44%)**, PF 1.39, DD 11.4%.
- Passed a clean forward test + cost stress. Uses small risk-based lots (no $5k margin wall).
- **Caveat: edge is DECAYING** (Jan–Mar big, Apr–Jul small, Aug negative).

**#2 FIX09 (CK_GOLD_PRO_FIX09)** — XAUUSD M15, fixed 0.09, $5k, real ticks:
- Last 12 months: +$8,740 (+175%), PF 1.37, DD 23%.
- Trend half: +$11,968 (+239%), PF 2.23, DD 9.7% (excellent in a trend).
- Current 6 months (fresh $5k): −$1,661, margin-locks (only 8 trades). **Trend-only.**

## 5. Disciplined combine + sealed-holdout final test
- Design: **v17 base (always) + FIX09 trend-only overlay** (regime gate: H1 EMA200 slope), equal
  $5k sleeves, NO weight tuning (anti-overfit).
- Sealed holdout **2026.07.01–2026.08.28** locked before building (ledger seq 117).
- Build window (excl. holdout): combined **+$7,993 on $10k (+80%, DD 12.4%)** — but per-dollar
  v17-alone was better (118%/9% vs 80%/12%); the trend module only adds diversification.
- **Sealed-holdout single unlock:** FIX09 trend-module = **0 trades** (gate correctly OFF, no trend);
  v17 = **−$391 (−7.8%)**, PF 0.75. Combined = −7.8%.

## 6. Honest final verdict
On the freshest UNSEEN data, even the best strategy (v17) is now slightly **NEGATIVE**; the combine
did not rescue it (no trend to pair with). **No deployable strategy right now — do NOT risk real money.**
The sealed-holdout discipline caught the decay and PREVENTED a losing live deployment. That is the win:
a process honest enough to reject its own favorite before it costs money.

## 7. Deliverables (paths in the repo)
- `PORTFOLIO/CK_XAUUSD_Validation_Report.pdf` — full boss report (method, scoreboard, v17, FIX09, verdict).
- `PORTFOLIO/Ranked_Results_MT5style.pdf` — MT5-style ranked results (#1 v17, #2 FIX09).
- `PORTFOLIO/CK_XAUUSD_BOSS_PACKAGE.zip` — everything for the boss (reports + code + README).
- `PORTFOLIO/STRATEGIES/` + `CK_XAUUSD_Strategies.zip` — the 2 EAs ready for VPS:
  `.ex5` (compiled) + `.set` (exact settings) + `.mq5` (source) + README.
- `SPEC/dof_ledger.jsonl` — 119 hash-chained records, integrity OK.

## 8. How to demo-test on the VPS (NOT real money)
1. Copy the `.ex5` files into MT5 `MQL5\Experts\` (File → Open Data Folder), refresh MT5.
2. Chart: **v17 → XAUUSD M5**, **FIX09 → XAUUSD M15**.
3. Drag EA → Inputs tab → **Load** the matching `.set`. Enable Algo Trading. Account = **DEMO**.
4. Run several weeks; compare live fills to the backtest. Only consider real money if v17's edge
   clearly returns on the demo.

## 9. Audit
Every run and parameter choice is in `SPEC/dof_ledger.jsonl` (append-only, SHA-256 hash-chained,
119 records, integrity verified). Deterministic pipeline owns PASS/FAIL — no guesswork.

## 10. Next steps
- Keep v17 on demo-forward; watch whether the edge returns.
- Any new idea → run through the same engine with the same sealed-holdout discipline.
- A real combine needs ≥2 independently-validated current edges; keep hunting honestly.

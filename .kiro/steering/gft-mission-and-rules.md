# CK — Mission & FundedNext Prop Rules (PERMANENT — always applies)

> This file is always in context. It is the locked mission and the hard rule-set
> for every EA, config, `.set`, backtest, and decision in this workspace.
> If any instruction conflicts with Section 0 or Section 2, THIS file wins.
>
> **LIVE DEPLOYMENT TARGET = FundedNext (Stellar 2-Step, $5,000).** The repo/folder name
> "CK_GFT" and the filename are HISTORICAL — the project began exploring Goat Funded Trader
> (which has "Goat Guard"). That firm was dropped in favour of FundedNext because FundedNext
> has **NO float-based guard**, which lets us size up (0.01 → 0.03) for ~3× the return at the
> same rule-safety. Confirmed by user 2026-09-18. Any leftover "GFT / Goat Guard" wording in
> other files is stale; the rules below govern.

## 0. MISSION LOCK (highest priority — never override)
- The goal is **NOT** merely to "pass the challenge" or to "take a payout."
- The goal **IS**: trade every stage with full **discipline**, respect **every FundedNext rule at all times**, keep a **solid win rate**, and **maximize profit strictly within the rules**.
- **One hard-breach = the account is permanently dead** (no funding, no payout, ever).
  Therefore **rule-compliance always outranks profit**. When in doubt, protect the account.
- Every EA / config / change **must respect all rules below WITH a safety buffer**.
  Never ship a config that can even touch a hard limit.

## 1. Account: FundedNext Stellar 2-Step (smallest = **$6,000**, not $5k)
(Confirmed from help.fundednext.com + user + ledger seq260 + user re-confirm 2026-09-21. The
FundedNext Stellar 2-Step's actual smallest offering is **$6,000**, not $5,000 as an earlier
draft assumed. All rules below scale proportionally to initial deposit — no change to the
percent limits, only the dollar amounts. For $6k basis: daily $300, static $600 = floor
$5,400, funded 3% risk = $180. Any Python/spreadsheet analysis that used $5k must be
re-computed for the $6k reality before it's actionable. If the real account is a different
FundedNext model — Stellar Lite / Express / 1-Step / Evaluation — RE-VERIFY on the dashboard;
targets, daily basis and min-days differ. FundedNext also changes terms over time — confirm
live.)

| Rule | Step 1 (Eval) | Step 2 (Eval) | Funded |
|---|---|---|---|
| Profit target | **8%** (+$400) | **5%** (+$250) | none |
| Daily drawdown (HARD) | 5% of **INITIAL** | 5% of **INITIAL** | 5% of **INITIAL** |
| Max overall loss (HARD) | 10% **STATIC** | 10% **STATIC** | 10% **STATIC** |
| Time limit | none | none | none |
| Min trading days | 5* | 5* | payout-dependent (21-Day option = no min)* |
| Consistency rule | none | none | none |
| Float-based guard (Goat Guard) | **N/A — FundedNext has none** | N/A | **N/A — FundedNext has none** |

\* *Min trading days + exact payout cadence changed by FundedNext across versions — RE-VERIFY on the live dashboard before relying on 3 vs 5.*

## 2. Hard-breach definitions (a single breach kills the account)
- **Max overall loss — 10% STATIC**: the absolute floor = 90% of starting capital. Dollar
  values by account size: $4,500 floor on $5k / **$5,400 floor on $6k (LIVE)** / $9,000 on
  $10k / $13,500 on $15k. FIXED, never trails up with profit. Account equity OR balance must
  never touch or cross the floor.
- **Daily drawdown — 5% of INITIAL**: within one trading day, loss must not reach 5% of the
  **fixed initial balance**. Dollar values: $250 on $5k / **$300 on $6k (LIVE)** / $500 on
  $10k / $750 on $15k. FundedNext counts **closed + floating + swap + commission** toward it
  (equity-based, includes open P&L). Resets at FundedNext's daily rollover (**00:00 server
  time**, GMT+2/+3). Because it is % of INITIAL (not day-start), our EA references the daily
  limit against the fixed initial via `Combo_DailyRefInitial=true`.

## 3. Payout / funded terms
- Profit split **80%** to trader, scaling to **90%** under FundedNext's scale-up plan.
- News handling (funded): news-trade **profit counted at 40%** (loss counted in full);
  weekend holding OK; no minimum hold time.
- EA allowed on **MT5** (small EA-usage fee scaled by account size); EA is **banned on
  Match-Trader**; EA allowed only on accounts **< $50,000**. Gold leverage **1:15**.
- Payout cadence / first-payout caps / min valid days: **confirm on the live dashboard** —
  FundedNext offers options (e.g. a 21-Day payout with no min days). Do NOT hard-code the
  GFT-style "$3,000 daily cap / 6% first-payout cap" here; those were Goat Funded Trader.

## 4. EA guardrails (DERIVED — enforce with buffer, never sit at a hard limit)
- **Static halt** — close all + stop for good when equity ≤ **8% below initial**
  (`Combo_StaticDDStopPct=8.0`; buffer under the 10% / $4,500 floor). Never approach $4,500.
- **Daily governor — PRE-TRADE predictive** (`Combo_UsePredictiveDaily=true`): before opening
  ANY new trade, if `today_realized_loss% + this_trade_worst_case_SL_risk%` (as % of INITIAL)
  would exceed the buffer (**~3.5%**, `Combo_DailyBufferPct=3.5`), skip the entry. A reactive
  flatten at **4.5%** (`Combo_DailyLossPct=4.5`) is the backstop. Both sit under the 5% hard
  daily line (a limit set AT 5% gets nicked by overshoot/slippage).
- **Per-trade SL-risk cap** (`Combo_PerTradeMaxRiskPct=2.0`): no single trade may risk enough
  to breach the daily buffer on its own.
- **News gate** (`Combo_UseNewsGate=true`, block ±6 min): avoids high-impact spike stop-outs
  and the funded 40% news-profit haircut.
- **Min trading days**: keep steady activity; never try to pass in fewer than the required
  valid days (assume 5/phase until the dashboard confirms otherwise).
- A guard must always sit **inside** the limit with margin, never exactly on it.

## 5. Testing & honesty discipline
- **MT5 Strategy Tester = truth. Python is EXPLORATION, never verdict.** Python may enumerate
  variants, filter data, or generate signals, but the number that decides deploy-vs-drop is
  ALWAYS the MT5 real-tick (Model 4) result. Any income projection, PF, DD or FN-compliance
  claim must come from an actual MT5 run — not a Python simulator.
- **The Python-vs-MT5 haircut is real and material.** Concrete evidence, ledger seq227 vs
  2026-09-21 signal-player run (QM/ICT erl_h4 + dedupe, $6k, $85/trade, 2025-08→2026-07):
  Python theoretical net $3,110 → **MT5 real-tick net $2,296 (-26% haircut)**; PF 1.58 → 1.49;
  win rate 38.1% → 22.7% (tight SLs get nicked by spread); 105 signals → 88 fired (17 skipped
  by tolerance/spread gate). MT5 also revealed **1 daily-line breach** (2026-03-23 = -$314.66
  = 5.24% of $6k, over the $300 line) that Python did not surface. **Never** approve deploy on
  Python numbers alone; always require the MT5 real-tick pass first.
- **No faking, ever.** Every number reported must come from an MT5 run, a CSV the EA wrote,
  or a chart actually read.
- **Hash-chained ledger** `SPEC/dof_ledger.jsonl`: pre-register experiments BEFORE running;
  log results after. Verify integrity.
- Report drawdown as the htm **"Balance / Equity Drawdown Absolute"** (distance below the
  initial deposit) — that is the FundedNext-relevant static number. Trailing "Maximal" DD is
  irrelevant on a static-drawdown firm.
- **Real money only after a forward-demo passes on the real FundedNext feed AND the human
  approves** (protocol: `experiments/combo_fnext_03/FORWARD_DEMO.md`, ledger seq223).

### 5a. Signal-player pattern (Python decides, MT5 executes)
When a strategy is prototyped in Python (e.g. QM/ICT state machine), the canonical way to
verdict-test it in MT5 without a full MQL5 rewrite is the **signal-player** pattern:
1. Python engine dumps trades to CSV with columns `datetime,direction,entry_price,sl_price,tp_price`.
2. A tiny MQL5 EA (`CK_QM_SignalPlayer.mq5`) reads that CSV from `Common/Files/` and places a
   market order at each row's time with the given SL/TP; lot is risk-based
   (`InpRiskUSD / (SL_dist × contract_size)`).
3. MT5 Strategy Tester Model 4 (real ticks) then executes the strategy with real spread,
   slippage, and swap. The output is the honest MT5 verdict.
This pattern is faster than a full MQL5 port (~2h vs ~25h) and produces the same
authoritative MT5 numbers. The full MQL5 port is only needed for live deployment (so the EA
can decide signals on its own, without needing Python running alongside).

## 6. FUNDED-STAGE RISK LIMITS on FundedNext (confirmed 2026-09-18) — THREE separate limits
FundedNext has NO Goat Guard, but the funded ("FundedNext") account carries a **3% RISK LIMIT** we
did not originally know about (help article 14702245). The three funded limits:
- **5% daily loss** of INITIAL, **INCLUDES floating** — HARD BREACH = account dead. ($250 on $5k / **$300 on $6k LIVE** / $500 on $10k)
- **10% max loss**, STATIC of initial — HARD BREACH = account dead. (floor $4,500 on $5k / **$5,400 on $6k LIVE** / $9,000 on $10k)
- **3% RISK limit** (funded only): at any instant, (max potential SL loss) + (combined realized +
  unrealized/floating loss across ALL open trades), vs INITIAL, must stay <= 3% = **$150 on $5k / $180 on $6k LIVE**
  (swap/commission excluded). NOT an instant kill: 1st breach = warning + 100% of the violating
  trades' profit deducted that cycle; 2nd breach = PERMANENT reclassification to a **1%** risk cap;
  later breaches keep deducting. It silently strips funded profit, so we MUST stay under it.
- Consequence for our EA: FIX + the DT swing open together can reach ~$220 combined floating (=4.4%)
  on the 0.02 config -> that VIOLATES the 3% rule. So the FUNDED config MUST cap combined risk under
  $150 — e.g. `Combo_FundedMaxOpenTotal=1` (no FIX+DT overlap) and/or a combined-floating flatten
  (the `Combo_Stage=1` funded-guard path, recalibrated to flatten well under 3%). This rework + a
  re-test is REQUIRED before the account is funded. (Goat Funded Trader's 2% Goat Guard is a separate,
  unrelated firm — not applicable here.)

## 7. CONFIGS — 0.02 for the challenge; funded needs a 3%-risk rework
- **CHALLENGE (Step 1 & 2)** — `experiments/combo_fnext_03/CK_GOLD_COMBO_FundedNext.set`:
  FIX **0.02** lot + DTChop + settlement-block (`Combo_BlockEntryHours=0,1`), `Combo_Stage=0`,
  `Combo_DailyRefInitial=true`. 0.02 NOT 0.03 because the 5% daily INCLUDES floating: 0.03 worst
  floating ~$293 > $250 (breach risk); 0.02 ~$220 < $250 (safe). Backtest (Model 1, last1y, $5k):
  net +$3,308, worst realized day -$143.71, 0 daily/static breach. The 3% risk rule is funded-only,
  so the challenge is governed only by the 5% daily / 10% static limits.
- **FUNDED (live account)** — starts from the 0.02 set but MUST be reworked to respect the 3% risk
  limit (Section 6): cap to ONE open position and/or a combined-floating flatten under $150, then
  re-test. Funded income will be somewhat LOWER than the ~$204/mo 0.02 projection as a result. This is
  a required TODO before the account is funded (there is time — it happens during the challenge weeks).
- **Scaling is capped by two funded rules**: (a) "identical trades across accounts are NOT allowed",
  and (b) accounts **$50,000 and above are MANUAL-ONLY (no EA)**. So the EA ladder cannot clone the
  same EA across many accounts and cannot use an EA at >=$50k. Realistic EA growth = FundedNext's own
  scale-up plan on a single sub-$50k account, or a few DIFFERENTIATED sub-$50k accounts.
  `INCOME_SCALING_PLAN.md` must be corrected — the 5k->200k same-EA ladder is NOT viable as written.

## 8. Machine-load discipline (protect the dev PC — our work is CPU-heavy)
The dev PC is a **Gigabyte B550M DS3H AC R2 / Ryzen 5 5600GT / 16 GB DDR4 /
256 GB NVMe (C:) / 450 W PSU**. The Kernel-Power 41 crash cluster
(Aug 24 – Sep 4 2026, 15+ events, 3-in-1-hour on Sep 3) was **ROOT-CAUSED** to
the **E: HDD (Daichi DI DE00D, 465.8 GB)**: Reallocated Sector Count = 240
(should be 0), SMART warning YES. CPU stayed at 44 °C, PSU +12 V = 11.95 V,
RAM clean, NVMe 99 % life — all healthy. The user shell folders (Documents/
Downloads/Music/Pictures/Videos) had been redirected to `E:\PERSONAL\`, so
every Explorer / app open hit the failing drive and the kernel watchdog
hard-reset the box.

**RESOLUTION — COMPLETED 2026-09-21.** E: is retired. Cloud storage was
originally planned but not needed — the E:\PERSONAL data was only 12.26 GB
(Downloads dominated at 12.26 GB / 59,679 items; Documents/Music/Videos
were near-empty; Pictures was already in OneDrive). Migration went directly
to C: instead. Final state:

- **Data:** 12.26 GB / 59,679 items robocopied to `C:\Users\prita\Downloads`,
  Music/Videos to their C: counterparts. Documents was already on C:.
  Robocopy report: **53,739 / 53,739 files, 0 FAILED, 0 SKIPPED.** Log at
  `C:\Users\prita\_robocopy_Downloads.log`. Elapsed 39 min (4:50 pure copy,
  rest was sick-HDD seek latency).
- **Shell folders (HKCU registry):** `Documents/Downloads/Music/Videos` →
  `C:\Users\prita\<Folder>`. `Pictures` → `C:\Users\prita\OneDrive\Pictures`.
- **E: drive letter — REMOVED.** Windows no longer sees an E: mount at all.
- **E: disk (Disk #0) — OFFLINE.** `Set-Disk -IsOffline $true` applied.
- **Boot-time guardian:** scheduled task `OfflineSickHDD_Daichi` runs as
  SYSTEM at every boot and re-applies `Set-Disk -IsOffline $true` on Disk
  #0. Belt-and-suspenders: even if Windows update or a manual mistake
  re-onlines it, the task shuts it back down at next boot.
- **C: free:** 105 GB free after migration (of 237 GB total) — plenty for
  MT5 tester caches, backtests, and archives.

### E: — HARD RULES for any future session, tool, or sub-agent
- **NEVER** read from, write to, mount, or reference `E:\` or Disk #0 (the
  Daichi HDD). E: is dead by design; touching it is guaranteed to bring
  back the Kernel-Power 41 crash cluster.
- **NEVER** modify or delete the scheduled task `OfflineSickHDD_Daichi`. If
  a Windows update wipes it, re-register it (SYSTEM principal, at-startup
  trigger, action: offline Disk #0).
- **NEVER** try to un-offline E: or add back a drive letter to test/inspect
  it. If diagnostic access is genuinely needed, ask the user first, do it
  in one bounded pass with `-ErrorAction SilentlyContinue`, and re-offline
  immediately after.
- If a script, config, or `.set` file references any path starting with
  `E:\`, that file is stale — fix the path (map to the C: equivalent), do
  not feed the sick drive.
- Physical removal (SATA + power cable disconnect) is the ultimate
  permanent fix, at the user's convenience. Software-side is fully
  neutralised in the meantime.

### Hang-safety: any shell/tool operation that waits indefinitely = KILL immediately
**Origin:** user instruction 2026-09-21 (Bengali; *"দিক্স থেকে জিনিসটা আসছে
না এবং ওয়েটিং এ থাকছে এইভাবে হার্ট শাট ডাউন পরে করা হচ্ছে"* — roughly:
"stuff isn't coming from disk and it's waiting like this, and later a hard
shutdown happens; don't do work like that; if it happens, kill it right away;
don't take from THE disk, take from other drives; lock this rule in and tell
everyone"). This is a permanent, cross-session rule.

**Historical context:** the E: HDD's failing sectors caused commands that
touched it to appear to "wait forever" while the kernel watchdog timed out
and issued a Kernel-Power 41 hard shutdown (§8 above). Even now that E: is
offlined, ANY future hang against a slow disk is the same physics.

**Rules (never soften, never skip):**
- If a shell command, tool call, or file read APPEARS TO HANG or BLOCK for
  more than a few seconds without progress, KILL it immediately. Do NOT wait
  it out, do NOT retry the same path.
- Diagnose only from a KNOWN-GOOD path on C: (`C:\Users\prita\CK_GFT_Repo\`,
  `C:\Program Files\MetaTrader 5\`, etc.). If a specific path causes a hang,
  that path is suspect and must not be re-entered in the same session.
- NEVER take input from `E:\` or any offline / suspect drive. Read only from
  C: (and OneDrive-backed folders under C:). "Take from all drives" in the
  user's instruction means "use whatever GOOD drive is available", NOT "try
  every drive including the sick one".
- Every PowerShell invocation must include `-NoProfile -NonInteractive`
  (also codified in §10). The default profile enumerates all drives on
  start-up and historically hung on the sick HDD.
- NEVER redirect a shell command's output to a bare filename without a full
  path (also in §10). A stray `> out.txt` will land wherever `cwd` is, which
  can silently touch a slow / protected drive.
- If ambiguous whether a hang is disk-related or tool-related, TREAT IT AS
  DISK-RELATED and abort. Tool-related hangs are recoverable; disk-related
  hangs cost the box.
- If ever a NEW slow / suspicious drive appears (SMART warning, growing
  reallocated-sector count, prolonged seek latency), OFFLINE IT and register
  a boot-time guardian task like `OfflineSickHDD_Daichi` before doing any
  further work.

**Machine-load rules** (still apply — the box is real hardware, not a server;
CPU still limits parallel MT5 work regardless of drive):
- Run only **ONE backtest at a time**; never chain or parallelise heavy MT5 runs.
- Use **Model 1 (1-min OHLC, fast)** for screening; use **Model 4 (real ticks)** only for a
  final confirmation, and only when the user says the machine is cool/ready.
  (User preference: real ticks are the trusted truth — use them for anything that ships.)
- **Stop and close every background process the moment it finishes** — never leave
  terminals/scans running idle.
- Clean up scratch files (`tools/_*.txt`) after use.
- Keep the MT5 GUI and other heavy apps closed except while actually testing.
- If the PC shows any instability, **pause heavy work immediately** — safety > speed.
  (Reserved for future issues; the Aug–Sep 2026 event was a drive fault, not a CPU/PSU limit.)

## 9. Storage discipline (clean up after every job)
- Analysis artifacts (charts, galleries, per-loss PNGs, temp CSVs, scratch `tools/_*.txt`) are
  **generated on demand, shown, then DELETED** once the user has seen them — don't let them pile up.
- After a backtest is analyzed, delete the heavy junk it leaves: MT5 **`tester.log`** files (often
  10+ MB each) and stale `experiments/<id>/` folders that are no longer referenced. Keep only
  what's needed: the EA, `.set`, `tools/` scripts, the ledger, steering, and source data.
- NEVER delete files that a currently-running backtest/process is using; do the big cleanup only
  after the run finishes and its results are read.
- Goal: keep the repo lean so the work stays fast and the disk doesn't fill up.

## 10. Shell hygiene (learned the hard way — 2026-09-19 phantom-file incident)
On 2026-09-19 18:42, an admin PowerShell whose `cwd` was `C:\Windows\System32`
executed something like `Get-WmiObject … > Get-WmiObject`, which silently
created a 0-byte file named `C:\Windows\System32\Get-WmiObject`. Windows /
VS Code kept trying to re-open that extensionless "file" and triggered a
recurring "Open with…" pop-up. Deleted 2026-09-21 (elevated); confirmed
gone. To make sure this class of mistake never happens again:

- **Never redirect (`>` / `>>` / `Out-File`) to a bare filename without a
  path.** Always use a full, non-protected path — e.g.
  `... | Out-File C:\Users\prita\_scratch\out.txt`, not
  `... > out.txt`. A typo becomes a phantom file wherever `cwd` happens
  to be, which is often somewhere you don't want.
- **Never `cd` into `C:\Windows\System32`, `C:\Windows`, `C:\Program Files`,
  or any protected system path from a script.** Reference full paths
  instead. If a tool insists on a working directory, set it to
  `C:\Users\prita\CK_GFT_Repo` or a purpose-built scratch folder.
- **Never redirect output to a name that matches a PowerShell cmdlet**
  (`Get-*`, `Set-*`, `New-*`, `Invoke-*`, `Remove-*`, …). Cmdlet-name
  collision on disk is what caused this incident.
- **`-NoProfile` is required** when Kiro launches PowerShell for E: probes
  or any file-system enumeration. The user's default PowerShell profile
  historically enumerated all drives on start-up and hung on the sick HDD;
  future profile changes can reintroduce the same trap. When in doubt,
  add `-NoProfile -NonInteractive` to shell invocations.
- **Elevated (UAC) operations must write results to a log file** on C:
  (not to the console of the elevated process — you can't read it), then
  the outer script `Get-Content` the log. Pattern used successfully during
  the E: retirement: `Start-Transcript -Path <log>` inside the elevated
  script; parent script reads the log after `Wait -PassThru`.
- **After any migration / clean-up job, delete the `_*.ps1` / `_*.log`
  scratch files** created for that job (Section 9 rule). Keep only durable
  artefacts (real logs the user might want as evidence) and note their
  paths in the ledger or steering.

## 11. FundedNext Trading-Ethics reply (2026-09-21) — Plan Z′ officially BLOCKED
On 2026-09-21 the user forwarded FN Trading Ethics support (agent **Allen**) response to
the email sent earlier that day about Article 8020351 (mirrored / opposite positions
across two FundedNext accounts).

**Allen's answer** (paraphrased for licensing compliance): as a support agent he cannot
specify which strategies are permitted, but if a strategy is not on the restricted-
strategies list, we may proceed to use it. This is a referral to the rulebook, not a
case-by-case exception.

**The restricted-strategies list is unambiguous** (help.fundednext.com Article 8020351
+ the general-rules page):
- "Hedging Across Various Accounts" is listed as prohibited: buying 1 lot of X on
  account A and simultaneously selling 1 lot of X on account B is banned.
- "Mirrored or opposite positions across two FundedNext accounts are prohibited,
  even when both belong to you."

Allen's referral to that list therefore CONFIRMS **Plan Z′ (two accounts, combo EA on
one + QM signal-player on the other, whose coincidental opposite-direction XAUUSD
positions were the whole edge) is prohibited.** No case-by-case exception is available
from support.

### Resolved deployment plan
**Plan C — CK_GOLD_COMBO FIX 0.02 solo — is the deployment path.** Reasons:
- Fully MT5-real-tick verified (JOURNAL_FundedNext.md, ledger seq255): 270 trades,
  +$2,240 on $5k basis, PF 1.35, win 25.6%, 1 daily-line touch that the governor caught.
  On $6k basis (same 0.02 lot) ≈ +37.3%/yr = **~$139/mo take-80 minus $5 EA fee =
  ~Rs 15,900/mo**; scales to ~Rs 17,900/mo at the 90% split.
- Fully deploy-ready: `experiments/combo_fnext_03/` ships install script, VPS setup
  guide, forward-demo protocol, daily/weekly checklist.
- Single MT5 binary, no Python signal-refresh, no VPS Python-runtime, no signal-CSV
  freshness worries.

Plan Q (QM signal-player solo, ~Rs 15,200/mo) remains a valid alternative if the user
specifically wants to run the QM setup for reasons outside pure income — but Plan Q
requires ~2–3h of extra prep (VPS-side Python + weekly signal refresh), and its income
is ~Rs 700/mo lower than Plan C. Choose Plan Q only on explicit user preference.

Plan Z′ is dead. Do not attempt a 2-account portfolio that could produce
coincidental opposite positions. The ~Rs 33k/mo target that Z′ chased is not
achievable on a single sub-$50k FundedNext account with these two strategies; the
income ceiling is the FundedNext scale-up plan on that single account.

### Full decision framework
`SPEC/FN_REPLY_DECISION.md` — the pre-declared reply-pattern → plan mapping used to
resolve this. Ledger `seq275` — the hash-chained record of the FN reply itself.

### Standing rule going forward
Any strategy that could produce mirrored / opposite positions across FundedNext
accounts is banned. If a future strategy proposal involves multiple FN accounts
under one profile, re-read Article 8020351 first and abort at the design stage,
not after implementation.

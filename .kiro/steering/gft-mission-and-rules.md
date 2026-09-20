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

## 1. Account: FundedNext $5,000 — Stellar 2-Step model
(Confirmed from help.fundednext.com + user. If the real account is a different FundedNext
model — Stellar Lite / Express / 1-Step / Evaluation — RE-VERIFY on the dashboard; targets,
daily basis and min-days differ. FundedNext also changes terms over time — confirm live.)

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
- **Max overall loss — 10% STATIC**: the absolute floor = 90% of starting capital =
  **$4,500 on a $5,000 account**, FIXED, never trails up with profit. Account equity OR
  balance must never touch or cross $4,500.
- **Daily drawdown — 5% of INITIAL**: within one trading day, loss must not reach 5% of the
  **fixed initial balance** (**$250** on $5k). FundedNext counts **closed + floating + swap +
  commission** toward it (equity-based, includes open P&L). Resets at FundedNext's daily
  rollover (**00:00 server time**, GMT+2/+3). Because it is % of INITIAL (not day-start), our
  EA references the daily limit against the fixed initial via `Combo_DailyRefInitial=true`.

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
- **MT5 Strategy Tester = truth.** Python only analyzes MT5 outputs; it never invents results.
- **No faking, ever.** Every number reported must come from an MT5 run, a CSV the EA wrote,
  or a chart actually read.
- **Hash-chained ledger** `SPEC/dof_ledger.jsonl`: pre-register experiments BEFORE running;
  log results after. Verify integrity.
- Report drawdown as the htm **"Balance / Equity Drawdown Absolute"** (distance below the
  initial $5,000) — that is the FundedNext-relevant static number. Trailing "Maximal" DD is
  irrelevant on a static-drawdown firm.
- **Real money only after a forward-demo passes on the real FundedNext feed AND the human
  approves** (protocol: `experiments/combo_fnext_03/FORWARD_DEMO.md`, ledger seq223).

## 6. FUNDED-STAGE RISK LIMITS on FundedNext (confirmed 2026-09-18) — THREE separate limits
FundedNext has NO Goat Guard, but the funded ("FundedNext") account carries a **3% RISK LIMIT** we
did not originally know about (help article 14702245). The three funded limits:
- **5% daily loss** of INITIAL, **INCLUDES floating** — HARD BREACH = account dead. (~$250 on $5k)
- **10% max loss**, STATIC of initial — HARD BREACH = account dead. (floor $4,500)
- **3% RISK limit** (funded only): at any instant, (max potential SL loss) + (combined realized +
  unrealized/floating loss across ALL open trades), vs INITIAL, must stay <= 3% = **$150 on $5k**
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

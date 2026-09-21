# VPS SETUP — Plan Q (CK_QM_SignalPlayer) on FundedNext Stellar 2-Step $6,000

The Plan Q VPS is heavier than Plan C's because a Python engine has to run alongside MT5
to keep the signal file fresh. Read this whole doc before provisioning.

## 1. Which VPS

- **FundedNext's own VPS add-on** — same as combo. Simple, single-IP guaranteed.
  Check whether Python installs are allowed on their VPS image; if not, this path
  won't work for Plan Q.
- **Independent forex VPS** (recommended for Plan Q — Python-friendly Windows Server):
  ForexVPS, BeeksFX, NYCServers, Contabo. **4 vCPU / 8 GB RAM / 80 GB SSD** (a step
  above Plan C's 2/4/40 because Python engine + MT5 both need headroom). Windows
  Server 2019 or 2022. Target latency to FN's MT5 server < 50 ms.

**Do NOT** run two MT5 terminals with different accounts on the same VPS if the second
one is a paired FN account — an incidental crossed hedge trips Article 8020351
(steering §11, ledger seq275).

## 2. Provisioning steps (independent VPS)

1. Sign up, choose Windows Server 2022 (or 2019). 4 vCPU / 8 GB RAM / 80 GB SSD.
2. Get IP + Administrator + password. RDP in via `mstsc`.
3. Install **MT5** from FundedNext's client-area installer (NOT metaquotes.net).
4. Install **Python 3.14** from `python.org/downloads/`. Add to PATH. Verify
   `python --version` reports 3.14.x.
5. Clone this repo on the VPS: `git clone https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED`.
   Branch `kiro/mt5-validation-backup`. Path: `C:\CK_GFT_Repo` (or wherever).
6. Run `experiments\qm_erl_h4\install_qm_signalplayer.ps1` to copy the EA + signals
   into MT5, compile.
7. Complete steps 4–7 of `QM_FORWARD_DEMO.md` section A (regenerate signals with fresh
   MT5 data, attach EA, load preset, enable trading).

## 3. Signal regeneration workflow (Plan Q's operational cost)

This is the extra work Plan C does not have.

### Fresh MT5 price data

From MT5 on the VPS:
1. Open XAUUSD, M15 timeframe.
2. Right-click chart → Timeframes → M15. Then wait a moment; press Page-Down until you
   have at least 3 years of history.
3. From the MetaEditor, use one of the `CK_ExportOHLC.mq5` or equivalent script (or
   MT5's built-in CSV export via `File → Save As → CSV`) to write:
   `XAUUSD_M15_export.csv` in `MQL5\Files\`.
4. Repeat for M5 → `XAUUSD_M5_YYYYMMDDHHMM_YYYYMMDDHHMM.csv`.
5. Copy both files to the repo working folder on the VPS.

### Python engine run

```
cd C:\CK_GFT_Repo
python _multi_tf_test.py --erl-tf H4 --dedupe --out _signals_erl_h4.csv
python _export_signals_for_mt5.py --input _signals_erl_h4.csv --output _signals_erl_h4.txt
```

The `.txt` uses tab-delimited format matching the EA's `FILE_CSV` reader with comma
delimiter — steering §5a details the format. Both `.csv` and `.txt` end in the same
schema (`datetime,direction,entry_price,sl_price,tp_price`).

### Deposit into MT5

Copy the fresh `_signals_erl_h4.csv` to:

    C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\signals_erl_h4.csv

Overwrite the existing file.

### EA restart (Option A from QM_FORWARD_DEMO §C)

Because `CK_QM_SignalPlayer.mq5` only reads the CSV in `OnInit()`, the new signals are
NOT picked up until the EA re-initializes. Options:

- **Right-click chart → Expert Advisors → Remove**, then drag the EA back on. ~10 seconds.
- **Or restart MT5**. ~30 seconds. Loses no positions (MT5 remembers open trades).
- **Or restart just the chart** by pressing F5 on the chart. Not guaranteed to re-init
  the EA — verify by checking the Experts log for the "loaded N signals" line.

Do this at 03:00 server time (the settlement window `Combo_BlockEntryHours=0,1` on the
combo config — Plan Q honours the same convention because 00:00–02:00 is the FundedNext
market-settlement window). No new signals fire during that window anyway.

### Schedule the regeneration

Use Windows Task Scheduler. Once per day at 03:00 server time:

- Action 1: run the two Python commands above, logged to `C:\Users\Administrator\_qm_signal_refresh.log`
- Action 2: copy the fresh CSV to `Common\Files\`
- Action 3 (semi-manual): a human confirms the log looks clean, then removes + re-attaches
  the EA. Fully-automating step 3 requires the file-poll EA patch (Option B in
  QM_FORWARD_DEMO §C) or the native rewrite (Option C) — neither is in place yet.

**Recommended interim: manual daily restart at 03:00 UTC, weekend regeneration only.**
The signal set is stable enough that daily runs aren't strictly necessary — a
Saturday-morning refresh covers the following week.

## 4. VPS-side hygiene (same as combo)

- **Auto-login on boot** (`netplwiz`), MT5 shortcut in `Startup`.
- **Windows Update** set to "Notify but don't auto-restart".
- **Antivirus:** disable Real-Time on the MT5 folders + `C:\CK_GFT_Repo`.
- **Sleep / hibernate OFF**.
- **Timezone:** leave UTC; use MT5 clock as authority.
- **RDP session:** disconnect (X) instead of logging off.
- **MT5 push notifications** enabled via mobile app.

## 5. Where the EA writes files

MT5 Common\Files on the VPS:

    C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
        signals_erl_h4.csv          — INPUT: Python-generated signals (you refresh this)
        qm_signalplayer_deals.csv   — OUTPUT: written on OnTester and on demand

For the LIVE run there is no OnTester trigger. Consider adding a manual "dump deals now"
tool or extract from MT5 History → Report weekly.

## 6. Cost / benefit vs Plan C (steering §7 + steering §11)

Plan Q at safe $75 risk on a $6k Funded account:
- Take-80: **~Rs 15,229/mo** (~$132.43/mo take-home after $5 EA fee).
- Take-90: ~Rs 17,205/mo (~$149.60/mo).

Plan C at 0.02 lot on the same account (pre-3%-rework):
- Take-80: **~Rs 17,345/mo** (~$150.82/mo).
- Take-90: ~Rs 19,584/mo (~$170.30/mo).

After the required Plan C funded 3%-risk rework (steering §6, §7), Plan C funded income
haircuts by ~20% → ~Rs 13,900–14,000/mo take-80. So the RESIDUAL income gap between the
two plans on FUNDED is small.

But Plan Q's operational load — Python engine on VPS, weekly regeneration, EA restart
cadence, thin daily/static buffers — is significantly higher than Plan C's single-binary
autopilot. Steering §11 recommends Plan C by default. Plan Q is available on explicit
user preference for the QM setup itself, not for income advantage.

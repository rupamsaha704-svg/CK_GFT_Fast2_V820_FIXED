# MT5 Validation Engine - quick reference

Discipline (never bent): MT5 Strategy Tester is the ONLY simulator; Python only reads MT5 output.
Every input pinned (GUARD #20). Current-regime (last ~11 months) is primary + both-halves must agree.
Deposit 50000 (removes the XAUUSD margin wall). Every run logged to `SPEC/dof_ledger.jsonl`. No real money.

Models: `1` = 1-minute OHLC (fast SCREEN). `4` = every tick / real ticks (final TRUTH).

## 1. Warm the tick cache once (fast later runs)
```
powershell -ExecutionPolicy Bypass -File tools\warm_ticks.ps1
```
Checks monthly `.tkc` coverage; downloads only missing months; no-op when warm.
(বাংলা: আগে একবার tick cache গরম করে নাও, পরের রান দ্রুত হবে।)

## 2. Fast-screen a candidate, then confirm on real ticks
```
powershell -ExecutionPolicy Bypass -File tools\screen_confirm.ps1 -Preset experiments\<id>\preset.json
```
Runs a Model-1 screen; if it is not clearly dead, auto-runs the Model-4 real-tick truth + pipeline verdict.
(বাংলা: দ্রুত Model-1 screen; টিকলে তবেই Model-4 real-tick — আসল সত্য।)

## 3. Batch many candidates (all output to files)
```
powershell -ExecutionPolicy Bypass -File tools\run_batch.ps1 -Glob "experiments\*\preset.json"
```
Writes `experiments\_BATCH_LOG.txt` and regenerates `experiments\_ALL_SUMMARY.txt` (MT5-style: trades, net $, PF, win%, maxDD%).

## 4. Parameter PLATEAU / robustness (MT5 native optimization + forward)
```
powershell -ExecutionPolicy Bypass -File tools\run_optimize.ps1 -OptPreset experiments\<id>\opt.json
```
MT5 optimizer maps the whole surface; `parse_opt.py` reports a BROAD plateau + robust CENTRE and an
IS->forward survival rate. The peak pass is shown but NEVER recommended. `plateau_report.txt` is written.
(বাংলা: শুধু plateau/robustness দেখতে — কখনো peak বেছে নয়; forward-এ টেকে কিনা তাই আসল।)

## Verdict ownership
Real-tick (Model 4) + `v1_lab/pipeline.py` (K2/K3 killers, M1/M5/M6/M8, walk-forward, Monte-Carlo,
cost stress via `--cost-per-trade`) own the final PASS / FAIL / REJECT. Screen & optimization only triage.

#!/usr/bin/env python3
"""
Regression suite for the GFT compliance engine.

Every expectation below was recorded INDEPENDENTLY in the hash-chained ledger before this
engine existed, so agreeing with them is real evidence the engine measures reality rather
than agreeing with itself.

Two failure modes are tested deliberately and separately:
  FALSE PASS   - calling a dead account safe. Costs the account.
  FALSE BREACH - calling a compliant strategy dead. Costs a good strategy.

Pure stdlib, reads existing MT5 output only, launches no backtest.
Run:  python tools/test_compliance.py
Exit: 0 all passed, 1 one or more failed.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ROOT, "tools", "gft_compliance.py")

# (name, stage, window, expected_exit, must_contain[], must_NOT_contain[], ledger_ref)
#
# Assertions run against --json output, NOT the human report: the report word-wraps at 68
# columns, so a phrase can be split across lines and a substring search would fail on text the
# engine really did emit. The JSON carries the same detail strings unwrapped.
CASES = [
    ("known BREACH - daily 5% on the compounded account",
     "step1", r"experiments\combo_base2\windows\last1y", 2,
     ['"verdict": "BREACH"', "DAILY DRAWDOWN 5%", "2026-03-23", "-5.22", '"trade_no": 192'],
     [],
     "seq171/seq172 recorded worst day -5.22% on 2026-03-23"),

    ("known GOOD - daily fix applied, must NOT breach",
     "step1", r"experiments\combo_v1_daily45\windows\last1y", 1,
     ["-4.56", "2026-01-30"],
     ['"verdict": "BREACH"'],
     "seq174 recorded worst -4.56% on Jan30 with ZERO days over 5%"),

    ("known Goat Guard candidate - must NOT be asserted as a fired trigger",
     "funded", r"experiments\combo_m4_funded\windows\last1y", 1,
     ["candidate trigger", "106.74"],
     ['"verdict": "BREACH"'],
     "seq181 recorded worst funded trade -106.74"),

    ("shipped funded config - must NOT be called safe on closed-trade data alone",
     "funded", r"experiments\combo_m4_funded2\windows\last1y", 1,
     ["53.37", "does NOT prove safety"],
     ['"verdict": "CLEARED"'],
     "seq182/seq191 recorded worst -53.37, eqDDabs 8.68, 276 trades"),

    ("static floor evidence comes from the floating-inclusive htm figure",
     "funded", r"experiments\combo_m4_funded2\windows\last1y", 1,
     ["Equity Drawdown Absolute 8.68", "MAX OVERALL LOSS 10% STATIC"],
     [],
     "seq182 recorded eqDDabs 8.68"),
]


def run(stage, window):
    p = subprocess.run(
        [sys.executable, ENGINE, "--stage", stage, "--window", window, "--json"],
        cwd=ROOT, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


# ----------------------------------------------------------------------------------
# PART 2 - synthetic fixtures for code paths that NO existing MT5 output exercises.
#
# The five ledger cases above only touch the paths our current data reaches. Several rules were
# written for evidence we do not yet have (equity series, seconds-resolution holds, a news
# calendar), so they had never executed even once. Untested code is an untested assumption, and
# on this project an untested assumption is how an account dies. These fixtures exercise them
# directly, with hand-computed expected answers.
# ----------------------------------------------------------------------------------
import datetime as _dt
import tempfile


def _write(path, text):
    with open(path, "w", newline="") as fh:
        fh.write(text)


def _mkcase(d, trades_rows, equity_rows=None, deals_rows=None, news_rows=None):
    """Build a synthetic window directory. Returns (window_dir, extra_cli_args)."""
    os.makedirs(d, exist_ok=True)
    _write(os.path.join(d, "trades.csv"), "time,profit\n" + "".join(trades_rows))
    extra = []
    if equity_rows is not None:
        p = os.path.join(d, "equity.csv")
        _write(p, "time,equity\n" + "".join(equity_rows))
        extra += ["--equity-series", p]
    if deals_rows is not None:
        p = os.path.join(d, "deals.csv")
        _write(p, "magic,dir,entry_time,entry_price,exit_time,exit_price,profit,volume,hold_sec,mae,mfe\n"
                  + "".join(deals_rows))
        extra += ["--deals", p]
    if news_rows is not None:
        p = os.path.join(d, "news.csv")
        _write(p, "".join(news_rows))
        extra += ["--news-csv", p]
    return d, extra


def _run_raw(stage, window, extra):
    p = subprocess.run(
        [sys.executable, ENGINE, "--stage", stage, "--window", window, "--json"] + extra,
        cwd=ROOT, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def synthetic_cases(tmp):
    """Each entry: (name, stage, builder, expected_exit, need[], forbid[], why)."""
    cases = []

    # --- Goat Guard PASS: combined float never reaches -100 -------------------------------
    def gg_safe(d):
        return _mkcase(d,
                       ["2026.01.05 12:00,-10.00\n", "2026.01.06 12:00,20.00\n",
                        "2026.01.07 12:00,-5.00\n"],
                       equity_rows=["2026.01.05 09:00,5000.00\n", "2026.01.05 11:00,4950.00\n",
                                    "2026.01.05 12:00,4990.00\n", "2026.01.06 09:00,4990.00\n",
                                    "2026.01.06 12:00,5010.00\n", "2026.01.07 09:00,5010.00\n",
                                    "2026.01.07 12:00,5005.00\n"])
    cases.append(("GG exact PASS - combined float worst -50, never reaches -100",
                  "funded", gg_safe, 1,
                  ["never reached", '"measurement": "exact"'],
                  ['"status": "BREACH"', "LIKELY"],
                  "floating = equity - balance; worst dip is -50 so no trigger can have fired"))

    # --- Goat Guard ONE confirmed trigger -------------------------------------------------
    def gg_one(d):
        return _mkcase(d,
                       ["2026.02.03 12:00,-40.00\n", "2026.02.04 12:00,10.00\n"],
                       equity_rows=["2026.02.03 09:00,5000.00\n", "2026.02.03 10:00,4880.00\n",
                                    "2026.02.03 11:00,4990.00\n", "2026.02.03 12:00,4960.00\n",
                                    "2026.02.04 09:00,4960.00\n", "2026.02.04 12:00,4970.00\n"])
    cases.append(("GG exact ONE trigger - float hits -120 once",
                  "funded", gg_one, 1,
                  ["ONE confirmed trigger", '"status": "WARN"'],
                  ['"status": "BREACH"'],
                  "equity 4880 vs balance 5000 = -120 float, one dip below -100"))

    # --- Goat Guard TWO dips -> LIKELY BREACH, blocking but not proven --------------------
    def gg_two(d):
        return _mkcase(d,
                       ["2026.03.02 12:00,-30.00\n", "2026.03.03 12:00,-30.00\n"],
                       equity_rows=["2026.03.02 09:00,5000.00\n", "2026.03.02 10:00,4870.00\n",
                                    "2026.03.02 11:00,4995.00\n", "2026.03.02 12:00,4970.00\n",
                                    "2026.03.03 09:00,4970.00\n", "2026.03.03 10:00,4850.00\n",
                                    "2026.03.03 11:00,4965.00\n", "2026.03.03 12:00,4940.00\n"])
    cases.append(("GG exact TWO dips - must be LIKELY BREACH, never a proven breach",
                  "funded", gg_two, 1,
                  ["LIKELY BREACH", "snapshot"],
                  ['"verdict": "BREACH"', '"verdict": "CLEARED"'],
                  "two separate dips below -100; snapshot rule cannot be settled from this data"))

    # --- daily reference must use max(balance, equity) at the reset ------------------------
    # Day-start balance 5000 but equity 5200 at reset -> reference 5200 -> floor 4940.
    # A -260 day is -5.00% of 5200 -> BREACH. Against balance-only it would be -5.2% too, so to
    # isolate the rule we use -255: -4.90% of 5200 (no breach) but -5.10% of 5000 (would breach).
    def daily_ref(d):
        return _mkcase(d,
                       ["2026.04.06 12:00,-255.00\n", "2026.04.07 12:00,5.00\n",
                        "2026.04.08 12:00,5.00\n"],
                       equity_rows=["2026.04.06 00:00,5200.00\n", "2026.04.06 12:00,4945.00\n",
                                    "2026.04.07 00:00,4745.00\n", "2026.04.07 12:00,4750.00\n",
                                    "2026.04.08 00:00,4750.00\n", "2026.04.08 12:00,4755.00\n"])
    cases.append(("daily reference uses max(balance,equity) at reset - -255 on ref 5200 is NOT a breach",
                  "step1", daily_ref, 1,
                  ["-4.90"],
                  ['"verdict": "BREACH"'],
                  "reference 5200 (equity>balance) -> -255 is -4.90%, inside the 5% limit; "
                  "balance-only reference 5000 would have wrongly read -5.10%"))

    # --- 2-minute rule with EXACT hold_sec ------------------------------------------------
    def micro(d):
        return _mkcase(d,
                       ["2026.05.04 10:02,50.00\n", "2026.05.04 11:10,30.00\n",
                        "2026.05.05 10:30,-20.00\n"],
                       deals_rows=[
                           "111,buy,2026.05.04 10:00,3000.00,2026.05.04 10:02,3050.00,50.00,0.01,119,5.00,60.00\n",
                           "111,buy,2026.05.04 11:00,3000.00,2026.05.04 11:10,3030.00,30.00,0.01,600,4.00,35.00\n",
                           "111,sell,2026.05.05 10:00,3000.00,2026.05.05 10:30,3020.00,-20.00,0.01,1800,22.00,3.00\n"])
    cases.append(("2-min rule EXACT via hold_sec - 119s winner of 50.00 must be stripped",
                  "funded", micro, 1,
                  ["50.00 will be REMOVED", '"measurement": "exact"'],
                  ["ambiguous"],
                  "hold_sec 119 < 120 is certain, no minute-resolution ambiguity"))

    # --- 2-minute rule must NOT apply during evaluation -----------------------------------
    cases.append(("2-min rule must be INFO not WARN during evaluation (funded-only rule)",
                  "step1", micro, 1,
                  ["not applicable during evaluation", "FORWARD-LOOKING EXPOSURE"],
                  ["will be REMOVED at payout"],
                  "GFT confines the 2-minute rule to funded accounts"))

    # --- weekend gap: Friday-late entry closed Monday-early --------------------------------
    # 2026.05.08 is a Friday; 2026.05.11 is the following Monday.
    def wknd(d):
        return _mkcase(d,
                       ["2026.05.11 02:00,40.00\n", "2026.05.12 12:00,10.00\n",
                        "2026.05.13 12:00,10.00\n"],
                       deals_rows=[
                           "111,buy,2026.05.08 22:00,3000.00,2026.05.11 02:00,3040.00,40.00,0.01,100800,3.00,45.00\n",
                           "111,buy,2026.05.12 10:00,3000.00,2026.05.12 12:00,3010.00,10.00,0.01,7200,2.00,12.00\n",
                           "111,buy,2026.05.13 10:00,3000.00,2026.05.13 12:00,3010.00,10.00,0.01,7200,2.00,12.00\n"])
    cases.append(("weekend gap - Fri 22:00 entry closed Mon 02:00 must strip 40.00 on funded",
                  "funded", wknd, 1,
                  ["40.00 will be REMOVED", "Friday's last 3 market hours"],
                  [],
                  "entry Friday >=21:00 and exit Monday <04:00 matches GFT's gap pattern"))

    # --- news window 1% cap ----------------------------------------------------------------
    def news(d):
        return _mkcase(d,
                       ["2026.06.05 15:33,80.00\n", "2026.06.08 12:00,20.00\n",
                        "2026.06.09 12:00,20.00\n"],
                       deals_rows=[
                           "111,buy,2026.06.05 15:31,3000.00,2026.06.05 15:33,3080.00,80.00,0.01,120,2.00,85.00\n",
                           "111,buy,2026.06.08 10:00,3000.00,2026.06.08 12:00,3020.00,20.00,0.01,7200,2.00,22.00\n",
                           "111,buy,2026.06.09 10:00,3000.00,2026.06.09 12:00,3020.00,20.00,0.01,7200,2.00,22.00\n"],
                       news_rows=["2026.06.05 15:30\n"])
    cases.append(("news cap - 80.00 profit inside +/-5min window, 50 cap -> 30.00 removed",
                  "step1", news, 1,
                  ["30.00 of profit exceeds", "per event, per trade or per day"],
                  [],
                  "1% of 5000 = 50 cap; 80-50 = 30 stripped; applies in evaluation too"))

    # --- data integrity: deals that do not reconcile with trades ---------------------------
    def mismatch(d):
        return _mkcase(d,
                       ["2026.07.06 12:00,10.00\n", "2026.07.07 12:00,10.00\n",
                        "2026.07.08 12:00,10.00\n"],
                       deals_rows=[
                           "111,buy,2026.07.06 10:00,3000.00,2026.07.06 12:00,3010.00,99.00,0.01,7200,2.00,12.00\n"])
    cases.append(("data integrity - mismatched deals CSV must be flagged, not silently used",
                  "funded", mismatch, 1,
                  ["does NOT match trades.csv", "different runs"],
                  [],
                  "1 deal netting 99 vs 3 trades netting 30 = different backtests"))

    # --- margin ceiling: 0.09 lot gold on a $5k account must BREACH the 80% rule ------------
    # 0.09 * 100 * 5000 * 0.10 = $4,500 margin = 90% of a $5,000 account. Over the 80% ceiling.
    # This is the shipped EVAL lot (FIX_FixedLot = 0.09), so this test guards a live config.
    def margin_over(d):
        return _mkcase(d,
                       ["2026.08.03 12:00,10.00\n", "2026.08.04 12:00,10.00\n",
                        "2026.08.05 12:00,10.00\n"],
                       deals_rows=[
                           "111,buy,2026.08.03 10:00,5000.00,2026.08.03 12:00,5010.00,10.00,0.09,7200,2.00,12.00\n",
                           "111,buy,2026.08.04 10:00,5000.00,2026.08.04 12:00,5010.00,10.00,0.09,7200,2.00,12.00\n",
                           "111,buy,2026.08.05 10:00,5000.00,2026.08.05 12:00,5010.00,10.00,0.09,7200,2.00,12.00\n"])
    cases.append(("margin ceiling - 0.09 lot gold at 5000 uses 90% margin, must BREACH the 80% rule",
                  "step1", margin_over, 2,
                  ["MARGIN CEILING", "90.0%", '"verdict": "BREACH"'],
                  [],
                  "0.09*100*5000*0.10 = 4500 margin = 90% of 5000; GFT caps usage at 80%"))

    # --- margin ceiling: 0.01 lot (the funded config) must be comfortably inside -------------
    def margin_ok(d):
        return _mkcase(d,
                       ["2026.09.07 12:00,10.00\n", "2026.09.08 12:00,10.00\n",
                        "2026.09.09 12:00,10.00\n"],
                       deals_rows=[
                           "111,buy,2026.09.07 10:00,5000.00,2026.09.07 12:00,5010.00,10.00,0.01,7200,2.00,12.00\n",
                           "111,buy,2026.09.08 10:00,5000.00,2026.09.08 12:00,5010.00,10.00,0.01,7200,2.00,12.00\n",
                           "111,buy,2026.09.09 10:00,5000.00,2026.09.09 12:00,5010.00,10.00,0.01,7200,2.00,12.00\n"])
    cases.append(("margin ceiling - 0.01 lot (funded config) uses 10%, must PASS",
                  "funded", margin_ok, 1,
                  ["10.0%", "well inside"],
                  ['"verdict": "BREACH"'],
                  "0.01*100*5000*0.10 = 500 margin = 10% of 5000, far inside the 80% ceiling"))

    return cases


def run_synthetic():
    print("\n" + "=" * 76)
    print("PART 2 - SYNTHETIC FIXTURES (paths no existing MT5 output reaches)")
    print("=" * 76)
    failed = 0
    with tempfile.TemporaryDirectory(prefix="gftc_") as tmp:
        for i, (name, stage, builder, want_exit, need, forbid, why) in \
                enumerate(synthetic_cases(tmp), 1):
            wdir, extra = builder(os.path.join(tmp, f"case{i}"))
            code, out = _run_raw(stage, wdir, extra)
            problems = []
            if code != want_exit:
                problems.append(f"exit {code}, expected {want_exit}")
            for s in need:
                if s not in out:
                    problems.append(f"missing expected text: {s!r}")
            for s in forbid:
                if s in out:
                    problems.append(f"contains forbidden text: {s!r}")
            if problems:
                failed += 1
                print(f"\n[FAIL] {name}")
                print(f"       why: {why}")
                for p in problems:
                    print(f"       - {p}")
            else:
                print(f"\n[ OK ] {name}")
                print(f"       why: {why}")
    return failed


def main():
    print("=" * 76)
    print("GFT COMPLIANCE ENGINE - REGRESSION SUITE")
    print("  expectations come from the ledger, recorded before this engine existed")
    print("=" * 76)

    failed = 0
    for name, stage, window, want_exit, need, forbid, ref in CASES:
        if not os.path.exists(os.path.join(ROOT, window, "trades.csv")):
            print(f"\n[SKIP] {name}\n       missing: {window}")
            continue

        code, out = run(stage, window)
        problems = []
        if code != want_exit:
            problems.append(f"exit {code}, expected {want_exit}")
        for s in need:
            if s not in out:
                problems.append(f"missing expected text: {s!r}")
        for s in forbid:
            if s in out:
                problems.append(f"contains forbidden text: {s!r}")

        if problems:
            failed += 1
            print(f"\n[FAIL] {name}")
            print(f"       ledger: {ref}")
            for p in problems:
                print(f"       - {p}")
        else:
            print(f"\n[ OK ] {name}")
            print(f"       ledger: {ref}")

    failed += run_synthetic()

    print("\n" + "=" * 76)
    if failed:
        print(f"RESULT: {failed} case(s) FAILED - do not trust the engine until fixed")
    else:
        print("RESULT: all cases passed - ledger-verified paths AND synthetic paths")
    print("=" * 76)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

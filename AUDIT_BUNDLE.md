# v23_live A/B — Audit Bundle (independently verifiable)

Answers the reviewer's 8-point audit request. Everything below is reproducible from immutable
Git objects. The `raw.githubusercontent.com` **branch** URL is CDN-cached (stale up to minutes);
use the authoritative GitHub **contents API** or **full-SHA** raw URLs instead.

## 1. Artifact commit — full 40-char SHA
```
d909b87d031f522dfc772a398fdb0fb649c36f54   (branch: kiro/validation-toolkit)
```
This single commit contains the final EA, run scripts, baseline EA, and regression report together.

## 2. Authoritative verification (NOT CDN-cached) — anyone can run:
```
gh api repos/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/branches/kiro/validation-toolkit --jq .commit.sha
#   -> d909b87d031f522dfc772a398fdb0fb649c36f54

gh api "repos/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/contents/CK_GFT_v23_live.mq5?ref=d909b87d031f522dfc772a398fdb0fb649c36f54" --jq .content | base64 -d | grep -nE "maxPts|DONE_PARTIAL|ORDER_FAIL"
#   -> 127: DONE_PARTIAL ... 130: ORDER_FAIL ... 203: maxPts ...
```
Immutable full-SHA raw URLs (unique per SHA, bypass the stale branch cache):
```
https://raw.githubusercontent.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED/d909b87d031f522dfc772a398fdb0fb649c36f54/CK_GFT_v23_live.mq5
.../d909b87d031f522dfc772a398fdb0fb649c36f54/CK_GFT_v23_ts.mq5
.../d909b87d031f522dfc772a398fdb0fb649c36f54/run_v23live_dump.ps1
.../d909b87d031f522dfc772a398fdb0fb649c36f54/run_v23_ab.ps1
.../d909b87d031f522dfc772a398fdb0fb649c36f54/A_B_REGRESSION_RESULT.md
.../d909b87d031f522dfc772a398fdb0fb649c36f54/v1_lab/ab_baseline.csv
.../d909b87d031f522dfc772a398fdb0fb649c36f54/v1_lab/ab_live.csv
.../d909b87d031f522dfc772a398fdb0fb649c36f54/v1_lab/ab_diff.py
```

## 3. git ls-tree blob IDs @ d909b87
```
CK_GFT_v23_live.mq5    763b136d93181a53b3d6aa1fc4897bf57b752756
CK_GFT_v23_ts.mq5      0f7f6cf4e863ab49203ca503e06bf2665977d1ad
run_v23live_dump.ps1   0e0f341bd4483ae5addc506871d86a5f2fba21e2
run_v23_ab.ps1         daa8f8b8fb3bf1dd9bef8b61fae06c41e2811a14
A_B_REGRESSION_RESULT.md f205dd505fba41dfd86840930a36b4bcee7f2773
```

## 4. SHA-256 of the audited files
```
dbd707401cfa94f33f9ab044ef52daae8510e29afec896104cf5d8e77e48ba2e  CK_GFT_v23_live.mq5
60c2acee565737e9156cf476615692aba75cc72361484ef1155259f97d405e62  CK_GFT_v23_ts.mq5
4fd2e0ac985d813982aa94e859f965f2fc3e00dde594d621dd9625b2d4157fa8  run_v23live_dump.ps1
f7f623490d9c776eb0af3854c052df64b50996e7542d1cf22d1c05cb0c37e17d  run_v23_ab.ps1
0058fece2dda1941e30e91b61db98a8c5da726046aa6da58c60682a941b8fc4a  A_B_REGRESSION_RESULT.md
8b58d6a573dbe2c638af31b8a374ef5ae6e58191168ddc0c3b13325f46ab80a9  v1_lab/ab_baseline.csv  (= v23_ts trades)
cc1480e16e24805981542c57463c85e81a388017c67d9551cf9cc61481dc8bff  v1_lab/ab_live.csv      (= ck_v23live trades)
8f1d77c978e4e0f26354f9e424af5be730a6afbddaa472e4f97196d07f195beb  v1_lab/ab_diff.py
```

## 5. Exact diff script + stdout
Script: `v1_lab/ab_diff.py`. Run: `python3 v1_lab/ab_diff.py v1_lab/ab_baseline.csv v1_lab/ab_live.csv`
```
baseline: 203 trades  net 5760.71
live    : 200 trades  net 6123.23

trades in BASELINE but NOT in live (3):
    2026.03.02 13:45 -183.69
    2026.05.25 07:25 -67.86
    2026.07.03 17:08 -110.97

trades in LIVE but NOT in baseline (0):

common timestamps: 200   profit-mismatches on common: 0
```

## 6. Tester log (from the same-session run that produced ab_live.csv)
```
[v23live] digits=2 point=0.01000 old60Price=0.60000 newMaxPrice=0.60000 maxSpreadPts=60 (baseline=60)
[v23live] safety triggers: spreadFiltered=194 spreadDivergence=0 subMinSkips=0 orderRejects=2
[v23live] ORDER_FAIL tag=BUY sent=false rc=10018 "market closed" deal=0 order=0   (each reject; retcode 10018 = TRADE_RETCODE_MARKET_CLOSED)
```
(The dump surfaced up to 6 ORDER_FAIL lines pooled across recent log files; the authoritative
count for THIS run is `orderRejects=2` from OnTester.)

## 7. Provenance
`git rev-parse HEAD` = `d909b87d031f522dfc772a398fdb0fb649c36f54` = `gh api ... branches` tip.
The report, both CSVs, the diff script and both EAs are all in this same commit tree (section 3),
so the test source and the report source are identical.

## 8. HONEST scope of what is proven (do not overstate)
- **Verified:** exit-deal identity — 200/200 common trades match on timestamp AND profit to the cent;
  v23_live is a strict subset of v23_ts (0 live-only trades); it skips exactly 3 trades, all losers
  (−362.52 total = the entire net delta). spreadDivergence=0, subMinSkips=0.
- **NOT independently verified:** per-trade entry-time / direction / lot / SL / TP identity. v23_ts does
  NOT emit a detail CSV, so no baseline detail exists to diff against. v23_live emits
  `ck_v23live_regression_detail.csv`, but a true detailed A/B requires adding the same detail dump to
  v23_ts and re-running both. The exit-level identity above is strong evidence of strategy identity but
  is not an entry-level proof.
- **Not attributed per-trade:** which specific safety branch caused each of the 3 skips is not proven
  from exit data alone; the tester logged `market closed` rejections but a definitive mapping needs the
  entry-side detail on both EAs.
- **Not a live-edge claim:** this preserves the validated *backtest*. Backtest ≠ live. Deploy on DEMO first.

### To upgrade to an entry-level PASS
Add the detail dump to `CK_GFT_v23_ts.mq5`, re-run both back-to-back (run_v23_ab pattern), and diff
`ck_v23ts_detail.csv` vs `ck_v23live_regression_detail.csv` on position_id/entry/side/volume/SL/TP.

#!/usr/bin/env python3
"""
parse_opt.py - read MT5's exported optimization XML (SpreadsheetML) and diagnose PLATEAU/robustness.

PHILOSOPHY (anti-overfit): a real edge is INSENSITIVE to small parameter changes -> it shows up as a
BROAD contiguous region of profitable passes (a plateau). An overfit edge is a lone SPIKE: one magic
combo wins, neighbours lose. This tool maps the whole surface and reports the plateau. It DELIBERATELY
does NOT hand back "the best pass" as a recommendation - the peak is printed only, labelled do-not-pick.
If a forward XML is given, it measures how many in-sample-profitable combos stay profitable forward
(the honest overfit test).

Usage:
  python tools/parse_opt.py --xml opt_results.xml --sweep InpTrendEMA,InpBreakoutLookback
         [--forward opt_results_forward.xml] [--out plateau_report.txt]
"""
import argparse, sys, xml.etree.ElementTree as ET
from collections import defaultdict
from statistics import median

SS = "{urn:schemas-microsoft-com:office:spreadsheet}"


def read_rows(path):
    """Return list of rows; each row is a list of string cell values (ss:Index gaps filled with '')."""
    with open(path, "rb") as fh:
        data = fh.read()
    root = ET.fromstring(data)                       # ET honours the XML encoding declaration (utf-16)
    table = root.find(f".//{SS}Worksheet/{SS}Table")
    if table is None:
        table = root.find(f".//{SS}Table")
    if table is None:
        raise SystemExit("parse_opt: no <Table> found - not an MT5 optimization XML?")
    rows = []
    for r in table.findall(f"{SS}Row"):
        cells = []
        col = 0
        for c in r.findall(f"{SS}Cell"):
            idx = c.get(f"{SS}Index")
            if idx:
                col = int(idx) - 1                    # ss:Index is 1-based; fill skipped columns
                while len(cells) < col:
                    cells.append("")
            d = c.find(f"{SS}Data")
            cells.append(d.text if (d is not None and d.text is not None) else "")
            col += 1
        rows.append(cells)
    return rows


def to_num(s):
    try:
        return float(str(s).replace(" ", "").replace(",", ""))
    except Exception:
        return None


def col_index(header, *needles, avoid=()):
    """Find the first header cell containing all needles (case-insensitive) and none of `avoid`."""
    for i, h in enumerate(header):
        hl = h.lower()
        if all(n in hl for n in needles) and not any(a in hl for a in avoid):
            return i
    return None


def load(path, sweep_names):
    rows = [r for r in read_rows(path) if any(str(x).strip() for x in r)]
    if not rows:
        raise SystemExit("parse_opt: empty XML")
    header = rows[0]
    ci_profit = col_index(header, "profit", avoid=("factor",))
    ci_pf     = col_index(header, "profit", "factor") or col_index(header, "factor")
    ci_trades = col_index(header, "trades")
    ci_dd     = col_index(header, "drawdown") or col_index(header, "dd")
    param_ci  = {}
    for nm in sweep_names:
        for i, h in enumerate(header):
            if h.strip() == nm:
                param_ci[nm] = i
                break
    passes = []
    for r in rows[1:]:
        def g(ci):
            return to_num(r[ci]) if (ci is not None and ci < len(r)) else None
        prof = g(ci_profit)
        if prof is None:
            continue
        params = {}
        ok = True
        for nm, ci in param_ci.items():
            v = g(ci)
            if v is None:
                ok = False; break
            params[nm] = v
        if not ok:
            continue
        passes.append(dict(profit=prof, pf=g(ci_pf), trades=g(ci_trades), dd=g(ci_dd), params=params))
    return header, passes, param_ci


def plateau_for_param(passes, nm):
    """Median profit per value of one parameter; return sorted (value, median_profit, n) and the widest
    contiguous run of values whose median profit > 0."""
    by_val = defaultdict(list)
    for p in passes:
        by_val[p["params"][nm]].append(p["profit"])
    vals = sorted(by_val)
    rows = [(v, median(by_val[v]), len(by_val[v])) for v in vals]
    best_run, cur = [], []
    for v, m, n in rows:
        if m > 0:
            cur.append(v)
            if len(cur) > len(best_run):
                best_run = cur[:]
        else:
            cur = []
    return rows, best_run


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--xml", required=True)
    ap.add_argument("--forward", default=None)
    ap.add_argument("--sweep", required=True, help="comma-separated optimized input names")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    sweep = [s.strip() for s in a.sweep.split(",") if s.strip()]

    _, passes, param_ci = load(a.xml, sweep)
    out = []
    def w(s=""):
        out.append(s); print(s)

    w("=" * 68)
    w("MT5 OPTIMIZATION - PLATEAU / ROBUSTNESS DIAGNOSIS (not a peak-picker)")
    w("=" * 68)
    if not passes:
        w("no parsable passes"); _flush(a.out, out); sys.exit(1)
    missing = [nm for nm in sweep if nm not in param_ci]
    if missing:
        w(f"WARNING: sweep columns not found in XML header: {', '.join(missing)}")

    n = len(passes)
    prof_pos = sum(1 for p in passes if p["profit"] > 0)
    pf_ok = sum(1 for p in passes if (p["pf"] or 0) >= 1.0)
    profits = sorted(p["profit"] for p in passes)
    w(f"passes parsed          : {n}")
    w(f"profitable passes      : {prof_pos}/{n} = {100*prof_pos/n:.0f}%   (broad % => robust plateau)")
    w(f"PF>=1.0 passes         : {pf_ok}/{n} = {100*pf_ok/n:.0f}%")
    w(f"profit  median / min / max : {median(profits):.0f} / {profits[0]:.0f} / {profits[-1]:.0f}")
    w("")

    plateau_center = {}
    for nm in param_ci:
        rows, run = plateau_for_param(passes, nm)
        w(f"[{nm}] median-profit by value (plateau = contiguous >0 band):")
        for v, m, cnt in rows:
            flag = "  <== plateau" if v in run else ""
            w(f"    {v:>10.4g} : median {m:>10.0f}  (n={cnt}){flag}")
        if run:
            center = run[len(run) // 2]
            plateau_center[nm] = center
            w(f"    -> plateau width {len(run)}/{len(rows)} values; robust centre = {center:g}")
        else:
            w(f"    -> NO positive plateau for {nm} (fragile on this axis)")
        w("")

    # peak (shown only, never recommended)
    peak = max(passes, key=lambda p: p["profit"])
    w("PEAK pass (DO NOT cherry-pick - shown for reference only):")
    w(f"    profit {peak['profit']:.0f}  PF {peak['pf']}  trades {peak['trades']}  params {peak['params']}")
    if plateau_center:
        w(f"ROBUST plateau-centre parameters (marginal): {plateau_center}")
    w("")

    # forward cross-check (the real overfit test)
    verdict = "MIXED"
    if a.forward:
        _, fpasses, _ = load(a.forward, sweep)
        fwd = {}
        for p in fpasses:
            key = tuple(sorted(p["params"].items()))
            fwd[key] = p["profit"]
        is_pos = [p for p in passes if p["profit"] > 0]
        survived = 0; checked = 0
        for p in is_pos:
            key = tuple(sorted(p["params"].items()))
            if key in fwd:
                checked += 1
                if fwd[key] > 0:
                    survived += 1
        rate = (100 * survived / checked) if checked else 0
        w(f"FORWARD cross-check    : {survived}/{checked} in-sample-profitable combos stay profitable forward = {rate:.0f}%")
        broad = (100 * prof_pos / n) >= 60 and any(len(plateau_for_param(passes, nm)[1]) >= 3 for nm in param_ci)
        if rate >= 50 and broad:
            verdict = "ROBUST-ish (broad plateau + forward-stable) -> worth a Model-4 real-tick confirm"
        elif rate < 30 or prof_pos / n < 0.3:
            verdict = "FRAGILE / OVERFIT (spike-only or forward collapses) -> REJECT"
    else:
        if (prof_pos / n) < 0.3:
            verdict = "FRAGILE (few profitable passes; likely spike) -> REJECT"
        elif (prof_pos / n) >= 0.6 and any(len(plateau_for_param(passes, nm)[1]) >= 3 for nm in param_ci):
            verdict = "BROAD plateau in-sample (add --forward to test overfit) -> candidate for Model-4 confirm"

    w("-" * 68)
    w(f"PLATEAU VERDICT: {verdict}")
    w("NOTE: this is a robustness diagnosis only. Real-tick (Model 4) + the deterministic")
    w("      pipeline still own the final PASS/FAIL. Never deploy the peak pass.")
    _flush(a.out, out)


def _flush(path, lines):
    if path:
        with open(path, "w", encoding="ascii", errors="replace") as fh:
            fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()

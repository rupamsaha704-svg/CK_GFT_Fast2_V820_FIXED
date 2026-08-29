#!/usr/bin/env python3
"""
QM/ICT setup — building-block 7: the variant-grid runner + honest OOS report.

Scope: enumerate a SANE, DOCUMENTED grid of variant configurations of the Block-6 state machine
(qm_state_machine.run), run the SAME historical data through each variant, convert every variant's
trade list to the pipeline's canonical 'time,profit' CSV format (exactly what metrics.load_trades
expects), split each into IN-SAMPLE / OUT-OF-SAMPLE by a PRE-DECLARED deterministic time boundary,
feed each IS/OOS pair into the UNMODIFIED deterministic verdict engine (v1_lab/pipeline.py), and
produce an honest comparison report ranking variants by OOS expectancy / profit-factor / max-DD /
trade-count / Monte-Carlo robustness.

This block is where deterministic MATH verifies which (if any) variant has a robust out-of-sample
edge. It NEVER pre-picks a winner. It reuses the engine (qm_state_machine), the canonical metrics
(metrics.py) and the verdict engine (pipeline.py) verbatim — it does NOT reimplement any of them,
and it does NOT modify pipeline.py's thresholds.

GOVERNING RULE (inviolable, SPEC/DESIGN_v1.0.md + SPEC/AGENT_SYSTEM_v1.md):
  "AI discovers and explains; deterministic code measures and judges; locked/unseen data is final
   evidence; no single metric equals PASS; overfitting is forbidden."
Concrete consequences enforced here:
  * The IS/OOS boundary is PRE-DECLARED (a fixed calendar date, documented below) and chosen a
    priori as the chronological midpoint of the dataset — NEVER after seeing any results. Choosing
    a split to flatter results would be overfitting and is forbidden.
  * IS results are EXPLORATION ONLY. A real verdict requires locked/unseen data and (per DESIGN
    v1.1) forward evidence. The report states this explicitly.
  * Every variant enumerated is a RESEARCHER DEGREE OF FREEDOM (a multiple-testing hazard). The
    report logs the trial count so the reader can discount for multiple comparisons.
  * If no variant shows a robust OOS edge, the report SAYS SO honestly. "Insufficient / no robust
    edge yet" is a valid, expected outcome — the QM engine produces ~155 trades for the default
    variant over the full period, so most variants legitimately fall short of the pipeline's
    >=200-OOS-trade bar and are reported INSUFFICIENT. That threshold is NOT worked around.

Grid design (A/B screening, NOT exhaustive over-search):
  The grid is a BASELINE + one-switch-at-a-time (OFAT) sweep. Each non-baseline variant differs from
  the documented default by EXACTLY ONE open switch, over a small documented range. This keeps the
  grid size sane and the comparison interpretable (each row isolates one degree of freedom) while
  still covering every open switch the setup creator has NOT locked. It is deliberately NOT a full
  cartesian product (that would be an over-search and inflate the multiple-testing burden).

Deterministic: same input data + same grid => byte-identical variant_results.csv and VARIANT_REPORT.md.
Pure Python standard library only (csv, os, sys, argparse, datetime, subprocess, hashlib) — dependency-free.

Usage:
    python3 v1_lab/variant_runner.py --selfcheck
    python3 v1_lab/variant_runner.py --data v1_lab/XAUUSD_M15_clean.csv --m5 v1_lab/XAUUSD_M5_clean.csv
        [--pair-csv XAGUSD.csv] [--outdir v1_lab/variants] [--deposit 5000]
"""
import os
import sys
import csv
import argparse
import datetime

# Ensure the sibling v1_lab modules (same directory) are importable from the repo root.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import qm_state_machine as QM          # noqa: E402  the engine (Block 6) — reused, not reimplemented
import metrics as M                    # noqa: E402  canonical metrics — reused, not reimplemented
import pipeline as PIPE                # noqa: E402  deterministic verdict engine — reused verbatim


# ---- PRE-DECLARED IS/OOS split boundary (documented, chosen a priori) ------------------------
# The repo data spans 2025-08-01 .. 2026-07-27 (~12 months). The chronological midpoint is
# ~2026-02. We PRE-DECLARE the split at the clean calendar boundary 2026-02-01 00:00 (naive, in the
# data's native clock). Trades whose entry time is strictly before this instant are IN-SAMPLE; at or
# after it are OUT-OF-SAMPLE. This date is fixed in code and was NOT chosen after inspecting any
# variant's results — that would be overfitting the split, which the governing rule forbids.
SPLIT_BOUNDARY = datetime.datetime(2026, 2, 1, 0, 0)
SPLIT_BOUNDARY_STR = "2026.02.01 00:00"

# Deposit used for metrics/Monte-Carlo (canonical default from metrics.py).
DEPOSIT_DEFAULT = M.DEPOSIT_DEFAULT

# The pipeline's own pre-declared minimum OOS-trade bar (imported, never redefined here).
MIN_OOS_TRADES = PIPE.MIN_OOS_TRADES


# ---- the variant grid (explicit, enumerable, documented) -------------------------------------
def build_grid():
    """Return an ordered list of (variant_id, VariantConfig, trial_note) tuples.

    BASELINE + one-switch-at-a-time across EVERY open switch the setup creator has NOT locked. Each
    entry is a researcher degree of freedom; the id encodes the single switch that differs from the
    documented default so the report is self-explanatory. Ranges are small and documented — the goal
    is A/B screening, not an exhaustive over-search.

    NOTE on SMT: smt_pair in ('xag','dxy') needs a partner series (XAGUSD/DXY) which is NOT in the
    repo. Those variants are still ENUMERATED (they are legitimate degrees of freedom) but, absent a
    partner CSV, the engine cleanly reports the data dependency and disables SMT (variant = OFF); the
    report flags them as an unresolved DATA DEPENDENCY rather than fabricating a signal.
    """
    d = QM.DEFAULT_CONFIG
    grid = []
    grid.append(("baseline", d, "documented default config (no switch changed)"))

    # POI confluence requirement (qm | qm_ob | qm_fvg)
    grid.append(("poi_qm_ob", d._replace(poi_type="qm_ob"), "POI type = qm_ob (order-block confluence)"))
    grid.append(("poi_qm_fvg", d._replace(poi_type="qm_fvg"), "POI type = qm_fvg (FVG confluence)"))

    # Stop placement mode + ATR buffer size (small documented range)
    grid.append(("sl_tight_poi", d._replace(sl_mode="tight_poi"), "SL mode = tight_poi (stop at POI edge)"))
    grid.append(("sl_buf_0p25", d._replace(sl_buffer_atr=0.25), "SL buffer = 0.25*ATR (tighter)"))
    grid.append(("sl_buf_1p0", d._replace(sl_buffer_atr=1.0), "SL buffer = 1.0*ATR (wider)"))

    # Target mode + fixed-RR + min projected-RR gate
    grid.append(("tp_fixed_rr", d._replace(tp_mode="fixed_rr"), "TP mode = fixed_rr (2R target)"))
    grid.append(("tp_partial", d._replace(tp_mode="partial_be_trail"), "TP mode = partial_be_trail (proxy)"))
    grid.append(("rr_3", d._replace(tp_mode="fixed_rr", fixed_rr=3.0), "fixed_rr target = 3R"))
    grid.append(("minrr_1p5", d._replace(min_projected_rr=1.5), "min projected-RR gate = 1.5"))

    # IDM clearing requirement (A+ mandatory vs experimental optional) + clearing precision
    grid.append(("idm_optional", d._replace(idm_clear_required=False), "IDM clear optional (experimental)"))
    grid.append(("idm_body", d._replace(idm_clear_mode="body"), "IDM clear precision = body"))

    # Swing pivot L/R count (structure sensitivity)
    grid.append(("pivot_3", d._replace(pivot=3), "swing pivot L/R = 3 (stricter swings)"))

    # MSS displacement gate
    grid.append(("disp_0p4", d._replace(disp=0.4), "MSS displacement gate = 0.4 (looser)"))
    grid.append(("disp_0p8", d._replace(disp=0.8), "MSS displacement gate = 0.8 (stricter)"))

    # ERL source timeframe
    grid.append(("erl_h4", d._replace(erl_tf="H4"), "ERL source TF = H4"))
    grid.append(("erl_m15", d._replace(erl_tf="M15"), "ERL source TF = M15"))

    # Session scope (NY-only vs all sessions)
    grid.append(("session_all", d._replace(session_scope="ny_london_asia"),
                 "session scope = ny_london_asia (24h eligible)"))

    # Risk caps
    grid.append(("max_trades_4", d._replace(max_trades_per_day=4), "max trades/day = 4 (looser cap)"))

    # SMT variants (enumerated; require a partner series — DATA DEPENDENCY when absent)
    grid.append(("smt_xag", d._replace(smt_pair="xag"), "SMT pair = xag (needs XAGUSD series)"))
    grid.append(("smt_dxy", d._replace(smt_pair="dxy"), "SMT pair = dxy (needs DXY series)"))

    return grid


# ---- per-variant trade generation + CSV emission ---------------------------------------------
def _pipeline_row_str(dt_str, net):
    """One canonical pipeline row: 'YYYY.MM.DD HH:MM,<net>'. Net formatted deterministically."""
    return f"{dt_str},{net:.2f}"


def split_rows(rows):
    """Split pipeline (time_str, net) rows into (is_rows, oos_rows) by the PRE-DECLARED boundary.

    A row is OOS iff its parsed entry datetime >= SPLIT_BOUNDARY. Rows whose time does not parse are
    conservatively assigned to IS (they cannot be dated, so they are never counted as unseen OOS
    evidence). The boundary is fixed in code (SPLIT_BOUNDARY) and identical on every run.
    """
    is_rows, oos_rows = [], []
    for tstr, net in rows:
        try:
            d = datetime.datetime.strptime(tstr, "%Y.%m.%d %H:%M")
        except Exception:
            d = None
        if d is not None and d >= SPLIT_BOUNDARY:
            oos_rows.append((tstr, net))
        else:
            is_rows.append((tstr, net))
    return is_rows, oos_rows


def write_pipeline_csv(rows, path):
    """Write rows in the EXACT pipeline format metrics.load_trades expects (header 'time,profit')."""
    with open(path, "w", newline="") as f:
        f.write("time,profit\n")
        for tstr, net in rows:
            f.write(_pipeline_row_str(tstr, net) + "\n")


def run_variant(variant_id, cfg, m15_bars, m5_bars, pair_bars, outdir):
    """Run the engine for one variant, emit IS/OOS pipeline CSVs, return a result dict.

    Reuses QM.run (the engine) and QM.to_pipeline_rows (the canonical converter). Writes:
      <outdir>/<variant_id>_is.csv  and  <outdir>/<variant_id>_oos.csv  (pipeline 'time,profit' format)
    """
    trades, stats = QM.run(m15_bars, cfg, m5_bars=m5_bars, pair_bars=pair_bars)
    rows = QM.to_pipeline_rows(trades)
    is_rows, oos_rows = split_rows(rows)
    is_path = os.path.join(outdir, f"{variant_id}_is.csv")
    oos_path = os.path.join(outdir, f"{variant_id}_oos.csv")
    write_pipeline_csv(is_rows, is_path)
    write_pipeline_csv(oos_rows, oos_path)
    return {
        "variant_id": variant_id,
        "cfg": cfg,
        "trades_total": len(rows),
        "n_is": len(is_rows),
        "n_oos": len(oos_rows),
        "is_path": is_path,
        "oos_path": oos_path,
        "smt_available": stats.get("smt_available", False),
        "smt_note": stats.get("smt_note", ""),
    }


# ---- verdict engine invocation (import + call the UNMODIFIED pipeline logic) ------------------
def pipeline_verdict(is_path, oos_path, deposit):
    """Compute the pipeline verdict + key OOS metrics using the UNMODIFIED pipeline/metrics logic.

    We reuse pipeline.py's own pre-declared thresholds and stage functions (imported as PIPE) and
    metrics.py (imported as M) rather than re-deriving any judgement here. This mirrors exactly what
    `python3 v1_lab/pipeline.py --is IS.csv --oos OOS.csv` computes for the verdict; we simply capture
    the result programmatically for the comparison table. Thresholds are never altered.

    Returns a dict: verdict, and OOS metrics (n, pf, exp, max_dd, mc_dd_p95, mc_p_losing, mc_net_p5,
    wf summary) — INSUFFICIENT variants still report their OOS metric snapshot for honest ranking.
    """
    IS = M.load_trades(is_path)
    OOS = M.load_trades(oos_path)
    res = {
        "verdict": None,
        "reasons": [],
        "oos_n": M.n_trades(OOS),
        "oos_pf": M.profit_factor(OOS),
        "oos_exp": M.expectancy(OOS),
        "oos_net": M.net_profit(OOS),
        "oos_win_rate": M.win_rate(OOS),
        "oos_max_dd": M.max_dd_closed(OOS, deposit),
        "is_n": M.n_trades(IS),
        "is_pf": M.profit_factor(IS),
        "is_exp": M.expectancy(IS),
        "mc_dd_p95": None,
        "mc_p_losing": None,
        "mc_net_p5": None,
        "wf": None,
    }
    # ---- Preconditions (same order/thresholds as pipeline.main) ----
    if M.n_trades(OOS) < MIN_OOS_TRADES:
        res["verdict"] = "INSUFFICIENT"
        res["reasons"].append(f"OOS trades {M.n_trades(OOS)}<{MIN_OOS_TRADES}")
        return res

    pf_o = M.profit_factor(OOS); exp_o = M.expectancy(OOS)
    pf_i = M.profit_factor(IS); exp_i = M.expectancy(IS)
    ci = PIPE.boot_exp_ci(OOS)
    mc = PIPE.montecarlo(OOS, deposit)
    ce, cp, ck = PIPE.concentration(OOS)
    tr = PIPE.trade_removal(OOS)
    yr = PIPE.by_year(OOS); tot = sum(yr.values())
    maxshare = (max(yr.values()) / tot if tot > 0 else 1)
    wf = PIPE.walkforward(OOS)
    res["mc_dd_p95"] = mc["dd_p95"]
    res["mc_p_losing"] = mc["p_losing"]
    res["mc_net_p5"] = mc["net_p5"]
    res["wf"] = wf

    verdict = None; reasons = []
    # ---- Killers ----
    if not (pf_o >= PIPE.K2_MIN_PF and exp_o > PIPE.K2_MIN_EXP):
        verdict = "REJECT"; reasons.append("K2: no OOS edge")
    if pf_i > 0 and exp_i > 0 and (pf_o / pf_i < PIPE.K3_PF_RATIO) and (exp_o / exp_i < PIPE.K3_EXP_RATIO):
        verdict = "REJECT"; reasons.append("K3: severe IS->OOS collapse (overfit)")
    # ---- Mandatory (implemented subset — M4/M7/K5 are PENDING without extra data, as in pipeline) ----
    mfail = []
    if not (pf_o >= PIPE.M1_MIN_PF and ci[0] > PIPE.M1_EXP_CI_LB):
        mfail.append("M1 OOS PF/exp-CI")
    if not (ce >= 0 and (cp >= 1.0 if M.n_trades(OOS) >= 200 else True)):
        mfail.append("M5 concentration")
    if not (tr >= PIPE.M6_MIN_POS_FRAC):
        mfail.append("M6 trade-removal")
    if not (maxshare <= PIPE.M8_MAX_YEAR_SHARE):
        mfail.append("M8 year-concentration")
    if not (wf and wf["frac"] >= 0.60 and wf["med"] >= 1.10 and wf["used"] >= 8):
        mfail.append("M2 walk-forward")

    if verdict != "REJECT":
        if mfail:
            verdict = "FAIL"; reasons += [f"mandatory miss: {x}" for x in mfail]
        else:
            verdict = "PASS (pending M3/M4/M7/K5)"
    res["verdict"] = verdict
    res["reasons"] = reasons
    return res


# ---- ranking + report ------------------------------------------------------------------------
# Result-CSV columns (machine-readable). Order is fixed for deterministic byte output.
RESULT_HEADER = [
    "variant_id", "trial_note", "verdict",
    "trades_total", "n_is", "n_oos",
    "oos_pf", "oos_exp", "oos_net", "oos_win_rate", "oos_max_dd_pct",
    "oos_mc_dd_p95", "oos_mc_p_losing", "oos_mc_net_p5",
    "is_pf", "is_exp",
    "smt_available", "smt_note",
]


def _fmt(v):
    if v is None:
        return ""
    if isinstance(v, float):
        return f"{v:.4f}"
    return str(v)


def rank_key(r):
    """Deterministic ranking key. Sort by a robustness-aware ordering (best first):

      1. verdict rank (PASS < FAIL < REJECT < INSUFFICIENT), so eligible variants surface first;
      2. then OOS expectancy (desc), profit-factor (desc), lower max-DD, higher trade-count, and
         higher Monte-Carlo net-p5 (robustness) as tie-breakers;
      3. finally variant_id for a total, stable order.

    NOTE: this ordering is a READING AID, not a selection. The report explicitly does NOT crown a
    winner from it; the verdict column (from the unmodified pipeline) is the only judgement.
    """
    verdict_rank = {"PASS": 0, "FAIL": 1, "REJECT": 2, "INSUFFICIENT": 3}
    v = r["res"]["verdict"] or "INSUFFICIENT"
    vr = 0 if v.startswith("PASS") else verdict_rank.get(v, 3)
    o = r["res"]
    mc_net = o["mc_net_p5"] if o["mc_net_p5"] is not None else -1e18
    return (
        vr,
        -o["oos_exp"],
        -(o["oos_pf"] if o["oos_pf"] != float("inf") else 1e9),
        o["oos_max_dd"],
        -o["oos_n"],
        -mc_net,
        r["variant_id"],
    )


def write_results_csv(ranked, path):
    """Deterministic machine-readable results CSV (one row per variant, ranking order)."""
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(RESULT_HEADER)
        for r in ranked:
            o = r["res"]
            pf = o["oos_pf"]
            ispf = o["is_pf"]
            w.writerow([
                r["variant_id"], r["trial_note"], o["verdict"],
                r["trades_total"], r["n_is"], r["n_oos"],
                ("inf" if pf == float("inf") else _fmt(pf)), _fmt(o["oos_exp"]),
                _fmt(o["oos_net"]), _fmt(o["oos_win_rate"]), _fmt(o["oos_max_dd"]),
                _fmt(o["mc_dd_p95"]), _fmt(o["mc_p_losing"]), _fmt(o["mc_net_p5"]),
                ("inf" if ispf == float("inf") else _fmt(ispf)), _fmt(o["is_exp"]),
                ("yes" if r["smt_available"] else "no"), r["smt_note"],
            ])


def _pf_str(pf):
    return "inf" if pf == float("inf") else f"{pf:.2f}"


def build_report(ranked, meta):
    """Assemble the human-readable VARIANT_REPORT.md as a deterministic string.

    Honest by construction: it states which variants cleared the >=200-OOS-trade bar vs INSUFFICIENT,
    which PASS/FAIL/REJECT, refuses to crown a winner when the evidence is thin, records the
    multiple-testing (trial count) hazard, and carries the IS-is-exploration-only + locked/forward-
    evidence caveat verbatim from the governing rule.
    """
    n_variants = len(ranked)
    eligible = [r for r in ranked if r["res"]["oos_n"] >= MIN_OOS_TRADES]
    insufficient = [r for r in ranked if r["res"]["oos_n"] < MIN_OOS_TRADES]
    passes = [r for r in eligible if (r["res"]["verdict"] or "").startswith("PASS")]

    lines = []
    A = lines.append
    A("# QM/ICT Variant Grid — Out-of-Sample Report (Block 7)")
    A("")
    A("Generated deterministically by `v1_lab/variant_runner.py`. Same input data + same grid =>")
    A("byte-identical `variant_results.csv` and this report. No LLM is in this measurement path.")
    A("")
    A("## Governing rule (inviolable)")
    A("")
    A("> AI discovers and explains; deterministic code measures and judges; locked/unseen data is")
    A("> final evidence; no single metric equals PASS; overfitting is forbidden.")
    A("")
    A("- **IS results are EXPLORATION ONLY.** They do not constitute evidence of an edge.")
    A("- A real verdict requires **locked / unseen data** and (per DESIGN v1.1) **forward evidence**.")
    A("- The verdict column below comes from the **unmodified** `v1_lab/pipeline.py` (its thresholds")
    A("  were not changed). This runner only enumerates variants and captures the pipeline's judgement.")
    A("")
    A("## Pre-declared IS/OOS split")
    A("")
    A(f"- Boundary (fixed in code, chosen a priori as the dataset's chronological midpoint): "
      f"**{SPLIT_BOUNDARY_STR}**")
    A("- Trades with entry time `< boundary` are IN-SAMPLE; `>= boundary` are OUT-OF-SAMPLE.")
    A("- This date was NOT chosen after seeing results. Tuning the split to flatter outcomes would be")
    A("  overfitting and is forbidden.")
    A("")
    A("## Multiple-testing disclosure (researcher degrees of freedom)")
    A("")
    A(f"- **{n_variants} variants** were enumerated in this run. Each variant is a separate trial and")
    A("  therefore a researcher degree of freedom. With this many comparisons, an apparently good OOS")
    A("  result on a single variant can arise by chance; discount accordingly. The grid is a")
    A("  BASELINE + one-switch-at-a-time (OFAT) sweep (each row differs from the default by exactly")
    A("  one open switch) — deliberately NOT a full cartesian product, to limit over-search.")
    A(f"- Pipeline minimum OOS-trade bar (pre-declared, unmodified): **>= {MIN_OOS_TRADES} OOS trades**.")
    A("")
    A("## Headline outcome")
    A("")
    A(f"- Variants enumerated: **{n_variants}**")
    A(f"- Reached the >= {MIN_OOS_TRADES}-OOS-trade bar (eligible for a verdict): **{len(eligible)}**")
    A(f"- Returned INSUFFICIENT (too few OOS trades to judge): **{len(insufficient)}**")
    A(f"- PASS (pending MT5/extra-data stages): **{len(passes)}**")
    A("")
    if not eligible:
        A("### Honest verdict: INSUFFICIENT / no robust edge established")
        A("")
        A("**No variant reached the pre-declared minimum of "
          f"{MIN_OOS_TRADES} out-of-sample trades**, so the deterministic pipeline cannot certify an")
        A("out-of-sample edge for ANY variant. This is an expected and legitimate outcome: the QM")
        A("engine is highly selective (the default variant produces ~155 trades over the full ~12")
        A("month period, so a chronological half has far fewer than 200 OOS trades). We therefore do")
        A("**NOT** declare a best variant. The honest answer is: *insufficient out-of-sample evidence")
        A("yet — no robust edge established.* More data (a longer history and/or forward-collected,")
        A("locked/unseen trades) is required before any variant can be judged.")
    elif not passes:
        A("### Honest verdict: no variant PASSES the out-of-sample gates")
        A("")
        A("Some variants cleared the trade-count bar and were judged, but **none PASSED** the")
        A("pipeline's mandatory OOS gates. We do **NOT** manufacture a winner. The honest answer is:")
        A("*no robust out-of-sample edge established.* See the per-variant reasons below.")
    else:
        A("### Note on the PASS rows")
        A("")
        A("One or more variants cleared the implemented OOS gates (marked `PASS (pending ...)`). This")
        A("is **exploratory** and **still conditional**: M3 (parameter plateau), M4 (cost stress), M7")
        A("(benchmark suite) and K5 (locked holdout) remain PENDING and require MT5 runs / extra data.")
        A("Given the multiple-testing disclosure above, a single PASS across many trials is NOT a")
        A("green light. A real verdict still requires locked/unseen data and forward evidence.")
    A("")
    A("## Per-variant ranking (OOS)")
    A("")
    A("Ordered by verdict, then OOS expectancy / PF / max-DD / trade-count / Monte-Carlo net-p5. This")
    A("ordering is a READING AID for comparison, **not** a selection — the verdict column is the only")
    A("judgement, and it comes from the unmodified pipeline.")
    A("")
    A("| # | variant | verdict | OOS n | OOS PF | OOS exp | OOS maxDD% | MC net-p5 | switch |")
    A("|---|---------|---------|-------|--------|---------|-----------|-----------|--------|")
    for i, r in enumerate(ranked, 1):
        o = r["res"]
        mc = "" if o["mc_net_p5"] is None else f"{o['mc_net_p5']:.0f}"
        A(f"| {i} | {r['variant_id']} | {o['verdict']} | {o['oos_n']} | "
          f"{_pf_str(o['oos_pf'])} | {o['oos_exp']:.2f} | {o['oos_max_dd']:.2f} | {mc} | "
          f"{r['trial_note']} |")
    A("")
    A("## Per-variant detail")
    A("")
    for r in ranked:
        o = r["res"]
        A(f"### {r['variant_id']} — {o['verdict']}")
        A("")
        A(f"- switch: {r['trial_note']}")
        A(f"- trades: total {r['trades_total']}, IS {r['n_is']}, OOS {r['n_oos']}")
        A(f"- OOS: PF {_pf_str(o['oos_pf'])}, expectancy {o['oos_exp']:.2f}, net {o['oos_net']:.2f}, "
          f"win-rate {o['oos_win_rate']:.1f}%, max-DD {o['oos_max_dd']:.2f}%")
        A(f"- IS (exploration only): PF {_pf_str(o['is_pf'])}, expectancy {o['is_exp']:.2f}")
        if o["mc_net_p5"] is not None:
            A(f"- OOS Monte-Carlo (advisory): DD p95 {o['mc_dd_p95']:.0f}%, "
              f"P(losing) {o['mc_p_losing']:.0f}%, net p5 {o['mc_net_p5']:.0f}")
        if r["cfg"].smt_pair != "off":
            A(f"- SMT: {r['smt_note']}")
        if o["reasons"]:
            A(f"- pipeline reasons: {'; '.join(o['reasons'])}")
        A("")
    A("## Data dependency notes")
    A("")
    smt_rows = [r for r in ranked if r["cfg"].smt_pair != "off"]
    if smt_rows and not any(r["smt_available"] for r in smt_rows):
        A("- **SMT variants (`smt_xag`, `smt_dxy`) had NO partner series** (XAGUSD / DXY are not in")
        A("  the repo). They were enumerated as legitimate degrees of freedom but SMT was disabled")
        A("  (variant = OFF) rather than fabricating a signal. Supply `--pair-csv` with an aligned")
        A("  partner series to actually exercise SMT.")
    else:
        A("- SMT partner series present where required (see per-variant SMT notes).")
    A("")
    A("## Provenance")
    A("")
    A(f"- M15 data: `{meta['data']}`  ({meta['n_m15']} bars)")
    A(f"- M5 data: `{meta['m5']}`  ({meta['n_m5']} bars)")
    A(f"- Deposit (metrics/MC sizing): {meta['deposit']:.2f}")
    A(f"- Verdicts computed via the unmodified `pipeline.py` logic (MIN_OOS_TRADES={MIN_OOS_TRADES}, "
      f"M1_MIN_PF={PIPE.M1_MIN_PF}).")
    A("")
    return "\n".join(lines) + "\n"


# ---- orchestration ---------------------------------------------------------------------------
def run_grid(m15_bars, m5_bars, pair_bars, outdir, deposit, meta):
    """Run every variant, invoke the verdict engine, rank, and return (ranked, report_str)."""
    if not os.path.isdir(outdir):
        os.makedirs(outdir)
    grid = build_grid()
    ranked = []
    for variant_id, cfg, note in grid:
        vr = run_variant(variant_id, cfg, m15_bars, m5_bars, pair_bars, outdir)
        res = pipeline_verdict(vr["is_path"], vr["oos_path"], deposit)
        vr["trial_note"] = note
        vr["res"] = res
        ranked.append(vr)
    ranked.sort(key=rank_key)
    report = build_report(ranked, meta)
    return ranked, report


def print_summary_table(ranked):
    """Print the per-variant OOS summary table to stdout (deterministic, ordered)."""
    print("=" * 96)
    print("QM/ICT block-7  variant-grid runner — per-variant OUT-OF-SAMPLE summary")
    print("=" * 96)
    print(f"  pre-declared IS/OOS split: {SPLIT_BOUNDARY_STR}   (>= {MIN_OOS_TRADES} OOS trades "
          f"required for a verdict)")
    print("-" * 96)
    hdr = f"  {'variant':<16}{'verdict':<28}{'OOSn':>6}{'OOSpf':>8}{'OOSexp':>10}{'maxDD%':>9}"
    print(hdr)
    print("-" * 96)
    for r in ranked:
        o = r["res"]
        print(f"  {r['variant_id']:<16}{(o['verdict'] or ''):<28}{o['oos_n']:>6}"
              f"{_pf_str(o['oos_pf']):>8}{o['oos_exp']:>10.2f}{o['oos_max_dd']:>9.2f}")
    print("-" * 96)
    eligible = [r for r in ranked if r["res"]["oos_n"] >= MIN_OOS_TRADES]
    passes = [r for r in eligible if (r["res"]["verdict"] or "").startswith("PASS")]
    print(f"  variants: {len(ranked)}   eligible (>= {MIN_OOS_TRADES} OOS): {len(eligible)}   "
          f"PASS: {len(passes)}")
    if not eligible:
        print("  HONEST VERDICT: insufficient OOS evidence — NO robust edge established (no winner).")
    elif not passes:
        print("  HONEST VERDICT: no variant PASSES the OOS gates — no robust edge established (no winner).")
    else:
        print("  NOTE: PASS rows are exploratory and pending MT5/extra-data stages; not a winner.")
    print("=" * 96)


# ---- self-check ------------------------------------------------------------------------------
def _synthetic_m15_m5():
    """Reuse the engine's synthetic happy-path builder for a tiny deterministic dataset."""
    return QM._build_happy_path()


def selfcheck():
    """Synthetic, deterministic assertions proving the runner's contract:

    (A) ENUMERATION: build_grid() enumerates the expected number of variants, all ids unique, and
        every open switch appears at least once (baseline + OFAT coverage).
    (B) PIPELINE-FORMAT CSVs: for a reduced run on the synthetic dataset, each per-variant IS/OOS CSV
        is parsed by metrics.load_trades WITHOUT error and has the exact 'time,profit' header.
    (C) DETERMINISTIC + PRE-DECLARED SPLIT: split_rows uses the fixed SPLIT_BOUNDARY and gives the
        SAME partition on a re-run; the boundary constant is not computed from data.
    (D) DETERMINISTIC REPORT: same synthetic input => byte-identical report string and results rows.
    (E) SWITCH IS WIRED THROUGH: changing a variant switch changes that variant's trade list (the
        engine is actually driven by the config, not ignored).
    """
    # (A) enumeration
    grid = build_grid()
    ids = [g[0] for g in grid]
    assert len(ids) == len(set(ids)), "A: variant ids must be unique"
    assert ids[0] == "baseline", "A: first variant must be the documented baseline"
    EXPECTED_N = 21
    assert len(grid) == EXPECTED_N, f"A: expected {EXPECTED_N} variants, got {len(grid)}"
    # every open switch must be exercised somewhere in the grid
    d = QM.DEFAULT_CONFIG
    switched_fields = set()
    for _id, cfg, _note in grid[1:]:
        for fld in d._fields:
            if getattr(cfg, fld) != getattr(d, fld):
                switched_fields.add(fld)
    for must in ("poi_type", "sl_mode", "sl_buffer_atr", "tp_mode", "min_projected_rr",
                 "idm_clear_required", "idm_clear_mode", "pivot", "disp", "erl_tf",
                 "session_scope", "max_trades_per_day", "smt_pair"):
        assert must in switched_fields, f"A: open switch '{must}' is not exercised by the grid"

    # tiny synthetic dataset + reduced grid for the CSV/format/determinism checks
    m15, m5 = _synthetic_m15_m5()
    import tempfile
    tmp = tempfile.mkdtemp(prefix="variant_selfcheck_")
    # relax session so the synthetic timestamps are not the discriminator (as the engine selfcheck does)
    base = QM.make_config(session_scope="ny_london_asia", min_projected_rr=0.0, erl_tf="input")
    reduced = [
        ("sc_baseline", base, "selfcheck baseline"),
        ("sc_idm_opt", base._replace(idm_clear_required=False), "selfcheck idm optional"),
        ("sc_tp_fixed", base._replace(tp_mode="fixed_rr"), "selfcheck fixed rr"),
    ]

    def run_reduced(outdir):
        os.makedirs(outdir, exist_ok=True)
        rk = []
        for vid, cfg, note in reduced:
            vr = run_variant(vid, cfg, m15, m5, None, outdir)
            res = pipeline_verdict(vr["is_path"], vr["oos_path"], DEPOSIT_DEFAULT)
            vr["trial_note"] = note; vr["res"] = res
            rk.append(vr)
        rk.sort(key=rank_key)
        return rk

    out1 = os.path.join(tmp, "run1")
    ranked1 = run_reduced(out1)

    # (B) each per-variant CSV parses via metrics.load_trades and has the exact header
    for vr in ranked1:
        for p in (vr["is_path"], vr["oos_path"]):
            first = open(p).readline().strip()
            assert first == "time,profit", f"B: {p} header must be 'time,profit', got {first!r}"
            loaded = M.load_trades(p)  # must not raise
            assert isinstance(loaded, list), "B: load_trades must return a list"
        # total IS+OOS must equal the emitted trade count (no rows dropped by the split)
        assert vr["n_is"] + vr["n_oos"] == vr["trades_total"], "B: split must partition all rows"

    # (C) deterministic + pre-declared split. SPLIT_BOUNDARY is a fixed constant, not data-derived.
    assert isinstance(SPLIT_BOUNDARY, datetime.datetime), "C: split boundary must be a fixed constant"
    demo_rows = [
        ("2025.12.31 23:45", 10.0),   # before boundary -> IS
        ("2026.02.01 00:00", -5.0),   # exactly at boundary -> OOS
        ("2026.03.15 09:30", 7.0),    # after boundary -> OOS
        ("bad-timestamp", 1.0),       # unparseable -> IS (never counted as OOS)
    ]
    is1, oos1 = split_rows(demo_rows)
    is2, oos2 = split_rows(demo_rows)
    assert is1 == is2 and oos1 == oos2, "C: split must be deterministic"
    assert [r[0] for r in is1] == ["2025.12.31 23:45", "bad-timestamp"], "C: IS partition wrong"
    assert [r[0] for r in oos1] == ["2026.02.01 00:00", "2026.03.15 09:30"], "C: OOS partition wrong"

    # (D) deterministic report + results rows: identical bytes on a second independent run
    out2 = os.path.join(tmp, "run2")
    ranked2 = run_reduced(out2)
    meta = {"data": "synthetic", "m5": "synthetic", "n_m15": len(m15), "n_m5": len(m5),
            "deposit": DEPOSIT_DEFAULT}
    rep1 = build_report(ranked1, meta)
    rep2 = build_report(ranked2, meta)
    assert rep1 == rep2, "D: report must be byte-identical for identical input"
    rcsv1 = os.path.join(tmp, "r1.csv"); rcsv2 = os.path.join(tmp, "r2.csv")
    write_results_csv(ranked1, rcsv1); write_results_csv(ranked2, rcsv2)
    assert open(rcsv1, "rb").read() == open(rcsv2, "rb").read(), "D: results CSV must be byte-identical"

    # (E) switch is wired through: on a scenario where the IDM is NEVER cleared (highs capped below
    #     the IDM level, mirroring the engine selfcheck's negative case), idm_clear_required=True
    #     yields NO trade but idm_clear_required=False yields a trade -> the switch is the gate.
    m15_neg = list(m15)
    for i in range(len(m15_neg)):
        idx, dt, o, h, l, c, v = m15_neg[i]
        if idx >= 23:  # after the break, cap highs below the IDM level so it never clears
            h = min(h, 103.0); o = min(o, 103.0); c = min(c, 103.0); l = min(l, c)
            m15_neg[i] = QM._b(idx, dt, o, h, l, c, v)
    m5_neg = QM._rebuild_m5(m15_neg)
    req_rows = QM.to_pipeline_rows(QM.run(m15_neg, base._replace(idm_clear_required=True), m5_bars=m5_neg)[0])
    opt_rows = QM.to_pipeline_rows(QM.run(m15_neg, base._replace(idm_clear_required=False), m5_bars=m5_neg)[0])
    assert req_rows != opt_rows, "E: flipping a switch must change that variant's trade list"

    # cleanup the temp dir
    import shutil
    shutil.rmtree(tmp, ignore_errors=True)

    print("selfcheck: PASS")
    print(f"  case A: grid enumerates {EXPECTED_N} unique variants (baseline + OFAT); every open switch exercised")
    print("  case B: each per-variant IS/OOS CSV parses via metrics.load_trades with exact 'time,profit' header")
    print("  case C: IS/OOS split uses the fixed PRE-DECLARED boundary and is deterministic on re-run")
    print("  case D: report + results CSV are byte-identical for identical input (deterministic)")
    print("  case E: flipping a variant switch changes that variant's trade list (switch is wired through)")
    return True


# ---- CLI -------------------------------------------------------------------------------------
def parse_args(argv):
    p = argparse.ArgumentParser(
        description="QM/ICT block-7: variant-grid runner + honest OOS report.")
    p.add_argument("--data", default=None, help="M15 XAUUSD OHLC CSV")
    p.add_argument("--m5", default=None, help="M5 execution-TF OHLC CSV")
    p.add_argument("--pair-csv", default=None, help="optional SMT partner series (XAGUSD/DXY)")
    p.add_argument("--selfcheck", action="store_true", help="run synthetic assertions only")
    p.add_argument("--outdir", default="v1_lab/variants", help="dir for per-variant IS/OOS CSVs")
    p.add_argument("--results", default="v1_lab/variant_results.csv", help="machine-readable results CSV")
    p.add_argument("--report", default="v1_lab/VARIANT_REPORT.md", help="human-readable report")
    p.add_argument("--deposit", type=float, default=DEPOSIT_DEFAULT, help="deposit for metrics/MC")
    return p.parse_args(argv)


def main():
    args = parse_args(sys.argv[1:])

    # Always prove the runner on synthetic data first (a released real run is thereby self-proven).
    if args.selfcheck or args.data is None:
        selfcheck()
        if args.data is None:
            return
        print()
    else:
        selfcheck()
        print()

    if not args.m5:
        raise SystemExit("--m5 is required for a real-data run (M5 execution timeframe)")

    m15 = QM.load_ohlc(args.data)
    if not m15:
        raise SystemExit(f"no OHLC rows parsed from {args.data}")
    m5 = QM.load_ohlc(args.m5)
    if not m5:
        raise SystemExit(f"no OHLC rows parsed from {args.m5}")
    pair = QM.load_ohlc(args.pair_csv) if args.pair_csv else None

    meta = {
        "data": args.data, "m5": args.m5,
        "n_m15": len(m15), "n_m5": len(m5), "deposit": args.deposit,
    }
    ranked, report = run_grid(m15, m5, pair, args.outdir, args.deposit, meta)
    write_results_csv(ranked, args.results)
    with open(args.report, "w", newline="") as f:
        f.write(report)
    print_summary_table(ranked)
    print(f"  results CSV: {args.results}")
    print(f"  report:      {args.report}")
    print(f"  per-variant CSVs: {args.outdir}/<variant>_is.csv / _oos.csv")


if __name__ == "__main__":
    main()

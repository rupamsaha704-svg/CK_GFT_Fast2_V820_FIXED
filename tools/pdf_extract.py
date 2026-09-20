#!/usr/bin/env python3
"""
Strategy-PDF text extractor + deduper + triage.

Reads the trading-strategy PDFs (default: the cloned Trading_Project folder), extracts real text
with pypdf, collapses obvious duplicate copies, and writes:
  - docs/strategy_pdfs_text/<slug>.txt   one text file per UNIQUE readable PDF
  - SPEC/STRATEGY_INDEX.md               a manifest: pages, chars, readable?, triage class, dupes

HONESTY:
  * Text is extracted, never invented. A PDF that yields little/no text (scanned images) is marked
    UNREADABLE, not summarised.
  * Triage keywords only SUGGEST whether a doc is mechanical (codeable) or mindset (no code). The
    class is a hint for humans, not a verdict.
  * Nothing is committed here; the raw PDFs stay outside the repo to keep it lean.

Usage:
  python tools/pdf_extract.py --src "C:/Users/prita/ck_tmp/Trading_Project"
"""
import argparse
import os
import re
import sys

try:
    from pypdf import PdfReader
except Exception as e:  # pragma: no cover
    sprint("pypdf not available:", e, file=sys.stderr)
    sys.exit(3)

def sprint(*args):
    """ASCII-safe print: Windows console is cp1252 and dies on exotic filenames/emoji."""
    msg = " ".join(str(a) for a in args)
    sys.stdout.buffer.write(msg.encode("ascii", "replace") + b"\n")
    sys.stdout.flush()


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TEXT = os.path.join(ROOT, "docs", "strategy_pdfs_text")
INDEX_MD = os.path.join(ROOT, "SPEC", "STRATEGY_INDEX.md")

# Triage keyword sets. Mechanical = something that could become an EA rule. Mindset = psychology.
MECH = ["entry", "stop loss", "take profit", "order block", "fair value gap", "fvg", "liquidity",
        "breaker", "swing", "session", "killzone", "kill zone", "supply", "demand", "snr",
        "support", "resistance", "fibonacci", "fib ", "retracement", "ote", "displacement",
        "market structure", "bos", "choch", "mss", "inducement", "premium", "discount",
        "power of 3", "po3", "quarterly", "standard deviation", "projection", "range", "sweep",
        "turtle soup", "pip", "risk reward", "r:r", "rr ", "candle", "wick", "close above",
        "close below", "higher high", "lower low"]
MIND = ["psychology", "discipline", "emotion", "mindset", "fear", "greed", "confidence",
        "patience", "belief", "probabilities", "journaling", "meditation", "the zone",
        "self-control", "mental"]


def slug(name):
    s = os.path.splitext(os.path.basename(name))[0]
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    return s[:70] or "doc"


def dedupe_key(name):
    """Collapse '(1)', '(2)', ' copy', trailing spaces, and case so duplicate uploads group."""
    s = os.path.splitext(os.path.basename(name))[0].lower()
    s = re.sub(r"\(\d+\)", "", s)
    s = re.sub(r"[^a-z0-9]+", "", s)
    return s


def extract(path):
    """Return (n_pages, text) or (n_pages, '') on failure."""
    try:
        r = PdfReader(path)
        pages = len(r.pages)
        chunks = []
        for pg in r.pages:
            try:
                chunks.append(pg.extract_text() or "")
            except Exception:
                chunks.append("")
        return pages, "\n".join(chunks)
    except Exception as e:
        return 0, f"__ERROR__ {e}"


def triage(text):
    t = text.lower()
    mech = sum(t.count(k) for k in MECH)
    mind = sum(t.count(k) for k in MIND)
    if len(t.strip()) < 400:
        return "UNREADABLE", mech, mind
    if mind > mech and mind >= 5:
        return "MINDSET", mech, mind
    if mech >= 5:
        return "MECHANICAL", mech, mind
    return "UNCLEAR", mech, mind


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="folder containing the strategy PDFs")
    ap.add_argument("--limit", type=int, default=0, help="process at most N unique PDFs (0 = all)")
    ap.add_argument("--skip", default="", help="comma-separated filenames to skip (crashers)")
    a = ap.parse_args()
    skip = set(x.strip() for x in a.skip.split(",") if x.strip())
    marker = os.path.join(ROOT, "tools", "_pdf_current.txt")

    src = a.src
    if not os.path.isdir(src):
        sprint(f"source folder not found: {src}", file=sys.stderr)
        return 3

    pdfs = sorted(f for f in os.listdir(src) if f.lower().endswith(".pdf"))
    os.makedirs(OUT_TEXT, exist_ok=True)

    seen = {}          # dedupe_key -> chosen filename
    dupes = {}         # chosen filename -> [dup names]
    for f in pdfs:
        k = dedupe_key(f)
        if k in seen:
            dupes.setdefault(seen[k], []).append(f)
        else:
            seen[k] = f

    unique = list(seen.values())
    if a.limit:
        unique = unique[:a.limit]

    rows = []
    for i, f in enumerate(unique, 1):
        path = os.path.join(src, f)
        s_pre = slug(f)
        cache = os.path.join(OUT_TEXT, s_pre + ".txt")
        if os.path.exists(cache):   # RESUME: already extracted, reuse it (skip the slow re-read)
            with open(cache, encoding="utf-8", errors="ignore") as fh:
                text = fh.read()
            pages = -1
            cls, mech, mind = triage(text)
            rows.append({"file": f, "slug": s_pre, "pages": pages, "chars": len(text),
                         "class": cls, "mech": mech, "mind": mind,
                         "dupes": len(dupes.get(f, [])), "err": ""})
            sprint(f"[{i}/{len(unique)}] CACHED {cls:<10} {f}")
            continue
        if f in skip:   # known crasher: record as unreadable, do not attempt
            rows.append({"file": f, "slug": s_pre, "pages": 0, "chars": 0,
                         "class": "UNREADABLE", "mech": 0, "mind": 0,
                         "dupes": len(dupes.get(f, [])), "err": "skipped (crashes pypdf)"})
            sprint(f"[{i}/{len(unique)}] SKIP       {f}")
            continue
        with open(marker, "w", encoding="utf-8") as mf:   # crash breadcrumb
            mf.write(f)
        pages, text = extract(path)
        err = text.startswith("__ERROR__")
        cls, mech, mind = triage("" if err else text)
        s = slug(f)
        if not err and len(text.strip()) >= 400:
            with open(os.path.join(OUT_TEXT, s + ".txt"), "w", encoding="utf-8", errors="ignore") as fh:
                fh.write(text)
        rows.append({
            "file": f, "slug": s, "pages": pages, "chars": 0 if err else len(text),
            "class": "ERROR" if err else cls, "mech": mech, "mind": mind,
            "dupes": len(dupes.get(f, [])),
            "err": text if err else "",
        })
        sprint(f"[{i}/{len(unique)}] {cls:<10} {f}  ({pages}p, {0 if err else len(text)} chars)")

    # ---- manifest ----
    rows.sort(key=lambda r: (r["class"], -r["chars"]))
    os.makedirs(os.path.dirname(INDEX_MD), exist_ok=True)
    lines = []
    lines.append("# Strategy PDF index (extracted, not interpreted)")
    lines.append("")
    lines.append(f"- Source: `{src}`")
    lines.append(f"- Unique PDFs: {len(unique)}  (from {len(pdfs)} files; duplicates collapsed)")
    lines.append(f"- Extracted text: `docs/strategy_pdfs_text/`")
    lines.append("- Class is a keyword HINT, not a verdict. MECHANICAL = may hold codeable rules;")
    lines.append("  MINDSET = psychology, no EA rule; UNREADABLE = scanned/no text (needs OCR);")
    lines.append("  UNCLEAR = too few signals to tell.")
    lines.append("")
    counts = {}
    for r in rows:
        counts[r["class"]] = counts.get(r["class"], 0) + 1
    lines.append("Class counts: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    lines.append("")
    lines.append("| # | Class | Pages | Chars | Dupes | File | mech/mind |")
    lines.append("|---|---|---|---|---|---|---|")
    for i, r in enumerate(rows, 1):
        lines.append(f"| {i} | {r['class']} | {r['pages']} | {r['chars']} | {r['dupes']} | "
                     f"{r['file']} | {r['mech']}/{r['mind']} |")
    lines.append("")
    if any(r["class"] == "UNREADABLE" or r["class"] == "ERROR" for r in rows):
        lines.append("## Not machine-readable (need OCR or manual reading)")
        for r in rows:
            if r["class"] in ("UNREADABLE", "ERROR"):
                extra = f" â€” {r['err']}" if r["err"] else ""
                lines.append(f"- {r['file']} ({r['pages']}p, {r['chars']} chars){extra}")
        lines.append("")
    with open(INDEX_MD, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))

    sprint(f"\nmanifest -> {INDEX_MD}")
    sprint("class counts:", counts)
    return 0


if __name__ == "__main__":
    sys.exit(main())

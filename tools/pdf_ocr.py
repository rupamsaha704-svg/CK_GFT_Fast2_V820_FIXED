#!/usr/bin/env python3
"""
OCR the scanned-image strategy PDFs that pdf_extract.py could not read.

Path: pypdfium2 renders each page to a PNG, then the tesseract.exe binary OCRs it. No pytesseract
(avoids the Python-3.14 wheel gap) - tesseract is called as a subprocess. Output text goes to
docs/strategy_pdfs_text/<slug>.ocr.txt so it never overwrites real extracted text.

POWER DISCIPLINE: OCR is CPU-moderate. This caps pages per PDF (--max-pages, default 6 - strategy
rules are almost always in the first pages), processes ONE PDF at a time, and is RESUMABLE (skips
a PDF whose .ocr.txt already exists). Run it in small batches, not all 26 at once.

Usage:
  python tools/pdf_ocr.py --src "C:/Users/prita/ck_tmp/Trading_Project" --max-pages 6 [--only "turtle,psp"]
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

TESS = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TEXT = os.path.join(ROOT, "docs", "strategy_pdfs_text")


def sprint(*a):
    sys.stdout.buffer.write((" ".join(str(x) for x in a)).encode("ascii", "replace") + b"\n")
    sys.stdout.flush()


def slug(name):
    s = os.path.splitext(os.path.basename(name))[0]
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    return s[:70] or "doc"


def already_readable(s):
    """True if pdf_extract already got real text for this slug (skip - not a scan)."""
    p = os.path.join(OUT_TEXT, s + ".txt")
    return os.path.exists(p) and os.path.getsize(p) >= 400


def ocr_pdf(path, max_pages, dpi=200):
    import pypdfium2 as pdfium
    from PIL import Image  # noqa: F401 (pypdfium2 returns PIL images)

    pdf = pdfium.PdfDocument(path)
    n = min(len(pdf), max_pages)
    texts = []
    with tempfile.TemporaryDirectory(prefix="ocr_") as tmp:
        for i in range(n):
            page = pdf[i]
            scale = dpi / 72.0
            pil = page.render(scale=scale).to_pil().convert("L")
            png = os.path.join(tmp, f"p{i}.png")
            pil.save(png)
            base = os.path.join(tmp, f"p{i}")
            try:
                subprocess.run([TESS, png, base, "--psm", "6", "-l", "eng"],
                               capture_output=True, timeout=120)
                txtf = base + ".txt"
                if os.path.exists(txtf):
                    with open(txtf, encoding="utf-8", errors="ignore") as fh:
                        texts.append(fh.read())
            except Exception as e:
                texts.append(f"[page {i} OCR error: {e}]")
    pdf.close()
    return n, "\n".join(texts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--max-pages", type=int, default=6)
    ap.add_argument("--only", default="", help="comma substrings; OCR only matching filenames")
    ap.add_argument("--limit", type=int, default=0, help="stop after N PDFs this run (0 = all)")
    a = ap.parse_args()

    if not os.path.exists(TESS):
        sprint("tesseract.exe not found at", TESS)
        return 3
    os.makedirs(OUT_TEXT, exist_ok=True)

    only = [x.strip().lower() for x in a.only.split(",") if x.strip()]
    pdfs = sorted(f for f in os.listdir(a.src) if f.lower().endswith(".pdf"))
    done = 0
    for f in pdfs:
        if only and not any(o in f.lower() for o in only):
            continue
        s = slug(f)
        if already_readable(s):
            continue  # pdf_extract already read it - not a scan
        ocr_out = os.path.join(OUT_TEXT, s + ".ocr.txt")
        if os.path.exists(ocr_out):
            sprint("CACHED", f)
            continue
        try:
            npg, text = ocr_pdf(os.path.join(a.src, f), a.max_pages)
        except Exception as e:
            sprint("ERROR", f, str(e))
            continue
        with open(ocr_out, "w", encoding="utf-8", errors="ignore") as fh:
            fh.write(text)
        chars = len(text.strip())
        sprint(f"OCR {f}  ({npg}p -> {chars} chars)")
        done += 1
        if a.limit and done >= a.limit:
            sprint(f"stopped after {done} PDFs (limit)")
            break
    sprint("done", done, "PDFs OCR'd this run")
    return 0


if __name__ == "__main__":
    sys.exit(main())

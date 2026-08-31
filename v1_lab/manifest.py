#!/usr/bin/env python3
"""
Step 1.5 — Immutable Evidence Manifest (append-only).
Records, per run: SHA-256 of every input/output file + full run metadata, so any later change to
FIX09 or the data is detectable. Deterministic; no judgment here, just provenance.

Usage:
  python3 manifest.py --out evidence_manifest.jsonl \
     --meta ea=CK_GOLD_PRO_FIX09 version=1.03 symbol=XAUUSD tf=M15 model=RealTicks \
            from=2025.08.01 to=2026.08.01 params="EMA20/Age12/BE0.50/lot0.09" \
            broker=MetaQuotes-Demo spread_assumption=real cost=broker \
     --file /path/CK_GOLD_PRO_FIX09.mq5 --file /path/ck_gold_pro_fix09_trades.csv

Honest limitation: we can hash files we control (EA source, config, output CSV). The broker's REAL-TICK
dataset is external and can silently update; we record broker/server + model + date-range, and rely on
'same config => same output-CSV hash' to detect drift on re-run.
"""
import argparse, hashlib, json, os, datetime

def sha256(path):
    if not os.path.exists(path): return None
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for chunk in iter(lambda: f.read(1<<20), b''): h.update(chunk)
    return h.hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--meta', nargs='*', default=[])
    ap.add_argument('--file', action='append', default=[])
    a=ap.parse_args()
    meta={}
    for kv in a.meta:
        if '=' in kv: k,v=kv.split('=',1); meta[k]=v
    files={}
    for p in a.file:
        files[os.path.basename(p)]={"path":p,"sha256":sha256(p),
                                    "bytes":(os.path.getsize(p) if os.path.exists(p) else None)}
    rec={"run_timestamp":datetime.datetime.utcnow().isoformat()+"Z","meta":meta,"files":files}
    with open(a.out,'a') as f: f.write(json.dumps(rec)+"\n")
    print("=====MANIFEST_RECORD====="); print(json.dumps(rec,indent=2)); print("=====END=====")
    print(f"appended to {a.out}")

if __name__=='__main__': main()

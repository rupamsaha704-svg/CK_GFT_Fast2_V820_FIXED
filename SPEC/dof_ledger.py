#!/usr/bin/env python3
"""
Global Researcher-Degrees-of-Freedom Ledger — append-only, hash-chained (tamper-evident).
EVERY analytical choice is a trial and must be logged here: feature added, filter tried, regime def
changed, date range changed, SL/TP altered, benchmark changed, cost assumption changed, classifier
changed, hypothesis tested, version created, dataset opened, holdout unlocked, amendment, contamination/
burn events. The running count feeds multiple-testing correction (Holm-Bonferroni / Deflated Sharpe / PBO).

Each record chains the SHA-256 of the previous record, so silent edits/deletions are detectable.

Usage:
  python3 dof_ledger.py --file dof_ledger.jsonl append \
      --type BASELINE_FREEZE --desc "Design v1.0 locked" --refhash <sha> --meta k=v ...
  python3 dof_ledger.py --file dof_ledger.jsonl verify      # checks the whole chain
"""
import argparse, hashlib, json, os, datetime

def rec_hash(rec):  # deterministic hash of a record dict
    return hashlib.sha256(json.dumps(rec, sort_keys=True).encode()).hexdigest()

def last_hash(path):
    if not os.path.exists(path): return "GENESIS"
    prev="GENESIS"
    for line in open(path):
        line=line.strip()
        if line: prev=json.loads(line).get("_hash","GENESIS")
    return prev

def append(path, typ, desc, refhash, meta):
    body={"seq":count(path)+1,
          "ts":datetime.datetime.utcnow().isoformat()+"Z",
          "type":typ, "desc":desc, "ref_hash":refhash, "meta":meta,
          "prev_hash":last_hash(path)}
    body["_hash"]=rec_hash(body)
    with open(path,'a') as f: f.write(json.dumps(body)+"\n")
    print("=====LEDGER_APPEND====="); print(json.dumps(body,indent=2)); print("=====END=====")

def count(path):
    if not os.path.exists(path): return 0
    return sum(1 for l in open(path) if l.strip())

def verify(path):
    if not os.path.exists(path): print("ledger empty"); return
    prev="GENESIS"; ok=True; n=0
    for line in open(path):
        line=line.strip()
        if not line: continue
        n+=1; rec=json.loads(line); h=rec.pop("_hash",None)
        if rec.get("prev_hash")!=prev: print(f"  CHAIN BREAK at seq {rec.get('seq')}"); ok=False
        if rec_hash(rec)!=h: print(f"  TAMPER at seq {rec.get('seq')} (hash mismatch)"); ok=False
        prev=h
    print(f"ledger records: {n}   integrity: {'OK' if ok else 'FAILED'}")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--file', required=True)
    ap.add_argument('cmd', choices=['append','verify'])
    ap.add_argument('--type', default=''); ap.add_argument('--desc', default='')
    ap.add_argument('--refhash', default=''); ap.add_argument('--meta', nargs='*', default=[])
    a=ap.parse_args()
    if a.cmd=='verify': verify(a.file); return
    meta={}
    for kv in a.meta:
        if '=' in kv: k,v=kv.split('=',1); meta[k]=v
    append(a.file, a.type, a.desc, a.refhash, meta)

if __name__=='__main__': main()

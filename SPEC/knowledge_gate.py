#!/usr/bin/env python3
"""
Self-learning KNOWLEDGE-GATE — append-only, hash-chained, PROOF-GATED.

The system may absorb new external knowledge (an idea, a technique, a source) ONLY after it has
been tested and has PASSED the deterministic pipeline on locked / out-of-sample data. Unproven
knowledge is discarded, not stored. This is how the system gets stronger over time — safely,
never by overfitting.

Enforcement:
  - To STORE knowledge you MUST supply --verdict PASS  AND  a non-empty --verdict-hash
    (the hash of the passing VALIDATOR/pipeline result or the ledger record that recorded it).
  - Anything else (FAIL / REJECT / missing hash) is REFUSED and nothing is written.

Each record chains the SHA-256 of the previous record (tamper-evident), same as dof_ledger.

Usage:
  python3 knowledge_gate.py --file knowledge_ledger.jsonl store \
      --knowledge "..." --source "..." --verdict PASS --verdict-hash <sha> [--meta k=v ...]
  python3 knowledge_gate.py --file knowledge_ledger.jsonl list
  python3 knowledge_gate.py --file knowledge_ledger.jsonl verify
"""
import argparse, hashlib, json, os, datetime

def rec_hash(rec):
    return hashlib.sha256(json.dumps(rec, sort_keys=True).encode()).hexdigest()

def last_hash(path):
    if not os.path.exists(path): return "GENESIS"
    prev = "GENESIS"
    for line in open(path):
        line = line.strip()
        if line: prev = json.loads(line).get("_hash", "GENESIS")
    return prev

def count(path):
    if not os.path.exists(path): return 0
    return sum(1 for l in open(path) if l.strip())

def store(path, knowledge, source, verdict, verdict_hash, meta):
    # PROOF GATE — refuse anything not proven on locked data
    if verdict.strip().upper() != "PASS":
        print("=====KNOWLEDGE_GATE=====")
        print(f"REFUSED: verdict is '{verdict}', not PASS. Knowledge NOT stored.")
        print("Only knowledge proven on locked/out-of-sample data may be stored.")
        print("=====END=====")
        return 1
    if not verdict_hash.strip():
        print("=====KNOWLEDGE_GATE=====")
        print("REFUSED: no --verdict-hash supplied. A passing verdict must reference its proof.")
        print("Knowledge NOT stored.")
        print("=====END=====")
        return 1
    body = {"seq": count(path) + 1,
            "ts": datetime.datetime.utcnow().isoformat() + "Z",
            "knowledge": knowledge, "source": source,
            "verdict": "PASS", "verdict_hash": verdict_hash, "meta": meta,
            "prev_hash": last_hash(path)}
    body["_hash"] = rec_hash(body)
    with open(path, 'a') as f: f.write(json.dumps(body) + "\n")
    print("=====KNOWLEDGE_GATE=====")
    print("ACCEPTED: proof-gated knowledge stored.")
    print(json.dumps(body, indent=2))
    print("=====END=====")
    return 0

def list_k(path):
    if not os.path.exists(path): print("knowledge ledger empty"); return
    for line in open(path):
        line = line.strip()
        if not line: continue
        r = json.loads(line)
        print(f"  [{r['seq']}] {r['knowledge']}  (proof {r['verdict_hash'][:12]}...)")

def verify(path):
    if not os.path.exists(path): print("knowledge ledger empty"); return
    prev = "GENESIS"; ok = True; n = 0
    for line in open(path):
        line = line.strip()
        if not line: continue
        n += 1; rec = json.loads(line); h = rec.pop("_hash", None)
        if rec.get("prev_hash") != prev: print(f"  CHAIN BREAK at seq {rec.get('seq')}"); ok = False
        if rec_hash(rec) != h: print(f"  TAMPER at seq {rec.get('seq')} (hash mismatch)"); ok = False
        prev = h
    print(f"knowledge records: {n}   integrity: {'OK' if ok else 'FAILED'}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--file', required=True)
    ap.add_argument('cmd', choices=['store', 'list', 'verify'])
    ap.add_argument('--knowledge', default=''); ap.add_argument('--source', default='')
    ap.add_argument('--verdict', default=''); ap.add_argument('--verdict-hash', default='')
    ap.add_argument('--meta', nargs='*', default=[])
    a = ap.parse_args()
    if a.cmd == 'verify': verify(a.file); return
    if a.cmd == 'list': list_k(a.file); return
    meta = {}
    for kv in a.meta:
        if '=' in kv: k, v = kv.split('=', 1); meta[k] = v
    raise SystemExit(store(a.file, a.knowledge, a.source, a.verdict, a.verdict_hash, meta))

if __name__ == '__main__': main()

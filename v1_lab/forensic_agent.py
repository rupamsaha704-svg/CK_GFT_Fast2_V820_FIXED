#!/usr/bin/env python3
"""
FORENSIC AGENT — governance/enforcement layer (deterministic).
The LLM may DRAFT hypotheses, but this code ENFORCES the locked rules so the agent can never become an
auto-tune/overfit machine. It does NOT judge PASS/FAIL and cannot edit thresholds/verdict.

What it enforces on an agent hypothesis file (JSON):
  - budget: <=3 PRIMARY (testable) + <=2 EXPLORATORY (log-only); hard ceiling 5
  - every hypothesis has ALL required fields
  - NO verdict/threshold-editing language (forbidden tokens) -> rejected
  - root-cause order respected: PRIMARY hypotheses must not jump to "strategy-logic/modification"
    while cheaper causes (data/execution/sampling/regime) are untested/unaddressed
  - confidence is LOW/MED/HIGH only (never a pass/fail input)
  - appends an accepted, validated set to the hash-chained DoF ledger (each = a researcher DoF)

Input JSON schema (list):
[{ "id":"H1","class":"PRIMARY|EXPLORATORY","root_cause":"data|execution|sampling|regime|strategy",
   "observation":"...","evidence_ref":"...","mechanism":"...","falsifiable_prediction":"...",
   "null_hypothesis":"...","experiment":"...","true_signal":"...","false_signal":"...",
   "data_exposure_count":0,"kill_criterion":"...","confidence":"LOW|MED|HIGH" }]

Usage:
  python3 forensic_agent.py hypotheses.json                 # validate only
  python3 forensic_agent.py hypotheses.json --commit LEDGER  # validate + append accepted to ledger
"""
import argparse, json, sys, re

REQUIRED=["id","class","root_cause","observation","evidence_ref","mechanism","falsifiable_prediction",
          "null_hypothesis","experiment","true_signal","false_signal","data_exposure_count",
          "kill_criterion","confidence"]
CLASSES={"PRIMARY","EXPLORATORY"}
ROOTS=["data","execution","sampling","regime","strategy"]   # cheap -> expensive order
CONF={"LOW","MED","HIGH"}
# phrases/words (word-boundary regex) that indicate the agent is trying to JUDGE / TUNE / DEPLOY => rejected.
# NOTE: bare "fail"/"pass" are NOT forbidden (legit in kill_criterion e.g. "if it fails OOS, discard").
FORBIDDEN=[r"\bdeploy\b", r"go live", r"\boverride\b", r"increase risk", r"raise risk",
           r"change (the )?threshold", r"lower (the )?threshold", r"raise (the )?threshold",
           r"set (the )?threshold", r"\bverdict\b", r"this is robust", r"edge is real",
           r"mark as pass", r"declare pass", r"it passes", r"should pass", r"real money"]

def viol(h):
    errs=[]
    for f in REQUIRED:
        if f not in h or (isinstance(h.get(f),str) and not h[f].strip()): errs.append(f"missing/empty '{f}'")
    if h.get("class") not in CLASSES: errs.append("class must be PRIMARY/EXPLORATORY")
    if h.get("root_cause") not in ROOTS: errs.append("root_cause invalid")
    if h.get("confidence") not in CONF: errs.append("confidence must be LOW/MED/HIGH")
    blob=json.dumps(h).lower()
    for pat in FORBIDDEN:
        if re.search(pat, blob): errs.append(f"forbidden pattern /{pat}/ (agent may not judge/tune/deploy)")
    return errs

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('hyp'); ap.add_argument('--commit', default=None)
    a=ap.parse_args()
    data=json.load(open(a.hyp))
    if not isinstance(data,list): print("ERROR: hypotheses file must be a JSON list"); sys.exit(1)
    prim=[h for h in data if h.get("class")=="PRIMARY"]; expl=[h for h in data if h.get("class")=="EXPLORATORY"]
    print("="*60); print("FORENSIC AGENT — hypothesis validation (enforcement only)"); print("="*60)
    problems=[]
    # budget
    if len(prim)>3: problems.append(f"budget: {len(prim)} PRIMARY > 3 (decision budget exceeded)")
    if len(expl)>2: problems.append(f"budget: {len(expl)} EXPLORATORY > 2")
    if len(data)>5: problems.append(f"budget: {len(data)} total > hard ceiling 5")
    # per-hypothesis
    for h in data:
        e=viol(h)
        tag=f"{h.get('id','?')} [{h.get('class','?')}/{h.get('root_cause','?')}]"
        if e: problems.append(f"{tag}: "+"; ".join(e)); print(f"  {tag}: REJECTED -> "+"; ".join(e))
        else: print(f"  {tag}: ok  (conf {h.get('confidence')})")
    # root-cause order for PRIMARY: no 'strategy' primary unless cheaper roots present among primaries
    prim_roots={h.get("root_cause") for h in prim}
    if "strategy" in prim_roots and not ({"data","execution","sampling","regime"} & prim_roots):
        problems.append("root-cause order: a PRIMARY jumps to 'strategy' with no cheaper-cause hypothesis first")
    print("-"*60)
    if problems:
        print("RESULT: REJECTED (fix before testing)"); [print("  -",p) for p in problems]; sys.exit(2)
    print("RESULT: ACCEPTED — hypotheses are well-formed & within budget.")
    print("  NOTE: acceptance ≠ evidence. Each PRIMARY must be tested by the deterministic pipeline")
    print("        on fresh/untouched data; every hypothesis counts as a researcher degree of freedom.")
    if a.commit:
        import subprocess, os, hashlib
        hh=hashlib.sha256(open(a.hyp,'rb').read()).hexdigest()
        os.system(f'python3 "{os.path.join(os.path.dirname(__file__),"..","SPEC","dof_ledger.py")}" '
                  f'--file "{a.commit}" append --type FORENSIC_HYPOTHESES '
                  f'--desc "{len(prim)} primary + {len(expl)} exploratory accepted (validated)" --refhash {hh} '
                  f'--meta primary={len(prim)} exploratory={len(expl)}')

if __name__=='__main__': main()

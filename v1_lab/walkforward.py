#!/usr/bin/env python3
"""
Walk-Forward / rolling out-of-sample CONSISTENCY (deterministic).
NOTE: this is NOT re-optimization walk-forward. Params are FROZEN by design (we do not optimize).
So this measures whether the SAME frozen params stay consistent across consecutive time windows.

PASS/FAIL thresholds are PRE-DECLARED here (locked in code, before looking at any result):
  WF_MIN_PROFITABLE_FRAC = 0.60   # >=60% of windows net>0
  WF_MIN_WINDOW_PF       = 0.60   # no window collapses below PF 0.60
  WF_MIN_MEDIAN_PF       = 1.10   # median window PF >= 1.10

Usage: python3 walkforward.py trades.csv [n_windows=6] [deposit=5000]
CSV: header time,profit ; rows YYYY.MM.DD HH:MM,profit
"""
import sys, datetime

WF_MIN_PROFITABLE_FRAC = 0.60
WF_MIN_WINDOW_PF       = 0.60
WF_MIN_MEDIAN_PF       = 1.10

def load(p):
    rows=[]
    for l in open(p):
        l=l.strip()
        if not l or l.lower().startswith('time,'): continue
        t,pf=l.rsplit(',',1)
        rows.append((datetime.datetime.strptime(t,"%Y.%m.%d %H:%M"), float(pf)))
    rows.sort(key=lambda x:x[0]); return rows

def pf_net(seq):
    gw=sum(p for p in seq if p>0); gl=abs(sum(p for p in seq if p<0))
    return (gw/gl if gl>0 else (float('inf') if gw>0 else 0.0)), sum(seq)

def main():
    f=sys.argv[1]; nwin=int(sys.argv[2]) if len(sys.argv)>2 else 6
    rows=load(f); n=len(rows)
    print("="*56); print(f"WALK-FORWARD CONSISTENCY (frozen params) — {n} trades, {nwin} windows"); print("="*56)
    # split by TIME into nwin equal calendar spans
    t0,t1=rows[0][0],rows[-1][0]; span=(t1-t0)/nwin
    wins=[[] for _ in range(nwin)]
    for dt,p in rows:
        idx=min(int((dt-t0)/span), nwin-1); wins[idx].append(p)
    pfs=[]; prof=0; used=0
    for i,w in enumerate(wins):
        if not w:
            print(f"  window {i+1}: (no trades)"); continue
        pf,net=pf_net(w); pfs.append(pf if pf!=float('inf') else 9.99); used+=1
        if net>0: prof+=1
        a=t0+span*i; b=t0+span*(i+1)
        print(f"  window {i+1} [{a.date()}..{b.date()}]: {len(w):>3} tr  net {net:>8.0f}  PF {pf:.2f}")
    frac=prof/used if used else 0
    med=sorted(pfs)[len(pfs)//2] if pfs else 0
    worst=min(pfs) if pfs else 0
    print("-"*56)
    print(f"  profitable windows: {prof}/{used} ({100*frac:.0f}%)   median PF {med:.2f}   worst PF {worst:.2f}")
    reasons=[]
    if frac < WF_MIN_PROFITABLE_FRAC: reasons.append(f"profitable frac {frac:.2f} < {WF_MIN_PROFITABLE_FRAC}")
    if worst < WF_MIN_WINDOW_PF:      reasons.append(f"worst window PF {worst:.2f} < {WF_MIN_WINDOW_PF}")
    if med  < WF_MIN_MEDIAN_PF:       reasons.append(f"median PF {med:.2f} < {WF_MIN_MEDIAN_PF}")
    print("  WALK-FORWARD: "+("PASS" if not reasons else "FAIL"))
    for r in reasons: print(f"    - {r}")

if __name__=='__main__': main()

#!/usr/bin/env python3
"""
Parameter-neighbourhood STABILITY (deterministic).
Goal is NOT to find the best params — it is to confirm the chosen point sits on a PLATEAU, not a lonely
spike. A lonely spike = overfit (tiny param change collapses performance).

Input CSV (one row per param combo run in the neighbourhood):
  label,is_center,pf,net
  e.g.  EMA20_Age12_BE0.50,1,1.47,10023
        EMA19_Age12_BE0.50,0,1.41,9200
        ...
PASS/FAIL PRE-DECLARED (locked before viewing results):
  PS_MIN_NEIGHBOUR_PF = 1.00   # every neighbour must stay profitable (PF >= 1.00)
  PS_MAX_PEAK_RATIO   = 1.30   # center PF must not exceed 1.30 * neighbour-median (else lonely spike)

Usage: python3 paramstability.py grid_results.csv
"""
import sys, statistics

PS_MIN_NEIGHBOUR_PF = 1.00
PS_MAX_PEAK_RATIO   = 1.30

def main():
    rows=[]
    for l in open(sys.argv[1]):
        l=l.strip()
        if not l or l.lower().startswith('label,'): continue
        parts=l.split(','); rows.append((parts[0], parts[1]=='1', float(parts[2].replace(',','')), float(parts[3].replace(',',''))))
    center=[r for r in rows if r[1]]; nb=[r for r in rows if not r[1]]
    print("="*56); print("PARAMETER-NEIGHBOURHOOD STABILITY"); print("="*56)
    for lbl,c,pf,net in rows:
        print(f"  {'*' if c else ' '} {lbl:<26} PF {pf:.2f}  net {net:.0f}")
    if not center or not nb:
        print("  need one center row (is_center=1) and >=1 neighbour"); return
    cpf=center[0][2]; nb_pf=[r[2] for r in nb]
    nb_med=statistics.median(nb_pf); nb_min=min(nb_pf)
    ratio=cpf/nb_med if nb_med>0 else 99
    print("-"*56)
    print(f"  center PF {cpf:.2f}   neighbour PF: min {nb_min:.2f}  median {nb_med:.2f}   center/median {ratio:.2f}")
    reasons=[]
    if nb_min < PS_MIN_NEIGHBOUR_PF: reasons.append(f"a neighbour collapses: min PF {nb_min:.2f} < {PS_MIN_NEIGHBOUR_PF}")
    if ratio > PS_MAX_PEAK_RATIO:    reasons.append(f"center is a lonely spike: ratio {ratio:.2f} > {PS_MAX_PEAK_RATIO}")
    print("  STABILITY: "+("PASS (plateau)" if not reasons else "FAIL (fragile/overfit)"))
    for r in reasons: print(f"    - {r}")

if __name__=='__main__': main()

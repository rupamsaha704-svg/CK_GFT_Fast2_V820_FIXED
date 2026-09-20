import csv, os
from collections import defaultdict
FIX="20260716"
deals=r"C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\ck_gold_combo_deals.csv"
def num(x):
    try: return float(x)
    except: return None
# columns: magic,dir,entry_time,entry_price,exit_time,exit_price,profit,volume
hn=defaultdict(float); hc=defaultdict(int); hw=defaultdict(int)
with open(deals, newline="") as f:
    rd=csv.reader(f); hdr=next(rd)
    ix={c.strip().lower():i for i,c in enumerate(hdr)}
    for r in rd:
        if len(r)<len(hdr): continue
        if r[ix["magic"]].strip()!=FIX: continue
        et=r[ix["entry_time"]].strip(); p=num(r[ix["profit"]])
        if p is None: continue
        hh=et.split()[1][:2] if " " in et else "??"
        hn[hh]+=p; hc[hh]+=1
        if p>0: hw[hh]+=1
print("FIX09 by ENTRY hour (server) from deals csv -- net$, n, win%")
tot=0
for hh in sorted(hn):
    tot+=hn[hh]
    flag=" <== NEGATIVE" if hn[hh]<0 else ""
    print("  %s : net=%8.2f  n=%3d  win=%3.0f%%%s"%(hh,hn[hh],hc[hh],100.0*hw[hh]/hc[hh] if hc[hh] else 0,flag))
print("  TOTAL FIX09 net=%.2f"%tot)

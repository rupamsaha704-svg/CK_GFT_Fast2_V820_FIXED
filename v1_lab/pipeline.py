#!/usr/bin/env python3
"""
DETERMINISTIC VALIDATION PIPELINE (Design v1.0). Same input => same output. Owns PASS/FAIL.
Uses canonical metrics.py only. Thresholds are PRE-DECLARED here (locked; change = version bump).

Implemented from trade CSVs: Preconditions (P1/P2/P3), K2/K3 killers, M1/M5/M6/M8, Monte Carlo, Walk-Forward.
PENDING (need MT5 runs / extra data, reported as PENDING, never silently passed):
  M3 parameter plateau · M4 cost stress · M7 benchmark suite · K5 locked holdout.

Usage:
  python3 pipeline.py --is IS.csv --oos OOS.csv [--holdout HO.csv] [--deposit 5000] [--spec-hash <sha>]
"""
import argparse, random, statistics
import metrics as M
import cost_stress as CS
import benchmark as BM

# ---- PRE-DECLARED THRESHOLDS (Design v1.0) ----
MIN_OOS_TRADES      = 200
K2_MIN_PF           = 1.00
K2_MIN_EXP          = 0.0
K3_PF_RATIO         = 0.65     # collapse if OOS_PF/IS_PF < this ...
K3_EXP_RATIO        = 0.50     # ... AND OOS_exp/IS_exp < this
M1_MIN_PF           = 1.20
M1_EXP_CI_LB        = 0.0      # 95% CI lower bound of expectancy must exceed this
M5_TOPN             = 10       # remove top-N winners
M6_DROP_FRAC        = 0.10
M6_MIN_POS_FRAC     = 0.95     # >=95% of resamples net>0
M8_MAX_YEAR_SHARE   = 0.80     # no single calendar year > 80% of total net (concentration)
MC_N                = 5000
SEED                = 42

def boot_exp_ci(rows, n=MC_N, seed=SEED):
    random.seed(seed); pls=[p for _,p in rows]; k=len(pls)
    if k==0: return (0,0)
    means=[]
    for _ in range(n):
        s=sum(random.choice(pls) for _ in range(k))/k; means.append(s)
    means.sort(); return (means[int(0.025*n)], means[int(0.975*n)])

def montecarlo(rows, dep, n=MC_N, seed=SEED):
    random.seed(seed); pls=[p for _,p in rows]; k=len(pls)
    def dd(seq):
        eq=dep; pk=dep; m=0.0
        for p in seq:
            eq+=p; pk=max(pk,eq); m=max(m,(pk-eq)/pk)
        return eq-dep, m*100
    nets=[]; dds=[]; los=0
    for _ in range(n):
        seq=[random.choice(pls) for _ in range(k)]
        net,d=dd(seq); nets.append(net); dds.append(d)
        if net<=0: los+=1
    q=lambda a,x: sorted(a)[int(x*len(a))]
    return dict(dd_p95=q(dds,.95), p_losing=100*los/n, net_p5=q(nets,.05))

def concentration(rows, topn=M5_TOPN):
    s=sorted(rows, key=lambda r:r[1], reverse=True)
    kept=s[topn:]
    return M.expectancy(kept), M.profit_factor(kept), len(kept)

def trade_removal(rows, drop=M6_DROP_FRAC, n=MC_N, seed=SEED):
    random.seed(seed); k=len(rows); keepn=int(k*(1-drop)); pos=0
    for _ in range(n):
        idx=random.sample(range(k), keepn)
        if sum(rows[i][1] for i in idx)>0: pos+=1
    return pos/n

def by_year(rows):
    d={}
    for dt,p in rows:
        if dt is None: continue
        d.setdefault(dt.year,0.0); d[dt.year]+=p
    return d

def walkforward(rows, nwin=8):
    r=sorted([x for x in rows if x[0] is not None], key=lambda x:x[0])
    if len(r)<nwin: return None
    t0,t1=r[0][0],r[-1][0]; span=(t1-t0)/nwin
    wins=[[] for _ in range(nwin)]
    for dt,p in r:
        i=min(int((dt-t0)/span),nwin-1); wins[i].append(p)
    pfs=[]; prof=0; used=0; small=0
    for w in wins:
        if not w: continue
        used+=1
        if len(w)<30: small+=1
        gw=sum(x for x in w if x>0); gl=abs(sum(x for x in w if x<0))
        pf=(gw/gl) if gl>0 else (9.99 if gw>0 else 0.0)
        pfs.append(pf)
        if sum(w)>0: prof+=1
    return dict(used=used, prof=prof, frac=(prof/used if used else 0),
                med=(sorted(pfs)[len(pfs)//2] if pfs else 0), worst=(min(pfs) if pfs else 0), small=small)

def line(k,v): print(f"  {k:<34} {v}")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--is', dest='is_', required=True)
    ap.add_argument('--oos', dest='oos', default=None)
    ap.add_argument('--holdout', default=None)
    ap.add_argument('--deposit', type=float, default=M.DEPOSIT_DEFAULT)
    ap.add_argument('--spec-hash', default=None)
    ap.add_argument('--cost-per-trade', type=float, default=None)   # M4 baseline extra cost ($/trade), pre-declared
    ap.add_argument('--price-csv', default=None)                    # M7 benchmark price series (same period as OOS)
    ap.add_argument('--ema', type=int, default=200)                 # M7 trend baseline EMA
    a=ap.parse_args(); dep=a.deposit
    print("="*64); print("DETERMINISTIC VALIDATION PIPELINE — Design v1.0"); print("="*64)

    IS=M.load_trades(a.is_); OOS=M.load_trades(a.oos) if a.oos else None
    si=M.summary(IS,dep)
    print("\n[IN-SAMPLE]"); [line(k,round(v,2) if isinstance(v,float) else v) for k,v in si.items()]
    if OOS:
        so=M.summary(OOS,dep); print("\n[OUT-OF-SAMPLE]"); [line(k,round(v,2) if isinstance(v,float) else v) for k,v in so.items()]

    verdict=None; reasons=[]; pend=[]
    # ---- Preconditions ----
    if a.spec_hash is None: pend.append("P1 integrity hash not supplied (attach manifest)")
    if OOS is None: verdict="INSUFFICIENT"; reasons.append("no OOS provided")
    elif M.n_trades(OOS)<MIN_OOS_TRADES: verdict="INSUFFICIENT"; reasons.append(f"OOS trades {M.n_trades(OOS)}<{MIN_OOS_TRADES}")

    if verdict!="INSUFFICIENT" and OOS:
        pf_o=M.profit_factor(OOS); exp_o=M.expectancy(OOS); pf_i=M.profit_factor(IS); exp_i=M.expectancy(IS)
        ci=boot_exp_ci(OOS); mc=montecarlo(OOS,dep); ce,cp,ck=concentration(OOS); tr=trade_removal(OOS)
        yr=by_year(OOS); tot=sum(yr.values()); maxshare=(max(yr.values())/tot if tot>0 else 1)
        wf=walkforward(OOS)
        print("\n[STAGES on OOS]")
        line("K2 OOS PF>1.0 & exp>0", f"PF {pf_o:.2f} exp {exp_o:.2f}")
        line("K3 IS->OOS collapse", f"PFratio {pf_o/pf_i:.2f} EXPratio {exp_o/exp_i:.2f}" if pf_i>0 and exp_i>0 else "n/a")
        line("M1 OOS PF>=1.20 & exp-CI-LB>0", f"PF {pf_o:.2f}  exp95CI [{ci[0]:.2f},{ci[1]:.2f}]")
        line("M5 concentration (drop top10)", f"exp {ce:.2f}  PF {cp:.2f}")
        line("M6 trade-removal 10% (>=95%net+)", f"{100*tr:.1f}% runs net+")
        line("M8 year concentration (<80%)", f"max-year share {100*maxshare:.0f}%  years {sorted(yr)}")
        line("MC (advisory)", f"DD p95 {mc['dd_p95']:.0f}%  P(losing) {mc['p_losing']:.0f}%  net p5 {mc['net_p5']:.0f}")
        line("WF (>=60%, med>=1.10, >=8win)", (f"{wf['prof']}/{wf['used']} pos, med {wf['med']:.2f}, worst {wf['worst']:.2f}, small-win {wf['small']}" if wf else "insufficient windows"))

        # ---- Killers ----
        if not (pf_o>=K2_MIN_PF and exp_o>K2_MIN_EXP): verdict="REJECT"; reasons.append("K2: no OOS edge")
        if pf_i>0 and exp_i>0 and (pf_o/pf_i<K3_PF_RATIO) and (exp_o/exp_i<K3_EXP_RATIO):
            verdict="REJECT"; reasons.append("K3: severe IS->OOS collapse (overfit)")
        # ---- Mandatory (implemented) ----
        # ---- M4 cost/slippage stress (if baseline cost pre-declared) ----
        m4=None
        if a.cost_per_trade is not None:
            r15=CS.adj(OOS, 1.5*a.cost_per_trade); m4=(M.net_profit(r15)>0 and M.profit_factor(r15)>=1.0)
            line("M4 cost stress @1.5x (net>0,PF>=1)", f"net {M.net_profit(r15):.0f} PF {M.profit_factor(r15):.2f} -> {'PASS' if m4 else 'FAIL'}")
        else: line("M4 cost stress", "PENDING (supply --cost-per-trade, pre-declared)")
        # ---- M7 benchmark suite (if matched-period price supplied) ----
        m7=None
        if a.price_csv:
            px=BM.load_px(a.price_csv); s_ret=so['return_pct']; s_dd=so['max_dd_closed_pct']
            bh=BM.buy_hold(px,0.09,dep); trd=BM.trend(px,0.09,dep,a.ema)
            s_mar=BM.mar(s_ret,s_dd); m7=(s_mar>=BM.mar(*bh) and s_mar>=BM.mar(*trd))
            line("M7 benchmark MAR (>= baselines)", f"strat {s_mar:.2f} | BH {BM.mar(*bh):.2f} | trend {BM.mar(*trd):.2f} -> {'PASS' if m7 else 'FAIL'}")
        else: line("M7 benchmark", "PENDING (supply --price-csv for the OOS period)")
        # ---- K5 locked holdout (if supplied) ----
        k5_fail=False
        if a.holdout:
            HO=M.load_trades(a.holdout); ho_exp=M.expectancy(HO); ho_pf=M.profit_factor(HO)
            k5_fail=not (ho_exp>0 and ho_pf>=1.0)
            line("K5 locked holdout (exp>0,PF>=1)", f"n {M.n_trades(HO)} exp {ho_exp:.2f} PF {ho_pf:.2f} -> {'FAIL->REJECT' if k5_fail else 'ok'}")
        else: line("K5 locked holdout", "PENDING (sealed; supply --holdout once, single unlock)")

        if k5_fail: verdict="REJECT"; reasons.append("K5: locked holdout failed")
        mfail=[]
        if not (pf_o>=M1_MIN_PF and ci[0]>M1_EXP_CI_LB): mfail.append("M1 OOS PF/exp-CI")
        if not (ce>=0 and (cp>=1.0 if M.n_trades(OOS)>=200 else True)): mfail.append("M5 concentration")
        if not (tr>=M6_MIN_POS_FRAC): mfail.append("M6 trade-removal")
        if not (maxshare<=M8_MAX_YEAR_SHARE): mfail.append("M8 year-concentration")
        if not (wf and wf['frac']>=0.60 and wf['med']>=1.10 and wf['used']>=8): mfail.append("M2 walk-forward")
        if m4 is False: mfail.append("M4 cost stress")
        if m7 is False: mfail.append("M7 benchmark")
        if m4 is None: pend.append("M4 cost/slippage stress (supply baseline cost)")
        if m7 is None: pend.append("M7 benchmark suite (supply OOS price)")
        if a.holdout is None: pend.append("K5 locked holdout")
        pend.append("M3 parameter plateau (MT5 grid)")

        if verdict!="REJECT":
            if mfail: verdict="FAIL"; reasons += [f"mandatory miss: {x}" for x in mfail]
            else: verdict="PASS (pending: "+", ".join(pend)+")"

    print("\n"+"="*64); print("VERDICT:", verdict or "INSUFFICIENT"); print("="*64)
    for r in reasons: print("  -",r)
    if pend and verdict and "PASS" not in str(verdict): print("  PENDING stages (need MT5/data):", "; ".join(dict.fromkeys(pend)))
    print("\n  (deterministic: same input => same output; no LLM in this path)")

if __name__=='__main__': main()

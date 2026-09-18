#!/usr/bin/env python3
"""Disciplined test: does a SHORT-TERM REVERSAL (contrarian) sleeve add an UNCORRELATED
out-of-sample edge to the validated crypto+NQ TREND book?

Same universe/engine/conventions as tools/tsmom_bt.py (daily close, forward-filled grid,
inverse-vol sizing, vol-target 10%, 2bps/turn cost, IS<2023 / OOS>=2023, strictly causal:
weight from info through t applied to t->t+1 return).

Anti-overfit discipline:
  - Reversal window is PRE-DECLARED = 5 days (standard weekly reversal). 3 and 10 shown only
    as robustness context, NOT to cherry-pick a winner.
  - Verdict gate (a-priori): ADD only if reversal OOS Sharpe > 0.25 AND |corr to book| < 0.30
    AND it improves the combined book's OOS Sharpe or drawdown. Otherwise REJECT honestly.
"""
import os, csv, math, sys
import numpy as np

DATA = "data_daily"
LOOKBACKS = [20, 60, 120, 250]      # trend (book) — unchanged
VOL_WIN   = 60
TARGET_ANN_VOL = 0.10
COST_PER_TURN = 0.0002              # 2 bps per unit weight traded
ANN = 252
REV_PRIMARY = 5                     # pre-declared weekly reversal
REV_ALTS = [3, 10]                  # robustness context only
BOOK = {"BTC": 0.35, "ETH": 0.35, "NQ": 0.30}   # the validated trend book weights

def load():
    markets = sorted(f[:-4] for f in os.listdir(DATA) if f.endswith(".csv"))
    series = {}
    for m in markets:
        d = {}
        with open(os.path.join(DATA, m + ".csv"), encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                try: d[row["date"]] = float(row["close"])
                except (ValueError, KeyError): pass
        if len(d) > max(LOOKBACKS) + VOL_WIN + 30:
            series[m] = d
    return sorted(series), series

def build_grid(markets, series):
    all_dates = sorted(set().union(*[set(series[m]) for m in markets]))
    T = len(all_dates); idx = {d:i for i,d in enumerate(all_dates)}
    px={}; valid_from={}
    for m in markets:
        arr=np.full(T,np.nan)
        for d,v in series[m].items(): arr[idx[d]]=v
        first=int(np.argmax(~np.isnan(arr))); valid_from[m]=first
        last=arr[first]
        for t in range(first,T):
            if np.isnan(arr[t]): arr[t]=last
            else: last=arr[t]
        px[m]=arr
    ret={m:np.zeros(T) for m in markets}
    for m in markets:
        f=valid_from[m]; ret[m][f+1:]=px[m][f+1:]/px[m][f:-1]-1.0
    return all_dates, T, px, ret, valid_from

def tsmom_w(px, ret, valid_from, T, m):
    W=np.zeros(T); s=valid_from[m]+max(LOOKBACKS)+1
    for t in range(s,T):
        sig=np.mean([np.sign(px[m][t]/px[m][t-Lk]-1.0) for Lk in LOOKBACKS])
        vol=np.std(ret[m][t-VOL_WIN+1:t+1]); W[t]=0.0 if vol<=0 else sig/vol
    return W

def rev_w(px, ret, valid_from, T, m, win):
    W=np.zeros(T); s=valid_from[m]+win+VOL_WIN+1
    for t in range(s,T):
        sig=-np.sign(px[m][t]/px[m][t-win]-1.0)   # CONTRARIAN
        vol=np.std(ret[m][t-VOL_WIN+1:t+1]); W[t]=0.0 if vol<=0 else sig/vol
    return W

def port_net(Wd, ret, subset, first_active, T):
    sret=np.zeros(T); turn=np.zeros(T)
    for t in range(first_active,T):
        pnl=0.0; tv=0.0
        for m in subset:
            pnl+=Wd[m][t-1]*ret[m][t]; tv+=abs(Wd[m][t-1]-Wd[m][t-2])
        sret[t]=pnl; turn[t]=tv
    rv=np.std(sret[first_active:]); sc=(TARGET_ANN_VOL/(rv*math.sqrt(ANN))) if rv>0 else 0.0
    return sret*sc - turn*COST_PER_TURN*sc

def stats(r,i0,i1):
    r=r[i0:i1]
    if len(r)==0 or np.std(r)==0: return dict(sharpe=0,cagr=0,mdd=0,n=len(r))
    eq=np.cumprod(1+r); yrs=len(r)/ANN
    cagr=eq[-1]**(1/yrs)-1 if eq[-1]>0 else -1
    vol=np.std(r)*math.sqrt(ANN); sh=(np.mean(r)*ANN)/vol if vol>0 else 0
    peak=np.maximum.accumulate(eq); mdd=float(np.max((peak-eq)/peak))
    return dict(sharpe=sh,cagr=cagr,mdd=mdd,n=len(r))

CLASS = {"ES":"equity","NQ":"equity","YM":"equity","RTY":"equity","DAX":"equity","NIKKEI":"equity","FTSE":"equity","STOXX":"equity","HSI":"equity",
    "ZN":"bond","ZB":"bond","ZF":"bond","ZT":"bond",
    "CL":"commod","BZ":"commod","NG":"commod","GC":"commod","XAU":"commod","SI":"commod","XAG":"commod","HG":"commod","PL":"commod","PA":"commod","ZC":"commod","ZW":"commod","ZS":"commod","KC":"commod","SB":"commod","CT":"commod","CC":"commod","LE":"commod","HE":"commod",
    "BTC":"crypto","ETH":"crypto",
    "EUR":"fx","GBP":"fx","AUD":"fx","NZD":"fx","USDCAD":"fx","USDCHF":"fx","USDJPY":"fx"}
def klass(m):
    for k,v in CLASS.items():
        if m.startswith(k): return v
    return "other"

def main():
    markets, series = load()
    if not markets: print("NO DATA"); return
    all_dates,T,px,ret,valid_from = build_grid(markets, series)
    first_active=min(valid_from[m]+max(LOOKBACKS)+2 for m in markets)
    split=next((i for i,d in enumerate(all_dates) if d>="2023-01-01"), T)
    out=[]; L=lambda s: out.append(str(s))
    L(f"universe {len(markets)}m, {T} days {all_dates[0]}..{all_dates[-1]}  IS<2023/OOS>=2023")

    # ---- TREND BOOK (validated) returns, for correlation + combo ----
    Wt={m:tsmom_w(px,ret,valid_from,T,m) for m in BOOK if m in markets}
    book_present=[m for m in BOOK if m in markets]
    Wbook={m: BOOK[m]*Wt[m] for m in book_present}
    book=port_net(Wbook, ret, book_present, first_active, T)
    b=stats(book,split,T); bfull=stats(book,first_active,T); bis=stats(book,first_active,split)
    L(f"TREND book {book_present}  FULL Sh {bfull['sharpe']:.2f} | IS {bis['sharpe']:.2f} | OOS {b['sharpe']:.2f} DD {b['mdd']*100:.1f}%")

    by_class={}
    for m in markets: by_class.setdefault(klass(m),[]).append(m)

    def run_rev(win, label, verbose=False):
        Wr={m:rev_w(px,ret,valid_from,T,m,win) for m in markets}
        allr=port_net(Wr,ret,markets,first_active,T)
        exfx=[m for m in markets if klass(m)!="fx"]
        rex=port_net(Wr,ret,exfx,first_active,T)
        a_full=stats(allr,first_active,T); a_oos=stats(allr,split,T)
        x_full=stats(rex,first_active,T); x_oos=stats(rex,split,T)
        # correlation to book over OOS
        cor=np.corrcoef(allr[split:T], book[split:T])[0,1]
        corx=np.corrcoef(rex[split:T], book[split:T])[0,1]
        L(f"  REV{win:<2} ALL   FULL {a_full['sharpe']:5.2f} OOS {a_oos['sharpe']:5.2f} DD {a_oos['mdd']*100:4.1f}%  corr(book)OOS {cor:+.2f}")
        L(f"  REV{win:<2} ex-FX FULL {x_full['sharpe']:5.2f} OOS {x_oos['sharpe']:5.2f} DD {x_oos['mdd']*100:4.1f}%  corr(book)OOS {corx:+.2f}")
        if verbose:
            for c in sorted(by_class):
                rc=port_net(Wr,ret,by_class[c],first_active,T); sc=stats(rc,split,T); fc=stats(rc,first_active,T)
                L(f"      {c:7} FULL {fc['sharpe']:5.2f} OOS {sc['sharpe']:5.2f}")
        return allr, rex

    L(""); L(f"=== REVERSAL primary (win={REV_PRIMARY}) — per class ===")
    rev_all, rev_ex = run_rev(REV_PRIMARY, "primary", verbose=True)
    L(""); L("=== robustness (NOT for cherry-picking) ===")
    for w in REV_ALTS: run_rev(w, f"alt{w}")

    # ---- COMBO: book + reversal sleeve (both vol-targeted to 10%) ----
    L(""); L("=== COMBO book + REV(primary) : does adding it help? ===")
    def combo_stats(a, rev_series, name):
        c = a*book + (1-a)*rev_series
        s=stats(c,split,T); f=stats(c,first_active,T)
        L(f"  {name} a={a:.2f}  FULL Sh {f['sharpe']:.2f} | OOS Sh {s['sharpe']:.2f} DD {s['mdd']*100:.1f}%")
    L(f"  (book alone: OOS Sh {b['sharpe']:.2f} DD {b['mdd']*100:.1f}%)")
    for a in (0.80,0.70,0.60):
        combo_stats(a, rev_all, "book+REV_ALL ")
    for a in (0.80,0.70,0.60):
        combo_stats(a, rev_ex, "book+REV_exFX")

    open("tools/reversal_sleeve_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-REV\n")
    print("\n".join(out)); print("DONE-REV")

if __name__=="__main__":
    main()

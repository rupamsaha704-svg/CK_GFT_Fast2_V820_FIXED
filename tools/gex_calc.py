#!/usr/bin/env python3
"""Free GEX engine using CBOE delayed-quotes cdn (gamma + OI provided).
Computes net dealer Gamma Exposure + call/put walls for an index/ETF, prints,
appends a daily summary row, and saves the full snapshot (to build our OWN
historical GEX dataset over time -> eventually backtestable, disciplined & free).
Usage: gex_calc.py [_NDX|QQQ|_SPX]   (default _NDX = Nasdaq-100)
Convention: dealer GEX = sum(gamma*OI) calls - puts, x100 x spot^2 x 0.01 ($/1% move).
Positive GEX -> dealers dampen (mean-revert/pin);  Negative -> amplify (trend/volatile).
"""
import urllib.request, json, sys, os, datetime as dt
UA=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36")
SYM = sys.argv[1] if len(sys.argv)>1 else "_NDX"
os.makedirs("data_gex/snapshots", exist_ok=True)

def parse_osi(s):
    # ...ROOT + YYMMDD + [C/P] + 8-digit strike(x0.001); parse from the right
    strike=int(s[-8:])/1000.0; cp=s[-9]; d=s[-15:-9]
    exp="20{}-{}-{}".format(d[0:2],d[2:4],d[4:6])
    return exp, cp, strike

def main():
    url=f"https://cdn.cboe.com/api/global/delayed_quotes/options/{SYM}.json"
    raw=urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":UA}),timeout=45).read()
    j=json.loads(raw); d=j.get("data",{})
    spot=d.get("current_price") or d.get("close")
    opts=d.get("options",[])
    rows=[]
    call_g={}; put_g={}
    net=0.0
    for o in opts:
        try:
            exp,cp,strike=parse_osi(o["option"])
            g=float(o.get("gamma") or 0); oi=float(o.get("open_interest") or 0)
        except Exception:
            continue
        if oi<=0 or g==0: 
            rows.append((exp,cp,strike,g,oi)); continue
        dollar = g*oi*100.0*spot*spot*0.01
        if cp=="C": net+=dollar; call_g[strike]=call_g.get(strike,0)+g*oi
        else:       net-=dollar; put_g[strike]=put_g.get(strike,0)+g*oi
        rows.append((exp,cp,strike,g,oi))
    # walls: strike above spot with max call gamma*OI ; below spot with max put gamma*OI
    call_wall=max([k for k in call_g if k>=spot], key=lambda k:call_g[k], default=None)
    put_wall =max([k for k in put_g  if k<=spot], key=lambda k:put_g[k],  default=None)
    gex_bn=net/1e9
    today=dt.date.today().isoformat()
    line=f"{SYM} {today}  spot={spot:.1f}  net_GEX=${gex_bn:+.2f}bn/1%  regime={'POSITIVE(dampen)' if net>0 else 'NEGATIVE(amplify)'}  call_wall={call_wall}  put_wall={put_wall}  contracts={len(opts)}"
    print(line)
    # daily summary append
    summ=f"data_gex/{SYM}_gex.csv"
    newf=not os.path.exists(summ)
    with open(summ,"a",encoding="utf-8") as f:
        if newf: f.write("date,spot,net_gex_bn,regime,call_wall,put_wall,contracts\n")
        f.write(f"{today},{spot:.2f},{gex_bn:.4f},{'POS' if net>0 else 'NEG'},{call_wall},{put_wall},{len(opts)}\n")
    # full snapshot for future backtest
    snap=f"data_gex/snapshots/{SYM}_{today}.csv"
    with open(snap,"w",encoding="utf-8") as f:
        f.write("exp,cp,strike,gamma,oi\n")
        for exp,cp,strike,g,oi in rows:
            f.write(f"{exp},{cp},{strike},{g},{oi}\n")
    open("tools/gex_calc_out.txt","w",encoding="utf-8").write(line+f"\nsnapshot: {snap}\nsummary: {summ}\nDONE-GEX\n")
    print("snapshot saved:",snap); print("DONE-GEX")

if __name__=="__main__":
    main()

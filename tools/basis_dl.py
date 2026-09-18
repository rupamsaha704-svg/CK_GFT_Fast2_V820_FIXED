#!/usr/bin/env python3
"""Pull Binance SPOT + PERP daily closes (free, public) to compute the real basis for
carry backtesting. Saves data_funding/<SYM>_px.csv: date,spot_close,perp_close."""
import urllib.request, json, os, time, datetime as dt
UA="Mozilla/5.0"; os.makedirs("data_funding",exist_ok=True)
def get(url):
    try: return urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":UA}),timeout=30).read()
    except Exception as e: return None
def klines(host, path, sym):
    out={}; start=1577836800000
    for _ in range(40):
        b=get(f"https://{host}{path}?symbol={sym}&interval=1d&limit=1000&startTime={start}")
        if not b: break
        try: arr=json.loads(b)
        except Exception: break
        if not isinstance(arr,list) or not arr: break
        for k in arr:
            day=dt.datetime.utcfromtimestamp(int(k[0])/1000).strftime("%Y-%m-%d")
            out[day]=float(k[4])
        last=int(arr[-1][0])
        if last<=start: break
        start=last+86400000; time.sleep(0.25)
        if len(arr)<1000: break
    return out
res=[]
for sym in ["BTCUSDT","ETHUSDT"]:
    spot=klines("api.binance.com","/api/v3/klines",sym)
    perp=klines("fapi.binance.com","/fapi/v1/klines",sym)
    days=sorted(set(spot)&set(perp))
    if not days: res.append(f"{sym}: FAIL spot={len(spot)} perp={len(perp)}"); continue
    with open(f"data_funding/{sym}_px.csv","w",encoding="utf-8") as f:
        f.write("date,spot_close,perp_close\n")
        for d in days: f.write(f"{d},{spot[d]},{perp[d]}\n")
    b0=(perp[days[0]]-spot[days[0]])/spot[days[0]]*100
    res.append(f"{sym}: {len(days)} days {days[0]}..{days[-1]}  first_basis={b0:+.2f}%")
open("tools/basis_dl_out.txt","w",encoding="utf-8").write("\n".join(res)+"\nDONE-BASIS\n")
print("\n".join(res)); print("DONE-BASIS")

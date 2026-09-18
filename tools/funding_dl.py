#!/usr/bin/env python3
"""Download Binance perpetual FUNDING-RATE history (free, no key) for carry research.
fapi/v1/fundingRate, paginated. Saves data_funding/<SYM>.csv: fundingTime_ms,rate.
Funding is exchanged every 8h; long-spot + short-perp (delta-neutral) receives it when +."""
import urllib.request, json, os, time
UA="Mozilla/5.0"
os.makedirs("data_funding", exist_ok=True)
def get(url):
    try:
        return urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":UA}),timeout=30).read()
    except urllib.error.HTTPError as e: return ("HTTP%s"%e.code).encode()
    except Exception as e: return ("ERR:%s"%type(e).__name__).encode()
def pull(sym, host):
    url0=f"https://{host}/fapi/v1/fundingRate?symbol={sym}&limit=1000"
    b=get(url0)
    try: first=json.loads(b)
    except Exception: return None, b[:60].decode(errors="replace")
    if not isinstance(first,list): return None, str(first)[:80]
    # paginate backward-forward: start from earliest known, walk forward
    rows={}
    start=1577836800000   # 2020-01-01, walk FORWARD
    for _ in range(40):
        u=f"https://{host}/fapi/v1/fundingRate?symbol={sym}&limit=1000&startTime={start}"
        b=get(u)
        try: arr=json.loads(b)
        except Exception: break
        if not isinstance(arr,list) or not arr: break
        for r in arr:
            rows[int(r["fundingTime"])]=float(r["fundingRate"])
        last=int(arr[-1]["fundingTime"])
        if last<=start: break
        start=last+1
        time.sleep(0.3)
        if len(arr)<1000: break
    return rows, "ok"
out=[]
for sym in ["BTCUSDT","ETHUSDT"]:
    rows=None
    for host in ["fapi.binance.com","fapi.binance.com"]:
        rows,msg=pull(sym,host)
        if rows: break
    if not rows:
        out.append(f"{sym}: FAIL ({msg})"); continue
    ks=sorted(rows)
    import datetime as dt
    with open(f"data_funding/{sym}.csv","w",encoding="utf-8") as f:
        f.write("time_ms,rate\n")
        for k in ks: f.write(f"{k},{rows[k]}\n")
    a=dt.datetime.utcfromtimestamp(ks[0]/1000).date(); b=dt.datetime.utcfromtimestamp(ks[-1]/1000).date()
    avg=sum(rows.values())/len(rows)
    out.append(f"{sym}: {len(ks)} funding pts {a}..{b}  avg={avg*100:.4f}%/8h (~{avg*3*365*100:.1f}%/yr)")
open("tools/funding_dl_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-FUND\n")
print("\n".join(out)); print("DONE-FUND")

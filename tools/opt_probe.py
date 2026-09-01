#!/usr/bin/env python3
"""Probe options-data availability for GEX (Nasdaq via QQQ/NDX).
Checks Yahoo options endpoint: current chain, open interest, implied vol.
GEX needs strike-wise OI + IV (for gamma). Historical = the hard part."""
import urllib.request, json
UA=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36")
out=[]
def L(s): out.append(str(s))
def get(url):
    try:
        r=urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":UA,"Accept":"application/json"}),timeout=30)
        return r.status, r.read()
    except urllib.error.HTTPError as e: return e.code, None
    except Exception as e: return None, str(e).encode()
for sym in ["QQQ","^NDX","SPY"]:
    st,b=get(f"https://query1.finance.yahoo.com/v7/finance/options/{urllib.parse.quote(sym)}") if False else get(f"https://query1.finance.yahoo.com/v7/finance/options/{sym}")
    L(f"[{sym}] status={st} bytes={len(b) if b else 0}")
    if st==200 and b:
        try:
            j=json.loads(b); res=j["optionChain"]["result"]
            if res:
                r0=res[0]; exps=r0.get("expirationDates",[])
                quote=r0.get("quote",{}); price=quote.get("regularMarketPrice")
                opts=r0.get("options",[])
                calls=opts[0].get("calls",[]) if opts else []
                puts=opts[0].get("puts",[]) if opts else []
                L(f"    price={price} expirations={len(exps)} firstExp_calls={len(calls)} puts={len(puts)}")
                if calls:
                    c=calls[len(calls)//2]
                    L(f"    sample call keys: strike={c.get('strike')} OI={c.get('openInterest')} IV={c.get('impliedVolatility')} gamma={c.get('gamma','NOT_PROVIDED')}")
        except Exception as e:
            L(f"    parse err: {e}")
import urllib.parse
open("tools/opt_probe_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-OPT\n")
print("\n".join(out)); print("DONE-OPT")

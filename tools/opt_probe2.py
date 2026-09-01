#!/usr/bin/env python3
"""Probe FREE options-chain sources for GEX (current chain w/ gamma+OI).
CBOE delayed-quotes cdn (gives greeks incl gamma!), nasdaq API."""
import urllib.request, json
UA=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36")
out=[]; L=lambda s: out.append(str(s))
def get(url, hdr=None):
    h={"User-Agent":UA,"Accept":"application/json"}
    if hdr: h.update(hdr)
    try:
        r=urllib.request.urlopen(urllib.request.Request(url,headers=h),timeout=30)
        return r.status, r.read()
    except urllib.error.HTTPError as e: return e.code, (e.read() if hasattr(e,'read') else None)
    except Exception as e: return None, str(e).encode()

# CBOE cdn delayed quotes (free). ETF: QQQ.json ; Index: _NDX.json / _SPX.json
for url in ["https://cdn.cboe.com/api/global/delayed_quotes/options/QQQ.json",
            "https://cdn.cboe.com/api/global/delayed_quotes/options/_NDX.json",
            "https://cdn.cboe.com/api/global/delayed_quotes/options/_SPX.json"]:
    st,b=get(url)
    L(f"[CBOE {url.split('/')[-1]}] status={st} bytes={len(b) if b else 0}")
    if st==200 and b:
        try:
            j=json.loads(b); d=j.get("data",{})
            opts=d.get("options",[])
            L(f"    underlying={d.get('close') or d.get('current_price')} n_options={len(opts)}")
            if opts:
                o=opts[len(opts)//2]
                L(f"    sample keys: {list(o.keys())}")
                L(f"    sample: opt={o.get('option')} OI={o.get('open_interest')} gamma={o.get('gamma')} iv={o.get('iv')}")
        except Exception as e:
            L(f"    parse err {e}")

# nasdaq API (backup)
st,b=get("https://api.nasdaq.com/api/quote/QQQ/option-chain?assetclass=etf&limit=10",
         hdr={"Accept":"application/json, text/plain, */*","Origin":"https://www.nasdaq.com","Referer":"https://www.nasdaq.com/"})
L(f"[nasdaq QQQ] status={st} bytes={len(b) if b else 0}")

open("tools/opt_probe2_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-OPT2\n")
print("\n".join(out)); print("DONE-OPT2")

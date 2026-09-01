#!/usr/bin/env python3
"""Download DAILY OHLC for a BROAD crypto universe from Yahoo -> data_crypto/.
Used to stress-test whether the crypto TSMOM edge is robust (not BTC/ETH luck)."""
import urllib.request, urllib.parse, json, os, datetime as dt
UA=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36")
OUT="data_crypto"; os.makedirs(OUT,exist_ok=True)
COINS=["BTC","ETH","BNB","XRP","SOL","ADA","DOGE","LTC","BCH","LINK","DOT","AVAX","MATIC","TRX","XLM","ATOM","ETC","UNI","AAVE","ALGO"]
def fetch(tk):
    url=f"https://query1.finance.yahoo.com/v8/finance/chart/{urllib.parse.quote(tk)}?range=10y&interval=1d"
    raw=urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":UA}),timeout=45).read()
    res=json.loads(raw)["chart"]["result"][0]; ts=res["timestamp"]; q=res["indicators"]["quote"][0]
    rows=[]
    for i,t in enumerate(ts):
        o,h,l,c=q["open"][i],q["high"][i],q["low"][i],q["close"][i]
        if c is None or o is None: continue
        rows.append((dt.datetime.utcfromtimestamp(t).strftime("%Y-%m-%d"),o,h,l,c))
    return rows
out=[]
for c in COINS:
    tk=c+"-USD"
    try:
        rows=fetch(tk)
        if len(rows)<200: out.append(f"{c:6} too few ({len(rows)})"); continue
        with open(os.path.join(OUT,c+".csv"),"w",encoding="utf-8") as f:
            f.write("date,open,high,low,close\n")
            for d,o,h,l,cl in rows: f.write(f"{d},{o},{h},{l},{cl}\n")
        out.append(f"{c:6} OK {len(rows)} bars {rows[0][0]}..{rows[-1][0]}")
    except Exception as e:
        out.append(f"{c:6} ERR {type(e).__name__}: {e}")
open("tools/yahoo_crypto_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-CRYPTO\n")
print("\n".join(out)); print("DONE-CRYPTO")

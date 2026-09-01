#!/usr/bin/env python3
"""Download multi-year DAILY OHLC for the TSMOM universe from Yahoo Finance chart API.
Saves data_daily/<MARKET>.csv (date,open,high,low,close). Reports coverage.
Free, no key. Used for portfolio time-series-momentum research."""
import urllib.request, urllib.parse, json, os, datetime as dt

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
OUTDIR = "data_daily"
os.makedirs(OUTDIR, exist_ok=True)

# market -> candidate Yahoo tickers (first that works wins). Broad multi-asset universe
# (equity indices, bonds, commodities, crypto, FX) = the proper TSMOM universe.
MARKETS = {
    # equity indices (futures + cash)
    "ES": ["ES=F"], "NQ": ["NQ=F"], "YM": ["YM=F"], "RTY": ["RTY=F"],
    "DAX": ["^GDAXI"], "NIKKEI": ["^N225"], "FTSE": ["^FTSE"], "STOXX": ["^STOXX50E"], "HSI": ["^HSI"],
    # bond futures
    "ZN": ["ZN=F"], "ZB": ["ZB=F"], "ZF": ["ZF=F"], "ZT": ["ZT=F"],
    # commodities
    "CL": ["CL=F"], "BZ": ["BZ=F"], "NG": ["NG=F"], "GC": ["GC=F"], "SI": ["SI=F"],
    "HG": ["HG=F"], "PL": ["PL=F"], "PA": ["PA=F"], "ZC": ["ZC=F"], "ZW": ["ZW=F"],
    "ZS": ["ZS=F"], "KC": ["KC=F"], "SB": ["SB=F"], "CT": ["CT=F"], "CC": ["CC=F"],
    "LE": ["LE=F"], "HE": ["HE=F"],
    # crypto
    "BTC": ["BTC-USD"], "ETH": ["ETH-USD"],
    # FX majors
    "EURUSD": ["EURUSD=X"], "GBPUSD": ["GBPUSD=X"], "AUDUSD": ["AUDUSD=X"],
    "NZDUSD": ["NZDUSD=X"], "USDCAD": ["USDCAD=X"], "USDCHF": ["USDCHF=X"], "USDJPY": ["USDJPY=X"],
}

def fetch(ticker):
    url = (f"https://query1.finance.yahoo.com/v8/finance/chart/{urllib.parse.quote(ticker)}"
           f"?range=10y&interval=1d")
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    raw = urllib.request.urlopen(req, timeout=45).read()
    j = json.loads(raw)
    res = j["chart"]["result"][0]
    ts = res["timestamp"]
    q = res["indicators"]["quote"][0]
    rows = []
    for i, t in enumerate(ts):
        o, h, l, c = q["open"][i], q["high"][i], q["low"][i], q["close"][i]
        if c is None or o is None:
            continue
        d = dt.datetime.utcfromtimestamp(t).strftime("%Y-%m-%d")
        rows.append((d, o, h, l, c))
    return rows

out = []
def L(s):
    out.append(str(s))

for mkt, tickers in MARKETS.items():
    done = False
    for tk in tickers:
        try:
            rows = fetch(tk)
            if len(rows) < 50:
                L(f"{mkt:8} {tk:10} too few rows ({len(rows)})"); continue
            with open(os.path.join(OUTDIR, mkt + ".csv"), "w", encoding="utf-8") as f:
                f.write("date,open,high,low,close\n")
                for d, o, h, l, c in rows:
                    f.write(f"{d},{o},{h},{l},{c}\n")
            L(f"{mkt:8} {tk:10} OK  {len(rows)} bars  {rows[0][0]} .. {rows[-1][0]}")
            done = True
            break
        except Exception as e:
            L(f"{mkt:8} {tk:10} ERR {type(e).__name__}: {e}")
    if not done:
        L(f"{mkt:8} FAILED all tickers")

open("tools/yahoo_dl_out.txt", "w", encoding="utf-8").write("\n".join(out) + "\nDONE-YAHOO\n")
print("\n".join(out)); print("DONE-YAHOO")

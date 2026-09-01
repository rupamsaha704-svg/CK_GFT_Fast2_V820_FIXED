#!/usr/bin/env python3
"""Connectivity probe: which free data sources can this machine reach?
Writes result + DONE sentinel to net_probe_out.txt"""
import urllib.request, json, sys

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")

def get(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    try:
        r = urllib.request.urlopen(req, timeout=timeout)
        b = r.read()
        return r.status, b
    except urllib.error.HTTPError as e:
        return e.code, b"(httperror)"
    except Exception as e:
        return None, (type(e).__name__ + ": " + str(e)).encode()

lines = []
def log(s):
    lines.append(s)

# 1) general internet
st, b = get("https://www.google.com/generate_204")
log(f"[google 204]      status={st} bytes={len(b) if b else 0}")

# 2) Binance klines BTCUSDT 1m (easiest BTC source)
st, b = get("https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=1m&limit=3")
log(f"[binance klines]  status={st} bytes={len(b) if b else 0}")
if st == 200:
    try:
        j = json.loads(b)
        log(f"    sample: {j[0][:5]}")
    except Exception as e:
        log(f"    parse err {e}")

# 2b) Binance data vision (bulk historical zip listing)
st, b = get("https://data.binance.vision/data/spot/monthly/klines/BTCUSDT/1m/BTCUSDT-1m-2024-01.zip", timeout=25)
log(f"[binance.vision]  status={st} bytes={len(b) if b else 0}")

# 3) Yahoo finance chart for Nasdaq100 (^NDX) daily
st, b = get("https://query1.finance.yahoo.com/v8/finance/chart/%5ENDX?range=5d&interval=1d")
log(f"[yahoo ^NDX]      status={st} bytes={len(b) if b else 0}")

# 4) Stooq daily nasdaq
st, b = get("https://stooq.com/q/d/l/?s=%5Endq&i=d")
log(f"[stooq ndq]       status={st} bytes={len(b) if b else 0}")
if st == 200 and b:
    log("    head: " + b[:80].decode(errors='replace').replace(chr(10),' '))

# 5) Dukascopy root + a datafeed path
st, b = get("https://www.dukascopy.com/", timeout=20)
log(f"[dukascopy www]   status={st} bytes={len(b) if b else 0}")
st, b = get("https://datafeed.dukascopy.com/datafeed/BTCUSD/2024/05/20/13h_ticks.bi5", timeout=20)
log(f"[duka datafeed]   status={st} bytes={len(b) if b else 0}")

open("tools/net_probe_out.txt", "w", encoding="utf-8").write("\n".join(lines) + "\n=== DONE-NET ===\n")
print("\n".join(lines))
print("=== DONE-NET ===")

#!/usr/bin/env python3
"""Throttled search for the correct Dukascopy index code (8s gaps to avoid 503).
Writes incrementally so partial progress is visible."""
import urllib.request, lzma, struct, time
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
OUT = "tools/nasfind_out.txt"
lines = []
def flush():
    open(OUT,"w",encoding="utf-8").write("\n".join(lines)+"\n")
def log(s):
    lines.append(str(s)); flush()

def probe(code, y=2024, m0=4, d=20, h=15):
    url = f"https://datafeed.dukascopy.com/datafeed/{code}/{y:04d}/{m0:02d}/{d:02d}/{h:02d}h_ticks.bi5"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
        data = urllib.request.urlopen(req, timeout=40).read()
        if not data:
            return f"[{code}] EMPTY-200 (valid code, no ticks this hour)"
        raw = lzma.decompress(data, format=lzma.FORMAT_AUTO)
        n = len(raw)//20
        ms, ask, bid, av, bv = struct.unpack_from(">IIIff", raw, 0)
        return f"[{code}] VALID {len(data)}B -> {n} ticks  askRaw={ask} (/1000={ask/1000:.3f})"
    except urllib.error.HTTPError as e:
        return f"[{code}] HTTP {e.code}"
    except Exception as e:
        return f"[{code}] ERR {type(e).__name__}: {e}"

log("start")
for code in ["DEUIDXEUR", "USATECHIDXUSD", "NDXUSD", "US100USD", "USATEC.IDXUSD", "USSC2000IDXUSD"]:
    log(probe(code))
    time.sleep(8)
log("DONE-NASFIND")

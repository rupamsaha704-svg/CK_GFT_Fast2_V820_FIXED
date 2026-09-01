#!/usr/bin/env python3
"""One clean request to confirm USATECHIDXUSD (classic Dukascopy Nasdaq 100 code)."""
import urllib.request, lzma, struct
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
out = []
code = "USATECHIDXUSD"
url = f"https://datafeed.dukascopy.com/datafeed/{code}/2024/04/20/15h_ticks.bi5"
try:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    data = urllib.request.urlopen(req, timeout=50).read()
    if not data:
        out.append(f"[{code}] EMPTY-200 valid code no ticks")
    else:
        raw = lzma.decompress(data, format=lzma.FORMAT_AUTO)
        n = len(raw)//20
        ms, ask, bid, av, bv = struct.unpack_from(">IIIff", raw, 0)
        out.append(f"[{code}] VALID {len(data)}B -> {n} ticks askRaw={ask} /1000={ask/1000:.3f}")
except urllib.error.HTTPError as e:
    out.append(f"[{code}] HTTP {e.code}")
except Exception as e:
    out.append(f"[{code}] ERR {type(e).__name__}: {e}")
open("tools/one_nas2_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-ONENAS2\n")

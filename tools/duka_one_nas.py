#!/usr/bin/env python3
"""Single request to confirm NAS100 Dukascopy code."""
import urllib.request, lzma, struct
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
out = []
def log(s): out.append(str(s))
for code in ["USA100IDXUSD"]:
    url = f"https://datafeed.dukascopy.com/datafeed/{code}/2024/04/20/15h_ticks.bi5"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
        data = urllib.request.urlopen(req, timeout=45).read()
        raw = lzma.decompress(data, format=lzma.FORMAT_AUTO)
        n = len(raw)//20
        log(f"[{code}] OK bytes={len(data)} -> {n} ticks")
        for i in range(min(3, n)):
            ms, ask, bid, av, bv = struct.unpack_from(">IIIff", raw, i*20)
            log(f"  ms={ms} askRaw={ask} bidRaw={bid} /1000={ask/1000:.3f} /100={ask/100:.2f}")
    except Exception as e:
        log(f"[{code}] ERR {type(e).__name__}: {e}")
open("tools/one_nas_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-ONENAS\n")

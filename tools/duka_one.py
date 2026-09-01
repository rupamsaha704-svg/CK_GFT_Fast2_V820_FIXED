#!/usr/bin/env python3
"""Single fast Dukascopy request: confirm .bi5 LZMA decode. No sleeps, one request."""
import urllib.request, lzma, struct

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
out = []
def log(s): out.append(str(s)); print(s, flush=True)

url = "https://datafeed.dukascopy.com/datafeed/BTCUSD/2024/04/20/13h_ticks.bi5"
try:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    data = urllib.request.urlopen(req, timeout=45).read()
    log(f"status OK bytes={len(data)}")
    open("tools/sample.bi5","wb").write(data)
    for name, kw in [("AUTO", dict(format=lzma.FORMAT_AUTO)),
                     ("ALONE", dict(format=lzma.FORMAT_ALONE))]:
        try:
            raw = lzma.decompress(data, **kw)
            log(f"DECODE OK via {name}: {len(raw)}B -> {len(raw)//20} ticks")
            for i in range(min(3, len(raw)//20)):
                ms, ask, bid, av, bv = struct.unpack_from(">IIIff", raw, i*20)
                log(f"  ms={ms} ask={ask/1000:.3f} bid={bid/1000:.3f}")
            break
        except Exception as e:
            log(f"  {name} failed: {type(e).__name__}: {e}")
    else:
        try:
            filt = [{"id": lzma.FILTER_LZMA1, "dict_size": 1 << 23}]
            d = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=filt)
            raw = d.decompress(data)
            log(f"DECODE OK via RAW_LZMA1: {len(raw)}B -> {len(raw)//20} ticks")
        except Exception as e:
            log(f"  RAW_LZMA1 failed: {type(e).__name__}: {e}")
except Exception as e:
    log("ERR: " + type(e).__name__ + ": " + str(e))
open("tools/one_out.txt","w",encoding="utf-8").write("\n".join(out)+"\nDONE-ONE\n")

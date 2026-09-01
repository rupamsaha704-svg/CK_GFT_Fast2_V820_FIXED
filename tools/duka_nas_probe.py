#!/usr/bin/env python3
"""Robust Dukascopy probe: (1) confirm .bi5 LZMA decode method, (2) find NAS100 code.
Always writes output file even on error (try/finally)."""
import urllib.request, lzma, struct, time

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
out = []
def log(s): out.append(str(s))

def dl(code, y, m0, d, h):
    url = f"https://datafeed.dukascopy.com/datafeed/{code}/{y:04d}/{m0:02d}/{d:02d}/{h:02d}h_ticks.bi5"
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    try:
        r = urllib.request.urlopen(req, timeout=30)
        return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, None
    except Exception as e:
        return None, ("EXC:"+type(e).__name__+":"+str(e))

def decode(data):
    # try several LZMA framings used for .bi5
    errs = []
    for name, fmt in [("AUTO", lzma.FORMAT_AUTO), ("ALONE", lzma.FORMAT_ALONE)]:
        try:
            return name, lzma.decompress(data, format=fmt)
        except Exception as e:
            errs.append(f"{name}:{type(e).__name__}")
    # raw LZMA1 with explicit filter (dukascopy classic)
    try:
        filt = [{"id": lzma.FILTER_LZMA1, "dict_size": 1 << 23}]
        d = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=filt)
        return "RAW_LZMA1", d.decompress(data)
    except Exception as e:
        errs.append(f"RAW:{type(e).__name__}")
    return None, ("all-fail: " + ",".join(errs)).encode()

try:
    st, data = dl("BTCUSD", 2024, 4, 20, 13)
    log(f"[BTCUSD 2024-05-20 13h] status={st} bytes={len(data) if isinstance(data,(bytes,bytearray)) else data}")
    if isinstance(data,(bytes,bytearray)) and data:
        name, raw = decode(data)
        if name:
            n = len(raw)//20
            log(f"   DECODE OK via {name}: {len(raw)}B -> {n} ticks")
            for i in range(min(3,n)):
                ms, ask, bid, av, bv = struct.unpack_from(">IIIff", raw, i*20)
                log(f"   ms={ms} askRaw={ask} bidRaw={bid} /1000 ask={ask/1000:.3f} bid={bid/1000:.3f} avol={av:.2f}")
        else:
            log("   DECODE FAILED: " + raw.decode(errors='replace'))
    time.sleep(5)
    for c in ["USA100IDXUSD", "USATECHIDXUSD"]:
        st, data = dl(c, 2024, 4, 20, 15)
        nb = len(data) if isinstance(data,(bytes,bytearray)) else data
        tag = ""
        if isinstance(data,(bytes,bytearray)) and data:
            name, raw = decode(data)
            tag = f" DECODE {name} -> {len(raw)//20 if name else '?'} ticks" if name else " decode-fail"
        log(f"[{c} 2024-05-20 15h] status={st} bytes={nb}{tag}")
        time.sleep(5)
except Exception as e:
    log("FATAL: " + type(e).__name__ + ": " + str(e))
finally:
    open("tools/nas_probe_out.txt","w",encoding="utf-8").write("\n".join(out)+"\n=== DONE-NAS ===\n")
    print("\n".join(out)); print("=== DONE-NAS ===")

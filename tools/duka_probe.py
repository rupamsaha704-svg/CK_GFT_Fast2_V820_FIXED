#!/usr/bin/env python3
"""Probe Dukascopy free tick feed: confirm reachability, correct codes, and the
latest AVAILABLE date (real server may not have 2026 data).
URL: https://datafeed.dukascopy.com/datafeed/{CODE}/{YYYY}/{MM0}/{DD}/{HH}h_ticks.bi5  (MM0 = month-1)
"""
import urllib.request, lzma

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")

def try_dl(code, y, m0, d, h):
    url = f"https://datafeed.dukascopy.com/datafeed/{code}/{y:04d}/{m0:02d}/{d:02d}/{h:02d}h_ticks.bi5"
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    try:
        r = urllib.request.urlopen(req, timeout=30)
        data = r.read()
        code_status = r.status
    except urllib.error.HTTPError as e:
        return f"  {y}-{m0+1:02d}-{d:02d} {h}h  HTTP {e.code}"
    except Exception as e:
        return f"  {y}-{m0+1:02d}-{d:02d} {h}h  ERR {type(e).__name__}: {e}"
    if not data:
        return f"  {y}-{m0+1:02d}-{d:02d} {h}h  EMPTY 200 (no data this hour)"
    try:
        raw = lzma.decompress(data)
        return f"  {y}-{m0+1:02d}-{d:02d} {h}h  OK {len(data)}B -> {len(raw)//20} ticks"
    except Exception as e:
        return f"  {y}-{m0+1:02d}-{d:02d} {h}h  {len(data)}B decompress-fail: {e}"

print("=== BTCUSD across dates (find latest available) ===")
for (y, m0, d, h) in [(2026,7,20,13),(2025,7,20,13),(2025,4,15,13),
                      (2024,5,20,13),(2023,0,10,13)]:
    print(try_dl("BTCUSD", y, m0, d, h))

print("=== NAS100 code candidates on a safe old date 2024-05-20 15h ===")
for c in ["USA100IDXUSD","US100USD","NAS100USD","USATECHIDXUSD","USATEC.IDXUSD","USA30IDXUSD"]:
    print(f"{c:16}", try_dl(c, 2024, 4, 20, 15).strip())

#!/usr/bin/env python3
"""Download BTCUSDT 1-minute klines from Binance public data (data.binance.vision),
combine to a single MT5-import CSV: epoch_sec,open,high,low,close,volume (UTC).
Usage: binance_dl.py SYMBOL START_YYYY-MM END_YYYY-MM OUT.csv
Monthly zips for complete months; daily zips for the current (partial) month.
"""
import urllib.request, io, zipfile, sys, datetime as dt

UA = "Mozilla/5.0"
BASE = "https://data.binance.vision/data/spot"

def get(url, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        return urllib.request.urlopen(req, timeout=timeout).read()
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:
        return type(e).__name__

def parse_zip(b):
    rows = []
    z = zipfile.ZipFile(io.BytesIO(b))
    name = z.namelist()[0]
    for line in z.read(name).decode().splitlines():
        p = line.split(",")
        try:
            t = int(p[0])          # openTime ms (may be microseconds in newer files)
            if t > 4102444800000:  # > year 2100 in ms => it's microseconds
                t //= 1000
            o, h, l, c, v = p[1], p[2], p[3], p[4], p[5]
            float(o)
        except (ValueError, IndexError):
            continue
        rows.append((t // 1000, o, h, l, c, v))  # epoch seconds
    return rows

def months(start, end):
    y, m = [int(x) for x in start.split("-")]
    ey, em = [int(x) for x in end.split("-")]
    while (y, m) <= (ey, em):
        yield y, m
        m += 1
        if m > 12:
            m = 1; y += 1

def main():
    sym, start, end, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    log = open(out + ".log", "w", encoding="utf-8")
    def L(s):
        log.write(s + "\n"); log.flush()
    allrows = {}
    for (y, m) in months(start, end):
        tag = f"{y:04d}-{m:02d}"
        # Try the monthly archive first; if missing (current/partial month), fall back to daily.
        url = f"{BASE}/monthly/klines/{sym}/1m/{sym}-1m-{tag}.zip"
        b = get(url)
        if isinstance(b, (bytes, bytearray)):
            rr = parse_zip(b)
            for r in rr:
                allrows[r[0]] = r
            L(f"{tag} monthly -> {len(rr)} bars")
            continue
        # daily fallback for every day in the month up to today
        got = 0
        for d in range(1, 32):
            try:
                day = dt.date(y, m, d)
            except ValueError:
                break
            url = f"{BASE}/daily/klines/{sym}/1m/{sym}-1m-{day.isoformat()}.zip"
            bd = get(url)
            if isinstance(bd, (bytes, bytearray)):
                rr = parse_zip(bd)
                for r in rr:
                    allrows[r[0]] = r
                got += len(rr)
        L(f"{tag} monthly-miss({b}) -> daily {got} bars")
    keys = sorted(allrows)
    with open(out, "w", encoding="utf-8") as f:
        for k in keys:
            r = allrows[k]
            f.write(f"{r[0]},{r[1]},{r[2]},{r[3]},{r[4]},{r[5]}\n")
    if keys:
        L(f"TOTAL {len(keys)} bars  {dt.datetime.utcfromtimestamp(keys[0])} .. {dt.datetime.utcfromtimestamp(keys[-1])}")
    L("DONE-BINANCE")
    log.close()

if __name__ == "__main__":
    main()

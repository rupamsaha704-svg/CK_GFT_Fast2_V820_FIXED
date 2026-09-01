#!/usr/bin/env python3
"""Download Dukascopy hourly tick .bi5 for one instrument, aggregate to 1-minute OHLC (BID),
write MT5-import CSV: epoch_sec,open,high,low,close,volume (UTC).
Gentle + RESUMABLE: caches per-day aggregated bars under tools/duka_cache/CODE/, so reruns
continue where they left off. Low concurrency (2) + jitter to avoid 503 rate-limit.
Usage: duka_dl.py CODE START_YYYY-MM-DD END_YYYY-MM-DD SCALE OUT.csv
"""
import urllib.request, lzma, struct, sys, time, os, random, datetime as dt
from concurrent.futures import ThreadPoolExecutor

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
CODE, START, END, SCALE, OUT = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), sys.argv[5]
CACHE = os.path.join("tools", "duka_cache", CODE)
os.makedirs(CACHE, exist_ok=True)
logf = open(OUT + ".log", "a", encoding="utf-8")
def L(s):
    logf.write(s + "\n"); logf.flush()

def fetch(url, tries=3):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
            return urllib.request.urlopen(req, timeout=15).read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return b""
            time.sleep(min(4.0, (1.5 ** i) * 0.8) + random.random())
        except Exception:
            time.sleep(min(4.0, (1.5 ** i) * 0.7) + random.random())
    return None

def hour_bars(y, mo, d, h):
    url = f"https://datafeed.dukascopy.com/datafeed/{CODE}/{y:04d}/{mo-1:02d}/{d:02d}/{h:02d}h_ticks.bi5"
    time.sleep(0.35 + random.random() * 0.3)   # steady pace, single-stream, avoid 503
    data = fetch(url)
    if not data:
        return {}
    try:
        raw = lzma.decompress(data, format=lzma.FORMAT_AUTO)
    except Exception:
        return {}
    base = int(dt.datetime(y, mo, d, h, tzinfo=dt.timezone.utc).timestamp())
    bars = {}
    for i in range(len(raw) // 20):
        ms, ask, bid, av, bv = struct.unpack_from(">IIIff", raw, i * 20)
        price = bid / SCALE
        mepoch = base + ((ms // 1000) // 60) * 60
        b = bars.get(mepoch)
        if b is None:
            bars[mepoch] = [price, price, price, price, 1]
        else:
            if price > b[1]: b[1] = price
            if price < b[2]: b[2] = price
            b[3] = price; b[4] += 1
    return bars

def day_hours(wd):
    hrs = []
    for h in range(24):
        if wd == 5: continue                 # Saturday closed
        if wd == 6 and h < 21: continue       # Sunday pre-open
        if wd == 4 and h > 21: continue       # Friday post-close
        hrs.append(h)
    return hrs

def process_day(day):
    cache_file = os.path.join(CACHE, day.isoformat() + ".csv")
    if os.path.exists(cache_file):
        out = {}
        for ln in open(cache_file, encoding="utf-8"):
            p = ln.strip().split(",")
            if len(p) == 6:
                out[int(p[0])] = [float(p[1]), float(p[2]), float(p[3]), float(p[4]), int(p[5])]
        return out, True
    hrs = day_hours(day.weekday())
    daybars = {}
    for h in hrs:                       # single stream (Dukascopy 503s on bursts)
        daybars.update(hour_bars(day.year, day.month, day.day, h))
    # Only cache when we actually got data, OR the day is a non-trading day (hrs empty).
    # If a trading day returned nothing (rate-limit/timeout), DON'T cache -> retry on rerun.
    if daybars or not hrs:
        with open(cache_file, "w", encoding="utf-8") as f:
            for k in sorted(daybars):
                o, hi, lo, c, v = daybars[k]
                f.write(f"{k},{o:.3f},{hi:.3f},{lo:.3f},{c:.3f},{v}\n")
        return daybars, False
    return daybars, False  # not cached; will retry next run

def main():
    y0, m0, d0 = [int(x) for x in START.split("-")]
    y1, m1, d1 = [int(x) for x in END.split("-")]
    cur = dt.date(y0, m0, d0); end = dt.date(y1, m1, d1)
    days = []
    while cur <= end:
        days.append(cur); cur += dt.timedelta(days=1)
    L(f"START {CODE} {START}..{END} : {len(days)} days")
    allbars = {}
    for idx, day in enumerate(days):
        try:
            daybars, cached = process_day(day)
        except Exception as e:
            L(f"day {day} ERR {e}"); daybars = {}
        allbars.update(daybars)
        if (idx + 1) % 20 == 0 or idx == len(days) - 1:
            L(f"day {idx+1}/{len(days)} {day} bars_total={len(allbars)}")
            keys = sorted(allbars)
            with open(OUT, "w", encoding="utf-8") as f:
                for k in keys:
                    o, hi, lo, c, v = allbars[k]
                    f.write(f"{k},{o:.3f},{hi:.3f},{lo:.3f},{c:.3f},{v}\n")
    keys = sorted(allbars)
    if keys:
        L(f"TOTAL {len(keys)} minute-bars {dt.datetime.utcfromtimestamp(keys[0])} .. {dt.datetime.utcfromtimestamp(keys[-1])}")
    L("DONE-DUKA")
    logf.close()

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Decode an MT5 tester agent log (UTF-16) and surface key diagnostic lines.
Usage: python tools/scan_log.py <tester.log>"""
import sys
path = sys.argv[1]
raw = open(path, "rb").read()
# MT5 agent logs are UTF-16LE; fall back to latin-1
for enc in ("utf-16", "utf-16-le", "latin-1"):
    try:
        text = raw.decode(enc)
        break
    except Exception:
        continue
keys = ("real ticks begin", "ticks data begins", "history ticks synchronized",
        "CK_GOLD_PRO_FIX09", "OnTester", "spreadFiltered", "orderRejects",
        "not enough money", "no money", "margin", "final balance", "Test passed",
        "real ticks absent")
seen = 0
for line in text.splitlines():
    low = line.lower()
    if any(k.lower() in low for k in keys):
        # strip the leading tab-separated log columns for readability
        parts = line.split("\t")
        msg = parts[-1].strip() if parts else line.strip()
        if msg:
            print(msg)
            seen += 1
            if seen > 60:
                print("... (truncated)")
                break

#!/usr/bin/env python3
"""
Generate the erl_h4 + dedupe signal CSV for MT5 signal-player EA.

Output columns (MT5-friendly):
  datetime (YYYY.MM.DD HH:MM), direction (BUY|SELL), entry_price, sl_price, tp_price

Python's role: DECIDE entries. MT5's role: EXECUTE them with real ticks (steering §5).
"""
import sys, os, csv
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'v1_lab'))
from qm_state_machine import run, make_config  # noqa
from qm_detect import load_ohlc  # noqa

CFG = make_config(erl_tf='H4')   # the winning variant from Task 9
OUT_CSV = '_signals_erl_h4.csv'  # MT5-consumable
OUT_TXT = '_signals_erl_h4.txt'  # human-readable

def dedupe(trades):
    seen = set()
    out = []
    for t in trades:
        key = (t['entry_datetime'], round(t['entry_price'],5),
               round(t['sl'],5), round(t['tp'],5), t['direction'])
        if key in seen: continue
        seen.add(key)
        out.append(t)
    return out

def main():
    print("Loading data...")
    m15 = load_ohlc('XAUUSD_M15_export.csv')
    m5  = load_ohlc('XAUUSD_M5_202508010105_202607271000.csv')
    print(f"  M15 bars: {len(m15)}   M5 bars: {len(m5)}")

    print("Running engine (erl_h4 config)...")
    import datetime as dt
    t0 = dt.datetime.now()
    trades, stats = run(m15, CFG, m5_bars=m5)
    print(f"  raw trades: {len(trades)}  elapsed: {(dt.datetime.now()-t0).total_seconds():.1f}s")

    trades = dedupe(trades)
    print(f"  after dedupe: {len(trades)}")

    # sort chronologically
    trades.sort(key=lambda t: t['entry_datetime'])

    # write MT5-friendly CSV
    with open(OUT_CSV, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['datetime', 'direction', 'entry_price', 'sl_price', 'tp_price'])
        for t in trades:
            dt_mt5 = t['entry_datetime'].strftime('%Y.%m.%d %H:%M')
            direc = 'BUY' if t['direction'] == 'bull' else 'SELL'
            w.writerow([dt_mt5, direc,
                        f"{t['entry_price']:.2f}",
                        f"{t['sl']:.2f}",
                        f"{t['tp']:.2f}"])

    # human-readable
    with open(OUT_TXT, 'w') as f:
        f.write(f"erl_h4 + dedupe signals ({len(trades)} trades)\n")
        f.write(f"Window: {trades[0]['entry_datetime']} -> {trades[-1]['entry_datetime']}\n")
        f.write("-" * 80 + "\n")
        f.write(f"{'#':>4} {'datetime':<20} {'dir':<5} {'entry':>10} {'sl':>10} {'tp':>10}\n")
        for i, t in enumerate(trades):
            direc = 'BUY' if t['direction'] == 'bull' else 'SELL'
            f.write(f"{i+1:>4} {t['entry_datetime'].strftime('%Y-%m-%d %H:%M'):<20} "
                    f"{direc:<5} {t['entry_price']:>10.2f} {t['sl']:>10.2f} {t['tp']:>10.2f}\n")

    print(f"\nSaved:")
    print(f"  {OUT_CSV}  ({len(trades)} rows + header, MT5-consumable)")
    print(f"  {OUT_TXT}  (human-readable)")
    print(f"\nFirst 5:")
    for i, t in enumerate(trades[:5]):
        direc = 'BUY' if t['direction'] == 'bull' else 'SELL'
        print(f"  {i+1} {t['entry_datetime']} {direc} @ {t['entry_price']:.2f}  SL={t['sl']:.2f}  TP={t['tp']:.2f}")
    print(f"\nLast 5:")
    for i, t in enumerate(trades[-5:]):
        direc = 'BUY' if t['direction'] == 'bull' else 'SELL'
        n = len(trades) - 5 + i + 1
        print(f"  {n} {t['entry_datetime']} {direc} @ {t['entry_price']:.2f}  SL={t['sl']:.2f}  TP={t['tp']:.2f}")

if __name__ == '__main__':
    main()

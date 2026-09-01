#!/usr/bin/env python3
"""Convert data_crypto/{BTC,ETH}.csv (daily OHLC) -> MT5 ImportDuka format
(epoch_sec,open,high,low,close,volume) in Common\\Files, for custom-symbol import."""
import csv, os, datetime as dt
COMMON=r"C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
def conv(sym, infile, outfile):
    n=0
    with open(outfile,"w",encoding="utf-8") as o:
        for r in csv.DictReader(open(infile,encoding="utf-8")):
            try:
                e=int(dt.datetime.strptime(r["date"],"%Y-%m-%d").replace(tzinfo=dt.timezone.utc).timestamp())
                o.write(f'{e},{r["open"]},{r["high"]},{r["low"]},{r["close"]},1\n'); n+=1
            except Exception: pass
    return n
for sym,src in [("BTCUSDx","data_crypto/BTC.csv"),("ETHUSDx","data_crypto/ETH.csv")]:
    out=os.path.join(COMMON, sym.replace("x","")+"_d1.csv")
    n=conv(sym,src,out)
    print(f"{sym}: {n} daily bars -> {out}")
print("DONE-PREP")

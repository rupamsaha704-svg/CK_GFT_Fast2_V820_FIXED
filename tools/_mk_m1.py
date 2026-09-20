import pandas as pd
m = pd.read_csv("XAUUSD_M5_202508010105_202607271000.csv", sep=None, engine="python")
m.columns = [c.strip().strip("<>").lower() for c in m.columns]
m["time"] = m["date"].astype(str) + " " + m["time"].astype(str).str.slice(0, 5)
m[["time","open","high","low","close"]].to_csv("tools/_m1_fnext.csv", index=False)
print("M5rows", len(m), "range", m["time"].iloc[0], "->", m["time"].iloc[-1])
d = pd.read_csv("experiments/combo_fnext_02f/deals.csv")
print("deals", len(d), "losers", int((d["profit"] < 0).sum()),
      "drange", d["entry_time"].min(), "->", d["exit_time"].max())

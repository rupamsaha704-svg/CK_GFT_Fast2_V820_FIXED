import json, os
base = json.load(open(r"experiments\combo_base2\preset.json"))
inp = base["inputs"]
inp["Combo_DailyLossPct"] = 4.5
inp["Combo_BlockEntryHours"] = "99"
inp["Combo_UsePredictiveDaily"] = True
inp["Combo_DailyBufferPct"] = 4.0
inp["Combo_UsePerTradeCap"] = True
inp["Combo_PerTradeMaxRiskPct"] = 3.0
d = os.path.join("experiments", "combo_gov")
os.makedirs(d, exist_ok=True)
json.dump(base, open(os.path.join(d, "preset.json"), "w"), indent=2)
print("wrote combo_gov: daily4.5 + predictive4.0 + pertradecap3.0, block none")

import json, os
base = json.load(open(r"experiments\combo_hrblock\preset.json"))
base["inputs"]["Combo_DailyLossPct"] = 5.0
base["inputs"]["Combo_BlockEntryHours"] = "99"   # 99 = block no hour (true baseline)
d = os.path.join("experiments", "combo_base2")
os.makedirs(d, exist_ok=True)
json.dump(base, open(os.path.join(d, "preset.json"), "w"), indent=2)
print("wrote combo_base2 daily5 no-block")

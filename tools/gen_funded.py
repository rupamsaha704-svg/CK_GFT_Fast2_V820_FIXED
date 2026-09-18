import json, os
p = json.load(open(r"experiments\combo_gov\preset.json"))
p["inputs"]["Combo_Stage"] = 1
p["inputs"]["Combo_FundedFloatFlatPct"] = 1.5
p["inputs"]["Combo_FundedPerTradePct"] = 1.0
p["inputs"]["Combo_FundedFixLot"] = 0.02
p["inputs"]["Combo_FundedRiskPct"] = 1.0
d = "experiments\\combo_funded"; os.makedirs(d, exist_ok=True)
json.dump(p, open(d+"\\preset.json","w"), indent=2)
print("wrote combo_funded stage=1 (funded mode: Goat-Guard-safe)")

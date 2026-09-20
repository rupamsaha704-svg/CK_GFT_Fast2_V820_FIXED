import json, os
p = json.load(open(r"experiments\combo_m4_funded2\preset.json"))  # model4, funded, tightened
# bigger-but-still-safe funded caps (worst trade target < ~$90, under Goat Guard $100)
p["inputs"]["Combo_FundedFixLot"] = 0.02
p["inputs"]["Combo_FundedPerTradePct"] = 0.8
p["inputs"]["Combo_FundedRiskPct"] = 0.8
p["inputs"]["Combo_FundedFloatFlatPct"] = 1.4
p["inputs"]["Combo_FundedLogin"] = 0            # new input - pin for GUARD#20
d = "experiments\\combo_m4_funded3"; os.makedirs(d, exist_ok=True)
json.dump(p, open(d+"\\preset.json","w"), indent=2)
print("wrote combo_m4_funded3 (bigger safe caps, model4)")

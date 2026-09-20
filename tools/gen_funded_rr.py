import json, os
p = json.load(open(r"experiments\combo_m4_funded2\preset.json"))  # 0.01 proven-safe funded, model4
p["inputs"]["FIX_RR"] = 5.0                     # let winners run further (bigger TP); SL/gap risk unchanged
p["inputs"]["Combo_FundedLogin"] = 0
p["inputs"]["Combo_FundedMaxSLpts"] = 0
p["inputs"]["Combo_FundedFixLot"] = 0.01        # gap-safe
p["inputs"]["Combo_FundedPerTradePct"] = 0.6
p["inputs"]["Combo_FundedRiskPct"] = 0.5
p["inputs"]["Combo_FundedFloatFlatPct"] = 1.2
d = "experiments\\combo_funded_rr"; os.makedirs(d, exist_ok=True)
json.dump(p, open(d+"\\preset.json","w"), indent=2)
print("wrote combo_funded_rr (FIX_RR=5, 0.01 lot, model4)")

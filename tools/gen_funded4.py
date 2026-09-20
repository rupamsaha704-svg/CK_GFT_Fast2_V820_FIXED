import json, os
p = json.load(open(r"experiments\combo_m4_funded2\preset.json"))  # model4 funded
p["inputs"]["Combo_FundedFixLot"] = 0.03        # bigger lot, now safe because SL is capped
p["inputs"]["Combo_FundedPerTradePct"] = 1.5
p["inputs"]["Combo_FundedRiskPct"] = 0.8
p["inputs"]["Combo_FundedFloatFlatPct"] = 1.7   # $85 lock
p["inputs"]["Combo_FundedLogin"] = 0
p["inputs"]["Combo_FundedMaxSLpts"] = 20.0      # NEW: skip wide-SL trades -> worst FIX09 = 20*0.03*100 = $60 < $85
d = "experiments\\combo_m4_funded4"; os.makedirs(d, exist_ok=True)
json.dump(p, open(d+"\\preset.json","w"), indent=2)
print("wrote combo_m4_funded4 (lot 0.03 + SL cap 20pts, model4)")

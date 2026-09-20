import json, os
p = json.load(open(r"experiments\combo_m4_funded\preset.json"))  # model4, Stage1, all inputs
p["inputs"]["Combo_FundedFixLot"] = 0.01        # min lot -> smallest FIX09 gap risk
p["inputs"]["Combo_FundedPerTradePct"] = 0.6    # planned per-trade risk ~$30 (room for real-tick slippage under $100)
p["inputs"]["Combo_FundedRiskPct"] = 0.5        # DTREND smaller
p["inputs"]["Combo_FundedFloatFlatPct"] = 1.2   # flatten combined floating at $60 (more room under Goat Guard $100)
d = "experiments\\combo_m4_funded2"; os.makedirs(d, exist_ok=True)
json.dump(p, open(d+"\\preset.json","w"), indent=2)
print("wrote combo_m4_funded2 (tighter funded caps, model4)")

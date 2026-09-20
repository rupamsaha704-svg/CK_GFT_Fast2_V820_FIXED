import json, os
p = json.load(open(r"experiments\combo_funded\preset.json"))  # has base+governor+funded inputs
p["inputs"]["Combo_Stage"] = 0            # EVAL mode for the MTF A/B test
p["inputs"]["Combo_UseMTF"] = True
p["inputs"]["Combo_MTF_EMA"] = 50
p["inputs"]["Combo_MTF_MinScore"] = 2
d = "experiments\\combo_mtf"; os.makedirs(d, exist_ok=True)
json.dump(p, open(d+"\\preset.json","w"), indent=2)
print("wrote combo_mtf (eval + MTF on)")

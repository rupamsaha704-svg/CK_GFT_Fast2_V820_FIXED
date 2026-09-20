import json, os
base = json.load(open(r"experiments\combo_mtf\preset.json"))  # complete input set, MTF=2, last1y
def mk(idv, stage):
    p = json.loads(json.dumps(base))
    p["model"] = 4                      # real ticks (honest)
    p["inputs"]["Combo_Stage"] = stage
    d = os.path.join("experiments", idv); os.makedirs(d, exist_ok=True)
    json.dump(p, open(os.path.join(d, "preset.json"), "w"), indent=2)
    print("wrote", idv, "model4 stage", stage)
mk("combo_m4_eval", 0)     # EVAL shipping config, real ticks
mk("combo_m4_funded", 1)   # FUNDED (Goat-Guard) config, real ticks

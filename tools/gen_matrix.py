import json, os
base = json.load(open(r"experiments\combo_mtf\preset.json"))  # complete input set (base+gov+funded+MTF)
def win(idv, frm, to): return [{"id": idv, "from": frm, "to": to}]
def mk(idv, changes, windows=None):
    p = json.loads(json.dumps(base))
    for k, v in changes.items(): p["inputs"][k] = v
    if windows: p["windows"] = windows
    d = os.path.join("experiments", idv); os.makedirs(d, exist_ok=True)
    json.dump(p, open(os.path.join(d, "preset.json"), "w"), indent=2)
    print("wrote", idv, changes, (windows[0]["id"] if windows else "last1y"))
# MTF strength sweep (Eval, last1y)
mk("combo_mtf1", {"Combo_MTF_MinScore": 1, "Combo_Stage": 0})
mk("combo_mtf3", {"Combo_MTF_MinScore": 3, "Combo_Stage": 0})
# OOS / older-regime confirm (2025 H1)
mk("combo_mtf_old",    {"Combo_MTF_MinScore": 2, "Combo_Stage": 0}, win("old2025h1", "2025.01.02", "2025.09.02"))
mk("combo_funded_old", {"Combo_Stage": 1},                          win("old2025h1", "2025.01.02", "2025.09.02"))

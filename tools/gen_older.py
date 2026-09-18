import json, os
for src, dst in [("combo_base2","combo_base_old"), ("combo_gov","combo_gov_old")]:
    p = json.load(open(f"experiments\\{src}\\preset.json"))
    p["windows"] = [{"id": "old2025h1", "from": "2025.01.02", "to": "2025.09.02"}]
    d = f"experiments\\{dst}"; os.makedirs(d, exist_ok=True)
    json.dump(p, open(f"{d}\\preset.json","w"), indent=2)
    print("wrote", dst)

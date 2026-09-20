import json, os
w = [{"id": "m20", "from": "2025.01.02", "to": "2026.09.02"}]  # ~20 months
# EVAL: from combo_mtf (Stage0, MTF2), Model-1 fast, 20m window
e = json.load(open(r"experiments\combo_mtf\preset.json")); e["model"] = 1; e["windows"] = w; e["inputs"]["Combo_Stage"] = 0
os.makedirs("experiments\\combo_20m_eval", exist_ok=True); json.dump(e, open("experiments\\combo_20m_eval\\preset.json","w"), indent=2)
# FUNDED: from combo_m4_funded2 (tightened safe caps), Model-1 fast, 20m window
f = json.load(open(r"experiments\combo_m4_funded2\preset.json")); f["model"] = 1; f["windows"] = w; f["inputs"]["Combo_Stage"] = 1
os.makedirs("experiments\\combo_20m_funded", exist_ok=True); json.dump(f, open("experiments\\combo_20m_funded\\preset.json","w"), indent=2)
print("wrote combo_20m_eval + combo_20m_funded (Model-1, 20 months)")

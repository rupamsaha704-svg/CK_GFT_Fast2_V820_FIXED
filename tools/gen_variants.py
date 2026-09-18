import json, os
base = json.load(open(r"experiments\combo_hrblock\preset.json"))
def mk(idv, daily, hours):
    p = json.loads(json.dumps(base))   # deep copy
    p["inputs"]["Combo_DailyLossPct"] = daily
    p["inputs"]["Combo_BlockEntryHours"] = hours
    d = os.path.join("experiments", idv)
    os.makedirs(d, exist_ok=True)
    json.dump(p, open(os.path.join(d, "preset.json"), "w"), indent=2)
    print("wrote", idv, "daily", daily, "hours", hours)
mk("combo_v1_daily45", 4.5, "99")      # #1 only: tighten daily, block none (99 = no valid hour)
mk("combo_v2_block1516", 5.0, "15,16") # #2 only: block just 15,16, daily 5.0
mk("combo_v3_both", 4.5, "15,16")      # both

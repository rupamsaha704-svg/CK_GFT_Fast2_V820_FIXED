import json, os
base = json.load(open(r"experiments\combo_m4_funded2\preset.json"))  # model4, funded, all inputs
def mk(idv, lot, cap, risk):
    p = json.loads(json.dumps(base))
    p["inputs"]["Combo_FundedFixLot"] = lot
    p["inputs"]["Combo_FundedPerTradePct"] = cap
    p["inputs"]["Combo_FundedRiskPct"] = risk
    p["inputs"]["Combo_FundedFloatFlatPct"] = 1.7   # $85 lock (user): flatten combined floating at 1.7% of initial
    p["inputs"]["Combo_FundedLogin"] = 0            # new input, pin for GUARD#20
    d = os.path.join("experiments", idv); os.makedirs(d, exist_ok=True)
    json.dump(p, open(os.path.join(d, "preset.json"), "w"), indent=2)
    print("wrote", idv, "lot", lot, "cap", cap, "risk", risk)
mk("combo_fs_a", 0.02, 1.0, 1.0)   # step up from 0.01
mk("combo_fs_b", 0.03, 1.5, 1.5)   # bigger - find the ceiling

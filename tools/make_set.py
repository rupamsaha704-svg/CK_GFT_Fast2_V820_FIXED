#!/usr/bin/env python3
"""Generate an MT5 .set file (loadable in the EA properties / Strategy Tester) from a preset's
pinned inputs. Emits 'Name=Value' + 'Name,F=0' per input (F=0 => not optimized), which MT5 loads
cleanly. Bools -> true/false, enums/numbers as-is.
Usage: python tools/make_set.py <preset.json> <out.set>
"""
import json, sys

preset, out = sys.argv[1], sys.argv[2]
p = json.load(open(preset))
lines = ["; " + p.get("ea", "") + "  (auto-generated from " + preset + ")"]
for k, v in p["inputs"].items():
    if isinstance(v, bool):
        val = "true" if v else "false"
    else:
        val = v
    lines.append(f"{k}={val}")
    lines.append(f"{k},F=0")
open(out, "w", encoding="ascii").write("\n".join(lines) + "\n")
print("set ->", out, f"({len(p['inputs'])} inputs)")

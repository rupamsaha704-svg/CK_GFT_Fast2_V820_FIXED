#!/usr/bin/env python3
"""Generate sweep presets for every available broker symbol x {Turtle, Trend}.
Pinned inputs (GUARD#20), sealed-holdout windows, real ticks. No tuning."""
import json, os

WINDOWS = [
    {"id": "IS_build",  "from": "2025.08.28", "to": "2026.03.01"},
    {"id": "OOS_build", "from": "2026.03.01", "to": "2026.07.01"},
    {"id": "holdout",   "from": "2026.07.01", "to": "2026.08.28"},
]

TURTLE_INPUTS = {
    "InpMagic": 20260905, "InpRiskPercent": 0.5, "InpMaxLot": 0.09,
    "InpMaxTradesPerDay": 3, "InpDailyLossStopR": 2.0, "InpDailyProfitStopR": 4.0,
    "InpMaxSpreadPoints": 60, "InpLookback": 20, "InpBufferATR": 0.10,
    "InpRR": 2.0, "InpMaxSL_ATR": 3.0, "InpAllowBuy": True, "InpAllowSell": True,
}
TREND_INPUTS = {
    "InpMagic": 20260906, "InpRiskPercent": 0.5, "InpMaxLot": 0.09,
    "InpMaxSpreadPoints": 60, "InpDonchian": 20, "InpExitDonchian": 10,
    "InpATRperiod": 14, "InpSLatr": 2.0, "InpTrailATR": 3.0,
    "InpAllowBuy": True, "InpAllowSell": True,
}

# broker-available symbols NOT yet swept with both strategies
SYMBOLS = ["AUDUSD","NZDUSD","USDCAD","USDCHF","USDJPY","USDCNH","USDSEK",
           "AMD","INTC","MSFT","NVDA","XAUUSD"]

def write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2)

made = []
for sym in SYMBOLS:
    # Turtle (mean-reversion) M15
    t = {"ea": "CK_TURTLE_SOUP_v1", "trades_csv": "ck_turtle_trades.csv",
         "symbol": sym, "period": "M15", "model": 4, "execution_mode": 0,
         "deposit": 5000, "currency": "USD", "leverage": 10,
         "inputs": dict(TURTLE_INPUTS), "windows": WINDOWS}
    p1 = f"experiments/sweep_turtle_{sym}/preset.json"
    write(p1, t); made.append(p1)
    # Trend (Donchian/ATR) H1
    r = {"ea": "CK_TREND_ATR_v1", "trades_csv": "ck_trend_trades.csv",
         "symbol": sym, "period": "H1", "model": 4, "execution_mode": 0,
         "deposit": 5000, "currency": "USD", "leverage": 10,
         "inputs": dict(TREND_INPUTS), "windows": WINDOWS}
    p2 = f"experiments/sweep_trend_{sym}/preset.json"
    write(p2, r); made.append(p2)

print(f"generated {len(made)} presets")
for m in made:
    print(" ", m)

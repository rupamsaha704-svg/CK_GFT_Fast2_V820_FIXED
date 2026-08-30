"""V1 TREND agent (momentum/trend-following, essence of v23 confirmations 1-2).

Position signal (1=long, -1=short, 0=flat):
  +1 while close > EMA(trend) AND EMA(fast) > EMA(slow)   (aligned uptrend)
  -1 while close < EMA(trend) AND EMA(fast) < EMA(slow)   (aligned downtrend)
   0 otherwise (no clean trend alignment -> stay out)

Few parameters by design (anti-overfit). This is the specialist that should
do well in TRENDING regimes and bleed in choppy ones (that is expected, and is
exactly why we later add a regime-aware judge).
"""
from typing import Dict
import numpy as np
import pandas as pd


class SignalEngine:
    def __init__(self, fast: int = 20, slow: int = 50, trend: int = 200):
        self.fast = fast
        self.slow = slow
        self.trend = trend

    def generate(self, data_map: Dict[str, pd.DataFrame]) -> Dict[str, pd.Series]:
        out = {}
        for code, df in data_map.items():
            c = df["close"]
            ef = c.ewm(span=self.fast, adjust=False).mean()
            es = c.ewm(span=self.slow, adjust=False).mean()
            et = c.ewm(span=self.trend, adjust=False).mean()
            up = (c > et) & (ef > es)
            dn = (c < et) & (ef < es)
            sig = np.where(up, 1, np.where(dn, -1, 0))
            out[code] = pd.Series(sig, index=df.index, name="signal").astype(int)
        return out

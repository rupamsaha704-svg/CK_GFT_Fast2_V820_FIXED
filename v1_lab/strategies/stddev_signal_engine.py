"""V1 STD-DEV agent (mean-reversion, for RANGE regimes).

z = (close - SMA(n)) / rolling_std(n)
Position signal:
  +1 when z < -entry_z  (over-sold, expect bounce up)
  -1 when z > +entry_z  (over-bought, expect fade down)
   0 when |z| <= entry_z (reverted / no edge -> flat)

Contrarian by construction: should shine when price oscillates in a band and
lose in strong trends (opposite profile to the trend agent -> diversification).
"""
from typing import Dict
import numpy as np
import pandas as pd


class SignalEngine:
    def __init__(self, n: int = 20, entry_z: float = 2.0):
        self.n = n
        self.entry_z = entry_z

    def generate(self, data_map: Dict[str, pd.DataFrame]) -> Dict[str, pd.Series]:
        out = {}
        for code, df in data_map.items():
            c = df["close"]
            sma = c.rolling(self.n).mean()
            sd = c.rolling(self.n).std(ddof=0)
            z = (c - sma) / sd.replace(0, np.nan)
            sig = np.where(z < -self.entry_z, 1, np.where(z > self.entry_z, -1, 0))
            s = pd.Series(sig, index=df.index, name="signal")
            s[z.isna()] = 0
            out[code] = s.astype(int)
        return out

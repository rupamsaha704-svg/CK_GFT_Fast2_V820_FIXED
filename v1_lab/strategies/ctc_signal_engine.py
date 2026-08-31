"""V1 CTC agent (close-to-close momentum confirmation).

Confirms direction using multi-bar close-to-close momentum plus the last bar:
  roc = close / close.shift(k) - 1      (k-bar momentum)
  up1 = close > close.shift(1)          (last bar up)
Position signal:
  +1 when roc > 0 AND up1
  -1 when roc < 0 AND NOT up1
   0 otherwise (mixed -> flat)

A confirmation specialist: agrees with a move only when both the multi-bar and
single-bar directions align. Cheap, few-param, momentum-family.
"""
from typing import Dict
import numpy as np
import pandas as pd


class SignalEngine:
    def __init__(self, k: int = 10):
        self.k = k

    def generate(self, data_map: Dict[str, pd.DataFrame]) -> Dict[str, pd.Series]:
        out = {}
        for code, df in data_map.items():
            c = df["close"]
            roc = c / c.shift(self.k) - 1.0
            up1 = c > c.shift(1)
            long_ = (roc > 0) & up1
            short_ = (roc < 0) & (~up1)
            sig = np.where(long_, 1, np.where(short_, -1, 0))
            s = pd.Series(sig, index=df.index, name="signal")
            s[roc.isna()] = 0
            out[code] = s.astype(int)
        return out

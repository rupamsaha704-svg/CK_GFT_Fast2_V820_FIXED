from typing import Dict
import numpy as np
import pandas as pd

class SignalEngine:
    """Hello-world: EMA20 vs EMA50 cross. 1=long, -1=short, 0=wait."""
    def __init__(self, fast: int = 20, slow: int = 50):
        self.fast = fast
        self.slow = slow

    def generate(self, data_map: Dict[str, pd.DataFrame]) -> Dict[str, pd.Series]:
        out = {}
        for code, df in data_map.items():
            ef = df["close"].ewm(span=self.fast, adjust=False).mean()
            es = df["close"].ewm(span=self.slow, adjust=False).mean()
            sig = np.where(ef > es, 1, np.where(ef < es, -1, 0))
            out[code] = pd.Series(sig, index=df.index, name="signal").astype(int)
        return out

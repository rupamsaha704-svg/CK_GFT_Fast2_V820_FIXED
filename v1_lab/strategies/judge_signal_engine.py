"""V1 SIMPLE JUDGE (consensus of the 3 specialists).

Inlines the Trend, StdDev and CTC logics (the runner loads ONE signal_engine.py
per run and restricts imports, so everything lives here with numpy/pandas only)
and combines them by simple consensus:

  vote = trend + stddev + ctc      (each in {-1,0,+1})
  +1 (BUY)  when vote >= +2
  -1 (SELL) when vote <= -2
   0 (WAIT) otherwise

Conservative on purpose: acts only when at least two specialists agree and none
strongly opposes. Note trend/ctc are momentum while stddev is contrarian, so in
strong trends stddev abstains-or-opposes and consensus leans momentum; in ranges
the reverse. V3's regime agent will later replace this equal-weight vote with
evidence-weighted, regime-aware weights.
"""
from typing import Dict
import numpy as np
import pandas as pd


class SignalEngine:
    def __init__(self, fast: int = 20, slow: int = 50, trend: int = 200,
                 n: int = 20, entry_z: float = 2.0, k: int = 10):
        self.fast, self.slow, self.trend = fast, slow, trend
        self.n, self.entry_z, self.k = n, entry_z, k

    def _trend(self, df):
        c = df["close"]
        ef = c.ewm(span=self.fast, adjust=False).mean()
        es = c.ewm(span=self.slow, adjust=False).mean()
        et = c.ewm(span=self.trend, adjust=False).mean()
        up = (c > et) & (ef > es)
        dn = (c < et) & (ef < es)
        return pd.Series(np.where(up, 1, np.where(dn, -1, 0)), index=df.index)

    def _stddev(self, df):
        c = df["close"]
        sma = c.rolling(self.n).mean()
        sd = c.rolling(self.n).std(ddof=0)
        z = (c - sma) / sd.replace(0, np.nan)
        s = pd.Series(np.where(z < -self.entry_z, 1, np.where(z > self.entry_z, -1, 0)), index=df.index)
        s[z.isna()] = 0
        return s

    def _ctc(self, df):
        c = df["close"]
        roc = c / c.shift(self.k) - 1.0
        up1 = c > c.shift(1)
        s = pd.Series(np.where((roc > 0) & up1, 1, np.where((roc < 0) & (~up1), -1, 0)), index=df.index)
        s[roc.isna()] = 0
        return s

    def generate(self, data_map: Dict[str, pd.DataFrame]) -> Dict[str, pd.Series]:
        out = {}
        for code, df in data_map.items():
            vote = self._trend(df) + self._stddev(df) + self._ctc(df)
            sig = np.where(vote >= 2, 1, np.where(vote <= -2, -1, 0))
            out[code] = pd.Series(sig, index=df.index, name="signal").astype(int)
        return out

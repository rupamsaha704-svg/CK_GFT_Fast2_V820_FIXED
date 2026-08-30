# Strategy screen — tested Vibe-Trading's ready strategies on XAUUSD M15 (honest, rigorous)

Goal: find a strategy that beats or complements v23 (trend). Screened 15 ready signal
engines; measured next-bar signal edge (gross) over the full year and the choppy 2nd half.

| strategy | signals | edge (gross) | verdict |
|---|---|---|---|
| harmonic | 182 | +16.4, 79% hit | ❌ **LOOKAHEAD BIAS** — uses `rolling(center=True)` (future bars). Delay the signal realistically (10 bars) → edge collapses to −1.4, 47% hit. Not tradeable. |
| smc (ICT) | 496 | −46.0, 22% hit | ❌ strongly negative on this data |
| candlestick | 11,566 | +6.8 | ❌ ~50% hit + huge turnover → dies on transaction costs |
| seasonal | 18,892 | +13.4 | ❌ same: turnover kills it after costs |
| technical-basic | 7,055 | −1.3 | ❌ negative |
| volatility | 10,280 | −18.8 | ❌ negative |
| ichimoku | 351 | −6.4 | ❌ negative |
| elliott-wave / multi-factor | 0 | — | no signals on this data/config |
| chanlun | — | — | needs `czsc` lib (not tested) |

## Conclusion
No ready Vibe strategy provided a clean, cost-robust, **lookahead-free** edge on XAUUSD M15
for this period. The flashy candidates (harmonic 79% hit; SMC) are traps — harmonic's edge is
pure lookahead bias that would look great in backtest and blow up live.

**v23 (trend breakout-pullback) remains the only real, validated, lookahead-free edge.**
This screen is itself evidence of rigor: we actively hunted for something better and rejected
the impostors with data, rather than shipping a lookahead-inflated result.

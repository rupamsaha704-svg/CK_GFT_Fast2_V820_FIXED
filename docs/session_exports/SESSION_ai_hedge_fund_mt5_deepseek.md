# SESSION EXPORT — AI Hedge Fund (Python + DeepSeek AI + MetaTrader 5)

> **Session type:** LIVE SYSTEM BUILD + VPS SETUP (NOT a backtest / NOT a validation session).
> **Language of session:** Bengali (user), mixed with English code.
> **Status at export time:** ⚠️ **INCOMPLETE / NOT VERIFIED WORKING.** The bot code was fully
> written, but it was never confirmed to connect to MT5 or place a single trade. Setup on the VPS
> repeatedly broke during file-transfer. See "UNFINISHED WORK" and "WARNINGS".
> **Honesty note:** No backtest results, no metrics, no P&L were produced in this session. Any number
> below is a *setting* or a *user-provided credential*, never a measured result.

---

## 1. PURPOSE

The user watched a YouTube video about an "automated AI hedge fund" and wanted to reproduce it. The
concept from the video:

- A fully automated AI system that analyses the market itself and places trades in **MetaTrader 5 (MT5)**.
- Claimed running cost < **$1/month** because AI is only called when the market is "important".
- Architecture (3 layers):

```
[MT5 Terminal]  <->  [Python Bot on VPS (Gatekeeper + Risk)]  <->  [DeepSeek AI API]
```

- The Python bot runs 24/7 on a VPS, pulls data every 15 minutes, computes price action / Smart Money
  Concepts (SMC) mathematically, and only calls the AI when a **100% clear setup** exists (cost saver).
- A "gatekeeper" filter blocks AI calls in sideways / bad markets.
- Uses a cheaper reasoning model (video said "DeepSeek V4 Pro"); we used `deepseek-chat`.
- Multi-timeframe: always sends **H4 (trend) + M15 (entry)** together (top-down).
- A probability filter: if AI confidence < 65%, skip the trade even if the setup looks good.
- Risk sized so each trade risks a fixed %.

The user's own words for the goal: they already have API, VPS, MT5, command line, Python — "just
connecting is left". They wanted the whole thing built and then set up on their VPS. They explicitly
want to **practice on a DEMO account first** and see the returns before ever using real money.

---

## 2. KEY DECISIONS (and why)

| Decision | Choice | Reason |
|---|---|---|
| Who places trades | **Python bot directly into MT5** (via `MetaTrader5` pip package) | User wanted the video's Python-driven flow; the pasted MQL5 EAs were used only as *logic reference*, not run. |
| AI model | `deepseek-chat` via `https://api.deepseek.com` | Cheapest DeepSeek chat model; video hyped DeepSeek for cost. |
| Cost control | **6-layer Gatekeeper** in `market_analyzer.py` — AI only called if ALL pass | Minimise token spend (video's core trick). |
| Confidence filter | `MIN_CONFIDENCE = 65` | Video's "secret probability trick"; below 65% => SKIP. |
| Assets | XAUUSD, EURUSD, GBPUSD, BTCUSD, USOIL, NAS100 | User specified these exactly ("Xuausd euro usd GBP usd btc us oil nasdaq"). |
| Timeframes | H4 (trend) + M15 (entry) | Video's multi-timeframe top-down approach. |
| Risk model | 1% per trade, RR 1:2.5, max 3 trades/day, daily loss stop 3R, daily profit stop 6R, max spread 50 pts | Ported/adapted from the user's own MQL5 EAs + sensible defaults. |
| Entry pattern | **"Knee" pullback** (see Strategy Rules) ported from user's MQL5 EAs to Python | Reuse the user's existing edge. |
| Account | **DEMO first** | User explicitly refused real money until demo results are seen. |
| Setup method (final) | A single Python generator script `rebuild_all.py` that writes all 7 bot files | Because pasting Python directly into PowerShell kept corrupting the files (see WARNINGS). |

---

## 3. CODE & FILES PRODUCED IN THIS SESSION

The system lives (in this session's sandbox) at `/projects/sandbox/ai_hedge_fund/` and was intended to
live on the VPS at `C:\ai_hedge_fund\`. Below are the **full, corrected** contents of every file. The
canonical corrected versions are the ones emitted by `rebuild_all.py` (the earlier hand-pasted versions
got mangled by PowerShell). **These are reproduced in full so this may be the only surviving copy.**

### 3.0 File list

```
ai_hedge_fund/
├── config.py            # all settings + credentials (SEE SECURITY WARNING)
├── mt5_connector.py     # MT5 connect / candles / order send / break-even
├── market_analyzer.py   # 6-layer Gatekeeper + indicators + knee detection
├── ai_signal.py         # DeepSeek API call, JSON signal, cost tracking
├── risk_manager.py      # 1% risk, lot sizing, daily limits
├── dashboard.py         # JSON log + auto-refresh HTML dashboard
├── main.py              # 24/7 loop orchestrating everything
├── rebuild_all.py       # generator that writes the 7 files above (VPS-safe)
└── requirements.txt     # MetaTrader5, pandas, numpy, requests
```

Also produced but superseded/one-off: `setup_vps.bat`, `install_and_run.ps1`,
`ONE_CLICK_INSTALL.ps1` (a single PowerShell installer), `README_SETUP.md`, plus throwaway test
scripts on the VPS (`fix_files.py`, `test_net.py`, `test.py`).

---

### 3.1 `config.py`

> ⚠️ Contains live-in-chat credentials and an API key. **These must be treated as compromised** (see
> WARNINGS). Reproduced verbatim for recovery, but rotate everything before use.

```python
MT5_LOGIN = 5052345932            # OLD demo account (see note); user later switched to 109861021
MT5_PASSWORD = "Pj-8VaXb"
MT5_SERVER = "MetaQuotes-Demo"
MT5_PATH = r"C:\Program Files\MetaTrader 5\terminal64.exe"
DEEPSEEK_API_KEY = "sk-or-v1-<REDACTED — OpenRouter-format key; removed for GitHub push protection. Original was posted in chat and MUST be rotated/revoked. Note the 'sk-or-v1-' prefix = OpenRouter, which mismatches base_url api.deepseek.com — see WARNING #2.>"
DEEPSEEK_BASE_URL = "https://api.deepseek.com"
DEEPSEEK_MODEL = "deepseek-chat"
ASSETS = ["XAUUSD", "EURUSD", "GBPUSD", "BTCUSD", "USOIL", "NAS100"]
HIGHER_TF = "H4"
LOWER_TF = "M15"
RISK_PERCENT = 1.0
MAX_TRADES_PER_DAY = 3
DAILY_LOSS_LIMIT_R = 3.0
DAILY_PROFIT_LIMIT_R = 6.0
REWARD_RISK_RATIO = 2.5
MAX_SPREAD_POINTS = 50
EMA_FAST = 21
EMA_SLOW = 50
ATR_PERIOD = 14
MIN_ATR_MULTIPLIER = 0.5
KNEE_MIN_RUN = 2
SL_BUFFER_ATR = 0.3
MIN_CONFIDENCE = 65
CHECK_INTERVAL_SECONDS = 900       # 15 minutes
LOG_FILE = "trades_log.json"
DASHBOARD_FILE = "dashboard.html"
LOG_LEVEL = "INFO"
MAGIC_NUMBER = 20260719
```

**Account update that was in progress:** user created a NEW demo and wanted to switch to it:
- New Login: `109861021`
- New Password: `!t4mDgTm`
- Investor pw: `8g*oLuPl`
- Server: `MetaQuotes-Demo`
- Account type: Forex Hedged USD, **Deposit $3000**, Name "Rupam Saha".
The config swap to the new account was attempted (a `re.sub` one-liner) but **never confirmed applied
or connected**.

---

### 3.2 `mt5_connector.py`

```python
import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime
import logging
import config

logger = logging.getLogger(__name__)
TF = {"M1":mt5.TIMEFRAME_M1,"M5":mt5.TIMEFRAME_M5,"M15":mt5.TIMEFRAME_M15,"M30":mt5.TIMEFRAME_M30,"H1":mt5.TIMEFRAME_H1,"H4":mt5.TIMEFRAME_H4,"D1":mt5.TIMEFRAME_D1,"W1":mt5.TIMEFRAME_W1}

class MT5Connector:
    def __init__(self):
        self.connected = False

    def connect(self):
        if not mt5.initialize(path=config.MT5_PATH):
            logger.error("MT5 init failed: " + str(mt5.last_error()))
            return False
        if config.MT5_LOGIN:
            if not mt5.login(login=config.MT5_LOGIN, password=config.MT5_PASSWORD, server=config.MT5_SERVER):
                logger.error("MT5 login failed: " + str(mt5.last_error()))
                mt5.shutdown()
                return False
        self.connected = True
        info = mt5.account_info()
        logger.info("MT5 OK! Account " + str(info.login) + " Balance $" + str(info.balance))
        return True

    def disconnect(self):
        mt5.shutdown()
        self.connected = False

    def get_account_info(self):
        i = mt5.account_info()
        if not i:
            return {}
        return {"login": i.login, "balance": i.balance, "equity": i.equity,
                "margin": i.margin, "free_margin": i.margin_free, "profit": i.profit}

    def get_candles(self, symbol, timeframe, count=100):
        tf = TF.get(timeframe)
        if not tf:
            return pd.DataFrame()
        r = mt5.copy_rates_from_pos(symbol, tf, 0, count)
        if r is None or len(r) == 0:
            return pd.DataFrame()
        df = pd.DataFrame(r)
        df["time"] = pd.to_datetime(df["time"], unit="s")
        df.rename(columns={"time": "datetime", "tick_volume": "volume"}, inplace=True)
        return df[["datetime", "open", "high", "low", "close", "volume"]]

    def get_symbol_info(self, symbol):
        i = mt5.symbol_info(symbol)
        if not i:
            return {}
        t = mt5.symbol_info_tick(symbol)
        return {"symbol": symbol, "bid": t.bid if t else 0, "ask": t.ask if t else 0,
                "spread": i.spread, "digits": i.digits, "trade_tick_value": i.trade_tick_value,
                "trade_tick_size": i.trade_tick_size, "volume_min": i.volume_min,
                "volume_max": i.volume_max, "volume_step": i.volume_step, "point": i.point}

    def get_spread(self, symbol):
        i = mt5.symbol_info(symbol)
        return i.spread if i else 9999

    def calculate_lot_size(self, symbol, sl_dist, risk_pct=None):
        if not risk_pct:
            risk_pct = config.RISK_PERCENT
        acc = mt5.account_info()
        if not acc:
            return 0.0
        risk_money = acc.balance * (risk_pct / 100.0)
        si = mt5.symbol_info(symbol)
        if not si:
            return 0.0
        tv, ts = si.trade_tick_value, si.trade_tick_size
        if tv <= 0 or ts <= 0 or sl_dist <= 0:
            return 0.0
        lots = risk_money / ((sl_dist / ts) * tv)
        lots = int(lots / si.volume_step) * si.volume_step
        lots = max(lots, si.volume_min)
        lots = min(lots, si.volume_max)
        return round(lots, 2)

    def open_trade(self, symbol, direction, lot_size, sl_price, tp_price, comment="AI_Bot"):
        si = mt5.symbol_info(symbol)
        if not si:
            return {"success": False, "error": "Symbol not found"}
        if not si.visible:
            mt5.symbol_select(symbol, True)
        d = si.digits
        sl_price = round(sl_price, d)
        tp_price = round(tp_price, d)
        t = mt5.symbol_info_tick(symbol)
        if not t:
            return {"success": False, "error": "No tick"}
        if direction.upper() == "BUY":
            otype, price = mt5.ORDER_TYPE_BUY, t.ask
        else:
            otype, price = mt5.ORDER_TYPE_SELL, t.bid
        req = {"action": mt5.TRADE_ACTION_DEAL, "symbol": symbol, "volume": lot_size,
               "type": otype, "price": price, "sl": sl_price, "tp": tp_price,
               "deviation": 30, "magic": config.MAGIC_NUMBER, "comment": comment,
               "type_time": mt5.ORDER_TIME_GTC, "type_filling": mt5.ORDER_FILLING_IOC}
        r = mt5.order_send(req)
        if not r:
            return {"success": False, "error": "Failed: " + str(mt5.last_error())}
        if r.retcode != mt5.TRADE_RETCODE_DONE:
            return {"success": False, "error": "Rejected: " + str(r.retcode) + " " + str(r.comment)}
        logger.info("TRADE: " + direction + " " + str(lot_size) + " " + symbol + " @ " + str(price))
        return {"success": True, "ticket": r.order, "price": price, "lots": lot_size,
                "sl": sl_price, "tp": tp_price, "direction": direction, "symbol": symbol}

    def count_positions(self, symbol=None):
        p = mt5.positions_get(symbol=symbol) if symbol else mt5.positions_get()
        if not p:
            return 0
        return sum(1 for x in p if x.magic == config.MAGIC_NUMBER)

    def get_today_trades_count(self):
        start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        deals = mt5.history_deals_get(start, datetime.now())
        if not deals:
            return 0
        return sum(1 for d in deals if d.magic == config.MAGIC_NUMBER and d.entry == mt5.DEAL_ENTRY_IN)

    def manage_break_even(self):
        positions = mt5.positions_get()
        if not positions:
            return
        for pos in positions:
            if pos.magic != config.MAGIC_NUMBER:
                continue
            op, sl = pos.price_open, pos.sl
            if pos.type == 0:  # BUY
                one_r = op - sl
                if one_r <= 0:
                    continue
                bid = mt5.symbol_info_tick(pos.symbol).bid
                if bid >= op + one_r and sl < op:
                    self._mod_sl(pos.ticket, pos.symbol, op, pos.tp)
            else:  # SELL
                one_r = sl - op
                if one_r <= 0:
                    continue
                ask = mt5.symbol_info_tick(pos.symbol).ask
                if ask <= op - one_r and sl > op:
                    self._mod_sl(pos.ticket, pos.symbol, op, pos.tp)

    def _mod_sl(self, ticket, symbol, new_sl, tp):
        d = mt5.symbol_info(symbol).digits
        req = {"action": mt5.TRADE_ACTION_SLTP, "position": ticket, "symbol": symbol,
               "sl": round(new_sl, d), "tp": tp, "magic": config.MAGIC_NUMBER}
        r = mt5.order_send(req)
        if r and r.retcode == mt5.TRADE_RETCODE_DONE:
            logger.info("BE set: ticket " + str(ticket))
```

---

### 3.3 `market_analyzer.py` (the Gatekeeper)

```python
import pandas as pd
import numpy as np
import logging
import config

logger = logging.getLogger(__name__)

class MarketAnalyzer:
    def __init__(self):
        self.ema_f = config.EMA_FAST
        self.ema_s = config.EMA_SLOW
        self.atr_p = config.ATR_PERIOD
        self.knee_run = config.KNEE_MIN_RUN
        self.sl_buf = config.SL_BUFFER_ATR

    def ema(self, df, p):
        return df["close"].ewm(span=p, adjust=False).mean()

    def atr(self, df, p=14):
        h, l, c = df["high"], df["low"], df["close"].shift(1)
        tr = pd.concat([h - l, abs(h - c), abs(l - c)], axis=1).max(axis=1)
        return tr.rolling(window=p).mean()

    def rsi(self, df, p=14):
        d = df["close"].diff()
        g = d.where(d > 0, 0).rolling(p).mean()
        lo = (-d.where(d < 0, 0)).rolling(p).mean()
        return 100 - (100 / (1 + g / lo))

    def get_trend(self, df):
        ef = self.ema(df, self.ema_f)
        es = self.ema(df, self.ema_s)
        c, f, s = df["close"].iloc[-1], ef.iloc[-1], es.iloc[-1]
        if c > f > s:
            trend, st = "BULLISH", ((c - s) / s) * 100
        elif c < f < s:
            trend, st = "BEARISH", ((s - c) / s) * 100
        else:
            trend, st = "SIDEWAYS", 0
        cross = "NONE"
        if ef.iloc[-2] <= es.iloc[-2] and f > s:
            cross = "BULLISH_CROSS"
        elif ef.iloc[-2] >= es.iloc[-2] and f < s:
            cross = "BEARISH_CROSS"
        return {"trend": trend, "strength": round(st, 3), "ema_fast": round(f, 5),
                "ema_slow": round(s, 5), "close": round(c, 5), "crossover": cross}

    def detect_knee(self, df):
        if len(df) < 15:
            return {"pattern": "NONE"}
        last = df.iloc[-2]
        if last["close"] < last["open"]:            # red pullback => BUY knee
            run = 0
            for i in range(3, min(16, len(df))):
                if df.iloc[-i]["close"] > df.iloc[-i]["open"]:
                    run += 1
                else:
                    break
            if run >= self.knee_run:
                a = self.atr(df, self.atr_p).iloc[-1]
                return {"pattern": "BUY_KNEE", "trigger": last["high"],
                        "sl": last["low"] - self.sl_buf * a, "knee_high": last["high"],
                        "knee_low": last["low"], "run": run, "atr": a}
        if last["close"] > last["open"]:            # green pullback => SELL knee
            run = 0
            for i in range(3, min(16, len(df))):
                if df.iloc[-i]["close"] < df.iloc[-i]["open"]:
                    run += 1
                else:
                    break
            if run >= self.knee_run:
                a = self.atr(df, self.atr_p).iloc[-1]
                return {"pattern": "SELL_KNEE", "trigger": last["low"],
                        "sl": last["high"] + self.sl_buf * a, "knee_high": last["high"],
                        "knee_low": last["low"], "run": run, "atr": a}
        return {"pattern": "NONE"}

    def check_vol(self, df):
        a = self.atr(df, self.atr_p)
        cur, avg = a.iloc[-1], a.iloc[-20:].mean()
        if cur <= 0 or avg <= 0:
            return {"ok": False, "ratio": 0}
        r = cur / avg
        return {"ok": r >= config.MIN_ATR_MULTIPLIER, "current_atr": round(cur, 5), "ratio": round(r, 2)}

    def should_call_ai(self, df_h4, df_m15, symbol):
        result = {"should_call": False, "symbol": symbol, "reason": "", "analysis": {}}
        h4t = self.get_trend(df_h4)                             # FILTER 1: H4 trend
        result["analysis"]["h4_trend"] = h4t
        if h4t["trend"] == "SIDEWAYS":
            result["reason"] = "H4 sideways"
            return result
        m15t = self.get_trend(df_m15)                           # FILTER 2: M15 trend
        result["analysis"]["m15_trend"] = m15t
        vol = self.check_vol(df_m15)                            # FILTER 3: volatility
        result["analysis"]["volatility"] = vol
        if not vol["ok"]:
            result["reason"] = "Low vol " + str(vol["ratio"])
            return result
        knee = self.detect_knee(df_m15)                         # FILTER 4: knee pattern
        result["analysis"]["knee_pattern"] = knee
        if knee["pattern"] == "NONE":
            result["reason"] = "No knee pattern"
            return result
        if knee["pattern"] == "BUY_KNEE" and h4t["trend"] == "BEARISH":   # FILTER 5: alignment
            result["reason"] = "BUY vs H4 BEAR"
            return result
        if knee["pattern"] == "SELL_KNEE" and h4t["trend"] == "BULLISH":
            result["reason"] = "SELL vs H4 BULL"
            return result
        result["should_call"] = True                            # ALL PASSED -> call AI
        result["reason"] = "OK: " + knee["pattern"] + " H4:" + h4t["trend"] + " M15:" + m15t["trend"]
        logger.info("GATE PASS " + symbol + ": " + result["reason"])
        return result

    def prepare_ai_data(self, df_h4, df_m15, analysis, symbol):
        h4c = df_h4.tail(20).to_dict("records")
        m15c = df_m15.tail(30).to_dict("records")
        r = self.rsi(df_m15).iloc[-1]
        for c in h4c:
            if "datetime" in c:
                c["datetime"] = str(c["datetime"])
        for c in m15c:
            if "datetime" in c:
                c["datetime"] = str(c["datetime"])
        return {"symbol": symbol, "h4_candles": h4c, "m15_candles": m15c,
                "indicators": {"rsi_m15": round(r, 2),
                               "atr_m15": round(analysis.get("volatility", {}).get("current_atr", 0), 5)},
                "trend_analysis": {"h4_trend": analysis.get("h4_trend", {}),
                                   "m15_trend": analysis.get("m15_trend", {})},
                "pattern": analysis.get("knee_pattern", {}), "structure": {}}
```

> Note: the fuller sandbox version of `market_analyzer.py` also had `analyze_structure()` (swing
> HH/HL/LH/LL detection) as a 6th filter and RSI/EMA extras in `prepare_ai_data`. The VPS/`rebuild_all.py`
> version above trims structure to `{}` for robustness. Both are functionally equivalent for the gate.

---

### 3.4 `ai_signal.py` (DeepSeek call)

```python
import json, time, logging, requests
import config

logger = logging.getLogger(__name__)

class AISignalGenerator:
    def __init__(self):
        self.api_key = config.DEEPSEEK_API_KEY
        self.base_url = config.DEEPSEEK_BASE_URL
        self.model = config.DEEPSEEK_MODEL
        self.min_conf = config.MIN_CONFIDENCE
        self.total_tokens = 0
        self.total_api_cost = 0.0
        self.total_calls = 0

    def _sys(self):
        return ("You are an expert trader (20yr+ SMC/Price Action). "
                "Analyze and respond in JSON only. RULES: 1) JSON only "
                "2) H4=trend M15=entry 3) Never against H4 4) Score 0-100 5) Below 60=SKIP. "
                "FORMAT: {\"signal\":\"BUY/SELL/SKIP\",\"confidence\":0-100,"
                "\"reasoning\":\"why\",\"entry_type\":\"MARKET\","
                "\"key_levels\":{\"support\":0,\"resistance\":0},"
                "\"risk_factors\":[\"list\"]}")

    def _user(self, d):
        s = d.get("symbol", "?")
        h4 = d.get("trend_analysis", {}).get("h4_trend", {})
        m15 = d.get("trend_analysis", {}).get("m15_trend", {})
        pat = d.get("pattern", {})
        ind = d.get("indicators", {})
        candles = d.get("m15_candles", [])[-6:]
        lines = []
        for c in candles:
            lines.append("  " + str(c.get("datetime", "")) + ": O=" + str(c.get("open", 0)) +
                         " H=" + str(c.get("high", 0)) + " L=" + str(c.get("low", 0)) +
                         " C=" + str(c.get("close", 0)))
        cl = "\n".join(lines)
        msg = "SYMBOL:" + s + "\n"
        msg += "H4:" + str(h4.get("trend", "?")) + " Str:" + str(h4.get("strength", 0)) + "%\n"
        msg += "M15:" + str(m15.get("trend", "?")) + " EMAf:" + str(m15.get("ema_fast", 0)) + " EMAs:" + str(m15.get("ema_slow", 0)) + "\n"
        msg += "RSI:" + str(ind.get("rsi_m15", 0)) + " ATR:" + str(ind.get("atr_m15", 0)) + "\n"
        msg += "Pattern:" + str(pat.get("pattern", "NONE")) + " Trigger:" + str(pat.get("trigger", 0)) + " SL:" + str(pat.get("sl", 0)) + "\n"
        msg += "M15 Candles:\n" + cl + "\nDecision?"
        return msg

    def get_signal(self, data):
        sym = data.get("symbol", "?")
        t0 = time.time()
        try:
            headers = {"Authorization": "Bearer " + self.api_key, "Content-Type": "application/json"}
            body = {"model": self.model, "messages": [
                        {"role": "system", "content": self._sys()},
                        {"role": "user", "content": self._user(data)}],
                    "temperature": 0.3, "max_tokens": 400,
                    "response_format": {"type": "json_object"}}
            r = requests.post(self.base_url + "/v1/chat/completions",
                              headers=headers, json=body, timeout=30)
            elapsed = time.time() - t0
            if r.status_code != 200:
                return self._err(sym, "API " + str(r.status_code))
            j = r.json()
            u = j.get("usage", {})
            inp = u.get("prompt_tokens", 0)
            out = u.get("completion_tokens", 0)
            cost = (inp * 0.27 / 1000000) + (out * 1.10 / 1000000)   # approx DeepSeek pricing, hardcoded
            self.total_tokens += inp + out
            self.total_api_cost += cost
            self.total_calls += 1
            ai = json.loads(j["choices"][0]["message"]["content"])
            sig = ai.get("signal", "SKIP").upper()
            conf = ai.get("confidence", 0)
            reason = ai.get("reasoning", "")
            if conf < self.min_conf:
                sig = "SKIP"
                reason += " [Low conf]"
            logger.info("AI " + sym + ": " + sig + " " + str(conf) + "% $" + str(round(cost, 4)))
            return {"symbol": sym, "signal": sig, "confidence": conf, "reasoning": reason,
                    "entry_type": ai.get("entry_type", "MARKET"),
                    "key_levels": ai.get("key_levels", {}),
                    "risk_factors": ai.get("risk_factors", []),
                    "tokens_used": inp + out, "api_cost": round(cost, 6),
                    "response_time": round(elapsed, 2),
                    "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")}
        except Exception as e:
            logger.error("AI err: " + str(e))
            return self._err(sym, str(e))

    def _err(self, sym, e):
        return {"symbol": sym, "signal": "SKIP", "confidence": 0,
                "reasoning": "Error:" + str(e), "entry_type": "MARKET",
                "key_levels": {}, "risk_factors": [str(e)], "tokens_used": 0,
                "api_cost": 0, "response_time": 0,
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")}

    def get_stats(self):
        return {"total_calls": self.total_calls, "total_tokens": self.total_tokens,
                "total_cost": round(self.total_api_cost, 4)}
```

---

### 3.5 `risk_manager.py`

```python
import logging
from datetime import datetime
import config

logger = logging.getLogger(__name__)

class RiskManager:
    def __init__(self, mt5):
        self.mt5 = mt5
        self.day_bal = 0
        self.day_date = None
        self.one_r = 0
        self._reset()

    def _reset(self):
        acc = self.mt5.get_account_info()
        self.day_bal = acc.get("balance", 0)
        self.day_date = datetime.now().date()
        self.one_r = self.day_bal * (config.RISK_PERCENT / 100)

    def check_new_day(self):
        if datetime.now().date() != self.day_date:
            self._reset()

    def can_trade(self, symbol):
        self.check_new_day()
        acc = self.mt5.get_account_info()
        bal = acc.get("balance", 0)
        if self.one_r > 0:
            r = (bal - self.day_bal) / self.one_r
            if r <= -config.DAILY_LOSS_LIMIT_R:
                return {"allowed": False, "reason": "Daily loss " + str(round(r, 1)) + "R"}
            if r >= config.DAILY_PROFIT_LIMIT_R:
                return {"allowed": False, "reason": "Daily profit hit"}
        t = self.mt5.get_today_trades_count()
        if t >= config.MAX_TRADES_PER_DAY:
            return {"allowed": False, "reason": "Max trades " + str(t)}
        sp = self.mt5.get_spread(symbol)
        if sp > config.MAX_SPREAD_POINTS:
            return {"allowed": False, "reason": "Spread " + str(sp)}
        if self.mt5.count_positions(symbol) > 0:
            return {"allowed": False, "reason": "Position exists"}
        return {"allowed": True, "reason": "OK"}

    def calculate_position_size(self, symbol, entry, sl, direction):
        if direction.upper() == "BUY":
            dist = entry - sl
        else:
            dist = sl - entry
        if dist <= 0:
            return {"lot_size": 0}
        acc = self.mt5.get_account_info()
        risk_money = acc.get("balance", 0) * (config.RISK_PERCENT / 100)
        lots = self.mt5.calculate_lot_size(symbol, dist, config.RISK_PERCENT)
        if direction.upper() == "BUY":
            tp = entry + (dist * config.REWARD_RISK_RATIO)
        else:
            tp = entry - (dist * config.REWARD_RISK_RATIO)
        return {"lot_size": lots, "risk_money": round(risk_money, 2),
                "sl_price": sl, "tp_price": round(tp, 5)}
```

---

### 3.6 `dashboard.py`

JSON log (`trades_log.json`) + auto-refreshing dark HTML dashboard (`dashboard.html`, meta refresh 60s)
showing 4 cards (Trades, AI Calls, Filtered, API Cost) and a recent-decisions table. Key methods:
`log_ai_decision`, `log_gatekeeper_skip`, `log_trade`, `log_risk_block`, `generate_html_dashboard`,
`print_status`. Full source is in `/projects/sandbox/ai_hedge_fund/dashboard.py` and inside
`rebuild_all.py`. (Omitted here only to keep length manageable; it is pure logging/HTML, no strategy
logic. If this doc is the only copy, regenerate it from `rebuild_all.py`.)

---

### 3.7 `main.py` (24/7 loop)

```python
import time, logging, sys
from datetime import datetime
import config
from mt5_connector import MT5Connector
from market_analyzer import MarketAnalyzer
from ai_signal import AISignalGenerator
from risk_manager import RiskManager
from dashboard import Dashboard

logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL, logging.INFO),
    format="%(asctime)s|%(levelname)-7s|%(message)s",
    handlers=[logging.FileHandler("bot.log", encoding="utf-8"), logging.StreamHandler(sys.stdout)])
logger = logging.getLogger("BOT")

def process(symbol, mt5c, ana, ai, risk, dash):
    try:
        df_h4 = mt5c.get_candles(symbol, config.HIGHER_TF, 100)
        df_m15 = mt5c.get_candles(symbol, config.LOWER_TF, 100)
        if df_h4.empty or df_m15.empty:
            logger.warning(symbol + ": no data"); return "NO_DATA"
        gate = ana.should_call_ai(df_h4, df_m15, symbol)
        if not gate["should_call"]:
            dash.log_gatekeeper_skip(symbol, gate["reason"]); return "FILTERED"
        rc = risk.can_trade(symbol)
        if not rc["allowed"]:
            dash.log_risk_block(symbol, rc["reason"]); return "BLOCKED"
        logger.info(symbol + ": AI call...")
        ai_data = ana.prepare_ai_data(df_h4, df_m15, gate["analysis"], symbol)
        sig = ai.get_signal(ai_data)
        dash.log_ai_decision(symbol, sig, gate)
        if sig["signal"] == "SKIP":
            return "SKIP"
        direction = sig["signal"]
        pat = gate["analysis"].get("knee_pattern", {})
        si = mt5c.get_symbol_info(symbol)
        if not si:
            return "ERROR"
        entry = si["ask"] if direction == "BUY" else si["bid"]
        sl = pat.get("sl", 0)
        if sl <= 0:
            return "ERROR"
        pos = risk.calculate_position_size(symbol, entry, sl, direction)
        lots = pos.get("lot_size", 0)
        tp = pos.get("tp_price", 0)
        if lots <= 0:
            return "ERROR"
        result = mt5c.open_trade(symbol, direction, lots, sl, tp, "AI" + str(sig["confidence"]))
        dash.log_trade(result, sig)
        if result["success"]:
            logger.info("TRADE! " + direction + " " + str(lots) + " " + symbol); return "TRADED"
        return "FAILED"
    except Exception as e:
        logger.error(symbol + " err: " + str(e)); return "ERROR"

def main():
    print("=" * 50)
    print("  AI HEDGE FUND BOT - RUNNING")
    print("  Assets: " + ", ".join(config.ASSETS))
    print("  Risk: " + str(config.RISK_PERCENT) + "% | RR 1:" + str(config.REWARD_RISK_RATIO))
    print("  Interval: " + str(config.CHECK_INTERVAL_SECONDS) + "s")
    print("=" * 50)
    mt5c = MT5Connector()
    if not mt5c.connect():
        print("ERROR: MT5 connection failed!")
        print("Is MT5 running? Check config.py credentials.")
        input("Press Enter to exit..."); sys.exit(1)
    ana = MarketAnalyzer(); ai = AISignalGenerator()
    risk = RiskManager(mt5c); dash = Dashboard()
    n = 0
    try:
        while True:
            n += 1
            logger.info("===== CYCLE " + str(n) + " =====")
            mt5c.manage_break_even(); risk.check_new_day()
            for s in config.ASSETS:
                r = process(s, mt5c, ana, ai, risk, dash)
                logger.info("  " + s + ": " + r); time.sleep(1)
            dash.generate_html_dashboard(); dash.print_status()
            logger.info("API cost: $" + str(round(ai.total_api_cost, 4)))
            logger.info("Sleeping " + str(config.CHECK_INTERVAL_SECONDS) + "s...")
            time.sleep(config.CHECK_INTERVAL_SECONDS)
    except KeyboardInterrupt:
        print("Stopped.")
    finally:
        s = ai.get_stats()
        print("Total: " + str(s["total_calls"]) + " calls, $" + str(s["total_cost"]) + " cost")
        dash.generate_html_dashboard(); mt5c.disconnect()

if __name__ == "__main__":
    main()
```

---

### 3.8 `requirements.txt`

```
MetaTrader5>=5.0.45
pandas>=2.0.0
numpy>=1.24.0
requests>=2.31.0
```

---

## 4. THE USER'S ORIGINAL MQL5 EAs (logic reference, pasted by user)

The Python knee-strategy was ported from TWO MQL5 EAs the user pasted. They are the source of the
"knee pullback + EMA trend + ATR-buffer SL + RR TP + break-even at 1R + daily caps" logic. Preserved
here because they may not exist elsewhere.

### 4.1 EA #1 — `CK GFT Fast` v8.10 (BUY-only)
Key inputs: `InpMagic=20260715`, `InpRiskPercent=0.35`, `InpRR=2.5`, `InpBreakEvenAt1R=true`,
`InpMaxTradesPerDay=3`, `InpDailyLossStopR=1.0`, `InpDailyProfitStopR=3.0`, `InpMaxSpreadPoints=50`,
`InpUseTrend=true`, `InpEMAPeriod=21`, `InpEMASlow=50`, `InpKneeMinRun=2`, `InpValidBars=5`,
`InpSLBufferATR=0.3`, `InpMaxLot=0.08`.
Logic: on a RED bar preceded by ≥2 consecutive GREEN bars AND uptrend (`EMAFast(1)>EMASlow(1)` and
`Close(1)>EMAFast(1)`) → arm a BUY. Trigger = knee bar high; SL = knee low − 0.3·ATR; TP = trigger +
RR·(trigger−SL). Setup valid for `InpValidBars`. Break-even to entry once +1R. Daily reset on D1 bar;
`RealizedRToday` gates profit/loss stops. Fires BUY when ask ≥ trigger. Lot sized so risk = RiskPercent
of balance, capped at `InpMaxLot`. (BUY-only — no short side.)

### 4.2 EA #2 — `GFT V2` (BUY + SELL)
Key inputs: `InpMagic=20260710`, `InpRiskPercent=0.5`, `InpRR=2.0`, `InpMaxTradesPerDay=2`,
`InpDailyDDLimit=4.0`, `InpTotalDDLimit=8.0`, `InpMaxSpread=40`, `InpEMAFast=21`, `InpEMASlow=50`,
`InpKneeMinRun=3`, `InpValidBars=6`, `InpSLBufferATR=0.8`.
Adds the SELL mirror: on a GREEN bar preceded by ≥3 consecutive RED bars AND downtrend
(`Close(1)<EMAFast<EMASlow`) → arm a SELL (trigger = knee low, SL = knee high + 0.8·ATR, TP below).
Uses equity-based **daily & total drawdown %** limits instead of R-multiple stops. Break-even both
directions at +1R.

> The Python `detect_knee` uses `KNEE_MIN_RUN=2` and buffer `0.3·ATR` (closer to EA#1) but supports
> both BUY and SELL like EA#2.

---

## 5. STRATEGY RULES (consolidated)

- **Symbols:** XAUUSD, EURUSD, GBPUSD, BTCUSD, USOIL, NAS100.
- **Timeframes:** H4 = trend filter, M15 = entry.
- **Trend:** EMA(21) vs EMA(50); price>EMAf>EMAs = BULLISH, price<EMAf<EMAs = BEARISH, else SIDEWAYS.
- **Entry (Knee/pullback):**
  - BUY: last closed M15 candle RED, preceded by ≥`KNEE_MIN_RUN` green candles; H4 not BEARISH.
  - SELL: last closed M15 candle GREEN, preceded by ≥`KNEE_MIN_RUN` red candles; H4 not BULLISH.
- **Volatility gate:** current ATR ≥ `MIN_ATR_MULTIPLIER`(0.5) × avg ATR(20).
- **SL:** BUY = knee low − 0.3·ATR; SELL = knee high + 0.3·ATR.
- **TP:** entry ± RR(2.5) × |entry − SL|.
- **Break-even:** move SL to entry once price reaches +1R.
- **Risk:** 1% of balance per trade; lot sized from tick value/size; clamped to symbol min/max/step.
- **Daily caps:** max 3 trades/day; stop day at −3R loss or +6R profit; max spread 50 points; one
  position per symbol at a time.
- **AI gate:** DeepSeek called ONLY when all gatekeeper filters pass; then must return BUY/SELL with
  confidence ≥ 65%, else SKIP.
- **Loop cadence:** every 15 minutes (900s), 24/7.

---

## 6. USER INSTRUCTIONS / PREFERENCES (remember these)

1. **Communicate in Bengali**, very simple, **one step at a time** (user gets overwhelmed by big blocks).
2. **DEMO account only** until returns are proven; do NOT put real money yet.
3. Minimise AI/token cost — only call AI on important/clear setups (this was a hard requirement).
4. User has (their words): API key, VPS, MT5, command line, Python — all installed; "just connect".
5. Prefer a true "one click" solution; user struggled with multi-step manual work.
6. Global learning already on file for this user: **do not run slow tests / full multi-period
   validation unless explicitly asked; run fast tests only by default.**

---

## 7. ENVIRONMENT / INFRASTRUCTURE

- **VPS:** AWS EC2 **Windows** instance.
  - Instance ID: `i-007fd29109784ab35` (name `CK_GFT_Fast2`)
  - Public DNS: `ec2-44-203-32-42.compute-1.amazonaws.com`
  - Security group: `sg-0a6f05df551b0c25e (CK_GFT_Fast22)`; VPC `vpc-07b5173b7f6b6b12d0`
  - RDP user: `Administrator` (password was visible in a shared screenshot — **rotate it**)
- **MT5:** installed on the VPS and confirmed present by user.
- **Python:** was NOT initially installed; installed during session (Python 3.11.9, silent install,
  PrependPath). `pip install MetaTrader5 pandas numpy requests` completed successfully.
- Target project dir on VPS: `C:\ai_hedge_fund\`.

---

## 8. UNFINISHED WORK / NEXT STEPS

**State at export:** Bot code is complete and (in clean form) syntactically valid, but on the VPS the
files repeatedly got corrupted during transfer. The bot was **never confirmed to run, connect to MT5,
call DeepSeek, or place any trade.** No dashboard, no logs, no trades exist yet.

Concrete next steps for a future agent / the user:
1. **Rotate all secrets first** (DeepSeek key + both MT5 passwords + VPS RDP password). They are all
   exposed (in chat and in this doc).
2. On the VPS, get clean files onto disk **without** pasting Python into PowerShell. Best options:
   - Save `rebuild_all.py` to `C:\ai_hedge_fund\` via Notepad (navigate into the folder in the Save
     dialog — do NOT type a full path into the filename box; that triggers "file name is not valid"),
     then run `python rebuild_all.py` — it writes all 7 files correctly.
   - OR clone from a git repo / download a zip (VPS has open internet + a browser).
3. Update `config.py` to the **new demo account** `109861021 / !t4mDgTm / MetaQuotes-Demo`.
4. In MT5: File → Login to Trade Account with the new demo; enable **Allow automated trading** and
   **Allow DLL imports**; confirm balance shows **$3000**.
5. Run `python test.py` (a tiny `mt5.initialize()` + `mt5.login()` check) and confirm SUCCESS before
   running `main.py`.
6. **Verify the DeepSeek key actually authenticates** (see WARNINGS — the key looks like an OpenRouter
   key, not a DeepSeek key). If it 401s, either use the correct DeepSeek key against
   `api.deepseek.com`, or switch `DEEPSEEK_BASE_URL` to OpenRouter (`https://openrouter.ai/api`) with
   an OpenRouter-style model id.
7. Then `python main.py` and watch `bot.log` / `dashboard.html`. Let it run on demo and evaluate.

Open questions never resolved:
- Correct broker symbol names on this broker (e.g. is it `XAUUSD` or `XAUUSDm`? `USOIL` vs `WTI`?
  `NAS100` vs `USTEC`/`US100`?). MetaQuotes-Demo may not even offer all six symbols.
- Whether MetaQuotes-Demo provides BTCUSD / USOIL / NAS100 at all.
- No verification that DeepSeek returns valid JSON under this prompt.

---

## 9. WARNINGS / BUGS / CAVEATS (must-read)

1. 🔴 **SECURITY — everything is exposed.** The DeepSeek API key, both MT5 demo passwords
   (`Pj-8VaXb`, `!t4mDgTm`), the investor password, and the VPS Administrator password were all
   posted in chat/screenshots. Treat all as compromised and rotate. (Demo accounts are low-risk, but
   the API key and VPS password are not.)
2. 🔴 **Likely API-key/provider mismatch.** `DEEPSEEK_API_KEY` starts with `sk-or-v1-…`, which is the
   **OpenRouter** key format, while `DEEPSEEK_BASE_URL = https://api.deepseek.com`. A real DeepSeek key
   starts with `sk-…` (no `or-`). As written this will most likely fail auth. Must be reconciled
   before the AI layer can work. This was NOT caught/fixed during the session.
3. 🔴 **PowerShell here-strings destroy Python code.** Pasting `@' ... '@ | Set-Content` and
   `python -c "...\n..."` one-liners repeatedly produced `SyntaxError: unterminated string literal`
   and, worse, PowerShell tried to *execute* the Python lines. **Do not transfer code this way.** Use
   a `.py` generator file (`rebuild_all.py`) run with `python`, or git/zip download. This wasted most
   of the session.
4. 🟠 **DeepSeek pricing is hardcoded/approximate** in `ai_signal.py` (`0.27` in / `1.10` out per 1M
   tokens). Cost figures in the dashboard are estimates, not billed truth.
5. 🟠 **`config.py` account drift.** At various points config still had the OLD account `5052345932`;
   the intended switch to `109861021` was attempted via a `re.sub` one-liner but never verified.
   Confirm the file's actual contents before trusting it.
6. 🟠 **No backtest, no validation, no proof of edge.** This session produced ZERO performance
   evidence. The knee strategy's profitability is entirely unproven here. (A *separate* session in this
   repo — `SESSION_gft_backtest_degradation_review.md` — found the related XAUUSD knee EA was buy-only,
   overfit, and regime-dependent, PF dropping from ~2.0 to ~1.06 across runs. Do not assume this
   Python port is profitable.)
7. 🟠 **Symbol availability / naming** on MetaQuotes-Demo is unverified (see Open questions).
8. 🟢 Minor: `analyze_structure()` exists in the fuller sandbox copy but is reduced to `{}` in the
   VPS build; not a functional problem for the gate.

---

## 10. FILE POINTERS (this session's sandbox)

All under `/projects/sandbox/ai_hedge_fund/` in the session sandbox (ephemeral — will vanish):
`config.py, mt5_connector.py, market_analyzer.py, ai_signal.py, risk_manager.py, dashboard.py,
main.py, rebuild_all.py, requirements.txt, README_SETUP.md, setup_vps.bat, install_and_run.ps1,
ONE_CLICK_INSTALL.ps1`. The authoritative, PowerShell-safe copies are embedded above and inside
`rebuild_all.py`.

---

*End of export. Written honestly: the code is complete but the system was never confirmed to run or
trade. No results were fabricated — none exist.*

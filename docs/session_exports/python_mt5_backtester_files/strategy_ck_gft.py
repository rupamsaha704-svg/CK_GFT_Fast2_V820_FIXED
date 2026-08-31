"""
CK_GFT_Fast2_V20_Funded Strategy - Python Implementation
=========================================================
Exact translation of the MQL5 EA logic into Python for backtesting.

Strategy Logic:
1. Knee Setup Detection (Buy: red candle after green run, Sell: green candle after red run)
2. Trend Filter (EMA 21 > EMA 50 for buy, EMA 21 < EMA 50 for sell)
3. Strong Candle Confirmation (body ratio check)
4. Trigger-based entry (price must reach knee high/low)
5. Risk management (% risk per trade, R:R ratio, break-even at 1R)
6. Daily limits (max trades, daily P&L stop)
"""

import pandas as pd
import numpy as np
from typing import Optional
from backtest_engine import BacktestEngine, Position
from symbol_info import SymbolInfo


class CKGFTStrategy:
    """
    Python implementation of CK_GFT_Fast2_V20_Funded.mq5
    """
    
    def __init__(
        self,
        engine: BacktestEngine,
        symbol_info: SymbolInfo,
        # Basic inputs
        magic: int = 20260715,
        risk_percent: float = 0.70,
        rr: float = 2.0,
        break_even_at_1r: bool = True,
        max_trades_per_day: int = 4,
        daily_loss_stop_r: float = 1.5,
        daily_profit_stop_r: float = 5.0,
        max_spread_points: int = 50,
        max_lot: float = 0.08,
        # Trend filter
        use_trend: bool = True,
        ema_fast_period: int = 21,
        ema_slow_period: int = 50,
        # Buy knee setup
        knee_min_run_buy: int = 2,
        min_body_ratio_buy: float = 0.60,
        # Sell knee setup (stricter)
        knee_min_run_sell: int = 3,
        min_body_ratio_sell: float = 0.70,
        # Shared settings
        valid_bars: int = 5,
        sl_buffer_atr: float = 0.3,
        min_sl_points: float = 5.0,
        # ATR period
        atr_period: int = 14,
    ):
        self.engine = engine
        self.symbol_info = symbol_info
        
        # Parameters (matching MQL5 inputs)
        self.magic = magic
        self.risk_percent = risk_percent
        self.rr = rr
        self.break_even_at_1r = break_even_at_1r
        self.max_trades_per_day = max_trades_per_day
        self.daily_loss_stop_r = daily_loss_stop_r
        self.daily_profit_stop_r = daily_profit_stop_r
        self.max_spread_points = max_spread_points
        self.max_lot = max_lot
        
        self.use_trend = use_trend
        self.ema_fast_period = ema_fast_period
        self.ema_slow_period = ema_slow_period
        
        self.knee_min_run_buy = knee_min_run_buy
        self.min_body_ratio_buy = min_body_ratio_buy
        self.knee_min_run_sell = knee_min_run_sell
        self.min_body_ratio_sell = min_body_ratio_sell
        
        self.valid_bars = valid_bars
        self.sl_buffer_atr = sl_buffer_atr
        self.min_sl_points = min_sl_points
        self.atr_period = atr_period
        
        # State variables (matching MQL5 globals)
        self.g_dir = 0           # Setup direction: +1 buy, -1 sell, 0 none
        self.g_trigger = 0.0     # Trigger price
        self.g_knee_low = 0.0
        self.g_knee_high = 0.0
        self.g_pending_sl = 0.0
        self.g_pending_tp = 0.0
        self.g_bars_left = 0
        self.g_one_r = 0.0
        
        # Daily tracking
        self.g_day_start = None
        self.g_day_start_bal = 0.0
        self.g_one_r_money = 0.0
        self.g_trades_today = 0
        
        # Bar tracking
        self.last_bar_time = None
        self.bars_history = []  # Store recent bars for indicator calculation
    
    def disarm(self):
        """Reset setup state."""
        self.g_dir = 0
        self.g_trigger = 0.0
        self.g_knee_low = 0.0
        self.g_knee_high = 0.0
        self.g_pending_sl = 0.0
        self.g_pending_tp = 0.0
        self.g_bars_left = 0
        self.g_one_r = 0.0
    
    def reset_daily(self):
        """Reset daily counters."""
        self.g_day_start = self.engine.current_time.date() if self.engine.current_time else None
        self.g_day_start_bal = self.engine.get_account_balance()
        self.g_one_r_money = self.g_day_start_bal * (self.risk_percent / 100.0)
        self.g_trades_today = 0
    
    def realized_r_today(self) -> float:
        """Calculate realized R for today."""
        if self.g_one_r_money <= 0:
            return 0.0
        return (self.engine.get_account_balance() - self.g_day_start_bal) / self.g_one_r_money
    
    def trading_allowed(self) -> bool:
        """Check if trading is allowed today."""
        r = self.realized_r_today()
        if self.daily_profit_stop_r > 0 and r >= self.daily_profit_stop_r:
            return False
        if self.daily_loss_stop_r > 0 and r <= -self.daily_loss_stop_r:
            return False
        if self.g_trades_today >= self.max_trades_per_day:
            return False
        return True
    
    def my_positions(self) -> int:
        """Count positions for this EA."""
        return self.engine.get_positions_count(
            magic=self.magic, symbol=self.symbol_info.symbol
        )
    
    def _is_new_bar(self, bar_time) -> bool:
        """Check if this is a new bar."""
        if self.last_bar_time is None or bar_time != self.last_bar_time:
            self.last_bar_time = bar_time
            return True
        return False
    
    def _is_green(self, shift: int) -> bool:
        """Check if bar at shift is green (bullish)."""
        if shift >= len(self.bars_history):
            return False
        bar = self.bars_history[-(shift + 1)]
        return bar['close'] > bar['open']
    
    def _is_red(self, shift: int) -> bool:
        """Check if bar at shift is red (bearish)."""
        if shift >= len(self.bars_history):
            return False
        bar = self.bars_history[-(shift + 1)]
        return bar['close'] < bar['open']
    
    def _get_bar(self, shift: int) -> Optional[dict]:
        """Get bar at shift (0 = current, 1 = previous, etc.)."""
        idx = -(shift + 1)
        if abs(idx) > len(self.bars_history):
            return None
        return self.bars_history[idx]
    
    def _calculate_atr(self) -> float:
        """Calculate ATR(14) from recent bars."""
        if len(self.bars_history) < self.atr_period + 1:
            return 0.0
        
        tr_values = []
        for i in range(1, self.atr_period + 1):
            bar = self.bars_history[-i]
            prev_bar = self.bars_history[-(i + 1)]
            
            tr = max(
                bar['high'] - bar['low'],
                abs(bar['high'] - prev_bar['close']),
                abs(bar['low'] - prev_bar['close'])
            )
            tr_values.append(tr)
        
        return sum(tr_values) / len(tr_values)
    
    def _calculate_ema(self, period: int, shift: int = 0) -> float:
        """Calculate EMA at given shift."""
        needed = period + 50 + shift  # Extra bars for EMA warmup
        if len(self.bars_history) < needed:
            # Simple fallback: use SMA
            if len(self.bars_history) < period + shift:
                return 0.0
            closes = [b['close'] for b in self.bars_history[-(period + shift):-shift if shift > 0 else None]]
            return sum(closes) / len(closes)
        
        # Calculate EMA properly
        multiplier = 2.0 / (period + 1)
        
        # Start with SMA for first 'period' bars
        start_idx = max(0, len(self.bars_history) - period * 3 - shift)
        closes = [b['close'] for b in self.bars_history[start_idx:]]
        
        if shift > 0:
            closes = closes[:-shift]
        
        if len(closes) < period:
            return sum(closes) / len(closes) if closes else 0.0
        
        # Initial SMA
        ema = sum(closes[:period]) / period
        
        # Calculate EMA
        for price in closes[period:]:
            ema = (price - ema) * multiplier + ema
        
        return ema
    
    def _ema_fast(self, shift: int = 1) -> float:
        """Get EMA Fast value at shift."""
        return self._calculate_ema(self.ema_fast_period, shift)
    
    def _ema_slow(self, shift: int = 1) -> float:
        """Get EMA Slow value at shift."""
        return self._calculate_ema(self.ema_slow_period, shift)
    
    def _is_trend_buy(self) -> bool:
        """Check if trend is bullish (EMA fast > EMA slow, close > EMA fast)."""
        ema_f = self._ema_fast(1)
        ema_s = self._ema_slow(1)
        bar = self._get_bar(1)
        if bar is None or ema_f == 0 or ema_s == 0:
            return False
        return ema_f > ema_s and bar['close'] > ema_f
    
    def _is_trend_sell(self) -> bool:
        """Check if trend is bearish (EMA fast < EMA slow, close < EMA fast)."""
        ema_f = self._ema_fast(1)
        ema_s = self._ema_slow(1)
        bar = self._get_bar(1)
        if bar is None or ema_f == 0 or ema_s == 0:
            return False
        return ema_f < ema_s and bar['close'] < ema_f
    
    def _is_strong_candle(self, shift: int, min_ratio: float) -> bool:
        """Check if candle at shift has a strong body (body/range >= min_ratio)."""
        bar = self._get_bar(shift)
        if bar is None:
            return False
        
        range_val = bar['high'] - bar['low']
        if range_val <= 0:
            return False
        
        body = abs(bar['close'] - bar['open'])
        return (body / range_val) >= min_ratio
    
    def _lot_for_risk(self, risk_money: float, sl_dist: float) -> float:
        """Calculate lot size based on risk money and SL distance."""
        if sl_dist <= 0:
            return 0.0
        
        tick_value = self.symbol_info.tick_value
        tick_size = self.symbol_info.tick_size
        
        if tick_value <= 0 or tick_size <= 0:
            return 0.0
        
        loss_per_lot = (sl_dist / tick_size) * tick_value
        if loss_per_lot <= 0:
            return 0.0
        
        lots = risk_money / loss_per_lot
        
        # Normalize
        step = self.symbol_info.volume_step
        lots = int(lots / step) * step
        lots = max(lots, self.symbol_info.volume_min)
        lots = min(lots, self.max_lot)
        
        return round(lots, 2)
    
    def try_arm_setup(self):
        """
        Try to detect and arm a knee setup.
        Exact translation of TryArmSetup() from MQL5.
        """
        atr = self._calculate_atr()
        if atr <= 0:
            return
        
        buf = self.sl_buffer_atr * atr
        
        # ===== BUY SETUP =====
        if self._is_red(1):  # Bar[1] is red (pullback candle)
            run = 0
            for i in range(2, 13):  # Check bars 2-12
                if self._is_green(i):
                    run += 1
                else:
                    break
            
            if run >= self.knee_min_run_buy:
                # Trend filter
                if self.use_trend and not self._is_trend_buy():
                    pass
                elif not self._is_strong_candle(2, self.min_body_ratio_buy):
                    pass
                else:
                    bar1 = self._get_bar(1)
                    if bar1:
                        self.g_dir = +1
                        self.g_knee_high = bar1['high']
                        self.g_knee_low = bar1['low']
                        self.g_trigger = self.g_knee_high
                        self.g_pending_sl = self.g_knee_low - buf
                        self.g_one_r = self.g_trigger - self.g_pending_sl
                        
                        if self.g_one_r >= self.min_sl_points * self.symbol_info.point:
                            self.g_pending_tp = self.g_trigger + (self.rr * self.g_one_r)
                            self.g_bars_left = self.valid_bars
                            return
        
        # ===== SELL SETUP (STRICTER) =====
        if self._is_green(1):  # Bar[1] is green (pullback candle)
            run = 0
            for i in range(2, 13):  # Check bars 2-12
                if self._is_red(i):
                    run += 1
                else:
                    break
            
            if run >= self.knee_min_run_sell:
                # Trend filter
                if self.use_trend and not self._is_trend_sell():
                    pass
                elif not self._is_strong_candle(2, self.min_body_ratio_sell):
                    pass
                else:
                    bar1 = self._get_bar(1)
                    if bar1:
                        self.g_dir = -1
                        self.g_knee_high = bar1['high']
                        self.g_knee_low = bar1['low']
                        self.g_trigger = self.g_knee_low
                        self.g_pending_sl = self.g_knee_high + buf
                        self.g_one_r = self.g_pending_sl - self.g_trigger
                        
                        if self.g_one_r >= self.min_sl_points * self.symbol_info.point:
                            self.g_pending_tp = self.g_trigger - (self.rr * self.g_one_r)
                            self.g_bars_left = self.valid_bars
                            return
        
        # No valid setup found
        self.disarm()
    
    def open_buy_trade(self):
        """Open a buy trade with calculated parameters."""
        ask = self.engine.current_ask
        sl = self.g_pending_sl
        tp = self.g_pending_tp
        
        one_r = ask - sl
        if one_r <= 0:
            return
        
        risk_money = self.engine.get_account_balance() * (self.risk_percent / 100.0)
        lots = self._lot_for_risk(risk_money, one_r)
        
        if lots <= 0:
            return
        
        sl = self.symbol_info.normalize_price(sl)
        tp = self.symbol_info.normalize_price(tp)
        
        if self.engine.open_position(
            direction="buy",
            volume=lots,
            sl=sl,
            tp=tp,
            magic=self.magic,
            comment="CK_GFT_Buy"
        ):
            self.g_trades_today += 1
    
    def open_sell_trade(self):
        """Open a sell trade with calculated parameters."""
        bid = self.engine.current_bid
        sl = self.g_pending_sl
        tp = self.g_pending_tp
        
        one_r = sl - bid
        if one_r <= 0:
            return
        
        risk_money = self.engine.get_account_balance() * (self.risk_percent / 100.0)
        lots = self._lot_for_risk(risk_money, one_r)
        
        if lots <= 0:
            return
        
        sl = self.symbol_info.normalize_price(sl)
        tp = self.symbol_info.normalize_price(tp)
        
        if self.engine.open_position(
            direction="sell",
            volume=lots,
            sl=sl,
            tp=tp,
            magic=self.magic,
            comment="CK_GFT_Sell"
        ):
            self.g_trades_today += 1
    
    def manage_break_even(self):
        """
        Move SL to break-even when price moves 1R in profit.
        Exact translation of ManageBE() from MQL5.
        """
        if not self.break_even_at_1r:
            return
        
        positions = self.engine.get_positions(magic=self.magic, symbol=self.symbol_info.symbol)
        
        for pos in positions:
            if pos.be_applied:
                continue  # Already at break-even
            
            be = self.symbol_info.normalize_price(pos.open_price)
            
            if pos.direction == "buy":
                bid = self.engine.current_bid
                one_r = pos.open_price - pos.sl
                
                if one_r > 0 and bid >= pos.open_price + one_r and pos.sl < be:
                    self.engine.modify_position_sl(pos, be)
                    pos.be_applied = True
            
            elif pos.direction == "sell":
                ask = self.engine.current_ask
                one_r = pos.sl - pos.open_price
                
                if one_r > 0 and ask <= pos.open_price - one_r and pos.sl > be:
                    self.engine.modify_position_sl(pos, be)
                    pos.be_applied = True
    
    def on_bar(self, bar: dict, bar_time):
        """
        Called on every new bar - main strategy logic.
        This is the equivalent of OnTick() with IsNewBar() check in MQL5.
        """
        # Store bar in history
        self.bars_history.append(bar)
        
        # Keep only needed history (max 200 bars for EMA + ATR calculation)
        max_history = max(self.ema_slow_period * 3, 200)
        if len(self.bars_history) > max_history:
            self.bars_history = self.bars_history[-max_history:]
        
        # Check for new day
        current_day = bar_time.date()
        if self.g_day_start is None or current_day != self.g_day_start:
            self.reset_daily()
        
        # Manage break-even (every bar, like OnTick)
        self.manage_break_even()
        
        # Need enough bars for indicators
        if len(self.bars_history) < self.ema_slow_period + 10:
            return
        
        # Setup countdown
        if self.g_dir != 0:
            self.g_bars_left -= 1
            if self.g_bars_left <= 0:
                self.disarm()
        
        # Try to arm new setup if no active setup and no open positions
        if self.g_dir == 0 and self.my_positions() == 0:
            self.try_arm_setup()
        
        # Check trigger (this happens on every tick in MQL5, but in bar-based
        # backtest we check if the bar's range includes the trigger)
        if self.g_dir != 0 and self.my_positions() == 0:
            # Spread check
            if self.engine.current_spread > self.max_spread_points:
                return
            
            # Daily limits check
            if not self.trading_allowed():
                return
            
            if self.g_dir > 0:
                # Buy trigger: ask >= trigger
                # In bar-based: check if bar's high reached trigger (ask perspective)
                ask_high = bar['high'] + self.symbol_info.spread_in_price(self.engine.current_spread)
                if ask_high >= self.g_trigger:
                    self.open_buy_trade()
                    self.disarm()
            
            elif self.g_dir < 0:
                # Sell trigger: bid <= trigger
                # In bar-based: check if bar's low reached trigger
                if bar['low'] <= self.g_trigger:
                    self.open_sell_trade()
                    self.disarm()

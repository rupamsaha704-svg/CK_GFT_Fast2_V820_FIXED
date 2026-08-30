"""
Backtest Engine - Core trading simulation engine that replicates MT5 Strategy Tester behavior.

Key features:
- Bar-by-bar execution (M5 timeframe)
- Realistic spread handling (uses bar's actual spread)
- Commission and swap calculation
- Slippage simulation
- Break-even management
- Position tracking with SL/TP monitoring
- Intra-bar SL/TP detection using High/Low
- Account equity/margin tracking
- Daily reset for daily limits
"""

import pandas as pd
import numpy as np
from dataclasses import dataclass, field
from typing import List, Optional, Dict
from datetime import datetime, timedelta
from symbol_info import SymbolInfo


@dataclass
class Position:
    """Represents an open trading position."""
    ticket: int
    symbol: str
    direction: str  # "buy" or "sell"
    volume: float
    open_price: float
    open_time: datetime
    sl: float
    tp: float
    magic: int
    comment: str = ""
    commission: float = 0.0
    swap: float = 0.0
    profit: float = 0.0
    be_applied: bool = False  # Track if break-even was applied


@dataclass
class Deal:
    """Represents a completed trade (deal) in history."""
    ticket: int
    symbol: str
    direction: str
    volume: float
    open_price: float
    close_price: float
    open_time: datetime
    close_time: datetime
    sl: float
    tp: float
    magic: int
    commission: float
    swap: float
    profit: float
    net_profit: float  # profit - commission - swap
    comment: str = ""
    close_reason: str = ""  # "SL", "TP", "BE", "Signal", "Manual"


class BacktestEngine:
    """
    Core backtesting engine that simulates MT5 Strategy Tester behavior.
    
    Handles:
    - Position opening/closing with spread
    - SL/TP monitoring (intra-bar using high/low)
    - Commission and swap
    - Break-even management
    - Account balance/equity tracking
    - Margin calculation
    """
    
    def __init__(
        self,
        symbol_info: SymbolInfo,
        initial_deposit: float = 5000.0,
        leverage: int = 500,
        commission_per_lot: float = 0.0,
        slippage_points: int = 3,
        swap_enabled: bool = True,
    ):
        self.symbol_info = symbol_info
        self.initial_deposit = initial_deposit
        self.leverage = leverage
        self.commission_per_lot = commission_per_lot
        self.slippage_points = slippage_points
        self.swap_enabled = swap_enabled
        
        # Account state
        self.balance = initial_deposit
        self.equity = initial_deposit
        self.margin = 0.0
        self.free_margin = initial_deposit
        
        # Position tracking
        self.positions: List[Position] = []
        self.deals: List[Deal] = []
        self.ticket_counter = 0
        
        # Equity curve
        self.equity_curve: List[Dict] = []
        
        # Current market state
        self.current_bar = None
        self.current_time = None
        self.current_bid = 0.0
        self.current_ask = 0.0
        self.current_spread = 0
        
        # Daily tracking
        self.day_start_balance = initial_deposit
        self.current_day = None
        self.last_swap_day = None
        
        # Statistics
        self.max_equity = initial_deposit
        self.max_drawdown = 0.0
        self.max_drawdown_pct = 0.0
    
    def _next_ticket(self) -> int:
        self.ticket_counter += 1
        return self.ticket_counter
    
    def update_market(self, bar: pd.Series, bar_time: datetime):
        """
        Update current market prices from bar data.
        Bid = Close, Ask = Close + Spread
        """
        self.current_bar = bar
        self.current_time = bar_time
        self.current_spread = int(bar.get('spread', self.symbol_info.spread_avg))
        
        # Bid price = close price of the bar
        self.current_bid = bar['close']
        # Ask price = bid + spread
        self.current_ask = self.current_bid + self.symbol_info.spread_in_price(self.current_spread)
    
    def _apply_slippage(self, price: float, direction: str, is_entry: bool) -> float:
        """
        Apply realistic slippage.
        Entry: slippage works against you
        Exit: slippage works against you
        """
        if self.slippage_points == 0:
            return price
        
        # Random slippage 0 to max
        slip = np.random.randint(0, self.slippage_points + 1) * self.symbol_info.point
        
        if direction == "buy":
            if is_entry:
                price += slip  # Buy entry: price goes up (worse)
            else:
                price -= slip  # Buy exit: price goes down (worse)
        else:  # sell
            if is_entry:
                price -= slip  # Sell entry: price goes down (worse)
            else:
                price += slip  # Sell exit: price goes up (worse)
        
        return self.symbol_info.normalize_price(price)
    
    def open_position(
        self,
        direction: str,
        volume: float,
        sl: float = 0.0,
        tp: float = 0.0,
        magic: int = 0,
        comment: str = ""
    ) -> bool:
        """
        Open a new position at current market price.
        Returns True if successful.
        """
        # Determine entry price
        if direction == "buy":
            entry_price = self.current_ask
        else:
            entry_price = self.current_bid
        
        # Apply slippage
        entry_price = self._apply_slippage(entry_price, direction, is_entry=True)
        
        # Validate volume
        volume = self.symbol_info.normalize_lots(volume)
        
        # Calculate margin required
        margin_req = self.symbol_info.calculate_margin(volume, entry_price, self.leverage)
        
        # Check if we have enough free margin
        if margin_req > self.free_margin:
            return False
        
        # Calculate commission
        commission = self.commission_per_lot * volume * 2  # Round trip
        
        # Create position
        pos = Position(
            ticket=self._next_ticket(),
            symbol=self.symbol_info.symbol,
            direction=direction,
            volume=volume,
            open_price=entry_price,
            open_time=self.current_time,
            sl=sl,
            tp=tp,
            magic=magic,
            comment=comment,
            commission=commission,
        )
        
        self.positions.append(pos)
        
        # Update margin
        self.margin += margin_req
        self.free_margin = self.equity - self.margin
        
        return True
    
    def close_position(self, pos: Position, close_price: float, reason: str = "Signal"):
        """Close a position at the given price."""
        # Apply slippage for exit
        close_price = self._apply_slippage(close_price, pos.direction, is_entry=False)
        
        # Calculate final profit
        profit = self.symbol_info.calculate_profit(
            pos.direction, pos.open_price, close_price, pos.volume
        )
        
        # Net profit (after commission and swap)
        net_profit = profit - pos.commission + pos.swap  # swap can be positive
        
        # Create deal record
        deal = Deal(
            ticket=pos.ticket,
            symbol=pos.symbol,
            direction=pos.direction,
            volume=pos.volume,
            open_price=pos.open_price,
            close_price=close_price,
            open_time=pos.open_time,
            close_time=self.current_time,
            sl=pos.sl,
            tp=pos.tp,
            magic=pos.magic,
            commission=pos.commission,
            swap=pos.swap,
            profit=profit,
            net_profit=net_profit,
            comment=pos.comment,
            close_reason=reason,
        )
        self.deals.append(deal)
        
        # Update balance
        self.balance += net_profit
        
        # Remove position
        if pos in self.positions:
            self.positions.remove(pos)
        
        # Update margin
        margin_released = self.symbol_info.calculate_margin(
            pos.volume, pos.open_price, self.leverage
        )
        self.margin = max(0, self.margin - margin_released)
        self.free_margin = self.equity - self.margin
    
    def modify_position_sl(self, pos: Position, new_sl: float):
        """Modify position's stop loss (for break-even)."""
        pos.sl = self.symbol_info.normalize_price(new_sl)
    
    def _check_sl_tp_hit(self, pos: Position, bar: pd.Series) -> Optional[str]:
        """
        Check if SL or TP was hit during the bar.
        Uses High/Low for intra-bar detection - this is how MT5 does it.
        
        Returns: "SL", "TP", or None
        """
        bar_high = bar['high']
        bar_low = bar['low']
        
        if pos.direction == "buy":
            # For buy: SL hit if low <= SL, TP hit if high >= TP
            if pos.sl > 0 and bar_low <= pos.sl:
                return "SL"
            if pos.tp > 0 and bar_high >= pos.tp:
                return "TP"
        else:  # sell
            # For sell: SL hit if high >= SL, TP hit if low <= TP
            # Ask = High + spread for worst case
            ask_high = bar_high + self.symbol_info.spread_in_price(self.current_spread)
            if pos.sl > 0 and ask_high >= pos.sl:
                return "SL"
            if pos.tp > 0 and bar_low <= pos.tp:
                return "TP"
        
        return None
    
    def _get_exit_price(self, pos: Position, reason: str) -> float:
        """Get the exit price for SL/TP hit."""
        if reason == "SL":
            return pos.sl
        elif reason == "TP":
            return pos.tp
        else:
            # Market close
            if pos.direction == "buy":
                return self.current_bid
            else:
                return self.current_ask
    
    def monitor_positions(self, bar: pd.Series):
        """
        Monitor all open positions for SL/TP hits.
        Called every bar with current bar data.
        """
        positions_to_close = []
        
        for pos in self.positions:
            hit = self._check_sl_tp_hit(pos, bar)
            if hit:
                exit_price = self._get_exit_price(pos, hit)
                positions_to_close.append((pos, exit_price, hit))
        
        # Close positions that hit SL/TP
        for pos, price, reason in positions_to_close:
            self.close_position(pos, price, reason)
    
    def _apply_swap(self):
        """Apply daily swap to all open positions (charged at midnight)."""
        if not self.swap_enabled:
            return
        
        for pos in self.positions:
            if pos.direction == "buy":
                swap_rate = self.symbol_info.swap_long
            else:
                swap_rate = self.symbol_info.swap_short
            
            # Swap per lot per day
            daily_swap = swap_rate * pos.volume
            pos.swap += daily_swap
    
    def update_equity(self):
        """Update equity based on current floating P&L."""
        floating_pl = 0.0
        
        for pos in self.positions:
            if pos.direction == "buy":
                current_price = self.current_bid
            else:
                current_price = self.current_ask
            
            pos.profit = self.symbol_info.calculate_profit(
                pos.direction, pos.open_price, current_price, pos.volume
            )
            floating_pl += pos.profit - pos.commission + pos.swap
        
        self.equity = self.balance + floating_pl
        self.free_margin = self.equity - self.margin
        
        # Track max equity and drawdown
        if self.equity > self.max_equity:
            self.max_equity = self.equity
        
        current_dd = self.max_equity - self.equity
        if current_dd > self.max_drawdown:
            self.max_drawdown = current_dd
            if self.max_equity > 0:
                self.max_drawdown_pct = (current_dd / self.max_equity) * 100
    
    def record_equity(self):
        """Record equity curve data point."""
        self.equity_curve.append({
            "time": self.current_time,
            "balance": self.balance,
            "equity": self.equity,
            "floating_pl": self.equity - self.balance,
            "positions": len(self.positions),
        })
    
    def process_bar(self, bar: pd.Series, bar_time: datetime):
        """
        Process a single bar - update market, check positions, apply swap.
        This is called before strategy logic.
        """
        # Update market prices
        self.update_market(bar, bar_time)
        
        # Check for new day (for swap and daily reset)
        bar_day = bar_time.date()
        if self.current_day is None:
            self.current_day = bar_day
            self.day_start_balance = self.balance
        elif bar_day != self.current_day:
            # New day - apply swap
            if self.last_swap_day != self.current_day:
                self._apply_swap()
                # Triple swap on Wednesday (for weekend)
                if self.current_day.weekday() == 2:  # Wednesday
                    self._apply_swap()
                    self._apply_swap()
                self.last_swap_day = self.current_day
            
            self.current_day = bar_day
            self.day_start_balance = self.balance
        
        # Monitor SL/TP for open positions
        self.monitor_positions(bar)
        
        # Update equity
        self.update_equity()
        
        # Record equity (every 12 bars = 1 hour for M5)
        if self.ticket_counter % 12 == 0 or len(self.positions) > 0:
            self.record_equity()
    
    def get_positions_count(self, magic: int = None, symbol: str = None) -> int:
        """Count open positions matching criteria."""
        count = 0
        for pos in self.positions:
            if magic and pos.magic != magic:
                continue
            if symbol and pos.symbol != symbol:
                continue
            count += 1
        return count
    
    def get_positions(self, magic: int = None, symbol: str = None) -> List[Position]:
        """Get open positions matching criteria."""
        result = []
        for pos in self.positions:
            if magic and pos.magic != magic:
                continue
            if symbol and pos.symbol != symbol:
                continue
            result.append(pos)
        return result
    
    def get_account_balance(self) -> float:
        return self.balance
    
    def get_account_equity(self) -> float:
        return self.equity
    
    def get_day_start_balance(self) -> float:
        return self.day_start_balance

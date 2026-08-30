"""
Symbol Information class - provides all MT5-like symbol properties for backtesting.
Realistic values for EURUSD and other major pairs.
"""

class SymbolInfo:
    """Provides symbol properties similar to MT5's SymbolInfoDouble/Integer functions."""
    
    # Default properties for common symbols
    SYMBOL_DEFAULTS = {
        "EURUSD": {
            "digits": 5,
            "point": 0.00001,
            "tick_size": 0.00001,
            "tick_value": 1.0,  # USD per tick per 1 lot (100,000 units)
            "contract_size": 100000,
            "volume_min": 0.01,
            "volume_max": 100.0,
            "volume_step": 0.01,
            "spread_avg": 12,  # points (1.2 pips)
            "spread_min": 8,
            "spread_max": 35,
            "stops_level": 0,
            "freeze_level": 0,
            "swap_long": -6.2,   # per lot per day
            "swap_short": 0.8,
            "commission_per_lot": 0.0,  # some brokers charge $7 round trip
            "trade_mode": "forex",
        },
        "GBPUSD": {
            "digits": 5,
            "point": 0.00001,
            "tick_size": 0.00001,
            "tick_value": 1.0,
            "contract_size": 100000,
            "volume_min": 0.01,
            "volume_max": 100.0,
            "volume_step": 0.01,
            "spread_avg": 15,
            "spread_min": 10,
            "spread_max": 45,
            "stops_level": 0,
            "freeze_level": 0,
            "swap_long": -3.5,
            "swap_short": -2.1,
            "commission_per_lot": 0.0,
            "trade_mode": "forex",
        },
        "USDJPY": {
            "digits": 3,
            "point": 0.001,
            "tick_size": 0.001,
            "tick_value": 0.67,  # approximate
            "contract_size": 100000,
            "volume_min": 0.01,
            "volume_max": 100.0,
            "volume_step": 0.01,
            "spread_avg": 12,
            "spread_min": 8,
            "spread_max": 30,
            "stops_level": 0,
            "freeze_level": 0,
            "swap_long": 8.5,
            "swap_short": -15.2,
            "commission_per_lot": 0.0,
            "trade_mode": "forex",
        },
        "XAUUSD": {
            "digits": 2,
            "point": 0.01,
            "tick_size": 0.01,
            "tick_value": 1.0,
            "contract_size": 100,
            "volume_min": 0.01,
            "volume_max": 50.0,
            "volume_step": 0.01,
            "spread_avg": 25,
            "spread_min": 15,
            "spread_max": 80,
            "stops_level": 0,
            "freeze_level": 0,
            "swap_long": -25.0,
            "swap_short": 5.0,
            "commission_per_lot": 0.0,
            "trade_mode": "cfd",
        },
    }
    
    def __init__(self, symbol: str, custom_props: dict = None):
        """
        Initialize symbol info.
        
        Args:
            symbol: Symbol name (e.g., "EURUSD")
            custom_props: Optional dict to override default properties
        """
        self.symbol = symbol.upper()
        
        if self.symbol in self.SYMBOL_DEFAULTS:
            self._props = self.SYMBOL_DEFAULTS[self.symbol].copy()
        else:
            # Default to EURUSD-like properties
            self._props = self.SYMBOL_DEFAULTS["EURUSD"].copy()
            print(f"Warning: Symbol {symbol} not found, using EURUSD defaults")
        
        # Apply custom overrides
        if custom_props:
            self._props.update(custom_props)
    
    @property
    def digits(self) -> int:
        return self._props["digits"]
    
    @property
    def point(self) -> float:
        return self._props["point"]
    
    @property
    def tick_size(self) -> float:
        return self._props["tick_size"]
    
    @property
    def tick_value(self) -> float:
        return self._props["tick_value"]
    
    @property
    def contract_size(self) -> float:
        return self._props["contract_size"]
    
    @property
    def volume_min(self) -> float:
        return self._props["volume_min"]
    
    @property
    def volume_max(self) -> float:
        return self._props["volume_max"]
    
    @property
    def volume_step(self) -> float:
        return self._props["volume_step"]
    
    @property
    def spread_avg(self) -> int:
        return self._props["spread_avg"]
    
    @property
    def spread_min(self) -> int:
        return self._props["spread_min"]
    
    @property
    def spread_max(self) -> int:
        return self._props["spread_max"]
    
    @property
    def stops_level(self) -> int:
        return self._props["stops_level"]
    
    @property
    def freeze_level(self) -> int:
        return self._props["freeze_level"]
    
    @property
    def swap_long(self) -> float:
        return self._props["swap_long"]
    
    @property
    def swap_short(self) -> float:
        return self._props["swap_short"]
    
    @property
    def commission_per_lot(self) -> float:
        return self._props["commission_per_lot"]
    
    def normalize_price(self, price: float) -> float:
        """Normalize price to symbol's digits."""
        return round(price, self.digits)
    
    def normalize_lots(self, lots: float) -> float:
        """Normalize lots to symbol's volume step."""
        step = self.volume_step
        lots = int(lots / step) * step
        lots = max(lots, self.volume_min)
        lots = min(lots, self.volume_max)
        return round(lots, 2)
    
    def calculate_profit(self, direction: str, open_price: float, close_price: float, lots: float) -> float:
        """
        Calculate profit/loss for a closed trade.
        Matches MT5's order_calc_profit logic.
        """
        if direction == "buy":
            price_diff = close_price - open_price
        else:
            price_diff = open_price - close_price
        
        ticks = price_diff / self.tick_size
        profit = ticks * self.tick_value * lots
        return round(profit, 2)
    
    def calculate_margin(self, lots: float, price: float, leverage: int) -> float:
        """Calculate required margin for a position."""
        if self._props["trade_mode"] == "forex":
            margin = (lots * self.contract_size) / leverage
        else:  # CFD
            margin = (lots * self.contract_size * price) / leverage
        return round(margin, 2)
    
    def get_spread_for_bar(self, bar_spread: int = None) -> int:
        """Get spread in points. Use bar's spread if available, otherwise average."""
        if bar_spread is not None and bar_spread > 0:
            return bar_spread
        return self.spread_avg
    
    def spread_in_price(self, spread_points: int) -> float:
        """Convert spread from points to price difference."""
        return spread_points * self.point

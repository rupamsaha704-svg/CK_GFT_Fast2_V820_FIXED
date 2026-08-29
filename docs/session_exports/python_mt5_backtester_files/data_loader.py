"""
Historical Data Loader - Generates realistic M5 OHLC data for backtesting.
Since we can't connect to MT5 from Linux, we generate synthetic data that
mirrors real forex market behavior with proper spread, volatility, and sessions.

For production use: export M5 data from MT5 as CSV and load it here.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os


def generate_realistic_m5_data(
    symbol: str = "EURUSD",
    start_date: str = "2025-01-01",
    end_date: str = "2025-06-30",
    base_price: float = 1.0800,
    avg_daily_range_pips: float = 60.0,
    avg_spread_points: int = 12,
    seed: int = 42
) -> pd.DataFrame:
    """
    Generate realistic M5 OHLCV data with proper forex market characteristics:
    - Market hours (Sunday 22:00 UTC to Friday 22:00 UTC)
    - Session volatility (Asian low, London/NY high)
    - Strong trending and ranging periods (critical for knee strategy)
    - Realistic spread variation
    - Weekend gaps
    - Proper impulse-pullback market structure
    
    Returns DataFrame with columns: time, open, high, low, close, tick_volume, spread
    """
    np.random.seed(seed)
    
    start = pd.Timestamp(start_date)
    end = pd.Timestamp(end_date)
    
    # Generate all M5 bars during forex market hours
    bars = []
    current_time = start
    price = base_price
    
    daily_range = avg_daily_range_pips * 0.0001  # Convert pips to price for forex
    # For gold/metals, point = 0.01, so daily_range_pips * point gives actual price range
    # We'll use avg_daily_range_pips as "points" regardless of instrument
    # The caller passes this in the instrument's point scale
    # e.g., EURUSD: 60 points * 0.0001 = 0.006 (60 pips range)
    # e.g., XAUUSD: 3500 points * 0.01 = $35 range
    if symbol.upper() in ("XAUUSD", "XAGUSD"):
        daily_range = avg_daily_range_pips * 0.01  # Gold: points * $0.01
    elif symbol.upper() in ("USDJPY", "EURJPY", "GBPJPY"):
        daily_range = avg_daily_range_pips * 0.001
    
    bar_volatility = daily_range / (12 * 12)  # Higher base volatility per M5 bar
    
    # Trend/impulse parameters - market structure
    trend_direction = 0       # -1, 0, +1
    trend_strength = 0.0
    trend_bars_left = 0
    
    # Impulse-pullback state machine
    market_state = "ranging"  # "trending_up", "trending_down", "pullback_up", "pullback_down", "ranging"
    state_bars_left = 0
    impulse_strength = 0.0
    
    day_open = price
    day_count = 0
    bar_count = 0
    
    # Determine price precision based on symbol
    if symbol.upper() == "XAUUSD":
        price_digits = 2
    elif symbol.upper() in ("USDJPY", "EURJPY", "GBPJPY"):
        price_digits = 3
    else:
        price_digits = 5
    
    while current_time <= end:
        weekday = current_time.weekday()
        hour = current_time.hour
        
        # Forex market: closed Saturday and most of Sunday
        if weekday == 5:
            current_time += timedelta(minutes=5)
            continue
        if weekday == 6 and hour < 22:
            current_time += timedelta(minutes=5)
            continue
        if weekday == 4 and hour >= 22:
            current_time += timedelta(minutes=5)
            continue
        
        # Session-based volatility multiplier
        if 0 <= hour < 8:      # Asian session
            vol_mult = 0.7
            spread_mult = 1.2
        elif 8 <= hour < 13:   # London session
            vol_mult = 1.5
            spread_mult = 0.8
        elif 13 <= hour < 17:  # London+NY overlap
            vol_mult = 1.8
            spread_mult = 0.7
        elif 17 <= hour < 22:  # NY session
            vol_mult = 1.2
            spread_mult = 0.9
        else:
            vol_mult = 0.5
            spread_mult = 1.4
        
        # New day tracking
        if current_time.hour == 0 and current_time.minute == 0 and weekday != 6:
            day_open = price
            day_count += 1
        
        bar_count += 1
        
        # Market structure state machine - creates proper impulse/pullback patterns
        if state_bars_left <= 0:
            # Transition to new state
            r = np.random.random()
            if market_state == "ranging":
                if r < 0.35:
                    market_state = "trending_up"
                    state_bars_left = np.random.randint(15, 80)  # Strong trends lasting 15-80 bars
                    impulse_strength = np.random.uniform(0.5, 1.5)
                elif r < 0.70:
                    market_state = "trending_down"
                    state_bars_left = np.random.randint(15, 80)
                    impulse_strength = np.random.uniform(0.5, 1.5)
                else:
                    market_state = "ranging"
                    state_bars_left = np.random.randint(20, 100)
                    impulse_strength = 0.0
            elif market_state == "trending_up":
                if r < 0.45:
                    market_state = "pullback_down"  # Pullback after uptrend
                    state_bars_left = np.random.randint(3, 12)  # Short pullbacks
                    impulse_strength = np.random.uniform(0.3, 0.8)
                elif r < 0.7:
                    market_state = "trending_up"  # Continue trend
                    state_bars_left = np.random.randint(10, 50)
                    impulse_strength = np.random.uniform(0.4, 1.2)
                else:
                    market_state = "ranging"
                    state_bars_left = np.random.randint(15, 60)
                    impulse_strength = 0.0
            elif market_state == "trending_down":
                if r < 0.45:
                    market_state = "pullback_up"  # Pullback after downtrend
                    state_bars_left = np.random.randint(3, 12)
                    impulse_strength = np.random.uniform(0.3, 0.8)
                elif r < 0.7:
                    market_state = "trending_down"  # Continue trend
                    state_bars_left = np.random.randint(10, 50)
                    impulse_strength = np.random.uniform(0.4, 1.2)
                else:
                    market_state = "ranging"
                    state_bars_left = np.random.randint(15, 60)
                    impulse_strength = 0.0
            elif market_state == "pullback_down":
                if r < 0.55:
                    market_state = "trending_up"  # Resume uptrend after pullback
                    state_bars_left = np.random.randint(10, 50)
                    impulse_strength = np.random.uniform(0.5, 1.3)
                else:
                    market_state = "trending_down"  # Reversal
                    state_bars_left = np.random.randint(15, 60)
                    impulse_strength = np.random.uniform(0.5, 1.0)
            elif market_state == "pullback_up":
                if r < 0.55:
                    market_state = "trending_down"  # Resume downtrend after pullback
                    state_bars_left = np.random.randint(10, 50)
                    impulse_strength = np.random.uniform(0.5, 1.3)
                else:
                    market_state = "trending_up"  # Reversal
                    state_bars_left = np.random.randint(15, 60)
                    impulse_strength = np.random.uniform(0.5, 1.0)
        
        state_bars_left -= 1
        
        # Calculate drift based on market state
        effective_vol = bar_volatility * vol_mult
        
        if market_state == "trending_up":
            drift = impulse_strength * effective_vol * 0.6
            noise_scale = 0.7  # Less noise during trends
        elif market_state == "trending_down":
            drift = -impulse_strength * effective_vol * 0.6
            noise_scale = 0.7
        elif market_state == "pullback_down":
            drift = -impulse_strength * effective_vol * 0.4
            noise_scale = 0.8
        elif market_state == "pullback_up":
            drift = impulse_strength * effective_vol * 0.4
            noise_scale = 0.8
        else:  # ranging
            drift = 0
            noise_scale = 1.0
        
        # Random walk with drift and momentum
        noise = np.random.normal(0, effective_vol * noise_scale)
        move = drift + noise
        
        bar_open = price
        bar_close = bar_open + move
        
        # Generate realistic high/low based on direction
        if bar_close > bar_open:  # Green candle
            # Wick generation
            upper_wick = abs(np.random.exponential(effective_vol * 0.3))
            lower_wick = abs(np.random.exponential(effective_vol * 0.2))
            bar_high = max(bar_open, bar_close) + upper_wick
            bar_low = min(bar_open, bar_close) - lower_wick
        else:  # Red candle
            upper_wick = abs(np.random.exponential(effective_vol * 0.2))
            lower_wick = abs(np.random.exponential(effective_vol * 0.3))
            bar_high = max(bar_open, bar_close) + upper_wick
            bar_low = min(bar_open, bar_close) - lower_wick
        
        # Ensure OHLC validity
        bar_high = max(bar_high, bar_open, bar_close)
        bar_low = min(bar_low, bar_open, bar_close)
        
        # Spread (in points)
        spread = max(
            int(avg_spread_points * spread_mult + np.random.normal(0, 2)),
            avg_spread_points // 2
        )
        
        # Tick volume (higher during active sessions and trends)
        trend_vol_boost = 1.5 if market_state.startswith("trending") else 1.0
        tick_vol = int(max(10, np.random.normal(150 * vol_mult * trend_vol_boost, 40)))
        
        bars.append({
            "time": current_time,
            "open": round(bar_open, price_digits),
            "high": round(bar_high, price_digits),
            "low": round(bar_low, price_digits),
            "close": round(bar_close, price_digits),
            "tick_volume": tick_vol,
            "spread": spread
        })
        
        price = bar_close
        current_time += timedelta(minutes=5)
    
    df = pd.DataFrame(bars)
    df["time"] = pd.to_datetime(df["time"])
    df.set_index("time", inplace=True)
    
    print(f"Generated {len(df)} M5 bars for {symbol}")
    print(f"  Period: {df.index[0]} to {df.index[-1]}")
    print(f"  Price range: {df['low'].min():.{price_digits}f} - {df['high'].max():.{price_digits}f}")
    print(f"  Avg spread: {df['spread'].mean():.1f} points")
    
    return df


def load_csv_data(filepath: str, start_date: str = None, end_date: str = None) -> pd.DataFrame:
    """
    Load M5 data exported from MT5 as CSV.
    Supports both tab-separated MT5 History Center format:
        <DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>
    And comma-separated format:
        time,open,high,low,close,tick_volume,spread,real_volume
    
    Args:
        filepath: Path to the CSV file
        start_date: Optional start date filter (YYYY-MM-DD)
        end_date: Optional end date filter (YYYY-MM-DD)
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Data file not found: {filepath}")
    
    # Detect format by reading first line
    with open(filepath, 'r') as f:
        first_line = f.readline()
    
    if '\t' in first_line and '<DATE>' in first_line.upper():
        # MT5 History Center tab-separated format
        df = pd.read_csv(filepath, sep='\t')
        
        # Standardize column names
        col_map = {}
        for col in df.columns:
            col_upper = col.upper().strip('<>').strip()
            if col_upper == 'DATE':
                col_map[col] = 'date'
            elif col_upper == 'TIME':
                col_map[col] = 'time_col'
            elif col_upper == 'OPEN':
                col_map[col] = 'open'
            elif col_upper == 'HIGH':
                col_map[col] = 'high'
            elif col_upper == 'LOW':
                col_map[col] = 'low'
            elif col_upper == 'CLOSE':
                col_map[col] = 'close'
            elif col_upper == 'TICKVOL':
                col_map[col] = 'tick_volume'
            elif col_upper == 'VOL':
                col_map[col] = 'volume'
            elif col_upper == 'SPREAD':
                col_map[col] = 'spread'
        
        df.rename(columns=col_map, inplace=True)
        
        # Parse datetime - format: 2025.08.01  01:05:00
        df['time'] = pd.to_datetime(df['date'] + ' ' + df['time_col'], format='%Y.%m.%d %H:%M:%S')
        df.drop(columns=['date', 'time_col'], inplace=True, errors='ignore')
    
    elif ',' in first_line and 'time' in first_line.lower():
        # Comma-separated format with 'time' column
        df = pd.read_csv(filepath)
        df['time'] = pd.to_datetime(df['time'])
    
    else:
        # Try generic reading
        try:
            df = pd.read_csv(filepath, sep='\t')
        except:
            df = pd.read_csv(filepath)
        
        # Attempt to find datetime column
        for col in df.columns:
            try:
                df['time'] = pd.to_datetime(df[col])
                break
            except:
                continue
    
    # Set time as index
    df.set_index('time', inplace=True)
    df.sort_index(inplace=True)
    
    # Ensure required columns exist
    required = ['open', 'high', 'low', 'close']
    for col in required:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")
    
    if 'tick_volume' not in df.columns:
        df['tick_volume'] = 100
    if 'spread' not in df.columns:
        df['spread'] = 25  # default gold spread
    
    # Filter by date range if specified
    if start_date:
        df = df[df.index >= pd.Timestamp(start_date)]
    if end_date:
        df = df[df.index <= pd.Timestamp(end_date)]
    
    print(f"Loaded {len(df)} bars from {filepath}")
    print(f"  Period: {df.index[0]} to {df.index[-1]}")
    print(f"  Price range: {df['low'].min():.2f} - {df['high'].max():.2f}")
    print(f"  Avg spread: {df['spread'].mean():.1f} points")
    
    return df


def save_data(df: pd.DataFrame, filepath: str):
    """Save data to CSV for reuse."""
    df.to_csv(filepath)
    print(f"Data saved to: {filepath}")


def load_data(filepath: str) -> pd.DataFrame:
    """Load previously saved data."""
    df = pd.read_csv(filepath, index_col='time', parse_dates=True)
    return df
